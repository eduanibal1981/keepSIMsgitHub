-- F1 regression suite — credit_wallet_for_refund must never be reachable by a
-- signed-in user (doc/PRODUCTION_PLAN_REVIEW.md § F-1).
--
-- RUN THIS AS ONE STATEMENT/ONE execute_sql CALL. Splitting it makes each
-- statement its own transaction, so the BEGIN never pairs with the ROLLBACK and
-- the fixture mutations commit (this is how D5b leaked test residue three times).
--
-- Uses the existing a1 fixture user only — creates no auth.users rows.

BEGIN;

DO $$
DECLARE
  v_user_id  uuid := 'e5a56433-6f75-41a3-96b9-19c62b9d1280';  -- a1-wallet-test@example.com
  v_fn       regprocedure := 'public.credit_wallet_for_refund(uuid,numeric,text,text,uuid,text)'::regprocedure;
  v_bal_before numeric;
  v_bal_after  numeric;
  v_sqlstate text;
  v_txn_id   uuid;
  v_passed   int := 0;
BEGIN
  SELECT balance INTO v_bal_before FROM public.wallets WHERE user_id = v_user_id;
  IF v_bal_before IS NULL THEN
    RAISE EXCEPTION 'FIXTURE MISSING: no wallet for a1 test user %', v_user_id;
  END IF;

  -- ==========================================================================
  -- Layer 1 — the grant. This is the assertion that would have caught F-1.
  -- ==========================================================================

  -- T1: anon must not hold EXECUTE
  IF has_function_privilege('anon', v_fn, 'EXECUTE') THEN
    RAISE EXCEPTION 'T1 FAIL: anon can EXECUTE credit_wallet_for_refund';
  END IF;
  v_passed := v_passed + 1;

  -- T2: authenticated must not hold EXECUTE  (F-1: it did, via 20260801010000)
  IF has_function_privilege('authenticated', v_fn, 'EXECUTE') THEN
    RAISE EXCEPTION 'T2 FAIL: authenticated can EXECUTE credit_wallet_for_refund — F-1 has regressed';
  END IF;
  v_passed := v_passed + 1;

  -- T3: PUBLIC must not hold EXECUTE (a PUBLIC grant is how F-2's sibling leaked)
  IF EXISTS (
    SELECT 1 FROM pg_proc p, aclexplode(p.proacl) a
    WHERE p.oid = v_fn::oid AND a.grantee = 0 AND a.privilege_type = 'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'T3 FAIL: PUBLIC holds EXECUTE on credit_wallet_for_refund';
  END IF;
  v_passed := v_passed + 1;

  -- T4: service_role must still hold EXECUTE (the workers depend on it)
  IF NOT has_function_privilege('service_role', v_fn, 'EXECUTE') THEN
    RAISE EXCEPTION 'T4 FAIL: service_role lost EXECUTE — the refund path is broken';
  END IF;
  v_passed := v_passed + 1;

  -- T5: there must be exactly one overload. Two signatures is how the grant
  --     drifted on debit_wallet_for_topup (F-2).
  IF (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public' AND p.proname = 'credit_wallet_for_refund') <> 1 THEN
    RAISE EXCEPTION 'T5 FAIL: more than one credit_wallet_for_refund overload exists';
  END IF;
  v_passed := v_passed + 1;

  -- ==========================================================================
  -- Layer 2 — the in-body guard, tested independently of the grant.
  -- current_user is postgres here, which holds EXECUTE, so these calls reach
  -- the body; only the JWT-claims guard can stop them.
  -- ==========================================================================

  -- T6: a JWT with role=authenticated is refused with KS403
  BEGIN
    PERFORM set_config('request.jwt.claims',
      json_build_object('role', 'authenticated', 'sub', v_user_id)::text, true);
    PERFORM public.credit_wallet_for_refund(v_user_id, 100000, 'f1_t6', 'guard probe', NULL, 'refund');
    PERFORM set_config('request.jwt.claims', '', true);
    RAISE EXCEPTION 'T6 FAIL: guard let an authenticated JWT mint 100000';
  EXCEPTION WHEN SQLSTATE 'KS403' THEN
    PERFORM set_config('request.jwt.claims', '', true);
    v_passed := v_passed + 1;
  END;

  -- T7: a JWT with role=anon is refused with KS403
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
    PERFORM public.credit_wallet_for_refund(v_user_id, 100000, 'f1_t7', 'guard probe', NULL, 'refund');
    PERFORM set_config('request.jwt.claims', '', true);
    RAISE EXCEPTION 'T7 FAIL: guard let an anon JWT mint 100000';
  EXCEPTION WHEN SQLSTATE 'KS403' THEN
    PERFORM set_config('request.jwt.claims', '', true);
    v_passed := v_passed + 1;
  END;

  -- T8: the guard is fail-CLOSED on malformed claims (must not fall through)
  BEGIN
    PERFORM set_config('request.jwt.claims', 'not-json', true);
    PERFORM public.credit_wallet_for_refund(v_user_id, 100000, 'f1_t8', 'guard probe', NULL, 'refund');
    PERFORM set_config('request.jwt.claims', '', true);
    RAISE EXCEPTION 'T8 FAIL: malformed JWT claims fell through to the refund';
  EXCEPTION WHEN SQLSTATE 'KS403' OR invalid_text_representation THEN
    PERFORM set_config('request.jwt.claims', '', true);
    v_passed := v_passed + 1;
  END;

  -- T9: assert nothing above actually moved money
  SELECT balance INTO v_bal_after FROM public.wallets WHERE user_id = v_user_id;
  IF v_bal_after <> v_bal_before THEN
    RAISE EXCEPTION 'T9 FAIL: balance moved during the guard probes (% -> %)', v_bal_before, v_bal_after;
  END IF;
  v_passed := v_passed + 1;

  -- ==========================================================================
  -- The legitimate paths must still work.
  -- ==========================================================================

  -- T10: a service_role JWT passes the guard and reaches the amount validation
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
    PERFORM public.credit_wallet_for_refund(v_user_id, -1, 'f1_t10', 'probe', NULL, 'refund');
    PERFORM set_config('request.jwt.claims', '', true);
    RAISE EXCEPTION 'T10 FAIL: a negative refund was accepted';
  EXCEPTION
    WHEN SQLSTATE 'KS403' THEN
      PERFORM set_config('request.jwt.claims', '', true);
      RAISE EXCEPTION 'T10 FAIL: the guard blocked service_role — the workers cannot refund';
    WHEN raise_exception THEN
      PERFORM set_config('request.jwt.claims', '', true);
      v_passed := v_passed + 1;
  END;

  -- T11: an internal caller with no claims GUC (pg_cron, reap_stale_esim_orders,
  --      a worker over the service key) still performs a real refund
  v_txn_id := public.credit_wallet_for_refund(v_user_id, 5.00, 'f1_t11', 'F1 refund path', NULL, 'refund');
  SELECT balance INTO v_bal_after FROM public.wallets WHERE user_id = v_user_id;
  IF v_txn_id IS NULL OR v_bal_after <> v_bal_before + 5.00 THEN
    RAISE EXCEPTION 'T11 FAIL: internal refund path broken (% -> %, txn %)', v_bal_before, v_bal_after, v_txn_id;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.wallet_transactions WHERE id = v_txn_id AND type = 'refund') THEN
    RAISE EXCEPTION 'T11 FAIL: no ledger row written for the refund';
  END IF;
  v_passed := v_passed + 1;

  RAISE NOTICE 'F1: % / 11 assertions passed', v_passed;
  IF v_passed <> 11 THEN
    RAISE EXCEPTION 'F1 FAIL: only % of 11 assertions passed', v_passed;
  END IF;
END;
$$;

ROLLBACK;
