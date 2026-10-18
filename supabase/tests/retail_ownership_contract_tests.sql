-- Synthetic customer identities and offers; no customer or provider data.
INSERT INTO auth.users(id,email) VALUES
 ('10000000-0000-4000-8000-000000000001','retail@example.invalid'),('10000000-0000-4000-8000-000000000002','foreign@example.invalid');
INSERT INTO public.profiles(id,email) SELECT id,email FROM auth.users;
INSERT INTO public.countries(id,name,iso_code,dialing_code,currency_code) VALUES
 ('30000000-0000-4000-8000-000000000001','Fixture','ZZ','+999','USD');
INSERT INTO public.carriers(id,name,country_id) VALUES
 ('40000000-0000-4000-8000-000000000001','Fixture','30000000-0000-4000-8000-000000000001');
INSERT INTO public.sim_lines(id,user_id,phone_number,country_id,carrier_id) VALUES
 ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','+15550000001','30000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000001'),
 ('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002','+15550000002','30000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000001');
INSERT INTO public.app_fee_rules(appfees_item,version,free_percentage,free_minimum,stand_percentage,stand_minimum,prem_percentage,prem_minimum,status)
 VALUES('refills',9999998,7,.50,5,.30,3,.10,'published'),('esimofferfee',9999998,10,0,7,0,5,0,'published'),('intelcallfee',9999998,15,0,10,0,5,0,'published');
INSERT INTO public.carrier_provider_map(carrier_id,provider,provider_country_code,provider_carrier_code,is_enabled,provider_country_label,provider_carrier_label)
 VALUES('40000000-0000-4000-8000-000000000001','dtone','ZZ','fixture',true,'Fixture','Fixture');
INSERT INTO public.service_providers(code,name,is_active,supports_topup) VALUES('dtone','Fixture',true,true);
INSERT INTO public.supplier_policy(provider,is_globally_enabled) VALUES('dtone',true);
INSERT INTO public.provider_offers_cache(api_provider,offer_id,country_code,carrier_code,price_type,price_fixed_usd,source_amount_native,send_min,send_max,send_currency)
 VALUES('dtone','fixed','ZZ','fixture','FIXED',2,200,200,200,'USD');
INSERT INTO public.provider_offers_cache(api_provider,offer_id,country_code,carrier_code,price_type,price_min_usd,price_max_usd,send_min,send_max,send_currency)
 VALUES('dtone','range','ZZ','fixture','RANGE',1,20,100,2000,'USD');
INSERT INTO public.provider_offers(provider_code,offer_kind,offer_code,country_code,carrier_id,source_price_usd,source_price_type,source_price_min_usd,source_price_max_usd,source_send_min,source_send_max,source_send_currency,source_name)
 VALUES('dtone','topup','fixed','ZZ','40000000-0000-4000-8000-000000000001',2,'FIXED',null,null,200,200,'USD','Fixture');
INSERT INTO public.service_providers(code,name) VALUES('fixture','Fixture');
INSERT INTO public.esim_suppliers(code,name) VALUES('fixture','Fixture');
INSERT INTO public.esim_offers_cache(provider,bundle_name,description,countries,roaming_enabled,data_amount_mb,duration_days,wholesale_price_usd)
 VALUES('fixture','bundle','Fixture',ARRAY['ZZ'],ARRAY['ZZ'],1024,7,2);
INSERT INTO public.esim_orders(id,user_id,provider,bundle_name,quantity,wholesale_price_usd,retail_price_usd,markup_percent,status,provider_order_ref,error_message,total_amount_usd)
 VALUES('50000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','fixture','bundle',1,2,2.2,10,'completed','SECRET-REFERENCE','SECRET-PROVIDER-ERROR',2.2),
 ('50000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002','fixture','bundle',1,2,2.2,10,'completed','SECRET-REFERENCE','SECRET-PROVIDER-ERROR',2.2);
INSERT INTO public.return_trip_packages(id,country_id,package_type,title,data_allowance_mb,duration_days,supplier_cost_usd,retail_price_usd)
 VALUES('60000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','esim','Fixture',1024,7,1,2),
 ('60000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000001','esim','Other',1024,7,2,4);
INSERT INTO public.call_rates(country_code,country_name,phone_prefix,destination_type,rate_per_minute_usd,cost_per_minute_usd)
 VALUES('ZZ','Fixture','+999','all',.02,.01);

-- CASE: anonymous and customer wholesale paths are denied, including column grants
DO $$ DECLARE r text; c text; BEGIN
 FOREACH r IN ARRAY ARRAY['provider_offers','provider_offers_cache','provider_offers_effective','zendit_offers_cache','esim_offers_cache','esim_suppliers','return_trip_packages'] LOOP
  FOREACH c IN ARRAY ARRAY['anon','authenticated'] LOOP
   IF has_any_column_privilege(c,'public.'||r,'SELECT') OR has_table_privilege(c,'public.'||r,'SELECT') THEN RAISE EXCEPTION 'Leaked % to %',r,c; END IF;
  END LOOP;
  IF NOT has_table_privilege('service_role','public.'||r,'SELECT') THEN RAISE EXCEPTION 'Backend lost %',r; END IF;
 END LOOP;
END $$;
SET ROLE authenticated;
DO $$ BEGIN
 BEGIN PERFORM * FROM public.provider_offers_effective; RAISE EXCEPTION 'view leaked'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM * FROM public.zendit_offers_cache; RAISE EXCEPTION 'fallback leaked'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM wholesale_price_usd FROM public.esim_orders; RAISE EXCEPTION 'order cost leaked'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM cost_per_minute_usd FROM public.call_rates; RAISE EXCEPTION 'calling cost leaked'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;

-- CASE: customer catalogue view works without supplier base privileges and uses canonical retail
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
DO $$ DECLARE q jsonb; BEGIN
 SELECT to_jsonb(o) INTO q FROM public.esim_offers o WHERE bundle_name='bundle';
 IF (q->>'retail_price_usd')::numeric<>2.2 OR q ? 'wholesale_price_usd' OR q ? 'markup_percent' THEN RAISE EXCEPTION 'Bad retail catalogue %',q; END IF;
 IF (q->>'price_per_gb_usd')::numeric<>2.2 THEN RAISE EXCEPTION 'Bad price per GB'; END IF;
END $$;

-- CASE: owned eSIM receipt is retail-only and foreign receipts are invisible
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
DO $$ DECLARE q jsonb; BEGIN
 IF (SELECT count(*) FROM public.customer_esim_orders)<>1 THEN RAISE EXCEPTION 'Foreign receipt visible'; END IF;
 SELECT to_jsonb(o) INTO q FROM public.customer_esim_orders o LIMIT 1;
 IF q ?| ARRAY['wholesale_price_usd','markup_percent','provider_order_ref'] OR q->>'error_message' IS NOT NULL OR (q->>'retail_price_usd')::numeric<>2.2 THEN RAISE EXCEPTION 'Unsafe receipt %',q; END IF;
 BEGIN PERFORM * FROM public.esim_orders; RAISE EXCEPTION 'SELECT star leaked supplier fields'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

-- CASE: arbitrary user entitlement and supplier quote helpers are not customer APIs
DO $$ DECLARE sig text; r text; BEGIN
 FOREACH sig IN ARRAY ARRAY['resolve_line_entitlement(uuid)','resolve_account_commerce_benefit(uuid)','has_paid_premium_entitlement(uuid)',
   'line_paid_plan_evidence(uuid,text)','resolve_esim_offer_price(numeric,uuid)','get_authoritative_refill_quote(uuid,numeric,text,text,text)',
   'choose_supplier_for_offer(uuid,text,text[])','supplier_candidates(uuid,text,text[])','carrier_refill_offer(uuid,numeric)',
   'selected_refill_quote_internal(uuid,text,numeric)','pick_best_refill_offer(uuid,numeric)','request_instant_refill(uuid,text,text,numeric,text)'] LOOP
  FOREACH r IN ARRAY ARRAY['anon','authenticated'] LOOP
   IF has_function_privilege(r,'public.'||sig,'EXECUTE') THEN RAISE EXCEPTION 'Unsafe % grant for %',sig,r; END IF;
  END LOOP;
  IF NOT has_function_privilege('service_role','public.'||sig,'EXECUTE') THEN RAISE EXCEPTION 'Lost backend helper %',sig; END IF;
 END LOOP;
END $$;
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN PERFORM public.resolve_line_entitlement('20000000-0000-4000-8000-000000000002'); RAISE EXCEPTION 'Foreign entitlement leaked'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

-- CASE: anonymous personalized RPCs and retail views are denied
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims','{"role":"anon"}',true);
DO $$ BEGIN
 BEGIN PERFORM * FROM public.esim_offers; RAISE EXCEPTION 'Anonymous view'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.get_customer_refill_quote('20000000-0000-4000-8000-000000000001','fixed'); RAISE EXCEPTION 'Anonymous quote'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.get_return_trip_packages_for_line('20000000-0000-4000-8000-000000000001'); RAISE EXCEPTION 'Anonymous packages'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

-- CASE: foreign line quote, refill catalogue and all trip APIs reject forged ownership
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
DO $$ BEGIN
 BEGIN PERFORM public.get_customer_refill_quote('20000000-0000-4000-8000-000000000002','fixed'); RAISE EXCEPTION 'Foreign quote'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.list_refill_offers('20000000-0000-4000-8000-000000000002'); RAISE EXCEPTION 'Foreign offers'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.get_return_trip_packages_for_line('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002'); RAISE EXCEPTION 'Foreign packages'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.get_active_return_trip_for_line('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002'); RAISE EXCEPTION 'Foreign active trip'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.get_return_trip_history_for_line('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002'); RAISE EXCEPTION 'Foreign history'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

-- CASE: line and add-line catalogues expose retail totals including range endpoints
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
DO $$ DECLARE q jsonb; BEGIN
 SELECT to_jsonb(o) INTO q FROM public.list_refill_offers('20000000-0000-4000-8000-000000000001') o WHERE offer_id='fixed';
 IF (q->>'price_fixed_usd')::numeric<>2.5 OR q ? 'base_cost_usd' THEN RAISE EXCEPTION 'Fixed catalogue leak %',q; END IF;
 SELECT to_jsonb(o) INTO q FROM public.list_refill_offers('20000000-0000-4000-8000-000000000001') o WHERE offer_id='range';
 IF (q->>'price_min_usd')::numeric<>1.5 OR (q->>'price_max_usd')::numeric<>21.4 THEN RAISE EXCEPTION 'Range catalogue leak %',q; END IF;
 SELECT to_jsonb(o) INTO q FROM public.list_carrier_offers('40000000-0000-4000-8000-000000000001') o WHERE offer_id='fixed';
 IF (q->>'price_usd')::numeric<>2.5 THEN RAISE EXCEPTION 'Add-line catalogue leak %',q; END IF;
END $$;

-- CASE: selected fixed and range quotes allowlist retail output and compute the exact value
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
DO $$ DECLARE q jsonb; BEGIN
 q:=public.get_customer_refill_quote('20000000-0000-4000-8000-000000000001','fixed');
 IF (q->>'total_charge_usd')::numeric<>2.5 OR q - ARRAY['offer_id','offer_value','total_charge_usd','currency','pricing_tier','quote_created_at']<>'{}'::jsonb THEN RAISE EXCEPTION 'Quote leaked %',q; END IF;
 q:=public.get_customer_refill_quote('20000000-0000-4000-8000-000000000001','range',777);
 IF (q->>'total_charge_usd')::numeric<>8.31 OR (q->>'offer_value')::numeric<>777 THEN RAISE EXCEPTION 'Range quote wrong %',q; END IF;
END $$;

-- CASE: bad, missing and stale selected offer values fail without a quote or execution
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
DO $$ BEGIN
 BEGIN PERFORM public.get_customer_refill_quote('20000000-0000-4000-8000-000000000001','range',99); RAISE EXCEPTION 'Bad value accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'Invalid refill value' THEN RAISE; END IF; END;
 BEGIN PERFORM public.get_customer_refill_quote('20000000-0000-4000-8000-000000000001','missing'); RAISE EXCEPTION 'Missing accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'Offer pricing unavailable' THEN RAISE; END IF; END;
 UPDATE public.provider_offers_cache SET refreshed_at=now()-interval '25 hours';
 BEGIN PERFORM public.get_customer_refill_quote('20000000-0000-4000-8000-000000000001','fixed'); RAISE EXCEPTION 'Stale accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'Offer pricing unavailable' THEN RAISE; END IF; END;
END $$;

-- CASE: calling RPCs and fallback contain only retail pricing and reject foreign accounts
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
DO $$ DECLARE q jsonb; BEGIN
 SELECT to_jsonb(o) INTO q FROM public.get_call_rate_for_number('+999123') o;
 IF q ? 'cost_per_minute_usd' OR (q->>'rate_per_minute_usd')::numeric<>.0115 THEN RAISE EXCEPTION 'Call price leaked %',q; END IF;
 PERFORM rate_per_minute_usd FROM public.call_rates;
 BEGIN PERFORM public.get_user_calling_rates('10000000-0000-4000-8000-000000000002'); RAISE EXCEPTION 'Foreign calling benefit'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

-- CASE: accepted active and historical trip prices survive catalogue changes
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
INSERT INTO public.return_trips(user_id,sim_line_id,destination_country_id,arrival_date,status,chosen_package_type,chosen_package_id)
 VALUES('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001',current_date,'planning','esim','60000000-0000-4000-8000-000000000001');
UPDATE public.return_trip_packages SET retail_price_usd=99;
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 IF (SELECT effective_price_usd FROM public.get_active_return_trip_for_line('20000000-0000-4000-8000-000000000001'))<>2 THEN RAISE EXCEPTION 'Active trip repriced'; END IF;
 IF (SELECT effective_price_usd FROM public.get_return_trip_history_for_line('20000000-0000-4000-8000-000000000001'))<>2 THEN RAISE EXCEPTION 'History repriced'; END IF;
 UPDATE public.return_trips SET accepted_price_usd=.01;
 IF (SELECT accepted_price_usd FROM public.return_trips)<>2 THEN RAISE EXCEPTION 'Price changed'; END IF;
 UPDATE public.return_trips SET status='arrived';
 BEGIN UPDATE public.return_trips SET status='planning'; RAISE EXCEPTION 'History reopened for repricing'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN UPDATE public.return_trips SET chosen_package_id='60000000-0000-4000-8000-000000000002'; RAISE EXCEPTION 'Accepted package changed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

-- CASE: legacy unknown trip prices remain unknown and cross-line direct writes fail
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
INSERT INTO public.return_trips(user_id,sim_line_id,destination_country_id,arrival_date,status,chosen_package_type,chosen_package_id)
 VALUES('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001',current_date,'completed','esim','60000000-0000-4000-8000-000000000001');
ALTER TABLE public.return_trips DISABLE TRIGGER guard_return_trip_contract;
UPDATE public.return_trips SET accepted_price_usd=null;
ALTER TABLE public.return_trips ENABLE TRIGGER guard_return_trip_contract;
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.get_return_trip_history_for_line('20000000-0000-4000-8000-000000000001') WHERE effective_price_usd IS NOT NULL) THEN RAISE EXCEPTION 'Legacy price invented'; END IF;
 BEGIN INSERT INTO public.return_trips(user_id,sim_line_id,destination_country_id,arrival_date,status)
   VALUES('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000001',current_date,'planning'); RAISE EXCEPTION 'Foreign line accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

-- CASE: adjacent receipt projections deny supplier cost, raw CDR and fee decomposition
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 PERFORM * FROM public.customer_call_records;
 PERFORM * FROM public.customer_topup_executions;
 PERFORM * FROM public.customer_scheduled_topups;
 BEGIN PERFORM raw_cdr FROM public.call_records; RAISE EXCEPTION 'CDR leaked'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM base_cost_usd FROM public.topup_executions; RAISE EXCEPTION 'Execution cost leaked'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM base_cost_usd FROM public.scheduled_topups; RAISE EXCEPTION 'Schedule cost leaked'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

-- CASE: admin supplier views require server app-metadata authorization even when user metadata is forged
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001","user_metadata":{"is_power_user":true}}',true);
DO $$ BEGIN
 BEGIN PERFORM * FROM public.admin_internal_provider_offers; RAISE EXCEPTION 'Ordinary user accessed admin catalogue'; EXCEPTION WHEN SQLSTATE 'KS460' THEN NULL; END;
 BEGIN PERFORM * FROM public.admin_internal_provider_offers_cache; RAISE EXCEPTION 'Ordinary user accessed raw cache'; EXCEPTION WHEN SQLSTATE 'KS460' THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001","app_metadata":{"is_power_user":true}}',true);
DO $$ BEGIN
 IF (SELECT count(*) FROM public.admin_internal_provider_offers)<>1 THEN RAISE EXCEPTION 'Admin catalogue unavailable'; END IF;
 IF (SELECT price_fixed_usd FROM public.admin_internal_provider_offers_cache WHERE offer_id='fixed')<>2 THEN RAISE EXCEPTION 'Admin lost supplier data'; END IF;
 PERFORM * FROM public.admin_internal_topup_executions;
END $$;

-- CASE: retail refill authorization rejects changed totals without creating an execution
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
DO $$ BEGIN
 BEGIN PERFORM public.request_retail_instant_refill('20000000-0000-4000-8000-000000000001','fixed',2.49); RAISE EXCEPTION 'Low ceiling accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Refill pricing or authorization changed%' THEN RAISE; END IF; END;
 IF EXISTS(SELECT 1 FROM public.customer_topup_executions) THEN RAISE EXCEPTION 'Failed authorization queued'; END IF;
END $$;

-- CASE: internal suppliers and paid entitlements still work for the backend
SET LOCAL ROLE service_role;
SELECT set_config('request.jwt.claims','{"role":"service_role"}',true);
DO $$ DECLARE q jsonb; BEGIN
 IF (SELECT wholesale_price_usd FROM public.esim_offers_cache LIMIT 1)<>2 THEN RAISE EXCEPTION 'Supplier eSIM cost lost'; END IF;
 IF (SELECT source_price_usd FROM public.provider_offers LIMIT 1)<>2 THEN RAISE EXCEPTION 'Supplier cost lost'; END IF;
 q:=public.resolve_line_entitlement('20000000-0000-4000-8000-000000000001');
 IF (q->>'found')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'Backend entitlement unavailable'; END IF;
 q:=public.get_authoritative_refill_quote('20000000-0000-4000-8000-000000000001',200,'USD','fixed','dtone');
 IF (q->>'wholesale_cost_usd')::numeric<>2 OR (q->>'total_charge_usd')::numeric<>2.5 THEN RAISE EXCEPTION 'Backend quote changed %',q; END IF;
END $$;

-- CASE: fixed and exact range submissions authorize retail totals and retain internal supplier costs
INSERT INTO public.payment_gateways(code,name) VALUES('wallet','Wallet');
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE eid uuid; BEGIN
 eid:=public.request_retail_instant_refill('20000000-0000-4000-8000-000000000001','fixed',2.5);
 IF NOT EXISTS(SELECT 1 FROM public.customer_topup_executions WHERE id=eid AND amount=2.5) THEN RAISE EXCEPTION 'Fixed retail charge wrong'; END IF;
 eid:=public.request_retail_instant_refill('20000000-0000-4000-8000-000000000001','range',8.31,777);
 IF NOT EXISTS(SELECT 1 FROM public.customer_topup_executions WHERE id=eid AND amount=8.31 AND offer_value=777) THEN RAISE EXCEPTION 'Range value drifted'; END IF;
END $$;
RESET ROLE;
DO $$ BEGIN
 IF (SELECT base_cost_usd FROM public.topup_executions WHERE offer_id='fixed')<>2 THEN RAISE EXCEPTION 'Supplier cost changed'; END IF;
 IF (SELECT base_cost_usd FROM public.topup_executions WHERE offer_id='range')<>7.77 THEN RAISE EXCEPTION 'Range cost wrong'; END IF;
END $$;

-- CASE: published zero refill fees and repeated quote reads preserve retail prices without writes
UPDATE public.app_fee_rules SET free_percentage=0,free_minimum=0,stand_percentage=0,stand_minimum=0,prem_percentage=0,prem_minimum=0 WHERE appfees_item='refills' AND version=9999998;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
DO $$ DECLARE a jsonb; b jsonb; BEGIN
 a:=public.get_customer_refill_quote('20000000-0000-4000-8000-000000000001','fixed');
 b:=public.get_customer_refill_quote('20000000-0000-4000-8000-000000000001','fixed');
 IF (a->>'total_charge_usd')::numeric<>2 OR a<>b THEN RAISE EXCEPTION 'Zero fee or retry changed'; END IF;
 IF EXISTS(SELECT 1 FROM public.customer_topup_executions) THEN RAISE EXCEPTION 'Reading quote performed a mutation'; END IF;
END $$;

-- CASE: only an accepted household manager may read a shared line retail quote
INSERT INTO public.household_members(owner_id,member_id,member_email,role,invite_status)
 VALUES('10000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','retail@example.invalid','manager','accepted');
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 IF (public.get_customer_refill_quote('20000000-0000-4000-8000-000000000002','fixed')->>'total_charge_usd')::numeric<>2.5 THEN RAISE EXCEPTION 'Shared quote unavailable'; END IF;
END $$;
RESET ROLE;
UPDATE public.household_members SET role='viewer';
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN PERFORM public.get_customer_refill_quote('20000000-0000-4000-8000-000000000002','fixed'); RAISE EXCEPTION 'Viewer pricing allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

-- CASE: public RPC return signatures contain no supplier cost or margin fields after containment
DO $$ DECLARE sig text; shape text; BEGIN
 FOREACH sig IN ARRAY ARRAY['get_return_trip_packages_for_line(uuid,uuid)','get_call_rate_for_number(text,uuid)','get_user_calling_rates(uuid)'] LOOP
  SELECT pg_get_function_result(to_regprocedure('public.'||sig)) INTO shape;
  IF shape~'(supplier_cost|cost_per_minute|app_fee|margin|override_note)' THEN RAISE EXCEPTION 'Unsafe shape % %',sig,shape; END IF;
 END LOOP;
END $$;

-- CASE: approval quote route and setup snapshots cannot disclose supplier information
INSERT INTO public.topup_executions(id,sim_line_id,user_id,amount,execution_type,status,execution_time)
 VALUES('70000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001',2.5,'refill_custom','awaiting_approval',now());
INSERT INTO public.refill_approval_quotes(execution_id,requested_by,execution_snapshot,status,route,error_message)
 VALUES('70000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','{}','ready',
 '{"costUsd":2,"feeUsd":0.5,"totalChargeUsd":2.5,"provider":"dtone","targetLocalValue":200,"targetLocalCurrency":"USD"}','SECRET-SUPPLIER-ERROR');
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE q jsonb; BEGIN
 SELECT to_jsonb(v) INTO q FROM public.customer_refill_approval_quotes v;
 IF q->'route' ?| ARRAY['costUsd','feeUsd','provider'] OR q->>'error_message' IS NOT NULL OR (q->'route'->>'totalChargeUsd')::numeric<>2.5 THEN RAISE EXCEPTION 'Approval route leaked %',q; END IF;
 BEGIN PERFORM route FROM public.refill_approval_quotes; RAISE EXCEPTION 'Raw approval leaked'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM pricing_snapshot FROM public.sim_setup_orders; RAISE EXCEPTION 'Setup snapshot leaked'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000002"}',true);
DO $$ BEGIN IF EXISTS(SELECT 1 FROM public.customer_refill_approval_quotes) THEN RAISE EXCEPTION 'Foreign quote visible'; END IF; END $$;

-- CASE: insertion price drift rolls back the execution and never exposes supplier error details
INSERT INTO public.payment_gateways(code,name) VALUES('wallet','Wallet');
CREATE FUNCTION public.zz_retail_test_drift() RETURNS trigger LANGUAGE plpgsql AS $$
 BEGIN NEW.amount:=99; RETURN NEW; END $$;
CREATE TRIGGER zz_retail_test_drift BEFORE INSERT ON public.topup_executions FOR EACH ROW EXECUTE FUNCTION public.zz_retail_test_drift();
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN PERFORM public.request_retail_instant_refill('20000000-0000-4000-8000-000000000001','fixed',2.5);
   RAISE EXCEPTION 'Drift accepted';
 EXCEPTION WHEN SQLSTATE '22023' THEN
   IF SQLERRM<>'Refill pricing or authorization changed. Review a fresh quote.' THEN RAISE EXCEPTION 'Unsafe price error'; END IF;
 END;
 IF EXISTS(SELECT 1 FROM public.customer_topup_executions) THEN RAISE EXCEPTION 'Drift left an execution'; END IF;
END $$;

-- CASE: fractional fixed supplier costs keep catalogue, retail quote and actual execution totals equal
INSERT INTO public.payment_gateways(code,name) VALUES('wallet','Wallet');
UPDATE public.provider_offers_cache SET price_fixed_usd=14.2143 WHERE offer_id='fixed';
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE q jsonb; eid uuid; catalogue numeric; BEGIN
 SELECT price_fixed_usd INTO catalogue FROM public.list_refill_offers('20000000-0000-4000-8000-000000000001') WHERE offer_id='fixed';
 q:=public.get_customer_refill_quote('20000000-0000-4000-8000-000000000001','fixed');
 IF catalogue<>15.21 OR (q->>'total_charge_usd')::numeric<>catalogue THEN RAISE EXCEPTION 'Fractional quote drifted: catalogue %, quote %',catalogue,q; END IF;
 eid:=public.request_retail_instant_refill('20000000-0000-4000-8000-000000000001','fixed',catalogue);
 IF (SELECT amount FROM public.customer_topup_executions WHERE id=eid)<>catalogue THEN RAISE EXCEPTION 'Fractional submission drifted'; END IF;
END $$;
