-- Tasks 7–8: production-shaped accounting and refund crash/recovery invariants.
-- CASE: mixed promotional and paid reversal restores exact original provenance across type aliases
DO $$
DECLARE u uuid:=gen_random_uuid(); ref text:=gen_random_uuid()::text; cash uuid; promo uuid; tx uuid; again uuid;
BEGIN
 INSERT INTO auth.users(id,email) VALUES(u,u||'@keepsims.test');
 PERFORM public.credit_wallet_for_deposit(u,10,'fixture','paypal_'||u,jsonb_build_object('paypal_capture_id',u));
 PERFORM public.credit_wallet_for_deposit(u,2,'referral_credit','refredeem_'||u);
 SELECT id INTO cash FROM public.wallet_funding_lots WHERE user_id=u AND origin_type='paypal_deposit';
 SELECT id INTO promo FROM public.wallet_funding_lots WHERE user_id=u AND origin_type='promotional';
 PERFORM public.debit_wallet_for_topup(u,NULL,5,'eSIM','esim_'||ref,'esim_purchase_debit');
 IF (SELECT remaining_amount FROM public.wallet_funding_lots WHERE id=promo)<>0 OR
   (SELECT remaining_amount FROM public.wallet_funding_lots WHERE id=cash)<>7 THEN RAISE EXCEPTION 'Mixed spend order wrong'; END IF;
 tx:=public.credit_wallet_for_refund(u,5,'esim_refund_'||ref,'generic worker');
 again:=public.credit_wallet_for_refund(u,5,'esim_refund_'||ref,'stale reaper',NULL,'esim_purchase_refund');
 IF tx<>again OR (SELECT count(*) FROM public.wallet_funding_lots WHERE user_id=u)<>2 OR
   (SELECT remaining_amount FROM public.wallet_funding_lots WHERE id=promo)<>2 OR
   (SELECT remaining_amount FROM public.wallet_funding_lots WHERE id=cash)<>10 OR
   (public.quote_wallet_refund(u)->>'eligible_amount')::numeric<>10 THEN RAISE EXCEPTION 'Mixed reversal lost provenance or duplicated'; END IF;
 BEGIN PERFORM public.credit_wallet_for_refund(u,1,'refund_esim_'||ref); RAISE EXCEPTION 'TEST: over reversal allowed';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Funding reconciliation required:%' THEN RAISE; END IF; END;
 IF EXISTS(SELECT 1 FROM public.wallet_reconciliation WHERE user_id=u AND drift<>0) THEN RAISE EXCEPTION 'Reversal reconciliation mismatch'; END IF;
END;
$$;

-- CASE: remaining provenance prevents referral gifting after the original cash was spent
DO $$
DECLARE u uuid:=gen_random_uuid(); recipient uuid:=gen_random_uuid(); r jsonb;
BEGIN
 INSERT INTO auth.users(id,email) VALUES(u,u||'@keepsims.test'),(recipient,recipient||'@keepsims.test');
 INSERT INTO public.profiles(id,email) VALUES(u,u||'@keepsims.test'),(recipient,recipient||'@keepsims.test');
 PERFORM public.ensure_wallet_v2(recipient);
 PERFORM public.credit_wallet_for_deposit(u,3,'fixture','paypal_'||u,jsonb_build_object('paypal_capture_id',u));
 PERFORM public.debit_wallet_for_topup(u,NULL,3,'fixture','spend_'||u);
 PERFORM public.credit_wallet_for_deposit(u,2,'referral_credit','refredeem_'||u);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',u,'role','authenticated')::text,true);
 r:=public.transfer_wallet_credit(recipient||'@keepsims.test',1,'gift_'||u);
 IF r->>'code'<>'NOT_GIFTABLE' OR (SELECT balance FROM public.wallets WHERE user_id=u)<>2
   OR (public.quote_wallet_refund(u)->>'eligible_amount')::numeric<>0 THEN RAISE EXCEPTION 'Promotional money laundered'; END IF;
END;
$$;

-- CASE: foreign-wallet and currency-corrupt lots or holds cannot be spent
DO $$
DECLARE u uuid:=gen_random_uuid(); v uuid:=gen_random_uuid(); h uuid; foreign_lot uuid; own_lot uuid;
BEGIN
 INSERT INTO auth.users(id,email) VALUES(u,u||'@keepsims.test'),(v,v||'@keepsims.test');
 PERFORM public.credit_wallet_for_deposit(u,10,'fixture','paypal_'||u,jsonb_build_object('paypal_capture_id',u));
 PERFORM public.credit_wallet_for_deposit(v,10,'fixture','paypal_'||v,jsonb_build_object('paypal_capture_id',v));
 SELECT id INTO own_lot FROM public.wallet_funding_lots WHERE user_id=u;
 SELECT id INTO foreign_lot FROM public.wallet_funding_lots WHERE user_id=v;
 h:=public.reserve_wallet_funds(u,2,'refill_instant','hold_'||u);
 UPDATE public.wallet_hold_allocations SET lot_id=foreign_lot WHERE hold_id=h;
 BEGIN PERFORM public.capture_wallet_hold(h); RAISE EXCEPTION 'TEST: foreign allocation captured';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Funding reconciliation required:%' THEN RAISE; END IF; END;
 UPDATE public.wallet_hold_allocations SET lot_id=own_lot WHERE hold_id=h;
 UPDATE public.wallet_funding_lots SET currency='EUR' WHERE id=own_lot;
 BEGIN PERFORM public.debit_wallet_for_topup(u,NULL,1,'fixture','bad_'||u); RAISE EXCEPTION 'TEST: foreign currency spent';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Funding reconciliation required:%' THEN RAISE; END IF; END;
 IF (SELECT balance FROM public.wallets WHERE user_id=u)<>10 THEN RAISE EXCEPTION 'Rejected binding mutated wallet'; END IF;
END;
$$;

-- CASE: expired or quarantined original cash is restored without gaining refund eligibility
DO $$
DECLARE u uuid:=gen_random_uuid(); ref text:=gen_random_uuid()::text; lot uuid;
BEGIN
 INSERT INTO auth.users(id,email) VALUES(u,u||'@keepsims.test');
 PERFORM public.credit_wallet_for_deposit(u,10,'fixture','paypal_'||u,jsonb_build_object('paypal_capture_id',u));
 SELECT id INTO lot FROM public.wallet_funding_lots WHERE user_id=u;
 UPDATE public.wallet_funding_lots SET refund_deadline=now()-interval '1 day' WHERE id=lot;
 PERFORM public.debit_wallet_for_topup(u,NULL,3,'fixture','spend_'||ref);
 PERFORM public.credit_wallet_for_refund(u,3,'refund_spend_'||ref);
 IF (SELECT remaining_amount FROM public.wallet_funding_lots WHERE id=lot)<>10 OR
   (public.quote_wallet_refund(u)->>'eligible_amount')::numeric<>0 THEN RAISE EXCEPTION 'Refund deadline reset'; END IF;
 PERFORM public.debit_wallet_for_topup(u,NULL,3,'fixture','other_'||ref);
 UPDATE public.wallet_funding_lots SET status='disputed' WHERE id=lot;
 BEGIN PERFORM public.credit_wallet_for_refund(u,3,'refund_other_'||ref); RAISE EXCEPTION 'TEST: disputed funding reactivated';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Funding reconciliation required:%' THEN RAISE; END IF; END;
END;
$$;

-- CASE: stale unsubmitted claims are fenced while stale submitted claims never authorize a second POST
DO $$
DECLARE u uuid:=gen_random_uuid(); r jsonb; i uuid; c jsonb; again jsonb; old_token uuid;
BEGIN
 INSERT INTO auth.users(id,email) VALUES(u,u||'@keepsims.test');
 PERFORM public.credit_wallet_for_deposit(u,10,'fixture','paypal_'||u,jsonb_build_object('paypal_capture_id',u));
 r:=public.request_wallet_refund(u,5);
 SELECT id INTO i FROM public.wallet_refund_items WHERE refund_request_id=(r->>'refund_request_id')::uuid;
 c:=public.claim_wallet_refund_item(i);old_token:=(c->>'claim_token')::uuid;
 UPDATE public.wallet_refund_items SET claimed_at=now()-interval '6 minutes' WHERE id=i;
 again:=public.claim_wallet_refund_item(i);
 IF again->>'action'<>'submit' OR again->>'claim_token'=c->>'claim_token' THEN RAISE EXCEPTION 'Safe pre-submission claim not recovered'; END IF;
 BEGIN PERFORM public.begin_wallet_refund_submission(i,old_token); RAISE EXCEPTION 'TEST: stale sender authorized';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 IF NOT public.begin_wallet_refund_submission(i,(again->>'claim_token')::uuid) THEN RAISE EXCEPTION 'Fresh submission refused'; END IF;
 IF public.begin_wallet_refund_submission(i,(again->>'claim_token')::uuid) THEN RAISE EXCEPTION 'Duplicate submission boundary opened'; END IF;
 UPDATE public.wallet_refund_items SET claimed_at=now()-interval '6 minutes' WHERE id=i;
 c:=public.claim_wallet_refund_item(i);
 IF (c->>'claimed')::boolean OR NOT (c->>'reconciliation_required')::boolean OR
   (public.get_wallet_summary(u)->>'held_amount')::numeric<>5 THEN RAISE EXCEPTION 'Ambiguous payout resubmitted or released'; END IF;
 BEGIN PERFORM public.release_wallet_hold((r->>'hold_id')::uuid); RAISE EXCEPTION 'TEST: generic release freed refund exposure';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'Use atomic refund item settlement' THEN RAISE; END IF; END;
END;
$$;

-- CASE: provider success survives a financial rollback and then settles exactly once
DO $$
DECLARE u uuid:=gen_random_uuid(); r jsonb; i uuid; c jsonb; token uuid; h uuid; before_lot numeric;
BEGIN
 INSERT INTO auth.users(id,email) VALUES(u,u||'@keepsims.test');
 PERFORM public.credit_wallet_for_deposit(u,10,'fixture','paypal_'||u,jsonb_build_object('paypal_capture_id',u));
 r:=public.request_wallet_refund(u,5);h:=(r->>'hold_id')::uuid;
 SELECT id INTO i FROM public.wallet_refund_items WHERE refund_request_id=(r->>'refund_request_id')::uuid;
 c:=public.claim_wallet_refund_item(i);token:=(c->>'claim_token')::uuid;
 PERFORM public.begin_wallet_refund_submission(i,token);
 PERFORM public.record_wallet_refund_evidence(i,token,'completed','provider_'||i);
 -- A deterministic ledger constraint failure stands in for a local DB failure.
 ALTER TABLE public.wallet_transactions ADD CONSTRAINT fixture_reject_payout CHECK(type<>'refund_payout') NOT VALID;
 BEGIN PERFORM public.finish_wallet_refund_item(i,token,'completed','provider_'||i); RAISE EXCEPTION 'TEST: failure injection did not fire';
 EXCEPTION WHEN check_violation THEN NULL; END;
 IF (SELECT balance FROM public.wallets WHERE user_id=u)<>10 OR
   (SELECT status FROM public.wallet_refund_items WHERE id=i)<>'processing' OR
   (SELECT provider_outcome FROM public.wallet_refund_items WHERE id=i)<>'completed' OR
   (SELECT amount FROM public.wallet_holds WHERE id=h)<>5 OR
   (SELECT count(*) FROM public.wallet_hold_allocations WHERE hold_id=h)<>1 OR
   (SELECT sum(remaining_amount) FROM public.wallet_funding_lots WHERE user_id=u)<>10 THEN
   RAISE EXCEPTION 'Partial local payout committed or provider evidence lost'; END IF;
 ALTER TABLE public.wallet_transactions DROP CONSTRAINT fixture_reject_payout;
 UPDATE public.wallet_refund_items SET claimed_at=now()-interval '6 minutes' WHERE id=i;
 c:=public.claim_wallet_refund_item(i);token:=(c->>'claim_token')::uuid;
 IF c->>'action'<>'settle' THEN RAISE EXCEPTION 'Recovery attempted another provider operation'; END IF;
 PERFORM public.finish_wallet_refund_item(i,token,'completed','provider_'||i);
 PERFORM public.finish_wallet_refund_item(i,token,'completed','provider_'||i);
 IF (SELECT balance FROM public.wallets WHERE user_id=u)<>5 OR
   (SELECT sum(remaining_amount) FROM public.wallet_funding_lots WHERE user_id=u)<>5 OR
   (SELECT status FROM public.wallet_holds WHERE id=h)<>'released' OR
   (SELECT count(*) FROM public.wallet_transactions WHERE user_id=u AND type='refund_payout')<>1 THEN RAISE EXCEPTION 'Recovery did not commit exactly once'; END IF;
END;
$$;

-- CASE: partial failure releases only unused exposure while the other provider refund is pending
DO $$
DECLARE u uuid:=gen_random_uuid(); r jsonb; i uuid; j uuid; c jsonb; h uuid; result jsonb;
BEGIN
 INSERT INTO auth.users(id,email) VALUES(u,u||'@keepsims.test');
 PERFORM public.credit_wallet_for_deposit(u,10,'fixture','paypal_a_'||u,jsonb_build_object('paypal_capture_id','a_'||u));
 PERFORM public.credit_wallet_for_deposit(u,10,'fixture','paypal_b_'||u,jsonb_build_object('paypal_capture_id','b_'||u));
 r:=public.request_wallet_refund(u,15);h:=(r->>'hold_id')::uuid;
 SELECT id INTO i FROM public.wallet_refund_items WHERE refund_request_id=(r->>'refund_request_id')::uuid AND amount=10;
 SELECT id INTO j FROM public.wallet_refund_items WHERE refund_request_id=(r->>'refund_request_id')::uuid AND amount=5;
 c:=public.claim_wallet_refund_item(j);PERFORM public.begin_wallet_refund_submission(j,(c->>'claim_token')::uuid);
 PERFORM public.record_wallet_refund_evidence(j,(c->>'claim_token')::uuid,'pending','pending_'||j);
 PERFORM public.finish_wallet_refund_item(j,(c->>'claim_token')::uuid,'pending','pending_'||j);
 c:=public.claim_wallet_refund_item(i);PERFORM public.begin_wallet_refund_submission(i,(c->>'claim_token')::uuid);
 PERFORM public.record_wallet_refund_evidence(i,(c->>'claim_token')::uuid,'failed','failed_'||i);
 PERFORM public.finish_wallet_refund_item(i,(c->>'claim_token')::uuid,'failed','failed_'||i);
 IF (public.get_wallet_summary(u)->>'held_amount')::numeric<>5 OR
   (SELECT sum(amount) FROM public.wallet_hold_allocations WHERE hold_id=h)<>5 OR
   (SELECT balance FROM public.wallets WHERE user_id=u)<>20 OR
   (SELECT status FROM public.wallet_refund_requests WHERE id=(r->>'refund_request_id')::uuid)<>'under_review' THEN
   RAISE EXCEPTION 'Partial failure released pending exposure or retained failed exposure'; END IF;
 c:=public.claim_wallet_refund_item(j);
 IF c->>'action'<>'poll' THEN RAISE EXCEPTION 'Pending provider refund was resubmitted'; END IF;
END;
$$;

-- CASE: refund binding and provider identity cannot be redirected between users
DO $$
DECLARE u uuid:=gen_random_uuid(); v uuid:=gen_random_uuid(); r jsonb; i uuid; c jsonb; foreign_lot uuid;
BEGIN
 INSERT INTO auth.users(id,email) VALUES(u,u||'@keepsims.test'),(v,v||'@keepsims.test');
 PERFORM public.credit_wallet_for_deposit(u,10,'fixture','paypal_'||u,jsonb_build_object('paypal_capture_id',u));
 PERFORM public.credit_wallet_for_deposit(v,10,'fixture','paypal_'||v,jsonb_build_object('paypal_capture_id',v));
 r:=public.request_wallet_refund(u,5);SELECT id INTO i FROM public.wallet_refund_items WHERE refund_request_id=(r->>'refund_request_id')::uuid;
 c:=public.claim_wallet_refund_item(i);PERFORM public.begin_wallet_refund_submission(i,(c->>'claim_token')::uuid);
 PERFORM public.record_wallet_refund_evidence(i,(c->>'claim_token')::uuid,'pending','bound_'||i);
 BEGIN PERFORM public.record_wallet_refund_evidence(i,(c->>'claim_token')::uuid,'completed','changed_'||i); RAISE EXCEPTION 'TEST: provider ID changed';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'Provider refund identity changed' THEN RAISE; END IF; END;
 SELECT id INTO foreign_lot FROM public.wallet_funding_lots WHERE user_id=v;
 UPDATE public.wallet_refund_items SET lot_id=foreign_lot WHERE id=i;
 BEGIN PERFORM public.finish_wallet_refund_item(i,(c->>'claim_token')::uuid,'pending','bound_'||i); RAISE EXCEPTION 'TEST: foreign lot settled';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'Refund owner, currency or funding binding mismatch' THEN RAISE; END IF; END;
END;
$$;

-- CASE: refunded call retries cannot return a different users call transaction
DO $$
DECLARE u uuid:=gen_random_uuid(); v uuid:=gen_random_uuid(); call_id uuid:=gen_random_uuid();
BEGIN
 INSERT INTO auth.users(id,email) VALUES(u,u||'@keepsims.test'),(v,v||'@keepsims.test');
 INSERT INTO public.call_records(id,user_id,caller_number,destination_number,rate_per_minute_usd) VALUES(call_id,u,'+15550000000','+15550000001',0.1);
 PERFORM public.credit_wallet_for_deposit(u,10,'fixture','paypal_'||u,jsonb_build_object('paypal_capture_id',u));
 PERFORM public.credit_wallet_for_deposit(v,10,'fixture','paypal_'||v,jsonb_build_object('paypal_capture_id',v));
 PERFORM public.debit_wallet_for_call(u,call_id,1);
 BEGIN PERFORM public.debit_wallet_for_call(v,call_id,1); RAISE EXCEPTION 'TEST: foreign call adopted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.debit_wallet_for_call(u,call_id,2); RAISE EXCEPTION 'TEST: conflicting call amount adopted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'Call reference amount mismatch' THEN RAISE; END IF; END;
END;
$$;

-- CASE: all new internal refund functions deny customer and anonymous execution
DO $$
DECLARE fn regprocedure;
BEGIN
 FOREACH fn IN ARRAY ARRAY['public.lock_wallet_refund_item(uuid)'::regprocedure,'public.begin_wallet_refund_submission(uuid,uuid)'::regprocedure,
   'public.record_wallet_refund_evidence(uuid,uuid,text,text)'::regprocedure,'public.adopt_wallet_refund_identity(uuid,text,uuid)'::regprocedure,
   'public.list_wallet_refund_work(uuid,integer)'::regprocedure] LOOP
   IF has_function_privilege('anon',fn,'EXECUTE') OR has_function_privilege('authenticated',fn,'EXECUTE')
     OR NOT has_function_privilege('service_role',fn,'EXECUTE') THEN RAISE EXCEPTION 'Refund ACL regression %',fn; END IF;
 END LOOP;
 SET LOCAL ROLE authenticated;
 BEGIN PERFORM public.claim_wallet_refund_item(gen_random_uuid()); RAISE EXCEPTION 'TEST: customer claimed payout'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 RESET ROLE;
END;
$$;

-- CASE: admin retries retain one signed correction and reject conflicting operation terms
DO $$
DECLARE u uuid:=gen_random_uuid(); admin uuid:=gen_random_uuid(); first_result jsonb; again jsonb;
BEGIN
 INSERT INTO auth.users(id,email) VALUES(u,u||'@keepsims.test'),(admin,admin||'@keepsims.test');
 INSERT INTO public.profiles(id,email) VALUES(u,u||'@keepsims.test'),(admin,admin||'@keepsims.test');
 PERFORM public.credit_wallet_for_deposit(u,10,'fixture','paypal_'||u,jsonb_build_object('paypal_capture_id',u));
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',admin,'role','authenticated','app_metadata',jsonb_build_object('is_power_user',true))::text,true);
 first_result:=public.admin_adjust_wallet_once(u,-2,'Fixture correction','correction_'||u);
 again:=public.admin_adjust_wallet_once(u,-2,'Fixture correction','correction_'||u);
 IF first_result->>'transaction_id'<>again->>'transaction_id' OR (SELECT balance FROM public.wallets WHERE user_id=u)<>8 THEN RAISE EXCEPTION 'Support correction applied twice'; END IF;
 BEGIN PERFORM public.admin_adjust_wallet_once(u,-3,'Fixture correction','correction_'||u); RAISE EXCEPTION 'TEST: conflicting correction adopted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'Adjustment reference mismatch' THEN RAISE; END IF; END;
 IF EXISTS(SELECT 1 FROM public.wallet_reconciliation WHERE user_id=u AND drift<>0) THEN RAISE EXCEPTION 'Support signed reconciliation mismatch'; END IF;
END;
$$;

-- CASE: ledger status updates and financial field edits cannot bypass insert-time funding
DO $$
DECLARE u uuid:=gen_random_uuid(); tx uuid;
BEGIN
 INSERT INTO auth.users(id,email) VALUES(u,u||'@keepsims.test');
 tx:=public.credit_wallet_for_deposit(u,2,'fixture','paypal_'||u,jsonb_build_object('paypal_capture_id',u));
 BEGIN UPDATE public.wallet_transactions SET amount=3 WHERE id=tx; RAISE EXCEPTION 'TEST: ledger amount edited';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'Wallet financial ledger fields are immutable' THEN RAISE; END IF; END;
 BEGIN UPDATE public.wallet_transactions SET status='pending' WHERE id=tx; RAISE EXCEPTION 'TEST: completed financial row relabeled';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'Wallet financial ledger fields are immutable' THEN RAISE; END IF; END;
 BEGIN DELETE FROM public.wallet_transactions WHERE id=tx; RAISE EXCEPTION 'TEST: financial row deleted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'Wallet ledger deletion requires a reviewed retention migration' THEN RAISE; END IF; END;
END;
$$;

-- CASE: pending entries of every supported type remain outside completed reconciliation
DO $$
DECLARE u uuid:=gen_random_uuid(); w uuid; t text;
BEGIN
 INSERT INTO auth.users(id,email) VALUES(u,u||'@keepsims.test');
 PERFORM public.credit_wallet_for_deposit(u,10,'fixture','paypal_'||u,jsonb_build_object('paypal_capture_id',u));
 SELECT id INTO w FROM public.wallets WHERE user_id=u;
 FOREACH t IN ARRAY ARRAY['deposit','topup_debit','refund','referral_credit','referral_withdrawal','plan_fee_debit',
   'home_mode_debit','auto_fund','esim_purchase_debit','esim_purchase_refund','wallet_settlement','wallet_forfeit',
   'gift_sent','gift_received','admin_adjustment','offline_voucher_debit','call_debit','call_refund','did_purchase_debit','refund_payout','verification_debit'] LOOP
   INSERT INTO public.wallet_transactions(wallet_id,user_id,type,amount,balance_before,balance_after,reference_id,status)
     VALUES(w,u,t,1,10,9,'pending_'||t||u,'pending');
 END LOOP;
 IF EXISTS(SELECT 1 FROM public.wallet_reconciliation WHERE user_id=u AND (ledger_sum<>10 OR drift<>0)) OR
   (SELECT count(*) FROM public.wallet_transactions WHERE user_id=u AND status='pending')<>21 THEN RAISE EXCEPTION 'Reconciliation included pending rows or lost a supported type'; END IF;
END;
$$;

-- CASE: new request keys and support operation keys preserve owner and admin boundaries
DO $$
DECLARE u uuid:=gen_random_uuid(); other_user uuid:=gen_random_uuid();
BEGIN
 INSERT INTO auth.users(id,email) VALUES(u,u||'@keepsims.test'),(other_user,other_user||'@keepsims.test');
 PERFORM public.credit_wallet_for_deposit(u,10,'fixture','paypal_'||u,jsonb_build_object('paypal_capture_id',u));
 PERFORM set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',other_user,'app_metadata','{}'::jsonb)::text,true);
 SET LOCAL ROLE authenticated;
 BEGIN PERFORM public.request_wallet_refund_once(u,1,'foreign_intent'); RAISE EXCEPTION 'TEST: foreign keyed refund allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.admin_adjust_wallet_once(u,1,'Unapproved credit','foreign_correction'); RAISE EXCEPTION 'TEST: nonadmin correction allowed';
 EXCEPTION WHEN SQLSTATE 'KS460' THEN NULL; END;
 RESET ROLE;
END;
$$;

-- CASE: a purchase reversal after unused cash was paid out restores only its unrefunded original allocation
DO $$
DECLARE u uuid:=gen_random_uuid(); ref text:=gen_random_uuid()::text; r jsonb; i uuid; c jsonb; lot uuid;
BEGIN
 INSERT INTO auth.users(id,email) VALUES(u,u||'@keepsims.test');
 PERFORM public.credit_wallet_for_deposit(u,10,'fixture','paypal_'||u,jsonb_build_object('paypal_capture_id',u));
 SELECT id INTO lot FROM public.wallet_funding_lots WHERE user_id=u;
 PERFORM public.debit_wallet_for_topup(u,NULL,3,'eSIM','esim_'||ref,'esim_purchase_debit');
 r:=public.request_wallet_refund_once(u,7,'unused_cash_'||u);
 SELECT id INTO i FROM public.wallet_refund_items WHERE refund_request_id=(r->>'refund_request_id')::uuid;
 c:=public.claim_wallet_refund_item(i);PERFORM public.begin_wallet_refund_submission(i,(c->>'claim_token')::uuid);
 PERFORM public.record_wallet_refund_evidence(i,(c->>'claim_token')::uuid,'completed','unused_'||i);
 PERFORM public.finish_wallet_refund_item(i,(c->>'claim_token')::uuid,'completed','unused_'||i);
 IF (SELECT status FROM public.wallet_funding_lots WHERE id=lot)<>'fully_refunded' THEN RAISE EXCEPTION 'Payout precondition failed'; END IF;
 PERFORM public.credit_wallet_for_refund(u,3,'esim_refund_'||ref,'Purchase reversal',NULL,'esim_purchase_refund');
 IF (SELECT remaining_amount FROM public.wallet_funding_lots WHERE id=lot)<>3 OR
   (SELECT status FROM public.wallet_funding_lots WHERE id=lot)<>'partially_refunded' OR
   (SELECT count(*) FROM public.wallet_funding_lots WHERE user_id=u)<>1 OR
   (public.quote_wallet_refund(u)->>'eligible_amount')::numeric<>3 THEN RAISE EXCEPTION 'Known purchase allocation lost after partial cash payout'; END IF;
END;
$$;
