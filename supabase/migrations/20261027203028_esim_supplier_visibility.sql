-- Respect the Admin eSIM source switch in every customer catalogue read and
-- in the authoritative purchase lookup. Cache activity remains bundle-specific.
-- Based on the captured live definitions; preserve pricing, signatures and ACLs.
BEGIN;
SET LOCAL lock_timeout = '5s';

DO $preflight$
BEGIN
  IF md5(pg_get_functiondef('public.compare_esim_offers(text,text,bigint,integer,numeric,boolean,text[],text,integer,integer,bigint,bigint[],integer,integer[],numeric)'::regprocedure)) NOT IN
     ('8f18c47279c623efeea8bd1548147307', '7da7bff4ee48366b772607635ca177f1') THEN
    RAISE EXCEPTION 'Unexpected deployed compare_esim_offers definition; inspect before applying';
  END IF;
END;
$preflight$;

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

DO $preflight$
BEGIN
  IF md5(pg_get_functiondef('public.request_esim_purchase(text,integer,text)'::regprocedure)) NOT IN
     ('0cd1179e31fea7675479e40e2baed06c', '524b7d1f6f79eadaf422fb0ff3f1c315') THEN
    RAISE EXCEPTION 'Unexpected deployed request_esim_purchase definition; inspect before applying';
  END IF;
END;
$preflight$;

CREATE OR REPLACE FUNCTION public.request_esim_purchase(p_offer_id text, p_quantity integer DEFAULT 1, p_device_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_offer RECORD;
  v_supplier_markup numeric;
  v_markup_percent numeric := 30.0;
  v_retail_price numeric(10,2);
  v_total_cost numeric(10,2);
  v_wallet_balance numeric(10,2);
  v_order_id uuid;
  v_txn_ref text;
  v_guard jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  IF EXISTS (SELECT 1 FROM public.profiles WHERE id = v_user_id AND is_suspended = true) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Account is suspended. Purchases are disabled.');
  END IF;

  PERFORM public.enforce_rate_limit('esim_purchase', v_user_id::text);

  IF p_quantity IS NULL OR p_quantity < 1 OR p_quantity > 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Quantity must be between 1 and 3');
  END IF;

  SELECT c.* INTO v_offer
  FROM public.esim_offers_cache c
  JOIN public.esim_suppliers s ON s.code = c.provider AND s.is_active = true
  WHERE (c.bundle_name = p_offer_id OR (c.provider || '_' || c.bundle_name = p_offer_id))
    AND c.is_active = true
  ORDER BY c.updated_at DESC
  LIMIT 1;

  IF v_offer IS NULL OR v_offer.bundle_name IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'eSIM offer not found or inactive');
  END IF;

  -- Use canonical tier-based pricing via resolve_esim_offer_price
  v_retail_price := public.resolve_esim_offer_price(v_offer.wholesale_price_usd, v_user_id);
  IF v_retail_price IS NULL OR v_retail_price <= 0 THEN
    SELECT markup_percent_override INTO v_supplier_markup
    FROM public.esim_suppliers
    WHERE code = v_offer.provider;

    IF v_supplier_markup IS NOT NULL THEN
      v_markup_percent := v_supplier_markup;
    ELSE
      BEGIN
        SELECT config_value::numeric INTO v_markup_percent
        FROM public.system_configs WHERE config_key = 'ESIM_MARKUP_PERCENT';
      EXCEPTION WHEN OTHERS THEN v_markup_percent := 30.0; END;
    END IF;
    IF v_markup_percent IS NULL THEN v_markup_percent := 30.0; END IF;

    v_retail_price := round(v_offer.wholesale_price_usd * (1.0 + (v_markup_percent / 100.0)), 2);
  ELSE
    v_markup_percent := round(((v_retail_price - v_offer.wholesale_price_usd) / NULLIF(v_offer.wholesale_price_usd, 0)) * 100.0, 2);
  END IF;

  v_total_cost := v_retail_price * p_quantity;

  SELECT COALESCE(balance, 0.00) INTO v_wallet_balance
  FROM public.wallets WHERE user_id = v_user_id;

  IF v_wallet_balance < v_total_cost THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'INSUFFICIENT_FUNDS',
      'error', 'Insufficient wallet balance. Required: $' || v_total_cost::text || ', Available: $' || v_wallet_balance::text
    );
  END IF;

  v_guard := public.guard_money_action('esim_purchase', v_total_cost, p_device_id, NULL, v_user_id);
  IF (v_guard ->> 'blocked')::boolean THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'DEVICE_BLOCKED',
      'reason', v_guard ->> 'reason',
      'error', 'This purchase was stopped by a security check on this device. Contact support if this is a mistake.'
    );
  END IF;

  INSERT INTO public.esim_orders (
    user_id, offer_id, bundle_name, provider, quantity, wholesale_price_usd, retail_price_usd, markup_percent, total_amount_usd, status
  ) VALUES (
    v_user_id, p_offer_id, v_offer.bundle_name, v_offer.provider, p_quantity, v_offer.wholesale_price_usd, v_retail_price, v_markup_percent, v_total_cost, 'pending'
  ) RETURNING id INTO v_order_id;

  v_txn_ref := 'esim_' || v_order_id::text;

  PERFORM public.debit_wallet_for_topup(
    p_user_id => v_user_id,
    p_sim_line_id => NULL,
    p_amount => v_total_cost,
    p_description => 'eSIM Purchase: ' || v_offer.bundle_name,
    p_reference_id => v_txn_ref,
    p_txn_type => 'esim_purchase_debit'
  );

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'retail_price_usd', v_retail_price,
    'total_amount_usd', v_total_cost,
    'status', 'pending'
  );
END;
$function$;

DO $preflight$
BEGIN
  IF md5(pg_get_functiondef('public.compare_esim_filter_bounds(text)'::regprocedure)) NOT IN
     ('4f9b0c9b1f34267aaa9fd1dc6df37b15', '449d54ccfef6242345517283c06fc57e') THEN
    RAISE EXCEPTION 'Unexpected deployed compare_esim_filter_bounds definition; inspect before applying';
  END IF;
END;
$preflight$;

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

DO $preflight$
BEGIN
  IF md5(pg_get_viewdef('public.esim_offers'::regclass, true)) NOT IN
     ('b7105348279911abe12b10998c08d748', '27fc8a9a7f5be4534c6ab634cbd40dc9') THEN
    RAISE EXCEPTION 'Unexpected deployed esim_offers definition; inspect before applying';
  END IF;
END;
$preflight$;

CREATE OR REPLACE VIEW public.esim_offers AS
 SELECT (c.provider || '_'::text) || c.bundle_name AS id,
    c.provider,
    c.bundle_name,
    c.description,
    c.countries,
    c.roaming_enabled,
    c.data_amount_mb,
    c.duration_days,
    round(c.wholesale_price_usd * (1.0 + COALESCE(s.markup_percent_override, ( SELECT NULLIF(system_configs.config_value::text, ''::text)::numeric AS "nullif"
           FROM system_configs
          WHERE system_configs.config_key::text = 'ESIM_MARKUP_PERCENT'::text), 30.0) / 100.0), 2)::numeric(10,2) AS retail_price_usd,
    c.image_url,
    c.is_active,
    c.updated_at,
    c.is_unlimited,
    c.bundle_group,
    c.speed_tier,
    c.region,
    c.country_count,
        CASE
            WHEN c.is_unlimited OR c.data_amount_mb <= 0 THEN NULL::numeric
            ELSE round(round(c.wholesale_price_usd * (1.0 + COALESCE(s.markup_percent_override, ( SELECT NULLIF(system_configs.config_value::text, ''::text)::numeric AS "nullif"
               FROM system_configs
              WHERE system_configs.config_key::text = 'ESIM_MARKUP_PERCENT'::text), 30.0) / 100.0), 2) / (c.data_amount_mb::numeric / 1024.0), 2)
        END::numeric(10,2) AS price_per_gb_usd
   FROM esim_offers_cache c
     JOIN esim_suppliers s ON s.code = c.provider AND s.is_active = true
  WHERE c.is_active = true;

NOTIFY pgrst, 'reload schema';
COMMIT;
