-- B4: money-path test suite (DB side).
-- Run the whole file as ONE batch against the live project: every mutation
-- happens inside BEGIN..ROLLBACK, so nothing persists and the PM2 workers
-- never see the test rows (uncommitted rows are invisible to them).
-- A failed assertion aborts the batch with 'FAIL Tn: ...'; success returns
-- the final SELECT.
--
-- Fixtures assumed (kept from B1): test user a1-wallet-test@example.com
-- (e5a56433-6f75-41a3-96b9-19c62b9d1280) with a wallet and the
-- 'B1 test Vodafone EG' sim line; payment_gateways rows 'paypal' and 'wallet'.

BEGIN;

DO $$
DECLARE
  v_user uuid := 'e5a56433-6f75-41a3-96b9-19c62b9d1280';
  v_line uuid;
  v_exec public.topup_executions%ROWTYPE;
  v_bal_start numeric;
  v_bal numeric;
  v_txn uuid;
  v_gw record;
  v_expected_gateway_fee numeric;
  v_expected_amount numeric;
  v_drift numeric;
BEGIN
  SELECT id INTO v_line
  FROM public.sim_lines
  WHERE user_id = v_user AND nickname = 'B1 test Vodafone EG';
  IF v_line IS NULL THEN
    RAISE EXCEPTION 'SETUP: test sim line "B1 test Vodafone EG" not found';
  END IF;

  SELECT balance INTO v_bal_start FROM public.wallets WHERE user_id = v_user;
  IF v_bal_start IS NULL THEN
    RAISE EXCEPTION 'SETUP: test wallet not found';
  END IF;

  ------------------------------------------------------------------
  -- T1: calculate_topup_fees — percentage + fixed gateway fee + 5% app fee
  ------------------------------------------------------------------
  SELECT * INTO v_gw FROM public.payment_gateways WHERE code = 'paypal';
  v_expected_gateway_fee := ROUND(10.00 * (v_gw.fee_percentage / 100.0) + v_gw.fee_fixed, 2);
  v_expected_amount := ROUND(10.00 + v_expected_gateway_fee + ROUND(10.00 * 0.05, 2), 2);

  INSERT INTO public.topup_executions
    (user_id, sim_line_id, execution_type, amount, currency, status,
     execution_time, base_cost_usd, payment_gateway_code)
  VALUES
    (v_user, v_line, 'refill_custom', 1, 'USD', 'pending',
     now() + interval '10 years', 10.00, 'paypal')
  RETURNING * INTO v_exec;

  IF v_exec.gateway_fee_usd IS DISTINCT FROM v_expected_gateway_fee THEN
    RAISE EXCEPTION 'FAIL T1: paypal gateway fee % (expected %)',
      v_exec.gateway_fee_usd, v_expected_gateway_fee;
  END IF;
  IF v_exec.app_fee_usd IS DISTINCT FROM 0.50::numeric THEN
    RAISE EXCEPTION 'FAIL T1: app fee % (expected 0.50)', v_exec.app_fee_usd;
  END IF;
  IF v_exec.amount IS DISTINCT FROM v_expected_amount THEN
    RAISE EXCEPTION 'FAIL T1: total amount % (expected %)', v_exec.amount, v_expected_amount;
  END IF;

  ------------------------------------------------------------------
  -- T2: calculate_topup_fees — wallet gateway carries no gateway fee
  ------------------------------------------------------------------
  INSERT INTO public.topup_executions
    (user_id, sim_line_id, execution_type, amount, currency, status,
     execution_time, base_cost_usd, payment_gateway_code)
  VALUES
    (v_user, v_line, 'refill_custom', 1, 'USD', 'pending',
     now() + interval '10 years', 10.00, 'wallet')
  RETURNING * INTO v_exec;

  IF v_exec.gateway_fee_usd IS DISTINCT FROM 0.00::numeric THEN
    RAISE EXCEPTION 'FAIL T2: wallet gateway fee % (expected 0)', v_exec.gateway_fee_usd;
  END IF;
  IF v_exec.amount IS DISTINCT FROM 10.50::numeric THEN
    RAISE EXCEPTION 'FAIL T2: total amount % (expected 10.50)', v_exec.amount;
  END IF;

  ------------------------------------------------------------------
  -- T3: route_topup_execution — API carrier assigns gateway and bumps
  --     refill_instant from pending to routing
  ------------------------------------------------------------------
  INSERT INTO public.topup_executions
    (user_id, sim_line_id, execution_type, amount, currency, status, execution_time)
  VALUES
    (v_user, v_line, 'refill_instant', 0.50, 'USD', 'pending', now() + interval '10 years')
  RETURNING * INTO v_exec;

  IF v_exec.fulfillment_gateway IS DISTINCT FROM 'API' THEN
    RAISE EXCEPTION 'FAIL T3: fulfillment_gateway % (expected API)', v_exec.fulfillment_gateway;
  END IF;
  IF v_exec.api_provider IS DISTINCT FROM 'zendit' THEN
    RAISE EXCEPTION 'FAIL T3: api_provider % (expected zendit)', v_exec.api_provider;
  END IF;
  IF v_exec.status IS DISTINCT FROM 'routing' THEN
    RAISE EXCEPTION 'FAIL T3: instant status % (expected routing)', v_exec.status;
  END IF;

  ------------------------------------------------------------------
  -- T4: route_topup_execution — scheduled types stay pending
  ------------------------------------------------------------------
  INSERT INTO public.topup_executions
    (user_id, sim_line_id, execution_type, amount, currency, status, execution_time)
  VALUES
    (v_user, v_line, 'refill_mini', 0.20, 'USD', 'pending', now() + interval '10 years')
  RETURNING * INTO v_exec;

  IF v_exec.status IS DISTINCT FROM 'pending' THEN
    RAISE EXCEPTION 'FAIL T4: mini status % (expected pending)', v_exec.status;
  END IF;

  ------------------------------------------------------------------
  -- T5: debit_wallet_for_topup — atomic balance + ledger
  ------------------------------------------------------------------
  v_txn := public.debit_wallet_for_topup(v_user, v_line, 5.00, 'B4 T5 debit', 'b4test_exec_1');
  SELECT balance INTO v_bal FROM public.wallets WHERE user_id = v_user;
  IF v_bal IS DISTINCT FROM v_bal_start - 5.00 THEN
    RAISE EXCEPTION 'FAIL T5: balance % (expected %)', v_bal, v_bal_start - 5.00;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.wallet_transactions
    WHERE id = v_txn AND type = 'topup_debit' AND amount = 5.00
      AND reference_id = 'b4test_exec_1' AND status = 'completed'
  ) THEN
    RAISE EXCEPTION 'FAIL T5: ledger row missing or wrong';
  END IF;

  ------------------------------------------------------------------
  -- T6: duplicate debit reference is rejected and rolls back entirely
  ------------------------------------------------------------------
  BEGIN
    PERFORM public.debit_wallet_for_topup(v_user, v_line, 5.00, 'B4 T6 replay', 'b4test_exec_1');
    RAISE EXCEPTION 'FAIL T6: duplicate debit was accepted';
  EXCEPTION WHEN unique_violation THEN
    NULL; -- expected
  END;
  SELECT balance INTO v_bal FROM public.wallets WHERE user_id = v_user;
  IF v_bal IS DISTINCT FROM v_bal_start - 5.00 THEN
    RAISE EXCEPTION 'FAIL T6: balance changed on rejected debit (%)', v_bal;
  END IF;

  ------------------------------------------------------------------
  -- T7: overdraft is rejected
  ------------------------------------------------------------------
  BEGIN
    PERFORM public.debit_wallet_for_topup(v_user, v_line, 999999, 'B4 T7 overdraft', 'b4test_exec_overdraft');
    RAISE EXCEPTION 'FAIL T7: overdraft debit was accepted';
  EXCEPTION WHEN others THEN
    IF SQLERRM LIKE 'FAIL T7%' OR SQLERRM NOT LIKE '%Insufficient wallet balance%' THEN
      RAISE;
    END IF;
  END;

  ------------------------------------------------------------------
  -- T8: non-positive debit is rejected
  ------------------------------------------------------------------
  BEGIN
    PERFORM public.debit_wallet_for_topup(v_user, v_line, -1, 'B4 T8 negative', 'b4test_exec_negative');
    RAISE EXCEPTION 'FAIL T8: negative debit was accepted';
  EXCEPTION WHEN others THEN
    IF SQLERRM LIKE 'FAIL T8%' OR SQLERRM NOT LIKE '%must be positive%' THEN
      RAISE;
    END IF;
  END;

  ------------------------------------------------------------------
  -- T9: credit_wallet_for_refund — atomic, idempotent per reference
  ------------------------------------------------------------------
  v_txn := public.credit_wallet_for_refund(v_user, v_line, 5.00, 'B4 T9 refund', 'b4test_refund_1');
  SELECT balance INTO v_bal FROM public.wallets WHERE user_id = v_user;
  IF v_bal IS DISTINCT FROM v_bal_start THEN
    RAISE EXCEPTION 'FAIL T9: balance % after refund (expected %)', v_bal, v_bal_start;
  END IF;
  BEGIN
    PERFORM public.credit_wallet_for_refund(v_user, v_line, 5.00, 'B4 T9 replay', 'b4test_refund_1');
    RAISE EXCEPTION 'FAIL T9: duplicate refund was accepted';
  EXCEPTION WHEN unique_violation THEN
    NULL; -- expected
  END;

  ------------------------------------------------------------------
  -- T10: credit_wallet_for_deposit — receipt metadata + capture idempotency
  ------------------------------------------------------------------
  v_txn := public.credit_wallet_for_deposit(
    v_user, 3.33, 'B4 T10 deposit', 'paypal_B4TESTCAPTURE',
    '{"method":"paypal","gross":3.33,"paypal_fee":0.40,"net":2.93}'::jsonb);
  IF NOT EXISTS (
    SELECT 1 FROM public.wallet_transactions
    WHERE id = v_txn AND type = 'deposit'
      AND metadata->>'method' = 'paypal' AND (metadata->>'net')::numeric = 2.93
  ) THEN
    RAISE EXCEPTION 'FAIL T10: deposit receipt metadata missing';
  END IF;
  BEGIN
    PERFORM public.credit_wallet_for_deposit(v_user, 3.33, 'B4 T10 replay', 'paypal_B4TESTCAPTURE', NULL);
    RAISE EXCEPTION 'FAIL T10: duplicate capture deposit was accepted';
  EXCEPTION WHEN unique_violation THEN
    NULL; -- expected
  END;

  ------------------------------------------------------------------
  -- T11: ledger invariant — wallet reconciles to zero drift after all ops
  ------------------------------------------------------------------
  SELECT drift INTO v_drift FROM public.wallet_reconciliation WHERE user_id = v_user;
  IF v_drift IS DISTINCT FROM 0.00::numeric THEN
    RAISE EXCEPTION 'FAIL T11: reconciliation drift % (expected 0)', v_drift;
  END IF;

  RAISE NOTICE 'B4 money-path SQL tests: T1-T11 all passed';
END $$;

ROLLBACK;

SELECT 'B4 money-path SQL tests: T1-T11 all passed (rolled back)' AS result;
