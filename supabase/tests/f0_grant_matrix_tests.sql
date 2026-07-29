-- ============================================================================
-- F0.6 — the grant matrix. This is the artifact that stops the F-1..F-4 class
-- of bug recurring.
--
-- Every SECURITY DEFINER function in `public` runs with the table owner's
-- rights, so its EXECUTE ACL *is* the security perimeter. Supabase blanket-grants
-- EXECUTE on new public functions and `GRANT ... TO service_role` does NOT
-- remove anon/authenticated — only a REVOKE does. Four separate live holes
-- (F-1 minting, F-2 draining, F-3 free compute, F-4 rate-limit DoS + an
-- unauthenticated profile write) all had exactly one root cause: nobody
-- asserted the ACL.
--
-- The rule this file enforces:
--
--   Every SECURITY DEFINER function in public must be either
--     (a) service_role-only, or
--     (b) on the explicit AUTHENTICATED_ALLOWLIST below.
--   NOTHING may be callable by anon or by PUBLIC. No exceptions.
--
-- Adding a function to the allow-list is a deliberate act: it means "a signed-in
-- user may call this directly, and it checks auth.uid() internally". If you add
-- one, add a test for its ownership check too — an allow-list entry without an
-- internal check is what F-4's apply_referral was.
--
-- ============================================================================
-- HOW TO RUN — as ONE execute_sql call. MCP makes each call its own
-- transaction, so a split file never pairs BEGIN with ROLLBACK.
-- ============================================================================
-- Last run 2026-07-29: 6/6 PASSED, 0 violations.
-- ============================================================================

BEGIN;

CREATE TEMP TABLE f0_results(t text, outcome text) ON COMMIT DROP;

DO $$
DECLARE
  -- (b) — signed-in users may call these directly. Each is self-scoped and
  -- gates on auth.uid() (or on ownership of the row it touches) internally.
  allowlist text[] := ARRAY[
    'admin_complete_manual_refill(uuid)',
    'admin_switch_gateway_to_manual(uuid)',
    'apply_referral(uuid,text)',
    'calculate_health_score(uuid,text,timestamp with time zone)',
    'cancel_account_deletion()',
    'cancel_topup_execution(uuid)',
    'export_user_data()',
    'get_wallet_forecast(uuid)',
    -- is_power_user(uuid) is deliberately absent: migration 20260801100000 made
    -- it SECURITY INVOKER, so it is out of this perimeter entirely. It must stay
    -- anon-EXECUTEable for the sim_lines "Allow power users full access" policy.
    'pay_plan_fee_from_wallet(text,uuid)',
    'queue_premium_refill_executions(uuid,uuid,timestamp with time zone,timestamp with time zone)',
    'quote_plan_price(uuid,text,text)',
    'redeem_referral_points()',
    'request_account_deletion(text,boolean)',
    'request_esim_purchase(text,integer)',
    'request_instant_refill(uuid,text,text,numeric)',
    'reschedule_mini_refill(uuid,timestamp with time zone)',
    'reset_mini_refill_to_default(uuid)',
    'retry_topup_execution(uuid)',
    'update_mini_refill_dates(uuid,jsonb)'
  ];
  v_bad text;
  v_n int;
  v_passed int := 0;
  v_expected int := 6;
BEGIN
  -- T1: nothing SECURITY DEFINER may be callable by anon. This is F-3/F-4.
  SELECT string_agg(p.oid::regprocedure::text, ', ' ORDER BY p.oid::regprocedure::text), count(*)
    INTO v_bad, v_n
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.prokind = 'f' AND p.prosecdef
    AND has_function_privilege('anon', p.oid, 'EXECUTE');
  IF v_n > 0 THEN
    RAISE EXCEPTION 'T1 FAIL: % SECURITY DEFINER function(s) callable by anon: %', v_n, v_bad;
  END IF;
  INSERT INTO f0_results VALUES ('T1 no SECURITY DEFINER fn is anon-callable', 'PASS');
  v_passed := v_passed + 1;

  -- T2: nothing may carry a PUBLIC EXECUTE grant. This is the F-2 shape — the
  -- ACL entry with an empty grantee, which has_function_privilege alone can miss
  -- if the role also holds a direct grant.
  SELECT string_agg(p.oid::regprocedure::text, ', ' ORDER BY p.oid::regprocedure::text), count(*)
    INTO v_bad, v_n
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.prokind = 'f' AND p.prosecdef
    AND EXISTS (
      SELECT 1 FROM aclexplode(p.proacl) a
      WHERE a.grantee = 0 AND a.privilege_type = 'EXECUTE'
    );
  IF v_n > 0 THEN
    RAISE EXCEPTION 'T2 FAIL: % SECURITY DEFINER function(s) hold PUBLIC EXECUTE: %', v_n, v_bad;
  END IF;
  INSERT INTO f0_results VALUES ('T2 no SECURITY DEFINER fn holds PUBLIC EXECUTE', 'PASS');
  v_passed := v_passed + 1;

  -- T3: a NULL proacl means "default privileges" — which for a function is
  -- EXECUTE TO PUBLIC. Catches a brand-new function nobody locked down.
  SELECT string_agg(p.oid::regprocedure::text, ', ' ORDER BY p.oid::regprocedure::text), count(*)
    INTO v_bad, v_n
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.prokind = 'f' AND p.prosecdef AND p.proacl IS NULL;
  IF v_n > 0 THEN
    RAISE EXCEPTION 'T3 FAIL: % SECURITY DEFINER function(s) have a default (PUBLIC) ACL: %', v_n, v_bad;
  END IF;
  INSERT INTO f0_results VALUES ('T3 no SECURITY DEFINER fn has a default ACL', 'PASS');
  v_passed := v_passed + 1;

  -- T4: anything callable by `authenticated` must be on the allow-list.
  SELECT string_agg(sig, ', ' ORDER BY sig), count(*) INTO v_bad, v_n
  FROM (
    SELECT replace(p.oid::regprocedure::text, 'public.', '') AS sig
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.prokind = 'f' AND p.prosecdef
      AND has_function_privilege('authenticated', p.oid, 'EXECUTE')
  ) s
  WHERE sig <> ALL (allowlist);
  IF v_n > 0 THEN
    RAISE EXCEPTION 'T4 FAIL: % authenticated-callable SECURITY DEFINER function(s) are NOT on the allow-list: %. Either revoke, or add to the allow-list AND test its auth.uid() check.', v_n, v_bad;
  END IF;
  INSERT INTO f0_results VALUES ('T4 every authenticated-callable fn is allow-listed', 'PASS');
  v_passed := v_passed + 1;

  -- T5: the reverse — an allow-listed function that LOST its grant means the
  -- app is broken. This is the D5c failure mode (a lockdown that went too far).
  SELECT string_agg(a, ', ' ORDER BY a), count(*) INTO v_bad, v_n
  FROM unnest(allowlist) a
  WHERE NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.prosecdef
      AND replace(p.oid::regprocedure::text, 'public.', '') = a
      AND has_function_privilege('authenticated', p.oid, 'EXECUTE')
  );
  IF v_n > 0 THEN
    RAISE EXCEPTION 'T5 FAIL: % allow-listed function(s) are missing or no longer callable by authenticated — the app is broken: %', v_n, v_bad;
  END IF;
  INSERT INTO f0_results VALUES ('T5 every allow-listed fn is still authenticated-callable', 'PASS');
  v_passed := v_passed + 1;

  -- T6: service_role must be able to execute everything, or the workers and cron
  -- jobs silently stop.
  SELECT string_agg(p.oid::regprocedure::text, ', ' ORDER BY p.oid::regprocedure::text), count(*)
    INTO v_bad, v_n
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.prokind = 'f' AND p.prosecdef
    AND NOT has_function_privilege('service_role', p.oid, 'EXECUTE');
  IF v_n > 0 THEN
    RAISE EXCEPTION 'T6 FAIL: service_role cannot execute % function(s) — workers/cron are broken: %', v_n, v_bad;
  END IF;
  INSERT INTO f0_results VALUES ('T6 service_role can execute every SECURITY DEFINER fn', 'PASS');
  v_passed := v_passed + 1;

  IF v_passed <> v_expected THEN
    RAISE EXCEPTION 'F0 FAIL: only % of % assertions passed', v_passed, v_expected;
  END IF;
  INSERT INTO f0_results VALUES ('TOTAL', format('%s / %s PASSED', v_passed, v_expected));
END;
$$;

-- Informational: the full matrix, so a reviewer can eyeball it.
SELECT * FROM f0_results;

SELECT
  replace(p.oid::regprocedure::text, 'public.', '') AS function,
  CASE
    WHEN has_function_privilege('anon', p.oid, 'EXECUTE')          THEN 'anon (VIOLATION)'
    WHEN has_function_privilege('authenticated', p.oid, 'EXECUTE') THEN 'authenticated (allow-listed)'
    ELSE 'service_role only'
  END AS bucket
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.prokind = 'f' AND p.prosecdef
ORDER BY 2, 1;

ROLLBACK;
