-- N1 — real filters for the eSIM comparison.
--
-- J2b shipped `compare_esim_offers()` with three one-directional filters: a
-- minimum data size, a minimum duration and a maximum price. That answers
-- "at least this much", which is not the question anyone actually asks of a
-- travel eSIM. "I am away 1 to 7 days" and "I want the 3-day OR the 7-day
-- plan" both had to be approximated by a floor, and a floor of 7 days also
-- returns every 180-day bundle.
--
-- This adds the other half of each pair plus an exact-value list, so each of
-- the three dimensions supports the same three shapes:
--
--   Validity   all | range (min..max days)  | exact set of durations
--   Data       all | range (min..max MB)    | exact set of sizes | unlimited
--   Price      all | range (min..max USD)
--
-- Two deliberate semantics, because both are the kind of thing that otherwise
-- gets re-derived differently on each surface:
--
--  1. UNLIMITED IS ITS OWN ANSWER, NOT A BIG NUMBER. J2b's data floor read
--     `is_unlimited OR data_amount_mb >= p_min_data_mb`, so every data filter
--     dragged all 3,894 unlimited bundles along — 72% of the catalogue — and
--     a "3 GB" filter returned mostly plans that are not 3 GB. Now a data
--     RANGE or EXACT set matches metered plans only, and unlimited is a
--     separate choice. `p_unlimited_only` keeps its name and still wins over
--     everything else, so an old client's call means exactly what it meant.
--
--  2. AN EMPTY BOUND IS NOT ZERO. NULL on any bound means "no bound on this
--     side" — a NULL minimum price is not a filter for free plans, and a NULL
--     maximum is the top of the catalogue. The client sends NULL for an empty
--     box rather than substituting 0, which would silently mean something
--     else on the max side.
--
-- The five new parameters are appended LAST and defaulted, so an APK built
-- against the J2b argument list still resolves. This is a DROP + CREATE, not
-- a CREATE OR REPLACE with extra params: replacing would leave two overloads
-- and PostgREST answers PGRST203 to every call (the D5b→F2b failure).

BEGIN;

DROP FUNCTION IF EXISTS public.compare_esim_offers(text, text, bigint, integer, numeric, boolean, text[], text, integer, integer);

CREATE FUNCTION public.compare_esim_offers(
  p_country_code   text,
  p_coverage       text     DEFAULT NULL,   -- 'local' | 'regional' | 'global'
  p_min_data_mb    bigint   DEFAULT NULL,
  p_min_days       integer  DEFAULT NULL,
  p_max_price_usd  numeric  DEFAULT NULL,
  p_unlimited_only boolean  DEFAULT false,
  p_speed_tiers    text[]   DEFAULT NULL,
  p_sort           text     DEFAULT 'price',
  p_limit          integer  DEFAULT 60,
  p_offset         integer  DEFAULT 0,
  -- N1 additions.
  p_max_data_mb    bigint   DEFAULT NULL,
  p_data_exact_mb  bigint[] DEFAULT NULL,
  p_max_days       integer  DEFAULT NULL,
  p_days_exact     integer[] DEFAULT NULL,
  p_min_price_usd  numeric  DEFAULT NULL
)
RETURNS TABLE (
  offer_kind         text,
  offer_id           text,
  source_code        text,
  source_name        text,
  logo_url           text,
  title              text,
  description        text,
  countries          text[],
  country_count      integer,
  data_amount_mb     bigint,
  is_unlimited       boolean,
  duration_days      integer,
  speed_tier         text,
  price_usd          numeric,
  list_price_usd     numeric,
  price_per_gb_usd   numeric,
  coupon_code        text,
  coupon_description text,
  image_url          text,
  action             text,
  price_is_stale     boolean,
  disclosure_required boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_iso           text := upper(trim(COALESCE(p_country_code, '')));
  v_affiliate_on  boolean := false;
  v_max_age_days  integer := 14;
  v_limit         integer := LEAST(GREATEST(COALESCE(p_limit, 60), 1), 200);
  v_offset        integer := GREATEST(COALESCE(p_offset, 0), 0);
  v_sort          text := lower(COALESCE(p_sort, 'price'));
  -- An empty array is the client saying "the exact-value mode is selected but
  -- nothing is ticked yet". Treated as no filter rather than as a set that
  -- matches nothing, so the sheet never shows an empty list the user cannot
  -- explain.
  v_days_exact    integer[] := NULLIF(p_days_exact, '{}');
  v_data_exact    bigint[]  := NULLIF(p_data_exact_mb, '{}');
BEGIN
  IF v_iso = '' THEN
    RETURN;
  END IF;

  -- Pre-production brake. With this off the function returns exactly the
  -- resale rows the app already showed, so shipping it changes nothing until
  -- the owner flips one row.
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
      o.bundle_name             AS offer_id,
      o.provider                AS source_code,
      COALESCE(s.name, o.provider) AS source_name,
      NULL::text                AS logo_url,
      COALESCE(NULLIF(o.description, ''), o.bundle_name) AS title,
      o.description,
      o.countries,
      o.country_count,
      o.data_amount_mb,
      o.is_unlimited,
      o.duration_days,
      o.speed_tier,
      o.retail_price_usd        AS price_usd,
      NULL::numeric             AS list_price_usd,
      o.price_per_gb_usd,
      NULL::text                AS coupon_code,
      NULL::text                AS coupon_description,
      o.image_url,
      'buy_in_app'::text        AS action,
      false                     AS price_is_stale,
      false                     AS disclosure_required
    FROM esim_offers o
    LEFT JOIN esim_suppliers s ON s.code = o.provider
    WHERE o.countries @> ARRAY[v_iso]
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
      -- A hand-typed price is a claim about someone else's shop. Past the
      -- configured age we still show the offer but tell the UI not to quote a
      -- number, because a confidently wrong price is worse than no price.
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
      -- A partner row may not be emitted without a disclosure. Enforced here
      -- rather than in the UI so a new surface cannot forget it.
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
    -- ── Data ──────────────────────────────────────────────────────────────
    -- Exactly one of the three shapes applies, in this order of precedence.
    -- Unlimited first: it is the only one that is a statement about the KIND
    -- of plan rather than about a number of megabytes.
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
    -- ── Validity ──────────────────────────────────────────────────────────
    AND (
      CASE
        WHEN v_days_exact IS NOT NULL THEN m.duration_days = ANY(v_days_exact)
        ELSE (p_min_days IS NULL OR m.duration_days >= p_min_days)
         AND (p_max_days IS NULL OR m.duration_days <= p_max_days)
      END
    )
    -- ── Price ─────────────────────────────────────────────────────────────
    AND (p_min_price_usd IS NULL OR m.price_usd >= p_min_price_usd)
    AND (p_max_price_usd IS NULL OR m.price_usd <= p_max_price_usd)
    AND (p_speed_tiers IS NULL OR m.speed_tier = ANY(p_speed_tiers))
  ORDER BY
    -- NULLS LAST is load-bearing: price_per_gb_usd is NULL for the 3,894
    -- unlimited bundles, and sorting them as 0 would put 72% of the catalogue
    -- above every metered plan under a heading that says "cheapest per GB".
    CASE WHEN v_sort = 'price_per_gb' THEN m.price_per_gb_usd END ASC NULLS LAST,
    CASE WHEN v_sort = 'data'         THEN m.data_amount_mb   END DESC,
    CASE WHEN v_sort = 'duration'     THEN m.duration_days    END DESC,
    CASE WHEN v_sort NOT IN ('price_per_gb','data','duration') THEN m.price_usd END ASC,
    m.price_usd ASC,
    m.offer_id ASC
  LIMIT v_limit OFFSET v_offset;
END;
$fn$;

REVOKE ALL ON FUNCTION public.compare_esim_offers(text, text, bigint, integer, numeric, boolean, text[], text, integer, integer, bigint, bigint[], integer, integer[], numeric) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.compare_esim_offers(text, text, bigint, integer, numeric, boolean, text[], text, integer, integer, bigint, bigint[], integer, integer[], numeric) TO authenticated;

-- ───────────────────────────────────────────────────────────────────────────
-- compare_esim_filter_bounds — what the sheet may offer
-- ───────────────────────────────────────────────────────────────────────────
-- The filter sheet used to hard-code its chip values, with a comment warning
-- that a "14 days" chip would match nothing. That comment is the problem: the
-- ladder is a property of the catalogue, so the catalogue should say it. This
-- returns the real durations and data sizes on sale for one destination plus
-- the price floor and ceiling, which is also what makes "leave max empty for
-- the highest price available" a statement the UI can actually show.
--
-- Same SECURITY DEFINER reasoning as compare_esim_offers: it reads the
-- affiliate tables, and it emits only bounds — no commission, no wholesale.
CREATE OR REPLACE FUNCTION public.compare_esim_filter_bounds(
  p_country_code text
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_iso          text := upper(trim(COALESCE(p_country_code, '')));
  v_affiliate_on boolean := false;
  v_result       jsonb;
BEGIN
  IF v_iso = '' THEN
    RETURN jsonb_build_object('durations', '[]'::jsonb, 'data_mb', '[]'::jsonb,
                              'min_price_usd', NULL, 'max_price_usd', NULL,
                              'has_unlimited', false);
  END IF;

  SELECT COALESCE(NULLIF(config_value, '')::boolean, false) INTO v_affiliate_on
    FROM system_configs WHERE config_key = 'AFFILIATE_ENABLED';
  v_affiliate_on := COALESCE(v_affiliate_on, false);

  WITH pool AS (
    SELECT o.duration_days, o.data_amount_mb, o.is_unlimited, o.retail_price_usd AS price_usd
      FROM esim_offers o
     WHERE o.countries @> ARRAY[v_iso]
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
$fn$;

REVOKE ALL ON FUNCTION public.compare_esim_filter_bounds(text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.compare_esim_filter_bounds(text) TO authenticated;

COMMIT;
