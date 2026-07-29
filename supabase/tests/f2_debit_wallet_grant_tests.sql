-- F2 regression suite — debit_wallet_for_topup must not be callable directly by a
-- client, but must still work when nested inside a server-side RPC
-- (doc/PRODUCTION_PLAN_REVIEW.md § F-2).
--
-- Uses the existing a1 fixture only — creates no auth.users rows.
--
-- ============================================================================
-- HOW TO RUN — read this, the file is in two parts on purpose
-- ============================================================================
-- PART A is one transaction. Run it as ONE statement / ONE execute_sql call.
--   Splitting it makes each statement its own transaction, so BEGIN never pairs
--   with ROLLBACK and the debits COMMIT. That is how test residue leaked into
--   production three times in this project.
--
-- PART B is three separate probes. Each one is EXPECTED TO RAISE, so each must be
--   run on its own — an error aborts the whole transaction, which is also what
--   discards the temporary GRANT each probe makes.
--
--   Part B cannot be folded into Part A. The guard keys on plpgsql call depth, and
--   a DO block is itself a frame: anything invoked from inside DO looks nested and
--   is allowed. Only a top-level statement reproduces what PostgREST actually
--   issues for an RPC. A DO-block "direct call" probe passes vacuously — verified
--   the hard way while writing this.
-- ============================================================================


-- ============================================================================
-- PART A — grants, and the legitimate paths that must keep working
-- ============================================================================

BEGIN;

CREATE TEMP TABLE f2_results(t text, outcome text) ON COMMIT DROP;

DO $$
DECLARE
  v_user_id uuid := 'e5a56433-6f75-41a3-96b9-19c62b9d1280';  -- a1-wallet-test@example.com
  v_line_id uuid := 'a918abf3-0bd8-45cf-8885-8a927846915f';  -- a1's free line
  v_fn regprocedure := 'public.debit_wallet_for_topup(uuid,uuid,numeric,text,text,text)'::regprocedure;
  v_bal_before numeric;
  v_bal_after numeric;
  v_passed int := 0;
  v_expected int := 7;
BEGIN
  SELECT balance INTO v_bal_before FROM public.wallets WHERE user_id = v_user_id;
  IF v_bal_before IS NULL THEN
    RAISE EXCEPTION 'FIXTURE MISSING: no wallet for a1 test user %', v_user_id;
  END IF;

  -- --- Layer 1: grants -------------------------------------------------------

  IF has_function_privilege('anon', v_fn, 'EXECUTE') THEN
    RAISE EXCEPTION 'T1 FAIL: anon can EXECUTE debit_wallet_for_topup — F-2 has regressed';
  END IF;
  INSERT INTO f2_results VALUES ('T1 anon has no EXECUTE', 'PASS'); v_passed := v_passed + 1;

  IF has_function_privilege('authenticated', v_fn, 'EXECUTE') THEN
    RAISE EXCEPTION 'T2 FAIL: authenticated can EXECUTE debit_wallet_for_topup';
  END IF;
  INSERT INTO f2_results VALUES ('T2 authenticated has no EXECUTE', 'PASS'); v_passed := v_passed + 1;

  IF EXISTS (
    SELECT 1 FROM pg_proc p, aclexplode(p.proacl) a
    WHERE p.oid = v_fn::oid AND a.grantee = 0 AND a.privilege_type = 'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'T3 FAIL: PUBLIC holds EXECUTE — this was the F-2 hole';
  END IF;
  INSERT INTO f2_results VALUES ('T3 PUBLIC holds no EXECUTE', 'PASS'); v_passed := v_passed + 1;

  IF NOT has_function_privilege('service_role', v_fn, 'EXECUTE') THEN
    RAISE EXCEPTION 'T4 FAIL: service_role lost EXECUTE — the refill path is broken';
  END IF;
  INSERT INTO f2_results VALUES ('T4 service_role keeps EXECUTE', 'PASS'); v_passed := v_passed + 1;

  -- T5: exactly ONE signature. Two is what let the PUBLIC grant hide, and what made
  --     PostgREST unable to resolve either real caller's payload (PGRST203) — see
  --     migration 20260801060000.
  IF (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public' AND p.proname = 'debit_wallet_for_topup') <> 1 THEN
    RAISE EXCEPTION 'T5 FAIL: debit_wallet_for_topup is overloaded again';
  END IF;
  INSERT INTO f2_results VALUES ('T5 exactly one overload', 'PASS'); v_passed := v_passed + 1;

  -- --- The legitimate paths --------------------------------------------------

  -- T6: NESTED call under an authenticated JWT. pay_plan_fee_from_wallet is a
  --     user-invoked SECURITY DEFINER RPC that debits internally. This is the half
  --     a naive copy of F-1's guard would have broken.
  BEGIN
    PERFORM set_config('request.jwt.claims',
      json_build_object('role','authenticated','sub',v_user_id)::text, true);
    PERFORM public.pay_plan_fee_from_wallet('f2_t6_' || gen_random_uuid()::text, v_line_id);
    PERFORM set_config('request.jwt.claims', '', true);

    SELECT balance INTO v_bal_after FROM public.wallets WHERE user_id = v_user_id;
    IF v_bal_after >= v_bal_before THEN
      RAISE EXCEPTION 'T6 FAIL: plan fee did not debit (% -> %)', v_bal_before, v_bal_after;
    END IF;
    INSERT INTO f2_results VALUES ('T6 nested authenticated debit (plan fee)',
      format('PASS — balance %s -> %s', v_bal_before, v_bal_after));
    v_passed := v_passed + 1;
  EXCEPTION WHEN SQLSTATE 'KS403' THEN
    PERFORM set_config('request.jwt.claims', '', true);
    RAISE EXCEPTION 'T6 FAIL: the guard blocked a legitimate nested debit — eSIM purchases and plan fees are broken';
  END;

  UPDATE public.wallets SET balance = v_bal_before WHERE user_id = v_user_id;

  -- T7: a service_role caller (the workers) passes the guard and reaches the body.
  --     A negative amount keeps it non-mutating; P0001 proves we got past the guard.
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('role','service_role')::text, true);
    PERFORM public.debit_wallet_for_topup(v_user_id, NULL, -1, 'f2 t7', 'f2_t7', 'topup_debit');
    PERFORM set_config('request.jwt.claims', '', true);
    RAISE EXCEPTION 'T7 FAIL: a negative debit was accepted';
  EXCEPTION
    WHEN SQLSTATE 'KS403' THEN
      PERFORM set_config('request.jwt.claims', '', true);
      RAISE EXCEPTION 'T7 FAIL: the guard blocked service_role — the refill workers cannot debit';
    WHEN raise_exception THEN
      PERFORM set_config('request.jwt.claims', '', true);
      INSERT INTO f2_results VALUES ('T7 service_role reaches the body', 'PASS');
      v_passed := v_passed + 1;
  END;

  SELECT balance INTO v_bal_after FROM public.wallets WHERE user_id = v_user_id;
  IF v_bal_after <> v_bal_before THEN
    RAISE EXCEPTION 'FAIL: net balance changed (% -> %)', v_bal_before, v_bal_after;
  END IF;
  INSERT INTO f2_results VALUES ('balance restored', format('%s', v_bal_after));

  IF v_passed <> v_expected THEN
    RAISE EXCEPTION 'F2 FAIL: only % of % assertions passed', v_passed, v_expected;
  END IF;
  INSERT INTO f2_results VALUES ('TOTAL', format('%s / %s PASSED', v_passed, v_expected));
END;
$$;

SELECT * FROM f2_results;

ROLLBACK;


-- ============================================================================
-- PART B — layer 2 proven on its own, one probe per run
--
-- Each probe restores the grant inside the transaction, so layer 1 cannot be the
-- thing that blocks: only the in-body guard can. Each is EXPECTED TO ERROR, and the
-- error IS the pass condition. Anything else — especially a returned uuid — is a
-- FAIL meaning the guard is dead code.
--
-- Last verified 2026-07-29, results inline.
-- ============================================================================

-- P1 — direct call as role authenticated.
-- EXPECT: ERROR KS403 "debit_wallet_for_topup is not directly callable by role authenticated"
BEGIN;
GRANT EXECUTE ON FUNCTION public.debit_wallet_for_topup(uuid,uuid,numeric,text,text,text) TO authenticated;
SELECT set_config('request.jwt.claims',
  json_build_object('role','authenticated','sub','e5a56433-6f75-41a3-96b9-19c62b9d1280')::text, true);
SET LOCAL ROLE authenticated;
SELECT public.debit_wallet_for_topup('e5a56433-6f75-41a3-96b9-19c62b9d1280', NULL, 100000, 'drain', 'f2_p1', 'topup_debit');
ROLLBACK;

-- P2 — direct call as role anon (the APK's key).
-- EXPECT: ERROR KS403 "debit_wallet_for_topup is not directly callable by role anon"
BEGIN;
GRANT EXECUTE ON FUNCTION public.debit_wallet_for_topup(uuid,uuid,numeric,text,text,text) TO anon;
SELECT set_config('request.jwt.claims', json_build_object('role','anon')::text, true);
SET LOCAL ROLE anon;
SELECT public.debit_wallet_for_topup('e5a56433-6f75-41a3-96b9-19c62b9d1280', NULL, 100000, 'drain', 'f2_p2', 'topup_debit');
ROLLBACK;

-- P3 — malformed JWT claims must fail CLOSED, not fall through.
-- EXPECT: ERROR 22P02 invalid input syntax for type json (raised at the claims cast,
--         i.e. before any balance is touched)
BEGIN;
GRANT EXECUTE ON FUNCTION public.debit_wallet_for_topup(uuid,uuid,numeric,text,text,text) TO authenticated;
SELECT set_config('request.jwt.claims', 'not-json', true);
SET LOCAL ROLE authenticated;
SELECT public.debit_wallet_for_topup('e5a56433-6f75-41a3-96b9-19c62b9d1280', NULL, 100000, 'drain', 'f2_p3', 'topup_debit');
ROLLBACK;
