-- C3: instant-recharge pricing and rate-limit tests.
--
-- Run live inside BEGIN..ROLLBACK (workers can't see uncommitted rows), so the
-- executions inserted here are never claimed or charged. Fixtures reference the
-- a1-wallet-test user (see doc/B1_B2_REFILL_MONEY_AUDIT.md).
--
-- Covers: the app fee coming from system_configs rather than a constant (this
-- is what stops the quote and the debit drifting apart again — they were 3% and
-- 5%), the config being changeable at runtime, a garbage config falling back
-- instead of breaking every refill, and the instant rate limiter actually
-- firing now that it matches 'refill_instant' instead of the 'instant' that
-- never existed.

BEGIN;

DO $$
DECLARE
  v_user uuid := 'e5a56433-6f75-41a3-96b9-19c62b9d1280';
  v_line uuid;
  v_amt  numeric;
  v_app  numeric;
  v_ok   boolean;
BEGIN
  SELECT id INTO v_line FROM public.sim_lines WHERE user_id = v_user LIMIT 1;

  -- 1) The configured 3% is what gets charged. A $5.00 base with the wallet
  --    gateway (0% + $0.00) must total $5.15, which is also what the sheet now
  --    quotes. Before C3 this row was written as $5.25 against a $5.15 quote.
  UPDATE public.system_configs SET config_value = '3' WHERE config_key = 'APP_FEE_PERCENT';
  INSERT INTO public.topup_executions
    (sim_line_id, user_id, amount, base_cost_usd, payment_gateway_code, currency, status, execution_type)
  VALUES (v_line, v_user, 5.00, 5.00, 'wallet', 'USD', 'routing', 'refill_instant')
  RETURNING amount, app_fee_usd INTO v_amt, v_app;
  IF v_amt <> 5.15 OR v_app <> 0.15 THEN
    RAISE EXCEPTION 'app fee 3%%: expected amount 5.15 / fee 0.15, got % / %', v_amt, v_app;
  END IF;

  -- 2) Changing the config changes the price with no redeploy — the whole point
  --    of moving the rate into the database.
  UPDATE public.system_configs SET config_value = '7' WHERE config_key = 'APP_FEE_PERCENT';
  INSERT INTO public.topup_executions
    (sim_line_id, user_id, amount, base_cost_usd, payment_gateway_code, currency, status, execution_type)
  VALUES (v_line, v_user, 5.00, 5.00, 'wallet', 'USD', 'routing', 'refill_mini')
  RETURNING amount, app_fee_usd INTO v_amt, v_app;
  IF v_amt <> 5.35 OR v_app <> 0.35 THEN
    RAISE EXCEPTION 'app fee 7%%: expected 5.35 / 0.35, got % / %', v_amt, v_app;
  END IF;

  -- 3) config_value is free text. A typo must not take refills down with it.
  UPDATE public.system_configs SET config_value = 'oops' WHERE config_key = 'APP_FEE_PERCENT';
  INSERT INTO public.topup_executions
    (sim_line_id, user_id, amount, base_cost_usd, payment_gateway_code, currency, status, execution_type)
  VALUES (v_line, v_user, 5.00, 5.00, 'wallet', 'USD', 'routing', 'refill_mini')
  RETURNING amount INTO v_amt;
  IF v_amt <> 5.15 THEN
    RAISE EXCEPTION 'garbage config should fall back to 3%%, got %', v_amt;
  END IF;

  -- 4) An out-of-range rate is refused the same way.
  UPDATE public.system_configs SET config_value = '900' WHERE config_key = 'APP_FEE_PERCENT';
  INSERT INTO public.topup_executions
    (sim_line_id, user_id, amount, base_cost_usd, payment_gateway_code, currency, status, execution_type)
  VALUES (v_line, v_user, 5.00, 5.00, 'wallet', 'USD', 'routing', 'refill_mini')
  RETURNING amount INTO v_amt;
  IF v_amt <> 5.15 THEN
    RAISE EXCEPTION 'out-of-range config should fall back to 3%%, got %', v_amt;
  END IF;

  UPDATE public.system_configs SET config_value = '3' WHERE config_key = 'APP_FEE_PERCENT';

  -- 5) THE RATE LIMIT: a second instant refill on the same line inside 10s is
  --    rejected. Test 1 already inserted one for this line.
  v_ok := false;
  BEGIN
    INSERT INTO public.topup_executions
      (sim_line_id, user_id, amount, base_cost_usd, payment_gateway_code, currency, status, execution_type)
    VALUES (v_line, v_user, 5.00, 5.00, 'wallet', 'USD', 'routing', 'refill_instant');
  EXCEPTION WHEN others THEN
    IF SQLERRM LIKE '%Rate limit exceeded%' THEN
      v_ok := true;
    ELSE
      RAISE;
    END IF;
  END;
  IF NOT v_ok THEN
    RAISE EXCEPTION 'rate limit did not fire on a second refill_instant within 10s';
  END IF;

  -- 6) The limiter must not touch the auto-refill workers: refill_mini is
  --    inserted on a schedule and several can legitimately land together.
  INSERT INTO public.topup_executions
    (sim_line_id, user_id, amount, base_cost_usd, payment_gateway_code, currency, status, execution_type)
  VALUES (v_line, v_user, 5.00, 5.00, 'wallet', 'USD', 'pending', 'refill_mini');
  INSERT INTO public.topup_executions
    (sim_line_id, user_id, amount, base_cost_usd, payment_gateway_code, currency, status, execution_type)
  VALUES (v_line, v_user, 5.00, 5.00, 'wallet', 'USD', 'pending', 'refill_mini');

  -- 7) A different line is throttled independently.
  IF (SELECT count(*) FROM public.sim_lines WHERE user_id = v_user) > 1 THEN
    INSERT INTO public.topup_executions
      (sim_line_id, user_id, amount, base_cost_usd, payment_gateway_code, currency, status, execution_type)
    SELECT id, v_user, 5.00, 5.00, 'wallet', 'USD', 'routing', 'refill_instant'
    FROM public.sim_lines WHERE user_id = v_user AND id <> v_line LIMIT 1;
  END IF;

  RAISE NOTICE 'C3 instant-recharge tests: all 7 assertions passed.';
END $$;

ROLLBACK;
