-- =============================================================================
-- K1 · Split `carriers` into a telecom identity and a service-provider registry
-- =============================================================================
-- WHY THIS EXISTS
--
--   `carriers` has been carrying two unrelated things in one row since the
--   `merge_telecom_routes_into_carriers` migration:
--
--     (a) WHO the telecom is        — country_id, name, logo_url, is_supported
--     (b) HOW each supplier NAMES that telecom in its own catalogue —
--         zen_country/zen_carrier, dt_country/dt_carrier,
--         ding_country/ding_carrier, reloadly_operator_id, api_provider
--
--   (b) is a per-supplier fact and there are four suppliers, so it was modelled
--   as four hardcoded column pairs and one single-valued `api_provider`. Adding
--   a fifth supplier meant a schema change; a carrier reachable through two
--   suppliers was unrepresentable. I1 already recognised half of this and added
--   `carrier_provider_map`, but it landed BESIDE the columns rather than
--   replacing them, so the database has held two answers to the same question
--   for eight phases.
--
-- THREE THINGS THIS ESTABLISHED BY MEASURING, NOT BY ASSUMING
--
--   1. `zen_country` / `dt_country` / `ding_country` DO NOT HOLD A JOIN KEY.
--      They hold the supplier's human country label — 'India', 'Saudi Arabia' —
--      while every live lookup joins on ISO-2 from `countries.iso_code`. All 50
--      zendit rows "differ" from `carrier_provider_map.provider_country_code`
--      for exactly this reason, and the three VM workers `select dt_country`
--      and then never read the variable. The information is still worth having
--      (it is what a supplier's own dashboard shows an operator), so it is
--      MIGRATED to `provider_country_label` rather than deleted — but it is
--      never again mistaken for something you can join on.
--
--   2. `carrier_provider_map` is CLEAN and can be trusted as the source of
--      truth: 0 carrier-code drift against the legacy columns, 0 offers in
--      `provider_offers_cache` that fail to resolve to a mapping row, and every
--      legacy code has a corresponding map row (50 zendit + 22 dtone = 72).
--      That is what makes dropping the columns in K3 safe.
--
--   3. `carriers.api_provider` is a SINGLE-VALUED routing default that I5
--      already identified as the reason only one supplier per carrier could
--      ever be cached. It becomes `carrier_provider_map.is_primary`, which is
--      the same fact expressed where it belongs — one row per supplier, with a
--      partial unique index enforcing "at most one primary per carrier".
--
-- WHAT `service_providers` IS, AND WHAT IT DELIBERATELY IS NOT
--
--   IS: the one place a supplier is born, named and described. Its code is the
--   FK target for `carrier_provider_map`, `supplier_policy`, `esim_suppliers`
--   and (in K2) `provider_offers`. It answers "what do we call this supplier,
--   what can it sell, and how does it spell a country".
--
--   IS NOT: a replacement for `supplier_policy` or `esim_suppliers`. Those two
--   hold genuinely different concerns — I5's margin/risk economics, and eSIM
--   catalogue sync state read by a DEPLOYED Edge Function and a VM worker.
--   Folding them in would rewrite `sync-esim-catalogue` and
--   `worker_esim_catalog.js` for cosmetics. They are FK'd to this table
--   instead, so a supplier cannot exist in one of them and not the others,
--   which is the actual defect (dtone/zendit are `is_active=false` in
--   `esim_suppliers` while `is_globally_enabled=true` in `supplier_policy`).
--
-- COUNTRY-LABEL STYLE (the "how does the app know the label" half of the ask)
--
--   Each supplier spells a country differently. Zendit's catalogue is keyed by
--   ISO-2 but its console shows 'India'; DTOne is ISO-2; Reloadly keys operators
--   by numeric id. `country_label_style` records which convention a supplier
--   uses so a resolver never has to guess, and `carrier_provider_map` carries
--   BOTH the join key (`provider_country_code`) and the display label
--   (`provider_country_label`) so neither one has to be derived from the other.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. service_providers
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.service_providers (
  code                 text PRIMARY KEY,
  name                 text NOT NULL,
  -- What this supplier can actually sell us. Both false is legal (a supplier
  -- being onboarded); it simply cannot be selected anywhere.
  supports_topup       boolean NOT NULL DEFAULT false,
  supports_esim        boolean NOT NULL DEFAULT false,
  -- How this supplier spells a country in its own catalogue. Read by resolvers
  -- and by the admin UI so an operator typing a mapping is told what shape the
  -- value must be, instead of finding out from a 0-row lookup.
  country_label_style  text NOT NULL DEFAULT 'iso2'
                       CHECK (country_label_style IN ('iso2', 'iso3', 'name', 'numeric')),
  -- How it identifies the telecom: a brand string ('VodafoneIdea') or an opaque
  -- operator id ('341'). Reloadly is the only `numeric_id` supplier today, and
  -- that difference is exactly why its codes never got filled in by hand.
  carrier_label_style  text NOT NULL DEFAULT 'brand_code'
                       CHECK (carrier_label_style IN ('brand_code', 'numeric_id')),
  -- Master switch. Distinct from supplier_policy.is_globally_enabled, which is
  -- a RANKING decision (may this supplier win a price comparison). This one is
  -- an IDENTITY decision (do we deal with this company at all) and gates the
  -- catalogue refresh in K2.
  is_active            boolean NOT NULL DEFAULT false,
  priority             integer NOT NULL DEFAULT 100,
  website_url          text,
  api_base_url         text,
  docs_url             text,
  -- Vault key name, never a credential. Same stance as esim_suppliers.
  credential_secret    text,
  notes                text,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.service_providers IS
  'K1: the canonical supplier registry — zendit, dtone, ding, reloadly, esim_go. '
  'One place a supplier is named and described. carrier_provider_map, '
  'supplier_policy, esim_suppliers and provider_offers all FK to code. '
  'supplier_policy holds the margin economics and esim_suppliers the eSIM sync '
  'state; neither duplicates identity any more.';

COMMENT ON COLUMN public.service_providers.country_label_style IS
  'How this supplier spells a country. Recorded because carriers.zen_country '
  'held ''India'' while every lookup joined on ''IN'', and nothing in the schema '
  'said which one was the key.';

COMMENT ON COLUMN public.service_providers.is_active IS
  'Identity switch: do we deal with this supplier at all. NOT the same as '
  'supplier_policy.is_globally_enabled, which decides whether it may win a '
  'price comparison.';

-- Deny-all. Supplier identity, endpoints and Vault key names are not client
-- business; the app never needs to know who fulfilled a refill.
ALTER TABLE public.service_providers ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.service_providers FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.service_providers TO service_role;

-- -----------------------------------------------------------------------------
-- 2. Seed, reconciled from the two registries that already disagreed
-- -----------------------------------------------------------------------------
-- `is_active` is the OR of the two existing switches, because a supplier that
-- is ranking-enabled for top-ups (zendit, dtone) but is_active=false in
-- esim_suppliers is a live supplier we simply do not buy eSIMs from. Reading it
-- as inactive would take the top-up rail down.
INSERT INTO public.service_providers
  (code, name, supports_topup, supports_esim, country_label_style,
   carrier_label_style, is_active, priority, api_base_url, docs_url,
   credential_secret, website_url, notes)
VALUES
  ('zendit',   'Zendit',   true,  false, 'iso2',    'brand_code', true,  10,
   NULL, NULL, NULL, NULL,
   'Primary top-up supplier: 50 of 67 carriers mapped, 780 of 783 cached offers.'),
  ('dtone',    'DTOne',    true,  false, 'iso2',    'brand_code', true,  20,
   NULL, NULL, NULL, NULL,
   'PREPROD endpoint — treat prices as indicative. Sole supplier for Zain KSA, '
   'which is the only carrier with a live SIM line.'),
  ('ding',     'Ding',     true,  false, 'iso2',    'brand_code', false, 30,
   NULL, NULL, NULL, NULL,
   'Credentials held by the owner. No carrier code has ever been populated and '
   'no catalogue has ever been fetched, so it has nothing to sell.'),
  ('reloadly', 'Reloadly', true,  false, 'iso2',    'numeric_id', false, 40,
   NULL, NULL, NULL, NULL,
   'OAuth, not a static key. Identifies operators by numeric id, which is why '
   'its codes were never filled in alongside the brand-code suppliers.'),
  ('esim_go',  'eSIM Go',  false, true,  'iso2',    'brand_code', true,  50,
   NULL, NULL, 'esim_go_api_key', NULL,
   'eSIM catalogue supplier. 5,412 bundles across 220 countries.')
ON CONFLICT (code) DO NOTHING;

-- Carry across whatever the two existing registries already knew, without
-- letting either one overwrite the reconciled `is_active` decided above.
UPDATE public.service_providers sp
   SET website_url       = COALESCE(sp.website_url, es.website_url),
       api_base_url      = COALESCE(sp.api_base_url, es.api_base_url),
       docs_url          = COALESCE(sp.docs_url, es.docs_url),
       credential_secret = COALESCE(sp.credential_secret, es.credential_secret),
       supports_esim     = sp.supports_esim OR es.is_active,
       updated_at        = now()
  FROM public.esim_suppliers es
 WHERE es.code = sp.code;

-- -----------------------------------------------------------------------------
-- 3. Tie the two satellite registries to it
-- -----------------------------------------------------------------------------
-- Any provider code present in a satellite but absent from the registry would
-- fail these FKs. Both were seeded from the same four/three codes above, so
-- this is a no-op today and a guarantee from here on.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'supplier_policy_provider_fkey'
  ) THEN
    ALTER TABLE public.supplier_policy
      ADD CONSTRAINT supplier_policy_provider_fkey
      FOREIGN KEY (provider) REFERENCES public.service_providers(code)
      ON UPDATE CASCADE ON DELETE RESTRICT;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'esim_suppliers_code_fkey'
  ) THEN
    ALTER TABLE public.esim_suppliers
      ADD CONSTRAINT esim_suppliers_code_fkey
      FOREIGN KEY (code) REFERENCES public.service_providers(code)
      ON UPDATE CASCADE ON DELETE RESTRICT;
  END IF;
END $$;

COMMENT ON TABLE public.supplier_policy IS
  'I5 margin economics for a top-up supplier, keyed to service_providers.code. '
  'Identity lives in service_providers; this table only answers "how much do we '
  'penalise this supplier when comparing prices".';

COMMENT ON TABLE public.esim_suppliers IS
  'eSIM catalogue sync state, keyed to service_providers.code. Read by the '
  'deployed sync-esim-catalogue Edge Function and worker_esim_catalog.js — do '
  'not fold into service_providers without redeploying both.';

-- -----------------------------------------------------------------------------
-- 4. carrier_provider_map becomes the whole answer
-- -----------------------------------------------------------------------------
ALTER TABLE public.carrier_provider_map
  ADD COLUMN IF NOT EXISTS provider_country_label text,
  ADD COLUMN IF NOT EXISTS provider_carrier_label text,
  ADD COLUMN IF NOT EXISTS is_primary             boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.carrier_provider_map.provider_country_code IS
  'The JOIN KEY into this supplier''s catalogue (provider_offers_cache.country_code). '
  'ISO-2 for every supplier we deal with today.';

COMMENT ON COLUMN public.carrier_provider_map.provider_country_label IS
  'K1: the supplier''s own human country label, migrated from carriers.zen_country / '
  'dt_country / ding_country. DISPLAY ONLY — never join on this. The legacy '
  'columns held ''India'' where the catalogue is keyed ''IN'', and that mismatch '
  'is why they looked like drift for eight phases.';

COMMENT ON COLUMN public.carrier_provider_map.provider_carrier_label IS
  'The supplier''s human name for this telecom. Defaults to provider_carrier_code, '
  'which IS the label for every brand_code supplier; it matters for Reloadly, '
  'where the code is an opaque numeric operator id.';

COMMENT ON COLUMN public.carrier_provider_map.is_primary IS
  'K1: replaces the single-valued carriers.api_provider. The supplier a new '
  'execution is routed to when nothing else picks one. At most one per carrier '
  '(uq_carrier_provider_map_primary).';

-- Backfill the display labels from the columns K3 drops. This runs BEFORE the
-- drop on purpose — it is the only chance to keep the information.
UPDATE public.carrier_provider_map m
   SET provider_country_label = COALESCE(m.provider_country_label, c.zen_country),
       provider_carrier_label = COALESCE(m.provider_carrier_label, c.zen_carrier)
  FROM public.carriers c
 WHERE c.id = m.carrier_id AND m.provider = 'zendit';

UPDATE public.carrier_provider_map m
   SET provider_country_label = COALESCE(m.provider_country_label, c.dt_country),
       provider_carrier_label = COALESCE(m.provider_carrier_label, c.dt_carrier)
  FROM public.carriers c
 WHERE c.id = m.carrier_id AND m.provider = 'dtone';

UPDATE public.carrier_provider_map m
   SET provider_country_label = COALESCE(m.provider_country_label, c.ding_country),
       provider_carrier_label = COALESCE(m.provider_carrier_label, c.ding_carrier)
  FROM public.carriers c
 WHERE c.id = m.carrier_id AND m.provider = 'ding';

-- Anything still unlabelled (dtone rows were backfilled by I1 from iso_code, and
-- reloadly has no rows at all) falls back to the country's own name and to the
-- provider code. Never leave a label NULL: the admin UI would render an empty
-- cell that reads as "not mapped" over a mapping that works.
UPDATE public.carrier_provider_map m
   SET provider_country_label = co.name
  FROM public.carriers c
  JOIN public.countries co ON co.id = c.country_id
 WHERE c.id = m.carrier_id AND m.provider_country_label IS NULL;

UPDATE public.carrier_provider_map
   SET provider_carrier_label = provider_carrier_code
 WHERE provider_carrier_label IS NULL;

ALTER TABLE public.carrier_provider_map
  ALTER COLUMN provider_country_label SET NOT NULL,
  ALTER COLUMN provider_carrier_label SET NOT NULL;

-- Adopt today's routing default verbatim. `api_provider` is non-NULL for all 67
-- carriers, so every carrier that has a matching enabled mapping gets exactly
-- one primary and no route changes.
UPDATE public.carrier_provider_map m
   SET is_primary = true
  FROM public.carriers c
 WHERE c.id = m.carrier_id
   AND lower(COALESCE(c.api_provider::text, 'zendit')) = m.provider
   AND m.is_enabled;

-- A carrier whose api_provider named a supplier it has no enabled mapping for
-- would end up with no primary and route nowhere. Give those the cheapest
-- available enabled mapping by priority, which is what supplier selection would
-- have picked anyway.
WITH fallback AS (
  SELECT DISTINCT ON (m.carrier_id) m.id
    FROM public.carrier_provider_map m
   WHERE m.is_enabled
     AND NOT EXISTS (
       SELECT 1 FROM public.carrier_provider_map x
        WHERE x.carrier_id = m.carrier_id AND x.is_primary
     )
   ORDER BY m.carrier_id, m.priority, m.provider
)
UPDATE public.carrier_provider_map m
   SET is_primary = true
  FROM fallback f
 WHERE m.id = f.id;

-- At most one primary per carrier. A partial unique index rather than a trigger:
-- it cannot fall open, and it is enforced against every writer including
-- service_role and a hand-typed UPDATE in the SQL editor.
CREATE UNIQUE INDEX IF NOT EXISTS uq_carrier_provider_map_primary
  ON public.carrier_provider_map (carrier_id) WHERE is_primary;

-- A primary that is not enabled is a route to a supplier we have switched off.
ALTER TABLE public.carrier_provider_map
  DROP CONSTRAINT IF EXISTS carrier_provider_map_primary_is_enabled;
ALTER TABLE public.carrier_provider_map
  ADD CONSTRAINT carrier_provider_map_primary_is_enabled
  CHECK (NOT is_primary OR is_enabled);

-- Replace the hardcoded CHECK with a real FK, and require the supplier to
-- actually sell top-ups. Putting esim_go in this table would produce a carrier
-- routed to a supplier that has no top-up catalogue.
ALTER TABLE public.carrier_provider_map
  DROP CONSTRAINT IF EXISTS carrier_provider_map_provider_check;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'carrier_provider_map_provider_fkey'
  ) THEN
    ALTER TABLE public.carrier_provider_map
      ADD CONSTRAINT carrier_provider_map_provider_fkey
      FOREIGN KEY (provider) REFERENCES public.service_providers(code)
      ON UPDATE CASCADE ON DELETE RESTRICT;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.trg_fn_carrier_map_provider_sells_topup()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.service_providers sp
     WHERE sp.code = NEW.provider AND sp.supports_topup
  ) THEN
    RAISE EXCEPTION 'Provider % does not sell mobile top-ups', NEW.provider
      USING ERRCODE = 'KS466';
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.trg_fn_carrier_map_provider_sells_topup() FROM PUBLIC, anon, authenticated;

-- I1's trigger kept `carriers.api_provider` in step with this table. K3 drops
-- that column, so the trigger is replaced rather than amended — its remaining
-- job is the updated_at stamp plus the new capability check.
DROP TRIGGER IF EXISTS trg_sync_carrier_default_provider ON public.carrier_provider_map;
DROP FUNCTION IF EXISTS public.trg_fn_sync_carrier_default_provider();

DROP TRIGGER IF EXISTS trg_carrier_map_provider_sells_topup ON public.carrier_provider_map;
CREATE TRIGGER trg_carrier_map_provider_sells_topup
  BEFORE INSERT OR UPDATE ON public.carrier_provider_map
  FOR EACH ROW EXECUTE FUNCTION public.trg_fn_carrier_map_provider_sells_topup();

-- -----------------------------------------------------------------------------
-- 5. carrier_supplier_routing — the resolver every reader now uses
-- -----------------------------------------------------------------------------
-- One place that answers, for a carrier: which suppliers can fulfil it, what
-- each one calls the country and the telecom, and which is the default. Every
-- function K3 rewrites reads through this instead of a CASE over four column
-- pairs, so adding a fifth supplier stops being a code change.
CREATE OR REPLACE VIEW public.carrier_supplier_routing AS
SELECT
  m.carrier_id,
  ca.name                    AS carrier_name,
  ca.country_id,
  co.iso_code                AS country_code,
  co.name                    AS country_name,
  co.is_supported            AS country_is_supported,
  m.provider                 AS provider_code,
  sp.name                    AS provider_name,
  m.provider_country_code,
  m.provider_country_label,
  m.provider_carrier_code,
  m.provider_carrier_label,
  m.is_enabled,
  m.is_primary,
  m.priority,
  m.last_verified_at,
  -- Enabled at every layer: the supplier exists and we deal with it, it may win
  -- a comparison, and this particular mapping is on. All three have to be true
  -- before a refill can actually be routed here.
  (m.is_enabled AND sp.is_active AND sp.supports_topup
     AND COALESCE(pol.is_globally_enabled, false)) AS is_routable
FROM public.carrier_provider_map m
JOIN public.carriers          ca  ON ca.id = m.carrier_id
JOIN public.countries         co  ON co.id = ca.country_id
JOIN public.service_providers sp  ON sp.code = m.provider
LEFT JOIN public.supplier_policy pol ON pol.provider = m.provider;

COMMENT ON VIEW public.carrier_supplier_routing IS
  'K1: the single resolver for "which supplier fulfils this carrier, and what '
  'does that supplier call the country and the telecom". Replaces the CASE over '
  'zen_/dt_/ding_ column pairs that every reader had its own copy of.';

ALTER VIEW public.carrier_supplier_routing SET (security_invoker = on);
REVOKE ALL ON public.carrier_supplier_routing FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.carrier_supplier_routing TO service_role;

CREATE INDEX IF NOT EXISTS idx_carrier_provider_map_provider_lookup
  ON public.carrier_provider_map (provider, provider_country_code, provider_carrier_code);
