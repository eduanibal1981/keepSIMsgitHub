-- Test suite for C9b eSIM purchase pipeline and tables.
-- Run in transaction with ROLLBACK to ensure zero persistent side-effects.

BEGIN;

-- 1. Setup test fixture data
DO $$
DECLARE
  v_test_user_id UUID;
  v_order_id UUID;
  v_wallet_before NUMERIC;
  v_wallet_after NUMERIC;
  v_txn_count INT;
BEGIN
  -- Find test user a1-wallet-test@example.com
  SELECT id INTO v_test_user_id FROM auth.users WHERE email = 'a1-wallet-test@example.com';
  IF v_test_user_id IS NULL THEN
    RAISE EXCEPTION 'Test user a1-wallet-test@example.com not found.';
  END IF;

  -- Ensure a test offer exists in esim_offers_cache with recent updated_at
  INSERT INTO public.esim_offers_cache (
    provider, bundle_name, description, countries, roaming_enabled,
    data_amount_mb, duration_days, wholesale_price_usd, is_active, updated_at
  ) VALUES (
    'esim_go', 'test_bundle_1gb', '1 GB 7 Days Test Bundle',
    ARRAY['US'], ARRAY['US'], 1024, 7, 1.5000, TRUE, NOW()
  ) ON CONFLICT (provider, bundle_name) DO UPDATE
  SET wholesale_price_usd = 1.5000, is_active = TRUE, updated_at = NOW();

  -- Verify wallet balance before test
  SELECT balance INTO v_wallet_before FROM public.wallets WHERE user_id = v_test_user_id;

  -- Test A: request_esim_purchase with valid offer as authenticated test user
  -- Set auth context
  PERFORM set_config('request.jwt.claim.sub', v_test_user_id::TEXT, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);

  -- Execute RPC
  v_order_id := public.request_esim_purchase('esim_go_test_bundle_1gb', 1);

  IF v_order_id IS NULL THEN
    RAISE EXCEPTION 'Assertion failed: request_esim_purchase returned null order ID.';
  END IF;

  -- Verify order status is pending
  IF NOT EXISTS (SELECT 1 FROM public.esim_orders WHERE id = v_order_id AND status = 'pending' AND user_id = v_test_user_id) THEN
    RAISE EXCEPTION 'Assertion failed: Pending order row not created correctly.';
  END IF;

  -- Verify wallet debited by retail price (1.50 * 1.30 = 1.95)
  SELECT balance INTO v_wallet_after FROM public.wallets WHERE user_id = v_test_user_id;
  IF v_wallet_before - v_wallet_after != 1.95 THEN
    RAISE EXCEPTION 'Assertion failed: Wallet balance incorrect after debit. Expected -1.95, got %', (v_wallet_before - v_wallet_after);
  END IF;

  -- Verify idempotent debit ledger entry
  SELECT COUNT(*) INTO v_txn_count 
  FROM public.wallet_transactions 
  WHERE reference_id = 'esim_' || v_order_id::TEXT AND type = 'esim_purchase_debit';

  IF v_txn_count != 1 THEN
    RAISE EXCEPTION 'Assertion failed: Wallet transaction count expected 1, got %', v_txn_count;
  END IF;

  RAISE NOTICE 'C9b SQL Tests Passed Successfully!';
END;
$$;

ROLLBACK;
