-- L3 — the operations half: the nightly sweep that keeps stock honest and
-- opens the fulfilment queue, plus the `admin_*` control plane behind the
-- Vouchers screen in keep_sims_admin.
--
-- Phase H convention throughout: every mutation is a SECURITY DEFINER RPC that
-- calls assert_admin(), validates, and writes an admin_audit_log row. No RLS
-- policy is added to any table — the voucher tables stay deny-all and the
-- admin app reaches them only here.
--
-- ── WHY A SWEEP AND NOT ONLY A TRIGGER ────────────────────────────────────
-- The whole feature depends on the PIN being on the handset BEFORE it loses
-- connectivity. Nothing about a subscriber's behaviour guarantees they open the
-- offline screen while they still have signal, so "provision lazily when they
-- ask" would deliver an empty pocket to exactly the person the feature is for.
-- The sweep is what notices "this line is entitled, has no voucher, and there
-- is nothing to give it" a week before it matters, and it is what turns that
-- into an operator task with a deadline.
--
-- It is also deliberately NOT a trigger on the money path. A trigger on
-- sim_lines or plan_payments that raises takes the plan purchase down with it —
-- J8 spent a session on precisely that failure, where an exception between the
-- debit and the insert produced a charged customer with no line.

BEGIN;

-- ───────────────────────────────────────────────────────────────────────────
-- 1. The sweep
-- ───────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.sweep_offline_voucher_requests(p_dry_run boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
  v_enabled       boolean;
  v_expired_stock integer := 0;
  v_expired_grant integer := 0;
  v_opened        integer := 0;
  v_nudged        integer := 0;
  v_row           RECORD;
  v_sla           integer;
BEGIN
  SELECT COALESCE(NULLIF(config_value, ''), 'false')::boolean INTO v_enabled
    FROM public.system_configs WHERE config_key = 'OFFLINE_VOUCHER_ENABLED';

  SELECT COALESCE(NULLIF(config_value, '')::integer, 7) INTO v_sla
    FROM public.system_configs WHERE config_key = 'OFFLINE_VOUCHER_MANUAL_SLA_DAYS';

  -- A dry run reads only, so it is allowed to run with the feature off: that is
  -- how an operator sees what WOULD happen before flipping the switch. Same
  -- stance as I8's carrier-advice preview.
  IF NOT COALESCE(v_enabled, false) AND NOT p_dry_run THEN
    RETURN jsonb_build_object('success', true, 'skipped', 'OFFLINE_VOUCHER_ENABLED is false');
  END IF;

  -- ── 1a. Retire dead stock ────────────────────────────────────────────────
  -- A voucher whose validity has run out is worse than no voucher: it is dialled
  -- by someone with no signal who then has no way to find out why it failed.
  IF NOT p_dry_run THEN
    WITH dead AS (
      UPDATE public.offline_voucher_stock
         SET status = 'expired', updated_at = now()
       WHERE status IN ('available','issued')
         AND expires_at IS NOT NULL
         AND expires_at <= now()
      RETURNING id
    )
    SELECT count(*) INTO v_expired_stock FROM dead;

    WITH dead AS (
      UPDATE public.offline_voucher_grants g
         SET status = 'expired', updated_at = now()
        FROM public.offline_voucher_stock s
       WHERE s.id = g.stock_id
         AND g.status = 'provisioned'
         AND s.status = 'expired'
      RETURNING g.id
    )
    SELECT count(*) INTO v_expired_grant FROM dead;
  ELSE
    SELECT count(*) INTO v_expired_stock FROM public.offline_voucher_stock
     WHERE status IN ('available','issued') AND expires_at IS NOT NULL AND expires_at <= now();
    SELECT count(*) INTO v_expired_grant FROM public.offline_voucher_grants g
      JOIN public.offline_voucher_stock s ON s.id = g.stock_id
     WHERE g.status = 'provisioned' AND s.expires_at IS NOT NULL AND s.expires_at <= now();
  END IF;

  -- ── 1b. Every entitled line that is not covered ──────────────────────────
  FOR v_row IN
    SELECT sl.id AS sim_line_id, sl.user_id, sl.carrier_id, sl.phone_number,
           EXISTS (
             SELECT 1 FROM public.offline_voucher_stock st
              WHERE st.carrier_id = sl.carrier_id
                AND st.status = 'available'
                AND (st.expires_at IS NULL OR st.expires_at > now() + interval '7 days')
           ) AS has_stock
      FROM public.sim_lines sl
     WHERE sl.carrier_id IS NOT NULL
       AND public.has_paid_premium_entitlement(sl.id)
       AND NOT EXISTS (
         SELECT 1 FROM public.offline_voucher_grants g
          WHERE g.sim_line_id = sl.id AND g.status IN ('provisioned','revealed')
       )
  LOOP
    IF v_row.has_stock THEN
      -- Stock exists but the handset has not collected it. Nudge them ONCE a
      -- week: the collection only works while they are online, and there is no
      -- way to push a PIN to a device that is already offline.
      IF NOT p_dry_run AND NOT EXISTS (
        SELECT 1 FROM public.notifications n
         WHERE n.user_id = v_row.user_id
           AND n.sim_line_id = v_row.sim_line_id
           AND n.category = 'system'
           AND n.title = 'Emergency top-up PIN ready'
           AND n.created_at > now() - interval '7 days'
      ) THEN
        INSERT INTO public.notifications (user_id, category, title, body, sim_line_id, action_url)
        VALUES (v_row.user_id, 'system', 'Emergency top-up PIN ready',
                'Open KeepSIMs while you have signal to store an emergency recharge PIN for '
                  || v_row.phone_number || '. It works with no data and no credit.',
                v_row.sim_line_id, '/settings/offline-recharge');
      END IF;
      v_nudged := v_nudged + 1;
    ELSE
      IF NOT p_dry_run THEN
        PERFORM public.open_offline_voucher_request(
          v_row.user_id, v_row.sim_line_id, v_row.carrier_id,
          CASE WHEN public.offline_voucher_source_for_carrier(v_row.carrier_id) = 'ding'
               THEN 'no_stock' ELSE 'no_automatic_source' END);
      END IF;
      v_opened := v_opened + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'dry_run', p_dry_run,
    'stock_expired', v_expired_stock,
    'grants_expired', v_expired_grant,
    'requests_open_needed', v_opened,
    'lines_nudged', v_nudged,
    'sla_days', v_sla
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.sweep_offline_voucher_requests(boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.sweep_offline_voucher_requests(boolean) TO service_role;

-- ───────────────────────────────────────────────────────────────────────────
-- 2. Admin: overview
-- ───────────────────────────────────────────────────────────────────────────
-- One row per carrier that has EITHER stock or premium demand, because a
-- carrier with neither is not an operations problem and 67 rows of zeroes hide
-- the three that matter.
CREATE OR REPLACE FUNCTION public.admin_voucher_overview()
RETURNS TABLE (
  carrier_id          uuid,
  carrier_name        text,
  country_name        text,
  source              text,
  available_count     bigint,
  issued_count        bigint,
  outstanding_count   bigint,
  outstanding_usd     numeric,
  premium_lines       bigint,
  open_requests       bigint,
  overdue_requests    bigint,
  is_low_stock        boolean,
  has_redeem_code     boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_low integer := 3;
BEGIN
  PERFORM public.assert_admin();

  SELECT COALESCE(NULLIF(config_value, '')::integer, 3) INTO v_low
    FROM system_configs WHERE config_key = 'OFFLINE_VOUCHER_STOCK_LOW_THRESHOLD';

  RETURN QUERY
  WITH demand AS (
    SELECT sl.carrier_id AS cid, count(*) AS premium_lines
      FROM sim_lines sl
     WHERE sl.carrier_id IS NOT NULL
       AND lower(coalesce(sl.plan_type,'')) = 'premium'
     GROUP BY sl.carrier_id
  ), stock AS (
    SELECT s.carrier_id AS cid,
           count(*) FILTER (WHERE s.status = 'available') AS available_count,
           count(*) FILTER (WHERE s.status = 'issued')    AS issued_count
      FROM offline_voucher_stock s
     GROUP BY s.carrier_id
  ), debt AS (
    SELECT s.carrier_id AS cid,
           count(*) AS outstanding_count,
           COALESCE(sum(g.amount_due_usd), 0) AS outstanding_usd
      FROM offline_voucher_grants g
      JOIN offline_voucher_stock s ON s.id = g.stock_id
     WHERE g.status = 'revealed'
     GROUP BY s.carrier_id
  ), reqs AS (
    SELECT r.carrier_id AS cid,
           count(*) FILTER (WHERE r.status = 'open') AS open_requests,
           count(*) FILTER (WHERE r.status = 'open' AND r.due_at < now()) AS overdue_requests
      FROM offline_voucher_requests r
     GROUP BY r.carrier_id
  )
  SELECT c.id, c.name, co.name,
         public.offline_voucher_source_for_carrier(c.id),
         COALESCE(stock.available_count, 0),
         COALESCE(stock.issued_count, 0),
         COALESCE(debt.outstanding_count, 0),
         COALESCE(debt.outstanding_usd, 0),
         COALESCE(demand.premium_lines, 0),
         COALESCE(reqs.open_requests, 0),
         COALESCE(reqs.overdue_requests, 0),
         -- Low stock only counts where somebody could actually need it. A
         -- carrier with no premium line is not short of anything.
         (COALESCE(demand.premium_lines, 0) > 0
          AND COALESCE(stock.available_count, 0) <= v_low),
         EXISTS (SELECT 1 FROM carrier_voucher_redemption cvr
                  WHERE cvr.carrier_id = c.id AND cvr.verified_at IS NOT NULL)
    FROM carriers c
    JOIN countries co ON co.id = c.country_id
    LEFT JOIN demand ON demand.cid = c.id
    LEFT JOIN stock  ON stock.cid  = c.id
    LEFT JOIN debt   ON debt.cid   = c.id
    LEFT JOIN reqs   ON reqs.cid   = c.id
   WHERE COALESCE(demand.premium_lines, 0) > 0
      OR COALESCE(stock.available_count, 0) > 0
      OR COALESCE(stock.issued_count, 0) > 0
      OR COALESCE(reqs.open_requests, 0) > 0
   ORDER BY COALESCE(reqs.overdue_requests, 0) DESC,
            COALESCE(reqs.open_requests, 0) DESC,
            c.name;
END;
$fn$;

-- ───────────────────────────────────────────────────────────────────────────
-- 3. Admin: stock
-- ───────────────────────────────────────────────────────────────────────────
-- The PIN is NEVER returned. `pin_last4` exists so an operator can match a row
-- against a physical scratch card or a supplier statement; four digits of a
-- 12–16 digit code identify without redeeming. The whole PIN has exactly one
-- exit from this database and it is `provision_offline_voucher`.
CREATE OR REPLACE FUNCTION public.admin_list_voucher_stock(
  p_carrier_id uuid DEFAULT NULL,
  p_status     text DEFAULT NULL,
  p_limit      integer DEFAULT 200
)
RETURNS TABLE (
  id uuid, carrier_id uuid, carrier_name text, source text, status text,
  pin_last4 text, serial text,
  face_value_usd numeric, face_value_native numeric, face_value_currency text,
  cost_usd numeric, expires_at timestamptz, provider_ref text,
  load_note text, void_reason text, created_at timestamptz,
  held_by_user_id uuid, held_by_email text, grant_status text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  PERFORM public.assert_admin();

  RETURN QUERY
  SELECT s.id, s.carrier_id, c.name, s.source, s.status,
         right(public.voucher_decrypt_pin(s.pin_encrypted), 4),
         s.serial,
         s.face_value_usd, s.face_value_native, s.face_value_currency,
         s.cost_usd, s.expires_at, s.provider_ref,
         s.load_note, s.void_reason, s.created_at,
         g.user_id, p.email, g.status
    FROM offline_voucher_stock s
    JOIN carriers c ON c.id = s.carrier_id
    LEFT JOIN offline_voucher_grants g ON g.stock_id = s.id
    LEFT JOIN profiles p ON p.id = g.user_id
   WHERE (p_carrier_id IS NULL OR s.carrier_id = p_carrier_id)
     AND (p_status IS NULL OR s.status = p_status)
   ORDER BY s.created_at DESC
   LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 200), 1000));
END;
$fn$;

-- Bulk load. An operator pastes a column of PINs from a supplier email or a
-- pack of scratch cards; per-PIN overrides are optional and the defaults fill
-- the rest.
--
-- Duplicates are SKIPPED, not refused: a paste that overlaps a previous one by
-- three rows should load the other forty-seven, and the count says so. Two
-- subscribers holding the same PIN is the worst outcome this feature has —
-- the second one dials a spent code with no way to ask why — so the uniqueness
-- is an index, and this only reports what the index rejected.
CREATE OR REPLACE FUNCTION public.admin_add_voucher_stock(
  p_carrier_id uuid,
  p_pins       jsonb,
  p_defaults   jsonb DEFAULT '{}'::jsonb,
  p_note       text  DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_admin     uuid;
  v_allowed   text[] := ARRAY['face_value_usd','face_value_native','face_value_currency',
                              'cost_usd','expires_at','serial','redeem_instructions','source'];
  v_key       text;
  v_item      jsonb;
  v_pin       text;
  v_face      numeric;
  v_expires   timestamptz;
  v_source    text;
  v_validity  integer;
  v_added     integer := 0;
  v_skipped   integer := 0;
  v_errors    text[] := ARRAY[]::text[];
  v_id        uuid;
  v_idx       integer := 0;
BEGIN
  v_admin := public.assert_admin();

  IF NOT EXISTS (SELECT 1 FROM carriers WHERE id = p_carrier_id) THEN
    RAISE EXCEPTION 'Carrier % not found', p_carrier_id USING ERRCODE = 'KS461';
  END IF;

  IF p_pins IS NULL OR jsonb_typeof(p_pins) <> 'array' OR jsonb_array_length(p_pins) = 0 THEN
    RAISE EXCEPTION 'Provide a non-empty array of PINs' USING ERRCODE = 'KS467';
  END IF;

  IF jsonb_array_length(p_pins) > 500 THEN
    RAISE EXCEPTION 'At most 500 PINs per load' USING ERRCODE = 'KS466';
  END IF;

  FOR v_key IN SELECT jsonb_object_keys(COALESCE(p_defaults, '{}'::jsonb)) LOOP
    IF NOT (v_key = ANY(v_allowed)) THEN
      RAISE EXCEPTION 'Unknown default field: %', v_key USING ERRCODE = 'KS467';
    END IF;
  END LOOP;

  v_source := lower(COALESCE(p_defaults ->> 'source', 'manual'));
  IF v_source NOT IN ('manual','ding') THEN
    RAISE EXCEPTION 'source must be manual or ding' USING ERRCODE = 'KS466';
  END IF;

  SELECT COALESCE(NULLIF(config_value, '')::integer, 365) INTO v_validity
    FROM system_configs WHERE config_key = 'OFFLINE_VOUCHER_VALIDITY_DAYS';

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_pins) LOOP
    v_idx := v_idx + 1;

    -- Accept either a bare string ("1234-5678") or an object with overrides.
    IF jsonb_typeof(v_item) = 'string' THEN
      v_pin  := btrim(v_item #>> '{}');
      v_item := '{}'::jsonb;
    ELSE
      v_pin := btrim(COALESCE(v_item ->> 'pin', ''));
    END IF;

    IF v_pin = '' THEN
      v_errors := v_errors || format('row %s: empty PIN', v_idx);
      CONTINUE;
    END IF;

    v_face := COALESCE(
      NULLIF(v_item ->> 'face_value_usd', '')::numeric,
      NULLIF(p_defaults ->> 'face_value_usd', '')::numeric);

    -- No silent default. J8's rule: a plausible wrong price gets charged
    -- unnoticed, and this one is charged to the subscriber.
    IF v_face IS NULL OR v_face <= 0 THEN
      v_errors := v_errors || format('row %s: face_value_usd is required', v_idx);
      CONTINUE;
    END IF;

    v_expires := COALESCE(
      NULLIF(v_item ->> 'expires_at', '')::timestamptz,
      NULLIF(p_defaults ->> 'expires_at', '')::timestamptz,
      now() + make_interval(days => COALESCE(v_validity, 365)));

    BEGIN
      INSERT INTO offline_voucher_stock (
        carrier_id, source, pin_encrypted, pin_fingerprint, serial,
        face_value_usd, face_value_native, face_value_currency, cost_usd,
        expires_at, redeem_instructions, loaded_by, load_note
      ) VALUES (
        p_carrier_id, v_source,
        public.voucher_encrypt_pin(v_pin),
        public.voucher_pin_fingerprint(p_carrier_id, v_pin),
        NULLIF(COALESCE(v_item ->> 'serial', p_defaults ->> 'serial'), ''),
        v_face,
        COALESCE(NULLIF(v_item ->> 'face_value_native', '')::numeric,
                 NULLIF(p_defaults ->> 'face_value_native', '')::numeric),
        NULLIF(upper(COALESCE(v_item ->> 'face_value_currency',
                              p_defaults ->> 'face_value_currency', '')), ''),
        COALESCE(NULLIF(v_item ->> 'cost_usd', '')::numeric,
                 NULLIF(p_defaults ->> 'cost_usd', '')::numeric),
        v_expires,
        NULLIF(COALESCE(v_item ->> 'redeem_instructions',
                        p_defaults ->> 'redeem_instructions'), ''),
        v_admin, p_note
      )
      ON CONFLICT (carrier_id, pin_fingerprint) DO NOTHING
      RETURNING id INTO v_id;

      IF v_id IS NULL THEN
        v_skipped := v_skipped + 1;
      ELSE
        v_added := v_added + 1;
        v_id := NULL;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      v_errors := v_errors || format('row %s: %s', v_idx, SQLERRM);
    END;
  END LOOP;

  -- The PINs themselves never reach the audit log; the counts do.
  INSERT INTO admin_audit_log (actor_id, action, target_type, target_id, after_value, note)
  VALUES (auth.uid(), 'voucher_stock_add', 'carrier', p_carrier_id::text,
          jsonb_build_object('added', v_added, 'skipped', v_skipped,
                             'errors', to_jsonb(v_errors), 'source', v_source),
          p_note);

  RETURN jsonb_build_object(
    'success', true, 'added', v_added, 'skipped_duplicates', v_skipped,
    'errors', to_jsonb(v_errors));
END;
$fn$;

CREATE OR REPLACE FUNCTION public.admin_void_voucher_stock(
  p_id     uuid,
  p_reason text,
  p_note   text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_row offline_voucher_stock%ROWTYPE;
BEGIN
  PERFORM public.assert_admin();

  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'A reason is required' USING ERRCODE = 'KS464';
  END IF;

  SELECT * INTO v_row FROM offline_voucher_stock WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Voucher % not found', p_id USING ERRCODE = 'KS461';
  END IF;

  -- An issued PIN is on somebody's handset. Voiding it here would not take it
  -- back — it would only stop us recognising it when they report the reveal,
  -- turning a settled debt into a mystery. Write off the grant instead.
  IF v_row.status <> 'available' THEN
    RAISE EXCEPTION 'Only available stock can be voided (this one is %)', v_row.status
      USING ERRCODE = 'KS462',
            HINT = 'If it is already with a subscriber, write off the grant instead.';
  END IF;

  UPDATE offline_voucher_stock
     SET status = 'void', void_reason = btrim(p_reason), updated_at = now()
   WHERE id = p_id
  RETURNING * INTO v_row;

  INSERT INTO admin_audit_log (actor_id, action, target_type, target_id, after_value, note)
  VALUES (auth.uid(), 'voucher_stock_void', 'offline_voucher_stock', p_id::text,
          jsonb_build_object('reason', p_reason), p_note);

  RETURN jsonb_build_object('success', true, 'id', p_id);
END;
$fn$;

-- ───────────────────────────────────────────────────────────────────────────
-- 4. Admin: grants and debts
-- ───────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_list_voucher_grants(
  p_status text DEFAULT NULL,
  p_limit  integer DEFAULT 200
)
RETURNS TABLE (
  id uuid, user_id uuid, user_email text, sim_line_id uuid, phone_number text,
  carrier_name text, status text, face_value_usd numeric, amount_due_usd numeric,
  provisioned_at timestamptz, revealed_at timestamptz, reported_at timestamptz,
  settled_at timestamptz, expires_at timestamptz, days_outstanding integer,
  is_overdue boolean, device_id text, write_off_reason text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_grace integer := 14;
BEGIN
  PERFORM public.assert_admin();

  SELECT COALESCE(NULLIF(config_value, '')::integer, 14) INTO v_grace
    FROM system_configs WHERE config_key = 'OFFLINE_VOUCHER_SETTLEMENT_GRACE_DAYS';

  RETURN QUERY
  SELECT g.id, g.user_id, p.email, g.sim_line_id, sl.phone_number,
         c.name, g.status, s.face_value_usd, g.amount_due_usd,
         g.provisioned_at, g.revealed_at, g.reported_at, g.settled_at, g.expires_at,
         CASE WHEN g.status = 'revealed'
              THEN GREATEST(0, (EXTRACT(EPOCH FROM (now() - g.revealed_at)) / 86400)::integer)
         END,
         (g.status = 'revealed'
          AND g.revealed_at < now() - make_interval(days => COALESCE(v_grace, 14))),
         g.device_id, g.write_off_reason
    FROM offline_voucher_grants g
    JOIN offline_voucher_stock s ON s.id = g.stock_id
    JOIN sim_lines sl ON sl.id = g.sim_line_id
    LEFT JOIN carriers c ON c.id = sl.carrier_id
    LEFT JOIN profiles p ON p.id = g.user_id
   WHERE (p_status IS NULL OR g.status = p_status)
   ORDER BY (g.status = 'revealed') DESC, g.revealed_at ASC NULLS LAST, g.provisioned_at DESC
   LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 200), 1000));
END;
$fn$;

-- Forgiving a debt. NOT a wallet adjustment: no money moved when the voucher
-- was revealed (that is the entire "gift now, pay later" design), so booking a
-- credit here would invent one. This only clears the block on the subscriber's
-- next voucher and records who decided to eat the cost.
CREATE OR REPLACE FUNCTION public.admin_write_off_voucher_grant(
  p_grant_id uuid,
  p_reason   text,
  p_note     text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_row offline_voucher_grants%ROWTYPE;
BEGIN
  PERFORM public.assert_admin();

  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'A reason is required' USING ERRCODE = 'KS464';
  END IF;

  SELECT * INTO v_row FROM offline_voucher_grants WHERE id = p_grant_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Grant % not found', p_grant_id USING ERRCODE = 'KS461';
  END IF;

  IF v_row.status NOT IN ('provisioned','revealed') THEN
    RAISE EXCEPTION 'Grant is already % ', v_row.status USING ERRCODE = 'KS462';
  END IF;

  UPDATE offline_voucher_grants
     SET status = 'written_off', write_off_reason = btrim(p_reason), updated_at = now()
   WHERE id = p_grant_id;

  UPDATE offline_voucher_stock
     SET status = CASE WHEN v_row.status = 'revealed' THEN 'redeemed' ELSE 'void' END,
         void_reason = CASE WHEN v_row.status = 'revealed' THEN void_reason
                            ELSE 'grant written off: ' || btrim(p_reason) END,
         updated_at = now()
   WHERE id = v_row.stock_id;

  INSERT INTO admin_audit_log (actor_id, action, target_type, target_id, before_value, after_value, note)
  VALUES (auth.uid(), 'voucher_grant_write_off', 'offline_voucher_grant', p_grant_id::text,
          to_jsonb(v_row), jsonb_build_object('reason', p_reason), p_note);

  RETURN jsonb_build_object('success', true, 'id', p_grant_id,
                            'amount_forgiven', v_row.amount_due_usd);
END;
$fn$;

-- ───────────────────────────────────────────────────────────────────────────
-- 5. Admin: the fulfilment queue
-- ───────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_list_voucher_requests(
  p_status text DEFAULT 'open',
  p_limit  integer DEFAULT 200
)
RETURNS TABLE (
  id uuid, user_id uuid, user_email text, sim_line_id uuid, phone_number text,
  carrier_id uuid, carrier_name text, country_name text, reason text, status text,
  opened_at timestamptz, due_at timestamptz, is_overdue boolean,
  hours_remaining numeric, available_stock bigint, note text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  PERFORM public.assert_admin();

  RETURN QUERY
  SELECT r.id, r.user_id, p.email, r.sim_line_id, sl.phone_number,
         r.carrier_id, c.name, co.name, r.reason, r.status,
         r.opened_at, r.due_at,
         (r.status = 'open' AND r.due_at < now()),
         round(EXTRACT(EPOCH FROM (r.due_at - now())) / 3600.0, 1),
         (SELECT count(*) FROM offline_voucher_stock st
           WHERE st.carrier_id = r.carrier_id AND st.status = 'available'),
         r.note
    FROM offline_voucher_requests r
    JOIN sim_lines sl ON sl.id = r.sim_line_id
    JOIN carriers c ON c.id = r.carrier_id
    JOIN countries co ON co.id = c.country_id
    LEFT JOIN profiles p ON p.id = r.user_id
   WHERE (p_status IS NULL OR r.status = p_status)
   ORDER BY r.due_at ASC
   LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 200), 1000));
END;
$fn$;

CREATE OR REPLACE FUNCTION public.admin_cancel_voucher_request(
  p_id     uuid,
  p_reason text,
  p_note   text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_row offline_voucher_requests%ROWTYPE;
BEGIN
  PERFORM public.assert_admin();

  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'A reason is required' USING ERRCODE = 'KS464';
  END IF;

  UPDATE offline_voucher_requests
     SET status = 'cancelled', note = btrim(p_reason), updated_at = now()
   WHERE id = p_id AND status = 'open'
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No open request %', p_id USING ERRCODE = 'KS461';
  END IF;

  INSERT INTO admin_audit_log (actor_id, action, target_type, target_id, after_value, note)
  VALUES (auth.uid(), 'voucher_request_cancel', 'offline_voucher_request', p_id::text,
          jsonb_build_object('reason', p_reason), p_note);

  -- The sweep will re-open it tomorrow if the line is still entitled and still
  -- uncovered. Cancelling is "not this week", not "never" — and saying so here
  -- stops the next operator wondering why it came back.
  RETURN jsonb_build_object('success', true, 'id', p_id,
    'note', 'The nightly sweep re-opens this if the line is still entitled and has no voucher.');
END;
$fn$;

-- ───────────────────────────────────────────────────────────────────────────
-- 6. Admin: redemption codes
-- ───────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_list_carrier_voucher_redemption()
RETURNS TABLE (
  carrier_id uuid, carrier_name text, country_name text,
  redeem_ussd_template text, instructions text,
  verified_at timestamptz, verified_by_email text, notes text,
  premium_lines bigint, available_stock bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  PERFORM public.assert_admin();

  RETURN QUERY
  SELECT c.id, c.name, co.name,
         r.redeem_ussd_template, r.instructions, r.verified_at, p.email, r.notes,
         (SELECT count(*) FROM sim_lines sl
           WHERE sl.carrier_id = c.id AND lower(coalesce(sl.plan_type,'')) = 'premium'),
         (SELECT count(*) FROM offline_voucher_stock st
           WHERE st.carrier_id = c.id AND st.status = 'available')
    FROM carriers c
    JOIN countries co ON co.id = c.country_id
    LEFT JOIN carrier_voucher_redemption r ON r.carrier_id = c.id
    LEFT JOIN profiles p ON p.id = r.verified_by
   ORDER BY (r.carrier_id IS NULL), co.name, c.name;
END;
$fn$;

-- `verified_at` and `verified_by` are NOT patch fields and never can be — the
-- server stamps them from `{"verified": true}`. A caller that could supply the
-- date could mark a code verified in the past without ever having looked at it,
-- and this particular lie is dialled by someone with no way to ask for help.
CREATE OR REPLACE FUNCTION public.admin_upsert_carrier_voucher_redemption(
  p_carrier_id uuid,
  p_patch      jsonb,
  p_note       text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_admin   uuid;
  v_allowed text[] := ARRAY['redeem_ussd_template','instructions','notes','verified'];
  v_key     text;
  v_before  jsonb;
  v_row     carrier_voucher_redemption%ROWTYPE;
BEGIN
  v_admin := public.assert_admin();

  IF p_patch IS NULL OR jsonb_typeof(p_patch) <> 'object' OR p_patch = '{}'::jsonb THEN
    RAISE EXCEPTION 'Patch must be a non-empty object' USING ERRCODE = 'KS467';
  END IF;

  FOR v_key IN SELECT jsonb_object_keys(p_patch) LOOP
    IF NOT (v_key = ANY(v_allowed)) THEN
      RAISE EXCEPTION 'Unknown patch field: %', v_key USING ERRCODE = 'KS467';
    END IF;
  END LOOP;

  IF NOT EXISTS (SELECT 1 FROM carriers WHERE id = p_carrier_id) THEN
    RAISE EXCEPTION 'Carrier % not found', p_carrier_id USING ERRCODE = 'KS461';
  END IF;

  -- Refuse the missing placeholder here rather than letting the CHECK fire: a
  -- raw 23514 tells the operator nothing about what a template is supposed to
  -- look like, and this is a field they type by hand from a carrier's website.
  IF p_patch ? 'redeem_ussd_template'
     AND NULLIF(btrim(p_patch ->> 'redeem_ussd_template'), '') IS NOT NULL
     AND position('{PIN}' in (p_patch ->> 'redeem_ussd_template')) = 0 THEN
    RAISE EXCEPTION 'The template must contain {PIN}, e.g. *102*{PIN}#'
      USING ERRCODE = 'KS466';
  END IF;

  SELECT * INTO v_row FROM carrier_voucher_redemption WHERE carrier_id = p_carrier_id;
  v_before := to_jsonb(v_row);

  IF v_row.carrier_id IS NULL THEN
    IF NOT (p_patch ? 'instructions') OR btrim(COALESCE(p_patch ->> 'instructions','')) = '' THEN
      RAISE EXCEPTION 'A new redemption entry needs instructions' USING ERRCODE = 'KS466';
    END IF;
    INSERT INTO carrier_voucher_redemption (carrier_id, instructions)
    VALUES (p_carrier_id, p_patch ->> 'instructions')
    RETURNING * INTO v_row;
  END IF;

  UPDATE carrier_voucher_redemption SET
    redeem_ussd_template = CASE WHEN p_patch ? 'redeem_ussd_template'
                                THEN NULLIF(btrim(p_patch ->> 'redeem_ussd_template'), '')
                                ELSE redeem_ussd_template END,
    instructions         = COALESCE(NULLIF(btrim(p_patch ->> 'instructions'), ''), instructions),
    notes                = CASE WHEN p_patch ? 'notes' THEN p_patch ->> 'notes' ELSE notes END,
    -- Editing the code un-verifies it. Somebody must look at the new string.
    verified_at = CASE
                    WHEN COALESCE((p_patch ->> 'verified')::boolean, false) THEN now()
                    WHEN p_patch ? 'redeem_ussd_template' THEN NULL
                    ELSE verified_at END,
    verified_by = CASE
                    WHEN COALESCE((p_patch ->> 'verified')::boolean, false) THEN v_admin
                    WHEN p_patch ? 'redeem_ussd_template' THEN NULL
                    ELSE verified_by END,
    updated_at = now()
  WHERE carrier_id = p_carrier_id
  RETURNING * INTO v_row;

  -- Checked AFTER the write against the resulting row, so setting the two
  -- fields in either order — or in two separate calls — cannot slip past (J4).
  IF v_row.verified_at IS NOT NULL AND COALESCE(btrim(v_row.redeem_ussd_template), '') = '' THEN
    RAISE EXCEPTION 'There is no code to verify — add redeem_ussd_template first'
      USING ERRCODE = 'KS466';
  END IF;

  INSERT INTO admin_audit_log (actor_id, action, target_type, target_id, before_value, after_value, note)
  VALUES (auth.uid(), 'voucher_redemption_upsert', 'carrier', p_carrier_id::text,
          v_before, to_jsonb(v_row), p_note);

  RETURN to_jsonb(v_row);
END;
$fn$;

-- ───────────────────────────────────────────────────────────────────────────
-- 7. Admin: DingConnect purchase jobs
-- ───────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_queue_ding_voucher_purchase(
  p_carrier_id     uuid,
  p_quantity       integer,
  p_account_number text DEFAULT NULL,
  p_max_unit_cost  numeric DEFAULT NULL,
  p_note           text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_admin uuid;
  v_on    boolean;
  v_cap   numeric;
  v_code  text;
  v_id    uuid;
BEGIN
  v_admin := public.assert_admin();

  SELECT COALESCE(NULLIF(config_value, ''), 'false')::boolean INTO v_on
    FROM system_configs WHERE config_key = 'OFFLINE_VOUCHER_DING_ENABLED';

  IF NOT COALESCE(v_on, false) THEN
    RAISE EXCEPTION 'DingConnect voucher buying is switched off'
      USING ERRCODE = 'KS472',
            HINT = 'Settings → Offline refill → "Buy PINs from DingConnect".';
  END IF;

  SELECT m.provider_carrier_code INTO v_code
    FROM carrier_provider_map m
    JOIN service_providers sp ON sp.code = m.provider
   WHERE m.carrier_id = p_carrier_id AND m.provider = 'ding'
     AND m.is_enabled AND sp.is_active
     AND COALESCE(m.provider_carrier_code, '') <> '';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'This carrier has no enabled DingConnect mapping'
      USING ERRCODE = 'KS472',
            HINT = 'Suppliers → map the carrier to ding and give it a provider code first.';
  END IF;

  IF COALESCE(p_quantity, 0) < 1 OR p_quantity > 50 THEN
    RAISE EXCEPTION 'Quantity must be 1..50' USING ERRCODE = 'KS466';
  END IF;

  SELECT COALESCE(NULLIF(config_value, '')::numeric, 5.00) INTO v_cap
    FROM system_configs WHERE config_key = 'OFFLINE_VOUCHER_DING_MAX_UNIT_COST_USD';

  -- The per-job cap may only be TIGHTER than the global one. An operator typing
  -- a bigger number here would otherwise route around the ceiling that exists
  -- to stop a mis-parsed price draining the Ding balance.
  v_cap := LEAST(COALESCE(p_max_unit_cost, v_cap), COALESCE(v_cap, 5.00));

  INSERT INTO offline_voucher_purchase_jobs
    (carrier_id, provider_code, quantity, max_unit_cost_usd, account_number, requested_by, note)
  VALUES (p_carrier_id, 'ding', p_quantity, v_cap, NULLIF(btrim(COALESCE(p_account_number,'')), ''),
          v_admin, p_note)
  RETURNING id INTO v_id;

  INSERT INTO admin_audit_log (actor_id, action, target_type, target_id, after_value, note)
  VALUES (auth.uid(), 'voucher_purchase_queue', 'offline_voucher_purchase_job', v_id::text,
          jsonb_build_object('carrier_id', p_carrier_id, 'quantity', p_quantity,
                             'max_unit_cost_usd', v_cap, 'provider_code', v_code),
          p_note);

  RETURN jsonb_build_object(
    'success', true, 'job_id', v_id, 'quantity', p_quantity, 'max_unit_cost_usd', v_cap,
    'note', 'Queued. worker_voucher_stock.js on the VM performs the purchase; read the job row for the outcome.');
END;
$fn$;

CREATE OR REPLACE FUNCTION public.admin_list_voucher_purchase_jobs(p_limit integer DEFAULT 50)
RETURNS TABLE (
  id uuid, carrier_id uuid, carrier_name text, provider_code text, quantity integer,
  max_unit_cost_usd numeric, account_number text, status text, produced_count integer,
  spent_usd numeric, last_error text, requested_by_email text,
  requested_at timestamptz, claimed_at timestamptz, completed_at timestamptz, note text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  PERFORM public.assert_admin();

  RETURN QUERY
  SELECT j.id, j.carrier_id, c.name, j.provider_code, j.quantity,
         j.max_unit_cost_usd, j.account_number, j.status, j.produced_count,
         j.spent_usd, j.last_error, p.email,
         j.requested_at, j.claimed_at, j.completed_at, j.note
    FROM offline_voucher_purchase_jobs j
    JOIN carriers c ON c.id = j.carrier_id
    LEFT JOIN profiles p ON p.id = j.requested_by
   ORDER BY j.requested_at DESC
   LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 50), 500));
END;
$fn$;

CREATE OR REPLACE FUNCTION public.admin_cancel_voucher_purchase_job(
  p_id   uuid,
  p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_row offline_voucher_purchase_jobs%ROWTYPE;
BEGIN
  PERFORM public.assert_admin();

  -- Only a job the worker has not picked up. Once claimed, money may already be
  -- in flight at Ding and "cancelled" here would just lose the receipt.
  UPDATE offline_voucher_purchase_jobs
     SET status = 'cancelled', completed_at = now(), updated_at = now()
   WHERE id = p_id AND status = 'queued'
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No queued job % (already claimed jobs cannot be cancelled)', p_id
      USING ERRCODE = 'KS462';
  END IF;

  INSERT INTO admin_audit_log (actor_id, action, target_type, target_id, after_value, note)
  VALUES (auth.uid(), 'voucher_purchase_cancel', 'offline_voucher_purchase_job', p_id::text,
          to_jsonb(v_row), p_note);

  RETURN jsonb_build_object('success', true, 'id', p_id);
END;
$fn$;

-- ───────────────────────────────────────────────────────────────────────────
-- 8. Worker-facing (service_role only)
-- ───────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.claim_voucher_purchase_job()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_job    offline_voucher_purchase_jobs%ROWTYPE;
  v_code   text;
  v_iso    text;
  v_on     boolean;
BEGIN
  SELECT COALESCE(NULLIF(config_value, ''), 'false')::boolean INTO v_on
    FROM system_configs WHERE config_key = 'OFFLINE_VOUCHER_DING_ENABLED';

  -- Re-checked at claim time, not only at queue time. A switch flipped off
  -- while jobs sit in the queue must actually stop the spending.
  IF NOT COALESCE(v_on, false) THEN
    RETURN jsonb_build_object('job', NULL, 'reason', 'OFFLINE_VOUCHER_DING_ENABLED is false');
  END IF;

  UPDATE offline_voucher_purchase_jobs
     SET status = 'claimed', claimed_at = now(), updated_at = now()
   WHERE id = (
     SELECT id FROM offline_voucher_purchase_jobs
      WHERE status = 'queued'
      ORDER BY requested_at
      FOR UPDATE SKIP LOCKED
      LIMIT 1)
  RETURNING * INTO v_job;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('job', NULL);
  END IF;

  SELECT m.provider_carrier_code, co.iso_code
    INTO v_code, v_iso
    FROM carrier_provider_map m
    JOIN carriers c ON c.id = m.carrier_id
    JOIN countries co ON co.id = c.country_id
   WHERE m.carrier_id = v_job.carrier_id AND m.provider = 'ding' AND m.is_enabled;

  RETURN jsonb_build_object(
    'job', jsonb_build_object(
      'id', v_job.id,
      'carrier_id', v_job.carrier_id,
      'provider_carrier_code', v_code,
      'country_iso', v_iso,
      'quantity', v_job.quantity,
      'max_unit_cost_usd', v_job.max_unit_cost_usd,
      'account_number', v_job.account_number));
END;
$fn$;

-- The worker hands back whatever Ding actually returned. `p_pins` is an array
-- of {pin, serial?, face_value_usd, cost_usd?, provider_ref?, receipt?,
-- instructions?}. Every raw receipt is stored: J5's rule is that a mapping
-- nobody has diffed against a live response must not be the only copy.
CREATE OR REPLACE FUNCTION public.record_voucher_purchase_result(
  p_job_id uuid,
  p_pins   jsonb DEFAULT '[]'::jsonb,
  p_error  text  DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_job    offline_voucher_purchase_jobs%ROWTYPE;
  v_item   jsonb;
  v_pin    text;
  v_face   numeric;
  v_cost   numeric;
  v_added  integer := 0;
  v_spent  numeric := 0;
  v_id     uuid;
  v_valid  integer;
BEGIN
  SELECT * INTO v_job FROM offline_voucher_purchase_jobs WHERE id = p_job_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Job % not found', p_job_id USING ERRCODE = 'KS461';
  END IF;

  SELECT COALESCE(NULLIF(config_value, '')::integer, 365) INTO v_valid
    FROM system_configs WHERE config_key = 'OFFLINE_VOUCHER_VALIDITY_DAYS';

  FOR v_item IN SELECT * FROM jsonb_array_elements(COALESCE(p_pins, '[]'::jsonb)) LOOP
    v_pin  := btrim(COALESCE(v_item ->> 'pin', ''));
    v_face := NULLIF(v_item ->> 'face_value_usd', '')::numeric;
    v_cost := NULLIF(v_item ->> 'cost_usd', '')::numeric;

    CONTINUE WHEN v_pin = '' OR v_face IS NULL OR v_face <= 0;

    -- The cap is enforced HERE as well as in the worker. A worker is a file on
    -- a VM that anyone with shell access can edit; the ceiling that protects
    -- the Ding balance belongs where the row is written.
    IF v_cost IS NOT NULL AND v_cost > v_job.max_unit_cost_usd THEN
      CONTINUE;
    END IF;

    INSERT INTO offline_voucher_stock (
      carrier_id, source, pin_encrypted, pin_fingerprint, serial,
      face_value_usd, cost_usd, expires_at, provider_ref, provider_receipt,
      redeem_instructions, load_note
    ) VALUES (
      v_job.carrier_id, 'ding',
      public.voucher_encrypt_pin(v_pin),
      public.voucher_pin_fingerprint(v_job.carrier_id, v_pin),
      NULLIF(v_item ->> 'serial', ''),
      v_face, v_cost,
      COALESCE(NULLIF(v_item ->> 'expires_at', '')::timestamptz,
               now() + make_interval(days => COALESCE(v_valid, 365))),
      NULLIF(v_item ->> 'provider_ref', ''),
      COALESCE(v_item -> 'receipt', '{}'::jsonb),
      NULLIF(v_item ->> 'instructions', ''),
      'ding job ' || p_job_id::text
    )
    ON CONFLICT (carrier_id, pin_fingerprint) DO NOTHING
    RETURNING id INTO v_id;

    IF v_id IS NOT NULL THEN
      v_added := v_added + 1;
      v_spent := v_spent + COALESCE(v_cost, 0);
      v_id := NULL;
    END IF;
  END LOOP;

  UPDATE offline_voucher_purchase_jobs
     SET status = CASE WHEN p_error IS NOT NULL AND v_added = 0 THEN 'failed' ELSE 'done' END,
         produced_count = v_added,
         spent_usd = v_spent,
         last_error = p_error,
         completed_at = now(),
         updated_at = now()
   WHERE id = p_job_id;

  RETURN jsonb_build_object('success', true, 'added', v_added, 'spent_usd', v_spent);
END;
$fn$;

-- ───────────────────────────────────────────────────────────────────────────
-- 9. Grants
-- ───────────────────────────────────────────────────────────────────────────
DO $do$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'admin_voucher_overview()',
    'admin_list_voucher_stock(uuid, text, integer)',
    'admin_add_voucher_stock(uuid, jsonb, jsonb, text)',
    'admin_void_voucher_stock(uuid, text, text)',
    'admin_list_voucher_grants(text, integer)',
    'admin_write_off_voucher_grant(uuid, text, text)',
    'admin_list_voucher_requests(text, integer)',
    'admin_cancel_voucher_request(uuid, text, text)',
    'admin_list_carrier_voucher_redemption()',
    'admin_upsert_carrier_voucher_redemption(uuid, jsonb, text)',
    'admin_queue_ding_voucher_purchase(uuid, integer, text, numeric, text)',
    'admin_list_voucher_purchase_jobs(integer)',
    'admin_cancel_voucher_purchase_job(uuid, text)'
  ] LOOP
    -- A SECURITY DEFINER function keeps EXECUTE-to-PUBLIC unless revoked. That
    -- default is how i7's admin_upsert_carrier_rule shipped anon-callable —
    -- occurrence #6 of the blanket-grant hole, caught by F0 T1.
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO authenticated', f);
  END LOOP;

  FOREACH f IN ARRAY ARRAY[
    'claim_voucher_purchase_job()',
    'record_voucher_purchase_result(uuid, jsonb, text)'
  ] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC, anon, authenticated', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO service_role', f);
  END LOOP;
END $do$;

-- ───────────────────────────────────────────────────────────────────────────
-- 10. Cron — after the 02:20 forecast and the 02:55 carrier advice
-- ───────────────────────────────────────────────────────────────────────────
SELECT cron.unschedule('sweep-offline-vouchers')
 WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'sweep-offline-vouchers');

SELECT cron.schedule('sweep-offline-vouchers', '20 3 * * *',
                     $cron$SELECT public.sweep_offline_voucher_requests(false);$cron$);

COMMIT;
