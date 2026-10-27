-- Follow-up to ESIM-02 live acceptance: minimum fees must appear in filter bounds.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $preflight$ BEGIN
  IF md5(pg_get_functiondef('public.compare_esim_filter_bounds(text)'::regprocedure))
       <> '449d54ccfef6242345517283c06fc57e' THEN
    RAISE EXCEPTION 'ESIM-02 bounds source drift: inspect before applying';
  END IF;
END $preflight$;
CREATE OR REPLACE FUNCTION public.compare_esim_filter_bounds(p_country_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_iso          text := upper(trim(COALESCE(p_country_code, '')));
  v_affiliate_on boolean := false;
  v_result       jsonb;
  v_user_id      uuid := auth.uid();
  v_tier         text := 'free';
  v_tier_markup  numeric := 10.0;
BEGIN
  IF v_iso = '' THEN
    RETURN jsonb_build_object('durations', '[]'::jsonb, 'data_mb', '[]'::jsonb,
                              'min_price_usd', NULL, 'max_price_usd', NULL,
                              'has_unlimited', false);
  END IF;

  IF v_user_id IS NOT NULL THEN
    v_tier := public.resolve_account_commerce_benefit(v_user_id);
  END IF;

  SELECT 
    CASE v_tier
      WHEN 'premium'  THEN prem_percentage
      WHEN 'standard' THEN stand_percentage
      ELSE free_percentage
    END INTO v_tier_markup
  FROM public.app_fee_rules
  WHERE appfees_item = 'esimofferfee'
    AND status = 'published'
  ORDER BY version DESC
  LIMIT 1;

  IF v_tier_markup IS NULL THEN
    SELECT 
      CASE v_tier
        WHEN 'premium'  THEN prem_percentage
        WHEN 'standard' THEN stand_percentage
        ELSE free_percentage
      END INTO v_tier_markup
    FROM public.app_fee_rules
    WHERE appfees_item = 'esimofferfee'
    ORDER BY version DESC
    LIMIT 1;
  END IF;

  IF v_tier_markup IS NULL THEN
    v_tier_markup := CASE v_tier
      WHEN 'premium'  THEN 5.0
      WHEN 'standard' THEN 7.0
      ELSE 10.0
    END;
  END IF;

  SELECT COALESCE(NULLIF(config_value, '')::boolean, false) INTO v_affiliate_on
    FROM system_configs WHERE config_key = 'AFFILIATE_ENABLED';
  v_affiliate_on := COALESCE(v_affiliate_on, false);

  WITH pool AS (
    SELECT c.duration_days, c.data_amount_mb, c.is_unlimited,
           public.resolve_esim_offer_price(c.wholesale_price_usd, v_user_id)::numeric(10,2) AS price_usd
      FROM esim_offers_cache c
      JOIN esim_suppliers s ON s.code = c.provider AND s.is_active = true
     WHERE c.is_active = true
       AND c.countries @> ARRAY[v_iso]
    UNION ALL
    SELECT ao.duration_days, ao.data_amount_mb, ao.is_unlimited, ao.price_usd
      FROM affiliate_offers ao
      JOIN affiliate_partners ap ON ap.id = ao.partner_id
     WHERE v_affiliate_on AND ao.is_active AND ap.is_active
       AND ap.disclosure_required IS NOT NULL
       AND ao.countries @> ARRAY[v_iso]
  )
  SELECT jsonb_build_object(
    'durations', COALESCE((
      SELECT jsonb_agg(DISTINCT d ORDER BY d)
        FROM (SELECT duration_days AS d FROM pool WHERE duration_days > 0) x
    ), '[]'::jsonb),
    'data_mb', COALESCE((
      SELECT jsonb_agg(DISTINCT mb ORDER BY mb)
        FROM (SELECT data_amount_mb AS mb FROM pool
               WHERE NOT is_unlimited AND data_amount_mb > 0) y
    ), '[]'::jsonb),
    'min_price_usd', (SELECT round(min(price_usd), 2) FROM pool),
    'max_price_usd', (SELECT round(max(price_usd), 2) FROM pool),
    'has_unlimited', EXISTS (SELECT 1 FROM pool WHERE is_unlimited)
  ) INTO v_result;

  RETURN v_result;
END;
$function$;
NOTIFY pgrst, 'reload schema';
COMMIT;
