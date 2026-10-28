BEGIN;
SET LOCAL lock_timeout='5s';

DO $preflight$ BEGIN
 IF md5(pg_get_functiondef('public.accept_esim_topup(uuid, uuid, text)'::regprocedure))<>'a05571f6ce5426fb6614589d3fb8a674' THEN RAISE EXCEPTION 'Dependency drift: accept_esim_topup'; END IF;
 IF md5(pg_get_functiondef('public.admin_esim_operation_timeline(uuid)'::regprocedure))<>'9bace4a029d5211a026d0feede649ecb' THEN RAISE EXCEPTION 'Dependency drift: admin_esim_operation_timeline'; END IF;
 IF md5(pg_get_functiondef('public.admin_request_esim_reconciliation(uuid)'::regprocedure))<>'14728b6e200d326c05f2042882754718' THEN RAISE EXCEPTION 'Dependency drift: admin_request_esim_reconciliation'; END IF;
 IF md5(pg_get_functiondef('public.assert_admin()'::regprocedure))<>'de1fe97eb4b7c9a14888cbdb26bab60e' THEN RAISE EXCEPTION 'Dependency drift: assert_admin'; END IF;
 IF md5(pg_get_functiondef('public.credit_wallet(uuid, numeric, text, text, text)'::regprocedure))<>'f958d9ae0708fb85e3c6b572b503a96c' THEN RAISE EXCEPTION 'Dependency drift: credit_wallet'; END IF;
 IF md5(pg_get_functiondef('esim_private.daily_order_current(esim_orders)'::regprocedure))<>'65ca289927ed4617d0a99e53059e0f75' THEN RAISE EXCEPTION 'Dependency drift: daily_order_current'; END IF;
 IF md5(pg_get_functiondef('public.service_esim_apply_observation(uuid, uuid, jsonb, text)'::regprocedure))<>'b8fc8e05702223da004362c0e7fbee05' THEN RAISE EXCEPTION 'Dependency drift: service_esim_apply_observation'; END IF;
 IF md5(pg_get_functiondef('public.service_esim_mark_submitted(uuid, uuid)'::regprocedure))<>'fd35c0919fa4d84a578f2957a1514115' THEN RAISE EXCEPTION 'Dependency drift: service_esim_mark_submitted'; END IF;
 IF md5(pg_get_functiondef('esim_private.topup_refusal(user_esims)'::regprocedure))<>'1d84bd8f3e355771d0d23d920a372f7d' THEN RAISE EXCEPTION 'Dependency drift: topup_refusal'; END IF;
 IF md5(pg_get_functiondef('public.quote_esim_topup(uuid, text, uuid, numeric)'::regprocedure))<>'2996f71b6f101ded3f34cf01beb24487' THEN RAISE EXCEPTION 'Dependency drift: quote_esim_topup'; END IF;
 IF md5(pg_get_functiondef('public.quote_esim_daily_extension(uuid, text, uuid, integer)'::regprocedure))<>'87f3af4b3c0cb45099fc0487bff161a5' THEN RAISE EXCEPTION 'Dependency drift: quote_esim_daily_extension'; END IF;
 IF md5(pg_get_functiondef('public.service_esim_alert_is_current(uuid)'::regprocedure))<>'5cbe6c5a31d859c46b29a6151d5b5374' THEN RAISE EXCEPTION 'Dependency drift: service_esim_alert_is_current'; END IF;
END $preflight$;

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


-- ESIM-10/11: controls are serialized with the existing recharge engine.
ALTER TABLE esim_private.accounts
 ADD COLUMN cancellation_enabled boolean NOT NULL DEFAULT false,
 ADD COLUMN cancellation_contract_verified boolean NOT NULL DEFAULT false,
 ADD COLUMN service_controls_enabled boolean NOT NULL DEFAULT false,
 ADD COLUMN service_controls_contract_verified boolean NOT NULL DEFAULT false,
 ADD COLUMN automation_enabled boolean NOT NULL DEFAULT false;
CREATE TABLE esim_private.refund_scopes(
 profile_id uuid PRIMARY KEY REFERENCES public.user_esims(id),version uuid NOT NULL DEFAULT gen_random_uuid(),
 context text NOT NULL,items jsonb NOT NULL,source_reference text NOT NULL,observed_at timestamptz NOT NULL,expires_at timestamptz NOT NULL
);
CREATE TABLE esim_private.control_quotes(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),acceptance_key uuid NOT NULL DEFAULT gen_random_uuid(),
 profile_id uuid NOT NULL REFERENCES public.user_esims(id),owner_id uuid NOT NULL,
 scope_version uuid NOT NULL,items jsonb NOT NULL,created_at timestamptz NOT NULL DEFAULT now(),expires_at timestamptz NOT NULL
);
CREATE INDEX esim_control_quotes_profile ON esim_private.control_quotes(profile_id,created_at);
CREATE TABLE esim_private.controls(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),profile_id uuid NOT NULL REFERENCES public.user_esims(id),
 owner_id uuid NOT NULL,action text NOT NULL CHECK(action IN('cancel','suspend','resume')),
 request_key uuid NOT NULL,quote_id uuid REFERENCES esim_private.control_quotes(id),refund_items jsonb NOT NULL DEFAULT '[]',
 state text NOT NULL DEFAULT 'prepared' CHECK(state IN('prepared','submitted','reconciling','refund_pending','completed','failed','support_required')),
 lease uuid,lease_until timestamptz,submitted_at timestamptz,observation_started_at timestamptz,
 next_check_at timestamptz NOT NULL DEFAULT now(),attempts integer NOT NULL DEFAULT 0,
 error_code text,created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(owner_id,request_key),UNIQUE(quote_id)
);
CREATE UNIQUE INDEX esim_one_control_per_profile ON esim_private.controls(profile_id)
 WHERE state NOT IN('completed','failed');
CREATE INDEX esim_control_due ON esim_private.controls(next_check_at) WHERE state NOT IN('completed','failed');
CREATE INDEX esim_controls_owner ON esim_private.controls(owner_id,created_at);
CREATE TABLE esim_private.cancellation_refunds(
 debit_id uuid PRIMARY KEY REFERENCES public.wallet_transactions(id),
 operation_id uuid NOT NULL REFERENCES esim_private.controls(id),
 refund_tx_id uuid NOT NULL UNIQUE REFERENCES public.wallet_transactions(id),
 amount numeric(12,2) NOT NULL CHECK(amount>0),source_reference text NOT NULL,created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX esim_refunds_operation ON esim_private.cancellation_refunds(operation_id);
CREATE TABLE esim_private.support_cases(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),profile_id uuid NOT NULL REFERENCES public.user_esims(id),
 actor_id uuid,reason text NOT NULL,created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX esim_support_profile ON esim_private.support_cases(profile_id,created_at);

CREATE FUNCTION esim_private.refund_context(pid uuid) RETURNS text LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT md5(coalesce(jsonb_agg(jsonb_build_array(o.id,o.user_id,o.quantity,r.settlement_tx_id,r.settlement_state) ORDER BY o.id)::text,''))
 FROM public.esim_orders o JOIN esim_private.order_runs r ON r.order_id=o.id JOIN public.user_esims p ON p.id=pid
 WHERE o.id=p.order_id OR o.recharge_profile_id=p.id;
$$;
CREATE FUNCTION esim_private.control_pending(pid uuid) RETURNS boolean LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM esim_private.controls WHERE profile_id=pid AND state NOT IN('completed','failed'));
$$;
CREATE FUNCTION esim_private.control_refusal(p public.user_esims,act text) RETURNS text LANGUAGE plpgsql STABLE SET search_path='' AS $$
BEGIN
 IF p.provider IS DISTINCT FROM 'esimaccess' OR p.supplier_account_id IS NULL OR p.supplier_profile_ref IS NULL THEN RETURN 'UNSUPPORTED_PROFILE'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.esim_suppliers WHERE code=p.provider AND is_active) THEN RETURN 'SUPPLIER_DISABLED'; END IF;
 IF p.profile_state IN('cancelled','revoked','expired') OR p.bundle_state IN('cancelled','expired') THEN RETURN 'PROFILE_UNAVAILABLE'; END IF;
 IF p.last_observation_at IS NULL OR p.last_observation_at<now()-interval '2 minutes' THEN RETURN 'PROFILE_REFRESH_REQUIRED'; END IF;
 IF act='cancel' AND (p.provider_state->>'esimStatus' IS DISTINCT FROM 'GOT_RESOURCE' OR p.provider_state->>'smdpStatus' IS DISTINCT FROM 'RELEASED'
  OR p.installation_state IS DISTINCT FROM 'released' OR p.first_activated_at IS NOT NULL OR coalesce(p.provider_state->>'activeType','') NOT IN('1','2') OR p.provider_state->>'has_eid'='true') THEN RETURN 'CANCELLATION_INELIGIBLE'; END IF;
 IF act='suspend' AND p.profile_state NOT IN('issued','active') THEN RETURN 'PROFILE_UNAVAILABLE'; END IF;
 IF act='resume' AND p.profile_state IS DISTINCT FROM 'suspended' THEN RETURN 'PROFILE_UNAVAILABLE'; END IF;
 RETURN NULL;
END $$;

-- Only independently verified, itemized retail policy is imported here. No
-- default fee reimbursement or inference from supplier wholesale balance.
CREATE FUNCTION public.service_esim_set_refund_scope(p_profile_id uuid,p_items jsonb,p_source_reference text,p_observed_at timestamptz)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.user_esims; i jsonb; d public.wallet_transactions; o public.esim_orders; amount numeric;
BEGIN
 PERFORM esim_private.require_service();SELECT * INTO STRICT p FROM public.user_esims WHERE id=p_profile_id FOR UPDATE;
 IF jsonb_typeof(p_items) IS DISTINCT FROM 'array' OR jsonb_array_length(p_items) NOT BETWEEN 1 AND 20
  OR p_source_reference IS NULL OR length(p_source_reference) NOT BETWEEN 8 AND 200 OR p_observed_at IS NULL OR p_observed_at<now()-interval '10 minutes' OR p_observed_at>clock_timestamp() THEN RAISE EXCEPTION 'Invalid refund evidence'; END IF;
 IF (SELECT count(DISTINCT value->>'debit_id') FROM jsonb_array_elements(p_items))<>jsonb_array_length(p_items) THEN RAISE EXCEPTION 'Duplicate refund binding'; END IF;
 FOR i IN SELECT value FROM jsonb_array_elements(p_items) LOOP
  SELECT * INTO STRICT d FROM public.wallet_transactions WHERE id=(i->>'debit_id')::uuid;
  SELECT ord.* INTO STRICT o FROM public.esim_orders ord JOIN esim_private.order_runs r ON r.order_id=ord.id
   WHERE r.settlement_tx_id=d.id AND r.settlement_state='captured' AND ord.provider='esimaccess'
    AND ((ord.id=p.order_id AND ord.quantity=1) OR ord.recharge_profile_id=p.id);
  amount:=(i->>'amount')::numeric;
  IF d.type NOT IN('esim_purchase_debit','esim_recharge_debit') OR d.status IS DISTINCT FROM 'completed'
   OR d.amount<=0 OR d.amount IS DISTINCT FROM d.balance_before-d.balance_after OR amount IS NULL OR amount<=0
   OR amount::text IN('NaN','Infinity','-Infinity') OR amount<>round(amount,2) OR amount>d.amount OR amount>o.total_amount_usd
   OR d.user_id IS DISTINCT FROM o.user_id OR EXISTS(SELECT 1 FROM esim_private.cancellation_refunds WHERE debit_id=d.id)
   OR EXISTS(SELECT 1 FROM public.wallet_transactions WHERE status='completed' AND (reference_id IN('esim_refund_'||o.id::text,'esim_cancel:'||d.id::text)
     OR (metadata->>'esim_order_id'=o.id::text AND type IN('refund','esim_purchase_refund','esim_recharge_refund')))) THEN RAISE EXCEPTION 'Unproven or previously refunded charge'; END IF;
 END LOOP;
 -- Every evidenced captured base/recharge must be accounted for. Exclusions
 -- and partial policies require support rather than silently omitting a charge.
 IF EXISTS(SELECT 1 FROM public.esim_orders o0 JOIN esim_private.order_runs r ON r.order_id=o0.id
  WHERE (o0.id=p.order_id OR o0.recharge_profile_id=p.id) AND r.settlement_state='captured'
   AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p_items) x WHERE (x->>'debit_id')::uuid=r.settlement_tx_id)) THEN RAISE EXCEPTION 'Incomplete refund scope'; END IF;
 INSERT INTO esim_private.refund_scopes(profile_id,context,items,source_reference,observed_at,expires_at)
 VALUES(p.id,esim_private.refund_context(p.id),p_items,p_source_reference,p_observed_at,p_observed_at+interval '10 minutes')
 ON CONFLICT(profile_id) DO UPDATE SET version=gen_random_uuid(),context=excluded.context,items=excluded.items,source_reference=excluded.source_reference,
 observed_at=excluded.observed_at,expires_at=excluded.expires_at WHERE refund_scopes.observed_at<=excluded.observed_at;
 RETURN FOUND;
END $$;
CREATE FUNCTION public.get_esim_controls(p_profile_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); p public.user_esims; a esim_private.accounts; s esim_private.refund_scopes; q esim_private.control_quotes; reason text; refunds jsonb;
BEGIN
 PERFORM esim_private.require_live_owner(u);
 SELECT * INTO p FROM public.user_esims WHERE id=p_profile_id AND user_id=u;
 IF NOT FOUND THEN RETURN '{"status":"PROFILE_UNAVAILABLE"}'::jsonb; END IF;
 SELECT * INTO a FROM esim_private.accounts WHERE id=p.supplier_account_id;
 reason:=esim_private.control_refusal(p,'cancel');
 IF reason='PROFILE_REFRESH_REQUIRED' THEN
  INSERT INTO esim_private.profile_work(profile_id,next_check_at,requested_at) VALUES(p.id,now(),now()) ON CONFLICT(profile_id) DO UPDATE SET next_check_at=now(),requested_at=now() WHERE profile_work.requested_at IS NULL OR profile_work.requested_at<now()-interval '1 minute';
 END IF;
 IF esim_private.control_pending(p.id) OR EXISTS(SELECT 1 FROM public.esim_orders WHERE recharge_profile_id=p.id AND status IN('pending','processing')) THEN reason:='UNRESOLVED_OPERATION'; END IF;
 SELECT * INTO s FROM esim_private.refund_scopes WHERE profile_id=p.id AND expires_at>now() AND context=esim_private.refund_context(p.id);
 IF reason IS NULL AND s.profile_id IS NULL THEN reason:='REFUND_POLICY_UNVERIFIED'; END IF;
 IF reason IS NULL THEN
  SELECT jsonb_agg(jsonb_build_object('debit_id',d.id,'payer_id',d.user_id,'amount',(i->>'amount')::numeric,'currency','USD','destination','original_payer_wallet')) INTO refunds
  FROM jsonb_array_elements(s.items) i JOIN public.wallet_transactions d ON d.id=(i->>'debit_id')::uuid;
  SELECT * INTO q FROM esim_private.control_quotes WHERE profile_id=p.id AND scope_version=s.version AND expires_at>now() ORDER BY created_at DESC LIMIT 1;
  IF NOT FOUND THEN
   INSERT INTO esim_private.control_quotes(profile_id,owner_id,scope_version,items,expires_at)
   VALUES(p.id,u,s.version,s.items,least(s.expires_at,now()+interval '2 minutes')) RETURNING * INTO q;
  END IF;
 END IF;
 RETURN jsonb_build_object('status','READY','profile_id',p.id,'owner_id',u,'profile_state',p.profile_state,
 'cancellation_reason',reason,'cancellation_enabled',coalesce(a.cancellation_enabled AND a.cancellation_contract_verified,false) AND reason IS NULL,
 'quote_id',q.id,'acceptance_key',q.acceptance_key,'quote_expires_at',q.expires_at,'refunds',coalesce(refunds,'[]'::jsonb),
 'suspend_enabled',coalesce(a.service_controls_enabled AND a.service_controls_contract_verified,false) AND esim_private.control_refusal(p,'suspend') IS NULL AND NOT esim_private.control_pending(p.id),
 'resume_enabled',coalesce(a.service_controls_enabled AND a.service_controls_contract_verified,false) AND esim_private.control_refusal(p,'resume') IS NULL AND NOT esim_private.control_pending(p.id),
 'operations',coalesce((SELECT jsonb_agg(jsonb_build_object('id',id,'action',action,'state',state,'error_code',error_code,'created_at',created_at)) FROM (SELECT * FROM esim_private.controls WHERE profile_id=p.id ORDER BY created_at DESC LIMIT 20) x),'[]'::jsonb),
 'validity_note','Suspension stops data service. Validity may continue to run.');
END $$;
CREATE FUNCTION public.request_esim_control(p_profile_id uuid,p_action text,p_request_key uuid,p_quote_id uuid DEFAULT NULL,p_acceptance_key uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); p public.user_esims; a esim_private.accounts; op esim_private.controls; q esim_private.control_quotes; reason text;
BEGIN
 PERFORM esim_private.require_money_session(u);
 IF p_action IS NULL OR p_action NOT IN('cancel','suspend','resume') OR p_request_key IS NULL THEN RETURN '{"status":"INVALID_REQUEST"}'::jsonb; END IF;
 SELECT * INTO p FROM public.user_esims WHERE id=p_profile_id AND user_id=u FOR UPDATE;
 IF NOT FOUND THEN RETURN '{"status":"PROFILE_UNAVAILABLE"}'::jsonb; END IF;
 SELECT * INTO op FROM esim_private.controls WHERE owner_id=u AND request_key=p_request_key;
 IF FOUND THEN
  IF op.profile_id<>p.id OR op.action<>p_action THEN RETURN '{"status":"REQUEST_CONFLICT"}'::jsonb; END IF;
  RETURN jsonb_build_object('status','ADOPTED','operation_id',op.id);
 END IF;
 SELECT * INTO a FROM esim_private.accounts WHERE id=p.supplier_account_id;
 IF (p_action='cancel' AND NOT coalesce(a.cancellation_enabled AND a.cancellation_contract_verified,false)) OR
  (p_action<>'cancel' AND NOT coalesce(a.service_controls_enabled AND a.service_controls_contract_verified,false)) THEN RETURN '{"status":"ACTION_DISABLED"}'::jsonb; END IF;
 reason:=esim_private.control_refusal(p,p_action);IF reason IS NOT NULL THEN RETURN jsonb_build_object('status',reason); END IF;
 IF esim_private.control_pending(p.id) OR EXISTS(SELECT 1 FROM public.esim_orders WHERE recharge_profile_id=p.id AND status IN('pending','processing')) THEN RETURN '{"status":"UNRESOLVED_OPERATION"}'::jsonb; END IF;
 IF p_action='cancel' THEN
  SELECT * INTO q FROM esim_private.control_quotes WHERE id=p_quote_id AND profile_id=p.id AND owner_id=u AND acceptance_key=p_acceptance_key AND expires_at>now();
  IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM esim_private.refund_scopes WHERE profile_id=p.id AND version=q.scope_version AND expires_at>now() AND context=esim_private.refund_context(p.id)) THEN RETURN '{"status":"STALE_QUOTE"}'::jsonb; END IF;
 END IF;
 INSERT INTO esim_private.controls(profile_id,owner_id,action,request_key,quote_id,refund_items)
 VALUES(p.id,u,p_action,p_request_key,q.id,coalesce(q.items,'[]'::jsonb)) RETURNING * INTO op;
 UPDATE esim_private.automation_consents SET enabled=false,stop_reason='SERVICE_CONTROL',updated_at=now() WHERE profile_id=p.id AND enabled;
 RETURN jsonb_build_object('status','ACCEPTED','operation_id',op.id);
END $$;
CREATE FUNCTION public.service_esim_claim_control(p_account_key text DEFAULT 'primary') RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE op esim_private.controls; p public.user_esims;
BEGIN
 PERFORM esim_private.require_service();
 SELECT c.* INTO op FROM esim_private.controls c JOIN public.user_esims e ON e.id=c.profile_id JOIN esim_private.accounts a ON a.id=e.supplier_account_id
 WHERE a.account_key=p_account_key AND c.state IN('prepared','submitted','reconciling') AND c.next_check_at<=now() AND (c.lease_until IS NULL OR c.lease_until<now())
 ORDER BY c.next_check_at FOR UPDATE OF c SKIP LOCKED LIMIT 1;
 IF NOT FOUND THEN RETURN NULL; END IF;
 UPDATE esim_private.controls SET lease=gen_random_uuid(),lease_until=now()+interval '2 minutes',observation_started_at=clock_timestamp(),attempts=attempts+1 WHERE id=op.id RETURNING * INTO op;
 SELECT * INTO STRICT p FROM public.user_esims WHERE id=op.profile_id;
 RETURN jsonb_build_object('id',op.id,'profile_id',p.id,'action',op.action,'lease',op.lease,'state',op.state,
 'supplier_profile_ref',p.supplier_profile_ref,'iccid',p.iccid,'provider_order_ref',(SELECT provider_order_ref FROM esim_private.order_runs WHERE order_id=p.order_id));
END $$;
CREATE FUNCTION public.service_esim_mark_control_submitted(p_operation_id uuid,p_lease uuid,p_observation jsonb) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE op esim_private.controls;p public.user_esims;a esim_private.accounts;reason text;
BEGIN
 PERFORM esim_private.require_service();SELECT * INTO STRICT op FROM esim_private.controls WHERE id=p_operation_id;
 SELECT * INTO STRICT p FROM public.user_esims WHERE id=op.profile_id FOR UPDATE;
 SELECT * INTO STRICT op FROM esim_private.controls WHERE id=p_operation_id FOR UPDATE;
 IF op.state<>'prepared' OR p_lease IS NULL OR op.lease IS DISTINCT FROM p_lease OR op.lease_until<now() THEN RETURN false; END IF;
 SELECT * INTO STRICT a FROM esim_private.accounts WHERE id=p.supplier_account_id;
 IF op.owner_id IS DISTINCT FROM p.user_id OR NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=p.user_id AND NOT coalesce(is_suspended,false)) OR
 (op.action='cancel' AND NOT(a.cancellation_enabled AND a.cancellation_contract_verified)) OR
 (op.action<>'cancel' AND NOT(a.service_controls_enabled AND a.service_controls_contract_verified)) THEN reason:='ACTION_DISABLED'; END IF;
 IF p_observation->>'supplier_profile_ref' IS DISTINCT FROM p.supplier_profile_ref OR p_observation->>'iccid' IS DISTINCT FROM p.iccid
 OR p_observation->>'provider_order_ref' IS DISTINCT FROM (SELECT provider_order_ref FROM esim_private.order_runs WHERE order_id=p.order_id)
 OR (p_observation->>'checked_at')::timestamptz<op.observation_started_at OR (p_observation->>'checked_at')::timestamptz>clock_timestamp()+interval '5 seconds'
 OR p_observation->>'checked_at' IS NULL THEN reason:='PROFILE_REFRESH_REQUIRED'; END IF;
 IF op.action='cancel' AND (p_observation#>>'{provider_state,esimStatus}' IS DISTINCT FROM 'GOT_RESOURCE' OR p_observation#>>'{provider_state,smdpStatus}' IS DISTINCT FROM 'RELEASED'
 OR p_observation->>'data_used_bytes' IS DISTINCT FROM '0' OR coalesce(p_observation#>>'{provider_state,activeType}','') NOT IN('1','2') OR p_observation#>>'{provider_state,has_eid}'='true') THEN reason:='CANCELLATION_INELIGIBLE'; END IF;
 IF op.action='suspend' AND coalesce(p_observation->>'profile_state','') NOT IN('issued','active') THEN reason:='PROFILE_UNAVAILABLE'; END IF;
 IF op.action='resume' AND p_observation->>'profile_state' IS DISTINCT FROM 'suspended' THEN reason:='PROFILE_UNAVAILABLE'; END IF;
 IF EXISTS(SELECT 1 FROM public.esim_orders WHERE recharge_profile_id=p.id AND status IN('pending','processing')) THEN reason:='UNRESOLVED_OPERATION'; END IF;
 IF op.action='cancel' AND NOT EXISTS(SELECT 1 FROM esim_private.control_quotes q JOIN esim_private.refund_scopes s ON s.profile_id=q.profile_id AND s.version=q.scope_version
 WHERE q.id=op.quote_id AND q.expires_at>now() AND s.expires_at>now() AND s.context=esim_private.refund_context(p.id)) THEN reason:='STALE_QUOTE'; END IF;
 IF reason IS NOT NULL THEN UPDATE esim_private.controls SET state='failed',error_code=reason,lease=NULL,lease_until=NULL,updated_at=now() WHERE id=op.id;RETURN false; END IF;
 UPDATE esim_private.controls SET state='submitted',submitted_at=clock_timestamp(),updated_at=now() WHERE id=op.id;RETURN true;
END $$;
CREATE FUNCTION public.service_esim_finish_control(p_operation_id uuid,p_lease uuid,p_observation jsonb DEFAULT NULL,p_error_code text DEFAULT NULL) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE op esim_private.controls;p public.user_esims;confirmed boolean;
BEGIN
 PERFORM esim_private.require_service();SELECT * INTO STRICT op FROM esim_private.controls WHERE id=p_operation_id;
 SELECT * INTO STRICT p FROM public.user_esims WHERE id=op.profile_id FOR UPDATE;
 SELECT * INTO STRICT op FROM esim_private.controls WHERE id=p_operation_id FOR UPDATE;
 IF p_lease IS NULL OR op.lease IS DISTINCT FROM p_lease OR op.lease_until<now() OR op.state NOT IN('prepared','submitted','reconciling') THEN RETURN false; END IF;
 IF p_error_code IS NOT NULL AND p_error_code!~'^[A-Z0-9_]{1,64}$' THEN RAISE EXCEPTION 'Invalid error code'; END IF;
 confirmed:=op.submitted_at IS NOT NULL AND p_observation->>'supplier_profile_ref'=p.supplier_profile_ref AND p_observation->>'iccid'=p.iccid
 AND p_observation->>'provider_order_ref'=(SELECT provider_order_ref FROM esim_private.order_runs WHERE order_id=p.order_id)
 AND (p_observation->>'checked_at')::timestamptz>=op.submitted_at AND (p_observation->>'checked_at')::timestamptz<=clock_timestamp()+interval '5 seconds'
 AND CASE op.action WHEN 'cancel' THEN p_observation->>'profile_state'='cancelled' WHEN 'suspend' THEN p_observation->>'profile_state'='suspended' WHEN 'resume' THEN p_observation->>'profile_state' IN('issued','active') END;
 IF coalesce(confirmed,false) AND (p.last_observation_at IS NULL OR (p_observation->>'checked_at')::timestamptz>=p.last_observation_at) THEN
  UPDATE public.user_esims SET profile_state=p_observation->>'profile_state',provider_state=p_observation->'provider_state',last_observation_at=(p_observation->>'checked_at')::timestamptz,
   bundle_state=CASE WHEN op.action='cancel' THEN 'cancelled' ELSE bundle_state END WHERE id=p.id;
  UPDATE esim_private.controls SET state=CASE WHEN action='cancel' THEN 'refund_pending' ELSE 'completed' END,error_code=NULL,lease=NULL,lease_until=NULL,updated_at=now() WHERE id=op.id;
 ELSE
  -- No resubmission on a timeout or a state that has not propagated yet.
  UPDATE esim_private.controls SET state=CASE WHEN submitted_at IS NULL THEN 'failed' WHEN attempts>=12 THEN 'support_required' ELSE 'reconciling' END,
   error_code=coalesce(p_error_code,'CONTROL_OUTCOME_UNKNOWN'),next_check_at=now()+interval '5 minutes',lease=NULL,lease_until=NULL,updated_at=now() WHERE id=op.id;
 END IF;
 RETURN coalesce(confirmed,false);
END $$;
-- Supplier credit evidence is explicit and separate from state confirmation.
-- Refund every quoted charge atomically or retain refund_pending. Never guess
-- attribution from a balance delta or accept an unverified callback.
CREATE FUNCTION public.service_esim_settle_cancellation(p_operation_id uuid,p_credit_items jsonb,p_source_reference text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE op esim_private.controls;p public.user_esims;i jsonb;d public.wallet_transactions;amt numeric;tx uuid;wid uuid;
BEGIN
 PERFORM esim_private.require_service();SELECT * INTO STRICT op FROM esim_private.controls WHERE id=p_operation_id;
 FOR wid IN SELECT DISTINCT d0.wallet_id FROM jsonb_array_elements(op.refund_items) x JOIN public.wallet_transactions d0 ON d0.id=(x->>'debit_id')::uuid ORDER BY d0.wallet_id LOOP
  PERFORM 1 FROM public.wallets WHERE id=wid FOR UPDATE;
 END LOOP;
 SELECT * INTO STRICT p FROM public.user_esims WHERE id=op.profile_id FOR UPDATE;
 SELECT * INTO STRICT op FROM esim_private.controls WHERE id=p_operation_id FOR UPDATE;
 IF op.state='completed' THEN RETURN '{"status":"ADOPTED"}'::jsonb; END IF;
 IF op.action<>'cancel' OR op.state<>'refund_pending' OR p.profile_state<>'cancelled' THEN RAISE EXCEPTION 'Confirmed cancellation required'; END IF;
 IF p_credit_items IS DISTINCT FROM op.refund_items OR p_source_reference IS NULL OR length(p_source_reference) NOT BETWEEN 8 AND 200 THEN RETURN '{"status":"CREDIT_SCOPE_UNPROVEN"}'::jsonb; END IF;
 FOR i IN SELECT value FROM jsonb_array_elements(op.refund_items) LOOP
  SELECT * INTO STRICT d FROM public.wallet_transactions WHERE id=(i->>'debit_id')::uuid FOR UPDATE;amt:=(i->>'amount')::numeric;
  IF d.status<>'completed' OR d.type NOT IN('esim_purchase_debit','esim_recharge_debit') OR d.amount IS DISTINCT FROM d.balance_before-d.balance_after OR amt<=0 OR amt>d.amount
  OR EXISTS(SELECT 1 FROM esim_private.cancellation_refunds WHERE debit_id=d.id) OR EXISTS(SELECT 1 FROM public.wallet_transactions t WHERE t.status='completed'
    AND (t.reference_id='esim_cancel:'||d.id::text OR EXISTS(SELECT 1 FROM esim_private.order_runs r WHERE r.settlement_tx_id=d.id AND (t.reference_id='esim_refund_'||r.order_id::text
    OR (t.metadata->>'esim_order_id'=r.order_id::text AND t.type IN('refund','esim_purchase_refund','esim_recharge_refund')))))) THEN RAISE EXCEPTION 'Refund binding changed'; END IF;
  IF d.wallet_id IS DISTINCT FROM (SELECT id FROM public.wallets WHERE user_id=d.user_id AND currency='USD') THEN RAISE EXCEPTION 'Original payer wallet changed'; END IF;
  tx:=public.credit_wallet(d.user_id,amt,CASE WHEN d.type='esim_recharge_debit' THEN 'esim_recharge_refund' ELSE 'esim_purchase_refund' END,'Unused eSIM cancellation','esim_cancel:'||d.id::text);
  INSERT INTO esim_private.cancellation_refunds(debit_id,operation_id,refund_tx_id,amount,source_reference) VALUES(d.id,op.id,tx,amt,p_source_reference);
 END LOOP;
 UPDATE esim_private.controls SET state='completed',updated_at=now() WHERE id=op.id;
 RETURN '{"status":"REFUNDED"}'::jsonb;
END $$;


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


CREATE OR REPLACE FUNCTION esim_private.accept_recharge(u uuid, p_quote_id uuid, p_acceptance_key uuid, p_device_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE q esim_private.recharge_quotes; p public.user_esims; c esim_private.topup_cache;
 o public.esim_orders; total numeric; reason text; guard jsonb;
BEGIN
 PERFORM esim_private.require_live_owner(u);
 SELECT * INTO q FROM esim_private.recharge_quotes WHERE id=p_quote_id AND owner_id=u AND payer_id=u AND acceptance_key=p_acceptance_key;
 IF NOT FOUND THEN RETURN '{"status":"QUOTE_UNAVAILABLE"}'::jsonb; END IF;
 -- Wallet -> profile -> quote/run/hold is the common financial lock order.
 PERFORM 1 FROM public.wallets WHERE user_id=u FOR UPDATE;
 SELECT * INTO p FROM public.user_esims WHERE id=q.profile_id AND user_id=u FOR UPDATE;
 IF NOT FOUND THEN RETURN '{"status":"PROFILE_UNAVAILABLE"}'::jsonb; END IF;
 SELECT * INTO o FROM public.esim_orders WHERE recharge_quote_id=q.id AND user_id=u;
 IF FOUND THEN RETURN jsonb_build_object('status','ADOPTED','order_id',o.id); END IF;
 IF NOT esim_private.recharge_can_accept() OR (q.action='daily_extension' AND NOT EXISTS(SELECT 1 FROM esim_private.accounts WHERE id=q.account_id AND daily_duration_enabled AND daily_contract_verified)) THEN RETURN '{"status":"RECHARGE_DISABLED"}'::jsonb; END IF;
 reason:=esim_private.topup_refusal(p);IF reason IS NOT NULL THEN RETURN jsonb_build_object('status',reason); END IF;
 SELECT * INTO c FROM esim_private.topup_cache WHERE profile_id=p.id AND owner_id=u AND account_id=q.account_id;
 IF q.expires_at<=now() OR c.expires_at<=now() OR c.status IS DISTINCT FROM 'ready' OR c.version IS DISTINCT FROM q.cache_version
  OR q.context IS DISTINCT FROM esim_private.topup_context(p) OR p.supplier_account_id IS DISTINCT FROM q.account_id THEN RETURN '{"status":"STALE_QUOTE"}'::jsonb; END IF;
 IF NOT (CASE WHEN q.action='daily_extension' THEN esim_private.daily_extension_current(q,p,c) ELSE EXISTS(SELECT 1 FROM jsonb_array_elements(c.offers) x WHERE x->>'package_id'=q.package_id AND x->>'data_type'='1' AND (x->>'wholesale_usd')::numeric=q.wholesale_usd AND (x->>'allowance_bytes')::bigint>0) END) THEN RETURN '{"status":"INCOMPATIBLE_OFFER"}'::jsonb; END IF;
 total:=public.resolve_esim_offer_price(q.wholesale_usd,u);
 IF total IS DISTINCT FROM q.retail_total THEN RETURN '{"status":"PRICE_CHANGED"}'::jsonb; END IF;
 IF (esim_private.topup_balance(u,total)->>'balance_state')<>'sufficient' THEN RETURN '{"status":"BALANCE_UNAVAILABLE"}'::jsonb; END IF;
 guard:=public.guard_money_action('esim_purchase',total,p_device_id,NULL,u);
 IF coalesce((guard->>'blocked')::boolean,true) THEN RETURN '{"status":"DEVICE_BLOCKED"}'::jsonb; END IF;
 INSERT INTO public.esim_orders(user_id,offer_id,bundle_name,provider,quantity,wholesale_price_usd,retail_price_usd,markup_percent,
  total_amount_usd,status,operation_kind,recharge_profile_id,recharge_quote_id,catalogue_snapshot)
 VALUES(u,q.package_id,q.package_id,'esimaccess',1,q.wholesale_usd,total,round((total/q.wholesale_usd-1)*100,2),total,'pending',
  CASE WHEN q.action='daily_extension' THEN 'daily_extension' ELSE 'fixed_recharge' END,p.id,q.id,jsonb_build_object('catalogue_details',q.retail_snapshot,'period_count',CASE WHEN q.action='daily_extension' THEN q.period_count END,'daily_price_id',q.daily_price_id,'daily_source_facts',(SELECT value FROM jsonb_array_elements(c.offers) WHERE value->>'package_id'=q.package_id),'daily_base_price',(SELECT (value->>'wholesale_usd')::numeric FROM jsonb_array_elements(c.offers) WHERE value->>'package_id'=q.package_id),'daily_previous_expiry',p.confirmed_expires_at,'supplier_profile_ref',p.supplier_profile_ref,
  'iccid',p.iccid,'supplier_account_id',p.supplier_account_id,'quote_context',q.context)) RETURNING * INTO o;
 PERFORM esim_private.reserve_order(o.id);
 RETURN jsonb_build_object('status','ACCEPTED','order_id',o.id);
END $function$
;

CREATE OR REPLACE FUNCTION public.accept_esim_topup(p_quote_id uuid,p_acceptance_key uuid,p_device_id text DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN PERFORM esim_private.require_money_session(auth.uid());RETURN esim_private.accept_recharge(auth.uid(),p_quote_id,p_acceptance_key,p_device_id);END $$;

CREATE OR REPLACE FUNCTION esim_private.quote_auto_fixed(u uuid, p_profile_id uuid, p_package_id text, p_offer_version uuid, p_expected_total numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE p public.user_esims%ROWTYPE; c esim_private.topup_cache%ROWTYPE; q esim_private.recharge_quotes%ROWTYPE;
 o jsonb; retail jsonb; total numeric; reason text;
BEGIN
 IF u IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
 SELECT * INTO p FROM public.user_esims WHERE id=p_profile_id AND user_id=u FOR UPDATE;
 IF NOT FOUND THEN RETURN '{"status":"PROFILE_UNAVAILABLE"}'::jsonb; END IF;
 IF NOT (SELECT discovery_enabled FROM esim_private.recharge_policy WHERE singleton) THEN RETURN '{"status":"DISCOVERY_DISABLED"}'::jsonb; END IF;
 reason:=esim_private.topup_refusal(p); IF reason IS NOT NULL THEN RETURN jsonb_build_object('status',reason); END IF;
 SELECT * INTO c FROM esim_private.topup_cache WHERE profile_id=p.id AND owner_id=u AND account_id=p.supplier_account_id;
 IF NOT FOUND OR c.status<>'ready' OR c.expires_at<=now() OR c.context IS DISTINCT FROM esim_private.topup_context(p)
  OR p_offer_version IS NULL OR c.version IS DISTINCT FROM p_offer_version THEN RETURN '{"status":"STALE_OFFERS"}'::jsonb; END IF;
 SELECT value INTO o FROM jsonb_array_elements(c.offers) WHERE value->>'package_id'=p_package_id;
 IF NOT FOUND THEN RETURN '{"status":"INCOMPATIBLE_OFFER"}'::jsonb; END IF;
 IF o->>'data_type'<>'1' THEN RETURN '{"status":"DURATION_QUOTE_UNAVAILABLE"}'::jsonb; END IF;
 retail:=esim_private.topup_retail(o,u); total:=(retail->>'retail_total')::numeric;
 IF total IS NULL OR total<=0 OR total::text IN('NaN','Infinity','-Infinity') THEN RETURN '{"status":"PRICE_UNAVAILABLE"}'::jsonb; END IF;
 IF p_expected_total IS NULL OR total IS DISTINCT FROM p_expected_total THEN RETURN '{"status":"PRICE_CHANGED"}'::jsonb; END IF;
 SELECT * INTO q FROM esim_private.recharge_quotes WHERE owner_id=u AND profile_id=p.id AND cache_version=c.version
  AND package_id=p_package_id AND retail_total=total AND expires_at>now() AND NOT EXISTS(SELECT 1 FROM public.esim_orders accepted WHERE accepted.recharge_quote_id=recharge_quotes.id) ORDER BY created_at DESC LIMIT 1;
 IF NOT FOUND THEN
  IF (SELECT count(*) FROM esim_private.recharge_quotes WHERE owner_id=u AND created_at>now()-interval '1 minute')>=20 THEN RETURN '{"status":"RATE_LIMITED"}'::jsonb; END IF;
  INSERT INTO esim_private.recharge_quotes(owner_id,payer_id,profile_id,account_id,provider,action,package_id,cache_version,context,
   wholesale_usd,retail_total,currency,duration_value,duration_unit,retail_snapshot,expires_at)
  VALUES(u,u,p.id,p.supplier_account_id,p.provider,'fixed_bundle_recharge',p_package_id,c.version,c.context,
   (o->>'wholesale_usd')::numeric,total,'USD',(o->>'duration_value')::integer,o->>'duration_unit',retail,least(c.expires_at,now()+interval '2 minutes')) RETURNING * INTO q;
 END IF;
 RETURN jsonb_build_object('status','QUOTED','quote_id',q.id,'acceptance_key',q.acceptance_key,'owner_id',u,'payer_id',u,
  'profile_id',p.id,'action',q.action,'offer',q.retail_snapshot,'expires_at',q.expires_at,'acceptance_enabled',esim_private.recharge_can_accept())
  ||esim_private.topup_balance(u,total);
END $function$
;

CREATE OR REPLACE FUNCTION esim_private.quote_auto_daily(u uuid, p_profile_id uuid, p_package_id text, p_offer_version uuid, p_period_count integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE p public.user_esims; c esim_private.topup_cache; r esim_private.daily_prices; q esim_private.recharge_quotes; o jsonb; retail jsonb; total numeric; reason text;
BEGIN
 PERFORM esim_private.require_live_owner(u);
 IF p_period_count IS NULL OR p_period_count NOT BETWEEN 1 AND 365 THEN RETURN '{"status":"INVALID_DURATION"}'::jsonb; END IF;
 SELECT * INTO p FROM public.user_esims WHERE id=p_profile_id AND user_id=u FOR UPDATE;
 IF NOT FOUND THEN RETURN '{"status":"PROFILE_UNAVAILABLE"}'::jsonb; END IF;
 IF NOT(SELECT discovery_enabled FROM esim_private.recharge_policy WHERE singleton) THEN RETURN '{"status":"DISCOVERY_DISABLED"}'::jsonb; END IF;
 reason:=esim_private.topup_refusal(p);IF reason IS NOT NULL THEN RETURN jsonb_build_object('status',reason); END IF;
 SELECT * INTO c FROM esim_private.topup_cache WHERE profile_id=p.id AND owner_id=u AND account_id=p.supplier_account_id;
 IF c.status IS DISTINCT FROM 'ready' OR c.expires_at<=now() OR c.version IS DISTINCT FROM p_offer_version OR c.context IS DISTINCT FROM esim_private.topup_context(p) THEN RETURN '{"status":"STALE_OFFERS"}'::jsonb; END IF;
 SELECT value INTO o FROM jsonb_array_elements(c.offers) WHERE value->>'package_id'=p_package_id;
 IF o IS NULL OR coalesce(o->>'data_type','') NOT IN('2','3','4') OR coalesce(o->>'topup_support','')<>'daily_extension'
  OR coalesce(p.plan_details->>'topup_support','')<>'daily_extension' OR coalesce(p.plan_details->>'plan_type','') NOT IN('daily_throttled','daily_cutoff','daily_unlimited')
  OR coalesce(o->>'alias',o->>'package_id') IS DISTINCT FROM coalesce(p.plan_details->>'product_alias',p.plan_details->>'supplier_product_id') THEN RETURN '{"status":"INCOMPATIBLE_OFFER"}'::jsonb; END IF;
 SELECT * INTO r FROM esim_private.daily_prices WHERE account_id=p.supplier_account_id AND package_id=p_package_id AND profile_id=p.id AND period_count=p_period_count ORDER BY revision DESC LIMIT 1;
 IF NOT FOUND OR NOT esim_private.daily_price_current(r.id,c.context,o) THEN RETURN '{"status":"DURATION_PRICE_UNAVAILABLE"}'::jsonb; END IF;
 IF r.max_recharges IS NULL OR r.observed_recharges IS NULL OR r.observed_recharges>=r.max_recharges THEN RETURN '{"status":"DAILY_LIMIT_UNVERIFIED"}'::jsonb; END IF;
 total:=public.resolve_esim_offer_price(r.wholesale_total,u);
 IF total IS NULL OR total<=0 OR total::text IN('NaN','Infinity','-Infinity') THEN RETURN '{"status":"PRICE_UNAVAILABLE"}'::jsonb; END IF;
 retail:=esim_private.topup_retail(o,u)||jsonb_build_object('retail_total',total,'duration_value',p_period_count,'duration_unit','DAY','period_count',p_period_count,
 'quote_supported',true,'effect','validity_only','daily_reset_time',NULL,'daily_reset_known',false);
 IF (SELECT count(*) FROM esim_private.recharge_quotes WHERE owner_id=u AND created_at>now()-interval '1 minute')>=20 THEN RETURN '{"status":"RATE_LIMITED"}'::jsonb; END IF;
 INSERT INTO esim_private.recharge_quotes(owner_id,payer_id,profile_id,account_id,provider,action,package_id,cache_version,context,wholesale_usd,retail_total,currency,duration_value,duration_unit,period_count,retail_snapshot,expires_at,daily_price_id)
 VALUES(u,u,p.id,p.supplier_account_id,p.provider,'daily_extension',p_package_id,c.version,c.context,r.wholesale_total,total,'USD',p_period_count,'DAY',p_period_count,retail,least(c.expires_at,r.expires_at,now()+interval '2 minutes'),r.id) RETURNING * INTO q;
 RETURN jsonb_build_object('status','QUOTED','quote_id',q.id,'acceptance_key',q.acceptance_key,'owner_id',u,'payer_id',u,'profile_id',p.id,'action',q.action,'offer',retail,
 'expires_at',q.expires_at,'acceptance_enabled',esim_private.recharge_can_accept() AND (SELECT daily_duration_enabled AND daily_contract_verified FROM esim_private.accounts WHERE id=p.supplier_account_id))||esim_private.topup_balance(u,total);
END $function$
;

CREATE OR REPLACE FUNCTION esim_private.topup_refusal(p user_esims)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$DECLARE reason text; BEGIN
 IF esim_private.control_pending(p.id) THEN RETURN 'UNRESOLVED_OPERATION'; END IF;
 reason:=esim_private.topup_refusal_base(p); IF reason IS NOT NULL THEN RETURN reason; END IF;
 IF EXISTS(SELECT 1 FROM public.esim_orders WHERE recharge_profile_id=p.id AND status IN('pending','processing')) THEN RETURN 'UNRESOLVED_OPERATION'; END IF;
 RETURN NULL; END $function$
;

CREATE OR REPLACE FUNCTION public.service_esim_mark_submitted(p_order_id uuid, p_lease uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE r esim_private.order_runs; o public.esim_orders; p public.user_esims; q esim_private.recharge_quotes; reason text; reject_code text; available numeric;
BEGIN
 PERFORM esim_private.require_service();SELECT * INTO STRICT o FROM public.esim_orders WHERE id=p_order_id;
 PERFORM 1 FROM public.wallets WHERE user_id=o.user_id FOR UPDATE;
 IF o.recharge_profile_id IS NOT NULL THEN SELECT * INTO STRICT p FROM public.user_esims WHERE id=o.recharge_profile_id FOR UPDATE; END IF;
 SELECT * INTO STRICT r FROM esim_private.order_runs WHERE order_id=o.id FOR UPDATE;
 IF p_lease IS NULL OR r.lease IS DISTINCT FROM p_lease OR r.lease_until IS NULL OR r.lease_until<now() OR r.state<>'prepared' OR r.submitted_at IS NOT NULL THEN RETURN false; END IF;
 IF r.finance_kind<>'reserved' OR r.hold_id IS NULL OR r.payer_id IS DISTINCT FROM o.user_id THEN RETURN false; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.esim_suppliers WHERE code=o.provider AND is_active) THEN reject_code:='SUPPLIER_DISABLED'; END IF;
 IF o.operation_kind IN('fixed_recharge','daily_extension') THEN
  IF NOT esim_private.recharge_can_accept() THEN reject_code:='SUBMISSION_DISABLED'; END IF;
  SELECT * INTO STRICT q FROM esim_private.recharge_quotes WHERE id=o.recharge_quote_id;
  IF q.expires_at<=now() THEN reject_code:='QUOTE_EXPIRED'; END IF;
  IF q.context IS DISTINCT FROM esim_private.topup_context(p) OR p.user_id IS DISTINCT FROM o.user_id
   OR p.supplier_account_id IS DISTINCT FROM r.account_id OR esim_private.topup_refusal_base(p) IS NOT NULL THEN reject_code:='PROFILE_CHANGED'; END IF;
  IF EXISTS(SELECT 1 FROM public.esim_orders WHERE recharge_profile_id=p.id AND id<>o.id AND status IN('pending','processing')) THEN reject_code:='PROFILE_CHANGED'; END IF;
 ELSE
  IF NOT EXISTS(SELECT 1 FROM esim_private.accounts WHERE id=r.account_id AND new_sales_enabled AND wallet_boundary_verified) THEN reject_code:='SUBMISSION_DISABLED'; END IF;
  IF o.daily_purchase_quote_id IS NULL AND NOT EXISTS(SELECT 1 FROM public.esim_offers_cache WHERE provider=o.provider AND bundle_name=o.bundle_name AND is_active AND wholesale_price_usd=o.wholesale_price_usd) THEN reject_code:='PRICE_CHANGED'; END IF;
 END IF;
 IF public.resolve_esim_offer_price(o.wholesale_price_usd,o.user_id) IS DISTINCT FROM o.retail_price_usd THEN reject_code:='PRICE_CHANGED'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=o.user_id AND NOT coalesce(is_suspended,false)) THEN reject_code:='SUBMISSION_DISABLED'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.wallet_holds WHERE id=r.hold_id AND status='active' AND user_id=r.payer_id AND amount=o.total_amount_usd AND expires_at IS NULL) THEN reject_code:='SUBMISSION_DISABLED'; END IF;
 SELECT w.balance-coalesce((SELECT sum(amount) FROM public.wallet_holds WHERE wallet_id=w.id AND status='active'),0) INTO available FROM public.wallets w WHERE user_id=r.payer_id AND currency='USD';
 IF available IS NULL OR available<0 OR available::text IN('NaN','Infinity','-Infinity') THEN reject_code:='SUBMISSION_DISABLED'; END IF;
 IF (o.daily_purchase_quote_id IS NOT NULL OR o.operation_kind='daily_extension') AND NOT EXISTS(SELECT 1 FROM esim_private.accounts WHERE id=r.account_id AND daily_duration_enabled AND daily_contract_verified) THEN reject_code:='SUBMISSION_DISABLED'; END IF;
 IF NOT esim_private.daily_order_current(o) THEN reject_code:='PRICE_CHANGED'; END IF;
 IF o.recharge_profile_id IS NOT NULL AND esim_private.control_pending(o.recharge_profile_id) THEN reject_code:='PROFILE_CHANGED'; END IF;
 IF EXISTS(SELECT 1 FROM esim_private.automation_orders WHERE order_id=o.id) AND NOT EXISTS(
 SELECT 1 FROM esim_private.automation_orders x JOIN esim_private.automation_consents c ON c.profile_id=x.profile_id JOIN esim_private.accounts a ON a.id=r.account_id
 WHERE x.order_id=o.id AND c.enabled AND c.revision=x.consent_revision AND c.owner_id=o.user_id AND c.payer_id=r.payer_id
 AND (c.ends_at IS NULL OR c.ends_at>now()) AND a.automation_enabled AND o.total_amount_usd<=c.max_charge AND o.total_amount_usd<=c.reviewed_charge
 AND esim_private.automation_exposure(c.profile_id)<=c.monthly_cap) THEN reject_code:='SUBMISSION_DISABLED'; END IF;
 IF reject_code IS NOT NULL THEN PERFORM public.service_esim_fail_before_submit(o.id,p_lease,reject_code);RETURN false; END IF;
 UPDATE esim_private.order_runs SET state='submitted',submitted_at=now(),updated_at=now() WHERE order_id=o.id;
 UPDATE public.esim_orders SET delivery_state='submitted' WHERE id=o.id;RETURN true;
END $function$
;

CREATE FUNCTION public.service_esim_prepare_automation() RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM esim_private.require_service();
 INSERT INTO esim_private.profile_work(profile_id,next_check_at,requested_at)
 SELECT p.id,now(),now() FROM public.user_esims p JOIN esim_private.automation_consents c ON c.profile_id=p.id JOIN esim_private.accounts a ON a.id=p.supplier_account_id
 WHERE c.enabled AND a.automation_enabled AND p.profile_state IN('issued','active') AND (p.last_observation_at IS NULL OR p.last_observation_at<now()-interval '15 minutes' OR (c.trigger_kind='fixed_low_data' AND (p.usage_observed_at IS NULL OR p.usage_observed_at<now()-interval '15 minutes')))
 ON CONFLICT(profile_id) DO UPDATE SET next_check_at=least(profile_work.next_check_at,now()),requested_at=now();
 INSERT INTO esim_private.topup_cache(profile_id,owner_id,account_id,context,status,requested_at)
 SELECT p.id,p.user_id,p.supplier_account_id,esim_private.topup_context(p),'pending',now() FROM public.user_esims p JOIN esim_private.automation_consents c ON c.profile_id=p.id JOIN esim_private.accounts a ON a.id=p.supplier_account_id
 WHERE c.enabled AND a.automation_enabled AND p.profile_state IN('issued','active')
 ON CONFLICT(profile_id) DO UPDATE SET status='pending',requested_at=now() WHERE topup_cache.expires_at<=now() AND (topup_cache.lease_until IS NULL OR topup_cache.lease_until<now());
END $$;
REVOKE ALL ON FUNCTION public.service_esim_prepare_automation() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.service_esim_prepare_automation() TO service_role;

CREATE OR REPLACE FUNCTION public.service_esim_alert_is_current(p_notification_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE a esim_private.alert_events; n public.notifications;
BEGIN
 PERFORM esim_private.require_service();
 SELECT * INTO n FROM public.notifications WHERE id=p_notification_id;
 IF NOT FOUND OR n.expires_at<=now() THEN RETURN false; END IF;
 IF n.event_type='esim_automation_paused' THEN RETURN EXISTS(SELECT 1 FROM esim_private.automation_consents c JOIN public.user_esims p ON p.id=c.profile_id WHERE c.profile_id=(n.template_data->>'profile_id')::uuid AND c.owner_id=n.user_id AND p.user_id=n.user_id AND NOT c.enabled AND c.revision=(n.template_data->>'revision')::integer AND c.stop_reason=n.template_data->>'reason'); END IF;
 SELECT * INTO a FROM esim_private.alert_events WHERE notification_id=n.id AND decision='queued';
 IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM esim_private.alert_policy WHERE id AND enabled) THEN RETURN false; END IF;
 IF a.profile_id IS NOT NULL THEN
  RETURN EXISTS(SELECT 1 FROM public.user_esims p JOIN esim_private.alert_profile_state s ON s.profile_id=p.id
   WHERE p.id=a.profile_id AND p.user_id=n.user_id AND s.cycle_id=a.cycle_id)
   AND esim_private.alert_is_relevant(a.profile_id,a.event_type,a.threshold);
 END IF;
 RETURN EXISTS(SELECT 1 FROM public.esim_orders o JOIN esim_private.order_runs r ON r.order_id=o.id
  WHERE o.id=a.order_id AND o.user_id=n.user_id AND a.event_type='esim_order_'||r.state);
END $function$
;

CREATE FUNCTION public.admin_esim_support(p_query text DEFAULT '') RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
 PERFORM public.assert_admin();
 IF length(coalesce(p_query,''))>100 THEN RAISE EXCEPTION 'Invalid search'; END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) INTO result FROM (
 SELECT e.id,e.user_id AS owner_id,right(e.iccid,4) AS iccid_suffix,e.profile_state,e.installation_state,e.bundle_state,e.last_observation_at,e.usage_observed_at,e.usage_error_code,
 (SELECT coalesce(jsonb_agg(jsonb_build_object('id',c.id,'action',c.action,'state',c.state,'submitted_at',c.submitted_at,'error_code',c.error_code)),'[]'::jsonb) FROM esim_private.controls c WHERE c.profile_id=e.id) AS controls,
 (SELECT coalesce(jsonb_agg(jsonb_build_object('order_id',o.id,'kind',o.operation_kind,'status',o.status,'state',r.state,'error_code',r.error_code)),'[]'::jsonb) FROM public.esim_orders o LEFT JOIN esim_private.order_runs r ON r.order_id=o.id WHERE o.id=e.order_id OR o.recharge_profile_id=e.id) AS operations
 FROM public.user_esims e WHERE e.provider='esimaccess' AND (e.id::text=p_query OR e.user_id::text=p_query OR
 (p_query~'^[0-9]{4}$' AND right(e.iccid,4)=p_query) OR (coalesce(p_query,'')='' AND (esim_private.control_pending(e.id)
 OR EXISTS(SELECT 1 FROM esim_private.order_runs r JOIN public.esim_orders o ON o.id=r.order_id WHERE (o.id=e.order_id OR o.recharge_profile_id=e.id) AND r.state IN('reconciling','support_required')))))
 ORDER BY e.last_observation_at NULLS FIRST LIMIT 50) x;
 PERFORM public.admin_log('esim.support.search','esim',NULL,NULL,jsonb_build_object('returned',jsonb_array_length(result)),'Redacted support search');
 RETURN jsonb_build_object('profiles',result,'runtime',public.admin_esim_runtime_status(),
 'switches',(SELECT jsonb_build_object('cancellation_enabled',cancellation_enabled,'service_controls_enabled',service_controls_enabled,'automation_enabled',automation_enabled) FROM esim_private.accounts WHERE account_key='primary'),
 'funding_health','UNKNOWN','credential_health','UNKNOWN',
 'catalogue_last_sync',(SELECT max(updated_at) FROM public.esim_offers_cache WHERE provider='esimaccess'));
END $$;
CREATE FUNCTION public.admin_esim_support_action(p_profile_id uuid,p_action text,p_reason text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.assert_admin();
 IF p_action IS NULL OR p_action NOT IN('refresh','escalate','reconcile') OR p_reason IS NULL OR length(trim(p_reason)) NOT BETWEEN 8 AND 500 THEN RAISE EXCEPTION 'A reason is required'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.user_esims WHERE id=p_profile_id AND provider='esimaccess') THEN RETURN '{"status":"PROFILE_UNAVAILABLE"}'::jsonb; END IF;
 IF p_action='refresh' THEN
  INSERT INTO esim_private.profile_work(profile_id,next_check_at,requested_at) VALUES(p_profile_id,now(),now())
  ON CONFLICT(profile_id) DO UPDATE SET next_check_at=now(),requested_at=now(),terminal_checks=0;
 ELSIF p_action='escalate' THEN
  INSERT INTO esim_private.support_cases(profile_id,actor_id,reason) VALUES(p_profile_id,auth.uid(),p_reason);
 ELSE
  -- Read-only recovery can inspect a quarantined request, never POST again.
  UPDATE esim_private.controls SET state='reconciling',next_check_at=now(),attempts=0 WHERE profile_id=p_profile_id AND state='support_required' AND submitted_at IS NOT NULL;
 END IF;
 PERFORM public.admin_log('esim.support.'||p_action,'esim_profile',p_profile_id::text,NULL,jsonb_build_object('read_only',true),p_reason);
 RETURN '{"status":"QUEUED","read_only":true}'::jsonb;
END $$;
CREATE FUNCTION public.admin_pause_esim_capability(p_capability text,p_reason text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.assert_admin();
 IF p_reason IS NULL OR length(trim(p_reason)) NOT BETWEEN 8 AND 500 OR p_capability IS NULL OR p_capability NOT IN('cancel','service_controls','automation') THEN RAISE EXCEPTION 'Invalid capability or reason'; END IF;
 UPDATE esim_private.accounts SET cancellation_enabled=CASE WHEN p_capability='cancel' THEN false ELSE cancellation_enabled END,
 service_controls_enabled=CASE WHEN p_capability='service_controls' THEN false ELSE service_controls_enabled END,
 automation_enabled=CASE WHEN p_capability='automation' THEN false ELSE automation_enabled END WHERE account_key='primary';
 PERFORM public.admin_log('esim.capability.pause','esim',p_capability,NULL,jsonb_build_object('enabled',false),p_reason);
 RETURN '{"status":"PAUSED","recovery_preserved":true}'::jsonb;
END $$;

DO $acl$ DECLARE n text;r record; BEGIN
 FOREACH n IN ARRAY ARRAY['refund_scopes','control_quotes','controls','cancellation_refunds','support_cases','automation_consents','automation_orders','automation_audit'] LOOP
  EXECUTE format('ALTER TABLE esim_private.%I ENABLE ROW LEVEL SECURITY',n);
  EXECUTE format('REVOKE ALL ON esim_private.%I FROM PUBLIC,anon,authenticated',n);
  EXECUTE format('GRANT SELECT ON esim_private.%I TO service_role',n);
 END LOOP;
 -- The schema is private. Revoke every newly added helper explicitly.
 FOR r IN SELECT p.oid::regprocedure ident FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='esim_private'
 AND p.proname IN('refund_context','control_pending','control_refusal','automation_exposure','stop_automation','accept_recharge','quote_auto_daily','quote_auto_fixed') LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',r.ident);
 END LOOP;
 FOR r IN SELECT p.oid::regprocedure ident,p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'
 AND p.proname IN('service_esim_set_refund_scope','get_esim_controls','request_esim_control','service_esim_claim_control','service_esim_mark_control_submitted','service_esim_finish_control','service_esim_settle_cancellation','get_esim_automation','set_esim_automation','service_esim_evaluate_automation','admin_esim_support','admin_esim_support_action','admin_pause_esim_capability') LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',r.ident);
  IF r.proname LIKE 'service_%' THEN EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role',r.ident);
  ELSE EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated',r.ident); END IF;
 END LOOP;
END $acl$;
NOTIFY pgrst,'reload schema';


COMMIT;
