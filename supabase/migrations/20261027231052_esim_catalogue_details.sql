-- ESIM-02: additive retail facts, immutable purchase snapshots, private diagnostics.
-- Deploy schema before either catalogue writer; release both writers together.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $preflight$ BEGIN
  IF md5(pg_get_functiondef('public.compare_esim_offers(text,text,bigint,integer,numeric,boolean,text[],text,integer,integer,bigint,bigint[],integer,integer[],numeric)'::regprocedure))
       <> '7da7bff4ee48366b772607635ca177f1'
    OR md5(pg_get_viewdef('public.esim_offers'::regclass,true)) <> '27fc8a9a7f5be4534c6ab634cbd40dc9'
    OR md5(pg_get_functiondef('public.request_esim_purchase(text,integer,text)'::regprocedure))
       <> '524b7d1f6f79eadaf422fb0ff3f1c315' THEN
    RAISE EXCEPTION 'ESIM-02 source drift: review the catalogue/checkout contract before applying';
  END IF;
END $preflight$;
ALTER TABLE public.esim_offers_cache
  ADD COLUMN catalogue_details jsonb,
  ADD COLUMN provider_values jsonb,
  ADD COLUMN provider_values_expires_at timestamptz;
ALTER TABLE public.esim_orders ADD COLUMN catalogue_snapshot jsonb;

-- Retail access uses allowlisted views/RPCs. Raw package values and cost are private.
REVOKE ALL ON public.esim_offers_cache FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.esim_offers_cache TO service_role;
ALTER TABLE public.esim_offers_cache ENABLE ROW LEVEL SECURITY;

-- Existing inferred unlimited/FUP claims have no evidence. A fresh BASE sync supplies facts.
UPDATE public.esim_offers_cache SET is_unlimited=false,speed_tier=NULL,bundle_group=NULL
WHERE provider='esimaccess';

CREATE OR REPLACE FUNCTION public.guard_esim_catalogue_writer()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
  IF NEW.provider='esimaccess' AND NEW.is_active AND
    (TG_OP='INSERT' OR NEW.updated_at IS DISTINCT FROM OLD.updated_at
      OR NEW.catalogue_details IS DISTINCT FROM OLD.catalogue_details) THEN
    IF NEW.catalogue_details->>'schema_version' IS DISTINCT FROM '1'
      OR NEW.catalogue_details->>'discovery_type' IS DISTINCT FROM 'BASE'
      OR (NEW.catalogue_details->>'observed_at')::timestamptz IS DISTINCT FROM NEW.updated_at THEN
      RAISE EXCEPTION 'ESIM_CATALOGUE_WRITER_UPGRADE_REQUIRED';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.guard_esim_catalogue_writer() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER guard_esim_catalogue_writer BEFORE INSERT OR UPDATE ON public.esim_offers_cache
FOR EACH ROW EXECUTE FUNCTION public.guard_esim_catalogue_writer();

-- Bind current product identity and retail facts atomically when checkout inserts its order.
-- No historical backfill: matching descriptions cannot establish an original identity.
CREATE OR REPLACE FUNCTION public.snapshot_esim_catalogue_order()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  SELECT jsonb_build_object('provider',c.provider,'bundle_name',c.bundle_name,
    'catalogue_details',c.catalogue_details,'countries',c.countries,
    'data_amount_mb',c.data_amount_mb,'duration_days',c.duration_days,
    'is_unlimited',c.is_unlimited,'retail_price_usd',NEW.retail_price_usd,
    'catalogue_observed_at',c.updated_at)
  INTO NEW.catalogue_snapshot FROM public.esim_offers_cache c
  WHERE c.provider=NEW.provider AND c.bundle_name=NEW.bundle_name;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.snapshot_esim_catalogue_order() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER snapshot_esim_catalogue_order BEFORE INSERT ON public.esim_orders
FOR EACH ROW EXECUTE FUNCTION public.snapshot_esim_catalogue_order();

-- One latest source record per offer, not an unbounded response history. Thirty-day TTL.
CREATE OR REPLACE FUNCTION public.prune_esim_catalogue_source()
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
  UPDATE public.esim_offers_cache SET provider_values=NULL,provider_values_expires_at=NULL
  WHERE provider_values_expires_at < now();
$$;
REVOKE ALL ON FUNCTION public.prune_esim_catalogue_source() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.prune_esim_catalogue_source() TO service_role;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname='pg_cron') THEN
    PERFORM cron.schedule('esim-catalogue-source-retention','17 3 * * *',
      'select public.prune_esim_catalogue_source()');
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.admin_esim_catalogue_diagnostics()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
  PERFORM public.assert_admin();
  RETURN (SELECT jsonb_build_object('active_offers',count(*),
    'enriched_offers',count(*) FILTER (WHERE catalogue_details->>'schema_version'='1'),
    'unknown_type',count(*) FILTER (WHERE COALESCE(catalogue_details->>'plan_type','unknown')='unknown'),
    'unknown_activation',count(*) FILTER (WHERE COALESCE(catalogue_details->>'activation_trigger','unknown')='unknown'),
    'unknown_recharge',count(*) FILTER (WHERE COALESCE(catalogue_details->>'topup_support','unknown')='unknown'),
    'last_observed_at',max(catalogue_details->>'observed_at'))
    FROM public.esim_offers_cache WHERE provider='esimaccess' AND is_active);
END;
$$;
REVOKE ALL ON FUNCTION public.admin_esim_catalogue_diagnostics() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_esim_catalogue_diagnostics() TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.compare_esim_offers(p_country_code text, p_coverage text DEFAULT NULL::text, p_min_data_mb bigint DEFAULT NULL::bigint, p_min_days integer DEFAULT NULL::integer, p_max_price_usd numeric DEFAULT NULL::numeric, p_unlimited_only boolean DEFAULT false, p_speed_tiers text[] DEFAULT NULL::text[], p_sort text DEFAULT 'price'::text, p_limit integer DEFAULT 60, p_offset integer DEFAULT 0, p_max_data_mb bigint DEFAULT NULL::bigint, p_data_exact_mb bigint[] DEFAULT NULL::bigint[], p_max_days integer DEFAULT NULL::integer, p_days_exact integer[] DEFAULT NULL::integer[], p_min_price_usd numeric DEFAULT NULL::numeric)
 RETURNS TABLE(offer_kind text, offer_id text, source_code text, source_name text, logo_url text, title text, description text, countries text[], country_count integer, data_amount_mb bigint, is_unlimited boolean, duration_days integer, speed_tier text, price_usd numeric, list_price_usd numeric, price_per_gb_usd numeric, coupon_code text, coupon_description text, image_url text, action text, price_is_stale boolean, disclosure_required boolean)
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
      public.resolve_esim_offer_price(c.wholesale_price_usd, v_user_id)::numeric(10,2) AS price_usd,
      NULL::numeric             AS list_price_usd,
      CASE
        WHEN c.is_unlimited OR c.data_amount_mb <= 0 OR c.catalogue_details->>'plan_type' LIKE 'daily_%' THEN NULL::numeric
        ELSE round(public.resolve_esim_offer_price(c.wholesale_price_usd, v_user_id) / COALESCE(NULLIF((c.catalogue_details->>'allowance_bytes')::numeric,0) / 1073741824.0, (c.data_amount_mb::numeric / 1024.0)), 2)
      END::numeric(10,2)        AS price_per_gb_usd,
      NULL::text                AS coupon_code,
      NULL::text                AS coupon_description,
      c.image_url,
      'buy_in_app'::text        AS action,
      false                     AS price_is_stale,
      false                     AS disclosure_required
    FROM esim_offers_cache c
    JOIN esim_suppliers s ON s.code = c.provider AND s.is_active = true
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
CREATE OR REPLACE FUNCTION public.compare_esim_offers_v2(p_country_code text, p_coverage text DEFAULT NULL::text, p_min_data_mb bigint DEFAULT NULL::bigint, p_min_days integer DEFAULT NULL::integer, p_max_price_usd numeric DEFAULT NULL::numeric, p_unlimited_only boolean DEFAULT false, p_speed_tiers text[] DEFAULT NULL::text[], p_sort text DEFAULT 'price'::text, p_limit integer DEFAULT 60, p_offset integer DEFAULT 0, p_max_data_mb bigint DEFAULT NULL::bigint, p_data_exact_mb bigint[] DEFAULT NULL::bigint[], p_max_days integer DEFAULT NULL::integer, p_days_exact integer[] DEFAULT NULL::integer[], p_min_price_usd numeric DEFAULT NULL::numeric, p_plan_types text[] DEFAULT NULL::text[])
 RETURNS TABLE(offer_kind text, offer_id text, source_code text, source_name text, logo_url text, title text, description text, countries text[], country_count integer, data_amount_mb bigint, is_unlimited boolean, duration_days integer, speed_tier text, price_usd numeric, list_price_usd numeric, price_per_gb_usd numeric, coupon_code text, coupon_description text, image_url text, action text, price_is_stale boolean, disclosure_required boolean, catalogue_details jsonb)
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
      public.resolve_esim_offer_price(c.wholesale_price_usd, v_user_id)::numeric(10,2) AS price_usd,
      NULL::numeric             AS list_price_usd,
      CASE
        WHEN c.is_unlimited OR c.data_amount_mb <= 0 OR c.catalogue_details->>'plan_type' LIKE 'daily_%' THEN NULL::numeric
        ELSE round(public.resolve_esim_offer_price(c.wholesale_price_usd, v_user_id) / COALESCE(NULLIF((c.catalogue_details->>'allowance_bytes')::numeric,0) / 1073741824.0, (c.data_amount_mb::numeric / 1024.0)), 2)
      END::numeric(10,2)        AS price_per_gb_usd,
      NULL::text                AS coupon_code,
      NULL::text                AS coupon_description,
      c.image_url,
      'buy_in_app'::text        AS action,
      false                     AS price_is_stale,
      false                     AS disclosure_required,
      c.catalogue_details
    FROM esim_offers_cache c
    JOIN esim_suppliers s ON s.code = c.provider AND s.is_active = true
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
      ap.disclosure_required,
      NULL::jsonb AS catalogue_details
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
  WHERE (p_plan_types IS NULL OR COALESCE(m.catalogue_details->>'plan_type', 'unknown') = ANY(p_plan_types))
    AND (p_coverage IS NULL
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
CREATE OR REPLACE VIEW public.esim_offers AS
 SELECT (c.provider || '_'::text) || c.bundle_name AS id,
    c.provider,
    c.bundle_name,
    c.description,
    c.countries,
    c.roaming_enabled,
    c.data_amount_mb,
    c.duration_days,
    public.resolve_esim_offer_price(c.wholesale_price_usd, auth.uid())::numeric(10,2) AS retail_price_usd,
    c.image_url,
    c.is_active,
    c.updated_at,
    c.is_unlimited,
    c.bundle_group,
    c.speed_tier,
    c.region,
    c.country_count,
        CASE WHEN c.is_unlimited OR c.data_amount_mb <= 0
          OR c.catalogue_details->>'plan_type' LIKE 'daily_%' THEN NULL::numeric
          ELSE round(public.resolve_esim_offer_price(c.wholesale_price_usd, auth.uid()) /
            COALESCE(NULLIF((c.catalogue_details->>'allowance_bytes')::numeric,0) / 1073741824.0,
              (c.data_amount_mb::numeric / 1024.0)), 2)
        END::numeric(10,2) AS price_per_gb_usd,
    c.catalogue_details
   FROM esim_offers_cache c
     JOIN esim_suppliers s ON s.code = c.provider AND s.is_active = true
  WHERE c.is_active = true;
REVOKE ALL ON FUNCTION public.compare_esim_offers_v2(text,text,bigint,integer,numeric,boolean,text[],text,integer,integer,bigint,bigint[],integer,integer[],numeric,text[]) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.compare_esim_offers_v2(text,text,bigint,integer,numeric,boolean,text[],text,integer,integer,bigint,bigint[],integer,integer[],numeric,text[]) TO authenticated,service_role;
NOTIFY pgrst, 'reload schema';
COMMIT;
