-- J2 — the affiliate rail
--
-- KeepSIMs now sells connectivity two different ways, and they are not
-- variations of one thing:
--
--   RESALE    (eSIM Go today) — we hold the wholesale price, add markup, take
--             the money into our wallet, and owe the customer an eSIM. Failure
--             is our problem. Revenue is the margin, realised at purchase.
--
--   AFFILIATE (Billion Connect via Impact, Orange via Affilae, more later) —
--             we hold no inventory, take no money and owe no fulfilment. We
--             show the partner's own advertised price and hand the customer
--             over on a tracked link. Revenue is a commission that appears in
--             the network's report days or weeks later, and can be reversed.
--
-- Trying to force the second through `esim_orders`/`request_esim_purchase`
-- would mean an order we cannot fulfil and a debit we must not take, so the
-- affiliate rail gets its own tables. The ONE thing the two share is the
-- comparison surface: `compare_esim_offers()` returns both in a single ranked
-- list, because a comparison split across two tabs is not a comparison.
--
-- Ships INERT: `AFFILIATE_ENABLED = false`, every seeded partner
-- `is_active = false`. With the flag off `compare_esim_offers()` returns
-- exactly the resale rows the app already showed, so applying this migration
-- changes no live decision.

BEGIN;

-- ───────────────────────────────────────────────────────────────────────────
-- 1. Networks — how we talk to an affiliate platform
-- ───────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.affiliate_networks (
  code                text PRIMARY KEY,
  name                text NOT NULL,
  api_base_url        text,
  docs_url            text,
  -- Vault secret NAME, never a credential. Same stance as esim_go_api_key.
  credential_secret   text,
  -- The query parameter this network uses to carry our own opaque click id
  -- back to us in its conversion reports. Impact calls it subId1; others
  -- differ. Stored rather than hardcoded so adding a network is a row.
  click_param         text NOT NULL DEFAULT 'subId1',
  -- The parameter that carries a deep-link destination, when supported.
  deeplink_param      text,
  is_active           boolean NOT NULL DEFAULT false,
  notes               text,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

-- ───────────────────────────────────────────────────────────────────────────
-- 2. Partners — the brand a user actually sees
-- ───────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.affiliate_partners (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  network_code          text NOT NULL REFERENCES public.affiliate_networks(code),
  code                  text NOT NULL UNIQUE,
  display_name          text NOT NULL,
  logo_url              text,
  website_url           text,
  -- Network-side identifiers, needed to pull reports and build links.
  external_advertiser_id text,
  external_campaign_id   text,
  default_tracking_url   text,
  -- What we are paid. Kept for admin margin comparison and NEVER exposed to
  -- the client — same reason `esim_offers_cache.wholesale_price_usd` is not:
  -- a user who can see our cut can see which recommendation pays us more.
  commission_percent    numeric(6,3),
  commission_note       text,
  -- App stores and consumer law both require the relationship be disclosed.
  -- Default true, and the compare RPC refuses to emit a partner row without a
  -- disclosure, so forgetting cannot ship silently.
  disclosure_required   boolean NOT NULL DEFAULT true,
  countries_supported   text[] NOT NULL DEFAULT '{}',
  priority              integer NOT NULL DEFAULT 100,
  is_active             boolean NOT NULL DEFAULT false,
  notes                 text,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_affiliate_partners_active
  ON public.affiliate_partners (is_active, priority);

-- ───────────────────────────────────────────────────────────────────────────
-- 3. Offers — the comparable products
-- ───────────────────────────────────────────────────────────────────────────
-- Shaped deliberately like `esim_offers_cache` so the union in
-- `compare_esim_offers()` is a genuine like-for-like comparison rather than
-- two different things printed in one column.
CREATE TABLE IF NOT EXISTS public.affiliate_offers (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id          uuid NOT NULL REFERENCES public.affiliate_partners(id) ON DELETE CASCADE,
  external_offer_id   text,
  title               text NOT NULL,
  description         text,
  countries           text[] NOT NULL DEFAULT '{}',
  country_count       integer NOT NULL DEFAULT 0,
  data_amount_mb      bigint NOT NULL DEFAULT 0,
  is_unlimited        boolean NOT NULL DEFAULT false,
  duration_days       integer NOT NULL DEFAULT 0,
  speed_tier          text,
  -- The partner's advertised price, and the price after a coupon we hold.
  -- `list_price_usd` is what gets struck through on the card; if there is no
  -- discount it stays NULL and nothing is struck through, rather than showing
  -- a fake "was" price.
  price_usd           numeric(10,2) NOT NULL,
  list_price_usd      numeric(10,2),
  coupon_code         text,
  coupon_description  text,
  landing_url         text,
  currency_code       text NOT NULL DEFAULT 'USD',

  -- ── Provenance. This is the honesty machinery. ──
  -- Billion Connect publishes NO product feed through Impact (`/Catalogs`
  -- returns 0, `/Promos` 404s), so their offers can only be typed in by hand.
  -- A hand-typed price is a claim about someone else's shop that rots. The
  -- compare RPC therefore reports a price older than
  -- AFFILIATE_PRICE_MAX_AGE_DAYS as stale, and the UI shows the offer without
  -- a number instead of quoting a figure we can no longer stand behind.
  source              text NOT NULL DEFAULT 'manual'
                        CHECK (source IN ('manual','api')),
  price_checked_at    timestamptz,
  checked_by          uuid REFERENCES auth.users(id) ON DELETE SET NULL,

  is_active           boolean NOT NULL DEFAULT true,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT affiliate_offers_speed_tier_check
    CHECK (speed_tier IS NULL OR speed_tier IN ('fixed','lite','essential','plus','long_duration')),
  -- A "discount" that raises the price is a dark pattern; refuse it in the
  -- schema rather than trusting every admin form that will ever write here.
  CONSTRAINT affiliate_offers_list_price_check
    CHECK (list_price_usd IS NULL OR list_price_usd >= price_usd),
  CONSTRAINT affiliate_offers_price_positive
    CHECK (price_usd >= 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_affiliate_offers_external
  ON public.affiliate_offers (partner_id, external_offer_id)
  WHERE external_offer_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_affiliate_offers_countries
  ON public.affiliate_offers USING gin (countries);
CREATE INDEX IF NOT EXISTS idx_affiliate_offers_active
  ON public.affiliate_offers (is_active, price_usd);

-- Same anti-drift trigger the resale cache uses.
CREATE OR REPLACE FUNCTION public.trg_fn_affiliate_offer_normalise()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $fn$
BEGIN
  NEW.country_count := cardinality(ARRAY(SELECT DISTINCT unnest(COALESCE(NEW.countries, '{}'))));
  IF NEW.data_amount_mb < 0 THEN
    NEW.is_unlimited   := true;
    NEW.data_amount_mb := 0;
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_affiliate_offer_normalise ON public.affiliate_offers;
CREATE TRIGGER trg_affiliate_offer_normalise
  BEFORE INSERT OR UPDATE ON public.affiliate_offers
  FOR EACH ROW EXECUTE FUNCTION public.trg_fn_affiliate_offer_normalise();

-- ───────────────────────────────────────────────────────────────────────────
-- 4. Clicks — our own attribution record
-- ───────────────────────────────────────────────────────────────────────────
-- `id` IS the token we hand the network. It is a random uuid and nothing else:
-- the user id never leaves this database. The network learns that click
-- 9f3c… converted; only we can say who that was.
CREATE TABLE IF NOT EXISTS public.affiliate_clicks (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  partner_id    uuid NOT NULL REFERENCES public.affiliate_partners(id) ON DELETE CASCADE,
  offer_id      uuid REFERENCES public.affiliate_offers(id) ON DELETE SET NULL,
  country_code  text,
  device_id     text,
  target_url    text NOT NULL,
  clicked_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_affiliate_clicks_user   ON public.affiliate_clicks (user_id, clicked_at DESC);
CREATE INDEX IF NOT EXISTS idx_affiliate_clicks_partner ON public.affiliate_clicks (partner_id, clicked_at DESC);

-- ───────────────────────────────────────────────────────────────────────────
-- 5. Conversions — what the network says it owes us
-- ───────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.affiliate_conversions (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  network_code        text NOT NULL REFERENCES public.affiliate_networks(code),
  partner_id          uuid REFERENCES public.affiliate_partners(id) ON DELETE SET NULL,
  external_action_id  text NOT NULL,
  click_id            uuid REFERENCES public.affiliate_clicks(id) ON DELETE SET NULL,
  -- A commission is not money until it clears, and it can be reversed months
  -- later. Anything that reports revenue must filter on this.
  status              text NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending','approved','reversed','rejected')),
  sale_amount_usd     numeric(12,2),
  commission_usd      numeric(12,2),
  currency_code       text NOT NULL DEFAULT 'USD',
  occurred_at         timestamptz,
  reported_at         timestamptz NOT NULL DEFAULT now(),
  raw                 jsonb,
  UNIQUE (network_code, external_action_id)
);

CREATE INDEX IF NOT EXISTS idx_affiliate_conversions_click  ON public.affiliate_conversions (click_id);
CREATE INDEX IF NOT EXISTS idx_affiliate_conversions_status ON public.affiliate_conversions (status, occurred_at DESC);

-- ───────────────────────────────────────────────────────────────────────────
-- 6. Lockdown
-- ───────────────────────────────────────────────────────────────────────────
-- Deny-all to clients. Reads reach the app only through
-- `compare_esim_offers()`, which projects the public-safe columns and leaves
-- `commission_percent` behind — the same markup-isolation stance that keeps
-- `wholesale_price_usd` off the wire. G5b proved a table left with the default
-- GRANT ALL is a live DELETE surface for the anon key that ships in the APK,
-- so these are revoked explicitly rather than trusted to default to safe.
DO $do$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['affiliate_networks','affiliate_partners','affiliate_offers',
                           'affiliate_clicks','affiliate_conversions']
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('REVOKE ALL ON public.%I FROM anon, authenticated, public', t);
    EXECUTE format('GRANT ALL ON public.%I TO service_role', t);
  END LOOP;
END $do$;

-- ───────────────────────────────────────────────────────────────────────────
-- 7. Config knobs
-- ───────────────────────────────────────────────────────────────────────────
INSERT INTO public.system_configs (config_key, config_value) VALUES
  ('AFFILIATE_ENABLED',              'false'),
  ('AFFILIATE_PRICE_MAX_AGE_DAYS',   '14'),
  ('AFFILIATE_MAX_PARTNER_ROWS',     '25'),
  ('RATE_LIMIT_AFFILIATE_CLICK',     '60/60')
ON CONFLICT (config_key) DO NOTHING;

COMMIT;
