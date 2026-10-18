-- ============================================================================
-- G5b — 🔴 LIVE HOLE: anon can DELETE the entire purchasable catalog through
--       two views. Found while building G5, which reads one of them.
--
-- ── What was wrong ─────────────────────────────────────────────────────────
--
-- `esim_offers` and `zendit_offers_cache` are read-only presentation views over
-- `esim_offers_cache` and `provider_offers_cache`. Both were created WITHOUT
-- `security_invoker`, which is correct and deliberate — it is what keeps
-- `wholesale_price_usd` and the markup out of reach of clients (doc/RLS_MATRIX.md,
-- and the G2 header note). But a view that is not `security_invoker` executes as
-- its OWNER, and the owner is `postgres`. Row-level security on the underlying
-- cache tables therefore does not apply to anything done through the view.
--
-- Both views also still carried the database's default `GRANT ALL` to `anon`
-- and `authenticated` — nobody ever revoked it, because F6 swept base tables
-- and these are views. A simple view over one table is auto-updatable, so
-- `DELETE` on it is a real, PostgREST-reachable verb.
--
-- Put together: `DELETE /rest/v1/esim_offers` with nothing but the publishable
-- key that ships inside the APK deletes every row of the catalog, RLS never
-- consulted.
--
-- ── Proven live, in rolled-back transactions, 2026-07-29 ───────────────────
--
--   SET LOCAL ROLE anon;
--   DELETE FROM public.esim_offers;         -- ALLOWED, 50 rows
--   DELETE FROM public.zendit_offers_cache; -- ALLOWED, 780 rows
--   -- underlying tables, read back as owner: 0 eSIM bundles, 3 top-up offers left
--
-- That is the whole eSIM catalogue and 99.6% of the top-up catalogue, destroyed
-- by an unauthenticated caller. The eSIM half is not even recoverable on a
-- timer the way the 10-minute top-up refresh is: `esim_offers_cache` is
-- rewritten every 6 hours, so the store is empty until the next sweep.
--
-- ── The fix ────────────────────────────────────────────────────────────────
--
-- Revoke everything except SELECT on all four public views. Nothing in the
-- codebase writes through any of them — `esim_go_repository_impl.dart:19` is a
-- SELECT, the workers write the base tables as `service_role` — so this cannot
-- break a caller. `security_invoker` is deliberately left alone on
-- `esim_offers` / `zendit_offers_cache`: flipping it would fix the RLS bypass
-- but would also break the reads the app depends on, because `authenticated`
-- has no SELECT policy on the cache tables. Removing the write verb is the
-- change that closes the hole without touching the markup isolation.
--
-- `sim_line_details_view` and `wallet_reconciliation` are `security_invoker`,
-- so they were never exploitable; their write grants are revoked anyway. A
-- read-only view with a DELETE grant is a hole waiting for someone to flip
-- `security_invoker` for an unrelated reason.
-- ============================================================================

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON public.esim_offers           FROM PUBLIC, anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON public.zendit_offers_cache   FROM PUBLIC, anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON public.sim_line_details_view FROM PUBLIC, anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON public.wallet_reconciliation FROM PUBLIC, anon, authenticated;

-- Re-assert the reads the app actually uses, so a future `REVOKE ALL` sweep
-- cannot silently take the catalogue offline.
GRANT SELECT ON public.esim_offers           TO anon, authenticated;
GRANT SELECT ON public.zendit_offers_cache   TO anon, authenticated;
GRANT SELECT ON public.sim_line_details_view TO authenticated;

-- Fail the migration rather than report a fix that did not take.
DO $$
DECLARE v_bad text;
BEGIN
  SELECT string_agg(c.relname || '/' || r.rolname, ', ')
    INTO v_bad
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  CROSS JOIN (VALUES ('anon'), ('authenticated')) AS r(rolname)
  WHERE n.nspname = 'public' AND c.relkind = 'v'
    AND (has_table_privilege(r.rolname, c.oid, 'DELETE')
      OR has_table_privilege(r.rolname, c.oid, 'INSERT')
      OR has_table_privilege(r.rolname, c.oid, 'UPDATE')
      OR has_table_privilege(r.rolname, c.oid, 'TRUNCATE'));

  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'G5b did not take: write privileges remain on %', v_bad;
  END IF;
END $$;
