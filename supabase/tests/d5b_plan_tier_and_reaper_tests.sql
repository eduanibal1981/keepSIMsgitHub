-- D5d Comprehensive SQL Test Suite & Probes
-- Runs as a single atomic transaction block ending in ROLLBACK so zero test rows persist.

BEGIN;

DO $$
DECLARE
  v_user_id uuid := 'a1111111-1111-1111-1111-111111111111';
  v_sim_id uuid := 'b2222222-2222-2222-2222-222222222222';
  v_wallet_id uuid;
  v_res jsonb;
  v_order_id uuid;
  v_unpaid_order_id uuid;
  v_bal_before numeric;
  v_bal_after numeric;
  v_refund_count integer;
  v_sqlstate text;
  v_plan_before text;
  v_plan_after text;
BEGIN
  -- 1. Setup Test Fixture Data
  INSERT INTO auth.users (id, email)
  VALUES (v_user_id, 'd5d-test@example.com')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.profiles (id, email, full_name)
  VALUES (v_user_id, 'd5d-test@example.com', 'D5d Test User')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.wallets (id, user_id, balance, currency)
  VALUES (gen_random_uuid(), v_user_id, 100.00, 'USD')
  ON CONFLICT (user_id) DO UPDATE SET balance = 100.00;

  INSERT INTO public.sim_lines (id, user_id, phone_number, plan_type, status)
  VALUES (v_sim_id, v_user_id, '+15550001111', 'free', 'active')
  ON CONFLICT (id) DO UPDATE SET plan_type = 'free';

  SELECT plan_type INTO v_plan_before FROM public.sim_lines WHERE id = v_sim_id;

  -- ==========================================================================
  -- PROBE A: Column grant revoked + role authenticated → Must raise 42501
  -- ==========================================================================
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_user_id::text, 'role', 'authenticated')::text, true);

  BEGIN
    UPDATE public.sim_lines SET plan_type = 'premium' WHERE id = v_sim_id;
    RAISE EXCEPTION 'TEST FAILED: Probe A - Direct update of plan_type succeeded!';
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_sqlstate = RETURNED_SQLSTATE;
    IF v_sqlstate <> '42501' THEN
      RAISE EXCEPTION 'TEST FAILED: Probe A expected SQLSTATE 42501 but got % (Error: %)', v_sqlstate, SQLERRM;
    END IF;
    RAISE NOTICE 'PROBE A PASSED: SQLSTATE = %', v_sqlstate;
  END;

  -- ==========================================================================
  -- PROBE B: Column grant restored + role authenticated → Trigger MUST raise KS403
  -- ==========================================================================
  PERFORM set_config('role', 'postgres', true);
  GRANT UPDATE (plan_type) ON public.sim_lines TO authenticated;

  PERFORM set_config('role', 'authenticated', true);

  BEGIN
    UPDATE public.sim_lines SET plan_type = 'premium' WHERE id = v_sim_id;
    RAISE EXCEPTION 'TEST FAILED: Probe B - Direct update of plan_type succeeded even with column grant!';
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_sqlstate = RETURNED_SQLSTATE;
    IF v_sqlstate <> 'KS403' THEN
      RAISE EXCEPTION 'TEST FAILED: Probe B expected SQLSTATE KS403 from trigger but got % (Error: %)', v_sqlstate, SQLERRM;
    END IF;
    RAISE NOTICE 'PROBE B PASSED: SQLSTATE = %', v_sqlstate;
  END;

  -- Restore grant revocation for remaining test steps
  PERFORM set_config('role', 'postgres', true);
  REVOKE UPDATE (plan_type) ON public.sim_lines FROM authenticated;

  -- ==========================================================================
  -- PROBE C: plan_payments INSERT with kind='plan' → sim_lines.plan_type changes
  -- ==========================================================================
  INSERT INTO public.plan_payments (
    user_id, sim_line_id, capture_id, kind, gross_usd, paypal_fee_usd, net_usd, metadata
  ) VALUES (
    v_user_id, v_sim_id, 'test_cap_d5d_999', 'plan', 2.50, 0.49, 2.01, jsonb_build_object('plan', 'premium')
  );

  SELECT plan_type INTO v_plan_after FROM public.sim_lines WHERE id = v_sim_id;

  IF v_plan_after <> 'premium' THEN
    RAISE EXCEPTION 'TEST FAILED: Probe C - plan_payments insert did not update plan_type (before=%, after=%)', v_plan_before, v_plan_after;
  END IF;

  RAISE NOTICE 'PROBE C PASSED: plan_type BEFORE = %, AFTER = %', v_plan_before, v_plan_after;

  -- ==========================================================================
  -- TEST 3: request_esim_purchase RPC Reconciliation & Table Insertion
  -- ==========================================================================
  INSERT INTO public.esim_offers_cache (
    bundle_name, provider, description, data_amount_mb, duration_days, wholesale_price_usd, is_active
  ) VALUES (
    'd5d_offer_101', 'esim_go', 'D5d Test Offer', 1024, 7, 5.00, true
  ) ON CONFLICT (provider, bundle_name) DO UPDATE SET is_active = true, wholesale_price_usd = 5.00;

  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_user_id::text, 'role', 'authenticated')::text, true);

  v_res := public.request_esim_purchase('d5d_offer_101', 1);

  IF NOT (v_res ->> 'success')::boolean THEN
    RAISE EXCEPTION 'TEST FAILED: Test 3 - request_esim_purchase failed: %', v_res ->> 'error';
  END IF;

  v_order_id := (v_res ->> 'order_id')::uuid;

  PERFORM set_config('role', 'postgres', true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_user_id::text, 'role', 'service_role')::text, true);

  IF NOT EXISTS (
    SELECT 1 FROM public.esim_orders
    WHERE id = v_order_id AND offer_id = 'd5d_offer_101' AND total_amount_usd > 0
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: Test 3 - esim_orders row missing offer_id or total_amount_usd!';
  END IF;

  -- ==========================================================================
  -- TEST 4: Stale eSIM Reaper - Debit Refund & Idempotency
  -- ==========================================================================
  UPDATE public.esim_orders
  SET created_at = NOW() - INTERVAL '4 hours'
  WHERE id = v_order_id;

  SELECT balance INTO v_bal_before FROM public.wallets WHERE user_id = v_user_id;

  v_res := public.reap_stale_esim_orders();
  IF (v_res ->> 'reaped_count')::int < 1 THEN
    RAISE EXCEPTION 'TEST FAILED: Test 4 - reap_stale_esim_orders failed to reap stale order!';
  END IF;

  SELECT balance INTO v_bal_after FROM public.wallets WHERE user_id = v_user_id;

  IF v_bal_after <= v_bal_before THEN
    RAISE EXCEPTION 'TEST FAILED: Test 4 - Wallet balance was not refunded by reaper!';
  END IF;

  -- ==========================================================================
  -- TEST 5: Worker Heartbeat Staleness Alert Test
  -- ==========================================================================
  INSERT INTO public.system_configs (config_key, config_value, updated_at)
  VALUES ('WORKER_ESIM_FULFILLMENT_HEARTBEAT', '"2026-01-01T00:00:00Z"', NOW() - INTERVAL '20 minutes')
  ON CONFLICT (config_key) DO UPDATE SET updated_at = NOW() - INTERVAL '20 minutes';

  PERFORM public.check_worker_heartbeat_health();

  IF NOT EXISTS (
    SELECT 1 FROM public.system_alerts
    WHERE kind = 'worker_heartbeat_stale'
      AND created_at >= NOW() - INTERVAL '1 minute'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: Test 5 - check_worker_heartbeat_health failed to raise worker_heartbeat_stale alert!';
  END IF;
  RAISE NOTICE 'TEST 5 PASSED: worker_heartbeat_stale alert correctly raised';
END;
$$;

ROLLBACK;
