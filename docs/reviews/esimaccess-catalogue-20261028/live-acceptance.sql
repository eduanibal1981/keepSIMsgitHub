BEGIN;
SELECT set_config('request.jwt.claim.sub','80000000-0000-4000-8000-000000000028',true);
SELECT set_config('request.jwt.claims','{"sub":"80000000-0000-4000-8000-000000000028","role":"authenticated","app_metadata":{"is_power_user":false}}',true);
SET LOCAL ROLE authenticated;
DO $accept$
DECLARE b jsonb; expected jsonb;
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.compare_esim_offers_v2('OM',p_limit=>200) n
    FULL JOIN public.compare_esim_offers('OM',p_limit=>200) o
    ON n.offer_kind=o.offer_kind AND n.offer_id=o.offer_id AND n.source_code=o.source_code
    WHERE n.offer_id IS NULL OR o.offer_id IS NULL OR n.price_usd IS DISTINCT FROM o.price_usd
      OR n.data_amount_mb IS DISTINCT FROM o.data_amount_mb OR n.is_unlimited IS DISTINCT FROM o.is_unlimited
  ) THEN RAISE EXCEPTION 'Legacy and v2 comparison differ'; END IF;
  IF EXISTS (
    SELECT 1 FROM public.compare_esim_offers_v2('OM',p_limit=>200) n
    LEFT JOIN public.esim_offers v ON v.id=n.source_code||'_'||n.offer_id
    WHERE n.offer_kind='resale' AND (v.id IS NULL OR v.retail_price_usd IS DISTINCT FROM n.price_usd)
  ) THEN RAISE EXCEPTION 'Comparison and checkout-view price differ'; END IF;
  IF EXISTS (SELECT 1 FROM public.compare_esim_offers_v2('OM',p_plan_types=>ARRAY['daily_throttled'],p_limit=>200)
    WHERE catalogue_details->>'plan_type' IS DISTINCT FROM 'daily_throttled' OR is_unlimited OR price_per_gb_usd IS NOT NULL) THEN
    RAISE EXCEPTION 'Daily filter/allowance semantics invalid'; END IF;
  IF EXISTS (SELECT 1 FROM public.compare_esim_offers_v2('OM',p_unlimited_only=>true) WHERE NOT is_unlimited) THEN
    RAISE EXCEPTION 'Unsupported unlimited claim'; END IF;
  WITH offers AS MATERIALIZED (SELECT * FROM public.compare_esim_offers_v2('OM',p_limit=>200))
  SELECT jsonb_build_object(
    'durations',COALESCE((SELECT jsonb_agg(d ORDER BY d) FROM (SELECT DISTINCT duration_days d FROM offers WHERE duration_days>0) x),'[]'::jsonb),
    'data_mb',COALESCE((SELECT jsonb_agg(mb ORDER BY mb) FROM (SELECT DISTINCT data_amount_mb mb FROM offers WHERE NOT is_unlimited AND data_amount_mb>0) x),'[]'::jsonb),
    'min_price_usd',(SELECT round(min(price_usd),2) FROM offers),
    'max_price_usd',(SELECT round(max(price_usd),2) FROM offers),
    'has_unlimited',EXISTS(SELECT 1 FROM offers WHERE is_unlimited)) INTO expected;
  b:=public.compare_esim_filter_bounds('OM');
  IF b IS DISTINCT FROM expected THEN RAISE EXCEPTION 'Filter bounds and current comparison differ'; END IF;
  BEGIN
    PERFORM provider_values FROM public.esim_offers_cache LIMIT 1;
    RAISE EXCEPTION 'Raw provider values exposed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    PERFORM public.admin_esim_catalogue_diagnostics();
    RAISE EXCEPTION 'Non-admin diagnostics exposed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
    WHEN SQLSTATE 'KS460' THEN NULL;
    WHEN raise_exception THEN IF SQLERRM='Non-admin diagnostics exposed' THEN RAISE; END IF;
  END;
END $accept$;
RESET ROLE;
SET LOCAL ROLE anon;
DO $accept$ BEGIN
  PERFORM * FROM public.esim_offers LIMIT 1;
  BEGIN
    PERFORM * FROM public.compare_esim_offers_v2('OM');
    RAISE EXCEPTION 'Anonymous v2 execution exposed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $accept$;
RESET ROLE;
ROLLBACK;
SELECT 'PASS: authenticated old/v2 prices, plan types, bounds, retail view and role denials; read-only transaction rolled back' as status;
