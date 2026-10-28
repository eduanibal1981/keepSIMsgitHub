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
