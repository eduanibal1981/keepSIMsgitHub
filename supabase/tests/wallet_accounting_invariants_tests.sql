-- ============================================================================
-- Test Suite: wallet_accounting_invariants_tests.sql
-- Description: Verifies wallet holds, funding lots, zero-wallet initialization,
--              and refund quote/reservation invariants. All fixtures are rolled back.
-- ============================================================================

BEGIN;

CREATE TEMP TABLE wallet_test_results(test_name TEXT, outcome TEXT) ON COMMIT DROP;

DO $$
DECLARE
  v_test_user_id UUID := gen_random_uuid();
  v_wallet_json JSONB;
  v_wallet_id UUID;
  v_summary JSONB;
  v_hold_id UUID;
  v_txn_id UUID;
  v_refund_res JSONB;
  v_passed INTEGER := 0;
BEGIN
  -- Insert isolated test user into auth.users (will be rolled back)
  INSERT INTO auth.users (
    id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at
  ) VALUES (
    v_test_user_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
    'test_wallet_' || substr(v_test_user_id::text, 1, 8) || '@keepsims.test',
    'unused_hash', now(), now(), now()
  );

  -- 1. Test ensure_wallet_v2 creates zero wallet
  v_wallet_json := public.ensure_wallet_v2(v_test_user_id);
  v_wallet_id := (v_wallet_json->>'id')::UUID;
  
  IF (v_wallet_json->>'balance')::NUMERIC != 0.00 THEN
    RAISE EXCEPTION 'Test failed: new wallet must have 0.00 balance, got %', v_wallet_json->>'balance';
  END IF;

  -- Verify no fake welcome credit rows exist
  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE user_id = v_test_user_id) THEN
    RAISE EXCEPTION 'Test failed: new wallet should not have sample transactions';
  END IF;
  INSERT INTO wallet_test_results VALUES ('1. ensure_wallet_v2 zero-balance creation', 'PASS');
  v_passed := v_passed + 1;

  -- 2. Deposit test funds ($20 paid deposit)
  PERFORM public.credit_wallet_for_deposit(
    v_test_user_id,
    20.00,
    'Test PayPal deposit',
    'paypal_test_cap_' || substr(v_test_user_id::text, 1, 8),
    jsonb_build_object('paypal_capture_id', 'test_cap_' || substr(v_test_user_id::text, 1, 8), 'order_id', 'test_order_123')
  );

  -- Promotional funding uses the actual ledger/lot transaction path.
  PERFORM public.credit_wallet_for_deposit(v_test_user_id,5,'referral_credit','refredeem_'||v_test_user_id);

  -- 3. Verify get_wallet_summary
  v_summary := public.get_wallet_summary(v_test_user_id);
  IF (v_summary->>'posted_balance')::NUMERIC != 25.00 THEN
    RAISE EXCEPTION 'Test failed: posted_balance should be 25.00, got %', v_summary->>'posted_balance';
  END IF;
  IF (v_summary->>'refundable_balance')::NUMERIC != 20.00 THEN
    RAISE EXCEPTION 'Test failed: refundable_balance should be 20.00 (excluding $5 promo), got %', v_summary->>'refundable_balance';
  END IF;
  INSERT INTO wallet_test_results VALUES ('2. get_wallet_summary separate paid & promotional', 'PASS');
  v_passed := v_passed + 1;

  -- 4. Test reserve_wallet_funds (Hold $12.00)
  v_hold_id := public.reserve_wallet_funds(
    v_test_user_id,
    12.00,
    'refill_instant',
    'test_exec_' || substr(v_test_user_id::text, 1, 8),
    'Instant refill test hold'
  );

  -- Re-check summary: held = 12.00, available = 13.00
  v_summary := public.get_wallet_summary(v_test_user_id);
  IF (v_summary->>'held_amount')::NUMERIC != 12.00 THEN
    RAISE EXCEPTION 'Test failed: held_amount should be 12.00, got %', v_summary->>'held_amount';
  END IF;
  IF (v_summary->>'available_balance')::NUMERIC != 13.00 THEN
    RAISE EXCEPTION 'Test failed: available_balance should be 13.00, got %', v_summary->>'available_balance';
  END IF;
  INSERT INTO wallet_test_results VALUES ('3. reserve_wallet_funds active hold and availability', 'PASS');
  v_passed := v_passed + 1;

  -- 5. Test overspending rejection: trying to reserve $15 when only $13 available must fail
  BEGIN
    PERFORM public.reserve_wallet_funds(
      v_test_user_id,
      15.00,
      'refill_instant',
      'test_exec_overspend_' || substr(v_test_user_id::text, 1, 8),
      'Should fail due to insufficient available funds'
    );
    RAISE EXCEPTION 'Test failed: overspend hold was not rejected';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%Insufficient available balance%' THEN
        RAISE EXCEPTION 'Unexpected error: %', SQLERRM;
      END IF;
  END;
  INSERT INTO wallet_test_results VALUES ('4. reserve_wallet_funds rejects overspend', 'PASS');
  v_passed := v_passed + 1;

  -- 6. Test capture_wallet_hold
  v_txn_id := public.capture_wallet_hold(
    v_hold_id,
    'topup_debit',
    'Captured test refill',
    jsonb_build_object('test', true)
  );

  -- Balance must now be 13.00 (posted), held must be 0.00
  v_summary := public.get_wallet_summary(v_test_user_id);
  IF (v_summary->>'posted_balance')::NUMERIC != 13.00 THEN
    RAISE EXCEPTION 'Test failed: posted_balance after capture should be 13.00, got %', v_summary->>'posted_balance';
  END IF;
  IF (v_summary->>'held_amount')::NUMERIC != 0.00 THEN
    RAISE EXCEPTION 'Test failed: held_amount after capture should be 0.00, got %', v_summary->>'held_amount';
  END IF;
  INSERT INTO wallet_test_results VALUES ('5. capture_wallet_hold debits balance and consumes hold', 'PASS');
  v_passed := v_passed + 1;

  -- 7. Test release_wallet_hold on a new hold
  v_hold_id := public.reserve_wallet_funds(
    v_test_user_id,
    5.00,
    'refill_instant',
    'test_exec_rel_' || substr(v_test_user_id::text, 1, 8),
    'Hold to release'
  );
  PERFORM public.release_wallet_hold(v_hold_id, 'Simulated provider failure');

  v_summary := public.get_wallet_summary(v_test_user_id);
  IF (v_summary->>'posted_balance')::NUMERIC != 13.00 OR (v_summary->>'available_balance')::NUMERIC != 13.00 THEN
    RAISE EXCEPTION 'Test failed: release should restore full available balance to 13.00';
  END IF;
  INSERT INTO wallet_test_results VALUES ('6. release_wallet_hold restores availability without ledger delta', 'PASS');
  v_passed := v_passed + 1;

  -- 8. Test quote_wallet_refund & request_wallet_refund
  -- Out of initial $20 paid deposit + $5 promo:
  -- $12 was captured (spending $5 promo + $7 paid).
  -- Remaining paid deposit = $13.00.
  v_refund_res := public.quote_wallet_refund(v_test_user_id);
  IF (v_refund_res->>'eligible_amount')::NUMERIC != 13.00 THEN
    RAISE EXCEPTION 'Test failed: eligible refund should be 13.00, got %', v_refund_res->>'eligible_amount';
  END IF;

  -- Request refund of $10.00
  v_refund_res := public.request_wallet_refund(v_test_user_id, 10.00, 'Test refund');
  IF (v_refund_res->>'success')::BOOLEAN != true THEN
    RAISE EXCEPTION 'Test failed: request_wallet_refund failed';
  END IF;

  v_summary := public.get_wallet_summary(v_test_user_id);
  IF (v_summary->>'held_amount')::NUMERIC != 10.00 THEN
    RAISE EXCEPTION 'Test failed: refund hold should be 10.00, got %', v_summary->>'held_amount';
  END IF;
  IF (v_summary->>'available_balance')::NUMERIC != 3.00 THEN
    RAISE EXCEPTION 'Test failed: available after refund hold should be 3.00, got %', v_summary->>'available_balance';
  END IF;
  INSERT INTO wallet_test_results VALUES ('7. quote & request refund allocates unspent paid funds', 'PASS');
  v_passed := v_passed + 1;

  IF EXISTS(SELECT 1 FROM public.wallet_reconciliation WHERE user_id=v_test_user_id AND drift<>0) THEN
    RAISE EXCEPTION 'Fixture introduced unexplained ledger drift';
  END IF;
  INSERT INTO wallet_test_results VALUES ('TOTAL', format('%s / 7 PASSED', v_passed));
END;
$$;

DO $$
DECLARE
  u uuid:=gen_random_uuid(); other_user uuid:=gen_random_uuid(); w uuid; h uuid; tx uuid; tx2 uuid;
  q jsonb; r jsonb; item public.wallet_refund_items; c jsonb; token uuid; ref text:=gen_random_uuid()::text;
BEGIN
  INSERT INTO auth.users(id,email) VALUES(u,ref||'@keepsims.test'),(other_user,'other-'||ref||'@keepsims.test');
  PERFORM public.ensure_wallet_v2(u); SELECT id INTO w FROM public.wallets WHERE user_id=u;
  tx:=public.credit_wallet_for_deposit(u,20,'fixture','paypal_'||ref,jsonb_build_object('paypal_capture_id',ref));
  tx2:=public.credit_wallet_for_deposit(u,20,'fixture','paypal_'||ref,jsonb_build_object('paypal_capture_id',ref));
  IF tx<>tx2 OR (SELECT balance FROM public.wallets WHERE id=w)<>20 THEN RAISE EXCEPTION 'Duplicate deposit credited twice'; END IF;
  h:=public.reserve_wallet_funds(u,20,'refill_instant',ref);
  BEGIN
    PERFORM public.debit_wallet_for_topup(u,NULL,1,'blocked','held-'||ref);
    RAISE EXCEPTION 'TEST: held balance was spent';
  EXCEPTION WHEN check_violation THEN NULL; END;
  IF (SELECT balance FROM public.wallets WHERE id=w)<>20 THEN RAISE EXCEPTION 'Rejected debit changed balance'; END IF;
  PERFORM public.release_wallet_hold(h);
  tx:=public.debit_wallet_for_topup(u,NULL,3,'fixture','exec_'||ref);
  tx2:=public.debit_wallet_for_topup(u,NULL,3,'fixture','exec_'||ref);
  IF tx<>tx2 OR (SELECT sum(remaining_amount) FROM public.wallet_funding_lots WHERE wallet_id=w)<>17 THEN
    RAISE EXCEPTION 'Immediate debit failed funding/idempotency'; END IF;
  PERFORM public.credit_wallet_for_refund(u,3,'refund_exec_'||ref);
  PERFORM public.credit_wallet_for_refund(u,3,'refund_exec_'||ref);
  IF (SELECT balance FROM public.wallets WHERE id=w)<>20 OR
    (SELECT sum(remaining_amount) FROM public.wallet_funding_lots WHERE wallet_id=w)<>20 THEN RAISE EXCEPTION 'Reversal did not restore original funding once'; END IF;
  BEGIN
    PERFORM public.credit_wallet_for_refund(u,1,'unmatched-'||ref);
    RAISE EXCEPTION 'TEST: unmatched legacy reversal minted funding';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Funding reconciliation required:%' THEN RAISE; END IF; END;

  -- Referral credits are usable, but neither refundable nor transferable.
  PERFORM public.credit_wallet_for_deposit(u,2,'referral_credit','refredeem_'||ref);
  IF NOT EXISTS(SELECT 1 FROM public.wallet_funding_lots WHERE wallet_id=w AND origin_type='promotional' AND NOT is_refundable)
    OR NOT EXISTS(SELECT 1 FROM public.wallet_transactions WHERE user_id=u AND type='referral_credit') THEN
    RAISE EXCEPTION 'Referral provenance incorrect'; END IF;

  -- Fully reserved paid lots cannot be refunded using unreserved promo funds.
  h:=public.reserve_wallet_funds(u,22,'refill_scheduled',ref||'-all');
  IF (public.quote_wallet_refund(u)->>'eligible_amount')::numeric<>0 THEN RAISE EXCEPTION 'Reserved funding quoted for refund'; END IF;
  BEGIN
    PERFORM public.request_wallet_refund(u,1);
    RAISE EXCEPTION 'TEST: refund reused reserved funding';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Refund exceeds eligible%' THEN RAISE; END IF; END;
  PERFORM public.release_wallet_hold(h);

  -- Actual API identities: no UID is never a self-service authorization.
  PERFORM set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',other_user)::text,true);
  BEGIN PERFORM public.get_wallet_summary(u); RAISE EXCEPTION 'TEST: foreign summary allowed';
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM public.request_wallet_refund(u,1); RAISE EXCEPTION 'TEST: foreign refund allowed';
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM set_config('request.jwt.claims','{"role":"authenticated"}',true);
  BEGIN PERFORM public.quote_wallet_refund(u); RAISE EXCEPTION 'TEST: missing UID allowed';
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM set_config('request.jwt.claims','{"role":"service_role"}',true);
  PERFORM public.get_wallet_summary(u);
  PERFORM set_config('request.jwt.claims','',true);

  -- Partial call capture consumes only actual spend, preserving unused funding.
  h:=public.reserve_wallet_funds(u,4,'call_budget',ref||'-call');
  tx:=public.settle_call_wallet_hold(h,1);
  IF tx IS NULL OR (SELECT balance FROM public.wallets WHERE id=w)<>21 OR
    (SELECT sum(remaining_amount) FROM public.wallet_funding_lots WHERE wallet_id=w)<>21 THEN
    RAISE EXCEPTION 'Partial call settlement did not reconcile'; END IF;
END;
$$;

DO $$
DECLARE u uuid:=gen_random_uuid(); w uuid; r jsonb; first_item public.wallet_refund_items;
  second_item public.wallet_refund_items; c jsonb; c2 jsonb; token uuid;
BEGIN
  INSERT INTO auth.users(id,email) VALUES(u,u||'@keepsims.test');
  PERFORM public.ensure_wallet_v2(u); SELECT id INTO w FROM public.wallets WHERE user_id=u;
  PERFORM public.credit_wallet_for_deposit(u,10,'fixture','paypal_a_'||u,jsonb_build_object('paypal_capture_id','a_'||u));
  PERFORM public.credit_wallet_for_deposit(u,10,'fixture','paypal_b_'||u,jsonb_build_object('paypal_capture_id','b_'||u));
  r:=public.request_wallet_refund(u,15);
  c:=public.request_wallet_refund(u,15);
  IF c->>'refund_request_id'<>r->>'refund_request_id' THEN RAISE EXCEPTION 'Duplicate refund request not adopted'; END IF;
  SELECT * INTO first_item FROM public.wallet_refund_items WHERE refund_request_id=(r->>'refund_request_id')::uuid ORDER BY amount DESC LIMIT 1;
  SELECT * INTO second_item FROM public.wallet_refund_items WHERE refund_request_id=first_item.refund_request_id AND id<>first_item.id;
  IF first_item.amount<>10 OR second_item.amount<>5 THEN RAISE EXCEPTION 'Refund allocation not complete'; END IF;
  BEGIN PERFORM public.finish_wallet_refund_item(first_item.id,NULL,'completed','provider-one');
    RAISE EXCEPTION 'TEST: unclaimed refund accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  c:=public.claim_wallet_refund_item(first_item.id); token:=(c->>'claim_token')::uuid;
  c2:=public.claim_wallet_refund_item(first_item.id);
  IF (c2->>'claimed')::boolean THEN RAISE EXCEPTION 'Refund was claimed twice'; END IF;
  BEGIN PERFORM public.finish_wallet_refund_item(first_item.id,gen_random_uuid(),'completed','provider-one');
    RAISE EXCEPTION 'TEST: invalid claim accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM public.begin_wallet_refund_submission(first_item.id,token);
  PERFORM public.record_wallet_refund_evidence(first_item.id,token,'pending','provider-one');
  PERFORM public.finish_wallet_refund_item(first_item.id,token,'pending','provider-one');
  IF (SELECT balance FROM public.wallets WHERE id=w)<>20 OR
    (public.get_wallet_summary(u)->>'held_amount')::numeric<>15 THEN RAISE EXCEPTION 'Pending payout was settled/released'; END IF;
  c:=public.claim_wallet_refund_item(first_item.id); token:=(c->>'claim_token')::uuid;
  PERFORM public.record_wallet_refund_evidence(first_item.id,token,'completed','provider-one');
  PERFORM public.finish_wallet_refund_item(first_item.id,token,'completed','provider-one');
  PERFORM public.finish_wallet_refund_item(first_item.id,token,'completed','provider-one');
  IF (SELECT balance FROM public.wallets WHERE id=w)<>10 OR
    (public.get_wallet_summary(u)->>'held_amount')::numeric<>5 THEN RAISE EXCEPTION 'Partial payout did not settle exactly once'; END IF;
  c:=public.claim_wallet_refund_item(second_item.id); token:=(c->>'claim_token')::uuid;
  PERFORM public.begin_wallet_refund_submission(second_item.id,token);
  PERFORM public.record_wallet_refund_evidence(second_item.id,token,'failed','provider-two');
  PERFORM public.finish_wallet_refund_item(second_item.id,token,'failed','provider-two');
  IF (public.get_wallet_summary(u)->>'held_amount')::numeric<>0 OR
    (SELECT sum(remaining_amount) FROM public.wallet_funding_lots WHERE wallet_id=w)<>10 OR
    (SELECT status FROM public.wallet_refund_requests WHERE id=first_item.refund_request_id)<>'partially_completed' THEN
    RAISE EXCEPTION 'Failed remainder did not release/refund request mismatch'; END IF;
END;
$$;


DO $$
DECLARE u uuid:=gen_random_uuid(); recipient uuid:=gen_random_uuid(); administrator uuid:=gen_random_uuid(); r jsonb; ref text:=gen_random_uuid()::text;
BEGIN
  INSERT INTO auth.users(id,email) VALUES(u,u||'@keepsims.test'),(recipient,recipient||'@keepsims.test'),(administrator,administrator||'@keepsims.test');
  INSERT INTO public.profiles(id,email,full_name) VALUES(u,u||'@keepsims.test','Sender'),(recipient,recipient||'@keepsims.test','Recipient'),(administrator,administrator||'@keepsims.test','Admin');
  PERFORM public.ensure_wallet_v2(u); PERFORM public.ensure_wallet_v2(recipient);
  PERFORM public.credit_wallet_for_deposit(u,10,'fixture','paypal_'||u,jsonb_build_object('paypal_capture_id',u::text));
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',u,'role','authenticated')::text,true);
  r:=public.transfer_wallet_credit(recipient||'@keepsims.test',3,ref,NULL);
  IF NOT (r->>'success')::boolean THEN RAISE EXCEPTION 'Gift failed: %',r; END IF;
  r:=public.transfer_wallet_credit(recipient||'@keepsims.test',3,ref,NULL);
  IF NOT (r->>'already_sent')::boolean OR (SELECT balance FROM public.wallets WHERE user_id=u)<>7
    OR NOT EXISTS(SELECT 1 FROM public.wallet_funding_lots WHERE user_id=recipient AND origin_type='gift_received' AND remaining_amount=3 AND NOT is_refundable)
    THEN RAISE EXCEPTION 'Gift funding/idempotency mismatch'; END IF;
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',administrator,'role','authenticated','app_metadata',jsonb_build_object('is_power_user',true))::text,true);
  r:=public.admin_adjust_wallet(recipient,2,'Fixture support credit');
  IF (SELECT sum(remaining_amount) FROM public.wallet_funding_lots WHERE user_id=recipient)<>5
    OR NOT EXISTS(SELECT 1 FROM public.wallet_funding_lots WHERE user_id=recipient AND origin_type='admin_adjustment' AND NOT is_refundable) THEN
    RAISE EXCEPTION 'Admin credit funding mismatch'; END IF;
  r:=public.admin_adjust_wallet(recipient,-1,'Fixture support debit');
  IF (SELECT sum(remaining_amount) FROM public.wallet_funding_lots WHERE user_id=recipient)<>4 OR
    (SELECT balance FROM public.wallets WHERE user_id=recipient)<>4 THEN RAISE EXCEPTION 'Admin debit funding mismatch'; END IF;
END;
$$;

DO $$
DECLARE u uuid:=gen_random_uuid(); w uuid;
BEGIN
  INSERT INTO auth.users(id,email) VALUES(u,u||'@keepsims.test');
  PERFORM public.ensure_wallet_v2(u);
  PERFORM public.credit_wallet_for_deposit(u,2,'fixture','paypal_'||u,jsonb_build_object('paypal_capture_id',u::text));
  SELECT id INTO w FROM public.wallets WHERE user_id=u;
  INSERT INTO public.wallet_transactions(wallet_id,user_id,type,amount,balance_before,balance_after,reference_id,status)
    VALUES(w,u,'wallet_forfeit',2,2,0,'purge_'||u,'completed');
  IF (SELECT balance FROM public.wallets WHERE id=w)<>0 OR
    (SELECT sum(remaining_amount) FROM public.wallet_funding_lots WHERE wallet_id=w)<>0 THEN
    RAISE EXCEPTION 'Legacy purge settlement did not reconcile'; END IF;
END;
$$;

SELECT * FROM wallet_test_results;

ROLLBACK;
