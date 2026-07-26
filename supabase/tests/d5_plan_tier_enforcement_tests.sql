-- SQL Test Suite: d5_plan_tier_enforcement_tests.sql
-- Runs in a transaction block (BEGIN...ROLLBACK) so zero data persists.

BEGIN;

-- Setup test user
INSERT INTO auth.users (id, email, role, instance_id, aud)
VALUES ('d5000000-0000-0000-0000-000000000001', 'd5-test@example.com', 'authenticated', '00000000-0000-0000-0000-000000000000', 'authenticated')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, email, full_name)
VALUES ('d5000000-0000-0000-0000-000000000001', 'd5-test@example.com', 'D5 Test User')
ON CONFLICT (id) DO NOTHING;

-- Setup test SIM line
INSERT INTO public.sim_lines (id, user_id, phone_number, plan_type, status)
VALUES (
  'd5100000-0000-0000-0000-000000000001',
  'd5000000-0000-0000-0000-000000000001',
  '+96890000055',
  'standard',
  'active'
)
ON CONFLICT (id) DO NOTHING;

-- TEST 1: Insert plan_payments for premium plan -> sim_lines.plan_type automatically updates to 'premium'
INSERT INTO public.plan_payments (
  id,
  user_id,
  sim_line_id,
  order_id,
  capture_id,
  kind,
  gross_usd,
  metadata
) VALUES (
  gen_random_uuid(),
  'd5000000-0000-0000-0000-000000000001',
  'd5100000-0000-0000-0000-000000000001',
  'TEST_ORDER_D5',
  'TEST_CAP_D5',
  'plan',
  5.00,
  '{"plan": "premium", "period": "monthly"}'::jsonb
);

DO $$
DECLARE
  v_plan text;
BEGIN
  SELECT plan_type INTO v_plan
  FROM public.sim_lines
  WHERE id = 'd5100000-0000-0000-0000-000000000001';

  IF v_plan <> 'premium' THEN
    RAISE EXCEPTION 'TEST 1 FAILED: Expected plan_type = premium, got %', v_plan;
  END IF;
END;
$$;

-- TEST 2: Stale pending eSIM Order Reaper
-- 1. Create wallet for user with $10 balance
INSERT INTO public.wallets (user_id, balance)
VALUES ('d5000000-0000-0000-0000-000000000001', 10.00)
ON CONFLICT (user_id) DO UPDATE SET balance = 10.00;

-- 2. Insert stale pending esim_order (created 2 hours ago)
INSERT INTO public.esim_orders (
  id,
  user_id,
  provider,
  bundle_name,
  quantity,
  wholesale_price_usd,
  retail_price_usd,
  markup_percent,
  status,
  created_at
) VALUES (
  'd5200000-0000-0000-0000-000000000001',
  'd5000000-0000-0000-0000-000000000001',
  'esim_go',
  'offer_test_d5',
  1,
  2.00,
  3.00,
  50.00,
  'pending',
  NOW() - INTERVAL '2 hours'
);

-- 3. Execute reap_stale_esim_orders()
DO $$
DECLARE
  v_res jsonb;
  v_status text;
  v_balance numeric;
  v_alert_count integer;
BEGIN
  v_res := public.reap_stale_esim_orders();
  
  IF (v_res->>'reaped_count')::int < 1 THEN
    RAISE EXCEPTION 'TEST 2 FAILED: Expected at least 1 order reaped, got %', v_res;
  END IF;

  SELECT status INTO v_status
  FROM public.esim_orders
  WHERE id = 'd5200000-0000-0000-0000-000000000001';

  IF v_status <> 'failed' THEN
    RAISE EXCEPTION 'TEST 2 FAILED: Order status not updated to failed, got %', v_status;
  END IF;

  SELECT balance INTO v_balance
  FROM public.wallets
  WHERE user_id = 'd5000000-0000-0000-0000-000000000001';

  IF v_balance <> 13.00 THEN
    RAISE EXCEPTION 'TEST 2 FAILED: Wallet not refunded correctly, expected 13.00, got %', v_balance;
  END IF;

  SELECT count(*) INTO v_alert_count
  FROM public.system_alerts
  WHERE kind = 'stale_esim_order_reaped'
    AND details->>'order_id' = 'd5200000-0000-0000-0000-000000000001';

  IF v_alert_count < 1 THEN
    RAISE EXCEPTION 'TEST 2 FAILED: System alert not created for reaped order';
  END IF;
END;
$$;

ROLLBACK;

SELECT 'ALL D5 TESTS PASSED' AS result;
