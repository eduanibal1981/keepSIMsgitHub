-- ============================================================================
-- Migration: 20260910023500_p4_tier_aware_compare_esim_offers.sql
-- Description: Update compare_esim_offers and compare_esim_filter_bounds
--              to apply tier-aware pricing via resolve_account_commerce_benefit(auth.uid())
--              and app_fee_rules (esimofferfee: Free +10%, Standard +7%, Premium +5%).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.compare_esim_offers(
  p_country_code text,
  p_coverage text DEFAULT NULL::text,
  p_min_data_mb bigint DEFAULT NULL::bigint,
  p_min_days integer DEFAULT NULL::integer,
  p_max_price_usd numeric DEFAULT NULL::numeric,
  p_unlimited_only boolean DEFAULT false,
  p_speed_tiers text[] DEFAULT NULL::text[],
  p_sort text DEFAULT 'price'::text,
  p_limit integer DEFAULT 60,
  p_offset integer DEFAULT 0,
  p_max_data_mb bigint DEFAULT NULL::bigint,
  p_data_exact_mb bigint[] DEFAULT NULL::bigint[],
  p_max_days integer DEFAULT NULL::integer,
  p_days_exact integer[] DEFAULT NULL::integer[],
  p_min_price_usd numeric DEFAULT NULL::numeric
)
RETURNS TABLE(
  offer_kind text,
  offer_id text,
  source_code text,
  source_name text,
  logo_url text,
  title text,
  description text,
  countries text[],
  country_count integer,
  data_amount_mb bigint,
  is_unlimited boolean,
  duration_days integer,
  speed_tier text,
  price_usd numeric,
  list_price_usd numeric,
  price_per_gb_usd numeric,
  coupon_code text,
  coupon_description text,
  image_url text,
  action text,
  price_is_stale boolean,
  disclosure_required boolean
)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_iso           text := upper(trim(COALESCE(p_country_code, '')));
  v_affiliate_on  boolean := false;
  v_max_age_days  integer := 14;
  v_limit         integer := LEAST(GREATEST(COALESCE(p_limit, 60), 1), 200);
  v_offset        integer := GREATEST(COALESCE(p_offset, 0), 0);
  v_sort          text := lower(COALESCE(p_sort, 'price'));
  v_days_exact    integer[] := NULLIF(p_days_exact, '{}');
  v_data_exact    bigint[]  := NULLIF(p_data_exact_mb, '{}');
  v_user_id       uuid := auth.uid();
  v_tier          text := 'free';
  v_tier_markup   numeric := 10.0;
BEGIN
  IF v_iso = '' THEN
    RETURN;
  END IF;

  -- 1. Derive user's commerce benefit tier (Halo effect)
  IF v_user_id IS NOT NULL THEN
    v_tier := public.resolve_account_commerce_benefit(v_user_id);
  END IF;

  -- 2. Resolve tier markup from app_fee_rules
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

  SELECT COALESCE(NULLIF(config_value, '')::integer, 14) INTO v_max_age_days
    FROM system_configs WHERE config_key = 'AFFILIATE_PRICE_MAX_AGE_DAYS';
  v_max_age_days := COALESCE(v_max_age_days, 14);

  RETURN QUERY
  WITH resale AS (
    SELECT
      'resale'::text            AS offer_kind,
      c.bundle_name             AS offer_id,
      c.provider                AS source_code,
      COALESCE(s.name, c.provider) AS source_name,
      NULL::text                AS logo_url,
      COALESCE(NULLIF(c.description, ''), c.bundle_name) AS title,
      c.description,
      c.countries,
      c.country_count,
      c.data_amount_mb,
      c.is_unlimited,
      c.duration_days,
      c.speed_tier,
      round(c.wholesale_price_usd * (1.0 + (v_tier_markup / 100.0)), 2)::numeric(10,2) AS price_usd,
      NULL::numeric             AS list_price_usd,
      CASE
        WHEN c.is_unlimited OR c.data_amount_mb <= 0 THEN NULL::numeric
        ELSE round(round(c.wholesale_price_usd * (1.0 + (v_tier_markup / 100.0)), 2) / (c.data_amount_mb::numeric / 1024.0), 2)
      END::numeric(10,2)        AS price_per_gb_usd,
      NULL::text                AS coupon_code,
      NULL::text                AS coupon_description,
      c.image_url,
      'buy_in_app'::text        AS action,
      false                     AS price_is_stale,
      false                     AS disclosure_required
    FROM esim_offers_cache c
    LEFT JOIN esim_suppliers s ON s.code = c.provider
    WHERE c.is_active = true
      AND c.countries @> ARRAY[v_iso]
  ),
  affil AS (
    SELECT
      'affiliate'::text         AS offer_kind,
      ao.id::text               AS offer_id,
      ap.code                   AS source_code,
      ap.display_name           AS source_name,
      ap.logo_url,
      ao.title,
      ao.description,
      ao.countries,
      ao.country_count,
      ao.data_amount_mb,
      ao.is_unlimited,
      ao.duration_days,
      ao.speed_tier,
      ao.price_usd,
      ao.list_price_usd,
      CASE
        WHEN ao.is_unlimited OR ao.data_amount_mb <= 0 THEN NULL
        ELSE round(ao.price_usd / (ao.data_amount_mb::numeric / 1024.0), 2)
      END                       AS price_per_gb_usd,
      ao.coupon_code,
      ao.coupon_description,
      NULL::text                AS image_url,
      'open_partner'::text      AS action,
      (ao.source = 'manual' AND (
         ao.price_checked_at IS NULL
         OR ao.price_checked_at < now() - make_interval(days => v_max_age_days)
      ))                        AS price_is_stale,
      ap.disclosure_required
    FROM affiliate_offers ao
    JOIN affiliate_partners ap ON ap.id = ao.partner_id
    WHERE v_affiliate_on
      AND ao.is_active
      AND ap.is_active
      AND ap.disclosure_required IS NOT NULL
      AND ao.countries @> ARRAY[v_iso]
  ),
  merged AS (
    SELECT * FROM resale
    UNION ALL
    SELECT * FROM affil
  )
  SELECT m.*
  FROM merged m
  WHERE (p_coverage IS NULL
         OR (p_coverage = 'local'    AND m.country_count <= 2)
         OR (p_coverage = 'regional' AND m.country_count BETWEEN 3 AND 49)
         OR (p_coverage = 'global'   AND m.country_count >= 50))
    AND (
      CASE
        WHEN COALESCE(p_unlimited_only, false) THEN m.is_unlimited
        WHEN v_data_exact IS NOT NULL THEN
          (NOT m.is_unlimited AND m.data_amount_mb = ANY(v_data_exact))
        WHEN p_min_data_mb IS NOT NULL OR p_max_data_mb IS NOT NULL THEN
          (NOT m.is_unlimited
           AND (p_min_data_mb IS NULL OR m.data_amount_mb >= p_min_data_mb)
           AND (p_max_data_mb IS NULL OR m.data_amount_mb <= p_max_data_mb))
        ELSE true
      END
    )
    AND (
      CASE
        WHEN v_days_exact IS NOT NULL THEN m.duration_days = ANY(v_days_exact)
        ELSE (p_min_days IS NULL OR m.duration_days >= p_min_days)
         AND (p_max_days IS NULL OR m.duration_days <= p_max_days)
      END
    )
    AND (p_min_price_usd IS NULL OR m.price_usd >= p_min_price_usd)
    AND (p_max_price_usd IS NULL OR m.price_usd <= p_max_price_usd)
    AND (p_speed_tiers IS NULL OR m.speed_tier = ANY(p_speed_tiers))
  ORDER BY
    CASE WHEN v_sort = 'price_per_gb' THEN m.price_per_gb_usd END ASC NULLS LAST,
    CASE WHEN v_sort = 'data'         THEN m.data_amount_mb   END DESC,
    CASE WHEN v_sort = 'duration'     THEN m.duration_days    END DESC,
    CASE WHEN v_sort NOT IN ('price_per_gb','data','duration') THEN m.price_usd END ASC,
    m.price_usd ASC,
    m.offer_id ASC
  LIMIT v_limit OFFSET v_offset;
END;
$function$;

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
           round(c.wholesale_price_usd * (1.0 + (v_tier_markup / 100.0)), 2)::numeric(10,2) AS price_usd
      FROM esim_offers_cache c
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
