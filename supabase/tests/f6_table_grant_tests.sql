-- F6 regression suite (doc/PRODUCTION_PLAN_REVIEW.md § F-6).
--
-- Two things are asserted, and the second matters as much as the first:
--   1. anon holds no write privilege on the five client-facing tables, and
--      authenticated holds only what the live RLS policies actually need.
--   2. THE APP STILL WORKS. A column lockdown already broke SIM line editing
--      once (D5c) because the client sent the full model to a column-scoped
--      UPDATE. Every real write path is exercised here for that reason.
--
-- Uses the existing a1 fixture only — creates no auth.users rows.
--
-- ============================================================================
-- HOW TO RUN — as ONE execute_sql call. MCP makes each call its own
-- transaction, so a split file never pairs BEGIN with ROLLBACK and the INSERTs
-- COMMIT. That is how test residue leaked into production three times here.
-- ============================================================================
-- Last run 2026-07-29: 12/12 PASSED.
-- ============================================================================

BEGIN;

CREATE TEMP TABLE f6(t text, outcome text) ON COMMIT DROP;
GRANT INSERT, SELECT ON f6 TO authenticated;

DO $$
DECLARE
  tbls text[] := ARRAY['profiles','sim_lines','scheduled_topups','esim_orders','user_esims'];
  t text; v_n int; v_passed int := 0; v_expected int := 4;
BEGIN
  -- T1: anon has no INSERT/UPDATE/DELETE/TRUNCATE anywhere. This is the headline.
  SELECT count(*) INTO v_n
  FROM information_schema.role_table_grants
  WHERE table_schema='public' AND table_name = ANY(tbls) AND grantee='anon'
    AND privilege_type IN ('INSERT','UPDATE','DELETE','TRUNCATE');
  IF v_n > 0 THEN RAISE EXCEPTION 'T1 FAIL: anon still holds % write grant(s)', v_n; END IF;
  INSERT INTO f6 VALUES ('T1 anon holds no INSERT/UPDATE/DELETE/TRUNCATE','PASS');
  v_passed := v_passed + 1;

  -- T2: nobody client-facing holds TRUNCATE. TRUNCATE is not RLS-filtered at
  --     all, so a grant here is unmediated data loss.
  SELECT count(*) INTO v_n
  FROM information_schema.role_table_grants
  WHERE table_schema='public' AND table_name = ANY(tbls)
    AND grantee IN ('anon','authenticated') AND privilege_type='TRUNCATE';
  IF v_n > 0 THEN RAISE EXCEPTION 'T2 FAIL: % TRUNCATE grant(s) survive', v_n; END IF;
  INSERT INTO f6 VALUES ('T2 no TRUNCATE for anon/authenticated','PASS'); v_passed := v_passed + 1;

  -- T3: esim_orders and user_esims have ONLY a SELECT policy, so any write grant
  --     to authenticated is dead surface that RLS alone is holding shut.
  SELECT count(*) INTO v_n
  FROM information_schema.role_table_grants
  WHERE table_schema='public' AND table_name IN ('esim_orders','user_esims')
    AND grantee='authenticated' AND privilege_type IN ('INSERT','UPDATE','DELETE');
  IF v_n > 0 THEN RAISE EXCEPTION 'T3 FAIL: authenticated holds % write grant(s) on esim_orders/user_esims', v_n; END IF;
  INSERT INTO f6 VALUES ('T3 esim_orders + user_esims are read-only for clients','PASS');
  v_passed := v_passed + 1;

  -- T4: the server-owned profiles columns are NOT in authenticated's column
  --     UPDATE grant. is_power_user is the privilege escalation vector (it syncs
  --     into auth.users.raw_app_meta_data and thence into the JWT);
  --     subscription_tier is entitlement; referral_* is set only by apply_referral.
  SELECT count(*) INTO v_n
  FROM information_schema.column_privileges
  WHERE table_schema='public' AND table_name='profiles' AND grantee='authenticated'
    AND privilege_type='UPDATE'
    AND column_name IN ('is_power_user','is_suspended','subscription_tier',
                        'referral_code','referred_by','id','email','created_at');
  IF v_n > 0 THEN RAISE EXCEPTION 'T4 FAIL: authenticated can UPDATE % server-owned profiles column(s)', v_n; END IF;
  INSERT INTO f6 VALUES ('T4 server-owned profiles columns are not client-writable','PASS');
  v_passed := v_passed + 1;

  IF v_passed <> v_expected THEN
    RAISE EXCEPTION 'F6 grants FAIL: only % of %', v_passed, v_expected;
  END IF;
END;
$$;

-- --------------------------------------------------------------------------
-- The app's real write paths, as a signed-in user. Failing any of these means
-- the lockdown went too far — the D5c failure mode.
-- --------------------------------------------------------------------------
SELECT set_config('request.jwt.claims',
  json_build_object('role','authenticated','sub','e5a56433-6f75-41a3-96b9-19c62b9d1280')::text, true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE
  v_uid  uuid := 'e5a56433-6f75-41a3-96b9-19c62b9d1280';
  v_line uuid := 'a918abf3-0bd8-45cf-8885-8a927846915f';
  v_new uuid; v_sched uuid;
BEGIN
  -- sim_lines_repository_impl.dart:171 updateSimLine -> SimLine.toClientWritableJson()
  UPDATE public.sim_lines SET phone_number=phone_number, nickname=nickname, avatar_icon=avatar_icon,
    status=status, country_id=country_id, carrier_id=carrier_id, carrier_rule_id=carrier_rule_id,
    household_id=household_id, is_home_mode=is_home_mode, protection_paused=protection_paused,
    requires_protection_at_home=requires_protection_at_home, updated_at=now()
  WHERE id = v_line;
  INSERT INTO f6 VALUES ('T5 updateSimLine','PASS');

  -- sim_lines_repository_impl.dart:147 addSimLine -> full toJson() INSERT
  INSERT INTO public.sim_lines (user_id, phone_number, nickname, avatar_icon, status, country_id,
    carrier_id, is_home_mode, protection_paused, requires_protection_at_home, plan_type)
  SELECT v_uid, '+99900011122', 'f6 test', avatar_icon, status, country_id, carrier_id,
    is_home_mode, protection_paused, requires_protection_at_home, 'standard'
  FROM public.sim_lines WHERE id = v_line RETURNING id INTO v_new;
  INSERT INTO f6 VALUES ('T6 addSimLine','PASS');

  -- scheduled_topup_repository.dart create + delete
  INSERT INTO public.scheduled_topups (user_id, sim_line_id, amount, currency, frequency_days,
    schedule_type, is_active, status, next_execution_at)
  VALUES (v_uid, v_new, 5.00, 'USD', 30, 'notify', true, 'active', now() + interval '30 days')
  RETURNING id INTO v_sched;
  INSERT INTO f6 VALUES ('T7 scheduled topup create','PASS');

  DELETE FROM public.scheduled_topups WHERE id = v_sched;
  INSERT INTO f6 VALUES ('T8 scheduled topup delete','PASS');

  DELETE FROM public.sim_lines WHERE id = v_new;
  INSERT INTO f6 VALUES ('T9 deleteSimLine','PASS');

  -- profile_repository.dart:44 updateProfile -> UserProfile.toClientWritableJson()
  UPDATE public.profiles SET full_name=full_name, avatar_url=avatar_url, phone=phone,
    home_country_code=home_country_code, last_country=last_country,
    preferred_currency=preferred_currency, onboarding_completed=onboarding_completed,
    updated_at=now()
  WHERE id = v_uid;
  INSERT INTO f6 VALUES ('T10 updateProfile (toClientWritableJson)','PASS');

  -- T11: the OLD full-model payload must now be refused. If this ever passes,
  --      someone re-granted the server-owned columns.
  BEGIN
    UPDATE public.profiles SET is_power_user=is_power_user, subscription_tier=subscription_tier,
      referred_by=referred_by, updated_at=now()
    WHERE id = v_uid;
    RAISE EXCEPTION 'T11 FAIL: the full-model profile UPDATE was accepted — server-owned columns are writable again';
  EXCEPTION WHEN insufficient_privilege THEN
    INSERT INTO f6 VALUES ('T11 old full-model updateProfile blocked 42501','PASS');
  END;

  -- T12: the escalation itself, at layer 1.
  BEGIN
    UPDATE public.profiles SET is_power_user = true WHERE id = v_uid;
    RAISE EXCEPTION 'T12 FAIL: a signed-in user just made themselves a power user';
  EXCEPTION WHEN insufficient_privilege THEN
    INSERT INTO f6 VALUES ('T12 self-escalation to power user blocked 42501','PASS');
  END;
END;
$$;

RESET ROLE;
SELECT set_config('request.jwt.claims','',true);

SELECT * FROM f6;

ROLLBACK;


-- ============================================================================
-- PART B — layer 2 (the trigger) proven on its own.
--
-- Restores the column grant layer 1 removed, so ONLY protect_is_power_user() can
-- stop the escalation. Run on its own; the ROLLBACK discards the grant.
--
-- EXPECT: is_power_user stays false, auth.users claim stays false, and the
--         privilege_escalation_attempt count goes UP by one.
-- Verified 2026-07-29: false / false / 0 -> 1.
--
-- Before migration 20260801090000 this same probe produced true / true / 0 —
-- the trigger was SECURITY DEFINER and keyed on current_user, which is the owner
-- ('postgres') for every caller, so it had never once fired.
-- ============================================================================
BEGIN;
GRANT UPDATE (is_power_user) ON public.profiles TO authenticated;

SELECT count(*) AS attempts_before FROM public.security_logs
WHERE event_type = 'privilege_escalation_attempt';

SELECT set_config('request.jwt.claims',
  json_build_object('role','authenticated','sub','e5a56433-6f75-41a3-96b9-19c62b9d1280')::text, true);
SET LOCAL ROLE authenticated;
UPDATE public.profiles SET is_power_user = true WHERE id='e5a56433-6f75-41a3-96b9-19c62b9d1280';
RESET ROLE;
SELECT set_config('request.jwt.claims','',true);

SELECT
  (SELECT is_power_user FROM public.profiles WHERE id='e5a56433-6f75-41a3-96b9-19c62b9d1280') AS still_false,
  (SELECT raw_app_meta_data->>'is_power_user' FROM auth.users WHERE id='e5a56433-6f75-41a3-96b9-19c62b9d1280') AS claim_untouched,
  (SELECT count(*) FROM public.security_logs WHERE event_type='privilege_escalation_attempt') AS attempts_after;
ROLLBACK;
