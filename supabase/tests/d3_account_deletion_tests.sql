-- Test Suite: d3_account_deletion_tests.sql
-- Purpose: Verify D3 Account Deletion state machine, drain checks, ledger anonymisation, C5 referral points fix, and export RPC.

BEGIN;

-- 1. Create test profiles: Referrer A and Referred Friend B
INSERT INTO auth.users (id, email) VALUES
  ('d3000000-0000-0000-0000-000000000001', 'referrer-a@example.com'),
  ('d3000000-0000-0000-0000-000000000002', 'referred-b@example.com')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, email, full_name, referral_code, referred_by) VALUES
  ('d3000000-0000-0000-0000-000000000001', 'referrer-a@example.com', 'Referrer A', 'REFA123', NULL),
  ('d3000000-0000-0000-0000-000000000002', 'referred-b@example.com', 'Referred B', 'REFB456', 'REFA123')
ON CONFLICT (id) DO NOTHING;

-- Seed wallet for Referred B with $0.50 (dust)
INSERT INTO public.wallets (id, user_id, balance) VALUES
  ('d3000000-0000-0000-0000-000000000010', 'd3000000-0000-0000-0000-000000000002', 0.50)
ON CONFLICT (id) DO NOTHING;

-- Seed referral points: Referrer A earned 1 point from Referred B's line
INSERT INTO public.referrals (id, referrer_id, referred_user_id, code) VALUES
  ('d3000000-0000-0000-0000-000000000020', 'd3000000-0000-0000-0000-000000000001', 'd3000000-0000-0000-0000-000000000002', 'REFA123')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.referral_points (id, referrer_id, referred_user_id, points, source) VALUES
  ('d3000000-0000-0000-0000-000000000030', 'd3000000-0000-0000-0000-000000000001', 'd3000000-0000-0000-0000-000000000002', 1, 'test')
ON CONFLICT (id) DO NOTHING;

-- Assert 1: Test request_account_deletion with dust forfeit for Referred B
DO $$
DECLARE
  v_res jsonb;
BEGIN
  -- Set auth context to Referred B
  PERFORM set_config('request.jwt.claim.sub', 'd3000000-0000-0000-0000-000000000002', true);

  v_res := public.request_account_deletion('Moving to another service', true);
  IF v_res->>'success' <> 'true' OR v_res->>'status' <> 'requested' THEN
    RAISE EXCEPTION 'Test 1 Failed: request_account_deletion did not return requested status: %', v_res;
  END IF;
END $$;

-- Assert 2: Verify account_deletions row and profile suspension
DO $$
DECLARE
  v_rec RECORD;
  v_suspended boolean;
BEGIN
  SELECT * INTO v_rec FROM public.account_deletions WHERE user_id = 'd3000000-0000-0000-0000-000000000002';
  IF v_rec.id IS NULL OR v_rec.status <> 'requested' THEN
    RAISE EXCEPTION 'Test 2 Failed: account_deletions row missing or wrong status';
  END IF;

  SELECT is_suspended INTO v_suspended FROM public.profiles WHERE id = 'd3000000-0000-0000-0000-000000000002';
  IF v_suspended IS NOT TRUE THEN
    RAISE EXCEPTION 'Test 2 Failed: Profile is_suspended is not true';
  END IF;
END $$;

-- Assert 3: Test cancel_account_deletion
DO $$
DECLARE
  v_res jsonb;
  v_suspended boolean;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', 'd3000000-0000-0000-0000-000000000002', true);

  v_res := public.cancel_account_deletion();
  IF v_res->>'success' <> 'true' THEN
    RAISE EXCEPTION 'Test 3 Failed: cancel_account_deletion failed: %', v_res;
  END IF;

  SELECT is_suspended INTO v_suspended FROM public.profiles WHERE id = 'd3000000-0000-0000-0000-000000000002';
  IF v_suspended IS NOT FALSE THEN
    RAISE EXCEPTION 'Test 3 Failed: Profile is_suspended was not restored to false';
  END IF;
END $$;

-- Assert 4: Test blocked balance policy when balance >= $1.00 and forfeit_dust = false
DO $$
DECLARE
  v_res jsonb;
BEGIN
  -- Set balance to $5.00
  UPDATE public.wallets SET balance = 5.00 WHERE user_id = 'd3000000-0000-0000-0000-000000000002';
  DELETE FROM public.account_deletions WHERE user_id = 'd3000000-0000-0000-0000-000000000002';

  PERFORM set_config('request.jwt.claim.sub', 'd3000000-0000-0000-0000-000000000002', true);
  v_res := public.request_account_deletion('Test block', false);

  IF v_res->>'success' <> 'false' OR v_res->>'code' <> 'WALLET_BALANCE_EXCEEDS_DUST_LIMIT' THEN
    RAISE EXCEPTION 'Test 4 Failed: Expected WALLET_BALANCE_EXCEEDS_DUST_LIMIT but got %', v_res;
  END IF;
END $$;

-- Assert 5: Test drain safety (purge_deleted_accounts refuses while execution is routing)
DO $$
DECLARE
  v_sim_id uuid := gen_random_uuid();
  v_res jsonb;
  v_status text;
BEGIN
  -- Reset balance back to $0.50
  UPDATE public.wallets SET balance = 0.50 WHERE user_id = 'd3000000-0000-0000-0000-000000000002';
  DELETE FROM public.account_deletions WHERE user_id = 'd3000000-0000-0000-0000-000000000002';

  PERFORM set_config('request.jwt.claim.sub', 'd3000000-0000-0000-0000-000000000002', true);
  PERFORM public.request_account_deletion('Moving to another service', true);

  -- Force scheduled_purge_at to past so purge worker evaluates it
  UPDATE public.account_deletions
  SET scheduled_purge_at = clock_timestamp() - INTERVAL '1 hour'
  WHERE user_id = 'd3000000-0000-0000-0000-000000000002';

  -- Create a SIM line and an in-flight 'routing' topup execution
  INSERT INTO public.sim_lines (id, user_id, phone_number, status)
  VALUES (v_sim_id, 'd3000000-0000-0000-0000-000000000002', '+15550001', 'active');

  INSERT INTO public.topup_executions (id, user_id, sim_line_id, status, amount)
  VALUES (gen_random_uuid(), 'd3000000-0000-0000-0000-000000000002', v_sim_id, 'routing', 2.50);

  -- Run purge worker
  v_res := public.purge_deleted_accounts();

  -- Verify status stayed in frozen / draining and was NOT purged
  SELECT status INTO v_status FROM public.account_deletions WHERE user_id = 'd3000000-0000-0000-0000-000000000002';
  IF v_status = 'purged' THEN
    RAISE EXCEPTION 'Test 5 Failed: Account was purged while a routing topup_execution existed!';
  END IF;
END $$;

-- Assert 6: Test full purge & anonymisation (and C5 referral points fix)
DO $$
DECLARE
  v_res jsonb;
  v_status text;
  v_points_balance int;
  v_wallet_user_id uuid;
BEGIN
  -- Mark topup execution as completed so drain passes
  UPDATE public.topup_executions
  SET status = 'success'
  WHERE user_id = 'd3000000-0000-0000-0000-000000000002';

  -- Run purge worker
  v_res := public.purge_deleted_accounts();

  SELECT status INTO v_status FROM public.account_deletions WHERE user_id = 'd3000000-0000-0000-0000-000000000002';
  IF v_status <> 'purged' THEN
    RAISE EXCEPTION 'Test 6 Failed: Expected purged status but got %', v_status;
  END IF;

  -- Verify wallet row was ANONYMISED (user_id SET NULL) rather than deleted
  SELECT user_id INTO v_wallet_user_id
  FROM public.wallets
  WHERE id = 'd3000000-0000-0000-0000-00000000010';

  IF v_wallet_user_id IS NOT NULL THEN
    RAISE EXCEPTION 'Test 6 Failed: Wallet user_id was not anonymised to NULL';
  END IF;

  -- Verify Referrer A's points balance is STILL 1 (not negative or broken by Referred B's deletion)
  SELECT COALESCE(SUM(points), 0) INTO v_points_balance
  FROM public.referral_points
  WHERE referrer_id = 'd3000000-0000-0000-0000-000000000001';

  IF v_points_balance <> 1 THEN
    RAISE EXCEPTION 'Test 6 Failed: Referrer A points balance changed to % after Referred B deletion!', v_points_balance;
  END IF;
END $$;

-- Assert 7: Test export_user_data RPC
DO $$
DECLARE
  v_export jsonb;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', 'd3000000-0000-0000-0000-000000000001', true);

  v_export := public.export_user_data();
  IF v_export->>'user_id' <> 'd3000000-0000-0000-0000-000000000001' OR v_export->'profile' IS NULL THEN
    RAISE EXCEPTION 'Test 7 Failed: export_user_data returned invalid payload: %', v_export;
  END IF;
END $$;

ROLLBACK;
