-- J2b — the unified comparison, the click recorder, and the real partner rows.
--
-- `compare_esim_offers()` is the whole product decision in one function: our
-- own resale bundles and every partner deal compete in ONE ranked list, on
-- price and $/GB, with the card saying plainly which is which. It will
-- sometimes rank a partner above us. That is the point — a comparison that
-- always concludes "buy ours" is an advert, and users work that out fast.
--
-- Both functions are SECURITY DEFINER because the affiliate tables are
-- deny-all to clients. That is deliberate: `affiliate_partners` holds
-- `commission_percent`, and a user who can read our cut can see which
-- recommendation pays us more. Same reasoning that keeps
-- `esim_offers_cache.wholesale_price_usd` off the wire.

BEGIN;

-- ───────────────────────────────────────────────────────────────────────────
-- 0. URL encoding, needed to build a deep link safely
-- ───────────────────────────────────────────────────────────────────────────
-- Postgres ships no urlencode. The per-byte hex split matters: convert_to()
-- returns 'c3a9' for é, and pasting that after a single '%' produces '%C3A9',
-- which is a different (broken) URL. Every byte gets its own '%'.
CREATE OR REPLACE FUNCTION public.url_encode(p_input text)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
  SELECT COALESCE(string_agg(
    CASE WHEN ch ~ '^[A-Za-z0-9_.~-]$' THEN ch
         ELSE regexp_replace(upper(encode(convert_to(ch, 'UTF8'), 'hex')), '(..)', '%\1', 'g')
    END, '' ORDER BY ord), '')
  FROM (
    SELECT ch, ord FROM regexp_split_to_table(COALESCE(p_input, ''), '') WITH ORDINALITY AS t(ch, ord)
  ) s;
$$;

-- ───────────────────────────────────────────────────────────────────────────
-- 1. compare_esim_offers — one ranked list, both rails
-- ───────────────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.compare_esim_offers(text, text, bigint, integer, numeric, boolean, text[], text, integer, integer);

CREATE FUNCTION public.compare_esim_offers(
  p_country_code   text,
  p_coverage       text    DEFAULT NULL,   -- 'local' | 'regional' | 'global'
  p_min_data_mb    bigint  DEFAULT NULL,
  p_min_days       integer DEFAULT NULL,
  p_max_price_usd  numeric DEFAULT NULL,
  p_unlimited_only boolean DEFAULT false,
  p_speed_tiers    text[]  DEFAULT NULL,
  p_sort           text    DEFAULT 'price',
  p_limit          integer DEFAULT 60,
  p_offset         integer DEFAULT 0
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
    AND (p_min_data_mb   IS NULL OR m.is_unlimited OR m.data_amount_mb >= p_min_data_mb)
    AND (p_min_days      IS NULL OR m.duration_days >= p_min_days)
    AND (p_max_price_usd IS NULL OR m.price_usd <= p_max_price_usd)
    AND (NOT p_unlimited_only OR m.is_unlimited)
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

REVOKE ALL ON FUNCTION public.compare_esim_offers(text, text, bigint, integer, numeric, boolean, text[], text, integer, integer) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.compare_esim_offers(text, text, bigint, integer, numeric, boolean, text[], text, integer, integer) TO authenticated;

-- ───────────────────────────────────────────────────────────────────────────
-- 2. record_affiliate_click — attribution without handing over identity
-- ───────────────────────────────────────────────────────────────────────────
-- The click row's own id is the token sent to the network. It is a random
-- uuid; the user id never leaves this database. The network can tell us "click
-- 9f3c… converted" and only we can say who that was. Building the URL here
-- rather than in the client also means attribution cannot be forged from a
-- device.
CREATE OR REPLACE FUNCTION public.record_affiliate_click(
  p_offer_id     uuid,
  p_country_code text DEFAULT NULL,
  p_device_id    text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_user_id  uuid := auth.uid();
  v_offer    RECORD;
  v_click_id uuid;
  v_url      text;
  v_sep      text;
  v_enabled  boolean := false;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'code', 'UNAUTHORIZED');
  END IF;

  SELECT COALESCE(NULLIF(config_value, '')::boolean, false) INTO v_enabled
    FROM system_configs WHERE config_key = 'AFFILIATE_ENABLED';
  IF NOT COALESCE(v_enabled, false) THEN
    RETURN jsonb_build_object('success', false, 'code', 'AFFILIATE_DISABLED');
  END IF;

  PERFORM public.enforce_rate_limit('affiliate_click', v_user_id::text);

  SELECT ao.id, ao.landing_url, ao.partner_id,
         ap.default_tracking_url, ap.is_active AS partner_active,
         an.click_param, an.deeplink_param, an.is_active AS network_active
    INTO v_offer
    FROM affiliate_offers ao
    JOIN affiliate_partners ap ON ap.id = ao.partner_id
    JOIN affiliate_networks an ON an.code = ap.network_code
   WHERE ao.id = p_offer_id AND ao.is_active;

  IF v_offer.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'code', 'OFFER_NOT_FOUND');
  END IF;
  IF NOT v_offer.partner_active OR NOT v_offer.network_active THEN
    RETURN jsonb_build_object('success', false, 'code', 'PARTNER_INACTIVE');
  END IF;
  IF COALESCE(v_offer.default_tracking_url, '') = '' THEN
    -- Without a tracking link the click earns nothing and we would be sending
    -- a user away for free. Refuse rather than open an untracked link.
    RETURN jsonb_build_object('success', false, 'code', 'NO_TRACKING_URL');
  END IF;

  v_click_id := gen_random_uuid();

  v_sep := CASE WHEN position('?' in v_offer.default_tracking_url) > 0 THEN '&' ELSE '?' END;
  v_url := v_offer.default_tracking_url || v_sep
           || v_offer.click_param || '=' || v_click_id::text;

  -- Deep link to the specific product page when the network supports it and
  -- we know the destination; otherwise the link lands on the partner's home
  -- page, which still tracks.
  IF COALESCE(v_offer.deeplink_param, '') <> '' AND COALESCE(v_offer.landing_url, '') <> '' THEN
    v_url := v_url || '&' || v_offer.deeplink_param || '=' || public.url_encode(v_offer.landing_url);
  END IF;

  INSERT INTO affiliate_clicks (id, user_id, partner_id, offer_id, country_code, device_id, target_url)
  VALUES (v_click_id, v_user_id, v_offer.partner_id, v_offer.id,
          upper(NULLIF(trim(COALESCE(p_country_code, '')), '')), p_device_id, v_url);

  RETURN jsonb_build_object('success', true, 'click_id', v_click_id, 'url', v_url);
END;
$fn$;

REVOKE ALL ON FUNCTION public.record_affiliate_click(uuid, text, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.record_affiliate_click(uuid, text, text) TO authenticated;

-- ───────────────────────────────────────────────────────────────────────────
-- 3. Real network + partner rows
-- ───────────────────────────────────────────────────────────────────────────
-- Values below are verified against the live APIs, not assumed:
--   * Impact campaign 44026 / advertiser 6626366 ("Weitaige Technology Co.,
--     Limited", trading as Billion Connect) read from /Campaigns.
--   * Tracking links and the NEWBC20 coupon read from /Ads. All three ads
--     report DeepLinkEnabled, which is why deeplink_param is set.
--
-- NO OFFERS ARE SEEDED. Impact's /Catalogs returns zero catalogues for this
-- account and /Promos 404s, so Billion Connect publishes no machine-readable
-- product list. Inventing plausible plans and prices would put fictional money
-- in front of a user — the same reason the DTOne adapter has no fallback
-- catalogue and I8 seeded carrier app names with every URL left NULL. Offers
-- are an owner task through the admin app, where each one records who checked
-- the price and when.
INSERT INTO public.affiliate_networks (code, name, api_base_url, docs_url, credential_secret, click_param, deeplink_param, is_active, notes)
VALUES
  ('impact', 'Impact', 'https://api.impact.com', 'https://integrations.impact.com',
   'impact_api_credentials', 'subId1', 'u', false,
   'Publisher (mediapartner) API, HTTP Basic with AccountSID:AuthToken. Read-only credential pair is sufficient for /Campaigns, /Ads and /Reports; /Catalogs needs the read-write pair and returns 0 catalogues for this account anyway.'),
  ('affilae', 'Affilae', 'https://app.affilae.com', 'https://affilae.com',
   'affilae_api_token', 'ae_sub', NULL, false,
   'Orange Travel runs here. Application still pending at time of writing and the publisher API base URL is unconfirmed — app.affilae.com/api/* serves the SPA shell for every path, so the reader stays unwired until a real endpoint is verified.'),
  ('direct', 'Direct partnership', NULL, NULL, NULL, 'ref', NULL, false,
   'For partners we deal with directly, with no network in between.')
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.affiliate_partners (
  network_code, code, display_name, website_url,
  external_advertiser_id, external_campaign_id, default_tracking_url,
  commission_percent, commission_note, countries_supported, priority, is_active, notes)
VALUES
  ('impact', 'billion_connect', 'Billion Connect', 'https://www.billionconnect.net/',
   '6626366', '44026', 'https://weitaigetechnologycolimited.pxf.io/c/7567818/3331478/44026',
   10.000, 'Online Sale 10%, 30-day referral period (Impact contract terms).',
   '{}', 10, false,
   'Approved 2026-08-05. Ads available: 3742965 "Affiliate 10% OFF", 3924052 coupon NEWBC20, 3924071 "New Customer Offer" — all deep-link enabled. No product catalogue via API, so offers must be entered by hand.'),
  ('affilae', 'orange_travel', 'Orange Travel', 'https://travel.orange.com/',
   NULL, NULL, NULL,
   NULL, NULL, '{}', 20, false,
   'Application pending as of 2026-08-05. Deliberately has no tracking URL: record_affiliate_click refuses NO_TRACKING_URL rather than sending a user away untracked and unpaid.')
ON CONFLICT (code) DO NOTHING;

COMMIT;
