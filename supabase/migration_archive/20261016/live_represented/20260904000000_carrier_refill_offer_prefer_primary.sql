-- Migration: 20260904000000_carrier_refill_offer_prefer_primary.sql
-- Updates public.carrier_refill_offer to prioritize the carrier's primary supplier (is_primary = true),
-- then direct airtime delivery, then lowest price (cheapest within primary if primary exists,
-- else cheapest overall across non-primary suppliers), with priority rank as tie-breaker.

BEGIN;

CREATE OR REPLACE FUNCTION public.carrier_refill_offer(p_carrier_id uuid, p_min_usd numeric DEFAULT NULL::numeric)
 RETURNS TABLE(provider_code text, offer_code text, price_type text, price_usd numeric, supplier_cost_usd numeric, offer_value numeric, is_overridden boolean, is_stale boolean, delivery_type text, redeem_instructions text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  WITH floored AS (
    SELECT NULLIF(GREATEST(COALESCE(p_min_usd, 0),
                           COALESCE(public.carrier_qualifying_topup_amount(p_carrier_id), 0)), 0) AS min_usd
  )
  SELECT
    o.provider_code,
    o.offer_code,
    o.source_price_type,
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
    (o.source_refreshed_at < now() - interval '24 hours'),
    COALESCE(o.delivery_type, 'direct'),
    o.redeem_instructions
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
    -- 1. Primary provider first
    CASE WHEN r.is_primary THEN 0 ELSE 1 END ASC,
    -- 2. Prefer direct airtime recharge over PIN voucher
    CASE WHEN COALESCE(o.delivery_type, 'direct') = 'direct' THEN 0 ELSE 1 END ASC,
    -- 3. Lowest price (cheapest within primary if primary exists, else cheapest overall)
    CASE WHEN o.source_price_type = 'RANGE'
         THEN GREATEST(o.source_price_min_usd,
                       LEAST(o.source_price_max_usd, COALESCE(f.min_usd, o.source_price_min_usd)))
         ELSE o.effective_price_usd END ASC,
    -- 4. Priority tie-breaker
    r.priority ASC,
    -- 5. Offer code tie-breaker
    o.offer_code ASC
  LIMIT 1;
$function$;

REVOKE ALL ON FUNCTION public.carrier_refill_offer(uuid, numeric) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.carrier_refill_offer(uuid, numeric) TO service_role;

COMMENT ON FUNCTION public.carrier_refill_offer(uuid, numeric) IS
  'Evaluates Primary provider first (is_primary = true), then Direct airtime over PIN voucher, '
  'then lowest price (cheapest within primary, or cheapest overall if no primary), with priority rank as tie-breaker.';

COMMIT;
