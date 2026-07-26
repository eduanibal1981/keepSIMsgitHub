-- D5b / D5c Comprehensive SQL Test Suite
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
BEGIN
  -- 1. Setup Test Fixture Data
  INSERT INTO auth.users (id, email)
  VALUES (v_user_id, 'd5c-test@example.com')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.profiles (id, email, full_name)
  VALUES (v_user_id, 'd5c-test@example.com', 'D5c Test User')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.wallets (id, user_id, balance, currency)
  VALUES (gen_random_uuid(), v_user_id, 100.00, 'USD')
  ON CONFLICT (user_id) DO UPDATE SET balance = 100.00;

  INSERT INTO public.sim_lines (id, user_id, phone_number, plan_type, status)
  VALUES (v_sim_id, v_user_id, '+15550001111', 'free', 'active')
  ON CONFLICT (id) DO UPDATE SET plan_type = 'free';

  -- TEST 1A: PROBE A - Role authenticated WITH jwt.claims MUST BE BLOCKED
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_user_id::text, 'role', 'authenticated')::text, true);

  BEGIN
    UPDATE public.sim_lines SET plan_type = 'premium' WHERE id = v_sim_id;
    RAISE EXCEPTION 'TEST FAILED: Probe A - authenticated user direct plan_type update succeeded!';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE '%TEST FAILED%' THEN
      RAISE EXCEPTION '%', SQLERRM;
    END IF;
  END;

  -- TEST 1B: PROBE B - Role authenticated WITHOUT jwt.claims MUST ALSO BE BLOCKED (FAIL-CLOSED)
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claims', '', true);

  BEGIN
    UPDATE public.sim_lines SET plan_type = 'premium' WHERE id = v_sim_id;
    RAISE EXCEPTION 'TEST FAILED: Probe B - authenticated user direct plan_type update without claims succeeded!';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE '%TEST FAILED%' THEN
      RAISE EXCEPTION '%', SQLERRM;
    END IF;
  END;

  -- Reset role to postgres
  PERFORM set_config('role', 'postgres', true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_user_id::text, 'role', 'service_role')::text, true);

  -- TEST 2: Legitimate Plan Payment Trigger Update
  INSERT INTO public.plan_payments (
    user_id, sim_line_id, capture_id, kind, gross_usd, paypal_fee_usd, net_usd, metadata
  ) VALUES (
    v_user_id, v_sim_id, 'test_cap_d5c_123', 'plan', 2.50, 0.49, 2.01, jsonb_build_object('plan', 'premium')
  );

  IF NOT EXISTS (
    SELECT 1 FROM public.sim_lines
    WHERE id = v_sim_id AND plan_type = 'premium' AND plan_expires_at > NOW()
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: Test 2 - Plan payment trigger failed to set plan_type to premium!';
  END IF;

  -- TEST 3: request_esim_purchase RPC Reconciliation & Table Insertion
  INSERT INTO public.esim_offers_cache (
    bundle_name, provider, description, data_amount_mb, duration_days, wholesale_price_usd, is_active
  ) VALUES (
    'd5c_offer_101', 'esim_go', 'D5c Test Offer', 1024, 7, 5.00, true
  ) ON CONFLICT (provider, bundle_name) DO UPDATE SET is_active = true, wholesale_price_usd = 5.00;

  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_user_id::text, 'role', 'authenticated')::text, true);

  v_res := public.request_esim_purchase('d5c_offer_101', 1);

  IF NOT (v_res ->> 'success')::boolean THEN
    RAISE EXCEPTION 'TEST FAILED: Test 3 - request_esim_purchase failed: %', v_res ->> 'error';
  END IF;

  v_order_id := (v_res ->> 'order_id')::uuid;

  PERFORM set_config('role', 'postgres', true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_user_id::text, 'role', 'service_role')::text, true);

  IF NOT EXISTS (
    SELECT 1 FROM public.esim_orders
    WHERE id = v_order_id AND offer_id = 'd5c_offer_101' AND total_amount_usd > 0
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: Test 3 - esim_orders row missing offer_id or total_amount_usd!';
  END IF;

  -- TEST 4: Stale eSIM Reaper - Debit Refund & Idempotency
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

  IF NOT EXISTS (
    SELECT 1 FROM public.wallet_transactions
    WHERE reference_id = 'esim_refund_' || v_order_id::text
      AND type = 'esim_purchase_refund'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: Test 4 - esim_purchase_refund transaction missing!';
  END IF;

  v_res := public.reap_stale_esim_orders();
  SELECT count(*) INTO v_refund_count
  FROM public.wallet_transactions
  WHERE reference_id = 'esim_refund_' || v_order_id::text
    AND type = 'esim_purchase_refund';

  IF v_refund_count <> 1 THEN
    RAISE EXCEPTION 'TEST FAILED: Test 4 - Double refund occurred! Refund count = %', v_refund_count;
  END IF;

  -- TEST 5: Stale eSIM Reaper - Unpaid Order Handling (No Completed Debit)
  INSERT INTO public.esim_orders (
    id, user_id, offer_id, bundle_name, provider, quantity, wholesale_price_usd, retail_price_usd, markup_percent, total_amount_usd, status, created_at
  ) VALUES (
    gen_random_uuid(), v_user_id, 'd5c_offer_101', 'D5c Test Unpaid', 'esim_go', 1, 5.00, 6.50, 30.0, 6.50, 'pending', NOW() - INTERVAL '5 hours'
  ) RETURNING id INTO v_unpaid_order_id;

  v_res := public.reap_stale_esim_orders();

  IF NOT EXISTS (
    SELECT 1 FROM public.esim_orders
    WHERE id = v_unpaid_order_id AND status = 'failed' AND error_message = 'stale_unpaid_order_reaped'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: Test 5 - Unpaid stale order status was not set to failed with stale_unpaid_order_reaped!';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.system_alerts
    WHERE kind = 'stale_esim_order_unpaid' AND (details ->> 'order_id')::uuid = v_unpaid_order_id
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: Test 5 - System alert stale_esim_order_unpaid was not logged!';
  END IF;
END;
$$;

ROLLBACK;
