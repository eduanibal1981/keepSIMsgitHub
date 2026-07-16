-- C1: notification dispatch DB-event wiring tests.
--
-- Run live inside BEGIN..ROLLBACK (workers can't see uncommitted rows); the
-- dispatch pg_net POSTs enqueued by trg_fn_dispatch_notification are discarded
-- on rollback, so nothing is actually delivered. Fixtures reference the
-- a1-wallet-test user (see doc/B1_B2_REFILL_MONEY_AUDIT.md).
--
-- Covers: refill success/failure notifications, the no-duplicate guard on an
-- unchanged status update, wallet-credit on deposit (and NOT on debit), and
-- system_alert fan-out to power users.

BEGIN;

DO $$
DECLARE
  v_user   uuid := 'e5a56433-6f75-41a3-96b9-19c62b9d1280';
  v_wallet uuid := '5451866e-6b29-4943-8b2f-f98ae4c5baa3';
  v_topup  uuid := '4de7f7a7-e78d-4cdc-8e10-1ed6903b9ad9';
  v_count  int;
  v_before int;
  v_power  int;
BEGIN
  -- 1) Refill failure: flipping an execution to 'failed' notifies the owner.
  SELECT count(*) INTO v_before FROM public.notifications
   WHERE user_id = v_user AND category = 'top_up_failed';
  UPDATE public.topup_executions SET status = 'failed' WHERE id = v_topup;
  SELECT count(*) INTO v_count FROM public.notifications
   WHERE user_id = v_user AND category = 'top_up_failed';
  IF v_count <> v_before + 1 THEN
    RAISE EXCEPTION 'refill-failure notification not created (before % after %)', v_before, v_count;
  END IF;

  -- 2) Refill success: flipping to 'success' notifies the owner.
  SELECT count(*) INTO v_before FROM public.notifications
   WHERE user_id = v_user AND category = 'top_up_success';
  UPDATE public.topup_executions SET status = 'success' WHERE id = v_topup;
  SELECT count(*) INTO v_count FROM public.notifications
   WHERE user_id = v_user AND category = 'top_up_success';
  IF v_count <> v_before + 1 THEN
    RAISE EXCEPTION 'refill-success notification not created (before % after %)', v_before, v_count;
  END IF;

  -- 3) A no-op status update must NOT create a duplicate notification.
  SELECT count(*) INTO v_before FROM public.notifications
   WHERE user_id = v_user AND category = 'top_up_success';
  UPDATE public.topup_executions SET status = 'success' WHERE id = v_topup;
  SELECT count(*) INTO v_count FROM public.notifications
   WHERE user_id = v_user AND category = 'top_up_success';
  IF v_count <> v_before THEN
    RAISE EXCEPTION 'unchanged-status update wrongly created a notification';
  END IF;

  -- 4) Wallet deposit creates a wallet_credit notification.
  SELECT count(*) INTO v_before FROM public.notifications
   WHERE user_id = v_user AND category = 'wallet_credit';
  INSERT INTO public.wallet_transactions
    (wallet_id, user_id, type, amount, balance_before, balance_after, description, reference_id)
  VALUES (v_wallet, v_user, 'deposit', 5.00, 0, 5.00, 'C1 test deposit', 'c1_test_' || gen_random_uuid());
  SELECT count(*) INTO v_count FROM public.notifications
   WHERE user_id = v_user AND category = 'wallet_credit';
  IF v_count <> v_before + 1 THEN
    RAISE EXCEPTION 'wallet-credit notification not created (before % after %)', v_before, v_count;
  END IF;

  -- 5) A debit must NOT create a wallet_credit notification.
  SELECT count(*) INTO v_before FROM public.notifications
   WHERE user_id = v_user AND category = 'wallet_credit';
  -- Debits are stored as positive amounts (see wallet_transactions_amount_positive),
  -- distinguished by type; only 'deposit' should notify.
  INSERT INTO public.wallet_transactions
    (wallet_id, user_id, type, amount, balance_before, balance_after, description, reference_id)
  VALUES (v_wallet, v_user, 'topup_debit', 1.00, 5.00, 4.00, 'C1 test debit', 'c1_testd_' || gen_random_uuid());
  SELECT count(*) INTO v_count FROM public.notifications
   WHERE user_id = v_user AND category = 'wallet_credit';
  IF v_count <> v_before THEN
    RAISE EXCEPTION 'debit wrongly created a wallet_credit notification';
  END IF;

  -- 6) system_alert notifies every power user.
  SELECT count(*) INTO v_power FROM public.profiles WHERE is_power_user;
  INSERT INTO public.system_alerts (kind, message) VALUES ('c1_test', 'C1 test alert');
  SELECT count(*) INTO v_count FROM public.notifications
   WHERE category = 'system' AND title = 'System alert: c1_test';
  IF v_count <> v_power THEN
    RAISE EXCEPTION 'system_alert notified % of % power users', v_count, v_power;
  END IF;

  RAISE NOTICE 'C1 notification-dispatch tests: all 6 assertions passed.';
END $$;

ROLLBACK;
