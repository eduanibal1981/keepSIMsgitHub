-- F3 + F4 regression suite (doc/PRODUCTION_PLAN_REVIEW.md § F-3, § F-4).
--
-- Uses the existing a1 fixture only — creates no auth.users rows.
--
-- ============================================================================
-- HOW TO RUN — the file is in two parts on purpose
-- ============================================================================
-- PART A is one transaction. Run it as ONE statement / ONE execute_sql call.
--   Splitting it makes each statement its own transaction, so BEGIN never pairs
--   with ROLLBACK and the plan-fee debit COMMITS. That is how test residue
--   leaked into production three times in this project.
--
-- PART B is six separate probes. Each is EXPECTED TO RAISE, and the raise IS the
--   pass condition, so each must be run on its own — the error aborts the
--   transaction, which is also what discards the temporary GRANT each probe makes.
--
--   Part B cannot be folded into Part A. consume_rate_limit and
--   enforce_rate_limit key on plpgsql call depth, and a DO block is itself a
--   frame: anything invoked from inside DO looks nested and is allowed. Only a
--   top-level statement reproduces what PostgREST issues for an RPC. A DO-block
--   "direct call" probe passes vacuously — learned the hard way in F-2.
-- ============================================================================


-- ============================================================================
-- PART A — grants, and the legitimate paths that must keep working
-- ============================================================================

BEGIN;

CREATE TEMP TABLE f34(t text, outcome text) ON COMMIT DROP;

DO $$
DECLARE
  v_uid  uuid := 'e5a56433-6f75-41a3-96b9-19c62b9d1280';  -- a1-wallet-test@example.com
  v_line uuid := 'a918abf3-0bd8-45cf-8885-8a927846915f';  -- a1's line
  v_victim uuid;
  -- The five that must be service_role-only.
  svc_only text[] := ARRAY[
    'public.purge_deleted_accounts()',
    'public.prune_rate_limit_data()',
    'public.check_rate_limit_health()',
    'public.consume_rate_limit(text,text,integer,numeric,timestamptz)',
    'public.enforce_rate_limit(text,text)',
    'public.trg_fn_award_referral_points()'
  ];
  -- The six that must stay callable by a signed-in user but never by anon.
  self_scoped text[] := ARRAY[
    'public.export_user_data()',
    'public.apply_referral(uuid,text)',
    'public.request_account_deletion(text,boolean)',
    'public.cancel_account_deletion()',
    'public.redeem_referral_points()'
  ];
  -- is_power_user(uuid) was in this list until F-4b. Revoking anon from it broke
  -- `anon SELECT sim_lines` with 42501, because the "Allow power users full
  -- access on sim_lines" policy is FOR ALL TO public and calls it — RLS policy
  -- expressions run as the querying role. Migration 20260801100000 made it
  -- SECURITY INVOKER and re-granted anon instead; T9 below pins that.
  s text;
  v_bal_before numeric; v_bal_after numeric; v_j jsonb;
  v_passed int := 0;
  v_expected int := 9;
BEGIN
  SELECT balance INTO v_bal_before FROM public.wallets WHERE user_id = v_uid;
  IF v_bal_before IS NULL THEN
    RAISE EXCEPTION 'FIXTURE MISSING: no wallet for a1 test user %', v_uid;
  END IF;

  -- --- Layer 1: grants ------------------------------------------------------

  -- T1: the service_role-only set is exactly that.
  FOREACH s IN ARRAY svc_only LOOP
    IF has_function_privilege('anon', s::regprocedure, 'EXECUTE') THEN
      RAISE EXCEPTION 'T1 FAIL: anon can EXECUTE % — F-3/F-4 has regressed', s;
    END IF;
    IF has_function_privilege('authenticated', s::regprocedure, 'EXECUTE') THEN
      RAISE EXCEPTION 'T1 FAIL: authenticated can EXECUTE %', s;
    END IF;
    IF NOT has_function_privilege('service_role', s::regprocedure, 'EXECUTE') THEN
      RAISE EXCEPTION 'T1 FAIL: service_role lost EXECUTE on % — cron/workers broken', s;
    END IF;
  END LOOP;
  INSERT INTO f34 VALUES ('T1 six fns are service_role-only', 'PASS'); v_passed := v_passed + 1;

  -- T2: the self-scoped set lost anon but kept authenticated.
  FOREACH s IN ARRAY self_scoped LOOP
    IF has_function_privilege('anon', s::regprocedure, 'EXECUTE') THEN
      RAISE EXCEPTION 'T2 FAIL: anon can still EXECUTE %', s;
    END IF;
    IF NOT has_function_privilege('authenticated', s::regprocedure, 'EXECUTE') THEN
      RAISE EXCEPTION 'T2 FAIL: authenticated lost EXECUTE on % — the app is broken', s;
    END IF;
  END LOOP;
  INSERT INTO f34 VALUES ('T2 six self-scoped fns: anon revoked, authenticated kept', 'PASS');
  v_passed := v_passed + 1;

  -- T3: no PUBLIC grant survives on any of them (the F-2 shape).
  FOREACH s IN ARRAY (svc_only || self_scoped) LOOP
    IF EXISTS (
      SELECT 1 FROM pg_proc p, aclexplode(p.proacl) a
      WHERE p.oid = s::regprocedure::oid AND a.grantee = 0 AND a.privilege_type = 'EXECUTE'
    ) THEN
      RAISE EXCEPTION 'T3 FAIL: PUBLIC holds EXECUTE on %', s;
    END IF;
  END LOOP;
  INSERT INTO f34 VALUES ('T3 no PUBLIC EXECUTE on any of the twelve', 'PASS'); v_passed := v_passed + 1;

  -- T4: enforce_rate_limit MUST re-raise KS403. Its body ends in a
  --     `WHEN OTHERS THEN RAISE NOTICE` catch-all; without an explicit KS403
  --     branch that swallows the guard AND disables rate limiting silently.
  IF (SELECT prosrc FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public' AND p.proname = 'enforce_rate_limit') NOT LIKE '%KS403%' THEN
    RAISE EXCEPTION 'T4 FAIL: enforce_rate_limit has no KS403 branch — WHEN OTHERS will eat the guard';
  END IF;
  INSERT INTO f34 VALUES ('T4 enforce_rate_limit re-raises KS403 past its WHEN OTHERS', 'PASS');
  v_passed := v_passed + 1;

  -- --- The legitimate paths -------------------------------------------------

  PERFORM set_config('request.jwt.claims',
    json_build_object('role','authenticated','sub',v_uid)::text, true);

  -- T5: NESTED enforce_rate_limit + consume_rate_limit under an authenticated
  --     JWT, through a real money RPC. This is the half a naive role guard
  --     would have broken — every eSIM purchase and plan fee.
  BEGIN
    PERFORM public.pay_plan_fee_from_wallet('f34_t5_' || gen_random_uuid()::text, v_line);
    SELECT balance INTO v_bal_after FROM public.wallets WHERE user_id = v_uid;
    IF v_bal_after >= v_bal_before THEN
      RAISE EXCEPTION 'T5 FAIL: plan fee did not debit (% -> %)', v_bal_before, v_bal_after;
    END IF;
    INSERT INTO f34 VALUES ('T5 nested enforce+consume under an authenticated JWT',
      format('PASS — balance %s -> %s', v_bal_before, v_bal_after));
    v_passed := v_passed + 1;
  EXCEPTION WHEN SQLSTATE 'KS403' THEN
    RAISE EXCEPTION 'T5 FAIL: the guard blocked a legitimate nested call — plan fees and eSIM purchases are broken';
  END;

  UPDATE public.wallets SET balance = v_bal_before WHERE user_id = v_uid;

  -- T6: nested consume_rate_limit via apply_referral reaches the body.
  BEGIN
    v_j := public.apply_referral(v_uid, 'NOSUCHCODE_F34');
    IF v_j ->> 'error' IS DISTINCT FROM 'Invalid referral code' THEN
      RAISE EXCEPTION 'T6 FAIL: unexpected apply_referral result %', v_j::text;
    END IF;
    INSERT INTO f34 VALUES ('T6 nested consume via apply_referral', 'PASS'); v_passed := v_passed + 1;
  EXCEPTION WHEN SQLSTATE 'KS403' THEN
    RAISE EXCEPTION 'T6 FAIL: the guard blocked apply_referral''s nested limiter call';
  END;

  -- T7: apply_referral's ownership check. Until 2026-07-29 this predicate was
  --     `auth.uid() IS NOT NULL AND auth.uid() <> p_referred_id`, which no-oped
  --     for anon and let an unauthenticated caller write ANY user's profile.
  SELECT id INTO v_victim FROM public.profiles WHERE id <> v_uid LIMIT 1;
  v_j := public.apply_referral(v_victim, 'SS2A150D18');
  IF v_j ->> 'error' IS DISTINCT FROM 'UNAUTHORIZED' THEN
    RAISE EXCEPTION 'T7 FAIL: apply_referral accepted another user''s id: %', v_j::text;
  END IF;
  INSERT INTO f34 VALUES ('T7 apply_referral refuses another user''s id', 'PASS'); v_passed := v_passed + 1;

  -- T8: service_role reaches consume_rate_limit at the TOP level. Five Edge
  --     Functions do exactly this (create-paypal-order, capture-paypal-order,
  --     detect-country, paypal-webhook, sms-webhook) — a depth-only guard
  --     without the service_role escape hatch would break all five.
  PERFORM set_config('request.jwt.claims', json_build_object('role','service_role')::text, true);
  PERFORM public.consume_rate_limit('f34_t8', 'f34_t8', 10, 1.0, clock_timestamp());
  INSERT INTO f34 VALUES ('T8 service_role top-level consume still works', 'PASS'); v_passed := v_passed + 1;

  PERFORM set_config('request.jwt.claims', '', true);

  -- T9: is_power_user must NOT be SECURITY DEFINER and MUST stay anon-callable.
  --     Both halves matter. If it regains SECURITY DEFINER it re-enters the
  --     grant-matrix perimeter as an anon-callable definer function; if it loses
  --     anon EXECUTE, `anon SELECT sim_lines` dies with 42501 because the
  --     "Allow power users full access" policy is FOR ALL TO public. See F-4b.
  IF (SELECT prosecdef FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public' AND p.proname = 'is_power_user') THEN
    RAISE EXCEPTION 'T9 FAIL: is_power_user is SECURITY DEFINER again — it is anon-callable by necessity';
  END IF;
  IF NOT has_function_privilege('anon', 'public.is_power_user(uuid)'::regprocedure, 'EXECUTE') THEN
    RAISE EXCEPTION 'T9 FAIL: anon lost EXECUTE on is_power_user — anon SELECT on sim_lines now raises 42501';
  END IF;
  INSERT INTO f34 VALUES ('T9 is_power_user is INVOKER and still anon-callable', 'PASS');
  v_passed := v_passed + 1;

  SELECT balance INTO v_bal_after FROM public.wallets WHERE user_id = v_uid;
  IF v_bal_after <> v_bal_before THEN
    RAISE EXCEPTION 'FAIL: net balance changed (% -> %)', v_bal_before, v_bal_after;
  END IF;
  INSERT INTO f34 VALUES ('balance restored', format('%s', v_bal_after));

  IF v_passed <> v_expected THEN
    RAISE EXCEPTION 'F34 FAIL: only % of % assertions passed', v_passed, v_expected;
  END IF;
  INSERT INTO f34 VALUES ('TOTAL', format('%s / %s PASSED', v_passed, v_expected));
END;
$$;

SELECT * FROM f34;

ROLLBACK;


-- ============================================================================
-- PART B — layer 2 proven on its own, one probe per run.
--
-- Each probe restores the grant inside the transaction, so layer 1 cannot be the
-- thing that blocks: only the in-body guard can. Each is EXPECTED TO ERROR, and
-- the error IS the pass condition. Anything else — especially a returned row —
-- is a FAIL meaning the guard is dead code.
--
-- Last verified 2026-07-29, results inline.
-- ============================================================================

-- P1 — consume_rate_limit direct as authenticated, picking a victim's key.
-- EXPECT: ERROR KS403 "consume_rate_limit is not directly callable by role authenticated"
BEGIN;
GRANT EXECUTE ON FUNCTION public.consume_rate_limit(text,text,integer,numeric,timestamptz) TO authenticated;
SELECT set_config('request.jwt.claims',
  json_build_object('role','authenticated','sub','e5a56433-6f75-41a3-96b9-19c62b9d1280')::text, true);
SET LOCAL ROLE authenticated;
SELECT * FROM public.consume_rate_limit('instant_refill','victim-user-id',10,1.0,clock_timestamp());
ROLLBACK;

-- P2 — consume_rate_limit direct as anon (the APK's key).
-- EXPECT: ERROR KS403 "consume_rate_limit is not directly callable by role anon"
BEGIN;
GRANT EXECUTE ON FUNCTION public.consume_rate_limit(text,text,integer,numeric,timestamptz) TO anon;
SELECT set_config('request.jwt.claims', json_build_object('role','anon')::text, true);
SET LOCAL ROLE anon;
SELECT * FROM public.consume_rate_limit('instant_refill','victim-user-id',10,1.0,clock_timestamp());
ROLLBACK;

-- P3 — enforce_rate_limit direct as authenticated. This one also proves the
-- KS403 branch beats the WHEN OTHERS catch-all: without it this probe returns
-- void cleanly and the guard is dead.
-- EXPECT: ERROR KS403 "enforce_rate_limit is not directly callable by role authenticated"
BEGIN;
GRANT EXECUTE ON FUNCTION public.enforce_rate_limit(text,text) TO authenticated;
SELECT set_config('request.jwt.claims',
  json_build_object('role','authenticated','sub','e5a56433-6f75-41a3-96b9-19c62b9d1280')::text, true);
SET LOCAL ROLE authenticated;
SELECT public.enforce_rate_limit('instant_refill','victim-user-id');
ROLLBACK;

-- P4 — purge_deleted_accounts direct as authenticated.
-- EXPECT: ERROR KS403 "purge_deleted_accounts is not callable by role authenticated"
BEGIN;
GRANT EXECUTE ON FUNCTION public.purge_deleted_accounts() TO authenticated;
SELECT set_config('request.jwt.claims',
  json_build_object('role','authenticated','sub','e5a56433-6f75-41a3-96b9-19c62b9d1280')::text, true);
SET LOCAL ROLE authenticated;
SELECT public.purge_deleted_accounts();
ROLLBACK;

-- P5 — prune_rate_limit_data direct as anon.
-- EXPECT: ERROR KS403 "prune_rate_limit_data is not callable by role anon"
BEGIN;
GRANT EXECUTE ON FUNCTION public.prune_rate_limit_data() TO anon;
SELECT set_config('request.jwt.claims', json_build_object('role','anon')::text, true);
SET LOCAL ROLE anon;
SELECT public.prune_rate_limit_data();
ROLLBACK;

-- P6 — malformed JWT claims must fail CLOSED, not fall through.
-- EXPECT: ERROR 22P02 invalid input syntax for type json, raised at the claims
--         cast (line 14) i.e. before the deletion state machine runs at all.
BEGIN;
GRANT EXECUTE ON FUNCTION public.purge_deleted_accounts() TO authenticated;
SELECT set_config('request.jwt.claims', 'not-json', true);
SET LOCAL ROLE authenticated;
SELECT public.purge_deleted_accounts();
ROLLBACK;
