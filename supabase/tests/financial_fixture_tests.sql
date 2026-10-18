-- Positive harness checks. These assert production safeguards and must stay
-- green independently of the desired-behavior financial regressions.

-- CASE: real ledger CHECK, NOT NULL and foreign-key constraints reject invalid writes
DO $$
DECLARE u uuid:=gen_random_uuid(); w uuid;
BEGIN
 INSERT INTO auth.users(id,email) VALUES(u,u||'@keepsims.test');
 PERFORM public.ensure_wallet_v2(u);
 SELECT id INTO w FROM public.wallets WHERE user_id=u;
 BEGIN
   INSERT INTO public.wallet_transactions(wallet_id,user_id,type,amount,balance_before,balance_after)
     VALUES(w,u,'invented_fixture_type',1,0,1);
   RAISE EXCEPTION 'TEST: unsupported type accepted';
 EXCEPTION WHEN check_violation THEN
   IF SQLERRM NOT LIKE '%wallet_transactions_type_check%' THEN RAISE; END IF;
 END;
 BEGIN
   INSERT INTO public.wallet_transactions(wallet_id,user_id,type,amount,balance_before,balance_after)
     VALUES(w,u,'deposit',0,0,0);
   RAISE EXCEPTION 'TEST: zero amount accepted by NOT VALID check';
 EXCEPTION WHEN check_violation THEN
   IF SQLERRM NOT LIKE '%wallet_transactions_amount_positive%' THEN RAISE; END IF;
 END;
 BEGIN
   INSERT INTO public.wallet_transactions(wallet_id,user_id,type,amount,balance_before,balance_after)
     VALUES(w,u,'deposit',1,NULL,1);
   RAISE EXCEPTION 'TEST: missing balance accepted';
 EXCEPTION WHEN not_null_violation THEN NULL;
 END;
 BEGIN
   INSERT INTO public.wallet_transactions(wallet_id,user_id,type,amount,balance_before,balance_after)
     VALUES(gen_random_uuid(),u,'deposit',1,0,1);
   RAISE EXCEPTION 'TEST: orphan ledger wallet accepted';
 EXCEPTION WHEN foreign_key_violation THEN NULL;
 END;
 BEGIN
   INSERT INTO public.sim_lines(user_id,phone_number) VALUES(u,'+15550000601');
   RAISE EXCEPTION 'TEST: auth user without profile accepted by SIM FK';
 EXCEPTION WHEN foreign_key_violation THEN NULL;
 END;
END;
$$;

-- CASE: authenticated reads obey the captured wallet ownership policies
DO $$
DECLARE u uuid:=gen_random_uuid(); foreign_user uuid:=gen_random_uuid();
BEGIN
 INSERT INTO auth.users(id,email) VALUES(u,u||'@keepsims.test'),(foreign_user,foreign_user||'@keepsims.test');
 PERFORM public.credit_wallet_for_deposit(u,2,'fixture','paypal_'||u,jsonb_build_object('paypal_capture_id',u));
 PERFORM public.credit_wallet_for_deposit(foreign_user,3,'fixture','paypal_'||foreign_user,jsonb_build_object('paypal_capture_id',foreign_user));
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',u,'role','authenticated')::text,true);
 SET LOCAL ROLE authenticated;
 IF (SELECT count(*) FROM public.wallets)<>1 OR
    (SELECT count(*) FROM public.wallet_transactions)<>1 THEN
   RAISE EXCEPTION 'Customer wallet RLS leaked or hid owned records';
 END IF;
 BEGIN
   UPDATE public.wallets SET balance=99 WHERE user_id=u;
   RAISE EXCEPTION 'TEST: customer directly updated balance';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 RESET ROLE;
 PERFORM set_config('request.jwt.claims','{"role":"anon"}',true);
 SET LOCAL ROLE anon;
 IF EXISTS(SELECT 1 FROM public.wallets) THEN RAISE EXCEPTION 'Anonymous wallet disclosure'; END IF;
 RESET ROLE;
END;
$$;

-- CASE: actual generated supplier columns cannot be replaced by permissive defaults
DO $$
DECLARE offer uuid:=gen_random_uuid();
BEGIN
 INSERT INTO public.service_providers(name,code) VALUES('Fixture','fixture');
 INSERT INTO public.provider_offers(id,provider_code,offer_kind,offer_code,country_code,source_name,source_price_usd,source_is_active)
   VALUES(offer,'fixture','esim','fixture','ZZ','Fixture offer',2,true);
 IF (SELECT effective_name FROM public.provider_offers WHERE id=offer)<>'Fixture offer' OR
    (SELECT effective_price_usd FROM public.provider_offers WHERE id=offer)<>2 THEN
   RAISE EXCEPTION 'Generated supplier price/name missing';
 END IF;
 UPDATE public.provider_offers SET override_price_usd=3 WHERE id=offer;
 IF (SELECT effective_price_usd FROM public.provider_offers WHERE id=offer)<>3 THEN RAISE EXCEPTION 'Generated override ignored'; END IF;
END;
$$;
