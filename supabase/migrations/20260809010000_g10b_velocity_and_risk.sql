-- ============================================================================
-- G10b — Device binding + velocity anti-fraud, part 2: the counters and the
--        decision.
--
-- g10 built the places facts live. This computes the signals and turns them
-- into one of three answers. It still blocks nothing: `guard_money_action()`
-- returns a decision and honours `DEVICE_RISK_ENFORCE`, which ships **false**.
-- g10c is what calls it from the money paths.
--
-- ── The signals, and why each one is the shape it is ───────────────────────
--
--   accounts_on_device   count(DISTINCT user_id) in `user_devices` for this
--                        device id. **Lifetime, not windowed** — an attacker
--                        who opens one account a week is doing the same thing
--                        more slowly, and a 24h window would miss it entirely.
--
--   cards_on_device      DISTINCT payment instruments across every account on
--                        this device, fingerprinted as the provider token when
--                        there is one and `provider|last4|exp` otherwise.
--                        Also lifetime: card testing is not a burst.
--
--   deposit_orders       `deposit_order` events for this device inside the
--                        window. Attempts, not captures — card testing is
--                        visible in attempts and invisible in captures, and at
--                        order-creation time a capture has not happened yet.
--
--   deposit_usd          Sum of those attempts.
--
--   failed_captures      GREATEST of two counts: PayPal orders that failed and
--                        are linked to this device through
--                        `device_money_events.reference_id`, and PayPal orders
--                        that failed for any account registered on this device.
--                        The second exists because the first can only see
--                        orders created after G10 — every one of the 28
--                        `paypal_orders` rows that predates this migration has
--                        no device. A device inherits the failure history of
--                        the accounts on it, which is the property being
--                        abused.
--
--   new_device           `first_seen_at` inside DEVICE_RISK_NEW_DEVICE_HOURS.
--                        Combined with an amount over
--                        DEVICE_RISK_NEW_DEVICE_MAX_USD this *scores*, and
--                        deliberately does not deny on its own: treating an
--                        unknown device as guilty would block the first
--                        legitimate deposit of every new customer, and treating
--                        it as clean is the classic hole — a rotated device id
--                        must not be cheaper than a reused one.
--
--   missing device id    Scores DEVICE_RISK_MISSING_DEVICE_SCORE. An old build
--                        sends none, so this must not be fatal; a script also
--                        sends none, so it must not be free.
--
-- ── Decisions worth not re-deriving ────────────────────────────────────────
--
-- 1. THE SCORE ESCALATES WITH DISTANCE OVER THE LINE, not with the number of
--    lines crossed. One over the account cap is 40 (challenge), three over is
--    80 (deny). A single breach can never deny on its own unless it is far
--    over, so the first honest edge case gets flagged, not refused.
--
-- 2. `trust_state` SHORT-CIRCUITS IN BOTH DIRECTIONS, and so does the
--    allowlist. `trusted` returns allow with score 0 before any counting;
--    `blocked` adds 100, which is above any deny threshold the config can
--    hold. Support needs one UPDATE to fix a false positive at 3am and one to
--    stop a confirmed mule, and neither should require understanding the model.
--
-- 3. THE DECISION IS RECORDED EVEN WHEN IT IS NOT ENFORCED.
--    `device_money_events.assessed_decision` is what the model said,
--    `enforced` is whether it actually blocked. With DEVICE_RISK_ENFORCE off,
--    every deny is a shadow deny — that column difference is the only honest
--    way to measure the false-positive rate before switching it on.
--
-- 4. `security_logs` VOCABULARY, stable, one row per non-clean assessment:
--       device_risk_flag        thresholds breached, still allowed
--       device_risk_challenge   score >= DEVICE_RISK_CHALLENGE_SCORE
--       device_risk_deny        score >= DEVICE_RISK_DENY_SCORE
--    The individual breach codes live in `metadata.reasons` as a stable array:
--       accounts_on_device, cards_on_device, deposit_count, deposit_total,
--       failed_captures, new_device_high_value, missing_device_id,
--       device_blocked.
--    One row per assessment rather than one per breach, so the support answer
--    to "why was I blocked?" is a single row. Volume is bounded by the
--    per-user rate limits already on every money RPC.
--
-- 5. NOTHING HERE RAISES. `guard_money_action` returns jsonb and lets the
--    caller decide how to refuse, because the four money RPCs have three
--    different refusal contracts between them (`request_instant_refill`
--    raises, the other three return `{success:false,…}`) and g10c must not
--    change any of them. It also means no exception of mine can be swallowed by
--    `enforce_rate_limit`'s `WHEN OTHERS THEN RAISE NOTICE`, which is the trap
--    G6 and G9 both had to route around.
--
-- 6. `revoked_at` IS NOT A CONTROL. Both `touch_user_device` and the touch
--    inside `guard_money_action` clear it, because signing back in on a device
--    you signed out of is normal. It is a UX affordance for the settings list,
--    not a fraud signal — do not start scoring it without also deciding what
--    a re-sign-in means.
-- ============================================================================


-- ---------------------------------------------------------------------------
-- 1. Config in one read.
--
-- Twelve separate SELECTs on a money path is twelve chances to disagree with
-- itself mid-transaction. One jsonb, with the defaults baked in so a deleted
-- config row degrades to the shipped behaviour instead of to NULL arithmetic.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.device_risk_config()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
  SELECT jsonb_build_object(
           'enabled',              'true',
           'enforce',              'false',
           'window_hours',         '24',
           'max_accounts',         '4',
           'max_cards',            '3',
           'max_deposits',         '8',
           'max_deposit_usd',      '600.00',
           'max_failed_captures',  '4',
           'new_device_hours',     '24',
           'new_device_max_usd',   '150.00',
           'challenge_score',      '40',
           'deny_score',           '80',
           'missing_device_score', '25'
         )
         || COALESCE(
              (SELECT jsonb_object_agg(lower(substring(sc.config_key from 13)), sc.config_value)
                 FROM public.system_configs sc
                WHERE sc.config_key LIKE 'DEVICE\_RISK\_%'
                  AND sc.config_key <> 'DEVICE_RISK_MAX_DEVICES_PER_USER'),
              '{}'::jsonb);
$$;

REVOKE ALL     ON FUNCTION public.device_risk_config() FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.device_risk_config() TO service_role;

COMMENT ON FUNCTION public.device_risk_config() IS
  'G10b: the DEVICE_RISK_* thresholds as one jsonb, keys stripped of the prefix '
  'and lowercased, shipped defaults merged underneath. service_role only — the '
  'thresholds are hidden from clients by a RESTRICTIVE policy on system_configs.';


-- ---------------------------------------------------------------------------
-- 2. The counters.
--
-- Read-only and safe to call by hand: this is the function an owner runs to
-- ask "what does the model see for this device?".
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.device_velocity(
  p_device_id    text,
  p_window_hours numeric DEFAULT 24
)
RETURNS TABLE (
  device_id              text,
  accounts_on_device     integer,
  cards_on_device        integer,
  deposit_orders         integer,
  deposit_usd            numeric,
  failed_captures        integer,
  failed_captures_device integer,
  failed_captures_users  integer,
  first_seen_at          timestamptz,
  worst_trust_state      text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_device text := public.normalize_device_id(p_device_id);
  -- `interval * float8` rather than make_interval(mins => …): make_interval's
  -- mins argument is an int, and numeric → int is not an implicit cast, so the
  -- obvious spelling fails to resolve at all.
  v_since  timestamptz := now()
                          - (GREATEST(COALESCE(p_window_hours, 24), 0.05)::double precision
                             * interval '1 hour');
BEGIN
  IF v_device IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH accounts AS (
    SELECT ud.user_id, ud.first_seen_at, ud.trust_state
      FROM public.user_devices ud
     WHERE ud.device_id = v_device
  ),
  instruments AS (
    SELECT DISTINCT COALESCE(
             NULLIF(btrim(pm.token), ''),
             COALESCE(pm.provider, '?') || '|' || COALESCE(pm.last_four, '') || '|'
               || COALESCE(pm.expiry_month::text, '') || '|' || COALESCE(pm.expiry_year::text, '')
           ) AS fingerprint
      FROM public.payment_methods pm
      JOIN accounts a ON a.user_id = pm.user_id
  ),
  dep AS (
    SELECT count(*)::int AS n, COALESCE(sum(e.amount_usd), 0)::numeric AS usd
      FROM public.device_money_events e
     WHERE e.device_id = v_device
       AND e.action = 'deposit_order'
       AND e.created_at >= v_since
  ),
  fail_dev AS (
    SELECT count(DISTINCT po.order_id)::int AS n
      FROM public.device_money_events e
      JOIN public.paypal_orders po ON po.order_id = e.reference_id
     WHERE e.device_id = v_device
       AND e.action = 'deposit_order'
       AND po.status = 'failed'
       AND po.created_at >= v_since
  ),
  fail_usr AS (
    SELECT count(*)::int AS n
      FROM public.paypal_orders po
     WHERE po.user_id IN (SELECT user_id FROM accounts)
       AND po.status = 'failed'
       AND po.created_at >= v_since
  )
  SELECT v_device,
         (SELECT count(*)::int FROM accounts),
         (SELECT count(*)::int FROM instruments),
         dep.n,
         dep.usd,
         GREATEST(fail_dev.n, fail_usr.n),
         fail_dev.n,
         fail_usr.n,
         (SELECT min(a.first_seen_at) FROM accounts a),
         (SELECT CASE
                   WHEN bool_or(a.trust_state = 'blocked') THEN 'blocked'
                   WHEN bool_and(a.trust_state = 'trusted') THEN 'trusted'
                   ELSE 'unknown'
                 END
            FROM accounts a)
    FROM dep, fail_dev, fail_usr;
END;
$function$;

REVOKE ALL     ON FUNCTION public.device_velocity(text, numeric) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.device_velocity(text, numeric) TO service_role;

COMMENT ON FUNCTION public.device_velocity(text, numeric) IS
  'G10b: what the risk model sees for one device id. accounts/cards are lifetime, '
  'deposits are windowed, failed captures are the greater of the device-linked and '
  'the accounts-on-device counts. Returns no rows for an unusable device id.';


-- ---------------------------------------------------------------------------
-- 3. The decision.
--
-- `worst_trust_state` is computed across every account on the device, not just
-- the caller's row: a mule who blocks nothing on their own account but shares a
-- handset with a blocked one is the case this exists for.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.assess_device_risk(
  p_user_id    uuid,
  p_device_id  text,
  p_action     text,
  p_amount_usd numeric DEFAULT NULL
)
RETURNS TABLE (
  decision text,
  reason   text,
  score    integer,
  detail   jsonb
)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_cfg        jsonb := public.device_risk_config();
  v_device     text  := public.normalize_device_id(p_device_id);
  v_amount     numeric := COALESCE(p_amount_usd, 0);
  v_score      int := 0;
  v_reasons    text[] := ARRAY[]::text[];
  v_decision   text := 'allow';
  v_v          RECORD;
  v_over       int;
  v_challenge  int := COALESCE((v_cfg ->> 'challenge_score')::int, 40);
  v_deny       int := COALESCE((v_cfg ->> 'deny_score')::int, 80);
  v_window     numeric := COALESCE((v_cfg ->> 'window_hours')::numeric, 24);
  v_detail     jsonb;
  v_event_type text;
BEGIN
  -- The global brake. Off means the model does not run at all, not that it runs
  -- and is ignored — an owner who sets this expects zero new behaviour.
  IF COALESCE(v_cfg ->> 'enabled', 'true') <> 'true' THEN
    RETURN QUERY SELECT 'allow'::text, 'risk_disabled'::text, 0, jsonb_build_object('enabled', false);
    RETURN;
  END IF;

  -- The escape hatch, checked before anything is counted.
  IF EXISTS (SELECT 1 FROM public.device_risk_allowlist al
              WHERE al.user_id = p_user_id
                AND (al.expires_at IS NULL OR al.expires_at > clock_timestamp())) THEN
    RETURN QUERY SELECT 'allow'::text, 'allowlisted'::text, 0, jsonb_build_object('allowlisted', true);
    RETURN;
  END IF;

  IF v_device IS NULL THEN
    v_score   := COALESCE((v_cfg ->> 'missing_device_score')::int, 25);
    v_reasons := ARRAY['missing_device_id'];
    v_detail  := jsonb_build_object('device_id', NULL, 'action', p_action, 'amount_usd', v_amount);
  ELSE
    SELECT * INTO v_v FROM public.device_velocity(v_device, v_window);

    IF NOT FOUND THEN
      -- Normalised fine but has no registry row at all. Treated as brand new.
      v_detail := jsonb_build_object('device_id', v_device, 'action', p_action,
                                     'amount_usd', v_amount, 'unregistered', true);
      IF v_amount > COALESCE((v_cfg ->> 'new_device_max_usd')::numeric, 150) THEN
        v_score   := v_score + 25;
        v_reasons := v_reasons || 'new_device_high_value'::text;
      END IF;
    ELSE
      IF v_v.worst_trust_state = 'trusted' THEN
        RETURN QUERY SELECT 'allow'::text, 'device_trusted'::text, 0,
                            jsonb_build_object('device_id', v_device, 'trust_state', 'trusted');
        RETURN;
      END IF;

      IF v_v.worst_trust_state = 'blocked' THEN
        v_score   := v_score + 100;
        v_reasons := v_reasons || 'device_blocked'::text;
      END IF;

      -- Accounts sharing this handset.
      v_over := v_v.accounts_on_device - COALESCE((v_cfg ->> 'max_accounts')::int, 4);
      IF v_over > 0 THEN
        v_score   := v_score + 40 + LEAST(v_over - 1, 3) * 20;
        v_reasons := v_reasons || 'accounts_on_device'::text;
      END IF;

      -- Payment instruments across those accounts.
      v_over := v_v.cards_on_device - COALESCE((v_cfg ->> 'max_cards')::int, 3);
      IF v_over > 0 THEN
        v_score   := v_score + 40 + LEAST(v_over - 1, 3) * 20;
        v_reasons := v_reasons || 'cards_on_device'::text;
      END IF;

      -- Deposit attempts in the window.
      v_over := v_v.deposit_orders - COALESCE((v_cfg ->> 'max_deposits')::int, 8);
      IF v_over > 0 THEN
        v_score   := v_score + 30 + LEAST(v_over - 1, 3) * 15;
        v_reasons := v_reasons || 'deposit_count'::text;
      END IF;

      -- Deposit value in the window, including the attempt being assessed.
      IF (v_v.deposit_usd + CASE WHEN p_action = 'deposit_order' THEN v_amount ELSE 0 END)
         > COALESCE((v_cfg ->> 'max_deposit_usd')::numeric, 600) THEN
        v_score   := v_score + 30;
        IF (v_v.deposit_usd + CASE WHEN p_action = 'deposit_order' THEN v_amount ELSE 0 END)
           > 2 * COALESCE((v_cfg ->> 'max_deposit_usd')::numeric, 600) THEN
          v_score := v_score + 30;
        END IF;
        v_reasons := v_reasons || 'deposit_total'::text;
      END IF;

      -- Failed captures — card testing's most direct fingerprint.
      v_over := v_v.failed_captures - COALESCE((v_cfg ->> 'max_failed_captures')::int, 4);
      IF v_over > 0 THEN
        v_score   := v_score + 35 + LEAST(v_over - 1, 3) * 15;
        v_reasons := v_reasons || 'failed_captures'::text;
      END IF;

      -- A device nobody has seen before, moving real money.
      IF v_v.first_seen_at > clock_timestamp()
                             - make_interval(hours => COALESCE((v_cfg ->> 'new_device_hours')::int, 24))
         AND v_amount > COALESCE((v_cfg ->> 'new_device_max_usd')::numeric, 150) THEN
        v_score   := v_score + 25;
        v_reasons := v_reasons || 'new_device_high_value'::text;
      END IF;

      v_detail := jsonb_build_object(
        'device_id',          v_device,
        'action',             p_action,
        'amount_usd',         v_amount,
        'window_hours',       v_window,
        'accounts_on_device', v_v.accounts_on_device,
        'cards_on_device',    v_v.cards_on_device,
        'deposit_orders',     v_v.deposit_orders,
        'deposit_usd',        v_v.deposit_usd,
        'failed_captures',    v_v.failed_captures,
        'trust_state',        v_v.worst_trust_state,
        'device_first_seen',  v_v.first_seen_at);
    END IF;
  END IF;

  IF v_score >= v_deny THEN
    v_decision := 'deny';
  ELSIF v_score >= v_challenge THEN
    v_decision := 'challenge';
  END IF;

  IF array_length(v_reasons, 1) IS NOT NULL THEN
    v_event_type := CASE v_decision
                      WHEN 'deny'      THEN 'device_risk_deny'
                      WHEN 'challenge' THEN 'device_risk_challenge'
                      ELSE                  'device_risk_flag'
                    END;

    INSERT INTO public.security_logs (user_id, event_type, description, metadata)
    VALUES (p_user_id, v_event_type,
            'Device risk ' || v_decision || ' (' || array_to_string(v_reasons, ', ')
              || ') on ' || COALESCE(p_action, '?'),
            v_detail || jsonb_build_object('reasons', to_jsonb(v_reasons), 'score', v_score));
  END IF;

  RETURN QUERY SELECT v_decision,
                      CASE WHEN array_length(v_reasons, 1) IS NULL
                           THEN 'clean'
                           ELSE array_to_string(v_reasons, ',') END,
                      v_score,
                      v_detail;
END;
$function$;

REVOKE ALL     ON FUNCTION public.assess_device_risk(uuid, text, text, numeric) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.assess_device_risk(uuid, text, text, numeric) TO service_role;

COMMENT ON FUNCTION public.assess_device_risk(uuid, text, text, numeric) IS
  'G10b: (allow|challenge|deny, reason, score, detail) for one money attempt. '
  'Writes one security_logs row per non-clean assessment. Does not raise and does '
  'not block — see guard_money_action().';


-- ---------------------------------------------------------------------------
-- 4. The single entry point the money paths use.
--
-- Touches the device, assesses, records the attempt, returns what to do. The
-- touch here deliberately ignores DEVICE_RISK_MAX_DEVICES_PER_USER: on a money
-- path we always want the row, because a device that spends money and is not in
-- the registry is invisible to every count above.
--
-- `p_user_id` defaults to auth.uid() so the four authenticated RPCs can call it
-- with three arguments, while the Edge Functions (service_role, no auth.uid())
-- pass the user explicitly. This function is service_role-only, so the explicit
-- user id is not a client-reachable impersonation surface — the SECURITY DEFINER
-- callers supply it themselves.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.guard_money_action(
  p_action       text,
  p_amount_usd   numeric DEFAULT NULL,
  p_device_id    text    DEFAULT NULL,
  p_reference_id text    DEFAULT NULL,
  p_user_id      uuid    DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user     uuid := COALESCE(p_user_id, auth.uid());
  v_device   text := public.normalize_device_id(p_device_id);
  v_cfg      jsonb := public.device_risk_config();
  v_enforce  boolean := COALESCE(v_cfg ->> 'enforce', 'false') = 'true';
  v_a        RECORD;
  v_event_id uuid;
  v_blocked  boolean;
BEGIN
  IF v_user IS NULL THEN
    -- No account to attribute anything to. The caller's own auth check owns
    -- this case; do not invent a decision for it.
    RETURN jsonb_build_object('decision', 'allow', 'reason', 'no_user',
                              'score', 0, 'enforced', false, 'blocked', false);
  END IF;

  IF v_device IS NOT NULL THEN
    INSERT INTO public.user_devices AS ud (user_id, device_id)
    VALUES (v_user, v_device)
    ON CONFLICT (user_id, device_id) DO UPDATE
      SET last_seen_at = now(),
          revoked_at   = NULL;
  END IF;

  SELECT * INTO v_a
  FROM public.assess_device_risk(v_user, v_device, p_action, p_amount_usd);

  v_blocked := v_enforce AND v_a.decision = 'deny';

  INSERT INTO public.device_money_events (
    user_id, device_id, action, amount_usd,
    assessed_decision, enforced, reason, score, reference_id, detail
  ) VALUES (
    v_user, v_device, p_action, p_amount_usd,
    v_a.decision, v_blocked, v_a.reason, v_a.score, p_reference_id, v_a.detail
  ) RETURNING id INTO v_event_id;

  RETURN jsonb_build_object(
    'decision', v_a.decision,
    'reason',   v_a.reason,
    'score',    v_a.score,
    'enforced', v_enforce,
    'blocked',  v_blocked,
    'event_id', v_event_id,
    'detail',   v_a.detail);
END;
$function$;

REVOKE ALL     ON FUNCTION public.guard_money_action(text, numeric, text, text, uuid) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.guard_money_action(text, numeric, text, text, uuid) TO service_role;

COMMENT ON FUNCTION public.guard_money_action(text, numeric, text, text, uuid) IS
  'G10b: the one call a money path makes. Records the device, assesses risk, logs '
  'the attempt, and returns {decision, reason, score, enforced, blocked, event_id}. '
  '`blocked` is the only field a caller needs to refuse on; it is false unless '
  'DEVICE_RISK_ENFORCE is true.';


-- ---------------------------------------------------------------------------
-- 5. Attaching a reference after the fact.
--
-- `create-paypal-order` has to assess *before* it asks PayPal for an order id,
-- so the event is written without one and the id is stitched on afterwards.
-- Write-once: the reference can be set, never changed, which keeps
-- `device_money_events` append-only in every way that matters.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.attach_device_money_reference(
  p_event_id     uuid,
  p_reference_id text
)
RETURNS boolean
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_hit int;
BEGIN
  IF p_event_id IS NULL OR NULLIF(btrim(COALESCE(p_reference_id, '')), '') IS NULL THEN
    RETURN false;
  END IF;

  UPDATE public.device_money_events
     SET reference_id = left(btrim(p_reference_id), 200)
   WHERE id = p_event_id AND reference_id IS NULL;
  GET DIAGNOSTICS v_hit = ROW_COUNT;

  RETURN v_hit > 0;
END;
$function$;

REVOKE ALL     ON FUNCTION public.attach_device_money_reference(uuid, text) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.attach_device_money_reference(uuid, text) TO service_role;


-- ---------------------------------------------------------------------------
-- 6. What the owner looks at.
--
-- The question after a week of observation is "would this have blocked anyone,
-- and who?". One function, no arguments, so it is one line in the SQL editor.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.device_risk_shadow_report(p_days integer DEFAULT 7)
RETURNS TABLE (
  assessed_decision text,
  enforced          boolean,
  action            text,
  events            bigint,
  distinct_users    bigint,
  distinct_devices  bigint,
  usd               numeric,
  top_reason        text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
  SELECT e.assessed_decision,
         e.enforced,
         e.action,
         count(*)                        AS events,
         count(DISTINCT e.user_id)       AS distinct_users,
         count(DISTINCT e.device_id)     AS distinct_devices,
         COALESCE(sum(e.amount_usd), 0)  AS usd,
         mode() WITHIN GROUP (ORDER BY e.reason) AS top_reason
    FROM public.device_money_events e
   WHERE e.created_at >= now() - make_interval(days => GREATEST(COALESCE(p_days, 7), 1))
   GROUP BY 1, 2, 3
   ORDER BY 1, 3;
$$;

REVOKE ALL     ON FUNCTION public.device_risk_shadow_report(integer) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.device_risk_shadow_report(integer) TO service_role;

COMMENT ON FUNCTION public.device_risk_shadow_report(integer) IS
  'G10b: rows where assessed_decision = deny and enforced = false are the shadow '
  'denials — the false-positive budget the owner is spending before turning '
  'DEVICE_RISK_ENFORCE on.';
