CREATE TABLE esim_private.automation_consents(
 profile_id uuid PRIMARY KEY REFERENCES public.user_esims(id),owner_id uuid NOT NULL,payer_id uuid NOT NULL,
 revision integer NOT NULL DEFAULT 1,enabled boolean NOT NULL DEFAULT false,package_id text NOT NULL,
 trigger_kind text NOT NULL CHECK(trigger_kind IN('fixed_low_data','daily_near_expiry')),
 reviewed_charge numeric(12,2) NOT NULL CHECK(reviewed_charge>0),max_charge numeric(12,2) NOT NULL CHECK(max_charge>0),monthly_cap numeric(12,2) NOT NULL CHECK(monthly_cap>=max_charge),
 threshold integer NOT NULL CHECK(threshold BETWEEN 1 AND 168),period_count integer CHECK(period_count BETWEEN 1 AND 365),
 minimum_interval_hours integer NOT NULL CHECK(minimum_interval_hours BETWEEN 1 AND 720),
 ends_at timestamptz,device_id text,stop_reason text,next_check_at timestamptz NOT NULL DEFAULT now(),
 last_order_at timestamptz,created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK(owner_id=payer_id),CHECK((trigger_kind='fixed_low_data' AND threshold<=50 AND period_count IS NULL) OR (trigger_kind='daily_near_expiry' AND period_count IS NOT NULL))
);
CREATE INDEX esim_automation_due ON esim_private.automation_consents(next_check_at) WHERE enabled;
CREATE INDEX esim_automation_owner ON esim_private.automation_consents(owner_id);
CREATE TABLE esim_private.automation_orders(
 order_id uuid PRIMARY KEY REFERENCES public.esim_orders(id),profile_id uuid NOT NULL REFERENCES public.user_esims(id),
 consent_revision integer NOT NULL,cycle_key text NOT NULL,amount numeric(12,2) NOT NULL CHECK(amount>0),created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(profile_id,cycle_key)
);
CREATE TABLE esim_private.automation_audit(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),profile_id uuid NOT NULL REFERENCES public.user_esims(id),
 revision integer NOT NULL,event text NOT NULL,created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX esim_automation_audit_profile ON esim_private.automation_audit(profile_id,created_at);
CREATE FUNCTION esim_private.automation_exposure(pid uuid) RETURNS numeric LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT coalesce(sum(a.amount),0) FROM esim_private.automation_orders a JOIN esim_private.order_runs r ON r.order_id=a.order_id
 WHERE a.profile_id=pid AND r.state<>'failed' AND (a.created_at>=date_trunc('month',now() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC'
 OR r.state NOT IN('completed','failed'));
$$;
CREATE FUNCTION public.get_esim_automation(p_profile_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid();c esim_private.automation_consents;
BEGIN
 PERFORM esim_private.require_live_owner(u);
 IF NOT EXISTS(SELECT 1 FROM public.user_esims WHERE id=p_profile_id AND user_id=u) THEN RETURN '{"status":"PROFILE_UNAVAILABLE"}'::jsonb; END IF;
 SELECT * INTO c FROM esim_private.automation_consents WHERE profile_id=p_profile_id AND owner_id=u;
 RETURN jsonb_build_object('status','READY','consent',CASE WHEN c.profile_id IS NULL THEN NULL ELSE to_jsonb(c)-'device_id'-'next_check_at' END,
 'exposure',esim_private.automation_exposure(p_profile_id),'currency','USD','cap_period','UTC calendar month',
 'available',coalesce((SELECT automation_enabled FROM esim_private.accounts a JOIN public.user_esims p ON p.supplier_account_id=a.id WHERE p.id=p_profile_id),false),
 'audit',coalesce((SELECT jsonb_agg(to_jsonb(x)) FROM (SELECT revision,event,created_at FROM esim_private.automation_audit WHERE profile_id=p_profile_id ORDER BY created_at DESC LIMIT 30) x),'[]'::jsonb));
END $$;
CREATE FUNCTION public.set_esim_automation(p_profile_id uuid,p_expected_revision integer,p_enabled boolean,p_settings jsonb DEFAULT NULL,p_device_id text DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid();p public.user_esims;c esim_private.automation_consents;pkg jsonb;max_amt numeric;cap numeric;trigger_value text;days integer;threshold_value integer;hours integer;end_value timestamptz;reviewed numeric;price esim_private.daily_prices;daily_cache esim_private.topup_cache;
BEGIN
 PERFORM esim_private.require_money_session(u);
 PERFORM 1 FROM public.wallets WHERE user_id=u FOR UPDATE;
 SELECT * INTO p FROM public.user_esims WHERE id=p_profile_id AND user_id=u FOR UPDATE;
 IF NOT FOUND THEN RETURN '{"status":"PROFILE_UNAVAILABLE"}'::jsonb; END IF;
 SELECT * INTO c FROM esim_private.automation_consents WHERE profile_id=p.id FOR UPDATE;
 IF p_expected_revision IS DISTINCT FROM coalesce(c.revision,0) THEN RETURN '{"status":"CONSENT_CHANGED"}'::jsonb; END IF;
 IF p_enabled IS NULL THEN RETURN '{"status":"INVALID_REQUEST"}'::jsonb; END IF;
 IF NOT p_enabled THEN
  UPDATE esim_private.automation_consents SET enabled=false,revision=revision+1,stop_reason='WITHDRAWN',updated_at=now() WHERE profile_id=p.id;
  INSERT INTO esim_private.automation_audit(profile_id,revision,event) VALUES(p.id,coalesce(c.revision,0)+1,'WITHDRAWN');
  RETURN '{"status":"PAUSED"}'::jsonb;
 END IF;
 IF NOT EXISTS(SELECT 1 FROM esim_private.accounts WHERE id=p.supplier_account_id AND automation_enabled AND recharge_enabled AND recharge_contract_verified AND wallet_boundary_verified) THEN RETURN '{"status":"AUTOMATION_DISABLED"}'::jsonb; END IF;
 IF esim_private.topup_refusal(p) IS NOT NULL THEN RETURN jsonb_build_object('status',esim_private.topup_refusal(p)); END IF;
 IF jsonb_typeof(p_settings) IS DISTINCT FROM 'object' OR EXISTS(SELECT 1 FROM jsonb_object_keys(p_settings) k WHERE k NOT IN('package_id','trigger','max_charge','monthly_cap','threshold','period_count','minimum_interval_hours','ends_at')) THEN RETURN '{"status":"INVALID_REQUEST"}'::jsonb; END IF;
 trigger_value:=p_settings->>'trigger';max_amt:=(p_settings->>'max_charge')::numeric;cap:=(p_settings->>'monthly_cap')::numeric;
 days:=(p_settings->>'period_count')::integer;threshold_value:=(p_settings->>'threshold')::integer;hours:=(p_settings->>'minimum_interval_hours')::integer;end_value:=(p_settings->>'ends_at')::timestamptz;
 IF max_amt IS NULL OR cap IS NULL OR max_amt<=0 OR cap<max_amt OR max_amt<>round(max_amt,2) OR cap<>round(cap,2)
 OR max_amt::text IN('NaN','Infinity','-Infinity') OR cap::text IN('NaN','Infinity','-Infinity')
 OR threshold_value IS NULL OR hours IS NULL OR hours NOT BETWEEN 1 AND 720 OR (end_value IS NOT NULL AND end_value<=now())
 OR trigger_value IS NULL OR trigger_value NOT IN('fixed_low_data','daily_near_expiry') THEN RETURN '{"status":"INVALID_REQUEST"}'::jsonb; END IF;
 SELECT x INTO pkg FROM esim_private.topup_cache cache CROSS JOIN LATERAL jsonb_array_elements(cache.offers) x
 WHERE cache.profile_id=p.id AND cache.owner_id=u AND cache.status='ready' AND cache.expires_at>now()
 AND cache.context=esim_private.topup_context(p) AND x->>'package_id'=p_settings->>'package_id';
 IF pkg IS NULL OR (trigger_value='fixed_low_data' AND (pkg->>'data_type'<>'1' OR p.plan_details->>'plan_type' LIKE 'daily_%' OR threshold_value NOT BETWEEN 1 AND 50 OR days IS NOT NULL))
 OR (trigger_value='daily_near_expiry' AND (coalesce(pkg->>'data_type','') NOT IN('2','3','4') OR coalesce(p.plan_details->>'plan_type','') NOT LIKE 'daily_%' OR threshold_value NOT BETWEEN 1 AND 168 OR days IS NULL OR days NOT BETWEEN 1 AND 365)) THEN RETURN '{"status":"INCOMPATIBLE_OFFER"}'::jsonb; END IF;
 IF trigger_value='daily_near_expiry' THEN
  SELECT * INTO daily_cache FROM esim_private.topup_cache WHERE profile_id=p.id;
  SELECT * INTO price FROM esim_private.daily_prices WHERE account_id=p.supplier_account_id AND profile_id=p.id AND package_id=p_settings->>'package_id' AND period_count=days ORDER BY revision DESC LIMIT 1;
  IF price.id IS NULL OR NOT esim_private.daily_price_current(price.id,daily_cache.context,pkg) THEN RETURN '{"status":"DURATION_PRICE_UNAVAILABLE"}'::jsonb; END IF;
  reviewed:=public.resolve_esim_offer_price(price.wholesale_total,u);
 ELSE reviewed:=public.resolve_esim_offer_price((pkg->>'wholesale_usd')::numeric,u); END IF;
 IF reviewed IS NULL OR reviewed>max_amt THEN RETURN '{"status":"PRICE_ABOVE_CONSENT"}'::jsonb; END IF;
 IF esim_private.automation_exposure(p.id)>cap THEN RETURN '{"status":"CAP_BELOW_EXPOSURE"}'::jsonb; END IF;
 INSERT INTO esim_private.automation_consents(profile_id,owner_id,payer_id,revision,enabled,package_id,trigger_kind,reviewed_charge,max_charge,monthly_cap,threshold,period_count,minimum_interval_hours,ends_at,device_id)
 VALUES(p.id,u,u,coalesce(c.revision,0)+1,true,p_settings->>'package_id',trigger_value,reviewed,max_amt,cap,threshold_value,days,hours,end_value,p_device_id)
 ON CONFLICT(profile_id) DO UPDATE SET revision=excluded.revision,enabled=true,package_id=excluded.package_id,trigger_kind=excluded.trigger_kind,
 reviewed_charge=excluded.reviewed_charge,max_charge=excluded.max_charge,monthly_cap=excluded.monthly_cap,threshold=excluded.threshold,period_count=excluded.period_count,
 minimum_interval_hours=excluded.minimum_interval_hours,ends_at=excluded.ends_at,device_id=excluded.device_id,stop_reason=NULL,next_check_at=now(),updated_at=now();
 INSERT INTO esim_private.automation_audit(profile_id,revision,event) VALUES(p.id,coalesce(c.revision,0)+1,'CONSENTED');
 RETURN '{"status":"SAVED"}'::jsonb;
EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range OR datetime_field_overflow THEN RETURN '{"status":"INVALID_REQUEST"}'::jsonb;
END $$;
CREATE FUNCTION esim_private.stop_automation(pid uuid,reason text) RETURNS void LANGUAGE plpgsql SET search_path='' AS $$
DECLARE c esim_private.automation_consents;
BEGIN
 UPDATE esim_private.automation_consents SET enabled=false,stop_reason=reason,updated_at=now() WHERE profile_id=pid AND enabled RETURNING * INTO c;
 IF NOT FOUND THEN RETURN; END IF;
 INSERT INTO esim_private.automation_audit(profile_id,revision,event) VALUES(pid,c.revision,reason);
 -- Existing notifications/preferences/outbox provide the delivery policy.
 IF coalesce((SELECT is_enabled FROM public.alert_settings WHERE user_id=c.owner_id AND category='esim_updates'),true) THEN
 INSERT INTO public.notifications(user_id,category,title,body,action_url,target,event_type,expires_at,template_data)
 VALUES(c.owner_id,'esim_updates','Automatic eSIM recharge paused','Review your eSIM recharge settings before enabling it again.','/esim/profiles/'||pid,jsonb_build_object('route','/esim/profiles/:id','id',pid),'esim_automation_paused',now()+interval '24 hours',jsonb_build_object('profile_id',pid,'revision',c.revision,'reason',reason));
 END IF;
END $$;
CREATE FUNCTION public.service_esim_evaluate_automation() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE c esim_private.automation_consents;p public.user_esims;cache esim_private.topup_cache;pkg jsonb;quoted jsonb;accepted jsonb;total numeric;cycle text;reason text;
BEGIN
 PERFORM esim_private.require_service();
 -- Take only one consent per transaction; wallet -> profile -> consent agrees
 -- with manual acceptance and pre-submission checks. SKIP LOCKED avoids two
 -- evaluators waiting with conflicting locks.
 SELECT c0.* INTO c FROM esim_private.automation_consents c0 JOIN public.user_esims e ON e.id=c0.profile_id JOIN esim_private.accounts a ON a.id=e.supplier_account_id
 WHERE c0.enabled AND c0.next_check_at<=now() AND a.automation_enabled ORDER BY c0.next_check_at LIMIT 1;
 IF NOT FOUND THEN RETURN '{"status":"IDLE"}'::jsonb; END IF;
 PERFORM 1 FROM public.wallets WHERE user_id=c.payer_id FOR UPDATE;
 SELECT * INTO STRICT p FROM public.user_esims WHERE id=c.profile_id FOR UPDATE;
 SELECT * INTO STRICT c FROM esim_private.automation_consents WHERE profile_id=c.profile_id FOR UPDATE;
 IF NOT c.enabled OR c.next_check_at>now() THEN RETURN '{"status":"WAITING"}'::jsonb; END IF;
 UPDATE esim_private.automation_consents SET next_check_at=now()+interval '5 minutes' WHERE profile_id=p.id;
 IF p.user_id IS DISTINCT FROM c.owner_id OR p.profile_state IN('suspended','cancelled','expired','revoked') OR c.ends_at<=now()
 OR NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=c.owner_id AND NOT coalesce(is_suspended,false)) THEN PERFORM esim_private.stop_automation(p.id,'PROFILE_UNAVAILABLE');RETURN '{"status":"PAUSED"}'::jsonb; END IF;
 reason:=esim_private.topup_refusal(p);
 IF reason IS NOT NULL THEN
  IF reason NOT IN('PROFILE_REFRESH_REQUIRED','UNRESOLVED_OPERATION') THEN PERFORM esim_private.stop_automation(p.id,reason); END IF;
  RETURN jsonb_build_object('status',reason);
 END IF;
 -- Read-only provider observations must be recent; a poll success without an
 -- observed usage timestamp cannot authorize a low-data charge.
 IF p.last_observation_at<now()-interval '15 minutes' OR (c.trigger_kind='fixed_low_data' AND (p.usage_observed_at IS NULL OR p.usage_observed_at<now()-interval '15 minutes'
 OR p.data_total_bytes IS NULL OR p.data_total_bytes<=0 OR p.data_remaining_bytes IS NULL)) THEN RETURN '{"status":"PROFILE_REFRESH_REQUIRED"}'::jsonb; END IF;
 IF p.confirmed_expires_at IS NULL OR p.confirmed_expires_at<=now()+interval '30 minutes' THEN PERFORM esim_private.stop_automation(p.id,'ELIGIBILITY_EXPIRED');RETURN '{"status":"PAUSED"}'::jsonb; END IF;
 IF c.last_order_at>now()-make_interval(hours=>c.minimum_interval_hours) THEN RETURN '{"status":"INTERVAL_WAIT"}'::jsonb; END IF;
 IF (c.trigger_kind='fixed_low_data' AND (coalesce(p.plan_details->>'plan_type','') LIKE 'daily_%' OR p.data_remaining_bytes::numeric*100/p.data_total_bytes>c.threshold))
 OR (c.trigger_kind='daily_near_expiry' AND (coalesce(p.plan_details->>'plan_type','') NOT LIKE 'daily_%' OR p.confirmed_expires_at>now()+make_interval(hours=>c.threshold))) THEN RETURN '{"status":"NOT_TRIGGERED"}'::jsonb; END IF;
 cycle:=coalesce((SELECT order_id::text FROM esim_private.entitlements WHERE profile_id=p.id ORDER BY created_at DESC LIMIT 1),p.order_id::text);
 IF EXISTS(SELECT 1 FROM esim_private.automation_orders WHERE profile_id=p.id AND cycle_key=cycle) THEN RETURN '{"status":"CYCLE_ALREADY_USED"}'::jsonb; END IF;
 SELECT * INTO cache FROM esim_private.topup_cache WHERE profile_id=p.id AND status='ready' AND expires_at>now() AND context=esim_private.topup_context(p);
 IF NOT FOUND THEN RETURN '{"status":"DISCOVERY_REQUIRED"}'::jsonb; END IF;
 SELECT x INTO pkg FROM jsonb_array_elements(cache.offers) x WHERE x->>'package_id'=c.package_id;
 IF pkg IS NULL THEN PERFORM esim_private.stop_automation(p.id,'PACKAGE_UNAVAILABLE');RETURN '{"status":"PAUSED"}'::jsonb; END IF;
 IF c.trigger_kind='daily_near_expiry' THEN
  quoted:=esim_private.quote_auto_daily(c.owner_id,p.id,c.package_id,cache.version,c.period_count);
 ELSE
  total:=public.resolve_esim_offer_price((pkg->>'wholesale_usd')::numeric,c.owner_id);
  quoted:=esim_private.quote_auto_fixed(c.owner_id,p.id,c.package_id,cache.version,total);
 END IF;
 IF quoted->>'status' IS DISTINCT FROM 'QUOTED' THEN RETURN quoted; END IF;
 total:=(quoted#>>'{offer,retail_total}')::numeric;
 IF total>c.max_charge OR total>c.reviewed_charge THEN PERFORM esim_private.stop_automation(p.id,'PRICE_ABOVE_CONSENT');RETURN '{"status":"PAUSED"}'::jsonb; END IF;
 IF total+esim_private.automation_exposure(p.id)>c.monthly_cap THEN PERFORM esim_private.stop_automation(p.id,'MONTHLY_CAP');RETURN '{"status":"PAUSED"}'::jsonb; END IF;
 accepted:=esim_private.accept_recharge(c.owner_id,(quoted->>'quote_id')::uuid,(quoted->>'acceptance_key')::uuid,c.device_id);
 IF accepted->>'status' NOT IN('ACCEPTED','ADOPTED') THEN
  IF accepted->>'status' IN('BALANCE_UNAVAILABLE','PRICE_CHANGED','DEVICE_BLOCKED') THEN PERFORM esim_private.stop_automation(p.id,accepted->>'status'); END IF;
  RETURN accepted;
 END IF;
 INSERT INTO esim_private.automation_orders(order_id,profile_id,consent_revision,cycle_key,amount) VALUES((accepted->>'order_id')::uuid,p.id,c.revision,cycle,total);
 UPDATE esim_private.automation_consents SET last_order_at=now() WHERE profile_id=p.id;
 INSERT INTO esim_private.automation_audit(profile_id,revision,event) VALUES(p.id,c.revision,'ORDER_RESERVED');
 RETURN accepted;
END $$;
