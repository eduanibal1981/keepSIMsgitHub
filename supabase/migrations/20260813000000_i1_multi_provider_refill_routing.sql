-- =============================================================================
-- I1 · Multi-provider refill routing
-- =============================================================================
-- WHY THIS EXISTS (proven live on 2026-08-04, not hypothesised):
--
--   `request_instant_refill` validated the chosen offer against
--   `zendit_offers_cache` — a view that is literally
--   `provider_offers_cache WHERE api_provider = 'zendit'` — and refused outright
--   when `carriers.zen_carrier IS NULL`.
--
--   Zain KSA is `api_provider = 'dtone'`, has **3** DTOne offers in
--   `provider_offers_cache`, and **1 live SIM line**. The Flutter client's
--   `fetchZenditOffers` is already provider-aware and lists those 3 offers.
--   The same three offers resolved to **0 rows** through the RPC's lookup, so
--   every tap returned `Offer % is not available for this SIM line`.
--   Instant refill on the only DTOne carrier has never once been able to work.
--
--   `worker_instant_refill.js` was never the problem: it already dispatches on
--   `topup_executions.api_provider` and already imports both provider adapters.
--   The break was one hardcoded view reference in one RPC.
--
-- WHAT THIS MIGRATION DOES
--   1. `carrier_provider_map` — one row per (carrier, provider) that *can*
--      fulfil that carrier, replacing the single-valued `carriers.api_provider`
--      as the routing source of truth. Backfilled so behaviour is byte-identical
--      to today: exactly the row matching `carriers.api_provider` is enabled.
--   2. `list_refill_offers()` — the offers a line can actually buy, unioned
--      across every ENABLED provider, cheapest first. The client stops doing
--      provider dispatch in Dart.
--   3. `pick_best_refill_offer()` — the same ranking reduced to one winner for a
--      target dollar amount. This is what auto/scheduled refills will call.
--   4. `request_instant_refill` — provider-agnostic, and it now STAMPS the
--      winning provider on the execution row.
--   5. `route_topup_execution()` — stops clobbering an explicitly-chosen
--      provider with the carrier default.
--
-- RANKING NOTE (do not re-derive): landed cost is
--   base + gateway%(base) + app%(base) + message_fee, per `calculate_topup_fees()`.
--   Every term is monotonic in `base_cost_usd` and the percentages do not vary
--   by supplier, so **ordering by base cost IS ordering by landed cost**. The
--   ranker deliberately does not duplicate the fee math — duplicating it is how
--   the quoted price and the charged price drift apart.
--
-- SIGNATURE NOTE (do not re-derive): `request_instant_refill` keeps its exact
--   5-arg signature. Adding `p_api_provider` would have created an OVERLOAD, not
--   a replacement, and PostgREST resolves overloads from body keys alone — the
--   D5b→F2b `PGRST203` trap that broke both money paths for eight days. The
--   provider is derived from the offer instead, which needs no new parameter and
--   no `f0_grant_matrix_tests.sql` allow-list churn.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. carrier_provider_map
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.carrier_provider_map (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  carrier_id            uuid NOT NULL REFERENCES public.carriers(id) ON DELETE CASCADE,
  provider              text NOT NULL CHECK (provider IN ('zendit', 'dtone', 'ding', 'reloadly')),
  provider_country_code text NOT NULL,
  provider_carrier_code text NOT NULL,
  is_enabled            boolean NOT NULL DEFAULT false,
  -- Tie-break only. Landed cost decides first; this settles exact ties so the
  -- winner is deterministic and a supplier outage can be de-prioritised without
  -- disabling it outright.
  priority              integer NOT NULL DEFAULT 100,
  last_verified_at      timestamptz,
  notes                 text,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  UNIQUE (carrier_id, provider)
);

CREATE INDEX IF NOT EXISTS idx_carrier_provider_map_lookup
  ON public.carrier_provider_map (carrier_id, is_enabled);

COMMENT ON TABLE public.carrier_provider_map IS
  'I1: which suppliers can fulfil a carrier. Supersedes the single-valued '
  'carriers.api_provider for routing. Enabling a second row is what turns on '
  'best-price selection for that carrier; nothing else has to change.';

-- Deny-all: this is supplier routing, it is nobody''s business on the client.
-- Reads happen through the SECURITY DEFINER RPCs below.
ALTER TABLE public.carrier_provider_map ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.carrier_provider_map FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.carrier_provider_map TO service_role;

-- Backfill. `is_enabled` reproduces today's routing EXACTLY: only the provider
-- that `carriers.api_provider` already names is live. Every other mapping is
-- recorded but off, so this migration cannot change a single price or route.
INSERT INTO public.carrier_provider_map
  (carrier_id, provider, provider_country_code, provider_carrier_code, is_enabled, priority, notes)
SELECT c.id, 'zendit', co.iso_code, c.zen_carrier,
       (lower(coalesce(c.api_provider, 'zendit')) = 'zendit'),
       10, 'I1 backfill from carriers.zen_carrier'
FROM public.carriers c
JOIN public.countries co ON co.id = c.country_id
WHERE c.zen_carrier IS NOT NULL
ON CONFLICT (carrier_id, provider) DO NOTHING;

INSERT INTO public.carrier_provider_map
  (carrier_id, provider, provider_country_code, provider_carrier_code, is_enabled, priority, notes)
SELECT c.id, 'dtone', co.iso_code, c.dt_carrier,
       (lower(coalesce(c.api_provider, 'zendit')) = 'dtone'),
       20, 'I1 backfill from carriers.dt_carrier'
FROM public.carriers c
JOIN public.countries co ON co.id = c.country_id
WHERE c.dt_carrier IS NOT NULL
ON CONFLICT (carrier_id, provider) DO NOTHING;

-- Both of these select 0 rows today (no carrier carries a Ding or Reloadly
-- code). They are here so that adding the codes is the ONLY step needed later.
INSERT INTO public.carrier_provider_map
  (carrier_id, provider, provider_country_code, provider_carrier_code, is_enabled, priority, notes)
SELECT c.id, 'ding', coalesce(c.ding_country, co.iso_code), c.ding_carrier,
       (lower(coalesce(c.api_provider, 'zendit')) = 'ding'),
       30, 'I1 backfill from carriers.ding_carrier'
FROM public.carriers c
JOIN public.countries co ON co.id = c.country_id
WHERE c.ding_carrier IS NOT NULL
ON CONFLICT (carrier_id, provider) DO NOTHING;

INSERT INTO public.carrier_provider_map
  (carrier_id, provider, provider_country_code, provider_carrier_code, is_enabled, priority, notes)
SELECT c.id, 'reloadly', co.iso_code, c.reloadly_operator_id,
       (lower(coalesce(c.api_provider, 'zendit')) = 'reloadly'),
       40, 'I1 backfill from carriers.reloadly_operator_id'
FROM public.carriers c
JOIN public.countries co ON co.id = c.country_id
WHERE c.reloadly_operator_id IS NOT NULL
ON CONFLICT (carrier_id, provider) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 2. list_refill_offers — every offer this line can buy, cheapest first
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.list_refill_offers(p_sim_line_id uuid)
RETURNS TABLE (
  provider              text,
  offer_id              text,
  offer_name            text,
  price_type            text,
  price_fixed_usd       numeric,
  price_min_usd         numeric,
  price_max_usd         numeric,
  send_min              numeric,
  send_max              numeric,
  send_currency         text,
  send_currency_divisor numeric,
  refreshed_at          timestamptz,
  is_stale              boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  -- Same visibility rule as request_instant_refill: own line, or a line in a
  -- household this caller manages. Keeping the two in step is the point —
  -- listing an offer the RPC will refuse is exactly the bug this migration fixes.
  IF NOT EXISTS (
    SELECT 1 FROM public.sim_lines sl
    WHERE sl.id = p_sim_line_id
      AND (sl.user_id = auth.uid()
           OR EXISTS (SELECT 1 FROM public.household_members hm
                      WHERE hm.owner_id = sl.user_id
                        AND hm.member_id = auth.uid()
                        AND hm.invite_status = 'accepted'
                        AND hm.role = 'manager'))
  ) THEN
    RAISE EXCEPTION 'Not authorized to read offers for this SIM line';
  END IF;

  RETURN QUERY
  SELECT
    poc.api_provider,
    poc.offer_id,
    poc.offer_name,
    poc.price_type,
    poc.price_fixed_usd,
    poc.price_min_usd,
    poc.price_max_usd,
    poc.send_min,
    poc.send_max,
    poc.send_currency,
    poc.send_currency_divisor,
    poc.refreshed_at,
    (poc.refreshed_at < now() - interval '24 hours') AS is_stale
  FROM public.sim_lines sl
  JOIN public.carrier_provider_map m
    ON m.carrier_id = sl.carrier_id
   AND m.is_enabled = true
  JOIN public.provider_offers_cache poc
    ON poc.api_provider  = m.provider
   AND poc.country_code  = m.provider_country_code
   AND poc.carrier_code  = m.provider_carrier_code
  WHERE sl.id = p_sim_line_id
  ORDER BY
    -- Cheapest entry price first; see the RANKING NOTE in the header for why
    -- base cost is a faithful proxy for landed cost.
    coalesce(poc.price_fixed_usd, poc.price_min_usd) ASC NULLS LAST,
    m.priority ASC,
    poc.offer_id ASC;
END;
$function$;

REVOKE ALL ON FUNCTION public.list_refill_offers(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_refill_offers(uuid) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 3. pick_best_refill_offer — one winner for a target amount
-- -----------------------------------------------------------------------------
-- Used by scheduled/auto refills, which have a dollar figure rather than a
-- user-tapped offer. Prefers the cheapest offer that can actually deliver the
-- target; falls back to the cheapest offer at all when nothing reaches it, so a
-- caller always gets a buyable answer or an explicit NULL.
CREATE OR REPLACE FUNCTION public.pick_best_refill_offer(
  p_sim_line_id uuid,
  p_target_usd  numeric
)
RETURNS TABLE (
  provider        text,
  offer_id        text,
  price_type      text,
  charge_usd      numeric,
  offer_value     numeric,
  reached_target  boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_row RECORD;
BEGIN
  IF p_target_usd IS NULL OR p_target_usd <= 0 THEN
    RAISE EXCEPTION 'Target amount must be positive';
  END IF;

  SELECT * INTO v_row
  FROM public.list_refill_offers(p_sim_line_id) o
  WHERE o.is_stale = false
    AND (
      (o.price_type = 'FIXED' AND o.price_fixed_usd >= p_target_usd)
      OR (o.price_type <> 'FIXED' AND o.price_max_usd >= p_target_usd
                                  AND o.price_min_usd <= p_target_usd)
    )
  ORDER BY
    CASE WHEN o.price_type = 'FIXED' THEN o.price_fixed_usd ELSE p_target_usd END ASC
  LIMIT 1;

  IF FOUND THEN
    RETURN QUERY SELECT
      v_row.provider,
      v_row.offer_id,
      v_row.price_type,
      CASE WHEN v_row.price_type = 'FIXED' THEN v_row.price_fixed_usd ELSE round(p_target_usd, 2) END,
      CASE WHEN v_row.price_type = 'FIXED' THEN NULL::numeric
           ELSE public.interpolate_offer_value(
                  v_row.send_min, v_row.send_max,
                  v_row.price_min_usd, v_row.price_max_usd, round(p_target_usd, 2)) END,
      true;
    RETURN;
  END IF;

  -- Nothing reaches the target. Return the cheapest buyable offer and say so,
  -- rather than returning nothing: G7's auto-rescue clamps UP to the carrier
  -- floor and needs a real offer to clamp to. A silent empty result there reads
  -- as "this line cannot be rescued".
  SELECT * INTO v_row
  FROM public.list_refill_offers(p_sim_line_id) o
  WHERE o.is_stale = false
  ORDER BY coalesce(o.price_fixed_usd, o.price_min_usd) ASC NULLS LAST
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  RETURN QUERY SELECT
    v_row.provider,
    v_row.offer_id,
    v_row.price_type,
    coalesce(v_row.price_fixed_usd, v_row.price_min_usd),
    CASE WHEN v_row.price_type = 'FIXED' THEN NULL::numeric ELSE v_row.send_min END,
    false;
END;
$function$;

REVOKE ALL ON FUNCTION public.pick_best_refill_offer(uuid, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pick_best_refill_offer(uuid, numeric) TO authenticated, service_role;

-- Shared with request_instant_refill so the RANGE→units maths exists once.
-- Previously this was inline in the RPC only; a second copy in the picker is how
-- a quote and a charge start disagreeing.
CREATE OR REPLACE FUNCTION public.interpolate_offer_value(
  p_send_min  numeric,
  p_send_max  numeric,
  p_price_min numeric,
  p_price_max numeric,
  p_price     numeric
)
RETURNS numeric
LANGUAGE sql
IMMUTABLE
SET search_path TO ''
AS $function$
  SELECT least(p_send_max, greatest(p_send_min, round(
    p_send_min
    + CASE WHEN p_price_max - p_price_min > 0
           THEN (p_price - p_price_min) * (p_send_max - p_send_min)
                / (p_price_max - p_price_min)
           ELSE 0 END)));
$function$;

REVOKE ALL ON FUNCTION public.interpolate_offer_value(numeric, numeric, numeric, numeric, numeric)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.interpolate_offer_value(numeric, numeric, numeric, numeric, numeric)
  TO service_role;

-- -----------------------------------------------------------------------------
-- 4. request_instant_refill — provider-agnostic
-- -----------------------------------------------------------------------------
-- Signature UNCHANGED (see SIGNATURE NOTE). Behaviour changes in exactly three
-- places, all marked `-- I1:` below.
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

  -- I1 (1 of 3): resolve the offer across EVERY enabled supplier for this
  -- carrier instead of against the zendit-only view. When the same offer_id is
  -- carried by more than one supplier, the cheapest wins and `priority` settles
  -- exact ties, so the choice is deterministic.
  SELECT poc.api_provider,
         poc.price_type,
         poc.price_fixed_usd,
         poc.price_min_usd,
         poc.price_max_usd,
         poc.send_min,
         poc.send_max,
         poc.refreshed_at
  INTO v_offer
  FROM public.sim_lines sl
  JOIN public.carrier_provider_map m
    ON m.carrier_id = sl.carrier_id
   AND m.is_enabled = true
  JOIN public.provider_offers_cache poc
    ON poc.api_provider = m.provider
   AND poc.country_code = m.provider_country_code
   AND poc.carrier_code = m.provider_carrier_code
  WHERE sl.id = p_sim_line_id
    AND poc.offer_id = p_offer_id
  ORDER BY coalesce(poc.price_fixed_usd, poc.price_min_usd) ASC NULLS LAST,
           m.priority ASC
  LIMIT 1;

  IF NOT FOUND THEN
    -- Distinguish "this carrier has no supplier at all" from "that offer is not
    -- one of them". The first is an owner/config problem, the second is a stale
    -- client. Merging them cost a session of debugging on the DTOne line.
    IF NOT EXISTS (
      SELECT 1 FROM public.sim_lines sl
      JOIN public.carrier_provider_map m ON m.carrier_id = sl.carrier_id AND m.is_enabled = true
      WHERE sl.id = p_sim_line_id
    ) THEN
      RAISE EXCEPTION 'This carrier has no online top-up catalog';
    END IF;
    RAISE EXCEPTION 'Offer % is not available for this SIM line', p_offer_id;
  END IF;

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

  -- I1 (2 of 3): stamp the winning supplier on the row. The worker dispatches on
  -- `topup_executions.api_provider`, so this is what makes a non-default
  -- supplier actually get bought from.
  INSERT INTO public.topup_executions (
    sim_line_id, user_id, acting_user_id, amount, base_cost_usd, payment_gateway_code,
    currency, status, execution_type, execution_time, offer_id, offer_value, api_provider
  ) VALUES (
    p_sim_line_id, v_payer, v_acting, v_base, v_base, p_payment_gateway_code,
    'USD', 'pending', 'refill_instant', now(), p_offer_id, v_value, v_offer.api_provider
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
-- 5. route_topup_execution — stop clobbering an explicit provider
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.route_topup_execution()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $function$
DECLARE
  v_gateway VARCHAR;
  v_api_provider VARCHAR;
BEGIN
  IF NEW.status IN ('pending', 'pending_payment', 'routing') AND NEW.fulfillment_gateway IS NULL THEN

    SELECT ca.fulfillment_gateway, ca.api_provider
    INTO v_gateway, v_api_provider
    FROM public.sim_lines sl
    JOIN public.carriers ca ON sl.carrier_id = ca.id
    WHERE sl.id = NEW.sim_line_id;

    IF v_gateway IS NULL THEN
      SELECT config_value
      INTO v_gateway
      FROM public.system_configs
      WHERE config_key = 'ACTIVE_FULFILLMENT_METHOD'
      LIMIT 1;

      IF v_gateway IS NULL THEN
        v_gateway := 'MANUAL';
      END IF;
    END IF;

    NEW.fulfillment_gateway := v_gateway;

    -- I1 (3 of 3): the carrier default is a FALLBACK now, not an override.
    -- request_instant_refill picks a supplier per offer; overwriting it here
    -- would send a DTOne purchase to Zendit.
    NEW.api_provider := COALESCE(NEW.api_provider, v_api_provider);

    IF NEW.execution_type = 'refill_instant' AND NEW.status = 'pending' THEN
      NEW.status := 'routing';
    END IF;

  END IF;

  RETURN NEW;
END;
$function$;

-- -----------------------------------------------------------------------------
-- 6. Keep carriers.api_provider honest
-- -----------------------------------------------------------------------------
-- `carriers.api_provider` remains the FALLBACK for rows that predate the map and
-- for scheduled refills that have not been migrated yet, so it must not drift
-- away from the map. This trigger mirrors an admin change in either direction.
CREATE OR REPLACE FUNCTION public.trg_fn_sync_carrier_default_provider()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.is_enabled AND NOT EXISTS (
    SELECT 1 FROM public.carriers c
    WHERE c.id = NEW.carrier_id AND lower(coalesce(c.api_provider, '')) = NEW.provider
  ) THEN
    -- Only adopt as the default when it is the ONLY enabled mapping; with two
    -- live suppliers the per-offer winner decides and the default is irrelevant.
    IF (SELECT count(*) FROM public.carrier_provider_map m
        WHERE m.carrier_id = NEW.carrier_id AND m.is_enabled) = 1 THEN
      UPDATE public.carriers SET api_provider = NEW.provider WHERE id = NEW.carrier_id;
    END IF;
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$function$;

-- H5c lesson: a trigger function created here gets `EXECUTE TO PUBLIC` by
-- default. Revoke it, or it is a callable SECURITY DEFINER for anon.
REVOKE ALL ON FUNCTION public.trg_fn_sync_carrier_default_provider() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.trg_fn_sync_carrier_default_provider() TO service_role;

DROP TRIGGER IF EXISTS trg_sync_carrier_default_provider ON public.carrier_provider_map;
CREATE TRIGGER trg_sync_carrier_default_provider
  BEFORE INSERT OR UPDATE ON public.carrier_provider_map
  FOR EACH ROW EXECUTE FUNCTION public.trg_fn_sync_carrier_default_provider();
