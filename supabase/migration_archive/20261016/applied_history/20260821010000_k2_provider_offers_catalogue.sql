-- =============================================================================
-- K2 · provider_offers — one curated catalogue for top-ups AND eSIMs
-- =============================================================================
-- WHY THIS EXISTS
--
--   Two caches held the shelf: `provider_offers_cache` (783 top-up rows) and
--   `esim_offers_cache` (5,412 eSIM bundles). Both are the landing zone of a
--   daily sync that upserts every row, so ANY hand-edit an operator makes is
--   gone by morning. There was nowhere to put a manual price.
--
--   They also had no shared shape, so "what can we sell for Egypt" had two
--   different answers in two different column vocabularies, and the admin app
--   would need two screens to show one shelf.
--
-- THE ONE IDEA: A SYNCED LAYER AND AN OVERRIDE LAYER IN THE SAME ROW
--
--   `source_*` belongs to `refresh_provider_offers()`. It is overwritten on
--   every run and must never be hand-edited.
--   `override_*` belongs to the admin UI. The refresh NEVER writes it.
--   `effective_*` are GENERATED columns — COALESCE(override, source).
--
--   That is what makes "updated daily AND editable by hand" possible without
--   the two fighting. An operator's price survives the sync because the sync
--   cannot see the column it is stored in. A NULL override is not "no price";
--   it means "whatever the supplier says today", which is the right default.
--
--   The retirement rule is the same one J1 learned the hard way: a row that
--   vanishes from the supplier feed is marked `source_is_active = false`, never
--   deleted — deleting it would take the operator's override with it, and an
--   empty fetch would otherwise retire the whole shop.
--
-- THE PRICE BUG THIS FIXES (measured on 2026-08-08, not hypothesised)
--
--   `queue_premium_refill_executions` queued each pre-paid refill at
--   `carrier_rules.minimum_topup_amount` while stamping it with
--   `carrier_rules.offer_id`. Those are two independent hand-typed fields and
--   nothing ever reconciled them against the supplier's actual price.
--
--     STC: queued $6.25 against STC_SA_001_USD, which costs $7.10.
--     `worker_auto_mini_refill.js` → `resolveVerifiedOffer` correctly refused:
--     "Offer price mismatch: STC_SA_001_USD costs 7.1 USD but 6.25 USD was
--     charged." Every STC premium refill fails, permanently.
--
--   This is NOT one bad row. Of the 36 carrier rules naming an offer, **23**
--   name one whose real FIXED price differs from the queued amount and **3**
--   name an offer no enabled catalogue contains (Jio/Airtel/BSNL's
--   `-I-BUNDLE` codes). Zain KSA is the only premium line that has ever
--   succeeded, and only because its rule has `offer_id IS NULL`, so the worker
--   matched by VALUE against a $1–50 RANGE offer instead of by code.
--
--   Worse, `carrier_rules.inapp_pricing` — the per-refill figure the CUSTOMER
--   is billed through `plan_price_net` — is also below the real cost nearly
--   everywhere (Turkcell bills $7.58 against a $10.00 cost, a 24% loss per
--   refill). Premium has been sold below the cost of fulfilling it.
--
--   The fix is not to re-type the numbers. It is to stop having a second copy
--   of them: `carrier_refill_offer()` reads the price from the catalogue, and
--   both the quote and the execution go through it. A hand-typed number can
--   still win, but only via `override_price_usd`, in one place, visible in the
--   admin UI, and never below what the supplier charges.
--
-- SCOPE NOTE
--   Rows are kept for every country in `countries` (21), not only the 16 with
--   `is_supported = true`. The EFFECTIVE view filters on `is_supported`, so
--   turning a country on is one UPDATE and takes effect immediately instead of
--   waiting for a re-sync. Nothing is silently dropped: DE/GB/JO/TR/US hold 457
--   real top-up offers and no live SIM lines, and losing them at refresh time
--   would be invisible.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. provider_offers
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.provider_offers (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_code         text NOT NULL REFERENCES public.service_providers(code)
                          ON UPDATE CASCADE ON DELETE RESTRICT,
  offer_kind            text NOT NULL CHECK (offer_kind IN ('topup', 'esim')),
  -- The supplier's own identifier: provider_offers_cache.offer_id for top-ups,
  -- esim_offers_cache.bundle_name for eSIMs.
  offer_code            text NOT NULL,
  country_code          text NOT NULL,
  -- Top-ups belong to a telecom; eSIMs do not. NULL for every esim row.
  carrier_id            uuid REFERENCES public.carriers(id) ON DELETE CASCADE,

  -- ---- synced layer — refresh_provider_offers() owns these -----------------
  source_name           text,
  source_price_type     text NOT NULL DEFAULT 'FIXED'
                          CHECK (source_price_type IN ('FIXED', 'RANGE')),
  -- The ENTRY price: what one unit costs at the low end. FIXED offers have one
  -- price; RANGE offers start at price_min. Always populated so that "cheapest
  -- first" is a single comparable column and no caller re-derives it.
  source_price_usd      numeric(12,4),
  source_price_min_usd  numeric(12,4),
  source_price_max_usd  numeric(12,4),
  source_send_min       numeric(14,4),
  source_send_max       numeric(14,4),
  source_send_currency  text,
  source_send_divisor   numeric(12,4),
  -- eSIM-only shape. J1: unlimited arrives as -1, never 0, and 72% of the
  -- catalogue is unlimited — so data_mb is NULL for unlimited, never 0, or
  -- every $/GB sort ranks them as free.
  source_data_mb        bigint,
  source_duration_days  integer,
  source_is_unlimited   boolean NOT NULL DEFAULT false,
  source_speed_tier     text,
  source_is_active      boolean NOT NULL DEFAULT true,
  source_refreshed_at   timestamptz,

  -- ---- override layer — the admin UI owns these, the sync never writes them -
  override_name         text,
  override_price_usd    numeric(12,4) CHECK (override_price_usd IS NULL OR override_price_usd >= 0),
  override_is_active    boolean,
  override_note         text,
  overridden_by         uuid,
  overridden_at         timestamptz,

  -- ---- effective — what every reader should use ----------------------------
  effective_name        text    GENERATED ALWAYS AS (COALESCE(override_name, source_name)) STORED,
  effective_price_usd   numeric(12,4) GENERATED ALWAYS AS (COALESCE(override_price_usd, source_price_usd)) STORED,
  is_active             boolean GENERATED ALWAYS AS (COALESCE(override_is_active, source_is_active)) STORED,

  first_seen_at         timestamptz NOT NULL DEFAULT now(),
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),

  -- A top-up row must name a telecom; an eSIM row must not.
  CONSTRAINT provider_offers_carrier_matches_kind
    CHECK ((offer_kind = 'topup' AND carrier_id IS NOT NULL)
        OR (offer_kind = 'esim'  AND carrier_id IS NULL)),
  CONSTRAINT provider_offers_range_priced
    CHECK (source_price_type <> 'RANGE'
        OR (source_price_min_usd IS NOT NULL AND source_price_max_usd IS NOT NULL))
);

-- carrier_id is NULL for every esim row, and NULLs are DISTINCT in a plain
-- UNIQUE constraint — which would let the same bundle land twice per country on
-- every refresh. COALESCE to a sentinel so the key actually holds.
CREATE UNIQUE INDEX IF NOT EXISTS uq_provider_offers_identity
  ON public.provider_offers (
    provider_code, offer_kind, offer_code, country_code,
    COALESCE(carrier_id, '00000000-0000-0000-0000-000000000000'::uuid)
  );

CREATE INDEX IF NOT EXISTS idx_provider_offers_topup_lookup
  ON public.provider_offers (carrier_id, is_active, effective_price_usd)
  WHERE offer_kind = 'topup';

CREATE INDEX IF NOT EXISTS idx_provider_offers_esim_lookup
  ON public.provider_offers (country_code, is_active, effective_price_usd)
  WHERE offer_kind = 'esim';

CREATE INDEX IF NOT EXISTS idx_provider_offers_overridden
  ON public.provider_offers (provider_code, offer_kind)
  WHERE override_price_usd IS NOT NULL OR override_is_active IS NOT NULL;

COMMENT ON TABLE public.provider_offers IS
  'K2: the curated shelf — every offer a service provider sells us, top-up and '
  'eSIM in one shape. source_* is rewritten by refresh_provider_offers() nightly; '
  'override_* is the admin UI''s and the refresh never touches it; effective_* is '
  'what callers read. Overrides survive the sync because the sync cannot see them.';

COMMENT ON COLUMN public.provider_offers.source_price_usd IS
  'Entry price in USD: the fixed price, or the low end of a RANGE. Always set, so '
  '"cheapest first" is one comparable column and no caller re-derives it.';

COMMENT ON COLUMN public.provider_offers.override_price_usd IS
  'Admin-set price. Wins over source_price_usd. Guarded by carrier_refill_offer(), '
  'which refuses to quote below the supplier''s own cost — a manual price that '
  'undercuts wholesale is how premium came to be sold at a loss.';

COMMENT ON COLUMN public.provider_offers.source_is_active IS
  'False = the supplier stopped listing it. Set by the retirement sweep, never by '
  'deletion: deleting would take the operator''s override with it.';

ALTER TABLE public.provider_offers ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.provider_offers FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.provider_offers TO service_role;

-- -----------------------------------------------------------------------------
-- 2. The effective shelf — what a caller should read
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.provider_offers_effective AS
SELECT
  o.id,
  o.provider_code,
  sp.name AS provider_name,
  o.offer_kind,
  o.offer_code,
  o.country_code,
  co.name AS country_name,
  o.carrier_id,
  ca.name AS carrier_name,
  o.effective_name        AS offer_name,
  o.source_price_type     AS price_type,
  o.effective_price_usd   AS price_usd,
  o.source_price_min_usd  AS price_min_usd,
  o.source_price_max_usd  AS price_max_usd,
  o.source_send_min       AS send_min,
  o.source_send_max       AS send_max,
  o.source_send_currency  AS send_currency,
  o.source_send_divisor   AS send_currency_divisor,
  o.source_data_mb        AS data_mb,
  o.source_duration_days  AS duration_days,
  o.source_is_unlimited   AS is_unlimited,
  o.source_speed_tier     AS speed_tier,
  -- Cost is what the SUPPLIER charges; price is what we decided to show. They
  -- differ exactly when an override is set, and every margin check needs both.
  o.source_price_usd      AS supplier_cost_usd,
  (o.override_price_usd IS NOT NULL) AS price_is_overridden,
  o.override_note,
  o.source_refreshed_at,
  (o.source_refreshed_at < now() - interval '24 hours') AS is_stale
FROM public.provider_offers o
JOIN public.service_providers sp ON sp.code = o.provider_code
JOIN public.countries         co ON co.iso_code = o.country_code
LEFT JOIN public.carriers     ca ON ca.id = o.carrier_id
WHERE o.is_active
  AND sp.is_active
  -- Scoped at READ time, not at refresh time: flipping a country on is one
  -- UPDATE and takes effect at once, with no data lost in the meantime.
  AND co.is_supported;

COMMENT ON VIEW public.provider_offers_effective IS
  'K2: the sellable shelf — active offers from active suppliers in KeepSIMs'' '
  'supported countries, with overrides already applied. Filters is_supported at '
  'read time so enabling a country needs no re-sync.';

ALTER VIEW public.provider_offers_effective SET (security_invoker = on);
REVOKE ALL ON public.provider_offers_effective FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.provider_offers_effective TO service_role;

-- -----------------------------------------------------------------------------
-- 3. refresh_provider_offers() — rebuild source_*, never touch override_*
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.refresh_provider_offers()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_topup    integer := 0;
  v_esim     integer := 0;
  v_retired  integer := 0;
  v_src_top  integer;
  v_src_esim integer;
BEGIN
  SELECT count(*) INTO v_src_top  FROM public.provider_offers_cache;
  SELECT count(*) INTO v_src_esim FROM public.esim_offers_cache WHERE is_active;

  -- J1's rule, generalised: an empty upstream is indistinguishable from a
  -- failed fetch, and retiring on it would empty the shop. Refuse the whole run.
  IF v_src_top = 0 AND v_src_esim = 0 THEN
    RETURN jsonb_build_object('status', 'skipped',
      'reason', 'both upstream caches are empty — refusing to retire the catalogue');
  END IF;

  -- ---- top-ups -------------------------------------------------------------
  -- Joined through carrier_provider_map, which is what resolves a supplier's own
  -- (country, carrier) labels back to a KeepSIMs carrier. Mappings that are off
  -- are still catalogued: you cannot compare a supplier you refuse to look at,
  -- and `is_routable` on carrier_supplier_routing is what gates actual routing.
  IF v_src_top > 0 THEN
    INSERT INTO public.provider_offers AS po (
      provider_code, offer_kind, offer_code, country_code, carrier_id,
      source_name, source_price_type, source_price_usd,
      source_price_min_usd, source_price_max_usd,
      source_send_min, source_send_max, source_send_currency, source_send_divisor,
      source_is_active, source_refreshed_at
    )
    -- DISTINCT ON is not decoration: ON CONFLICT DO UPDATE raises
    -- "cannot affect row a second time" if one statement presents the same key
    -- twice, and two carriers sharing a provider_carrier_code would do exactly
    -- that. Zero such pairs today; this stops the first one being an outage.
    SELECT DISTINCT ON (p.api_provider, p.offer_id, p.country_code, m.carrier_id)
      p.api_provider, 'topup', p.offer_id, p.country_code, m.carrier_id,
      p.offer_name, p.price_type,
      COALESCE(p.price_fixed_usd, p.price_min_usd),
      p.price_min_usd, p.price_max_usd,
      p.send_min, p.send_max, p.send_currency, p.send_currency_divisor,
      true, p.refreshed_at
    FROM public.provider_offers_cache p
    JOIN public.carrier_provider_map m
      ON m.provider              = p.api_provider
     AND m.provider_country_code = p.country_code
     AND m.provider_carrier_code = p.carrier_code
    JOIN public.countries co ON co.iso_code = p.country_code
    ORDER BY p.api_provider, p.offer_id, p.country_code, m.carrier_id,
             m.is_primary DESC, m.priority ASC
    ON CONFLICT (provider_code, offer_kind, offer_code, country_code,
                 COALESCE(carrier_id, '00000000-0000-0000-0000-000000000000'::uuid))
    DO UPDATE SET
      source_name          = EXCLUDED.source_name,
      source_price_type    = EXCLUDED.source_price_type,
      source_price_usd     = EXCLUDED.source_price_usd,
      source_price_min_usd = EXCLUDED.source_price_min_usd,
      source_price_max_usd = EXCLUDED.source_price_max_usd,
      source_send_min      = EXCLUDED.source_send_min,
      source_send_max      = EXCLUDED.source_send_max,
      source_send_currency = EXCLUDED.source_send_currency,
      source_send_divisor  = EXCLUDED.source_send_divisor,
      source_is_active     = true,
      source_refreshed_at  = EXCLUDED.source_refreshed_at,
      updated_at           = now();
    GET DIAGNOSTICS v_topup = ROW_COUNT;
  END IF;

  -- ---- eSIMs ---------------------------------------------------------------
  -- One bundle covers many countries, so it fans out to one row per country it
  -- serves — that is what makes "what can we sell in Egypt" answerable with an
  -- equality instead of an array scan.
  IF v_src_esim > 0 THEN
    INSERT INTO public.provider_offers AS po (
      provider_code, offer_kind, offer_code, country_code, carrier_id,
      source_name, source_price_type, source_price_usd,
      source_data_mb, source_duration_days, source_is_unlimited, source_speed_tier,
      source_is_active, source_refreshed_at
    )
    SELECT DISTINCT ON (e.provider, e.bundle_name, co.iso_code)
      e.provider, 'esim', e.bundle_name, co.iso_code, NULL::uuid,
      COALESCE(e.description, e.bundle_name), 'FIXED', e.wholesale_price_usd,
      -- Unlimited is stored as NULL, never 0: a 0 here makes every $/GB sort
      -- rank 72% of the catalogue as free (J1).
      CASE WHEN e.is_unlimited OR e.data_amount_mb <= 0 THEN NULL ELSE e.data_amount_mb END,
      NULLIF(e.duration_days, 0), e.is_unlimited, e.speed_tier,
      true, e.updated_at
    FROM public.esim_offers_cache e
    JOIN public.countries co
      ON co.iso_code = ANY (e.countries) OR co.iso_code = ANY (e.roaming_enabled)
    WHERE e.is_active
    ORDER BY e.provider, e.bundle_name, co.iso_code, e.updated_at DESC
    ON CONFLICT (provider_code, offer_kind, offer_code, country_code,
                 COALESCE(carrier_id, '00000000-0000-0000-0000-000000000000'::uuid))
    DO UPDATE SET
      source_name          = EXCLUDED.source_name,
      source_price_usd     = EXCLUDED.source_price_usd,
      source_data_mb       = EXCLUDED.source_data_mb,
      source_duration_days = EXCLUDED.source_duration_days,
      source_is_unlimited  = EXCLUDED.source_is_unlimited,
      source_speed_tier    = EXCLUDED.source_speed_tier,
      source_is_active     = true,
      source_refreshed_at  = EXCLUDED.source_refreshed_at,
      updated_at           = now();
    GET DIAGNOSTICS v_esim = ROW_COUNT;
  END IF;

  -- ---- retirement ----------------------------------------------------------
  -- Only sweep a kind whose upstream actually produced rows this run, or a
  -- failed top-up fetch would retire every top-up while the eSIM half looked
  -- healthy. Marked, never deleted — the override layer must survive.
  UPDATE public.provider_offers o
     SET source_is_active = false, updated_at = now()
   WHERE o.source_is_active
     AND ((o.offer_kind = 'topup' AND v_src_top > 0
           AND NOT EXISTS (
             SELECT 1 FROM public.provider_offers_cache p
              JOIN public.carrier_provider_map m
                ON m.provider = p.api_provider
               AND m.provider_country_code = p.country_code
               AND m.provider_carrier_code = p.carrier_code
              WHERE p.api_provider = o.provider_code
                AND p.offer_id     = o.offer_code
                AND p.country_code = o.country_code
                AND m.carrier_id   = o.carrier_id))
       OR (o.offer_kind = 'esim' AND v_src_esim > 0
           AND NOT EXISTS (
             SELECT 1 FROM public.esim_offers_cache e
              WHERE e.provider = o.provider_code
                AND e.bundle_name = o.offer_code
                AND e.is_active
                AND (o.country_code = ANY (e.countries)
                  OR o.country_code = ANY (e.roaming_enabled)))));
  GET DIAGNOSTICS v_retired = ROW_COUNT;

  RETURN jsonb_build_object(
    'status', 'ok',
    'topup_upserted', v_topup,
    'esim_upserted',  v_esim,
    'retired',        v_retired,
    'source_topup',   v_src_top,
    'source_esim',    v_src_esim,
    'refreshed_at',   now());
END;
$function$;

REVOKE ALL ON FUNCTION public.refresh_provider_offers() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_provider_offers() TO service_role;

COMMENT ON FUNCTION public.refresh_provider_offers() IS
  'K2: rebuilds provider_offers.source_* from both upstream caches. Never writes '
  'override_*. Refuses to run when both caches are empty, and retires only the '
  'kind whose upstream produced rows — either guard alone empties the shop.';

-- -----------------------------------------------------------------------------
-- 4. carrier_refill_offer() — the real price, replacing the hand-typed one
-- -----------------------------------------------------------------------------
-- This is the fix for the STC failure. Given a carrier and the smallest top-up
-- that qualifies for validity, it returns an offer that CAN ACTUALLY BE BOUGHT
-- at a price the supplier will honour. Callers stop reading
-- carrier_rules.minimum_topup_amount as if it were a price.
CREATE OR REPLACE FUNCTION public.carrier_refill_offer(
  p_carrier_id uuid,
  p_min_usd    numeric DEFAULT NULL
)
RETURNS TABLE (
  provider_code   text,
  offer_code      text,
  price_type      text,
  price_usd       numeric,
  supplier_cost_usd numeric,
  offer_value     numeric,
  is_overridden   boolean,
  is_stale        boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT
    o.provider_code,
    o.offer_code,
    o.source_price_type,
    -- A RANGE offer can be bought at exactly the qualifying amount, as long as
    -- that sits inside the band. A FIXED offer costs what it costs — rounding
    -- it towards the rule's number is precisely the bug being fixed.
    CASE WHEN o.source_price_type = 'RANGE'
         THEN GREATEST(o.source_price_min_usd,
                       LEAST(o.source_price_max_usd, COALESCE(p_min_usd, o.source_price_min_usd)))
         ELSE o.effective_price_usd END,
    o.source_price_usd,
    -- The send value a RANGE offer must carry, interpolated the same way
    -- ingest_offline_refill and run_auto_rescue already do it.
    CASE WHEN o.source_price_type = 'RANGE'
              AND o.source_price_max_usd > o.source_price_min_usd
         THEN round(o.source_send_min
                    + (GREATEST(o.source_price_min_usd,
                        LEAST(o.source_price_max_usd, COALESCE(p_min_usd, o.source_price_min_usd)))
                       - o.source_price_min_usd)
                      * (o.source_send_max - o.source_send_min)
                      / (o.source_price_max_usd - o.source_price_min_usd))
         ELSE NULL END,
    (o.override_price_usd IS NOT NULL),
    (o.source_refreshed_at < now() - interval '24 hours')
  FROM public.provider_offers o
  JOIN public.carrier_supplier_routing r
    ON r.carrier_id = o.carrier_id AND r.provider_code = o.provider_code
  WHERE o.offer_kind = 'topup'
    AND o.carrier_id = p_carrier_id
    AND o.is_active
    AND r.is_routable
    -- Must reach the qualifying amount, or the top-up buys airtime without
    -- resetting the validity clock — money spent for nothing.
    AND (p_min_usd IS NULL
         OR (o.source_price_type = 'RANGE' AND o.source_price_max_usd >= p_min_usd)
         OR (o.source_price_type = 'FIXED' AND o.effective_price_usd  >= p_min_usd))
  ORDER BY
    CASE WHEN o.source_price_type = 'RANGE'
         THEN GREATEST(o.source_price_min_usd,
                       LEAST(o.source_price_max_usd, COALESCE(p_min_usd, o.source_price_min_usd)))
         ELSE o.effective_price_usd END ASC,
    r.priority ASC,
    o.offer_code ASC
  LIMIT 1;
$function$;

REVOKE ALL ON FUNCTION public.carrier_refill_offer(uuid, numeric) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.carrier_refill_offer(uuid, numeric) TO service_role;

COMMENT ON FUNCTION public.carrier_refill_offer(uuid, numeric) IS
  'K2: the cheapest routable top-up offer for a carrier that actually reaches the '
  'validity-qualifying amount, priced from the catalogue. Replaces reading '
  'carrier_rules.minimum_topup_amount as a price — the divergence between those '
  'two numbers broke premium refills on 26 of 36 carriers.';

-- -----------------------------------------------------------------------------
-- 5. Backfill, then schedule
-- -----------------------------------------------------------------------------
SELECT public.refresh_provider_offers();

-- After J1's 03:40 eSIM sync and the VM's top-up cache run, so the curated shelf
-- is built from fresh upstream rather than yesterday's. Unschedule first: re-running
-- this migration would otherwise stack duplicate jobs.
DO $$
BEGIN
  PERFORM cron.unschedule('refresh-provider-offers');
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

SELECT cron.schedule(
  'refresh-provider-offers',
  '30 4 * * *',
  $$SELECT public.refresh_provider_offers();$$
);
