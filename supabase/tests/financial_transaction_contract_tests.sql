-- Isolated desired-behavior regressions. Run after the actual pending migrations.
-- Failures are release blockers, never accepted as "expected passes".

-- CASE: refund payout settles once under the real ledger discriminator CHECK
DO $$
DECLARE u uuid:=gen_random_uuid(); r jsonb; i uuid; c jsonb; w uuid;
BEGIN
 INSERT INTO auth.users(id,email) VALUES(u,u||'@keepsims.test');
 INSERT INTO public.profiles(id,email) VALUES(u,u||'@keepsims.test');
 PERFORM public.credit_wallet_for_deposit(u,20,'fixture','paypal_'||u,jsonb_build_object('paypal_capture_id',u));
 r:=public.request_wallet_refund(u,5);
 SELECT id INTO i FROM public.wallet_refund_items WHERE refund_request_id=(r->>'refund_request_id')::uuid;
 c:=public.claim_wallet_refund_item(i);
 PERFORM public.begin_wallet_refund_submission(i,(c->>'claim_token')::uuid);
 PERFORM public.record_wallet_refund_evidence(i,(c->>'claim_token')::uuid,'completed','fixture-provider-refund');
 PERFORM public.finish_wallet_refund_item(i,(c->>'claim_token')::uuid,'completed','fixture-provider-refund');
 PERFORM public.finish_wallet_refund_item(i,(c->>'claim_token')::uuid,'completed','fixture-provider-refund');
 IF (SELECT balance FROM public.wallets WHERE user_id=u)<>15 OR
    (SELECT count(*) FROM public.wallet_transactions WHERE user_id=u AND type='refund_payout')<>1 THEN
   RAISE EXCEPTION 'Refund payout did not settle exactly once';
 END IF;
END;
$$;

-- CASE: valid eSIM purchase reversal restores the original refundable funding source
DO $$
DECLARE u uuid:=gen_random_uuid(); ref text:=gen_random_uuid()::text; lot uuid;
BEGIN
 INSERT INTO auth.users(id,email) VALUES(u,u||'@keepsims.test');
 INSERT INTO public.profiles(id,email) VALUES(u,u||'@keepsims.test');
 PERFORM public.credit_wallet_for_deposit(u,20,'fixture','paypal_'||u,jsonb_build_object('paypal_capture_id',u));
 SELECT id INTO lot FROM public.wallet_funding_lots WHERE user_id=u;
 PERFORM public.debit_wallet_for_topup(u,NULL,3,'eSIM fixture','esim_'||ref,'esim_purchase_debit');
 -- Same explicit discriminator passed by live reap_stale_esim_orders.
 PERFORM public.credit_wallet_for_refund(u,3,'esim_refund_'||ref,'eSIM reversal',NULL,'esim_purchase_refund');
 PERFORM public.credit_wallet_for_refund(u,3,'esim_refund_'||ref,'eSIM reversal',NULL,'esim_purchase_refund');
 IF (SELECT remaining_amount FROM public.wallet_funding_lots WHERE id=lot)<>20 OR
    (SELECT count(*) FROM public.wallet_funding_lots WHERE user_id=u)<>1 OR
    (SELECT balance FROM public.wallets WHERE user_id=u)<>20 OR
    (SELECT count(*) FROM public.wallet_transactions WHERE user_id=u AND type='esim_purchase_refund')<>1 OR
    (public.quote_wallet_refund(u)->>'eligible_amount')::numeric<>20 THEN
   RAISE EXCEPTION 'eSIM reversal minted a replacement lot instead of restoring original refundable provenance';
 END IF;
END;
$$;

-- CASE: supported call reversal discriminator preserves original funding and retry identity
DO $$
DECLARE u uuid:=gen_random_uuid(); call_id uuid:=gen_random_uuid(); lot uuid;
BEGIN
 INSERT INTO auth.users(id,email) VALUES(u,u||'@keepsims.test');
 INSERT INTO public.profiles(id,email) VALUES(u,u||'@keepsims.test');
 INSERT INTO public.call_records(id,user_id,caller_number,destination_number,rate_per_minute_usd)
   VALUES(call_id,u,'+15550000000','+15550000001',0.1);
 PERFORM public.credit_wallet_for_deposit(u,20,'fixture','paypal_'||u,jsonb_build_object('paypal_capture_id',u));
 SELECT id INTO lot FROM public.wallet_funding_lots WHERE user_id=u;
 PERFORM public.debit_wallet_for_call(u,call_id,3);
 -- Existing generic reversal reference convention resolves refund_call_<id>
 -- to the original call_<id>; only the supported type varies here.
 PERFORM public.credit_wallet_for_refund(u,3,'refund_call_'||call_id,'Call reversal',NULL,'call_refund');
 PERFORM public.credit_wallet_for_refund(u,3,'refund_call_'||call_id,'Call reversal',NULL,'call_refund');
 IF (SELECT remaining_amount FROM public.wallet_funding_lots WHERE id=lot)<>20 OR
    (SELECT count(*) FROM public.wallet_funding_lots WHERE user_id=u)<>1 OR
    (SELECT balance FROM public.wallets WHERE user_id=u)<>20 OR
    (SELECT count(*) FROM public.wallet_transactions WHERE user_id=u AND type='call_refund')<>1 OR
    (public.quote_wallet_refund(u)->>'eligible_amount')::numeric<>20 THEN
   RAISE EXCEPTION 'Call reversal minted a replacement lot instead of restoring original provenance';
 END IF;
END;
$$;

-- CASE: verified paid liveness settlement uses a production-supported ledger discriminator
DO $$
DECLARE u uuid:=gen_random_uuid(); line uuid:=gen_random_uuid(); attempt uuid:=gen_random_uuid(); h uuid;
BEGIN
 INSERT INTO auth.users(id,email) VALUES(u,u||'@keepsims.test');
 INSERT INTO public.profiles(id,email) VALUES(u,u||'@keepsims.test');
 INSERT INTO public.sim_lines(id,user_id,phone_number) VALUES(line,u,'+15550000002');
 PERFORM public.credit_wallet_for_deposit(u,20,'fixture','paypal_'||u,jsonb_build_object('paypal_capture_id',u));
 h:=public.reserve_wallet_funds(u,1,'line_verification',attempt::text);
 INSERT INTO public.line_verification_attempts(id,sim_line_id,user_id,method,destination_phone,retail_price,funding_kind,wallet_hold_id,evidence_version,provider,provider_resource_id)
   VALUES(attempt,line,u,'voice','+15550000002',1,'wallet',h,1,'telnyx',attempt::text);
 PERFORM public.settle_line_verification_event(attempt,'telnyx',attempt::text,'call.ringing','succeeded');
 IF (SELECT balance FROM public.wallets WHERE user_id=u)<>19 THEN RAISE EXCEPTION 'Verified liveness charge not settled'; END IF;
END;
$$;
