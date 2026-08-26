-- Migration: 20260825010000_m1_pin_voucher_fallback.sql
-- Enables DTOne PIN voucher fallback when no direct recharge offer is available,
-- and updates carrier_refill_offer to prioritize direct recharge.

BEGIN;

-- 1. Extend provider_offers_cache and provider_offers with delivery_type and redeem_instructions
ALTER TABLE public.provider_offers_cache
  ADD COLUMN IF NOT EXISTS delivery_type text DEFAULT 'direct',
  ADD COLUMN IF NOT EXISTS redeem_instructions text;

ALTER TABLE public.provider_offers
  ADD COLUMN IF NOT EXISTS delivery_type text DEFAULT 'direct',
  ADD COLUMN IF NOT EXISTS redeem_instructions text;

-- 2. Update admin_refresh_provider_offers to sync delivery_type and redeem_instructions
CREATE OR REPLACE FUNCTION public.admin_refresh_provider_offers(p_reason text DEFAULT 'manual_refresh')
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_topup integer := 0; v_esim integer := 0; v_retired integer := 0;
  v_src_top integer; v_src_esim integer;
BEGIN
  SELECT count(*) INTO v_src_top  FROM public.provider_offers_cache;
  SELECT count(*) INTO v_src_esim FROM public.esim_offers_cache WHERE is_active;

  IF v_src_top = 0 AND v_src_esim = 0 THEN
    RETURN jsonb_build_object('status', 'skipped',
      'reason', 'both upstream caches are empty — refusing to retire the catalogue');
  END IF;

  IF v_src_top > 0 THEN
    INSERT INTO public.provider_offers AS po (
      provider_code, offer_kind, offer_code, country_code, carrier_id,
      source_name, source_price_type, source_price_usd,
      source_price_min_usd, source_price_max_usd,
      source_send_min, source_send_max, source_send_currency, source_send_divisor,
      source_is_active, source_refreshed_at,
      source_currency, source_amount_native, fx_usd_to_local,
      delivery_type, redeem_instructions)
    SELECT DISTINCT ON (p.api_provider, p.offer_id, co.iso_code, m.carrier_id)
      p.api_provider, 'topup', p.offer_id, co.iso_code, m.carrier_id,
      p.offer_name, p.price_type, COALESCE(p.price_fixed_usd, p.price_min_usd),
      p.price_min_usd, p.price_max_usd,
      p.send_min, p.send_max, p.send_currency, p.send_currency_divisor,
      true, p.refreshed_at,
      p.source_currency, p.source_amount_native, p.fx_usd_to_local,
      COALESCE(p.delivery_type, 'direct'), p.redeem_instructions
    FROM public.provider_offers_cache p
    JOIN public.carrier_provider_map m
      ON m.provider = p.api_provider
     AND m.provider_country_code = p.country_code
     AND m.provider_carrier_code = p.carrier_code
    JOIN public.carriers c ON c.id = m.carrier_id
    JOIN public.countries co ON co.id = c.country_id
    ORDER BY p.api_provider, p.offer_id, co.iso_code, m.carrier_id,
             m.is_primary DESC, m.priority ASC
    ON CONFLICT (provider_code, offer_kind, offer_code, country_code,
                 COALESCE(carrier_id, '00000000-0000-0000-0000-000000000000'::uuid))
    DO UPDATE SET
      source_name = EXCLUDED.source_name, source_price_type = EXCLUDED.source_price_type,
      source_price_usd = EXCLUDED.source_price_usd,
      source_price_min_usd = EXCLUDED.source_price_min_usd,
      source_price_max_usd = EXCLUDED.source_price_max_usd,
      source_send_min = EXCLUDED.source_send_min, source_send_max = EXCLUDED.source_send_max,
      source_send_currency = EXCLUDED.source_send_currency,
      source_send_divisor = EXCLUDED.source_send_divisor,
      source_is_active = true, source_refreshed_at = EXCLUDED.source_refreshed_at,
      source_currency = EXCLUDED.source_currency,
      source_amount_native = EXCLUDED.source_amount_native,
      fx_usd_to_local = EXCLUDED.fx_usd_to_local,
      delivery_type = EXCLUDED.delivery_type,
      redeem_instructions = EXCLUDED.redeem_instructions,
      updated_at = now();
    GET DIAGNOSTICS v_topup = ROW_COUNT;
  END IF;

  IF v_src_esim > 0 THEN
    INSERT INTO public.provider_offers AS po (
      provider_code, offer_kind, offer_code, country_code, carrier_id,
      source_name, source_price_type, source_price_usd,
      source_data_mb, source_duration_days, source_is_unlimited, source_speed_tier,
      source_is_active, source_refreshed_at, delivery_type)
    SELECT DISTINCT ON (e.provider, e.bundle_name, co.iso_code)
      e.provider, 'esim', e.bundle_name, co.iso_code, NULL::uuid,
      COALESCE(e.description, e.bundle_name), 'FIXED', e.wholesale_price_usd,
      CASE WHEN e.is_unlimited OR e.data_amount_mb <= 0 THEN NULL ELSE e.data_amount_mb END,
      NULLIF(e.duration_days, 0), e.is_unlimited, e.speed_tier,
      true, e.updated_at, 'esim'
    FROM public.esim_offers_cache e
    JOIN public.countries co
      ON co.iso_code = ANY (e.countries) OR co.iso_code = ANY (e.roaming_enabled)
    WHERE e.is_active
    ORDER BY e.provider, e.bundle_name, co.iso_code, e.updated_at DESC
    ON CONFLICT (provider_code, offer_kind, offer_code, country_code,
                 COALESCE(carrier_id, '00000000-0000-0000-0000-000000000000'::uuid))
    DO UPDATE SET
      source_name = EXCLUDED.source_name, source_price_usd = EXCLUDED.source_price_usd,
      source_data_mb = EXCLUDED.source_data_mb,
      source_duration_days = EXCLUDED.source_duration_days,
      source_is_unlimited = EXCLUDED.source_is_unlimited,
      source_speed_tier = EXCLUDED.source_speed_tier,
      source_is_active = true, source_refreshed_at = EXCLUDED.source_refreshed_at,
      delivery_type = 'esim',
      updated_at = now();
    GET DIAGNOSTICS v_esim = ROW_COUNT;
  END IF;

  UPDATE public.provider_offers o
     SET source_is_active = false, updated_at = now()
   WHERE o.source_is_active
     AND ((o.offer_kind = 'topup' AND v_src_top > 0
           AND NOT EXISTS (
             SELECT 1 FROM public.provider_offers_cache p
              JOIN public.carrier_provider_map m
                ON m.provider = p.api_provider
               AND m.provider_country_code = p.country_code
               AND m.provider_carrier_code = p.carrier_code
             WHERE p.offer_id = o.offer_code
               AND p.country_code = o.country_code
               AND m.carrier_id = o.carrier_id))
       OR (o.offer_kind = 'esim' AND v_src_esim > 0
           AND NOT EXISTS (
             SELECT 1 FROM public.esim_offers_cache e
              JOIN public.countries co
                ON co.iso_code = ANY (e.countries) OR co.iso_code = ANY (e.roaming_enabled)
             WHERE e.bundle_name = o.offer_code
               AND co.iso_code = o.country_code
               AND e.is_active)));
  GET DIAGNOSTICS v_retired = ROW_COUNT;

  RETURN jsonb_build_object(
    'status', 'ok',
    'reason', p_reason,
    'topup_offers_updated', v_topup,
    'esim_offers_updated', v_esim,
    'offers_retired', v_retired
  );
END;
$function$;

-- 3. Update carrier_refill_offer to prioritize direct recharge, then fallback to PIN
CREATE OR REPLACE FUNCTION public.carrier_refill_offer(
  p_carrier_id uuid, p_min_usd numeric DEFAULT NULL::numeric)
RETURNS TABLE (
  provider_code text,
  offer_code text,
  price_type text,
  price_usd numeric,
  supplier_cost_usd numeric,
  offer_value numeric,
  is_overridden boolean,
  is_stale boolean,
  delivery_type text,
  redeem_instructions text
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
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
    -- 1. Prefer direct airtime recharge over PIN voucher
    CASE WHEN COALESCE(o.delivery_type, 'direct') = 'direct' THEN 0 ELSE 1 END ASC,
    -- 2. Lowest price
    CASE WHEN o.source_price_type = 'RANGE'
         THEN GREATEST(o.source_price_min_usd,
                       LEAST(o.source_price_max_usd, COALESCE(f.min_usd, o.source_price_min_usd)))
         ELSE o.effective_price_usd END ASC,
    r.priority ASC, o.offer_code ASC
  LIMIT 1;
$function$;

REVOKE ALL ON FUNCTION public.carrier_refill_offer(uuid, numeric) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.carrier_refill_offer(uuid, numeric) TO service_role;

-- 4. Enable DT One for Mobily in carrier_provider_map with priority 20
UPDATE public.carrier_provider_map
   SET is_enabled = true,
       notes = 'DTOne PIN voucher fallback enabled. Direct recharges take priority if available.',
       updated_at = now()
 WHERE provider = 'dtone'
   AND provider_country_code = 'SAU'
   AND provider_carrier_code = '3220';

COMMIT;
