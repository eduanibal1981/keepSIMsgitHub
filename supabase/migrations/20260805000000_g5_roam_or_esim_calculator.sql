-- ============================================================================
-- G5 — "Roam or eSIM?" calculator
--
-- Feature suggestion #5 in doc/PRODUCTION_PLAN_REVIEW.md § 6. C8 already
-- resolves the caller's country from the request IP with zero permissions and
-- fires a `geo_fence_triggered` notification whose action_url is `/esim` — but
-- the screen it lands on has never been able to answer the only question the
-- traveller is actually asking: *is this cheaper than just roaming?*
--
-- This adds the missing half of that comparison: what the user's OWN carrier
-- charges to roam where they are standing.
--
-- ── Five deliberate departures from the sketch in the review ────────────────
--
-- 1. A CORRIDOR IS (carrier → destination), AND ONE ROW IS ONE PRODUCT, NOT
--    ONE CORRIDOR. Carriers do not sell "a roaming rate"; they sell a shelf of
--    packs. Zong alone publishes four different Saudi Arabia bundles. Keying
--    the table on (carrier, destination) would have forced a choice of which
--    one to call "the" rate; keying on (carrier, destination, product) lets
--    `roam_or_esim_quote()` pick the cheapest pack that actually covers the
--    trip, which is what a person would do.
--
-- 2. `destination_country_code = '*'` IS A REAL VALUE. Gulf and US carriers
--    sell a single worldwide/zone day pass (du AED 35/day, AT&T $12/day),
--    while South Asian carriers sell per-destination packs (Jazz PK→AE). Both
--    shapes have to fit. `'*'` means "any destination this carrier roams in";
--    an exact-country row and a `'*'` row are both candidates and the cheaper
--    wins. Four wildcard rows are what turn 16 seeded products into 89 priced
--    corridors — the review asked for 20.
--
-- 3. A DAY PASS IS A PACK WITH `bundle_days = 1`. There is no separate day-pass
--    shape. `bundle_data_mb IS NULL` means the pass publishes no data cap of
--    its own (AT&T's Day Pass re-uses the domestic allowance), so only the day
--    count drives how many are needed.
--
-- 4. EVERY USD FIGURE IS DERIVED, NEVER TYPED. `bundle_price_usd` is a
--    GENERATED column over `local_price / fx_rate_to_usd`. The carrier's own
--    currency and price are what is stored, next to the FX rate and the date
--    it was taken. Nobody can quietly edit a dollar figure, an owner
--    re-checking a tariff sees exactly the arithmetic, and refreshing FX is one
--    UPDATE. Every seeded row also carries `source_url`, and `verified_at` is
--    NULL on all of them — these are published tariffs read off the operator's
--    own site or its press release, not figures confirmed with the operator.
--    `is_estimate` is true and the UI says so.
--
-- 5. NOTHING HERE IS `SECURITY DEFINER`. `roam_or_esim_quote()` runs as the
--    caller. It reads `sim_lines` and `profiles` through their existing RLS
--    (so a user can only ever be quoted on carriers they actually hold a line
--    on), `carrier_roaming_rates` through a plain read-all policy, and retail
--    eSIM pricing through the `esim_offers` view — which is `security_invoker
--    = false` precisely so the markup stays isolated. The function never sees
--    `wholesale_price_usd`. That is the whole reason it can afford to be
--    INVOKER, and it sidesteps the `current_user`-inside-DEFINER trap this
--    project has now shipped four times (D5c, D5d, F4b, F1).
--
-- ⚠️ HONESTY CONSTRAINT ON THE OUTPUT. The live eSIM catalog is 50 bundles,
-- every one of them 1 GB / 7 days, covering only 4 of this product's 21
-- supported countries (AE, BD, BH, DE). The review's example line — "3 days
-- roaming ≈ $42 vs this 5 GB eSIM $11" — cannot be produced from it, because
-- no 5 GB bundle exists. So the quote reports `esim_covers_trip` and the
-- verdict distinguishes `esim_cheaper` from `esim_partial` (the best available
-- bundle is smaller than the trip) and from `no_esim` (nothing covers this
-- country at all). It never scales a 1 GB bundle up into an imaginary 5 GB one.
-- ============================================================================


-- ---------------------------------------------------------------------------
-- 1. carrier_roaming_rates — what a carrier charges its own subscribers to use
--    data abroad. Published tariff data, so it is world-readable to signed-in
--    users; it is not user data and holds no wholesale cost.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.carrier_roaming_rates (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  carrier_id    uuid NOT NULL REFERENCES public.carriers(id) ON DELETE CASCADE,

  -- ISO-3166-1 alpha-2, or '*' for a worldwide / zone-wide pass.
  destination_country_code text NOT NULL
    CHECK (destination_country_code = '*' OR destination_country_code ~ '^[A-Z]{2}$'),

  -- Stable slug, unique per corridor. Human name is what the carrier calls it.
  product_code  text NOT NULL,
  product_name  text NOT NULL,

  -- ── Shape A: a roaming pack (a day pass is simply bundle_days = 1) ────────
  -- NULL bundle_data_mb = the pass publishes no data cap of its own.
  bundle_data_mb bigint  CHECK (bundle_data_mb IS NULL OR bundle_data_mb > 0),
  bundle_days    integer CHECK (bundle_days    IS NULL OR bundle_days    > 0),

  -- ── Shape B: pay-as-you-go, the default disaster rate ────────────────────
  payg_per_mb_usd numeric(10,4) CHECK (payg_per_mb_usd IS NULL OR payg_per_mb_usd >= 0),

  -- ── Provenance. The USD price is DERIVED from these, never entered. ──────
  local_currency text        NOT NULL DEFAULT 'USD' CHECK (local_currency ~ '^[A-Z]{3}$'),
  local_price    numeric(12,2) CHECK (local_price IS NULL OR local_price >= 0),
  fx_rate_to_usd numeric(14,6) CHECK (fx_rate_to_usd IS NULL OR fx_rate_to_usd > 0),
  fx_rate_as_of  date,
  source_url     text,
  source_note    text,
  verified_at    date,        -- NULL = read off a public page, not confirmed with the carrier
  is_estimate    boolean NOT NULL DEFAULT true,
  is_active      boolean NOT NULL DEFAULT true,

  bundle_price_usd numeric(12,2)
    GENERATED ALWAYS AS (round(local_price / fx_rate_to_usd, 2)) STORED,

  created_at timestamptz NOT NULL DEFAULT NOW(),
  updated_at timestamptz NOT NULL DEFAULT NOW(),

  -- A row has to price something.
  CONSTRAINT carrier_roaming_rates_prices_something
    CHECK (payg_per_mb_usd IS NOT NULL
           OR (local_price IS NOT NULL AND fx_rate_to_usd IS NOT NULL AND bundle_days IS NOT NULL)),
  -- A pack needs all three of price, FX and duration, or it is not a pack.
  CONSTRAINT carrier_roaming_rates_pack_is_complete
    CHECK (num_nulls(local_price, fx_rate_to_usd, bundle_days) IN (0, 3)),

  CONSTRAINT carrier_roaming_rates_unique_product
    UNIQUE (carrier_id, destination_country_code, product_code)
);

CREATE INDEX IF NOT EXISTS carrier_roaming_rates_lookup_idx
  ON public.carrier_roaming_rates (carrier_id, destination_country_code)
  WHERE is_active;

COMMENT ON TABLE public.carrier_roaming_rates IS
  'G5: what a carrier charges ITS OWN subscribers for data abroad. One row per purchasable roaming product; destination_country_code = ''*'' is a worldwide/zone pass. bundle_price_usd is GENERATED from local_price / fx_rate_to_usd so no dollar figure is ever hand-typed. Read-all for authenticated; writes are service_role only.';
COMMENT ON COLUMN public.carrier_roaming_rates.bundle_data_mb IS
  'NULL = the pass publishes no data cap of its own (e.g. it re-uses the domestic allowance), so only bundle_days drives how many are needed.';
COMMENT ON COLUMN public.carrier_roaming_rates.verified_at IS
  'NULL = taken from a public page and never confirmed with the carrier. Every seeded row is NULL.';

DROP TRIGGER IF EXISTS trg_carrier_roaming_rates_updated_at ON public.carrier_roaming_rates;
CREATE TRIGGER trg_carrier_roaming_rates_updated_at
  BEFORE UPDATE ON public.carrier_roaming_rates
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


-- ---------------------------------------------------------------------------
-- 2. Grants + RLS.
--
-- The default privileges on this database still hand anon and authenticated a
-- full GRANT ALL on new public tables — including TRUNCATE, which RLS does not
-- gate. F6 revoked that table by table; a new table has to do it too or it
-- arrives with the same hole. Read is deliberately world-readable to signed-in
-- users: these are published tariffs, not user data.
-- ---------------------------------------------------------------------------
ALTER TABLE public.carrier_roaming_rates ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.carrier_roaming_rates FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.carrier_roaming_rates TO authenticated;
GRANT ALL    ON TABLE public.carrier_roaming_rates TO service_role;

DROP POLICY IF EXISTS "Signed-in users can read roaming rates" ON public.carrier_roaming_rates;
CREATE POLICY "Signed-in users can read roaming rates"
  ON public.carrier_roaming_rates
  FOR SELECT TO authenticated
  USING (is_active);
-- No INSERT/UPDATE/DELETE policy: the catalogue is maintained by the owner via
-- service_role, exactly like countries/carriers seeding.


-- ---------------------------------------------------------------------------
-- 3. Seed — 16 published products across 6 carriers.
--
-- Only rows that can be attributed to a public page are seeded. The remaining
-- 44 carriers get nothing rather than a plausible-looking invention: a made-up
-- roaming price in a screen whose call to action is "buy our eSIM instead"
-- would be the single most dishonest number this product could show.
-- `roam_or_esim_quote()` returns verdict `no_roaming_rate` for those and the
-- UI says so out loud.
--
-- FX taken 2026-07-29: PKR 278.00, EGP 50.50, AED 3.6725 (pegged),
-- SAR 3.75 (pegged), USD 1.00.
-- ---------------------------------------------------------------------------
INSERT INTO public.carrier_roaming_rates (
  carrier_id, destination_country_code, product_code, product_name,
  bundle_data_mb, bundle_days,
  local_currency, local_price, fx_rate_to_usd, fx_rate_as_of,
  source_url, source_note
)
SELECT ca.id, s.dest, s.code, s.pname, s.mb, s.days,
       s.cur, s.price, s.fx, DATE '2026-07-29', s.url, s.note
FROM (VALUES
  -- ── Zong (Pakistan) ─────────────────────────────────────────────────────
  ('PK','Zong','AE','zong_ae_2gb_7d','UAE IR Bundle (2 GB / 7 days)',
     2000::bigint, 7, 'PKR', 1999.00, 278.000000,
     'https://www.zong.com.pk/international-roaming',
     'Prepaid UAE IR bundle: 120 min + 120 SMS + 2 GB, 7 days, Rs 1,999 + tax. Tax not included in the figure.'),
  ('PK','Zong','SA','zong_sa_1gb_90d','Saudi Arabia IR Bundle (1 GB / 90 days)',
     1000::bigint, 90, 'PKR', 999.00, 278.000000,
     'https://www.zong.com.pk/international-roaming',
     'Hajj/Umrah prepaid bundle: 35 min + 1 GB, 90 days, PKR 999 + tax.'),
  ('PK','Zong','SA','zong_sa_1gb_15d','Saudi Arabia IR Bundle (1 GB / 15 days)',
     1000::bigint, 15, 'PKR', 1700.00, 278.000000,
     'https://www.zong.com.pk/onlineshop/ir-bundles',
     '30 min + 30 SMS + 1 GB, 15 days, Rs 1,700 + tax.'),
  ('PK','Zong','SA','zong_sa_3gb_30d','Saudi Arabia IR Bundle (3 GB / 30 days)',
     3000::bigint, 30, 'PKR', 4200.00, 278.000000,
     'https://www.zong.com.pk/onlineshop/ir-bundles',
     '60 min + 60 SMS + 3 GB, 30 days, Rs 4,200 + tax.'),
  ('PK','Zong','SA','zong_sa_5gb_45d','Saudi Arabia IR Bundle (5 GB / 45 days)',
     5000::bigint, 45, 'PKR', 6600.00, 278.000000,
     'https://www.zong.com.pk/onlineshop/ir-bundles',
     '90 min + 90 SMS + 5 GB, 45 days, Rs 6,600 + tax.'),

  -- ── Jazz (Pakistan) ─────────────────────────────────────────────────────
  ('PK','Jazz','AE','jazz_ae_1gb_7d','UAE Data Roaming Bundle (1 GB / 7 days)',
     1000::bigint, 7, 'PKR', 999.00, 278.000000,
     'https://jazz.com.pk/explore/uae-roaming-bundles',
     'UAE data roaming bundle, VoIP included.'),
  ('PK','Jazz','AE','jazz_ae_2gb_15d','UAE Data Roaming Bundle (2 GB / 15 days)',
     2000::bigint, 15, 'PKR', 1799.00, 278.000000,
     'https://jazz.com.pk/explore/uae-roaming-bundles', 'UAE data roaming bundle.'),
  ('PK','Jazz','AE','jazz_ae_5gb_30d','UAE Data Roaming Bundle (5 GB / 30 days)',
     5000::bigint, 30, 'PKR', 4499.00, 278.000000,
     'https://jazz.com.pk/explore/uae-roaming-bundles', 'UAE data roaming bundle.'),
  ('PK','Jazz','SA','jazz_sa_5gb_30d','Saudi Roaming Bundle (5 GB / 30 days)',
     5000::bigint, 30, 'PKR', 2000.00, 278.000000,
     'https://jazz.com.pk/explore/saudi-roaming-bundle', 'Saudi Arabia data roaming bundle.'),

  -- ── du (UAE) — worldwide daily/weekly/monthly ───────────────────────────
  ('AE','du','*','du_daily_500mb','Roaming Data Daily Bundle (500 MB)',
     500::bigint, 1, 'AED', 35.00, 3.672500,
     'https://www.du.ae/about/media-centre/newsdetail/du-introduces-new-Roaming-Data-Daily-Bundle',
     'Dh 35/day for 500 MB. AED is pegged to USD at 3.6725.'),
  ('AE','du','*','du_weekly_2500mb','Roaming Data Weekly Bundle (2.5 GB)',
     2500::bigint, 7, 'AED', 200.00, 3.672500,
     'https://www.du.ae/about/media-centre/newsdetail/du-introduces-new-Roaming-Data-Daily-Bundle',
     'Dh 200/week for 2.5 GB.'),
  ('AE','du','*','du_monthly_6gb','Roaming Data Monthly Bundle (6 GB)',
     6000::bigint, 30, 'AED', 500.00, 3.672500,
     'https://www.du.ae/about/media-centre/newsdetail/du-introduces-new-Roaming-Data-Daily-Bundle',
     'Dh 500/month for 6 GB.'),
  ('AE','du','*','du_vip_15gb','Roaming Data VIP Bundle (15 GB)',
     15000::bigint, 30, 'AED', 1000.00, 3.672500,
     'https://www.du.ae/about/media-centre/newsdetail/du-introduces-new-Roaming-Data-Daily-Bundle',
     'Dh 1,000 for 15 GB.'),

  -- ── stc (Saudi Arabia) — worldwide weekly ───────────────────────────────
  ('SA','STC','*','stc_quicknet_weekly_20gb','QuickNet Roaming Weekly (20 GB / 7 days)',
     20000::bigint, 7, 'SAR', 287.50, 3.750000,
     'https://www.stc.com.sa/content/stc/sa/en/personal/mobile/roaming/roaming-prices/roaming-outside-the-kingdom.html',
     'SAR 287.50 for 20 GB over 7 days, worldwide. SAR is pegged to USD at 3.75. Price includes VAT.'),

  -- ── AT&T (United States) — worldwide day pass, no cap of its own ────────
  ('US','AT&T','*','att_international_day_pass','International Day Pass',
     NULL::bigint, 1, 'USD', 12.00, 1.000000,
     'https://www.att.com/support/article/wireless/KM1458476/',
     '$12 per 24 hours on land and air, 210+ destinations; re-uses the domestic data allowance, so no separate cap.'),

  -- ── Orange (Egypt) — worldwide monthly bucket ───────────────────────────
  ('EG','Orange Egypt','*','orange_eg_auto_roaming_1gb','Auto-roaming monthly bucket (1 GB)',
     1000::bigint, 30, 'EGP', 350.00, 50.500000,
     'https://www.orange.eg/en/help/roaming-international/roaming-international',
     'Postpaid auto-roaming adds a 1 GB monthly roaming bucket for EGP 350 once any roaming pack is used up.')
) AS s(home_iso, carrier_name, dest, code, pname, mb, days, cur, price, fx, url, note)
JOIN public.countries co ON co.iso_code = s.home_iso
JOIN public.carriers  ca ON ca.country_id = co.id AND ca.name = s.carrier_name
ON CONFLICT (carrier_id, destination_country_code, product_code) DO NOTHING;

-- Fail loudly rather than shipping a silently-empty catalogue: a renamed
-- carrier would otherwise turn the whole feature into "no rate on file".
DO $$
DECLARE v_rows integer;
BEGIN
  SELECT COUNT(*) INTO v_rows FROM public.carrier_roaming_rates;
  IF v_rows < 16 THEN
    RAISE EXCEPTION 'G5 seed incomplete: expected 16 roaming products, found %. A carrier name in the seed no longer matches public.carriers.', v_rows;
  END IF;
END $$;


-- ---------------------------------------------------------------------------
-- 4. roam_or_esim_quote() — the calculator.
--
-- SECURITY INVOKER (see header note 5). Returns exactly one row.
--
--   p_country_code  where the user is / is going. C8 puts this in
--                   profiles.last_country.
--   p_days          trip length.
--   p_data_mb       how much data they expect to use.
--   p_carrier_id    pin the comparison to one of the user's carriers; NULL
--                   picks their home-country carrier, else the cheapest.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.roam_or_esim_quote(
  p_country_code text,
  p_days         integer DEFAULT 7,
  p_data_mb      bigint  DEFAULT 1000,
  p_carrier_id   uuid    DEFAULT NULL
)
RETURNS TABLE (
  destination_country_code text,
  destination_country_name text,
  trip_days                integer,
  trip_data_mb             bigint,

  roaming_carrier_id       uuid,
  roaming_carrier_name     text,
  roaming_home_country     text,
  roaming_product_name     text,
  roaming_product_kind     text,     -- 'day_pass' | 'bundle' | 'payg'
  roaming_scope            text,     -- 'country' | 'worldwide'
  roaming_units            integer,  -- packs needed, or days for a day pass
  roaming_total_usd        numeric,
  roaming_is_estimate      boolean,
  roaming_source_url       text,
  roaming_priced_as_of     date,

  esim_offer_id            text,
  esim_bundle_name         text,
  esim_data_mb             bigint,
  esim_duration_days       integer,
  esim_quantity            integer,
  esim_unit_price_usd      numeric,
  esim_total_usd           numeric,
  esim_covers_trip         boolean,

  savings_usd              numeric,
  verdict                  text
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
WITH args AS (
  SELECT upper(btrim(COALESCE(p_country_code, '')))       AS dest,
         GREATEST(COALESCE(p_days, 7), 1)                 AS days,
         GREATEST(COALESCE(p_data_mb, 1000), 1)::bigint   AS mb
),
-- Carriers the caller could actually be roaming on: only ones they hold a line
-- with (RLS on sim_lines does the enforcing), and never a carrier based in the
-- destination itself — that is home usage, not roaming.
mine AS (
  SELECT DISTINCT ca.id AS carrier_id, ca.name AS carrier_name, co.iso_code AS home_iso
  FROM public.sim_lines sl
  JOIN public.carriers  ca ON ca.id = sl.carrier_id
  JOIN public.countries co ON co.id = ca.country_id
  CROSS JOIN args a
  WHERE sl.user_id = auth.uid()
    AND (p_carrier_id IS NULL OR ca.id = p_carrier_id)
    AND co.iso_code <> a.dest
),
home AS (
  SELECT upper(COALESCE(pr.home_country_code, '')) AS hc
  FROM public.profiles pr WHERE pr.id = auth.uid()
),
-- One candidate per (roaming product × pricing path).
candidates AS (
  -- Pack path. A day pass is a pack with bundle_days = 1; an uncapped pass
  -- (bundle_data_mb IS NULL) is driven by the day count alone.
  SELECT m.carrier_id, m.carrier_name, m.home_iso,
         r.product_name,
         CASE WHEN r.bundle_days = 1 THEN 'day_pass' ELSE 'bundle' END AS kind,
         CASE WHEN r.destination_country_code = '*' THEN 'worldwide' ELSE 'country' END AS scope,
         GREATEST(
           ceil(a.days::numeric / r.bundle_days),
           CASE WHEN r.bundle_data_mb IS NULL THEN 1
                ELSE ceil(a.mb::numeric / r.bundle_data_mb) END
         )::integer AS units,
         (r.bundle_price_usd * GREATEST(
           ceil(a.days::numeric / r.bundle_days),
           CASE WHEN r.bundle_data_mb IS NULL THEN 1
                ELSE ceil(a.mb::numeric / r.bundle_data_mb) END
         ))::numeric(12,2) AS total_usd,
         r.is_estimate, r.source_url, r.fx_rate_as_of AS priced_as_of
  FROM public.carrier_roaming_rates r
  JOIN mine m ON m.carrier_id = r.carrier_id
  CROSS JOIN args a
  WHERE r.is_active
    AND r.destination_country_code IN (a.dest, '*')
    AND r.bundle_price_usd IS NOT NULL

  UNION ALL

  -- Pay-as-you-go path.
  SELECT m.carrier_id, m.carrier_name, m.home_iso,
         r.product_name, 'payg',
         CASE WHEN r.destination_country_code = '*' THEN 'worldwide' ELSE 'country' END,
         a.mb::integer,
         (r.payg_per_mb_usd * a.mb)::numeric(12,2),
         r.is_estimate, r.source_url, r.fx_rate_as_of
  FROM public.carrier_roaming_rates r
  JOIN mine m ON m.carrier_id = r.carrier_id
  CROSS JOIN args a
  WHERE r.is_active
    AND r.destination_country_code IN (a.dest, '*')
    AND r.payg_per_mb_usd IS NOT NULL
),
-- The user's home-country carrier is the headline if it has any rate at all —
-- "what YOUR carrier charges" is the whole point. Within a carrier, and when no
-- home carrier qualifies, cheapest wins.
best_roaming AS (
  SELECT c.*
  FROM candidates c CROSS JOIN home h
  ORDER BY (c.home_iso = h.hc AND h.hc <> '') DESC, c.total_usd ASC, c.product_name ASC
  LIMIT 1
),
-- Retail eSIM side. `esim_offers` applies ESIM_MARKUP_PERCENT; wholesale is
-- never read here. Quantity is capped at 3 because request_esim_purchase caps
-- it at 3 — quoting a fourth bundle would quote something unbuyable.
esim_priced AS (
  SELECT o.id, o.bundle_name, o.data_amount_mb, o.duration_days, o.retail_price_usd,
         LEAST(3, GREATEST(
           ceil(a.days::numeric / NULLIF(o.duration_days, 0)),
           CASE WHEN COALESCE(o.data_amount_mb, 0) > 0
                THEN ceil(a.mb::numeric / o.data_amount_mb) ELSE 1 END,
           1
         ))::integer AS qty,
         a.days, a.mb
  FROM public.esim_offers o CROSS JOIN args a
  WHERE o.is_active AND a.dest = ANY (o.countries)
),
best_esim AS (
  SELECT e.id, e.bundle_name, e.data_amount_mb, e.duration_days, e.retail_price_usd,
         e.qty,
         (e.retail_price_usd * e.qty)::numeric(12,2) AS total_usd,
         (COALESCE(e.duration_days, 0) * e.qty >= e.days
          AND (COALESCE(e.data_amount_mb, 0) = 0
               OR e.data_amount_mb * e.qty >= e.mb))                AS covers
  FROM esim_priced e
  ORDER BY covers DESC, total_usd ASC, e.data_amount_mb DESC
  LIMIT 1
)
SELECT
  a.dest,
  COALESCE(co.name, a.dest),
  a.days,
  a.mb,

  r.carrier_id, r.carrier_name, r.home_iso, r.product_name, r.kind, r.scope,
  r.units, r.total_usd, r.is_estimate, r.source_url, r.priced_as_of,

  e.id, e.bundle_name, e.data_amount_mb, e.duration_days, e.qty,
  e.retail_price_usd, e.total_usd, e.covers,

  CASE WHEN r.total_usd IS NOT NULL AND e.total_usd IS NOT NULL AND e.covers
       THEN (r.total_usd - e.total_usd)::numeric(12,2) END,

  CASE
    WHEN r.total_usd IS NULL AND e.total_usd IS NULL THEN 'no_data'
    WHEN r.total_usd IS NULL                         THEN 'no_roaming_rate'
    WHEN e.total_usd IS NULL                         THEN 'no_esim'
    WHEN NOT e.covers                                THEN 'esim_partial'
    WHEN e.total_usd <  r.total_usd                  THEN 'esim_cheaper'
    WHEN e.total_usd >  r.total_usd                  THEN 'roaming_cheaper'
    ELSE 'tie'
  END
FROM args a
LEFT JOIN public.countries co ON co.iso_code = a.dest
LEFT JOIN best_roaming r ON true
LEFT JOIN best_esim    e ON true;
$$;

COMMENT ON FUNCTION public.roam_or_esim_quote(text, integer, bigint, uuid) IS
  'G5: compares what the caller''s own carrier charges to roam in a destination against the cheapest retail eSIM that covers it. SECURITY INVOKER — the caller''s RLS on sim_lines is what limits which carriers they can be quoted on, and retail pricing comes from the esim_offers view so wholesale is never read. Returns exactly one row; read `verdict`.';

REVOKE ALL     ON FUNCTION public.roam_or_esim_quote(text, integer, bigint, uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.roam_or_esim_quote(text, integer, bigint, uuid) TO authenticated, service_role;


-- ---------------------------------------------------------------------------
-- 5. my_roaming_carriers() — which of the caller's carriers can be quoted for a
--    destination, for the picker on the calculator screen. Same INVOKER story.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.my_roaming_carriers(p_country_code text)
RETURNS TABLE (
  carrier_id    uuid,
  carrier_name  text,
  home_iso      text,
  home_country  text,
  is_home       boolean,
  has_rate      boolean,
  product_count integer
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
WITH args AS (SELECT upper(btrim(COALESCE(p_country_code, ''))) AS dest),
mine AS (
  SELECT DISTINCT ca.id, ca.name, co.iso_code, co.name AS country_name
  FROM public.sim_lines sl
  JOIN public.carriers  ca ON ca.id = sl.carrier_id
  JOIN public.countries co ON co.id = ca.country_id
  WHERE sl.user_id = auth.uid()
)
SELECT m.id, m.name, m.iso_code, m.country_name,
       (m.iso_code = upper(COALESCE((SELECT home_country_code FROM public.profiles WHERE id = auth.uid()), ''))),
       COUNT(r.id) > 0,
       COUNT(r.id)::integer
FROM mine m
CROSS JOIN args a
LEFT JOIN public.carrier_roaming_rates r
       ON r.carrier_id = m.id
      AND r.is_active
      AND r.destination_country_code IN (a.dest, '*')
      AND m.iso_code <> a.dest
GROUP BY m.id, m.name, m.iso_code, m.country_name, a.dest
ORDER BY 5 DESC, 6 DESC, m.name;
$$;

COMMENT ON FUNCTION public.my_roaming_carriers(text) IS
  'G5: the caller''s own carriers, flagged with whether a roaming tariff exists for a destination. Drives the carrier picker on the Roam-or-eSIM screen.';

REVOKE ALL     ON FUNCTION public.my_roaming_carriers(text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.my_roaming_carriers(text) TO authenticated, service_role;
