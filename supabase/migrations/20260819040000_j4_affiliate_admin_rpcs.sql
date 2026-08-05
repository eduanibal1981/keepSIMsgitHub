-- J4 — admin control plane for the affiliate rail.
--
-- The affiliate tables are deny-all, and the admin app authenticates with the
-- customer anon key plus a power-user session, so it cannot write to a table at
-- all. Every mutation here is an `admin_*` SECURITY DEFINER RPC that calls
-- assert_admin(), validates, and writes an admin_audit_log row — the Phase H
-- convention. No new RLS policy is added to any user-facing table; that is how
-- F-1..F-4 happened.
--
-- Patch convention (Phase H): writes take a jsonb patch, an absent key means
-- unchanged, and an UNKNOWN key is refused with KS467. A defaulted-NULL
-- parameter cannot distinguish "leave alone" from "set NULL", and adding a
-- parameter later re-creates the PGRST203 overload trap.

BEGIN;

-- ───────────────────────────────────────────────────────────────────────────
-- 1. Partners
-- ───────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_list_affiliate_partners()
RETURNS TABLE (
  id uuid, code text, display_name text, network_code text, network_active boolean,
  website_url text, logo_url text, external_advertiser_id text, external_campaign_id text,
  default_tracking_url text, commission_percent numeric, commission_note text,
  disclosure_required boolean, countries_supported text[], priority integer,
  is_active boolean, notes text,
  offer_count bigint, active_offer_count bigint, stale_offer_count bigint,
  click_count bigint, conversion_count bigint, commission_earned_usd numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_max_age integer := 14;
BEGIN
  PERFORM public.assert_admin();

  SELECT COALESCE(NULLIF(config_value, '')::integer, 14) INTO v_max_age
    FROM system_configs WHERE config_key = 'AFFILIATE_PRICE_MAX_AGE_DAYS';

  RETURN QUERY
  SELECT ap.id, ap.code, ap.display_name, ap.network_code, an.is_active,
         ap.website_url, ap.logo_url, ap.external_advertiser_id, ap.external_campaign_id,
         ap.default_tracking_url, ap.commission_percent, ap.commission_note,
         ap.disclosure_required, ap.countries_supported, ap.priority,
         ap.is_active, ap.notes,
         (SELECT count(*) FROM affiliate_offers o WHERE o.partner_id = ap.id),
         (SELECT count(*) FROM affiliate_offers o WHERE o.partner_id = ap.id AND o.is_active),
         -- The number that tells the owner what actually needs their attention:
         -- live offers quoting a price nobody has re-checked inside the window.
         (SELECT count(*) FROM affiliate_offers o
           WHERE o.partner_id = ap.id AND o.is_active AND o.source = 'manual'
             AND (o.price_checked_at IS NULL
                  OR o.price_checked_at < now() - make_interval(days => COALESCE(v_max_age, 14)))),
         (SELECT count(*) FROM affiliate_clicks c WHERE c.partner_id = ap.id),
         (SELECT count(*) FROM affiliate_conversions cv WHERE cv.partner_id = ap.id),
         -- Approved only. A pending commission is not money and a reversed one
         -- never was; summing every row would report revenue we may never see.
         COALESCE((SELECT sum(cv.commission_usd) FROM affiliate_conversions cv
                    WHERE cv.partner_id = ap.id AND cv.status = 'approved'), 0)
    FROM affiliate_partners ap
    JOIN affiliate_networks an ON an.code = ap.network_code
   ORDER BY ap.priority, ap.display_name;
END;
$fn$;

CREATE OR REPLACE FUNCTION public.admin_upsert_affiliate_partner(
  p_code  text,
  p_patch jsonb,
  p_note  text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_allowed text[] := ARRAY['network_code','display_name','logo_url','website_url',
    'external_advertiser_id','external_campaign_id','default_tracking_url',
    'commission_percent','commission_note','disclosure_required',
    'countries_supported','priority','is_active','notes'];
  v_key    text;
  v_before jsonb;
  v_row    affiliate_partners%ROWTYPE;
  v_commission numeric;
  v_disclosure boolean;
BEGIN
  PERFORM public.assert_admin();

  IF p_patch IS NULL OR jsonb_typeof(p_patch) <> 'object' OR p_patch = '{}'::jsonb THEN
    RAISE EXCEPTION 'Patch must be a non-empty object' USING ERRCODE = 'KS467';
  END IF;

  FOR v_key IN SELECT jsonb_object_keys(p_patch) LOOP
    IF NOT (v_key = ANY(v_allowed)) THEN
      RAISE EXCEPTION 'Unknown patch field: %', v_key USING ERRCODE = 'KS467';
    END IF;
  END LOOP;

  SELECT * INTO v_row FROM affiliate_partners WHERE code = p_code;
  v_before := to_jsonb(v_row);

  IF v_row.id IS NULL THEN
    IF NOT (p_patch ? 'display_name') OR NOT (p_patch ? 'network_code') THEN
      RAISE EXCEPTION 'A new partner needs display_name and network_code'
        USING ERRCODE = 'KS466';
    END IF;
    INSERT INTO affiliate_partners (code, network_code, display_name)
    VALUES (p_code, p_patch ->> 'network_code', p_patch ->> 'display_name')
    RETURNING * INTO v_row;
  END IF;

  UPDATE affiliate_partners SET
    network_code           = COALESCE(p_patch ->> 'network_code', network_code),
    display_name           = COALESCE(p_patch ->> 'display_name', display_name),
    logo_url               = CASE WHEN p_patch ? 'logo_url' THEN p_patch ->> 'logo_url' ELSE logo_url END,
    website_url            = CASE WHEN p_patch ? 'website_url' THEN p_patch ->> 'website_url' ELSE website_url END,
    external_advertiser_id = CASE WHEN p_patch ? 'external_advertiser_id' THEN p_patch ->> 'external_advertiser_id' ELSE external_advertiser_id END,
    external_campaign_id   = CASE WHEN p_patch ? 'external_campaign_id' THEN p_patch ->> 'external_campaign_id' ELSE external_campaign_id END,
    default_tracking_url   = CASE WHEN p_patch ? 'default_tracking_url' THEN p_patch ->> 'default_tracking_url' ELSE default_tracking_url END,
    commission_percent     = CASE WHEN p_patch ? 'commission_percent' THEN (p_patch ->> 'commission_percent')::numeric ELSE commission_percent END,
    commission_note        = CASE WHEN p_patch ? 'commission_note' THEN p_patch ->> 'commission_note' ELSE commission_note END,
    disclosure_required    = COALESCE((p_patch ->> 'disclosure_required')::boolean, disclosure_required),
    countries_supported    = CASE WHEN p_patch ? 'countries_supported'
                                  THEN ARRAY(SELECT upper(jsonb_array_elements_text(p_patch -> 'countries_supported')))
                                  ELSE countries_supported END,
    priority               = COALESCE((p_patch ->> 'priority')::integer, priority),
    is_active              = COALESCE((p_patch ->> 'is_active')::boolean, is_active),
    notes                  = CASE WHEN p_patch ? 'notes' THEN p_patch ->> 'notes' ELSE notes END,
    updated_at             = now()
  WHERE id = v_row.id
  RETURNING * INTO v_row;

  -- If we are paid for the referral, the relationship must be disclosed. This
  -- is checked AFTER the write against the resulting row, so setting the two
  -- fields in either order — or in separate calls — cannot slip past it.
  SELECT commission_percent, disclosure_required INTO v_commission, v_disclosure
    FROM affiliate_partners WHERE id = v_row.id;

  IF COALESCE(v_commission, 0) > 0 AND NOT v_disclosure THEN
    RAISE EXCEPTION 'Disclosure cannot be switched off for a partner that pays commission (%.3f%%)', v_commission
      USING ERRCODE = 'KS466';
  END IF;

  -- A partner cannot be switched on without a way to get paid, or it would
  -- send users away untracked. record_affiliate_click refuses this at runtime
  -- too; refusing it here means the owner learns at the moment they flip it.
  IF v_row.is_active AND COALESCE(v_row.default_tracking_url, '') = '' THEN
    RAISE EXCEPTION 'Partner % cannot be activated without a tracking URL', p_code
      USING ERRCODE = 'KS466';
  END IF;

  INSERT INTO admin_audit_log (actor_id, action, target_type, target_id, before_value, after_value, note)
  VALUES (auth.uid(), 'affiliate_partner_upsert', 'affiliate_partner', p_code,
          v_before, to_jsonb(v_row), p_note);

  RETURN jsonb_build_object('success', true, 'id', v_row.id, 'code', v_row.code);
END;
$fn$;

-- ───────────────────────────────────────────────────────────────────────────
-- 2. Offers
-- ───────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_list_affiliate_offers(
  p_partner_code text DEFAULT NULL,
  p_limit        integer DEFAULT 200
)
RETURNS TABLE (
  id uuid, partner_code text, partner_name text, partner_active boolean,
  external_offer_id text, title text, description text,
  countries text[], country_count integer,
  data_amount_mb bigint, is_unlimited boolean, duration_days integer, speed_tier text,
  price_usd numeric, list_price_usd numeric, coupon_code text, coupon_description text,
  landing_url text, currency_code text, source text,
  price_checked_at timestamptz, price_is_stale boolean, checked_by_email text,
  is_active boolean, click_count bigint, updated_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_max_age integer := 14;
BEGIN
  PERFORM public.assert_admin();

  SELECT COALESCE(NULLIF(config_value, '')::integer, 14) INTO v_max_age
    FROM system_configs WHERE config_key = 'AFFILIATE_PRICE_MAX_AGE_DAYS';

  RETURN QUERY
  SELECT ao.id, ap.code, ap.display_name, ap.is_active,
         ao.external_offer_id, ao.title, ao.description,
         ao.countries, ao.country_count,
         ao.data_amount_mb, ao.is_unlimited, ao.duration_days, ao.speed_tier,
         ao.price_usd, ao.list_price_usd, ao.coupon_code, ao.coupon_description,
         ao.landing_url, ao.currency_code, ao.source,
         ao.price_checked_at,
         (ao.source = 'manual' AND (ao.price_checked_at IS NULL
            OR ao.price_checked_at < now() - make_interval(days => COALESCE(v_max_age, 14)))),
         u.email::text,
         ao.is_active,
         (SELECT count(*) FROM affiliate_clicks c WHERE c.offer_id = ao.id),
         ao.updated_at
    FROM affiliate_offers ao
    JOIN affiliate_partners ap ON ap.id = ao.partner_id
    LEFT JOIN auth.users u ON u.id = ao.checked_by
   WHERE p_partner_code IS NULL OR ap.code = p_partner_code
   ORDER BY ap.priority, ao.price_usd
   LIMIT LEAST(GREATEST(COALESCE(p_limit, 200), 1), 1000);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.admin_upsert_affiliate_offer(
  p_id    uuid,
  p_patch jsonb,
  p_note  text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_allowed text[] := ARRAY['partner_code','external_offer_id','title','description',
    'countries','data_amount_mb','is_unlimited','duration_days','speed_tier',
    'price_usd','list_price_usd','coupon_code','coupon_description','landing_url',
    'currency_code','source','is_active','confirm_price'];
  v_key       text;
  v_before    jsonb;
  v_row       affiliate_offers%ROWTYPE;
  v_partner   uuid;
  v_confirm   boolean := COALESCE((p_patch ->> 'confirm_price')::boolean, false);
  v_price_touched boolean := (p_patch ? 'price_usd') OR (p_patch ? 'list_price_usd');
BEGIN
  PERFORM public.assert_admin();

  IF p_patch IS NULL OR jsonb_typeof(p_patch) <> 'object' OR p_patch = '{}'::jsonb THEN
    RAISE EXCEPTION 'Patch must be a non-empty object' USING ERRCODE = 'KS467';
  END IF;

  FOR v_key IN SELECT jsonb_object_keys(p_patch) LOOP
    IF NOT (v_key = ANY(v_allowed)) THEN
      -- `price_checked_at` and `checked_by` are deliberately NOT accepted. The
      -- staleness guard is only worth anything if the timestamp means "a human
      -- looked at the partner's site just now"; a caller-supplied date makes it
      -- a decoration. Same stance as I8's carrier_self_service.verified_at.
      RAISE EXCEPTION 'Unknown patch field: %', v_key USING ERRCODE = 'KS467';
    END IF;
  END LOOP;

  IF p_id IS NOT NULL THEN
    SELECT * INTO v_row FROM affiliate_offers WHERE id = p_id;
    IF v_row.id IS NULL THEN
      RAISE EXCEPTION 'Affiliate offer % not found', p_id USING ERRCODE = 'KS461';
    END IF;
    v_before := to_jsonb(v_row);
  ELSE
    IF NOT (p_patch ? 'partner_code') OR NOT (p_patch ? 'title') OR NOT (p_patch ? 'price_usd') THEN
      RAISE EXCEPTION 'A new offer needs partner_code, title and price_usd'
        USING ERRCODE = 'KS466';
    END IF;
    SELECT id INTO v_partner FROM affiliate_partners WHERE code = p_patch ->> 'partner_code';
    IF v_partner IS NULL THEN
      RAISE EXCEPTION 'Unknown partner_code %', p_patch ->> 'partner_code' USING ERRCODE = 'KS461';
    END IF;
    INSERT INTO affiliate_offers (partner_id, title, price_usd)
    VALUES (v_partner, p_patch ->> 'title', (p_patch ->> 'price_usd')::numeric)
    RETURNING * INTO v_row;
  END IF;

  UPDATE affiliate_offers SET
    external_offer_id  = CASE WHEN p_patch ? 'external_offer_id' THEN p_patch ->> 'external_offer_id' ELSE external_offer_id END,
    title              = COALESCE(p_patch ->> 'title', title),
    description        = CASE WHEN p_patch ? 'description' THEN p_patch ->> 'description' ELSE description END,
    countries          = CASE WHEN p_patch ? 'countries'
                              THEN ARRAY(SELECT upper(jsonb_array_elements_text(p_patch -> 'countries')))
                              ELSE countries END,
    data_amount_mb     = COALESCE((p_patch ->> 'data_amount_mb')::bigint, data_amount_mb),
    is_unlimited       = COALESCE((p_patch ->> 'is_unlimited')::boolean, is_unlimited),
    duration_days      = COALESCE((p_patch ->> 'duration_days')::integer, duration_days),
    speed_tier         = CASE WHEN p_patch ? 'speed_tier' THEN p_patch ->> 'speed_tier' ELSE speed_tier END,
    price_usd          = COALESCE((p_patch ->> 'price_usd')::numeric, price_usd),
    list_price_usd     = CASE WHEN p_patch ? 'list_price_usd' THEN (p_patch ->> 'list_price_usd')::numeric ELSE list_price_usd END,
    coupon_code        = CASE WHEN p_patch ? 'coupon_code' THEN p_patch ->> 'coupon_code' ELSE coupon_code END,
    coupon_description = CASE WHEN p_patch ? 'coupon_description' THEN p_patch ->> 'coupon_description' ELSE coupon_description END,
    landing_url        = CASE WHEN p_patch ? 'landing_url' THEN p_patch ->> 'landing_url' ELSE landing_url END,
    currency_code      = COALESCE(upper(p_patch ->> 'currency_code'), currency_code),
    source             = COALESCE(p_patch ->> 'source', source),
    is_active          = COALESCE((p_patch ->> 'is_active')::boolean, is_active),
    -- Stamped by the server, never supplied. Confirming the price is an
    -- explicit act; editing the price is treated as confirming it, because
    -- someone typing a new figure has just looked at the partner's site.
    price_checked_at   = CASE WHEN v_confirm OR v_price_touched THEN now() ELSE price_checked_at END,
    checked_by         = CASE WHEN v_confirm OR v_price_touched THEN auth.uid() ELSE checked_by END
  WHERE id = v_row.id
  RETURNING * INTO v_row;

  INSERT INTO admin_audit_log (actor_id, action, target_type, target_id, before_value, after_value, note)
  VALUES (auth.uid(), CASE WHEN v_before IS NULL THEN 'affiliate_offer_create' ELSE 'affiliate_offer_update' END,
          'affiliate_offer', v_row.id::text, v_before, to_jsonb(v_row), p_note);

  RETURN jsonb_build_object('success', true, 'id', v_row.id,
                            'price_checked_at', v_row.price_checked_at);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.admin_delete_affiliate_offer(
  p_id   uuid,
  p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_row affiliate_offers%ROWTYPE;
BEGIN
  PERFORM public.assert_admin();

  SELECT * INTO v_row FROM affiliate_offers WHERE id = p_id;
  IF v_row.id IS NULL THEN
    RAISE EXCEPTION 'Affiliate offer % not found', p_id USING ERRCODE = 'KS461';
  END IF;

  -- Deactivate, never DELETE. affiliate_clicks.offer_id is ON DELETE SET NULL,
  -- so a real delete would orphan the click history that conversions are
  -- reconciled against — money we are owed would lose the thing that explains
  -- where it came from.
  UPDATE affiliate_offers SET is_active = false WHERE id = p_id RETURNING * INTO v_row;

  INSERT INTO admin_audit_log (actor_id, action, target_type, target_id, before_value, after_value, note)
  VALUES (auth.uid(), 'affiliate_offer_deactivate', 'affiliate_offer', p_id::text,
          jsonb_build_object('is_active', true), to_jsonb(v_row), p_note);

  RETURN jsonb_build_object('success', true, 'id', p_id, 'is_active', false);
END;
$fn$;

-- ───────────────────────────────────────────────────────────────────────────
-- 3. Performance dashboard
-- ───────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_affiliate_overview(p_days integer DEFAULT 30)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_since timestamptz := now() - make_interval(days => LEAST(GREATEST(COALESCE(p_days, 30), 1), 365));
  v_result jsonb;
BEGIN
  PERFORM public.assert_admin();

  SELECT jsonb_build_object(
    'window_days', p_days,
    'affiliate_enabled', COALESCE((SELECT NULLIF(config_value,'')::boolean
                                     FROM system_configs WHERE config_key='AFFILIATE_ENABLED'), false),
    'partners_total',  (SELECT count(*) FROM affiliate_partners),
    'partners_active', (SELECT count(*) FROM affiliate_partners WHERE is_active),
    'offers_total',    (SELECT count(*) FROM affiliate_offers),
    'offers_active',   (SELECT count(*) FROM affiliate_offers WHERE is_active),
    'clicks',          (SELECT count(*) FROM affiliate_clicks WHERE clicked_at >= v_since),
    'clicks_all_time', (SELECT count(*) FROM affiliate_clicks),
    -- Split by status, because only 'approved' is money. Reporting a single
    -- revenue figure that folds in pending and reversed rows overstates it.
    'conversions', COALESCE((
      SELECT jsonb_object_agg(status, cnt) FROM (
        SELECT status, count(*) AS cnt FROM affiliate_conversions
         WHERE reported_at >= v_since GROUP BY status
      ) s), '{}'::jsonb),
    'commission_approved_usd', COALESCE((SELECT sum(commission_usd) FROM affiliate_conversions
                                          WHERE status='approved' AND reported_at >= v_since), 0),
    'commission_pending_usd',  COALESCE((SELECT sum(commission_usd) FROM affiliate_conversions
                                          WHERE status='pending' AND reported_at >= v_since), 0),
    -- Clicks that produced no conversion row at all. High and rising means
    -- either the offers are wrong or attribution is broken — and the second
    -- looks exactly like the first until someone checks.
    'clicks_unconverted', (SELECT count(*) FROM affiliate_clicks c
                            WHERE c.clicked_at >= v_since
                              AND NOT EXISTS (SELECT 1 FROM affiliate_conversions cv WHERE cv.click_id = c.id)),
    'stale_offers', (SELECT count(*) FROM affiliate_offers o
                      WHERE o.is_active AND o.source='manual'
                        AND (o.price_checked_at IS NULL OR o.price_checked_at <
                             now() - make_interval(days => COALESCE(
                               (SELECT NULLIF(config_value,'')::integer FROM system_configs
                                 WHERE config_key='AFFILIATE_PRICE_MAX_AGE_DAYS'), 14)))),
    'top_countries', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('country', country_code, 'clicks', n) ORDER BY n DESC)
      FROM (SELECT country_code, count(*) AS n FROM affiliate_clicks
             WHERE clicked_at >= v_since AND country_code IS NOT NULL
             GROUP BY country_code ORDER BY n DESC LIMIT 10) t), '[]'::jsonb),
    'by_partner', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'code', ap.code, 'name', ap.display_name, 'is_active', ap.is_active,
        'clicks', (SELECT count(*) FROM affiliate_clicks c
                    WHERE c.partner_id = ap.id AND c.clicked_at >= v_since),
        'conversions', (SELECT count(*) FROM affiliate_conversions cv
                         WHERE cv.partner_id = ap.id AND cv.reported_at >= v_since),
        'commission_approved_usd', COALESCE((SELECT sum(cv.commission_usd) FROM affiliate_conversions cv
                                    WHERE cv.partner_id = ap.id AND cv.status='approved'
                                      AND cv.reported_at >= v_since), 0)
      ) ORDER BY ap.priority)
      FROM affiliate_partners ap), '[]'::jsonb)
  ) INTO v_result;

  RETURN v_result;
END;
$fn$;

-- ───────────────────────────────────────────────────────────────────────────
-- 4. Grants
-- ───────────────────────────────────────────────────────────────────────────
DO $do$
DECLARE s text;
BEGIN
  FOREACH s IN ARRAY ARRAY[
    'admin_list_affiliate_partners()',
    'admin_upsert_affiliate_partner(text,jsonb,text)',
    'admin_list_affiliate_offers(text,integer)',
    'admin_upsert_affiliate_offer(uuid,jsonb,text)',
    'admin_delete_affiliate_offer(uuid,text)',
    'admin_affiliate_overview(integer)'
  ]
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM public, anon', s);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO authenticated', s);
  END LOOP;
END $do$;

COMMIT;
