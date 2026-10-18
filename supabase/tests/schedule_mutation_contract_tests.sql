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


INSERT INTO public.payment_gateways(code,name) VALUES('wallet','Wallet');
INSERT INTO public.carrier_rules(id,carrier_id,minimum_topup_amount,inactivity_limit_days,rule_type,topup_validity_days)
 VALUES('80000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000001',1,30,'prepaid',30);
UPDATE public.sim_lines SET carrier_rule_id='80000000-0000-4000-8000-000000000001',plan_type='premium',protection_tier='premium',plan_expires_at=now()+interval '365 days';
INSERT INTO public.line_plan_grants(sim_line_id,user_id,plan,source,source_key,credit_usd,expires_at,reason)
 SELECT id,user_id,'premium','promotion',id::text,0,now()+interval '365 days','Synthetic approved promotion' FROM public.sim_lines;


-- CASE: existing yearly queues are paused without deleting history or retaining spendable future duplicates
DO $$ BEGIN
 IF (SELECT is_active FROM public.scheduled_topups WHERE id='90000000-0000-4000-8000-000000000001') THEN RAISE EXCEPTION 'Legacy refill stayed active'; END IF;
 IF EXISTS(SELECT 1 FROM public.topup_executions WHERE scheduled_topup_id='90000000-0000-4000-8000-000000000001' AND status IN ('pending','pending_payment')) THEN RAISE EXCEPTION 'Legacy yearly queue remained'; END IF;
 IF (SELECT count(*) FROM public.topup_executions WHERE scheduled_topup_id='90000000-0000-4000-8000-000000000001')<>2 THEN RAISE EXCEPTION 'Legacy history deleted'; END IF;
END $$;

-- CASE: table and historical column grants deny arbitrary schedule mutations for both client roles
DO $$ DECLARE role_name text; BEGIN
 FOREACH role_name IN ARRAY ARRAY['anon','authenticated'] LOOP
 IF has_table_privilege(role_name,'public.scheduled_topups','INSERT,UPDATE,DELETE,TRUNCATE')
 OR has_any_column_privilege(role_name,'public.scheduled_topups','INSERT,UPDATE') THEN RAISE EXCEPTION 'Schedule mutation grant survived'; END IF;
 IF has_function_privilege(role_name,'public.queue_premium_refill_executions(uuid,uuid,timestamptz,timestamptz)','EXECUTE') THEN RAISE EXCEPTION 'Legacy queue callable'; END IF;
 END LOOP;
END $$;
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN UPDATE public.scheduled_topups SET amount=.01,engine_version=99,pricing_tier='premium'; RAISE EXCEPTION 'Direct price mutation'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN INSERT INTO public.scheduled_topups(sim_line_id,user_id,amount,frequency_days,next_execution_at)
 VALUES('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001',.01,1,now()); RAISE EXCEPTION 'Direct insert'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

-- CASE: ordinary customer may save reminders without supplying any authoritative financial fields
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
DO $$ DECLARE a jsonb; b jsonb; BEGIN
 a:=public.save_customer_schedule('20000000-0000-4000-8000-000000000001','notify',14,now()+interval '14 days');
 b:=public.save_customer_schedule('20000000-0000-4000-8000-000000000001','notify',21,now()+interval '21 days');
 IF a->>'id' IS DISTINCT FROM b->>'id' OR (b->>'frequency_days')::int<>21 THEN RAISE EXCEPTION 'Reminder save not idempotent'; END IF;
 IF b->>'user_id'<>'10000000-0000-4000-8000-000000000001' OR b->>'max_authorized_usd' IS NOT NULL THEN RAISE EXCEPTION 'Reminder financial boundary'; END IF;
END $$;

-- CASE: fixed custom schedule derives price tier owner engine and exactly one funded-when-due occurrence
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE a jsonb; sid uuid; BEGIN
 a:=public.save_customer_schedule('20000000-0000-4000-8000-000000000001','refill_custom',14,now()+interval '14 days',true,'fixed',null,2.1);
 sid:=(a->>'id')::uuid;
 PERFORM public.save_customer_schedule('20000000-0000-4000-8000-000000000001','refill_custom',14,now()+interval '14 days',true,'fixed',null,2.1,sid);
 IF (a->>'amount')::numeric<>2.1 OR a->>'pricing_tier'<>'premium' OR (a->>'engine_version')::int<>2 OR (a->>'target_local_value')::numeric<>2 THEN RAISE EXCEPTION 'Untrusted schedule fields %',a; END IF;
 IF (SELECT count(*) FROM public.customer_topup_executions WHERE scheduled_topup_id=sid AND status='pending')<>1 THEN RAISE EXCEPTION 'Duplicate future occurrence'; END IF;
END $$;
RESET ROLE;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.wallet_holds) OR EXISTS(SELECT 1 FROM public.wallet_transactions) THEN RAISE EXCEPTION 'Scheduling claimed prepayment'; END IF;
END $$;

-- CASE: foreign line viewer and anonymous requests cannot create paid schedules
SET LOCAL ROLE anon;
DO $$ BEGIN
 BEGIN PERFORM public.initialize_line_schedules('20000000-0000-4000-8000-000000000001'); RAISE EXCEPTION 'Anonymous scheduling'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
DO $$ BEGIN
 BEGIN PERFORM public.save_customer_schedule('20000000-0000-4000-8000-000000000002','notify',14,now()); RAISE EXCEPTION 'Foreign scheduling'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

-- CASE: mini schedules derive carrier cadence and qualifying offer instead of client frequency or SKU
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
DO $$ DECLARE q jsonb; BEGIN
 q:=public.save_customer_schedule('20000000-0000-4000-8000-000000000001','refill_mini',1,now()+interval '23 days',true,'forged',777,2.1);
 IF (q->>'frequency_days')::int<>23 OR q->>'offer_id'<>'fixed' OR q->>'offer_value' IS NOT NULL
 OR (q->>'amount')::numeric<>2.1 THEN RAISE EXCEPTION 'Client controlled mini pricing/cadence %',q; END IF;
END $$;

-- CASE: range intent retains provider-native dispatch units and major-currency target values
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
DO $$ DECLARE q jsonb; BEGIN
 q:=public.save_customer_schedule('20000000-0000-4000-8000-000000000001','refill_custom',14,now()+interval '14 days',true,'range',777,8);
 IF (q->>'offer_value')::numeric<>777 OR (q->>'target_local_value')::numeric<>7.77 OR (q->>'amount')::numeric<>8 THEN RAISE EXCEPTION 'Range unit mismatch %',q; END IF;
END $$;

-- CASE: unpaid and expired plan labels never authorize automated schedules
UPDATE public.sim_lines SET plan_expires_at=now()-interval '1 day' WHERE id='20000000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
DO $$ BEGIN
 BEGIN PERFORM public.save_customer_schedule('20000000-0000-4000-8000-000000000001','refill_custom',14,now(),true,'fixed',null,2.1); RAISE EXCEPTION 'Expired automation'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
UPDATE public.sim_lines SET plan_expires_at=now()+interval '365 days' WHERE id='20000000-0000-4000-8000-000000000001';
DELETE FROM public.line_plan_grants WHERE sim_line_id='20000000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN PERFORM public.save_customer_schedule('20000000-0000-4000-8000-000000000001','refill_custom',14,now(),true,'fixed',null,2.1); RAISE EXCEPTION 'Unpaid automation'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

-- CASE: invalid authorization ceilings and timestamps cannot save an automatic schedule
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
DO $$ DECLARE cap numeric; BEGIN
 FOREACH cap IN ARRAY ARRAY[0.01::numeric,'NaN'::numeric,'Infinity'::numeric,1001::numeric] LOOP
 BEGIN PERFORM public.save_customer_schedule('20000000-0000-4000-8000-000000000001','refill_custom',14,now(),true,'fixed',null,cap); RAISE EXCEPTION 'Bad ceiling'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 END LOOP;
 BEGIN PERFORM public.save_customer_schedule('20000000-0000-4000-8000-000000000001','notify',14,'infinity'); RAISE EXCEPTION 'Infinite date'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.save_customer_schedule('20000000-0000-4000-8000-000000000001','notify',0,now()); RAISE EXCEPTION 'Zero cadence'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END $$;

-- CASE: accepted managers derive the line owner's schedule and viewers cannot write
INSERT INTO public.household_members(owner_id,member_id,member_email,role,invite_status)
 VALUES('10000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','retail@example.invalid','manager','accepted');
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE q jsonb; BEGIN
 q:=public.save_customer_schedule('20000000-0000-4000-8000-000000000002','notify',14,now());
 IF q->>'user_id'<>'10000000-0000-4000-8000-000000000002' THEN RAISE EXCEPTION 'Manager spoofed schedule owner'; END IF;
END $$;
RESET ROLE;
UPDATE public.household_members SET role='viewer';
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN PERFORM public.save_customer_schedule('20000000-0000-4000-8000-000000000002','notify',14,now()); RAISE EXCEPTION 'Viewer scheduling'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

-- CASE: paused and resumed schedules retain one waiting occurrence and authorized settings
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
DO $$ DECLARE q jsonb; sid uuid; BEGIN
 q:=public.save_customer_schedule('20000000-0000-4000-8000-000000000001','refill_custom',14,now()+interval '14 days',true,'fixed',null,3);
 sid:=(q->>'id')::uuid;
 PERFORM public.set_customer_schedule_active(sid,false);
 IF EXISTS(SELECT 1 FROM public.customer_topup_executions WHERE scheduled_topup_id=sid AND status='pending') THEN RAISE EXCEPTION 'Paused future remained'; END IF;
 PERFORM public.set_customer_schedule_active(sid,true); PERFORM public.set_customer_schedule_active(sid,true);
 IF (SELECT count(*) FROM public.customer_topup_executions WHERE scheduled_topup_id=sid AND status='pending')<>1 THEN RAISE EXCEPTION 'Resume duplicated'; END IF;
END $$;

-- CASE: legacy migration pause cannot be bypassed with a toggle or retired yearly queue API
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
DO $$ BEGIN
 BEGIN PERFORM public.set_customer_schedule_active('90000000-0000-4000-8000-000000000001',true); RAISE EXCEPTION 'Unreviewed restart'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.queue_premium_refill_executions('20000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000001'); RAISE EXCEPTION 'Legacy queue'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
DO $$ BEGIN
 BEGIN PERFORM public.queue_premium_refill_executions('20000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000001'); RAISE EXCEPTION 'Privileged yearly queue'; EXCEPTION WHEN feature_not_supported THEN NULL; END;
END $$;

-- CASE: claimed work remains unchanged during schedule edits and prevents replacement
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
SELECT public.save_customer_schedule('20000000-0000-4000-8000-000000000001','refill_custom',14,now()+interval '14 days',true,'fixed',null,3);
UPDATE public.topup_executions SET status='processing',carrier_in_flight=true WHERE status='pending' AND execution_type='refill_custom';
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 PERFORM public.save_customer_schedule('20000000-0000-4000-8000-000000000001','refill_custom',21,now()+interval '21 days',true,'fixed',null,4);
 IF EXISTS(SELECT 1 FROM public.customer_topup_executions WHERE status='pending' AND execution_type='refill_custom') THEN RAISE EXCEPTION 'Replacement behind claimed operation'; END IF;
 IF (SELECT count(*) FROM public.customer_topup_executions WHERE status='processing')<>1 THEN RAISE EXCEPTION 'Claimed operation erased'; END IF;
END $$;

-- CASE: successful occurrence advances the parent and creates exactly one next occurrence once
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
SELECT public.save_customer_schedule('20000000-0000-4000-8000-000000000001','refill_custom',14,now(),true,'fixed',null,3);
DO $$ DECLARE eid uuid; sid uuid; BEGIN
 SELECT id,scheduled_topup_id INTO eid,sid FROM public.topup_executions WHERE execution_type='refill_custom' AND status='pending';
 UPDATE public.topup_executions SET status='success',completed_at=now() WHERE id=eid;
 UPDATE public.topup_executions SET status='success' WHERE id=eid;
 IF (SELECT count(*) FROM public.topup_executions WHERE scheduled_topup_id=sid AND status='pending')<>1 THEN RAISE EXCEPTION 'Success created duplicate or missing future'; END IF;
 IF (SELECT next_execution_at FROM public.scheduled_topups WHERE id=sid) IS DISTINCT FROM now()+interval '14 days' THEN RAISE EXCEPTION 'Success cadence changed'; END IF;
END $$;

-- CASE: moving the next mini date updates one parent and one waiting occurrence without a yearly batch
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
DO $$ DECLARE q jsonb; eid uuid; BEGIN
 q:=public.save_customer_schedule('20000000-0000-4000-8000-000000000001','refill_mini',1,now()+interval '23 days',true,null,null,3);
 PERFORM public.reschedule_mini_refill('20000000-0000-4000-8000-000000000001',now()+interval '10 days');
 SELECT id INTO eid FROM public.customer_topup_executions WHERE scheduled_topup_id=(q->>'id')::uuid AND status='pending';
 PERFORM public.update_mini_refill_dates('20000000-0000-4000-8000-000000000001',jsonb_build_object(eid::text,now()+interval '11 days'));
 IF (SELECT count(*) FROM public.customer_topup_executions WHERE scheduled_topup_id=(q->>'id')::uuid AND status='pending')<>1 THEN RAISE EXCEPTION 'Date move duplicated'; END IF;
 IF (SELECT execution_time FROM public.customer_topup_executions WHERE scheduled_topup_id=(q->>'id')::uuid AND status='pending') IS DISTINCT FROM now()+interval '11 days' THEN RAISE EXCEPTION 'Date control ignored'; END IF;
END $$;

-- CASE: deleting an unsubmitted schedule cancels its pending occurrence and foreign deletes fail
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
DO $$ DECLARE q jsonb; sid uuid; BEGIN
 q:=public.save_customer_schedule('20000000-0000-4000-8000-000000000001','refill_custom',14,now(),true,'fixed',null,3);sid:=(q->>'id')::uuid;
 PERFORM public.delete_customer_schedule(sid);
 IF EXISTS(SELECT 1 FROM public.customer_scheduled_topups WHERE id=sid) THEN RAISE EXCEPTION 'Delete failed'; END IF;
 IF EXISTS(SELECT 1 FROM public.customer_topup_executions WHERE execution_type='refill_custom' AND status='pending') THEN RAISE EXCEPTION 'Deleted schedule still buys'; END IF;
END $$;

-- CASE: account suspension blocks schedule writes even with a valid prior schedule
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001","app_metadata":{"is_suspended":true}}',true);
DO $$ BEGIN
 BEGIN PERFORM public.save_customer_schedule('20000000-0000-4000-8000-000000000001','notify',14,now()); RAISE EXCEPTION 'Suspended user scheduling'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

-- CASE: old notification payloads may synchronize overdue dates without creating a paid execution
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
DO $$ DECLARE q jsonb; BEGIN
 q:=public.save_customer_schedule('20000000-0000-4000-8000-000000000001','notify',14,now()-interval '2 days');
 IF (q->>'next_execution_at')::timestamptz<>now()-interval '2 days' THEN RAISE EXCEPTION 'Offline reminder lost'; END IF;
 IF EXISTS(SELECT 1 FROM public.customer_topup_executions WHERE status='pending') THEN RAISE EXCEPTION 'Reminder created paid work'; END IF;
END $$;

-- CASE: initialization after upgrade reports missing authorization truthfully and retries never create a batch
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
DO $$ DECLARE a jsonb; b jsonb; BEGIN
 a:=public.initialize_line_schedules('20000000-0000-4000-8000-000000000001');b:=public.initialize_line_schedules('20000000-0000-4000-8000-000000000001');
 IF a<>b OR a->>'needs_authorization'<>'true' THEN RAISE EXCEPTION 'Initialization misstated active protection'; END IF;
 IF EXISTS(SELECT 1 FROM public.customer_topup_executions WHERE status='pending') THEN RAISE EXCEPTION 'Initialization resurrected yearly queue'; END IF;
END $$;

-- CASE: stale reviewed prices fail atomically when the current quote exceeds the ceiling
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
SELECT public.save_customer_schedule('20000000-0000-4000-8000-000000000001','refill_custom',14,now(),true,'fixed',null,2.1);
UPDATE public.provider_offers_cache SET price_fixed_usd=3 WHERE offer_id='fixed';
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN PERFORM public.save_customer_schedule('20000000-0000-4000-8000-000000000001','refill_custom',21,now(),true,'fixed',null,2.1); RAISE EXCEPTION 'Stale price accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 IF (SELECT frequency_days FROM public.customer_scheduled_topups WHERE schedule_type='refill_custom')<>14 THEN RAISE EXCEPTION 'Failed save partially committed'; END IF;
END $$;

-- CASE: foreign deletion is denied and claimed deletion preserves the active parent
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
SELECT public.save_customer_schedule('20000000-0000-4000-8000-000000000001','refill_custom',14,now(),true,'fixed',null,3);
UPDATE public.topup_executions SET status='processing',carrier_in_flight=true WHERE execution_type='refill_custom' AND status='pending';
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000002"}',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE sid uuid; BEGIN
 -- UUID discovery must not grant deletion authority.
 SELECT id INTO sid FROM public.customer_scheduled_topups WHERE schedule_type='refill_custom';
 BEGIN PERFORM public.delete_customer_schedule('90000000-0000-4000-8000-000000000001'); RAISE EXCEPTION 'Foreign delete accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
DO $$ DECLARE sid uuid; blocked boolean:=false; BEGIN
 SELECT id INTO sid FROM public.customer_scheduled_topups WHERE schedule_type='refill_custom';
 BEGIN PERFORM public.delete_customer_schedule(sid); EXCEPTION WHEN raise_exception THEN blocked:=SQLERRM LIKE '%reconciliation%'; END;
 IF NOT blocked OR NOT (SELECT is_active FROM public.customer_scheduled_topups WHERE id=sid) THEN RAISE EXCEPTION 'Unsafe or partial delete'; END IF;
END $$;

-- CASE: legacy provider evidence survives reauthorization and is excluded from worker claims
UPDATE public.topup_executions SET status='pending',carrier_in_flight=true WHERE scheduled_topup_id='90000000-0000-4000-8000-000000000001';
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
SELECT public.save_customer_schedule('20000000-0000-4000-8000-000000000001','refill_mini',23,now(),true,null,null,3);
SET LOCAL ROLE service_role;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.claim_due_executions('refill_mini',10)) THEN RAISE EXCEPTION 'Legacy claim accepted'; END IF;
 IF (SELECT count(*) FROM public.topup_executions WHERE scheduled_topup_id='90000000-0000-4000-8000-000000000001' AND carrier_in_flight)<>2 THEN RAISE EXCEPTION 'Legacy evidence removed'; END IF;
END $$;

-- CASE: admin schedule inspection requires app metadata rather than user metadata
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001","user_metadata":{"is_power_user":true}}',true);
DO $$ BEGIN
 BEGIN PERFORM * FROM public.admin_internal_scheduled_topups; RAISE EXCEPTION 'Forged admin read'; EXCEPTION WHEN SQLSTATE 'KS460' THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001","app_metadata":{"is_power_user":true}}',true);
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.admin_internal_scheduled_topups) THEN RAISE EXCEPTION 'Authorized monitor lost'; END IF;
END $$;

-- CASE: reset date preserves cadence and batch date requests cannot change schedules
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
SELECT public.save_customer_schedule('20000000-0000-4000-8000-000000000001','refill_mini',23,now()+interval '10 days',true,null,null,3);
UPDATE public.sim_lines SET last_topup_at=now()-interval '2 days' WHERE id='20000000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 IF public.reset_mini_refill_to_default('20000000-0000-4000-8000-000000000001')<>now()+interval '21 days' THEN RAISE EXCEPTION 'Reset ignored carrier cadence'; END IF;
 BEGIN PERFORM public.update_mini_refill_dates('20000000-0000-4000-8000-000000000001','{}'); RAISE EXCEPTION 'Empty date edits'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.update_mini_refill_dates('20000000-0000-4000-8000-000000000001','{"00000000-0000-4000-8000-000000000001":"2027-01-01"}'); RAISE EXCEPTION 'Forged occurrence'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

-- CASE: approved initialization retries preserve one occurrence and cannot rewrite schedule identity
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
SET LOCAL ROLE authenticated;
SELECT public.save_customer_schedule('20000000-0000-4000-8000-000000000001','refill_mini',23,now()+interval '23 days',true,null,null,3);
DO $$ DECLARE q jsonb; BEGIN
 q:=public.initialize_line_schedules('20000000-0000-4000-8000-000000000001');
 PERFORM public.initialize_line_schedules('20000000-0000-4000-8000-000000000001');
 IF q->>'needs_authorization'<>'false' OR (SELECT count(*) FROM public.customer_topup_executions WHERE status='pending')<>1 THEN RAISE EXCEPTION 'Approved initialization duplicated or failed'; END IF;
END $$;
RESET ROLE;
DO $$ BEGIN
 BEGIN UPDATE public.scheduled_topups SET user_id='10000000-0000-4000-8000-000000000002' WHERE schedule_type='refill_mini'; RAISE EXCEPTION 'Schedule owner rewritten'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

-- CASE: paid setup settles once and revalidates an existing legacy parent with one next occurrence
INSERT INTO public.system_configs(config_key,config_value) VALUES('MEMBERSHIP_FEE_STANDARD_USD','2.50'),('MEMBERSHIP_FEE_PREMIUM_USD','5.00') ON CONFLICT(config_key) DO UPDATE SET config_value=excluded.config_value;
SELECT set_config('request.jwt.claims','{"role":"service_role","sub":"10000000-0000-4000-8000-000000000001"}',true);
SELECT public.credit_wallet_for_deposit('10000000-0000-4000-8000-000000000001',20,'fixture','paypal_schedule-setup','{"paypal_capture_id":"schedule-setup"}');
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
DO $$ DECLARE o jsonb; oid uuid; d jsonb; eid uuid; hid uuid; q jsonb; sid uuid; BEGIN
 o:=public.create_sim_setup_order(p_phone_number=>(SELECT phone_number FROM public.sim_lines WHERE id='20000000-0000-4000-8000-000000000001'),p_plan=>'premium',p_carrier_rule_id=>'80000000-0000-4000-8000-000000000001',p_sim_line_id=>'20000000-0000-4000-8000-000000000001');
 oid:=(o->>'order_id')::uuid;
 q:=public.reserve_sim_setup_holds(oid);
 IF q->>'success'<>'true' THEN RAISE EXCEPTION 'Setup reservation failed %',q; END IF;
 d:=public.dispatch_sim_setup_verification(oid,'20000000-0000-4000-8000-000000000001');eid:=(d->>'execution_id')::uuid;
 SELECT first_refill_hold_id INTO hid FROM public.sim_setup_orders WHERE id=oid;
 PERFORM public.begin_refill_submission(eid,hid);
 PERFORM public.settle_instant_refill_execution(eid,'synthetic-schedule-setup',hid);
 BEGIN
  DELETE FROM public.provider_offers_cache WHERE offer_id='fixed';
  PERFORM public.finalize_sim_setup_order(oid,'20000000-0000-4000-8000-000000000001');
  RAISE EXCEPTION 'Missing future units accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM NOT LIKE 'Future refill target unavailable%' THEN RAISE; END IF; END;
 q:=public.finalize_sim_setup_order(oid,'20000000-0000-4000-8000-000000000001');
 IF q->>'success'<>'true' THEN RAISE EXCEPTION 'Setup finalizer failed %',q; END IF;
 PERFORM public.finalize_sim_setup_order(oid);
 SELECT id INTO sid FROM public.scheduled_topups WHERE sim_line_id='20000000-0000-4000-8000-000000000001' AND schedule_type='refill_mini';
 IF sid<>'90000000-0000-4000-8000-000000000001' OR (SELECT schedule_contract_version FROM public.scheduled_topups WHERE id=sid)<>1 THEN RAISE EXCEPTION 'Setup did not revalidate existing schedule'; END IF;
 IF (SELECT count(*) FROM public.topup_executions WHERE scheduled_topup_id=sid AND status='pending')<>1 THEN RAISE EXCEPTION 'Setup queued multiple future refills'; END IF;
 IF (SELECT count(*) FROM public.wallet_transactions WHERE type IN ('plan_fee_debit','topup_debit'))<>2 THEN RAISE EXCEPTION 'Setup retry charged again'; END IF;
 IF (SELECT target_local_value FROM public.scheduled_topups WHERE id=sid)<>2 OR (SELECT offer_value FROM public.scheduled_topups WHERE id=sid) IS NOT NULL THEN RAISE EXCEPTION 'Setup future intent units are unsafe'; END IF;
END $$;
