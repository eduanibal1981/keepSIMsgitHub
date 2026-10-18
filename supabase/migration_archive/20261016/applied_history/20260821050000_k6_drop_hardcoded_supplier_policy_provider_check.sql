-- =============================================================================
-- K6 · A hardcoded CHECK made "add a provider" impossible
-- =============================================================================
-- I5 gave `supplier_policy` a CHECK listing the four suppliers that existed in
-- August 2026: ('zendit','dtone','ding','reloadly'). K1 added a FOREIGN KEY to
-- `service_providers(code)`, which enforces the same integrity without freezing
-- the list — but left the CHECK standing beside it.
--
-- FOUND BY PROBING, NOT BY READING. The first live call to
-- `admin_upsert_service_provider` raised 23514 the moment it tried to create
-- the new supplier's ranking-policy row:
--
--   new row for relation "supplier_policy" violates check constraint
--   "supplier_policy_provider_check"
--
-- So the headline capability K4 exists to deliver — a new supplier is a row an
-- operator adds, not a migration — did not work at all. Reading the K4 code
-- would never have shown this; the constraint is three migrations away.
--
-- The FK is the better guard: it cannot go stale as suppliers are added, and
-- ON UPDATE CASCADE carries a rename.
-- =============================================================================

ALTER TABLE public.supplier_policy
  DROP CONSTRAINT IF EXISTS supplier_policy_provider_check;

-- carrier_provider_map's equivalent CHECK was already replaced by an FK in K1.
-- Assert it here, so a future migration that re-introduces a hardcoded provider
-- list fails this file rather than failing an operator months later.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_constraint
              WHERE conname = 'carrier_provider_map_provider_check') THEN
    RAISE EXCEPTION 'carrier_provider_map still has a hardcoded provider CHECK; it must be an FK to service_providers';
  END IF;
END $$;

COMMENT ON CONSTRAINT supplier_policy_provider_fkey ON public.supplier_policy IS
  'Replaces I5''s hardcoded provider CHECK. A new supplier must exist in '
  'service_providers first, but the list is no longer frozen into a constraint '
  'definition — which is what made adding one raise 23514.';
