-- =============================================================================
-- I5 · Margin-aware supplier selection + failover to the next supplier
-- =============================================================================
-- THE TWO DECISIONS, as given by the owner on 2026-08-04:
--
--   1. "margin-aware, but I need it to be fixable so I can change it from the
--      database"
--   2. "a failed purchase auto-retries at the next supplier — yes, but inform
--      the user unless it is the same cost"
--
-- SHIPS PRE-PRODUCTION, DELIBERATELY. The owner's standing instruction is to
-- stay pre-production until the app is confirmed to cover what users need. So:
--   * `SUPPLIER_RETRY_ENABLED` defaults to **false** — the failover engine is
--     installed, tested and inert, exactly how G10 shipped `DEVICE_RISK_ENFORCE`.
--   * `supplier_policy.is_globally_enabled` is **false for ding and reloadly**.
--     Their credentials exist but no catalogue has ever been fetched, and a
--     supplier with an empty cache that is "enabled" ranks as infinitely cheap
--     by absence rather than by price.
--   * Zendit and DTOne stay enabled because they are what routes today.
-- Flipping any of these is one UPDATE. Nothing here changes behaviour on apply.
--
-- WHY "MARGIN-AWARE" IS NOT JUST "CHEAPEST"
--   Absolute-cheapest churns suppliers for a cent. That costs more than it
--   saves: a different supplier means a different failure mode, a different
--   settlement, and a support ticket the 1¢ does not pay for. So selection has
--   two DB-editable layers:
--
--   (a) **Effective cost** — `base × (1 + risk_premium_percent/100) + flat_penalty_usd`,
--       per supplier. This is how a cheap-but-flaky supplier is priced honestly
--       against a dearer reliable one without hardcoding a preference.
--   (b) **A switching threshold** — the carrier's incumbent supplier wins
--       unless a challenger beats it on effective cost by BOTH
--       `SUPPLIER_SWITCH_MIN_SAVING_USD` and `SUPPLIER_SWITCH_MIN_SAVING_PERCENT`.
--       Requiring both is what stops a 2¢ saving on a $0.25 top-up (8%!) and a
--       2¢ saving on a $50 top-up from being treated the same way.
--
--   Set `SUPPLIER_SELECTION_MODE = 'cheapest'` to bypass (b) entirely.
--
-- ⚠️ EVERY KNOB IS IN `system_configs` OR `supplier_policy`, NEVER IN CODE —
--   rule 6 of PROJECT_TOPOLOGY §7. `system_configs.config_value` is an untyped
--   varchar, so every read below is wrapped and falls back to a safe default
--   rather than raising on a fat-fingered value (the G11 lesson: an untyped
--   config that multiplies money needs a floor and a ceiling, not trust).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Per-supplier policy
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.supplier_policy (
  provider              text PRIMARY KEY
                          CHECK (provider IN ('zendit', 'dtone', 'ding', 'reloadly')),
  is_globally_enabled   boolean NOT NULL DEFAULT false,

  -- The margin knobs. Both add to the *comparison* cost only — neither is ever
  -- charged to a user and neither touches `base_cost_usd`.
  risk_premium_percent  numeric(6,3) NOT NULL DEFAULT 0
                          CHECK (risk_premium_percent >= 0 AND risk_premium_percent <= 100),
  flat_penalty_usd      numeric(10,4) NOT NULL DEFAULT 0
                          CHECK (flat_penalty_usd >= 0),

  -- Operational reality, for the admin screen and for future auto-tuning.
  success_count         integer NOT NULL DEFAULT 0,
  failure_count         integer NOT NULL DEFAULT 0,
  last_failure_at       timestamptz,
  notes                 text,
  updated_at            timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.supplier_policy ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.supplier_policy FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.supplier_policy TO service_role;

COMMENT ON TABLE public.supplier_policy IS
  'I5: per-supplier selection policy. risk_premium_percent and flat_penalty_usd shift a supplier''s COMPARISON cost only — they are never charged to a user. is_globally_enabled is the kill switch, independent of carrier_provider_map.is_enabled.';

INSERT INTO public.supplier_policy (provider, is_globally_enabled, risk_premium_percent, flat_penalty_usd, notes) VALUES
  ('zendit',   true,  0,   0, 'Primary supplier, 49 of 50 carriers. Baseline: zero premium by definition.'),
  -- dtone MUST ship enabled: it is the only supplier for Zain KSA, and I1 has
  -- just made that line refillable for the first time. Seeding it false here
  -- would silently undo I1 the moment this migration applied. Its 5% risk
  -- premium reflects that it is still on the PREPROD endpoint — real enough to
  -- route, not trusted enough to win a close price comparison.
  ('dtone',    true,  5.0, 0, 'On the PREPROD endpoint, so treat its prices as indicative. Enabled because it is the sole supplier for Zain KSA. Drop the premium to 0 once production credentials land.'),
  ('ding',     false, 0,   0, 'Credentials held by the owner; no catalogue has ever been fetched and carriers.ding_carrier is NULL for all 50. Enable only after worker_offers_cache populates it.'),
  ('reloadly', false, 0,   0, 'Same as ding: OAuth credentials held, carriers.reloadly_operator_id NULL for all 50.')
ON CONFLICT (provider) DO NOTHING;

INSERT INTO public.system_configs (config_key, config_value) VALUES
  ('SUPPLIER_SELECTION_MODE',          'margin_aware'),
  ('SUPPLIER_SWITCH_MIN_SAVING_USD',   '0.05'),
  ('SUPPLIER_SWITCH_MIN_SAVING_PERCENT','2.0'),
  ('SUPPLIER_RETRY_ENABLED',           'false'),
  ('SUPPLIER_RETRY_MAX_ATTEMPTS',      '2'),
  ('SUPPLIER_RETRY_SAME_COST_TOLERANCE_USD', '0.01'),
  ('SUPPLIER_RETRY_SKIP_REASONS',      'insufficient,invalid number,invalid_number,invalid msisdn,suspended,blocked,cap,not eligible,barred')
ON CONFLICT (config_key) DO NOTHING;

-- Numeric config reader with a floor, a ceiling and a default. Every caller
-- below goes through it so one bad row cannot multiply or zero a price.
CREATE OR REPLACE FUNCTION public.config_numeric(
  p_key text, p_default numeric, p_min numeric, p_max numeric
)
RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE v numeric;
BEGIN
  BEGIN
    SELECT config_value::numeric INTO v FROM public.system_configs WHERE config_key = p_key;
  EXCEPTION WHEN OTHERS THEN
    v := NULL;
  END;
  IF v IS NULL OR v < p_min OR v > p_max THEN
    RETURN p_default;
  END IF;
  RETURN v;
END;
$function$;

REVOKE ALL ON FUNCTION public.config_numeric(text, numeric, numeric, numeric) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.config_numeric(text, numeric, numeric, numeric) TO service_role;

-- The comparison price. NOT the charged price — the user always pays
-- `base_cost_usd` plus the usual fees, whichever supplier wins.
CREATE OR REPLACE FUNCTION public.supplier_effective_cost(p_provider text, p_base numeric)
RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_prem numeric := 0;
  v_flat numeric := 0;
BEGIN
  IF p_base IS NULL THEN RETURN NULL; END IF;

  SELECT sp.risk_premium_percent, sp.flat_penalty_usd
  INTO v_prem, v_flat
  FROM public.supplier_policy sp
  WHERE sp.provider = p_provider;

  -- An unknown supplier gets no discount and no penalty; it simply competes at
  -- face value. Failing closed here would hide a newly added provider.
  RETURN round(p_base * (1 + COALESCE(v_prem, 0) / 100.0) + COALESCE(v_flat, 0), 4);
END;
$function$;

REVOKE ALL ON FUNCTION public.supplier_effective_cost(text, numeric) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.supplier_effective_cost(text, numeric) TO service_role;

-- -----------------------------------------------------------------------------
-- 2. The selection rule, in ONE place
-- -----------------------------------------------------------------------------
-- Every supplier that could fulfil this (line, offer): enabled for the carrier,
-- not globally switched off, offer present and fresh, not already tried.
--
-- Split out from `choose_supplier_for_offer` on purpose. The first version
-- materialised this into a TEMP TABLE inside a `STABLE` function — which cannot
-- work, because a STABLE function may not write, and `CREATE TEMP TABLE` is a
-- write. A set-returning helper gives the same "use it twice" convenience with
-- no side effect at all.
CREATE OR REPLACE FUNCTION public.supplier_candidates(
  p_sim_line_id uuid,
  p_offer_id    text,
  p_exclude     text[] DEFAULT NULL
)
RETURNS TABLE (
  provider  text,
  base      numeric,
  eff       numeric,
  incumbent boolean,
  prio      integer
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT poc.api_provider,
         COALESCE(poc.price_fixed_usd, poc.price_min_usd),
         public.supplier_effective_cost(poc.api_provider,
           COALESCE(poc.price_fixed_usd, poc.price_min_usd)),
         (lower(COALESCE(ca.api_provider, '')) = poc.api_provider),
         m.priority
  FROM public.sim_lines sl
  JOIN public.carriers ca ON ca.id = sl.carrier_id
  JOIN public.carrier_provider_map m
    ON m.carrier_id = sl.carrier_id AND m.is_enabled
  JOIN public.supplier_policy sp
    ON sp.provider = m.provider AND sp.is_globally_enabled
  JOIN public.provider_offers_cache poc
    ON poc.api_provider = m.provider
   AND poc.country_code = m.provider_country_code
   AND poc.carrier_code = m.provider_carrier_code
   AND poc.offer_id     = p_offer_id
  WHERE sl.id = p_sim_line_id
    AND poc.refreshed_at >= now() - interval '24 hours'
    AND (p_exclude IS NULL OR NOT (poc.api_provider = ANY (p_exclude)));
$function$;

REVOKE ALL ON FUNCTION public.supplier_candidates(uuid, text, text[]) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.supplier_candidates(uuid, text, text[]) TO service_role;

-- Returns the winning supplier for a (line, offer) pair. `request_instant_refill`
-- and the failover engine both call this, so a quote and a charge cannot use
-- different rules — the I1 lesson, one step further.
CREATE OR REPLACE FUNCTION public.choose_supplier_for_offer(
  p_sim_line_id uuid,
  p_offer_id    text,
  p_exclude     text[] DEFAULT NULL
)
RETURNS TABLE (
  provider        text,
  base_cost_usd   numeric,
  effective_usd   numeric,
  is_incumbent    boolean,
  chosen_reason   text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_mode       text;
  v_min_usd    numeric;
  v_min_pct    numeric;
  v_incumbent  RECORD;
  v_challenger RECORD;
BEGIN
  BEGIN
    SELECT config_value INTO v_mode FROM public.system_configs
    WHERE config_key = 'SUPPLIER_SELECTION_MODE';
  EXCEPTION WHEN OTHERS THEN v_mode := NULL;
  END;
  v_mode := lower(COALESCE(v_mode, 'margin_aware'));

  v_min_usd := public.config_numeric('SUPPLIER_SWITCH_MIN_SAVING_USD',    0.05, 0, 100);
  v_min_pct := public.config_numeric('SUPPLIER_SWITCH_MIN_SAVING_PERCENT', 2.0, 0, 100);

  SELECT * INTO v_challenger
  FROM public.supplier_candidates(p_sim_line_id, p_offer_id, p_exclude) c
  ORDER BY c.eff ASC, c.prio ASC, c.provider ASC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  IF v_mode = 'cheapest' THEN
    RETURN QUERY SELECT v_challenger.provider, v_challenger.base, v_challenger.eff,
                        v_challenger.incumbent, 'cheapest'::text;
    RETURN;
  END IF;

  SELECT * INTO v_incumbent
  FROM public.supplier_candidates(p_sim_line_id, p_offer_id, p_exclude) c
  WHERE c.incumbent
  ORDER BY c.eff ASC
  LIMIT 1;

  -- No incumbent among the candidates (it may be excluded by a failover, or the
  -- carrier default may be globally disabled) — the cheapest simply wins.
  IF NOT FOUND THEN
    RETURN QUERY SELECT v_challenger.provider, v_challenger.base, v_challenger.eff,
                        v_challenger.incumbent, 'no_incumbent'::text;
    RETURN;
  END IF;

  IF v_challenger.provider = v_incumbent.provider THEN
    RETURN QUERY SELECT v_incumbent.provider, v_incumbent.base, v_incumbent.eff,
                        true, 'incumbent_is_cheapest'::text;
    RETURN;
  END IF;

  -- BOTH thresholds, deliberately. An absolute floor alone lets a trivial
  -- saving win on a large top-up; a percentage alone lets a trivial saving win
  -- on a tiny one. See the header.
  IF (v_incumbent.eff - v_challenger.eff) >= v_min_usd
     AND v_incumbent.eff > 0
     AND ((v_incumbent.eff - v_challenger.eff) / v_incumbent.eff * 100.0) >= v_min_pct
  THEN
    RETURN QUERY SELECT v_challenger.provider, v_challenger.base, v_challenger.eff,
                        false, 'challenger_beat_threshold'::text;
  ELSE
    RETURN QUERY SELECT v_incumbent.provider, v_incumbent.base, v_incumbent.eff,
                        true, 'saving_below_threshold'::text;
  END IF;
END;
$function$;

REVOKE ALL ON FUNCTION public.choose_supplier_for_offer(uuid, text, text[]) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.choose_supplier_for_offer(uuid, text, text[]) TO service_role;

-- -----------------------------------------------------------------------------
-- 3. request_instant_refill uses the policy
-- -----------------------------------------------------------------------------
-- Signature unchanged (5 args) — see I1's SIGNATURE NOTE. The only change is
-- that supplier resolution now goes through choose_supplier_for_offer().
CREATE OR REPLACE FUNCTION public.request_instant_refill(
  p_sim_line_id        uuid,
  p_offer_id           text,
  p_payment_gateway_code text,
  p_amount_usd         numeric DEFAULT NULL::numeric,
  p_device_id          text DEFAULT NULL::text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_pick         RECORD;
  v_offer        RECORD;
  v_base         numeric;
  v_value        numeric;
  v_execution_id uuid;
  v_line_owner   uuid;
  v_payer        uuid;
  v_acting       uuid;
  v_charged      numeric;
  v_chk          RECORD;
  v_guard        jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_suspended = true) THEN
    RAISE EXCEPTION 'Account is suspended. Refills are disabled.';
  END IF;

  PERFORM public.enforce_rate_limit('instant_refill', auth.uid()::text);

  SELECT sl.user_id INTO v_line_owner
  FROM public.sim_lines sl
  WHERE sl.id = p_sim_line_id
    AND (sl.user_id = auth.uid()
         OR EXISTS (SELECT 1 FROM public.household_members hm
                    WHERE hm.owner_id = sl.user_id
                      AND hm.member_id = auth.uid()
                      AND hm.invite_status = 'accepted'
                      AND hm.role = 'manager'));

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Not authorized to refill this SIM line';
  END IF;

  -- I5: the policy decides the supplier.
  SELECT * INTO v_pick FROM public.choose_supplier_for_offer(p_sim_line_id, p_offer_id, NULL);

  IF NOT FOUND THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.sim_lines sl2
      JOIN public.carrier_provider_map m2 ON m2.carrier_id = sl2.carrier_id AND m2.is_enabled
      JOIN public.supplier_policy sp2 ON sp2.provider = m2.provider AND sp2.is_globally_enabled
      WHERE sl2.id = p_sim_line_id
    ) THEN
      RAISE EXCEPTION 'This carrier has no online top-up catalog';
    END IF;
    RAISE EXCEPTION 'Offer % is not available for this SIM line', p_offer_id;
  END IF;

  SELECT poc.price_type, poc.price_fixed_usd, poc.price_min_usd, poc.price_max_usd,
         poc.send_min, poc.send_max, poc.refreshed_at
  INTO v_offer
  FROM public.provider_offers_cache poc
  JOIN public.sim_lines sl ON sl.id = p_sim_line_id
  JOIN public.carrier_provider_map m
    ON m.carrier_id = sl.carrier_id AND m.provider = v_pick.provider
  WHERE poc.api_provider = v_pick.provider
    AND poc.country_code = m.provider_country_code
    AND poc.carrier_code = m.provider_carrier_code
    AND poc.offer_id = p_offer_id;

  IF v_offer.refreshed_at < now() - interval '24 hours' THEN
    RAISE EXCEPTION 'Offer pricing is temporarily unavailable. Please try again later.';
  END IF;

  IF v_offer.price_type = 'FIXED' THEN
    v_base := v_offer.price_fixed_usd;
    v_value := NULL;
  ELSE
    IF p_amount_usd IS NULL THEN
      RAISE EXCEPTION 'This offer requires an amount';
    END IF;
    v_base := round(p_amount_usd, 2);
    IF v_base < v_offer.price_min_usd - 0.01 OR v_base > v_offer.price_max_usd + 0.01 THEN
      RAISE EXCEPTION 'Amount % is outside this offer''s %-% USD range',
        v_base, v_offer.price_min_usd, v_offer.price_max_usd;
    END IF;
    v_value := public.interpolate_offer_value(
      v_offer.send_min, v_offer.send_max,
      v_offer.price_min_usd, v_offer.price_max_usd, v_base);
  END IF;

  IF v_base IS NULL OR v_base <= 0 THEN
    RAISE EXCEPTION 'Offer % has no usable price', p_offer_id;
  END IF;

  v_guard := public.guard_money_action('instant_refill', v_base, p_device_id, NULL, auth.uid());
  IF (v_guard ->> 'blocked')::boolean THEN
    RAISE EXCEPTION USING
      ERRCODE = 'KS451',
      MESSAGE = 'DEVICE_BLOCKED:' || COALESCE(v_guard ->> 'reason', 'unknown'),
      DETAIL  = 'device risk score ' || COALESCE(v_guard ->> 'score', '?'),
      HINT    = 'This payment was stopped by a security check on this device.';
  END IF;

  v_payer  := public.resolve_household_payer(auth.uid(), v_line_owner);
  v_acting := CASE WHEN v_payer <> auth.uid() THEN auth.uid() END;

  INSERT INTO public.topup_executions (
    sim_line_id, user_id, acting_user_id, amount, base_cost_usd, payment_gateway_code,
    currency, status, execution_type, execution_time, offer_id, offer_value,
    api_provider, attempted_providers
  ) VALUES (
    p_sim_line_id, v_payer, v_acting, v_base, v_base, p_payment_gateway_code,
    'USD', 'pending', 'refill_instant', now(), p_offer_id, v_value,
    v_pick.provider, ARRAY[v_pick.provider]
  )
  RETURNING id, amount INTO v_execution_id, v_charged;

  IF v_acting IS NOT NULL THEN
    SELECT * INTO v_chk
    FROM public.household_spend_check(v_payer, v_acting, v_charged, v_execution_id);

    IF NOT v_chk.allowed THEN
      RAISE EXCEPTION 'HOUSEHOLD_CAP:%:%:%:%',
        v_chk.reason, v_chk.monthly_cap, v_chk.spent_mtd, v_chk.remaining_usd
        USING ERRCODE = 'KS402';
    END IF;
  END IF;

  RETURN v_execution_id;
END;
$function$;

-- -----------------------------------------------------------------------------
-- 4. Failover — retry at the next supplier, tell the user only if it costs more
-- -----------------------------------------------------------------------------
ALTER TABLE public.topup_executions
  ADD COLUMN IF NOT EXISTS attempted_providers text[];

COMMENT ON COLUMN public.topup_executions.attempted_providers IS
  'I5: suppliers already tried for this top-up, so a failover never re-tries one that just failed.';

CREATE OR REPLACE FUNCTION public.retry_execution_at_next_supplier(p_execution_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_exec    RECORD;
  v_pick    RECORD;
  v_max     int;
  v_tol     numeric;
  v_new_id  uuid;
  v_delta   numeric;
BEGIN
  SELECT * INTO v_exec FROM public.topup_executions WHERE id = p_execution_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('retried', false, 'reason', 'not_found');
  END IF;

  v_max := public.config_numeric('SUPPLIER_RETRY_MAX_ATTEMPTS', 2, 1, 5)::int;
  v_tol := public.config_numeric('SUPPLIER_RETRY_SAME_COST_TOLERANCE_USD', 0.01, 0, 10);

  IF COALESCE(array_length(v_exec.attempted_providers, 1), 0) >= v_max THEN
    RETURN jsonb_build_object('retried', false, 'reason', 'max_attempts');
  END IF;

  -- Next best supplier, excluding everything already tried.
  SELECT * INTO v_pick
  FROM public.choose_supplier_for_offer(
    v_exec.sim_line_id, v_exec.offer_id, COALESCE(v_exec.attempted_providers, ARRAY[]::text[]));

  IF NOT FOUND THEN
    RETURN jsonb_build_object('retried', false, 'reason', 'no_alternative_supplier');
  END IF;

  INSERT INTO public.topup_executions (
    sim_line_id, user_id, acting_user_id, amount, base_cost_usd, payment_gateway_code,
    currency, status, execution_type, execution_time, offer_id, offer_value,
    api_provider, attempted_providers, retry_of, scheduled_topup_id
  ) VALUES (
    v_exec.sim_line_id, v_exec.user_id, v_exec.acting_user_id,
    v_pick.base_cost_usd, v_pick.base_cost_usd, v_exec.payment_gateway_code,
    'USD', 'pending', v_exec.execution_type, now(), v_exec.offer_id, v_exec.offer_value,
    v_pick.provider,
    COALESCE(v_exec.attempted_providers, ARRAY[]::text[]) || v_pick.provider,
    p_execution_id, v_exec.scheduled_topup_id
  )
  RETURNING id INTO v_new_id;

  v_delta := COALESCE(v_pick.base_cost_usd, 0) - COALESCE(v_exec.base_cost_usd, 0);

  -- "Inform the user unless it is the same cost." Same cost is a band, not an
  -- equality: two suppliers quoting 2.50 and 2.5000001 are the same price, and
  -- a notification for that is noise that trains people to ignore the real ones.
  IF abs(v_delta) > v_tol THEN
    INSERT INTO public.notifications (user_id, category, title, body, sim_line_id, action_url)
    VALUES (
      v_exec.user_id, 'system',
      CASE WHEN v_delta > 0 THEN 'Top-up retried at a slightly higher price'
           ELSE 'Top-up retried at a lower price' END,
      format('Your top-up could not be completed by the first supplier, so we are retrying it. The price changed from $%s to $%s.',
             to_char(COALESCE(v_exec.base_cost_usd,0), 'FM999990.00'),
             to_char(COALESCE(v_pick.base_cost_usd,0), 'FM999990.00')),
      v_exec.sim_line_id, '/sim-lines/detail/' || v_exec.sim_line_id::text
    );
  END IF;

  RETURN jsonb_build_object(
    'retried', true, 'new_execution_id', v_new_id, 'provider', v_pick.provider,
    'old_cost', v_exec.base_cost_usd, 'new_cost', v_pick.base_cost_usd,
    'user_notified', (abs(v_delta) > v_tol));
END;
$function$;

REVOKE ALL ON FUNCTION public.retry_execution_at_next_supplier(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.retry_execution_at_next_supplier(uuid) TO service_role;

-- The trigger that arms it. Off by default (`SUPPLIER_RETRY_ENABLED = false`).
CREATE OR REPLACE FUNCTION public.trg_fn_supplier_failover()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_on   text;
  v_skip text;
  v_pat  text;
BEGIN
  IF NEW.status <> 'failed' OR OLD.status = 'failed' THEN
    RETURN NEW;
  END IF;

  BEGIN
    SELECT config_value INTO v_on FROM public.system_configs WHERE config_key = 'SUPPLIER_RETRY_ENABLED';
  EXCEPTION WHEN OTHERS THEN v_on := NULL;
  END;
  IF lower(COALESCE(v_on, 'false')) <> 'true' THEN
    RETURN NEW;
  END IF;

  -- Do not retry a failure that will fail identically at any supplier. The
  -- patterns are a config row so support can add one at 3am without a deploy.
  BEGIN
    SELECT config_value INTO v_skip FROM public.system_configs WHERE config_key = 'SUPPLIER_RETRY_SKIP_REASONS';
  EXCEPTION WHEN OTHERS THEN v_skip := NULL;
  END;

  IF NEW.failure_reason IS NOT NULL AND COALESCE(v_skip, '') <> '' THEN
    FOREACH v_pat IN ARRAY string_to_array(v_skip, ',') LOOP
      IF btrim(v_pat) <> '' AND position(lower(btrim(v_pat)) in lower(NEW.failure_reason)) > 0 THEN
        RETURN NEW;
      END IF;
    END LOOP;
  END IF;

  -- Never let a failover error abort the failure write itself: the row must end
  -- up 'failed' even if the retry cannot be built. This is the ONLY place a
  -- catch-all is correct here, and it re-raises nothing on purpose.
  BEGIN
    PERFORM public.retry_execution_at_next_supplier(NEW.id);
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO public.system_alerts (kind, message, details, created_at)
    VALUES ('supplier_failover_failed',
            'Failover could not queue a retry for execution ' || NEW.id::text,
            jsonb_build_object('error', SQLERRM), now());
  END;

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.trg_fn_supplier_failover() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.trg_fn_supplier_failover() TO service_role;

DROP TRIGGER IF EXISTS trg_supplier_failover ON public.topup_executions;
CREATE TRIGGER trg_supplier_failover
  AFTER UPDATE OF status ON public.topup_executions
  FOR EACH ROW EXECUTE FUNCTION public.trg_fn_supplier_failover();

-- -----------------------------------------------------------------------------
-- 5. Admin surface
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_list_supplier_policy()
RETURNS TABLE (
  provider text, is_globally_enabled boolean, risk_premium_percent numeric,
  flat_penalty_usd numeric, success_count integer, failure_count integer,
  last_failure_at timestamptz, notes text,
  carriers_enabled bigint, offers_cached bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.assert_admin();
  RETURN QUERY
  SELECT sp.provider, sp.is_globally_enabled, sp.risk_premium_percent,
         sp.flat_penalty_usd, sp.success_count, sp.failure_count,
         sp.last_failure_at, sp.notes,
         (SELECT count(*) FROM public.carrier_provider_map m
          WHERE m.provider = sp.provider AND m.is_enabled),
         (SELECT count(*) FROM public.provider_offers_cache p
          WHERE p.api_provider = sp.provider)
  FROM public.supplier_policy sp
  ORDER BY sp.provider;
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_list_supplier_policy() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_supplier_policy() TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_update_supplier_policy(
  p_provider text,
  p_patch    jsonb,
  p_note     text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_key text;
  v_allowed text[] := ARRAY['is_globally_enabled','risk_premium_percent','flat_penalty_usd','notes'];
BEGIN
  PERFORM public.assert_admin();

  FOR v_key IN SELECT jsonb_object_keys(p_patch) LOOP
    IF NOT (v_key = ANY (v_allowed)) THEN
      RAISE EXCEPTION 'Unknown supplier_policy field: %', v_key USING ERRCODE = 'KS422';
    END IF;
  END LOOP;

  IF NOT EXISTS (SELECT 1 FROM public.supplier_policy WHERE provider = p_provider) THEN
    RAISE EXCEPTION 'Unknown supplier %', p_provider USING ERRCODE = 'KS404';
  END IF;

  UPDATE public.supplier_policy sp SET
    is_globally_enabled  = COALESCE((p_patch ->> 'is_globally_enabled')::boolean, sp.is_globally_enabled),
    risk_premium_percent = COALESCE((p_patch ->> 'risk_premium_percent')::numeric, sp.risk_premium_percent),
    flat_penalty_usd     = COALESCE((p_patch ->> 'flat_penalty_usd')::numeric, sp.flat_penalty_usd),
    notes                = CASE WHEN p_patch ? 'notes' THEN p_patch ->> 'notes' ELSE sp.notes END,
    updated_at           = now()
  WHERE sp.provider = p_provider;

  PERFORM public.admin_log('supplier_policy_update', 'supplier_policy', p_provider,
                           NULL::jsonb, p_patch, p_note);
  RETURN true;
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_update_supplier_policy(text, jsonb, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_supplier_policy(text, jsonb, text) TO authenticated, service_role;
