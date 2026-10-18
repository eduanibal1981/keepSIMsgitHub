-- J1 — eSIM catalogue enrichment
--
-- Context: `esim_offers_cache` held 50 rows because `worker_esim_catalog.js`
-- called GET /catalogue once and kept page 1. The live catalogue is 5,412
-- bundles over 28 pages, reaching 220 countries. Egypt alone has 141 bundles
-- and the app showed zero.
--
-- Pulling the rest in is not a data-only change. Three real product dimensions
-- arrive with it that the schema could not express, and each one is a wrong
-- answer on screen if it stays unmodelled:
--
--   1. 3,894 of 5,412 bundles are UNLIMITED. eSIM Go sends `dataAmount: -1`.
--      The client computes $/GB as `price / (mb/1024)` and returns 0.0 when mb
--      <= 0, so "sort by $/GB" would rank every unlimited plan as free and put
--      72% of the catalogue above every metered plan. `price_per_gb` is
--      therefore NULL for unlimited in the view — NULL sorts to the end under
--      NULLS LAST and cannot be mistaken for zero.
--
--   2. Unlimited is sold in four speed tiers (Lite / Essential / Plus, plus
--      Long Duration). Two rows can be "unlimited, 30 days, Egypt" at very
--      different prices and the only honest difference is throughput. Without
--      `speed_tier` the cheaper one always wins a comparison it should not.
--
--   3. Coverage now spans 1..106 countries per bundle. The client's
--      local/regional/global split is derived from array length at render
--      time; `country_count` is stored so the same split can happen in SQL,
--      where the filtering has to move anyway.
--
-- `bundle_name` is untouched: `request_esim_purchase` resolves offers by it.

BEGIN;

-- ── 1. New descriptive columns ──────────────────────────────────────────────
ALTER TABLE public.esim_offers_cache
  ADD COLUMN IF NOT EXISTS is_unlimited  boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS bundle_group  text,
  ADD COLUMN IF NOT EXISTS speed_tier    text,
  ADD COLUMN IF NOT EXISTS region        text,
  ADD COLUMN IF NOT EXISTS country_count integer NOT NULL DEFAULT 0;

-- speed_tier is a normalised read of eSIM Go's `groups`, kept small and closed
-- so the UI can order it. NULL is allowed: a future supplier may not grade
-- speed at all, and inventing a tier for it would be a claim we cannot support.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'esim_offers_cache_speed_tier_check'
  ) THEN
    ALTER TABLE public.esim_offers_cache
      ADD CONSTRAINT esim_offers_cache_speed_tier_check
      CHECK (speed_tier IS NULL OR speed_tier IN ('fixed','lite','essential','plus','long_duration'));
  END IF;
END $$;

-- ── 2. Backfill the 50 rows already cached ──────────────────────────────────
-- All of them are Standard Fixed 1GB/7d, so this is exact, not a guess.
UPDATE public.esim_offers_cache
   SET is_unlimited  = (data_amount_mb <= 0),
       bundle_group  = COALESCE(bundle_group, 'Standard Fixed'),
       speed_tier    = COALESCE(speed_tier, 'fixed'),
       country_count = GREATEST(
         cardinality(ARRAY(SELECT DISTINCT unnest(countries || roaming_enabled))), 0)
 WHERE bundle_group IS NULL OR country_count = 0;

-- country_count must never drift from the arrays it summarises.
CREATE OR REPLACE FUNCTION public.trg_fn_esim_offer_country_count()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  NEW.country_count := cardinality(
    ARRAY(SELECT DISTINCT unnest(COALESCE(NEW.countries, '{}') || COALESCE(NEW.roaming_enabled, '{}')))
  );
  -- A supplier that reports a negative allowance means "no cap", not "owes us
  -- data". Normalise to 0 so no arithmetic anywhere has to know about -1.
  IF NEW.data_amount_mb < 0 THEN
    NEW.is_unlimited   := true;
    NEW.data_amount_mb := 0;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_esim_offer_country_count ON public.esim_offers_cache;
CREATE TRIGGER trg_esim_offer_country_count
  BEFORE INSERT OR UPDATE OF countries, roaming_enabled, data_amount_mb
  ON public.esim_offers_cache
  FOR EACH ROW EXECUTE FUNCTION public.trg_fn_esim_offer_country_count();

-- ── 3. Indexes the 5,412-row catalogue needs ────────────────────────────────
-- `getPlans()` downloaded the whole table and filtered in Dart. That was
-- survivable at 50 rows and is not at 5,412; the filter moves to SQL, and
-- these are what make it cheap. GIN over the array is the operative one —
-- `countries @> ARRAY['EG']` is the query the compare screen runs constantly.
CREATE INDEX IF NOT EXISTS idx_esim_offers_cache_countries
  ON public.esim_offers_cache USING gin (countries);
CREATE INDEX IF NOT EXISTS idx_esim_offers_cache_roaming
  ON public.esim_offers_cache USING gin (roaming_enabled);
CREATE INDEX IF NOT EXISTS idx_esim_offers_cache_active_price
  ON public.esim_offers_cache (is_active, wholesale_price_usd);

-- ── 4. Retail view gains the new dimensions ─────────────────────────────────
-- CREATE OR REPLACE (not DROP+CREATE) on purpose: G5b revoked every write verb
-- on this view after proving anon could DELETE the whole catalogue through it,
-- and it is deliberately NOT security_invoker so wholesale stays hidden. A
-- DROP would silently restore the default GRANT ALL and undo both. Replace
-- only appends columns, so the existing grants and column order survive.
CREATE OR REPLACE VIEW public.esim_offers AS
  SELECT (provider || '_'::text) || bundle_name AS id,
    provider,
    bundle_name,
    description,
    countries,
    roaming_enabled,
    data_amount_mb,
    duration_days,
    round(wholesale_price_usd * (1.0 + COALESCE((
        SELECT NULLIF(system_configs.config_value::text, ''::text)::numeric
          FROM system_configs
         WHERE system_configs.config_key::text = 'ESIM_MARKUP_PERCENT'::text), 30.0) / 100.0), 2)::numeric(10,2) AS retail_price_usd,
    image_url,
    is_active,
    updated_at,
    -- Appended by J1 ↓
    is_unlimited,
    bundle_group,
    speed_tier,
    region,
    country_count,
    -- NULL, never 0, for unlimited. See the header note: a 0 here is the
    -- difference between "cheapest per GB" and "has no GB".
    CASE
      WHEN is_unlimited OR data_amount_mb <= 0 THEN NULL
      ELSE round(
        round(wholesale_price_usd * (1.0 + COALESCE((
            SELECT NULLIF(system_configs.config_value::text, ''::text)::numeric
              FROM system_configs
             WHERE system_configs.config_key::text = 'ESIM_MARKUP_PERCENT'::text), 30.0) / 100.0), 2)
        / (data_amount_mb::numeric / 1024.0), 2)
    END::numeric(10,2) AS price_per_gb_usd
   FROM esim_offers_cache c
  WHERE is_active = true;

COMMIT;
