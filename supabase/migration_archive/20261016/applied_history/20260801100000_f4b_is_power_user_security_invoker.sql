-- ============================================================================
-- F4b: is_power_user must stay anon-EXECUTEable — so take it out of the
--      SECURITY DEFINER perimeter instead of revoking it.
--
-- Migration 20260801070000 revoked anon's EXECUTE on is_power_user along with
-- the other five self-scoped RPCs. That was wrong, and doc/RLS_MATRIX.md already
-- said so ("Required: used in RLS policies evaluated as anon") — a claim this
-- session verified rather than assuming:
--
--   SET LOCAL ROLE anon; SELECT count(*) FROM public.sim_lines;
--   -> ERROR 42501 permission denied for function is_power_user
--
-- The cause is the sim_lines policy "Allow power users full access on
-- sim_lines", which is defined FOR ALL TO public — so it is evaluated for anon
-- as well, and its USING clause calls is_power_user(auth.uid()). RLS policy
-- expressions run as the querying role, so without EXECUTE the whole SELECT
-- errors out instead of simply returning no rows. An expired token mid-request
-- would surface as a hard 42501 rather than an empty list.
--
-- Note this is a pre-existing coupling, not something F-6 introduced:
-- profiles and scheduled_topups were unaffected (verified in the same probe)
-- because their is_power_user-bearing policies are scoped TO authenticated.
--
-- ---------------------------------------------------------------------------
-- The fix
-- ---------------------------------------------------------------------------
-- is_power_user does not need definer rights at all. Its entire body is
--
--     RETURN COALESCE((auth.jwt() -> 'app_metadata' ->> 'is_power_user')::boolean, false);
--
-- It reads the CALLER'S OWN JWT out of a GUC and touches no table, so running it
-- as the invoker is identical in behaviour — including when it is called from
-- inside another SECURITY DEFINER function, where it reads the same
-- transaction-scoped claims either way. It also ignores its `user_id` argument
-- entirely, so it is not a lookup oracle for other users.
--
-- Switching it to SECURITY INVOKER means:
--   * the RLS policy works for anon again (behaviour restored), and
--   * it leaves the SECURITY DEFINER attack surface, so the grant-matrix test
--     in supabase/tests/f0_grant_matrix_tests.sql still reports ZERO
--     anon-callable SECURITY DEFINER functions — the count is honest, not a
--     carve-out.
--
-- The `user_id` parameter is kept so the existing policy expressions and the
-- app's call sites do not have to change.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.is_power_user(user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY INVOKER
STABLE
SET search_path TO ''
AS $function$
BEGIN
  -- Reads the caller's own JWT claim. The argument is deliberately unused: this
  -- answers "am I a power user", never "is someone else one".
  RETURN COALESCE((auth.jwt() -> 'app_metadata' ->> 'is_power_user')::boolean, false);
END;
$function$;

-- anon needs EXECUTE for the sim_lines "Allow power users full access" policy,
-- which is FOR ALL TO public and therefore evaluated for anon too.
GRANT EXECUTE ON FUNCTION public.is_power_user(uuid) TO anon, authenticated, service_role;

COMMENT ON FUNCTION public.is_power_user(uuid) IS
  'Returns whether the CALLING user holds the is_power_user app_metadata claim. SECURITY INVOKER '
  'on purpose: it reads only the caller''s JWT, and anon must be able to execute it because the '
  'sim_lines "Allow power users full access" policy is FOR ALL TO public and calls it — revoking '
  'anon breaks anon SELECT on sim_lines with 42501 (verified 2026-07-29, F-4b).';
