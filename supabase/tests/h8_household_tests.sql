-- ============================================================================
-- H8 — Household & Family. Regression tests for the three defects that turning
-- the feature back on exposed.
--
-- T1 is the important one. Before H8 it FAILED: an accepted viewer ran
--     UPDATE household_members SET role='manager' WHERE id=<own row>;
-- and it worked, because `authenticated` holds column-level UPDATE on every
-- column and the member policy scoped rows but not columns. `role='manager'`
-- gates request_instant_refill, the sim_lines UPDATE policy and G6 wallet
-- spending, so that one UPDATE turned a read-only relative into someone who
-- could drain the owner's wallet to the $100,000 CHECK ceiling.
--
-- ============================================================================
-- HOW TO RUN — as ONE execute_sql call. MCP makes each call its own
-- transaction, so a split file never pairs BEGIN with ROLLBACK.
-- ============================================================================
-- Last run 2026-08-04 (H8 applied): 7/7 PASSED.
-- ============================================================================

BEGIN;

CREATE TEMP TABLE h8_results(t text, outcome text) ON COMMIT DROP;
-- Unlike f0_grant_matrix_tests.sql, this file impersonates `authenticated` to
-- exercise RLS, and the results table has to stay writable across those
-- SET LOCAL ROLE sections.
GRANT INSERT ON h8_results TO authenticated;

DO $$
DECLARE
  v_owner    uuid;
  v_member   uuid;
  v_owner_em text;
  v_mem_em   text;
  v_ghost    uuid := gen_random_uuid();
  v_ghost_em text := 'h8-ghost-' || substr(gen_random_uuid()::text, 1, 8) || '@example.test';
  v_id       uuid;
  v_role     text;
  v_cap      numeric;
  v_n        int;
  v_res      jsonb;
  v_passed   int := 0;
  v_expected int := 7;
BEGIN
  -- Two real profiles; the FKs point at profiles(id), so fabricated uuids will
  -- not do.
  SELECT id, email INTO v_owner, v_owner_em FROM public.profiles ORDER BY created_at LIMIT 1;
  SELECT id, email INTO v_member, v_mem_em
    FROM public.profiles WHERE id <> v_owner ORDER BY created_at LIMIT 1;

  DELETE FROM public.household_members WHERE owner_id = v_owner;

  -- ---------------------------------------------------------------- fixtures
  INSERT INTO public.household_members (owner_id, member_email, role, invite_status)
  VALUES (v_owner, lower(v_mem_em), 'viewer', 'accepted') RETURNING id INTO v_id;

  PERFORM set_config('request.jwt.claims', json_build_object(
    'sub', v_member, 'role', 'authenticated', 'email', v_mem_em)::text, true);
  SET LOCAL ROLE authenticated;

  -- T1: a member cannot promote themselves. THE hole.
  UPDATE public.household_members SET role = 'manager' WHERE id = v_id;
  SELECT role INTO v_role FROM public.household_members WHERE id = v_id;
  IF v_role <> 'viewer' THEN
    RAISE EXCEPTION 'T1 FAIL: a viewer escalated itself to % — the wallet is reachable', v_role;
  END IF;
  INSERT INTO h8_results VALUES ('T1 member cannot self-promote to manager', 'PASS');
  v_passed := v_passed + 1;

  -- T2: nor fund themselves out of the owner's wallet.
  UPDATE public.household_members SET monthly_cap_usd = 9999 WHERE id = v_id;
  SELECT monthly_cap_usd INTO v_cap FROM public.household_members WHERE id = v_id;
  IF v_cap <> 0 THEN
    RAISE EXCEPTION 'T2 FAIL: a member set its own cap to % of the owner''s wallet', v_cap;
  END IF;
  INSERT INTO h8_results VALUES ('T2 member cannot set its own spend cap', 'PASS');
  v_passed := v_passed + 1;

  -- T3: leaving works, and works through the RPC rather than silently not at
  -- all. Members have no DELETE policy, so the direct delete is the no-op the
  -- UI used to report as success.
  DELETE FROM public.household_members WHERE id = v_id;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'T3 FAIL: a member deleted its own row directly (% rows)', v_n;
  END IF;
  v_res := public.leave_household(v_id);
  IF v_res ->> 'success' <> 'true'
     OR EXISTS (SELECT 1 FROM public.household_members WHERE id = v_id) THEN
    RAISE EXCEPTION 'T3 FAIL: leave_household did not remove the membership: %', v_res;
  END IF;
  INSERT INTO h8_results VALUES ('T3 leave_household actually removes the row', 'PASS');
  v_passed := v_passed + 1;

  -- ------------------------------------------------- the invite lifecycle
  RESET ROLE;
  PERFORM set_config('request.jwt.claims', json_build_object(
    'sub', v_owner, 'role', 'authenticated', 'email', v_owner_em)::text, true);
  SET LOCAL ROLE authenticated;

  -- T4: the duplicate check is server-side and returns an envelope, not a raw
  -- UNIQUE violation.
  v_res := public.invite_household_member(upper(v_mem_em), 'manager');
  IF v_res ->> 'success' <> 'true' THEN
    RAISE EXCEPTION 'T4 FAIL: a valid invite was refused: %', v_res;
  END IF;
  v_id := (v_res ->> 'id')::uuid;
  IF public.invite_household_member(v_mem_em, 'viewer') ->> 'code' <> 'ALREADY_INVITED' THEN
    RAISE EXCEPTION 'T4 FAIL: a duplicate invite was not refused';
  END IF;
  IF public.invite_household_member(v_owner_em, 'viewer') ->> 'code' <> 'SELF_INVITE' THEN
    RAISE EXCEPTION 'T4 FAIL: self-invite was not refused';
  END IF;
  IF public.invite_household_member('not-an-email', 'viewer') ->> 'code' <> 'INVALID_EMAIL' THEN
    RAISE EXCEPTION 'T4 FAIL: a malformed address was accepted';
  END IF;
  INSERT INTO h8_results VALUES ('T4 invite validates duplicate/self/format server-side', 'PASS');
  v_passed := v_passed + 1;

  -- T5: an invite to somebody with no account yet binds when they register.
  -- This is the dead-invite bug: member_id was resolved at INSERT only, the
  -- member SELECT policy keyed on member_id, and nothing back-filled it — so
  -- the invitee registered and saw nothing, forever.
  PERFORM public.invite_household_member(v_ghost_em, 'viewer');
  IF (SELECT member_id FROM public.household_members WHERE member_email = lower(v_ghost_em)) IS NOT NULL THEN
    RAISE EXCEPTION 'T5 FAIL: member_id was set for an account that does not exist';
  END IF;
  RESET ROLE;
  INSERT INTO auth.users (id, email, aud, role)
  VALUES (v_ghost, v_ghost_em, 'authenticated', 'authenticated');
  IF (SELECT member_id FROM public.household_members WHERE member_email = lower(v_ghost_em)) <> v_ghost THEN
    RAISE EXCEPTION 'T5 FAIL: signing up did not claim the pending invitation';
  END IF;
  INSERT INTO h8_results VALUES ('T5 signup back-fills member_id on a pending invite', 'PASS');
  v_passed := v_passed + 1;

  -- T6: accepting binds the row and changes nothing else.
  PERFORM set_config('request.jwt.claims', json_build_object(
    'sub', v_member, 'role', 'authenticated', 'email', v_mem_em)::text, true);
  SET LOCAL ROLE authenticated;
  v_res := public.respond_to_household_invite(v_id, true);
  IF v_res ->> 'success' <> 'true' THEN
    RAISE EXCEPTION 'T6 FAIL: accept was refused: %', v_res;
  END IF;
  SELECT invite_status || '/' || role, monthly_cap_usd INTO v_role, v_cap
    FROM public.household_members WHERE id = v_id;
  -- 'manager' is what the owner invited them as; accept must not alter it, and
  -- must not invent a cap.
  IF v_role <> 'accepted/manager' OR v_cap <> 0
     OR (SELECT member_id FROM public.household_members WHERE id = v_id) <> v_member THEN
    RAISE EXCEPTION 'T6 FAIL: accept left the row in a wrong state (%, cap=%)', v_role, v_cap;
  END IF;
  INSERT INTO h8_results VALUES ('T6 accept binds member_id and touches nothing else', 'PASS');
  v_passed := v_passed + 1;

  -- T7: member_id must always be the account that owns member_email, so an
  -- owner cannot hand a stranger read access to their own lines.
  RESET ROLE;
  BEGIN
    UPDATE public.household_members SET member_id = v_owner WHERE id = v_id;
    RAISE EXCEPTION 'T7 FAIL: member_id was pointed at an unrelated account';
  EXCEPTION
    WHEN SQLSTATE 'KS403' THEN NULL;
  END;
  INSERT INTO h8_results VALUES ('T7 member_id is pinned to the invited address', 'PASS');
  v_passed := v_passed + 1;

  IF v_passed <> v_expected THEN
    RAISE EXCEPTION 'H8 FAIL: only % of % assertions passed', v_passed, v_expected;
  END IF;
  INSERT INTO h8_results VALUES ('TOTAL', format('%s / %s PASSED', v_passed, v_expected));
END;
$$;

SELECT * FROM h8_results;

ROLLBACK;
