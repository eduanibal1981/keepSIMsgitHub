-- Isolated regression fixtures only. Run after the October 16 migrations.
BEGIN;

DO $$
DECLARE p regprocedure;
BEGIN
  IF to_regprocedure('public.finalize_sim_setup_order(uuid,text)') IS NOT NULL THEN RAISE EXCEPTION 'Ambiguous finalizer retained'; END IF;
  FOREACH p IN ARRAY ARRAY[
    'public.reap_stuck_executions(integer,integer)'::regprocedure,
    'public.reserve_wallet_funds(uuid,numeric,text,text,text,integer)'::regprocedure,
    'public.capture_sim_setup_holds(uuid,text)'::regprocedure,
    'public.claim_wallet_refund_item(uuid)'::regprocedure,
    'public.finish_wallet_refund_item(uuid,uuid,text,text)'::regprocedure,
    'public.resolve_line_entitlement(uuid)'::regprocedure
  ] LOOP
    IF has_function_privilege('anon',p,'EXECUTE') OR has_function_privilege('authenticated',p,'EXECUTE')
      OR NOT has_function_privilege('service_role',p,'EXECUTE') THEN RAISE EXCEPTION 'Incorrect grant: %',p; END IF;
  END LOOP;
  IF has_table_privilege('authenticated','public.return_trip_packages','SELECT')
    OR has_column_privilege('authenticated','public.call_rates','cost_per_minute_usd','SELECT') THEN
    RAISE EXCEPTION 'Customer wholesale access retained'; END IF;
  -- Exercise effective SQL roles, beyond privilege metadata.
  SET LOCAL ROLE anon;
  BEGIN PERFORM public.reap_stuck_executions(); RAISE EXCEPTION 'TEST: anon maintenance allowed';
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  RESET ROLE;
  SET LOCAL ROLE authenticated;
  BEGIN PERFORM public.reap_stuck_executions(); RAISE EXCEPTION 'TEST: customer maintenance allowed';
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  RESET ROLE;
  BEGIN PERFORM public.reap_stuck_executions(0,0); RAISE EXCEPTION 'TEST: unbounded reaper allowed';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END;
$$;

DO $$
DECLARE u uuid:=gen_random_uuid(); other_user uuid:=gen_random_uuid(); l uuid:=gen_random_uuid();
  o uuid:=gen_random_uuid(); h uuid; q jsonb; rule_id uuid:=gen_random_uuid(); carrier uuid:=gen_random_uuid();
  country uuid:=gen_random_uuid(); premium_o uuid; refill_hold uuid; fee_hold uuid; e uuid:=gen_random_uuid();
  before_balance numeric; r jsonb;
BEGIN
  INSERT INTO auth.users(id,email) VALUES(u,u||'@keepsims.test'),(other_user,other_user||'@keepsims.test');
  INSERT INTO public.profiles(id,email) VALUES(u,u||'@keepsims.test'),(other_user,other_user||'@keepsims.test');
  INSERT INTO public.countries(id,name,iso_code,dialing_code,currency_code) VALUES(country,'Fixture','ZZ','+999','USD');
  INSERT INTO public.carriers(id,country_id,name) VALUES(carrier,country,'Fixture');
  INSERT INTO public.carrier_rules(id,carrier_id,minimum_topup_amount,inactivity_limit_days,rule_type,topup_validity_days)
    VALUES(rule_id,carrier,1,90,'prepaid',90);
  INSERT INTO public.sim_lines(id,user_id,phone_number,country_id,carrier_id,carrier_rule_id,plan_type,protection_tier,plan_expires_at)
    VALUES(l,u,'+15550000001',country,carrier,rule_id,'standard','standard',now()+interval '1 year');
  -- A draft Standard label is not evidence of payment.
  IF (public.resolve_line_entitlement(l)->>'is_paid')::boolean THEN RAISE EXCEPTION 'Unpaid draft has entitlement'; END IF;
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',u,'role','authenticated')::text,true);
  q:=public.quote_premium_breakdown(rule_id,l);
  IF (q->>'is_upgrade')::boolean OR (q->>'annual_fee_usd')::numeric<>5 THEN RAISE EXCEPTION 'Unpaid draft received upgrade credit'; END IF;
  PERFORM set_config('request.jwt.claims','',true);
  PERFORM public.ensure_wallet_v2(u);
  PERFORM public.credit_wallet_for_deposit(u,30,'fixture','paypal_'||u,jsonb_build_object('paypal_capture_id',u::text));
  h:=public.reserve_wallet_funds(u,2.50,'plan_fee','setup_fee_'||o::text);
  INSERT INTO public.sim_setup_orders(id,user_id,sim_line_id,carrier_rule_id,plan,phone_number,annual_fee_usd,total_charge_usd,annual_fee_hold_id,status)
    VALUES(o,u,l,rule_id,'standard','+15550000001',2.50,2.50,h,'reserved');
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',other_user,'role','authenticated')::text,true);
  BEGIN PERFORM public.finalize_sim_setup_order(o); RAISE EXCEPTION 'TEST: foreign finalization allowed';
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',u,'role','authenticated')::text,true);
  r:=public.finalize_sim_setup_order(o,p_sim_line_id=>l);
  r:=public.finalize_sim_setup_order(o);
  IF NOT (r->>'success')::boolean OR (SELECT count(*) FROM public.plan_payments WHERE sim_line_id=l)<>1
    OR (SELECT count(*) FROM public.scheduled_topups WHERE sim_line_id=l)<>1 THEN RAISE EXCEPTION 'Standard finalization not idempotent'; END IF;
  IF (SELECT is_carrier_verified OR carrier_verified_at IS NOT NULL OR verification_status='verified' FROM public.sim_lines WHERE id=l)
    THEN RAISE EXCEPTION 'Standard payment fabricated verification'; END IF;
  IF NOT (public.resolve_line_entitlement(l)->>'is_paid')::boolean THEN RAISE EXCEPTION 'Settled Standard setup not entitled'; END IF;
  q:=public.quote_premium_breakdown(rule_id,l);
  IF NOT (q->>'is_upgrade')::boolean OR (q->>'annual_fee_usd')::numeric<>2.50 THEN RAISE EXCEPTION 'Paid Standard upgrade rejected'; END IF;
  IF public.plan_price_net('premium',l,rule_id)<>(q->>'total_charge_usd')::numeric
    OR public.quote_plan_price(l,'premium','wallet',rule_id)<>(q->>'total_charge_usd')::numeric THEN RAISE EXCEPTION 'Quote and collection disagree'; END IF;
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',other_user,'role','authenticated')::text,true);
  BEGIN PERFORM public.finalize_sim_setup_order(o); RAISE EXCEPTION 'TEST: active foreign finalization leaked';
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM set_config('request.jwt.claims','{"role":"anon"}',true);
  BEGIN PERFORM public.finalize_sim_setup_order(o); RAISE EXCEPTION 'TEST: anon finalization allowed';
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',u,'role','authenticated')::text,true);
  UPDATE public.sim_lines SET plan_expires_at=now()-interval '1 day' WHERE id=l;
  IF (public.quote_premium_breakdown(rule_id,l)->>'is_upgrade')::boolean THEN RAISE EXCEPTION 'Expired Standard received credit'; END IF;

  -- Published zero beats a retired/draft nonzero fee; absent rules use fallback.
  INSERT INTO public.app_fee_rules(appfees_item,version,prem_percentage,prem_minimum,free_percentage,free_minimum,
    stand_percentage,stand_minimum,status) VALUES('refills',99999,0,0,0,0,0,0,'published');
  IF public.resolve_app_fee('refills','premium',10)<>0 THEN RAISE EXCEPTION 'Zero promotion lost'; END IF;
  IF (public.quote_premium_breakdown(rule_id,l)->>'first_refill_cost_usd')::numeric<>1 THEN RAISE EXCEPTION 'Zero refill fee replaced by fallback'; END IF;
  IF public.resolve_app_fee('missing-fixture','premium',10) IS NOT NULL THEN RAISE EXCEPTION 'Missing rule confused with zero'; END IF;
  INSERT INTO public.app_fee_rules(appfees_item,version,prem_percentage,prem_minimum,free_percentage,free_minimum,
    stand_percentage,stand_minimum,status) VALUES('esimofferfee',99999,0,0,0,0,0,0,'published');
  IF public.resolve_esim_offer_price(10,u)<>10 THEN RAISE EXCEPTION 'Zero eSIM fee replaced by fallback'; END IF;

  -- Wallet-paid lines have settled ledger evidence even without plan_payments.
  r:=public.pay_plan_fee_from_wallet('plan-'||u,l,NULL,'standard',rule_id);
  DELETE FROM public.plan_payments WHERE sim_line_id=l;
  IF NOT (r->>'success')::boolean OR NOT (public.resolve_line_entitlement(l)->>'is_paid')::boolean THEN
    RAISE EXCEPTION 'Wallet-paid entitlement not recognized'; END IF;

  -- Premium is activated only after authoritative successful initial delivery.
  premium_o:=gen_random_uuid();
  fee_hold:=public.reserve_wallet_funds(u,2.50,'plan_fee','setup_fee_'||premium_o::text);
  refill_hold:=public.reserve_wallet_funds(u,1,'setup_refill','setup_refill_'||premium_o::text);
  INSERT INTO public.sim_setup_orders(id,user_id,sim_line_id,carrier_rule_id,plan,phone_number,annual_fee_usd,
    first_refill_cost_usd,total_charge_usd,annual_fee_hold_id,first_refill_hold_id,status)
    VALUES(premium_o,u,l,rule_id,'premium','+15550000001',2.50,1,3.50,fee_hold,refill_hold,'dispatching');
  SELECT balance INTO before_balance FROM public.wallets WHERE user_id=u;
  r:=public.finalize_sim_setup_order(premium_o);
  IF NOT (r->>'pending')::boolean THEN RAISE EXCEPTION 'Undelivered Premium activated'; END IF;
  INSERT INTO public.topup_executions(id,user_id,sim_line_id,amount,status,wallet_hold_id,offer_id,offer_value,api_provider,base_cost_usd,app_fee_usd)
    VALUES(e,u,l,1,'processing',refill_hold,'fixture',1,'dtone',1,0);
  PERFORM public.begin_refill_submission(e,refill_hold);
  UPDATE public.topup_executions SET status='failed' WHERE id=e;
  r:=public.finalize_sim_setup_order(premium_o);
  IF (SELECT balance FROM public.wallets WHERE user_id=u)<>before_balance
    OR (SELECT status FROM public.wallet_holds WHERE id=refill_hold)<>'active' THEN RAISE EXCEPTION 'Failure released/captured ambiguous purchase'; END IF;
  r:=public.settle_instant_refill_execution(e,'provider-proof',refill_hold);
  r:=public.finalize_sim_setup_order(premium_o);
  r:=public.finalize_sim_setup_order(premium_o);
  IF NOT (r->>'success')::boolean OR (SELECT balance FROM public.wallets WHERE user_id=u)<>before_balance-3.50
    OR (SELECT count(*) FROM public.scheduled_topups WHERE sim_line_id=l AND schedule_type='refill_mini')<>1 THEN
    RAISE EXCEPTION 'Delivered Premium did not settle once'; END IF;
  -- Verification is still independent of successful money settlement.
  IF (SELECT is_carrier_verified FROM public.sim_lines WHERE id=l) THEN RAISE EXCEPTION 'Premium fabricated carrier verification'; END IF;
END;
$$;

DO $$
DECLARE u uuid:=gen_random_uuid(); other_user uuid:=gen_random_uuid(); l uuid:=gen_random_uuid(); foreign_line uuid:=gen_random_uuid();
  country uuid:=gen_random_uuid(); pkg uuid:=gen_random_uuid(); trip uuid; price numeric; h uuid; h2 uuid; x uuid:=gen_random_uuid(); q jsonb; rate_json jsonb;
BEGIN
  INSERT INTO auth.users(id,email) VALUES(u,u||'@keepsims.test'),(other_user,other_user||'@keepsims.test');
  INSERT INTO public.profiles(id,email) VALUES(u,u||'@keepsims.test'),(other_user,other_user||'@keepsims.test');
  INSERT INTO public.countries(id,name,iso_code,dialing_code,currency_code) VALUES(country,'Fixture','ZZ','+999','USD');
  INSERT INTO public.sim_lines(id,user_id,phone_number,country_id) VALUES(l,u,'+15550000201',country),(foreign_line,other_user,'+15550000202',country);
  INSERT INTO public.return_trip_packages(id,country_id,package_type,title,data_allowance_mb,duration_days,supplier_cost_usd,retail_price_usd)
    VALUES(pkg,country,'esim','Fixture',1000,7,1,2);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',u,'role','authenticated')::text,true);
  SELECT to_jsonb(p) INTO q FROM public.get_return_trip_packages_for_line(l) p WHERE id=pkg;
  IF q ? 'supplier_cost_usd' OR q ? 'app_fee_usd' OR (q->>'effective_price_usd')::numeric<>2 THEN RAISE EXCEPTION 'Package contract exposes wholesale'; END IF;
  BEGIN PERFORM public.get_return_trip_packages_for_line(foreign_line,other_user); RAISE EXCEPTION 'TEST: foreign packages allowed';
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM public.get_return_trip_history_for_line(foreign_line,other_user); RAISE EXCEPTION 'TEST: foreign trip history allowed';
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    INSERT INTO public.return_trips(user_id,sim_line_id,destination_country_id,arrival_date,status,chosen_package_id,chosen_package_type,accepted_price_usd)
      VALUES(u,l,country,current_date,'data_ready',pkg,'esim',0.01);
    RAISE EXCEPTION 'TEST: forged accepted quote allowed';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Package price changed%' THEN RAISE; END IF; END;
  SET LOCAL ROLE authenticated;
  INSERT INTO public.return_trips(user_id,sim_line_id,destination_country_id,arrival_date,status,chosen_package_id,chosen_package_type,accepted_price_usd)
    VALUES(u,l,country,current_date,'data_ready',pkg,'esim',2) RETURNING id INTO trip;
  BEGIN
    INSERT INTO public.return_trips(user_id,sim_line_id,destination_country_id,arrival_date,status)
      VALUES(u,foreign_line,country,current_date,'planning');
    RAISE EXCEPTION 'TEST: customer wrote trip for foreign SIM';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM cost_per_minute_usd FROM public.call_rates; RAISE EXCEPTION 'TEST: customer read wholesale rate';
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM supplier_cost_usd FROM public.return_trip_packages; RAISE EXCEPTION 'TEST: customer read wholesale packages';
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  RESET ROLE;
  UPDATE public.return_trip_packages SET retail_price_usd=9 WHERE id=pkg;
  SELECT effective_price_usd INTO price FROM public.get_return_trip_history_for_line(l) WHERE trip_id=trip;
  IF price<>2 THEN RAISE EXCEPTION 'History repriced from current catalogue'; END IF;
  UPDATE public.return_trips SET accepted_price_usd=0.01 WHERE id=trip;
  IF (SELECT accepted_price_usd FROM public.return_trips WHERE id=trip)<>2 THEN RAISE EXCEPTION 'Saved quote mutable'; END IF;
  -- Simulate pre-migration historical data without fabricating a historical quote.
  ALTER TABLE public.return_trips DISABLE TRIGGER guard_return_trip_contract;
  UPDATE public.return_trips SET accepted_price_usd=NULL WHERE id=trip;
  ALTER TABLE public.return_trips ENABLE TRIGGER guard_return_trip_contract;
  IF EXISTS(SELECT 1 FROM public.get_return_trip_history_for_line(l) WHERE trip_id=trip AND effective_price_usd IS NOT NULL) THEN
    RAISE EXCEPTION 'Unknown legacy history reported as known price'; END IF;
  INSERT INTO public.call_rates(country_code,country_name,phone_prefix,destination_type,rate_per_minute_usd,cost_per_minute_usd)
    VALUES('ZZ','Fixture','+1555','all',0.02,0.01);
  SELECT to_jsonb(r) INTO rate_json FROM public.get_call_rate_for_number('+15550000201') r LIMIT 1;
  IF rate_json ? 'cost_per_minute_usd' OR (rate_json->>'rate_per_minute_usd')::numeric<=0 THEN RAISE EXCEPTION 'Calling contract invalid'; END IF;
  BEGIN PERFORM public.get_user_calling_rates(other_user); RAISE EXCEPTION 'TEST: foreign pricing allowed';
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;

  PERFORM set_config('request.jwt.claims','',true);
  PERFORM public.ensure_wallet_v2(u);
  PERFORM public.credit_wallet_for_deposit(u,10,'fixture','paypal_'||u,jsonb_build_object('paypal_capture_id',u::text));
  h:=public.reserve_wallet_funds(u,2,'refill_instant',x::text);
  h2:=public.reserve_wallet_funds(u,2,'refill_scheduled',x::text);
  UPDATE public.wallet_holds SET expires_at=now()-interval '1 hour' WHERE id IN (h,h2);
  INSERT INTO public.topup_executions(id,user_id,sim_line_id,amount,status,wallet_hold_id,execution_type) VALUES(x,u,l,2,'failed',h,'refill_instant');
  INSERT INTO public.topup_executions(user_id,sim_line_id,amount,status,wallet_hold_id,carrier_in_flight) VALUES(u,l,2,'failed',h2,true);
  q:=public.recover_expired_wallet_holds();
  IF (SELECT status FROM public.wallet_holds WHERE id=h)<>'released' OR
    (SELECT status FROM public.wallet_holds WHERE id=h2)<>'active' THEN RAISE EXCEPTION 'Recovery ignored provider state'; END IF;
  q:=public.recover_expired_wallet_holds();
  IF (q->>'released')::integer<>0 OR (q->>'review_required')::integer<>0 THEN RAISE EXCEPTION 'Recovery not idempotent'; END IF;
  IF (SELECT balance FROM public.wallets WHERE user_id=u)<>10 THEN RAISE EXCEPTION 'Recovery mutated posted balance'; END IF;
END;
$$;


DO $$
DECLARE u uuid:=gen_random_uuid(); l uuid:=gen_random_uuid(); r jsonb; q jsonb; o uuid; v_price numeric;
BEGIN
  INSERT INTO auth.users(id,email) VALUES(u,u||'@keepsims.test');
 INSERT INTO public.profiles(id,email) VALUES(u,u||'@keepsims.test');
  INSERT INTO public.sim_lines(id,user_id,phone_number,plan_type,protection_tier,plan_expires_at)
    VALUES(l,u,'+15550000777','standard','standard',now()+interval '1 year');
  PERFORM public.ensure_wallet_v2(u);
  PERFORM public.credit_wallet_for_deposit(u,20,'fixture','paypal_'||u,jsonb_build_object('paypal_capture_id',u::text));
  INSERT INTO public.system_configs(config_key,config_value) VALUES('MEMBERSHIP_FEE_STANDARD_USD','3.00'),('BASE_SERVICE_FEE_USD','1.00')
    ON CONFLICT(config_key) DO UPDATE SET config_value=EXCLUDED.config_value;
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',u,'role','authenticated')::text,true);
  q:=public.quote_sim_setup('+15550000777','standard',NULL,l);
  r:=public.create_sim_setup_order(p_phone_number=>'+15550000777',p_plan=>'standard',p_sim_line_id=>l);
  o:=(r->>'order_id')::uuid;
  IF (q->>'total_charge_usd')::numeric<>3 OR (r->>'total_charge_usd')::numeric<>3 THEN RAISE EXCEPTION 'Standard order and quote diverge'; END IF;
  r:=public.reserve_sim_setup_holds(o);
  IF NOT (r->>'success')::boolean THEN RAISE EXCEPTION 'Actual customer reservation failed'; END IF;
  r:=public.finalize_sim_setup_order(p_order_id=>o);
  IF NOT (r->>'success')::boolean OR (SELECT balance FROM public.wallets WHERE user_id=u)<>17 THEN RAISE EXCEPTION 'Actual customer finalization failed'; END IF;
  INSERT INTO public.esim_offers_cache(bundle_name,provider,countries,country_count,data_amount_mb,is_unlimited,duration_days,
    wholesale_price_usd,is_active) VALUES('fixture-plan','fixture',ARRAY['ZZ'],1,1024,false,7,10,true);
  INSERT INTO public.app_fee_rules(appfees_item,version,free_percentage,free_minimum,stand_percentage,stand_minimum,prem_percentage,prem_minimum,status)
    VALUES('esimofferfee',100000,0,0,0,0,0,0,'published');
  SELECT price_usd INTO v_price FROM public.compare_esim_offers('ZZ') WHERE offer_id='fixture-plan';
  IF v_price<>public.resolve_esim_offer_price(10,u) OR v_price<>10 THEN RAISE EXCEPTION 'eSIM comparison and collection diverge at zero fee'; END IF;
  q:=public.compare_esim_filter_bounds('ZZ');
  IF (q->>'min_price_usd')::numeric<>10 THEN RAISE EXCEPTION 'eSIM bounds disagree with quote'; END IF;
END;
$$;

DO $$
DECLARE u uuid:=gen_random_uuid(); l uuid:=gen_random_uuid(); h_dead uuid; h_retry uuid; h_flight uuid; dead_id uuid:=gen_random_uuid();
  retry_id uuid:=gen_random_uuid(); flight_id uuid:=gen_random_uuid();
BEGIN
  INSERT INTO auth.users(id,email) VALUES(u,u||'@keepsims.test');
 INSERT INTO public.profiles(id,email) VALUES(u,u||'@keepsims.test');
  PERFORM public.ensure_wallet_v2(u);
  PERFORM public.credit_wallet_for_deposit(u,20,'fixture','paypal_'||u,jsonb_build_object('paypal_capture_id',u::text));
  INSERT INTO public.sim_lines(id,user_id,phone_number) VALUES(l,u,'+15550000901');
  h_dead:=public.reserve_wallet_funds(u,2,'refill_instant',dead_id::text);
  h_retry:=public.reserve_wallet_funds(u,2,'refill_instant',retry_id::text);
  h_flight:=public.reserve_wallet_funds(u,2,'refill_instant',flight_id::text);
  INSERT INTO public.topup_executions(id,user_id,sim_line_id,amount,status,wallet_hold_id,reaper_retries,processing_since,pre_processing_status,carrier_in_flight,execution_type)
    VALUES(dead_id,u,l,2,'processing',h_dead,3,now()-interval '20 minutes','pending',false,'refill_instant'),
      (retry_id,u,l,2,'processing',h_retry,0,now()-interval '20 minutes','pending',false,'refill_instant'),
      (flight_id,u,l,2,'processing',h_flight,3,now()-interval '20 minutes','pending',true,'refill_instant');
  PERFORM public.reap_stuck_executions(10,3);
  IF (SELECT status FROM public.wallet_holds WHERE id=h_dead)<>'released'
    OR (SELECT status FROM public.wallet_holds WHERE id=h_retry)<>'active'
    OR (SELECT status FROM public.wallet_holds WHERE id=h_flight)<>'active'
    OR (SELECT status FROM public.topup_executions WHERE id=retry_id)<>'pending' THEN
    RAISE EXCEPTION 'Reaper failed terminal/retry/in-flight reservation rules'; END IF;
END;
$$;

DO $$
DECLARE u uuid:=gen_random_uuid(); l uuid:=gen_random_uuid(); o uuid:=gen_random_uuid(); annual uuid; refill uuid; r jsonb;
BEGIN
  INSERT INTO auth.users(id,email) VALUES(u,u||'@keepsims.test');
 INSERT INTO public.profiles(id,email) VALUES(u,u||'@keepsims.test');
  INSERT INTO public.sim_lines(id,user_id,phone_number,plan_type) VALUES(l,u,'+15550000888','premium');
  PERFORM public.ensure_wallet_v2(u);
  PERFORM public.credit_wallet_for_deposit(u,20,'fixture','paypal_'||u,jsonb_build_object('paypal_capture_id',u::text));
  annual:=public.reserve_wallet_funds(u,5,'plan_fee','setup_fee_'||o::text);
  refill:=public.reserve_wallet_funds(u,1,'setup_refill','setup_refill_'||o::text);
  INSERT INTO public.sim_setup_orders(id,user_id,sim_line_id,plan,phone_number,annual_fee_usd,first_refill_cost_usd,
    total_charge_usd,annual_fee_hold_id,first_refill_hold_id,status)
    VALUES(o,u,l,'premium','+15550000888',5,1,6,annual,refill,'dispatching');
  INSERT INTO public.topup_executions(user_id,sim_line_id,amount,wallet_hold_id,status) VALUES(u,l,1,refill,'failed');
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',u,'role','authenticated')::text,true);
  r:=public.finalize_sim_setup_order(o);
  IF r->>'status'<>'failed' OR (SELECT status FROM public.wallet_holds WHERE id=annual)<>'released'
    OR (SELECT status FROM public.wallet_holds WHERE id=refill)<>'released' THEN RAISE EXCEPTION 'Safe initial failure did not release both holds'; END IF;
  r:=public.fallback_sim_setup_to_reminders(o,l,'standard');
  r:=public.fallback_sim_setup_to_reminders(o,l,'standard');
  IF NOT (r->>'success')::boolean OR (SELECT balance FROM public.wallets WHERE user_id=u)<>20-public.membership_fee_usd('standard')
    OR (SELECT count(*) FROM public.plan_payments WHERE sim_line_id=l)<>1
    OR (SELECT sum(remaining_amount) FROM public.wallet_funding_lots WHERE user_id=u)<>(SELECT balance FROM public.wallets WHERE user_id=u)
    THEN RAISE EXCEPTION 'Standard fallback did not use canonical atomic capture once'; END IF;
END;
$$;

DO $$
DECLARE u uuid:=gen_random_uuid(); l uuid:=gen_random_uuid(); e uuid:=gen_random_uuid(); h uuid; r jsonb;
BEGIN
  INSERT INTO auth.users(id,email) VALUES(u,u||'@keepsims.test');
 INSERT INTO public.profiles(id,email) VALUES(u,u||'@keepsims.test');
  PERFORM public.ensure_wallet_v2(u);
  PERFORM public.credit_wallet_for_deposit(u,10,'fixture','paypal_'||u,jsonb_build_object('paypal_capture_id',u::text));
  INSERT INTO public.sim_lines(id,user_id,phone_number) VALUES(l,u,'+15550000902');
  h:=public.reserve_wallet_funds(u,2,'refill_instant',e::text);
  INSERT INTO public.topup_executions(id,user_id,sim_line_id,status,amount,wallet_hold_id,execution_type,api_provider) VALUES(e,u,l,'processing',2,h,'refill_instant','dtone');
  UPDATE public.wallet_holds SET recovery_contract_version=0 WHERE id=h;
  BEGIN PERFORM public.begin_refill_submission(e,h); RAISE EXCEPTION 'TEST: legacy reservation submitted without reconciliation';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Matching active wallet reservation%' THEN RAISE; END IF; END;
  UPDATE public.wallet_holds SET recovery_contract_version=1 WHERE id=h;
  PERFORM public.begin_refill_submission(e,h);
  BEGIN PERFORM public.begin_refill_submission(e,h); RAISE EXCEPTION 'TEST: in-flight execution resubmitted';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Execution requires reconciliation%' THEN RAISE; END IF; END;
  UPDATE public.wallet_holds SET expires_at=now()-interval '1 hour' WHERE id=h;
  UPDATE public.topup_executions SET status='failed' WHERE id=e;
  PERFORM public.recover_expired_wallet_holds();
  IF (SELECT status FROM public.wallet_holds WHERE id=h)<>'active' THEN RAISE EXCEPTION 'Submitted purchase lost reservation'; END IF;
  r:=public.settle_instant_refill_execution(e,'confirmed-provider',h);
  r:=public.settle_instant_refill_execution(e,'confirmed-provider',h);
  IF (SELECT balance FROM public.wallets WHERE user_id=u)<>8
    OR (SELECT status FROM public.topup_executions WHERE id=e)<>'success'
    OR (SELECT carrier_in_flight FROM public.wallet_holds WHERE id=h) THEN RAISE EXCEPTION 'Worker settlement not atomic/idempotent'; END IF;
END;
$$;

ROLLBACK;
