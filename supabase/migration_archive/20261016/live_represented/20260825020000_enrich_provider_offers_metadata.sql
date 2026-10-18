-- Migration: Add service_type, benefit_summary, data_mb, and duration_days to provider_offers_cache
-- and update list_refill_offers RPC

ALTER TABLE public.provider_offers_cache
  ADD COLUMN IF NOT EXISTS service_type text DEFAULT 'airtime',
  ADD COLUMN IF NOT EXISTS benefit_summary text,
  ADD COLUMN IF NOT EXISTS data_mb bigint,
  ADD COLUMN IF NOT EXISTS duration_days integer;

DROP FUNCTION IF EXISTS public.list_refill_offers(uuid);

CREATE OR REPLACE FUNCTION public.list_refill_offers(p_sim_line_id uuid)
 RETURNS TABLE(
   provider text,
   offer_id text,
   offer_name text,
   price_type text,
   price_fixed_usd numeric,
   price_min_usd numeric,
   price_max_usd numeric,
   send_min numeric,
   send_max numeric,
   send_currency text,
   send_currency_divisor numeric,
   refreshed_at timestamp with time zone,
   is_stale boolean,
   delivery_type text,
   service_type text,
   benefit_summary text,
   data_mb bigint,
   duration_days integer
 )
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

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
    (poc.refreshed_at < now() - interval '24 hours') AS is_stale,
    COALESCE(poc.delivery_type, 'direct') AS delivery_type,
    COALESCE(poc.service_type, 'airtime') AS service_type,
    COALESCE(poc.benefit_summary, poc.offer_name) AS benefit_summary,
    poc.data_mb,
    poc.duration_days
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
    coalesce(poc.price_fixed_usd, poc.price_min_usd) ASC NULLS LAST,
    m.priority ASC,
    poc.offer_id ASC;
END;
$function$;
