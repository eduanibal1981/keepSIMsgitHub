-- ============================================================================
-- I8c — `admin_upsert_carrier_rule(uuid,jsonb)` shipped with the default ACL.
--
-- Found by re-running supabase/tests/f0_grant_matrix_tests.sql after I8, which
-- is the entire reason that file exists. i7 created this function and never
-- revoked anything, so Supabase's blanket grant left it:
--
--   {=X/postgres, postgres=X/postgres, anon=X/postgres, authenticated=X/postgres, ...}
--
-- — PUBLIC EXECUTE *and* an explicit anon grant, on a SECURITY DEFINER function
-- that rewrites the rules every refill schedule and every plan price is
-- computed from. Occurrence 3 of the F-3/F-4 shape.
--
-- LATENT, NOT LIVE, and that distinction was established by probing rather than
-- by reading: called as `anon` it answered **KS460 "Admin access required"**,
-- because the body opens with `PERFORM public.assert_admin()` and assert_admin
-- raises on a *missing* identity (the H-phase correction to the
-- `IF auth.uid() IS NOT NULL AND NOT allowed(...)` shape that fell open). So no
-- carrier rule was ever writable by an anonymous caller.
--
-- It is still wrong. F0's rule is that the EXECUTE ACL *is* the perimeter and
-- the internal check is the second line, not the first — every one of the four
-- F-class holes had a plausible-looking guard too. After this migration the
-- same probe answers `42501`, which is the grant refusing rather than the body.
-- ============================================================================

REVOKE ALL ON FUNCTION public.admin_upsert_carrier_rule(uuid,jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_upsert_carrier_rule(uuid,jsonb)
  TO authenticated, service_role;

COMMENT ON FUNCTION public.admin_upsert_carrier_rule(uuid,jsonb) IS
  'i7 carrier-rule admin write, patch-shaped and gated on assert_admin(). I8c revoked the PUBLIC/anon EXECUTE it shipped with; it is on the f0_grant_matrix_tests.sql authenticated allow-list.';
