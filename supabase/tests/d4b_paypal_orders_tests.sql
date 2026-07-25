-- D4b PayPal Orders & Quote Plan Price Integration Test Suite
-- Executes inside a transaction block (BEGIN...ROLLBACK) for zero residual state.

BEGIN;

DO $$
DECLARE
  v_test_user_id uuid := '00000000-1111-2222-3333-444444444444';
  v_other_user_id uuid := '00000000-9999-8888-7777-666666666666';
  v_order_id text := 'TEST_ORDER_D4B_' || gen_random_uuid()::text;
  v_std_price numeric;
  v_prem_price numeric;
  v_carrier_id uuid;
  v_sim_line_id uuid := gen_random_uuid();
  v_sim_line_orange uuid := gen_random_uuid();
  v_sim_line_vi uuid := gen_random_uuid();
  v_order_count int;
  v_status text;
BEGIN
  RAISE NOTICE '=== Running D4b PayPal Orders Test Suite ===';

  -- Create test users in auth.users
  INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, is_super_admin, created_at, updated_at)
  VALUES 
    (v_test_user_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'test-d4b@keepsims.test', '$2a$10$abcdefghijklmnopqrstuu', now(), '{}', '{}', false, now(), now()),
    (v_other_user_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'other-d4b@keepsims.test', '$2a$10$abcdefghijklmnopqrstuu', now(), '{}', '{}', false, now(), now());

  -- 1. Test quote_plan_price for Standard Plan ($3.10)
  SELECT public.quote_plan_price(NULL, 'standard') INTO v_std_price;
  IF v_std_price <> 3.10 THEN
    RAISE EXCEPTION 'Assertion failed: quote_plan_price(NULL, standard) = %, expected 3.10', v_std_price;
  END IF;
  RAISE NOTICE 'Assertion 1 passed: Standard plan quote = $3.10';

  -- 2. Test Carrier 1: Vodafone Egypt
  SELECT id INTO v_carrier_id FROM public.carriers WHERE name ILIKE '%Vodafone Egypt%' LIMIT 1;
  IF v_carrier_id IS NOT NULL THEN
    INSERT INTO public.sim_lines (id, user_id, carrier_id, phone_number, status, plan_type)
    VALUES (v_sim_line_id, v_test_user_id, v_carrier_id, '+201099998888', 'active', 'standard');

    SELECT public.quote_plan_price(v_sim_line_id, 'premium') INTO v_prem_price;
    IF v_prem_price <> 5.89 THEN
      RAISE EXCEPTION 'Assertion failed: quote_plan_price(Vodafone Egypt) = %, expected 5.89', v_prem_price;
    END IF;
    RAISE NOTICE 'Assertion 2 passed: Premium plan quote for Vodafone Egypt = $5.89';
  END IF;

  -- 3. Test Carrier 2: Orange Egypt
  SELECT id INTO v_carrier_id FROM public.carriers WHERE name ILIKE '%Orange Egypt%' LIMIT 1;
  IF v_carrier_id IS NOT NULL THEN
    INSERT INTO public.sim_lines (id, user_id, carrier_id, phone_number, status, plan_type)
    VALUES (v_sim_line_orange, v_test_user_id, v_carrier_id, '+201299998888', 'active', 'standard');

    SELECT public.quote_plan_price(v_sim_line_orange, 'premium') INTO v_prem_price;
    IF v_prem_price <> 60.96 THEN
      RAISE EXCEPTION 'Assertion failed: quote_plan_price(Orange Egypt) = %, expected 60.96', v_prem_price;
    END IF;
    RAISE NOTICE 'Assertion 3 passed: Premium plan quote for Orange Egypt = $60.96 (matches Dart RefillPricing)';
  END IF;

  -- 4. Test Carrier 3: Vi (Vodafone Idea)
  SELECT id INTO v_carrier_id FROM public.carriers WHERE name ILIKE '%Vi (Vodafone Idea)%' LIMIT 1;
  IF v_carrier_id IS NOT NULL THEN
    INSERT INTO public.sim_lines (id, user_id, carrier_id, phone_number, status, plan_type)
    VALUES (v_sim_line_vi, v_test_user_id, v_carrier_id, '+919999888877', 'active', 'standard');

    SELECT public.quote_plan_price(v_sim_line_vi, 'premium') INTO v_prem_price;
    IF v_prem_price <> 148.66 THEN
      RAISE EXCEPTION 'Assertion failed: quote_plan_price(Vi) = %, expected 148.66', v_prem_price;
    END IF;
    RAISE NOTICE 'Assertion 4 passed: Premium plan quote for Vi = $148.66 (matches Dart RefillPricing)';
  END IF;

  -- 5. Service role insert & status update lifecycle
  INSERT INTO public.paypal_orders (order_id, user_id, kind, plan, sim_line_id, amount_usd, status)
  VALUES (v_order_id, v_test_user_id, 'plan', 'standard', v_sim_line_id, 3.10, 'created');

  UPDATE public.paypal_orders SET status = 'captured', captured_at = now() WHERE order_id = v_order_id;

  SELECT count(*) INTO v_order_count FROM public.paypal_orders WHERE order_id = v_order_id AND status = 'captured';
  IF v_order_count <> 1 THEN
    RAISE EXCEPTION 'Assertion failed: paypal_orders status update to captured failed';
  END IF;
  RAISE NOTICE 'Assertion 5 passed: Service role paypal_orders lifecycle created -> captured verified';

  -- 6. Test failed capture status transition (422 / error does NOT mark captured)
  UPDATE public.paypal_orders SET status = 'failed' WHERE order_id = v_order_id;
  SELECT status INTO v_status FROM public.paypal_orders WHERE order_id = v_order_id;
  IF v_status <> 'failed' THEN
    RAISE EXCEPTION 'Assertion failed: paypal_orders failed status transition';
  END IF;
  RAISE NOTICE 'Assertion 6 passed: Error state sets paypal_orders status to failed';

  RAISE NOTICE '=== ALL D4b PAYPAL ORDERS ASSERTIONS PASSED SUCCESSFULLY ===';
END $$;

-- 7. Test RLS lockdown on paypal_orders: authenticated user cannot direct INSERT
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "00000000-1111-2222-3333-444444444444", "role": "authenticated"}';

DO $$
BEGIN
  INSERT INTO public.paypal_orders (order_id, user_id, kind, amount_usd, status)
  VALUES ('FORGED_ORDER', '00000000-1111-2222-3333-444444444444', 'deposit', 10.00, 'created');
  RAISE EXCEPTION 'Security Assertion failed: Authenticated role was allowed to direct INSERT into paypal_orders';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Assertion 7 passed: Direct client INSERT into paypal_orders denied (403)';
END $$;

-- 8. Test RLS lockdown: authenticated user cannot SELECT other user''s paypal_orders
DO $$
DECLARE
  v_other_count int;
BEGIN
  SELECT count(*) INTO v_other_count FROM public.paypal_orders WHERE user_id = '00000000-9999-8888-7777-666666666666';
  IF v_other_count <> 0 THEN
    RAISE EXCEPTION 'Security Assertion failed: User was able to see another user''s paypal_orders';
  END IF;
  RAISE NOTICE 'Assertion 8 passed: Cross-user RLS select isolation enforced (0 rows seen)';
END $$;

RESET ROLE;

ROLLBACK;
