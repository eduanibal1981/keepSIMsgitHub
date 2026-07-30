-- ============================================================================
-- G10 — Device binding + velocity anti-fraud, part 1: the registry
--
-- Feature suggestion #10 in doc/PRODUCTION_PLAN_REVIEW.md § 6. This part is
-- deliberately inert: it creates the places device facts live, the one client
-- write path into them, and the read path a user needs to see their own
-- devices. Nothing is scored and nothing is blocked until g10b/g10c.
--
-- ── Decisions worth not re-deriving ────────────────────────────────────────
--
-- 1. THE DEVICE ID ALREADY EXISTED; THIS DOES NOT INVENT ONE.
--    `DeviceTokenRepository` has been generating a 32-char hex id from
--    `Random.secure()` and persisting it in **SharedPreferences** under
--    `keepsims_device_id` since the push work, then upserting
--    `device_push_tokens (user_id, device_id)`. (The G10 brief said
--    flutter_secure_storage and a UUID — it is neither.) `user_devices` is a
--    second, money-facing view of that same id, not a competing identity.
--    It is a separate table because `device_push_tokens` is a delivery
--    address that gets nulled on sign-out, and an anti-fraud registry must
--    not forget a device the moment its owner signs out.
--
-- 2. A DEVICE ID FROM A CLIENT IS A CLAIM, NOT A FACT. Nothing here treats it
--    as authentication. `normalize_device_id()` therefore bounds the claim
--    (charset + length) and is enforced as a CHECK constraint, so no writer —
--    including service_role — can park a megabyte of attacker text in the
--    column. An id that fails normalisation becomes NULL, which g10b scores
--    as *more* suspicious than a known device, never as clean.
--
-- 3. THE SAME PHYSICAL DEVICE UNDER SEVERAL user_ids IS THE POINT. The PK is
--    `(user_id, device_id)` and there is a plain index on `device_id` alone,
--    because "how many accounts share this handset" is the single most useful
--    signal this feature has. It is not a uniqueness violation, it is data.
--
-- 4. `device_money_events` IS APPEND-ONLY AND IN THE MONEY TRANSACTION.
--    Velocity cannot be recovered from `security_logs` (jsonb, no amount, no
--    device column, no index to aggregate on) and it cannot be recovered from
--    `wallet_transactions` either, because a user with two devices would have
--    every deposit attributed to both. So attempts are recorded here, typed,
--    with the decision that was reached. `security_logs` still gets the
--    threshold breaches — that is where the F-phase audit vocabulary lives.
--    The insert is inside the caller's transaction on purpose: an audit trail
--    that a money path is allowed to skip is not an audit trail.
--
-- 5. `security_logs` GETS ITS DEFAULT GRANTS STRIPPED HERE. It arrived with
--    `GRANT ALL` to `anon` and `authenticated` (one of the 32 tables F6
--    missed), and RLS-on-with-zero-policies does **not** gate TRUNCATE. It was
--    latent because TRUNCATE is not reachable through PostgREST; it stops
--    being acceptable the moment G10 makes that table the place refusals are
--    explained from. See § "hardening" below.
--
-- 6. THE THRESHOLDS ARE HIDDEN FROM CLIENTS. `system_configs` is SELECTable by
--    every authenticated user (`Allow authenticated users to read config`,
--    `USING (true …)`). Publishing "we deny at 4 accounts per device" to the
--    people the control exists to stop is self-defeating, so a RESTRICTIVE
--    policy excludes `DEVICE_RISK_%` from that read. The existing permissive
--    policies are untouched; service_role (and therefore the dashboard and
--    every Edge Function) still reads them normally.
--
-- 7. THE USER'S OWN DEVICE LIST GOES THROUGH A FUNCTION, NOT A POLICY.
--    `my_devices()` is SECURITY DEFINER with no user-id argument, the shape
--    § 4 of the brief requires and the same shape as G6's
--    `household_spend_summary()`. The tables stay deny-all so the cross-user
--    device linkage — the sensitive half — has no client-reachable surface at
--    all, not even a row count.
-- ============================================================================


-- ---------------------------------------------------------------------------
-- 1. Bounding the claim.
--
-- IMMUTABLE so it can be used in a CHECK constraint. Returns NULL rather than
-- raising: callers on a money path must be able to say "no usable device id"
-- and carry on scoring, not blow up.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.normalize_device_id(p_raw text)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path TO ''
AS $$
  SELECT CASE
           WHEN s.v ~ '^[a-z0-9][a-z0-9._:-]{7,127}$' THEN s.v
           ELSE NULL
         END
  FROM (SELECT lower(btrim(coalesce(p_raw, ''))) AS v) s;
$$;

COMMENT ON FUNCTION public.normalize_device_id(text) IS
  'G10: lowercases/trims a client-supplied device id and returns NULL unless it '
  'matches ^[a-z0-9][a-z0-9._:-]{7,127}$. A device id is attacker-controlled; '
  'this is the only thing standing between it and a text column.';


-- ---------------------------------------------------------------------------
-- 2. The registry.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_devices (
  user_id       uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  device_id     text        NOT NULL,
  platform      text,
  app_version   text,
  trust_state   text        NOT NULL DEFAULT 'unknown',
  first_seen_at timestamptz NOT NULL DEFAULT now(),
  last_seen_at  timestamptz NOT NULL DEFAULT now(),
  attested_at   timestamptz,
  label         text,
  revoked_at    timestamptz,
  PRIMARY KEY (user_id, device_id),
  CONSTRAINT user_devices_trust_state_check
    CHECK (trust_state IN ('unknown', 'trusted', 'blocked')),
  CONSTRAINT user_devices_device_id_shape
    CHECK (device_id = public.normalize_device_id(device_id)),
  CONSTRAINT user_devices_platform_check
    CHECK (platform IS NULL OR platform = ANY (ARRAY['android', 'ios', 'web', 'macos', 'windows', 'linux', 'fuchsia'])),
  CONSTRAINT user_devices_app_version_len
    CHECK (app_version IS NULL OR length(app_version) <= 32),
  CONSTRAINT user_devices_label_len
    CHECK (label IS NULL OR length(label) <= 60)
);

-- The cross-user lookup. Not unique, deliberately: see decision 3.
CREATE INDEX IF NOT EXISTS idx_user_devices_device_id
  ON public.user_devices (device_id);

CREATE INDEX IF NOT EXISTS idx_user_devices_user_last_seen
  ON public.user_devices (user_id, last_seen_at DESC);

COMMENT ON TABLE public.user_devices IS
  'G10: one row per (account, app install). Deny-all to clients; read your own '
  'through my_devices(). trust_state trusted/blocked is the support escape '
  'hatch in both directions.';
COMMENT ON COLUMN public.user_devices.attested_at IS
  'G10 part 4: last time Firebase App Check proved this app instance was genuine. '
  'NULL means never attested, which is the normal state until App Check is enforced.';
COMMENT ON COLUMN public.user_devices.revoked_at IS
  'G10: set by revoke_my_device(). The row is kept — an anti-fraud registry that '
  'forgets on sign-out is worthless — but the device is treated as new again.';


-- ---------------------------------------------------------------------------
-- 3. The append-only attempt log that velocity is computed from.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.device_money_events (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at        timestamptz NOT NULL DEFAULT now(),
  user_id           uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  device_id         text,
  action            text        NOT NULL,
  amount_usd        numeric(10,2),
  assessed_decision text        NOT NULL,
  enforced          boolean     NOT NULL DEFAULT false,
  reason            text,
  score             integer,
  reference_id      text,
  detail            jsonb,
  CONSTRAINT dme_action_check CHECK (action IN (
    'deposit_order', 'instant_refill', 'esim_purchase', 'gift_send', 'plan_fee')),
  CONSTRAINT dme_decision_check CHECK (assessed_decision IN ('allow', 'challenge', 'deny')),
  CONSTRAINT dme_device_id_shape
    CHECK (device_id IS NULL OR device_id = public.normalize_device_id(device_id))
);

CREATE INDEX IF NOT EXISTS idx_dme_device_created
  ON public.device_money_events (device_id, created_at DESC)
  WHERE device_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_dme_user_created
  ON public.device_money_events (user_id, created_at DESC);

COMMENT ON TABLE public.device_money_events IS
  'G10: every money attempt that reached a guarded RPC, with the risk decision '
  'that was reached. assessed_decision is what the model said; enforced is '
  'whether it actually blocked. Deny-all; the source of every velocity count.';
COMMENT ON COLUMN public.device_money_events.enforced IS
  'false with assessed_decision = deny means DEVICE_RISK_ENFORCE was off and the '
  'money moved anyway. That gap is how the owner measures the false-positive rate '
  'before turning enforcement on.';


-- ---------------------------------------------------------------------------
-- 4. The escape hatch.
--
-- The first false positive will be a real customer who cannot top up, at a
-- time when nobody wants to reason about scores. One INSERT here and that
-- user is never scored again until expires_at.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.device_risk_allowlist (
  user_id    uuid        PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  reason     text        NOT NULL,
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by text        NOT NULL DEFAULT 'owner',
  CONSTRAINT device_risk_allowlist_reason_len CHECK (length(btrim(reason)) BETWEEN 3 AND 500)
);

COMMENT ON TABLE public.device_risk_allowlist IS
  'G10: per-user exemption from device risk scoring. expires_at NULL = permanent. '
  'Every row is a decision someone should be able to defend, hence reason NOT NULL.';


-- ---------------------------------------------------------------------------
-- 5. RLS and grants — all three tables are deny-all to clients.
--
-- RLS on with zero policies denies every DML verb for anon/authenticated, and
-- the REVOKE is what closes TRUNCATE, which RLS does not gate. Both, always:
-- F6 learned that the hard way and G5b learned it again.
-- ---------------------------------------------------------------------------
ALTER TABLE public.user_devices          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_money_events   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_risk_allowlist ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.user_devices          FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.device_money_events   FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.device_risk_allowlist FROM PUBLIC, anon, authenticated;

GRANT ALL ON TABLE public.user_devices          TO service_role;
GRANT ALL ON TABLE public.device_money_events   TO service_role;
GRANT ALL ON TABLE public.device_risk_allowlist TO service_role;


-- ---------------------------------------------------------------------------
-- 6. Hardening found on the way in (decision 5).
--
-- `security_logs` is about to become the table that answers "why was I
-- blocked?". It shipped with the default `GRANT ALL` to anon + authenticated
-- and RLS with no policies. PostgREST cannot reach TRUNCATE, so this was
-- latent rather than live — but "latent" is not a property of the grant, it is
-- a property of today's routing, and this table is now load-bearing.
-- ---------------------------------------------------------------------------
REVOKE ALL ON TABLE public.security_logs FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.security_logs TO service_role;


-- ---------------------------------------------------------------------------
-- 7. Keep the thresholds out of the client's hands (decision 6).
--
-- RESTRICTIVE policies AND with the permissive ones, so this subtracts from
-- `Allow authenticated users to read config` without editing it. service_role
-- bypasses RLS entirely and is unaffected.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "Hide device risk thresholds from clients" ON public.system_configs;
CREATE POLICY "Hide device risk thresholds from clients"
  ON public.system_configs
  AS RESTRICTIVE
  FOR SELECT
  TO anon, authenticated
  USING (config_key NOT LIKE 'DEVICE\_RISK\_%');


-- ---------------------------------------------------------------------------
-- 8. Thresholds and brakes.
--
-- Every number below is a guess: no device id has ever been bound to a payment
-- in this database, `payment_methods` holds 2 rows and `paypal_orders` 28, so
-- there is no distribution to calibrate against. They are chosen to be
-- generous enough that no honest user meets one by accident — a shared family
-- tablet with three accounts, or a user who deposits four times in a day,
-- passes everything here — and they live in config precisely so the owner can
-- argue with them without a deploy. See § 6 of the report for the reasoning
-- per key.
--
-- DEVICE_RISK_ENABLED  = scoring and logging.       Default ON  (observe).
-- DEVICE_RISK_ENFORCE  = actually refusing money.   Default OFF (do no harm).
-- ---------------------------------------------------------------------------
INSERT INTO public.system_configs (config_key, config_value) VALUES
  ('DEVICE_RISK_ENABLED',              'true'),
  ('DEVICE_RISK_ENFORCE',              'false'),
  ('DEVICE_RISK_WINDOW_HOURS',         '24'),
  ('DEVICE_RISK_MAX_ACCOUNTS',         '4'),
  ('DEVICE_RISK_MAX_CARDS',            '3'),
  ('DEVICE_RISK_MAX_DEPOSITS',         '8'),
  ('DEVICE_RISK_MAX_DEPOSIT_USD',      '600.00'),
  ('DEVICE_RISK_MAX_FAILED_CAPTURES',  '4'),
  ('DEVICE_RISK_NEW_DEVICE_HOURS',     '24'),
  ('DEVICE_RISK_NEW_DEVICE_MAX_USD',   '150.00'),
  ('DEVICE_RISK_CHALLENGE_SCORE',      '40'),
  ('DEVICE_RISK_DENY_SCORE',           '80'),
  ('DEVICE_RISK_MISSING_DEVICE_SCORE', '25'),
  ('DEVICE_RISK_MAX_DEVICES_PER_USER', '10'),
  ('RATE_LIMIT_DEVICE_TOUCH',          '30/60')
ON CONFLICT (config_key) DO NOTHING;


-- ---------------------------------------------------------------------------
-- 9. The one client write path.
--
-- Called at sign-in and on resume. Records that this install belongs to this
-- account, and nothing else: no IMEI, no advertising id, no location. A random
-- id plus platform plus app version is the whole payload, which is what keeps
-- doc/PLAY_DATA_SAFETY.md and the Apple privacy label unchanged.
--
-- Bounded two ways, because it is an authenticated client write:
--   * `consume_rate_limit` (not enforce_rate_limit — see the swallowing trap in
--     § 5.2 of the brief; also this must never raise on a non-money path and
--     break sign-in), and
--   * DEVICE_RISK_MAX_DEVICES_PER_USER, so rotating the local id in a loop
--     cannot grow the table without bound. The cap deliberately does NOT apply
--     to the money path in g10b: there we always want the row.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.touch_user_device(
  p_device_id   text,
  p_platform    text DEFAULT NULL,
  p_app_version text DEFAULT NULL
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id   uuid := auth.uid();
  v_device    text;
  v_platform  text;
  v_version   text;
  v_allowed   boolean;
  v_cap       int := 10;
  v_existing  boolean;
  v_count     int;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN NULL;
  END IF;

  v_device := public.normalize_device_id(p_device_id);
  IF v_device IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT allowed INTO v_allowed
  FROM public.consume_rate_limit('device_touch', v_user_id::text, 30, 0.5, clock_timestamp());
  IF v_allowed IS NOT NULL AND v_allowed = false THEN
    RETURN v_device;
  END IF;

  v_platform := lower(btrim(coalesce(p_platform, '')));
  IF v_platform NOT IN ('android', 'ios', 'web', 'macos', 'windows', 'linux', 'fuchsia') THEN
    v_platform := NULL;
  END IF;
  v_version := NULLIF(left(btrim(coalesce(p_app_version, '')), 32), '');

  SELECT true INTO v_existing
  FROM public.user_devices
  WHERE user_id = v_user_id AND device_id = v_device;

  IF NOT coalesce(v_existing, false) THEN
    BEGIN
      SELECT config_value::int INTO v_cap
      FROM public.system_configs WHERE config_key = 'DEVICE_RISK_MAX_DEVICES_PER_USER';
    EXCEPTION WHEN OTHERS THEN v_cap := 10; END;
    IF v_cap IS NULL OR v_cap < 1 THEN v_cap := 10; END IF;

    SELECT count(*) INTO v_count
    FROM public.user_devices WHERE user_id = v_user_id;

    IF v_count >= v_cap THEN
      INSERT INTO public.security_logs (user_id, event_type, description, metadata)
      VALUES (v_user_id, 'device_registry_cap_reached',
              'Account already has the maximum number of registered devices; a new device id was not recorded',
              jsonb_build_object('registered', v_count, 'cap', v_cap));
      RETURN v_device;
    END IF;
  END IF;

  INSERT INTO public.user_devices AS ud (user_id, device_id, platform, app_version)
  VALUES (v_user_id, v_device, v_platform, v_version)
  ON CONFLICT (user_id, device_id) DO UPDATE
    SET last_seen_at = now(),
        platform     = COALESCE(EXCLUDED.platform,     ud.platform),
        app_version  = COALESCE(EXCLUDED.app_version,  ud.app_version),
        revoked_at   = NULL;

  RETURN v_device;
END;
$function$;

REVOKE ALL     ON FUNCTION public.touch_user_device(text, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.touch_user_device(text, text, text) TO authenticated, service_role;

COMMENT ON FUNCTION public.touch_user_device(text, text, text) IS
  'G10: records this app install against the calling account. Returns the '
  'normalised device id, or NULL if the claim was unusable. Never raises — it '
  'runs on the sign-in path.';


-- ---------------------------------------------------------------------------
-- 10. The user's own view of their devices, and how they cut one off.
--
-- SECURITY DEFINER, no user-id argument, curated columns. `device_id` is
-- returned in full only for the caller's own rows, which is information the
-- caller's own device already has.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.my_devices()
RETURNS TABLE (
  device_id     text,
  is_current    boolean,
  label         text,
  platform      text,
  app_version   text,
  trust_state   text,
  first_seen_at timestamptz,
  last_seen_at  timestamptz,
  attested_at   timestamptz,
  revoked_at    timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
  SELECT ud.device_id,
         false AS is_current,       -- only the client knows which id is itself
         ud.label,
         ud.platform,
         ud.app_version,
         ud.trust_state,
         ud.first_seen_at,
         ud.last_seen_at,
         ud.attested_at,
         ud.revoked_at
  FROM public.user_devices ud
  WHERE ud.user_id = auth.uid()
  ORDER BY ud.revoked_at IS NOT NULL, ud.last_seen_at DESC;
$$;

REVOKE ALL     ON FUNCTION public.my_devices() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.my_devices() TO authenticated, service_role;


-- Cutting a device off. Clears the push address as well, so "sign out this
-- device" actually stops notifications reaching it rather than only relabelling
-- a row. Does not delete: the registry must keep remembering.
CREATE OR REPLACE FUNCTION public.revoke_my_device(p_device_id text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_device  text;
  v_hit     int;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN false;
  END IF;

  v_device := public.normalize_device_id(p_device_id);
  IF v_device IS NULL THEN
    RETURN false;
  END IF;

  UPDATE public.user_devices
     SET revoked_at = now()
   WHERE user_id = v_user_id AND device_id = v_device AND revoked_at IS NULL;
  GET DIAGNOSTICS v_hit = ROW_COUNT;

  IF v_hit = 0 THEN
    RETURN false;
  END IF;

  UPDATE public.device_push_tokens
     SET onesignal_player_id = NULL,
         fcm_token           = NULL,
         updated_at          = now()
   WHERE user_id = v_user_id AND device_id = v_device;

  INSERT INTO public.security_logs (user_id, event_type, description, metadata)
  VALUES (v_user_id, 'device_revoked_by_user',
          'User revoked one of their registered devices',
          jsonb_build_object('device_id', v_device));

  RETURN true;
END;
$function$;

REVOKE ALL     ON FUNCTION public.revoke_my_device(text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.revoke_my_device(text) TO authenticated, service_role;


-- Rename a device so the list in settings is readable ("Pixel at work").
CREATE OR REPLACE FUNCTION public.label_my_device(p_device_id text, p_label text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_device  text;
  v_label   text;
  v_hit     int;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN false;
  END IF;

  v_device := public.normalize_device_id(p_device_id);
  IF v_device IS NULL THEN
    RETURN false;
  END IF;

  v_label := NULLIF(left(btrim(coalesce(p_label, '')), 60), '');

  UPDATE public.user_devices
     SET label = v_label
   WHERE user_id = v_user_id AND device_id = v_device;
  GET DIAGNOSTICS v_hit = ROW_COUNT;

  RETURN v_hit > 0;
END;
$function$;

REVOKE ALL     ON FUNCTION public.label_my_device(text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.label_my_device(text, text) TO authenticated, service_role;
