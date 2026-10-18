-- =============================================================================
-- K10 · A top-up may never be quoted below the amount that makes it count
-- =============================================================================
-- Four independent hand-typed numbers answer "how much should we top up?", and
-- three of them can sit BELOW the amount the carrier requires for the top-up to
-- reset its validity clock:
--
--   carrier_rules.recommended_topup_amount        24 of 67 below
--   carriers.default_refill_amount                21 of 67 below
--   offline_refill_settings.default_refill_amount  2 of 2  below
--   carrier_rules.inapp_pricing                    0 — K3 already floors it
--
-- STC is the clearest case: minimum 6.25, recommended 2.00. Spending $2.00 buys
-- airtime and keeps the line no more alive, because it does not qualify. And
-- `recommended` has only 14 distinct values across 67 carriers with 2.00
-- repeated 8 times — the signature of a seed default nobody filled in, exactly
-- like the offer_id/minimum divergence that broke premium refills.
--
-- WHERE IT REACHED: compute_usage_forecasts() picks
--   COALESCE(median_amount, recommended_topup_amount, minimum_topup_amount)
-- into sim_line_usage_forecast.suggested_amount_usd, which drives both the
-- refill suggestion in the app AND the floor run_auto_rescue hands to
-- carrier_refill_offer() when it auto-buys to save a dying line.
--
-- FIXING EACH CALL SITE WOULD RE-CREATE THE PROBLEM. There would be four floors
-- to keep in step, and the fifth caller would forget. Both guards below sit at a
-- CHOKE POINT instead, so a caller may ask for MORE than the qualifying amount
-- and can no longer ask for less.
--
-- DELIBERATELY NOT DONE: the 45 wrong numbers are left as they are. Rewriting
-- them would mean inventing values nobody researched — the same fault as the
-- fabricated catalogue this phase removed. The floors make them harmless, and
-- admin_list_carriers.pricing_problem surfaces each one for a human to correct.
-- =============================================================================

-- One definition of "the amount that makes a top-up count", so the four callers
-- cannot drift apart. NULL when the carrier has no rule — no rule, no floor.
CREATE OR REPLACE FUNCTION public.carrier_qualifying_topup_amount(p_carrier_id uuid)
RETURNS numeric
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT COALESCE(cr.validity_qualifying_topup_amount, cr.minimum_topup_amount)
  FROM public.carrier_rules cr
  WHERE cr.carrier_id = p_carrier_id
  ORDER BY cr.updated_at DESC NULLS LAST
  LIMIT 1;
$function$;

REVOKE ALL ON FUNCTION public.carrier_qualifying_topup_amount(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.carrier_qualifying_topup_amount(uuid) TO service_role;

COMMENT ON FUNCTION public.carrier_qualifying_topup_amount(uuid) IS
  'K10: the smallest top-up that resets this carrier''s validity clock — '
  'validity_qualifying_topup_amount when set, else minimum_topup_amount. The one '
  'definition every floor uses.';

-- -----------------------------------------------------------------------------
-- 1. Purchases: carrier_refill_offer enforces the floor itself
-- -----------------------------------------------------------------------------
-- Every money path already funnels through here — premium queueing, plan
-- pricing, auto-rescue and offline refill. Flooring inside means a caller
-- passing a stale `recommended` or a user's `default_refill_amount` can no
-- longer buy something that does not qualify.
CREATE OR REPLACE FUNCTION public.carrier_refill_offer(
  p_carrier_id uuid, p_min_usd numeric DEFAULT NULL::numeric)
RETURNS TABLE (provider_code text, offer_code text, price_type text, price_usd numeric,
               supplier_cost_usd numeric, offer_value numeric, is_overridden boolean, is_stale boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  WITH floored AS (
    -- The caller's request, raised to the qualifying amount if it fell short.
    -- NULLIF(...,0) keeps "no constraint at all" meaning exactly that.
    SELECT NULLIF(GREATEST(COALESCE(p_min_usd, 0),
                           COALESCE(public.carrier_qualifying_topup_amount(p_carrier_id), 0)), 0) AS min_usd
  )
  SELECT
    o.provider_code, o.offer_code, o.source_price_type,
    CASE WHEN o.source_price_type = 'RANGE'
         THEN GREATEST(o.source_price_min_usd,
                       LEAST(o.source_price_max_usd, COALESCE(f.min_usd, o.source_price_min_usd)))
         ELSE o.effective_price_usd END,
    o.source_price_usd,
    CASE WHEN o.source_price_type = 'RANGE' AND o.source_price_max_usd > o.source_price_min_usd
         THEN round(o.source_send_min
                    + (GREATEST(o.source_price_min_usd,
                        LEAST(o.source_price_max_usd, COALESCE(f.min_usd, o.source_price_min_usd)))
                       - o.source_price_min_usd)
                      * (o.source_send_max - o.source_send_min)
                      / (o.source_price_max_usd - o.source_price_min_usd))
         ELSE NULL END,
    (o.override_price_usd IS NOT NULL),
    (o.source_refreshed_at < now() - interval '24 hours')
  FROM public.provider_offers o
  CROSS JOIN floored f
  JOIN public.carrier_supplier_routing r
    ON r.carrier_id = o.carrier_id AND r.provider_code = o.provider_code
  WHERE o.offer_kind = 'topup' AND o.carrier_id = p_carrier_id AND o.is_active
    AND r.is_routable
    AND (f.min_usd IS NULL
         OR (o.source_price_type = 'RANGE' AND o.source_price_max_usd >= f.min_usd)
         OR (o.source_price_type = 'FIXED' AND o.effective_price_usd  >= f.min_usd))
  ORDER BY
    CASE WHEN o.source_price_type = 'RANGE'
         THEN GREATEST(o.source_price_min_usd,
                       LEAST(o.source_price_max_usd, COALESCE(f.min_usd, o.source_price_min_usd)))
         ELSE o.effective_price_usd END ASC,
    r.priority ASC, o.offer_code ASC
  LIMIT 1;
$function$;

REVOKE ALL ON FUNCTION public.carrier_refill_offer(uuid, numeric) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.carrier_refill_offer(uuid, numeric) TO service_role;

COMMENT ON FUNCTION public.carrier_refill_offer(uuid, numeric) IS
  'K2/K10: the cheapest routable top-up offer for a carrier. p_min_usd is raised '
  'to carrier_qualifying_topup_amount() — a caller may ask for MORE, never less, '
  'so a stale recommended_topup_amount cannot buy a top-up that does not qualify.';

-- -----------------------------------------------------------------------------
-- 2. Display: the forecast's suggestion is floored on write
-- -----------------------------------------------------------------------------
-- Any of the three COALESCE candidates can fall short — the median too, if the
-- line's own history is small top-ups. A trigger floors whatever is written, so
-- this holds for any future writer as well, not only today's one.
CREATE OR REPLACE FUNCTION public.trg_fn_floor_forecast_suggestion()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_floor numeric;
BEGIN
  IF NEW.sim_line_id IS NULL OR NEW.suggested_amount_usd IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT public.carrier_qualifying_topup_amount(sl.carrier_id)
  INTO v_floor
  FROM public.sim_lines sl
  WHERE sl.id = NEW.sim_line_id;

  IF v_floor IS NOT NULL AND NEW.suggested_amount_usd < v_floor THEN
    -- Suggesting less than the qualifying amount tells someone to spend money
    -- that keeps their line no more alive. Raising is the only safe direction.
    NEW.suggested_amount_usd := v_floor;
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.trg_fn_floor_forecast_suggestion() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_floor_forecast_suggestion ON public.sim_line_usage_forecast;
CREATE TRIGGER trg_floor_forecast_suggestion
  BEFORE INSERT OR UPDATE ON public.sim_line_usage_forecast
  FOR EACH ROW EXECUTE FUNCTION public.trg_fn_floor_forecast_suggestion();
