-- ESIM-08 uses the existing order/run engine and wallet primitives.
ALTER TABLE esim_private.accounts ADD COLUMN recharge_enabled boolean NOT NULL DEFAULT false,
 ADD COLUMN recharge_contract_verified boolean NOT NULL DEFAULT false,
 ADD COLUMN wallet_boundary_verified boolean NOT NULL DEFAULT false;
ALTER TABLE public.esim_orders ADD COLUMN operation_kind text NOT NULL DEFAULT 'purchase'
 CHECK(operation_kind IN('purchase','fixed_recharge')),
 ADD COLUMN recharge_profile_id uuid REFERENCES public.user_esims(id),
 ADD COLUMN recharge_quote_id uuid REFERENCES esim_private.recharge_quotes(id);
ALTER TABLE public.esim_orders ADD COLUMN client_request_key uuid;
CREATE UNIQUE INDEX esim_purchase_request_key ON public.esim_orders(user_id,client_request_key) WHERE client_request_key IS NOT NULL;
ALTER TABLE public.esim_orders ADD CONSTRAINT esim_operation_shape CHECK(
 (operation_kind='purchase' AND recharge_profile_id IS NULL AND recharge_quote_id IS NULL) OR
 (operation_kind='fixed_recharge' AND recharge_profile_id IS NOT NULL AND recharge_quote_id IS NOT NULL AND quantity=1));
CREATE UNIQUE INDEX esim_one_quote_acceptance ON public.esim_orders(recharge_quote_id) WHERE recharge_quote_id IS NOT NULL;
CREATE UNIQUE INDEX esim_one_unresolved_profile_action ON public.esim_orders(recharge_profile_id)
 WHERE recharge_profile_id IS NOT NULL AND status IN('pending','processing');
CREATE INDEX esim_orders_recharge_owner ON public.esim_orders(user_id,recharge_profile_id,created_at);
ALTER TABLE esim_private.order_runs ADD COLUMN finance_kind text NOT NULL DEFAULT 'legacy_unverified'
 CHECK(finance_kind IN('reserved','legacy_debit','legacy_unverified')),
 ADD COLUMN payer_id uuid, ADD COLUMN hold_id uuid REFERENCES public.wallet_holds(id),
 ADD COLUMN debit_tx_id uuid REFERENCES public.wallet_transactions(id),
 ADD COLUMN settlement_tx_id uuid REFERENCES public.wallet_transactions(id),
 ADD COLUMN settlement_state text NOT NULL DEFAULT 'pending'
 CHECK(settlement_state IN('pending','capturing','captured','releasing','released','refunding','refunded','support_required')),
 ADD COLUMN receipt jsonb, ADD COLUMN receipt_hash text, ADD COLUMN receipt_at timestamptz;
ALTER TABLE esim_private.order_runs DROP CONSTRAINT order_runs_state_check;
ALTER TABLE esim_private.order_runs ADD CONSTRAINT order_runs_state_check CHECK(state IN('prepared','submitted','reconciling','support_required','completed','failed'));
CREATE UNIQUE INDEX esim_one_hold ON esim_private.order_runs(hold_id) WHERE hold_id IS NOT NULL;
CREATE UNIQUE INDEX esim_one_debit ON esim_private.order_runs(debit_tx_id) WHERE debit_tx_id IS NOT NULL;
CREATE TABLE esim_private.entitlements (
 order_id uuid PRIMARY KEY REFERENCES public.esim_orders(id), profile_id uuid NOT NULL REFERENCES public.user_esims(id),
 account_id uuid NOT NULL REFERENCES esim_private.accounts(id), supplier_topup_ref text NOT NULL,
 package_id text NOT NULL, allowance_bytes bigint NOT NULL CHECK(allowance_bytes>=0),
 duration_value integer NOT NULL,duration_unit text NOT NULL,retail_total numeric(12,2) NOT NULL CHECK(retail_total>0),
 currency text NOT NULL CHECK(currency='USD'),provider_expires_at timestamptz,expiry_confirmed boolean NOT NULL,created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(account_id,supplier_topup_ref)
);
CREATE INDEX esim_entitlements_profile ON esim_private.entitlements(profile_id,created_at);
ALTER TABLE esim_private.entitlements ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON esim_private.entitlements FROM PUBLIC,anon,authenticated;
GRANT SELECT ON esim_private.entitlements TO service_role;
-- Transaction-local capture provenance. Rows are inserted/deleted only by the
-- existing capture primitive; clients cannot forge a reservation exclusion.
CREATE TABLE esim_private.capture_context(txid bigint NOT NULL,hold_id uuid NOT NULL,wallet_id uuid NOT NULL,PRIMARY KEY(txid,hold_id));
CREATE INDEX esim_capture_context_wallet ON esim_private.capture_context(txid,wallet_id);
ALTER TABLE esim_private.capture_context ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON esim_private.capture_context FROM PUBLIC,anon,authenticated;
GRANT SELECT ON esim_private.capture_context TO service_role;
CREATE INDEX IF NOT EXISTS esim_active_holds_wallet ON public.wallet_holds(wallet_id) WHERE status='active';

-- Deliberate allowlist extensions; preserve all existing discriminator values.
ALTER TABLE public.wallet_holds ALTER COLUMN expires_at DROP NOT NULL;
ALTER TABLE public.wallet_holds ADD CONSTRAINT esim_hold_no_expiry CHECK(expires_at IS NOT NULL OR
 (order_type IN('esim_purchase','esim_recharge') AND order_reference_id LIKE 'esim_op:%'));
DO $$DECLARE expression text; BEGIN
 SELECT pg_get_expr(conbin,conrelid) INTO STRICT expression FROM pg_constraint
 WHERE conrelid='public.wallet_holds'::regclass AND conname='wallet_holds_order_type_check';
 ALTER TABLE public.wallet_holds DROP CONSTRAINT wallet_holds_order_type_check;
 EXECUTE format('ALTER TABLE public.wallet_holds ADD CONSTRAINT wallet_holds_order_type_check CHECK ((%s) OR order_type=''esim_recharge'')',expression);
 SELECT pg_get_expr(conbin,conrelid) INTO STRICT expression FROM pg_constraint
 WHERE conrelid='public.wallet_transactions'::regclass AND conname='wallet_transactions_type_check';
 ALTER TABLE public.wallet_transactions DROP CONSTRAINT wallet_transactions_type_check;
 EXECUTE format('ALTER TABLE public.wallet_transactions ADD CONSTRAINT wallet_transactions_type_check CHECK ((%s) OR type IN(''esim_recharge_debit'',''esim_recharge_refund''))',expression);
END $$;

CREATE FUNCTION esim_private.recharge_can_accept() RETURNS boolean LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT coalesce((SELECT a.recharge_enabled AND a.recharge_contract_verified AND a.wallet_boundary_verified
 AND p.discovery_enabled FROM esim_private.accounts a CROSS JOIN esim_private.recharge_policy p WHERE a.account_key='primary' AND p.singleton),false);
$$;
CREATE FUNCTION esim_private.require_live_owner(u uuid) RETURNS void LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
 IF u IS NULL OR NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=u AND NOT coalesce(is_suspended,false)) THEN
  RAISE EXCEPTION 'Account unavailable' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=u AND deleted_at IS NULL AND (banned_until IS NULL OR banned_until<=now())) THEN
  RAISE EXCEPTION 'Account unavailable' USING ERRCODE='42501'; END IF;
END $$;
CREATE FUNCTION esim_private.require_money_session(u uuid) RETURNS void LANGUAGE plpgsql SET search_path='' AS $$
DECLARE session_id_value text;
BEGIN
 PERFORM esim_private.require_live_owner(u);
 session_id_value:=coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb->>'session_id';
 IF coalesce(session_id_value,'')!~'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN
  RAISE EXCEPTION 'Active session required' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM auth.sessions WHERE id=session_id_value::uuid AND user_id=u AND (not_after IS NULL OR not_after>now())) THEN
  RAISE EXCEPTION 'Active session required' USING ERRCODE='42501'; END IF;
END $$;

-- Namespace the new holds so historical holds and other workers are unaffected.
CREATE FUNCTION esim_private.reserve_order(p_order_id uuid) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE o public.esim_orders; r esim_private.order_runs; h uuid; w public.wallets;
BEGIN
 SELECT * INTO STRICT o FROM public.esim_orders WHERE id=p_order_id;
 IF auth.uid() IS DISTINCT FROM o.user_id AND coalesce(auth.role(),'')<>'service_role' THEN RAISE EXCEPTION 'Owner required' USING ERRCODE='42501'; END IF;
 PERFORM esim_private.require_live_owner(o.user_id);
 SELECT * INTO STRICT w FROM public.wallets WHERE user_id=o.user_id FOR UPDATE;
 IF w.currency IS DISTINCT FROM 'USD' THEN RAISE EXCEPTION 'Unsupported wallet currency'; END IF;
 SELECT * INTO STRICT r FROM esim_private.order_runs WHERE order_id=o.id FOR UPDATE;
 IF r.hold_id IS NOT NULL THEN RETURN r.hold_id; END IF;
 IF r.state<>'prepared' OR r.submitted_at IS NOT NULL OR o.provider<>'esimaccess' THEN RAISE EXCEPTION 'Reservation intent unavailable'; END IF;
 IF EXISTS(SELECT 1 FROM public.wallet_transactions WHERE reference_id='esim_'||o.id::text AND type='esim_purchase_debit') THEN
  RAISE EXCEPTION 'Already-debited legacy order cannot be reserved'; END IF;
 UPDATE esim_private.order_runs SET finance_kind='reserved',payer_id=o.user_id WHERE order_id=o.id;
 h:=public.reserve_wallet_funds(o.user_id,o.total_amount_usd,
  CASE WHEN o.operation_kind='fixed_recharge' THEN 'esim_recharge' ELSE 'esim_purchase' END,'esim_op:'||o.id::text,'eSIM operation reservation',120);
 UPDATE esim_private.order_runs SET hold_id=h WHERE order_id=o.id;
 UPDATE public.wallet_holds SET expires_at=NULL WHERE id=h;
 RETURN h;
END $$;

CREATE FUNCTION esim_private.guard_operation_hold() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r esim_private.order_runs; o public.esim_orders; operation_id uuid;
BEGIN
 IF NEW.order_type NOT IN('esim_purchase','esim_recharge') OR NEW.order_reference_id NOT LIKE 'esim_op:%' THEN RETURN NEW; END IF;
 operation_id:=substr(NEW.order_reference_id,9)::uuid;
 SELECT * INTO STRICT r FROM esim_private.order_runs WHERE order_id=operation_id;
 SELECT * INTO STRICT o FROM public.esim_orders WHERE id=operation_id;
 IF r.finance_kind<>'reserved' OR r.payer_id IS DISTINCT FROM NEW.user_id OR o.total_amount_usd IS DISTINCT FROM NEW.amount
  OR NEW.currency<>'USD' OR NEW.wallet_id IS DISTINCT FROM (SELECT id FROM public.wallets WHERE user_id=r.payer_id)
  OR NEW.order_type IS DISTINCT FROM (CASE WHEN o.operation_kind='fixed_recharge' THEN 'esim_recharge' ELSE 'esim_purchase' END) THEN
  RAISE EXCEPTION 'eSIM hold binding mismatch'; END IF;
 IF TG_OP='INSERT' THEN
  IF r.hold_id IS NOT NULL OR r.state<>'prepared' OR NEW.status<>'active' THEN RAISE EXCEPTION 'Invalid eSIM reservation'; END IF;
 ELSE
  IF (NEW.wallet_id,NEW.user_id,NEW.amount,NEW.order_type,NEW.order_reference_id,NEW.currency) IS DISTINCT FROM
     (OLD.wallet_id,OLD.user_id,OLD.amount,OLD.order_type,OLD.order_reference_id,OLD.currency) THEN RAISE EXCEPTION 'Immutable eSIM hold'; END IF;
  IF NEW.status IS DISTINCT FROM OLD.status THEN
   PERFORM esim_private.require_service();
   IF (NEW.status='captured' AND r.settlement_state='capturing' AND r.receipt IS NOT NULL) OR
      (NEW.status='released' AND r.settlement_state='releasing' AND r.state='failed' AND r.receipt IS NOT NULL) THEN NULL;
   ELSE RAISE EXCEPTION 'Unproven eSIM settlement'; END IF;
  END IF;
 END IF;
 -- New reservations have no timer-based release, even after a process restart.
 NEW.expires_at:=NULL;
 RETURN NEW;
END $$;
CREATE TRIGGER guard_esim_operation_hold BEFORE INSERT OR UPDATE ON public.wallet_holds
FOR EACH ROW EXECUTE FUNCTION esim_private.guard_operation_hold();

CREATE FUNCTION esim_private.guard_reserved_wallet() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE floor_amount numeric;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.wallet_holds h JOIN esim_private.order_runs r ON r.hold_id=h.id
  WHERE h.wallet_id=OLD.id AND h.status='active') THEN RETURN NEW; END IF;
 IF NEW.balance IS NULL OR NEW.balance::text IN('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'Invalid protected wallet balance'; END IF;
 IF NEW.balance>=OLD.balance THEN RETURN NEW; END IF;
 SELECT coalesce(sum(h.amount),0) INTO floor_amount FROM public.wallet_holds h
 WHERE h.wallet_id=OLD.id AND h.status='active' AND NOT EXISTS(
  SELECT 1 FROM esim_private.capture_context c WHERE c.txid=txid_current() AND c.hold_id=h.id AND c.wallet_id=OLD.id);
 IF NEW.balance<floor_amount THEN RAISE EXCEPTION 'Active reservations protect these funds'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER guard_esim_reserved_wallet BEFORE UPDATE OF balance ON public.wallets
FOR EACH ROW EXECUTE FUNCTION esim_private.guard_reserved_wallet();

CREATE FUNCTION public.accept_esim_topup(p_quote_id uuid,p_acceptance_key uuid,p_device_id text DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); q esim_private.recharge_quotes; p public.user_esims; c esim_private.topup_cache;
 o public.esim_orders; total numeric; reason text; guard jsonb;
BEGIN
 PERFORM esim_private.require_money_session(u);
 SELECT * INTO q FROM esim_private.recharge_quotes WHERE id=p_quote_id AND owner_id=u AND payer_id=u AND acceptance_key=p_acceptance_key;
 IF NOT FOUND THEN RETURN '{"status":"QUOTE_UNAVAILABLE"}'::jsonb; END IF;
 -- Wallet -> profile -> quote/run/hold is the common financial lock order.
 PERFORM 1 FROM public.wallets WHERE user_id=u FOR UPDATE;
 SELECT * INTO p FROM public.user_esims WHERE id=q.profile_id AND user_id=u FOR UPDATE;
 IF NOT FOUND THEN RETURN '{"status":"PROFILE_UNAVAILABLE"}'::jsonb; END IF;
 SELECT * INTO o FROM public.esim_orders WHERE recharge_quote_id=q.id AND user_id=u;
 IF FOUND THEN RETURN jsonb_build_object('status','ADOPTED','order_id',o.id); END IF;
 IF NOT esim_private.recharge_can_accept() THEN RETURN '{"status":"RECHARGE_DISABLED"}'::jsonb; END IF;
 reason:=esim_private.topup_refusal(p);IF reason IS NOT NULL THEN RETURN jsonb_build_object('status',reason); END IF;
 SELECT * INTO c FROM esim_private.topup_cache WHERE profile_id=p.id AND owner_id=u AND account_id=q.account_id;
 IF q.expires_at<=now() OR c.expires_at<=now() OR c.status IS DISTINCT FROM 'ready' OR c.version IS DISTINCT FROM q.cache_version
  OR q.context IS DISTINCT FROM esim_private.topup_context(p) OR p.supplier_account_id IS DISTINCT FROM q.account_id THEN RETURN '{"status":"STALE_QUOTE"}'::jsonb; END IF;
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(c.offers) x WHERE x->>'package_id'=q.package_id AND x->>'data_type'='1'
  AND (x->>'wholesale_usd')::numeric=q.wholesale_usd AND (x->>'allowance_bytes')::bigint>0) THEN RETURN '{"status":"INCOMPATIBLE_OFFER"}'::jsonb; END IF;
 total:=public.resolve_esim_offer_price(q.wholesale_usd,u);
 IF total IS DISTINCT FROM q.retail_total THEN RETURN '{"status":"PRICE_CHANGED"}'::jsonb; END IF;
 IF (esim_private.topup_balance(u,total)->>'balance_state')<>'sufficient' THEN RETURN '{"status":"BALANCE_UNAVAILABLE"}'::jsonb; END IF;
 guard:=public.guard_money_action('esim_purchase',total,p_device_id,NULL,u);
 IF coalesce((guard->>'blocked')::boolean,true) THEN RETURN '{"status":"DEVICE_BLOCKED"}'::jsonb; END IF;
 INSERT INTO public.esim_orders(user_id,offer_id,bundle_name,provider,quantity,wholesale_price_usd,retail_price_usd,markup_percent,
  total_amount_usd,status,operation_kind,recharge_profile_id,recharge_quote_id,catalogue_snapshot)
 VALUES(u,q.package_id,q.package_id,'esimaccess',1,q.wholesale_usd,total,round((total/q.wholesale_usd-1)*100,2),total,'pending',
  'fixed_recharge',p.id,q.id,jsonb_build_object('catalogue_details',q.retail_snapshot,'supplier_profile_ref',p.supplier_profile_ref,
  'iccid',p.iccid,'supplier_account_id',p.supplier_account_id,'quote_context',q.context)) RETURNING * INTO o;
 PERFORM esim_private.reserve_order(o.id);
 RETURN jsonb_build_object('status','ACCEPTED','order_id',o.id);
END $$;

CREATE FUNCTION esim_private.settle_order(p_order_id uuid,p_capture boolean) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r esim_private.order_runs; o public.esim_orders; h public.wallet_holds; tx uuid; charged public.wallet_transactions;
 refunded numeric; ref text;
BEGIN
 PERFORM esim_private.require_service();
 SELECT * INTO STRICT o FROM public.esim_orders WHERE id=p_order_id;
 PERFORM 1 FROM public.wallets WHERE user_id=o.user_id FOR UPDATE;
 SELECT * INTO STRICT r FROM esim_private.order_runs WHERE order_id=o.id FOR UPDATE;
 IF r.settlement_state IN('captured','refunded','released') THEN
  IF (p_capture AND r.settlement_state<>'captured') OR (NOT p_capture AND r.settlement_state='captured') THEN RAISE EXCEPTION 'Settlement direction conflict'; END IF;
  RETURN r.settlement_tx_id;
 END IF;
 IF r.receipt IS NULL THEN RAISE EXCEPTION 'Receipt required'; END IF;
 IF r.finance_kind='reserved' THEN
  SELECT * INTO STRICT h FROM public.wallet_holds WHERE id=r.hold_id FOR UPDATE;
  IF h.user_id IS DISTINCT FROM r.payer_id OR h.amount IS DISTINCT FROM o.total_amount_usd OR h.status<>'active'
   OR h.order_reference_id IS DISTINCT FROM 'esim_op:'||o.id::text THEN RAISE EXCEPTION 'Reservation changed'; END IF;
  IF p_capture THEN
   IF r.receipt->>'outcome'<>'success' THEN RAISE EXCEPTION 'Confirmed service required'; END IF;
   UPDATE esim_private.order_runs SET settlement_state='capturing' WHERE order_id=o.id;
   tx:=public.capture_wallet_hold(h.id,CASE WHEN o.operation_kind='fixed_recharge' THEN 'esim_recharge_debit' ELSE 'esim_purchase_debit' END,
    'eSIM operation completed',jsonb_build_object('esim_order_id',o.id,'quote_id',o.recharge_quote_id,'action',o.operation_kind));
   UPDATE esim_private.order_runs SET settlement_state='captured',settlement_tx_id=tx WHERE order_id=o.id;
  ELSE
   IF r.state<>'failed' OR r.receipt->>'outcome'<>'failed' THEN RAISE EXCEPTION 'Definitive failure required'; END IF;
   UPDATE esim_private.order_runs SET settlement_state='releasing' WHERE order_id=o.id;
   PERFORM public.release_wallet_hold(h.id,'Verified eSIM failure or no submission');
   UPDATE esim_private.order_runs SET settlement_state='released' WHERE order_id=o.id;
  END IF;
 ELSIF r.finance_kind='legacy_debit' THEN
  SELECT * INTO STRICT charged FROM public.wallet_transactions WHERE id=r.debit_tx_id AND type='esim_purchase_debit'
   AND status='completed' AND reference_id='esim_'||o.id::text AND user_id=r.payer_id FOR UPDATE;
  IF charged.amount<=0 OR charged.amount::text IN('NaN','Infinity','-Infinity') OR charged.amount IS DISTINCT FROM (charged.balance_before-charged.balance_after) THEN RAISE EXCEPTION 'Unproven legacy charge'; END IF;
  IF charged.wallet_id IS DISTINCT FROM (SELECT id FROM public.wallets WHERE user_id=r.payer_id) THEN RAISE EXCEPTION 'Original wallet changed'; END IF;
  ref:='esim_refund_'||o.id::text;
  IF EXISTS(SELECT 1 FROM public.wallet_transactions WHERE status='completed'
   AND (reference_id=ref OR (metadata->>'esim_order_id'=o.id::text AND type IN('refund','esim_purchase_refund')))
   AND (user_id IS DISTINCT FROM r.payer_id OR wallet_id IS DISTINCT FROM charged.wallet_id OR type NOT IN('refund','esim_purchase_refund')
    OR amount<=0 OR balance_after-balance_before IS DISTINCT FROM amount)) THEN RAISE EXCEPTION 'Unproven prior refund'; END IF;
  SELECT coalesce(sum(amount),0) INTO refunded FROM public.wallet_transactions WHERE status='completed' AND
   (reference_id=ref OR (metadata->>'esim_order_id'=o.id::text AND type IN('refund','esim_purchase_refund')));
  IF p_capture THEN
   IF refunded<>0 THEN RAISE EXCEPTION 'Legacy delivery has prior refund; support required'; END IF;
   tx:=charged.id;
   UPDATE esim_private.order_runs SET settlement_state='captured',settlement_tx_id=tx WHERE order_id=o.id;
  ELSE
   IF r.state<>'failed' OR r.receipt->>'outcome'<>'failed' OR refunded>charged.amount THEN RAISE EXCEPTION 'Unproven legacy refund'; END IF;
   IF EXISTS(SELECT 1 FROM public.user_esims WHERE order_id=o.id) THEN RAISE EXCEPTION 'Partial issuance requires support'; END IF;
   IF refunded<charged.amount THEN
    UPDATE esim_private.order_runs SET settlement_state='refunding' WHERE order_id=o.id;
    tx:=public.credit_wallet_for_refund(r.payer_id,charged.amount-refunded,ref,'Verified legacy eSIM failure',NULL,'esim_purchase_refund');
   END IF;
   UPDATE esim_private.order_runs SET settlement_state='refunded',settlement_tx_id=coalesce(tx,settlement_tx_id) WHERE order_id=o.id;
  END IF;
 ELSE RAISE EXCEPTION 'Legacy financial proof required';
 END IF;
 RETURN tx;
END $$;

CREATE FUNCTION public.service_esim_fail_before_submit(p_order_id uuid,p_lease uuid,p_code text) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r esim_private.order_runs; u uuid;
BEGIN
 PERFORM esim_private.require_service();
 SELECT user_id INTO STRICT u FROM public.esim_orders WHERE id=p_order_id;
 PERFORM 1 FROM public.wallets WHERE user_id=u FOR UPDATE;
 SELECT * INTO STRICT r FROM esim_private.order_runs WHERE order_id=p_order_id FOR UPDATE;
 IF r.state<>'prepared' OR r.submitted_at IS NOT NULL OR p_lease IS NULL OR r.lease IS DISTINCT FROM p_lease OR r.lease_until<now()
  OR r.finance_kind<>'reserved' THEN RETURN false; END IF;
 IF p_code NOT IN('QUOTE_EXPIRED','SUPPLIER_DISABLED','PROFILE_CHANGED','PRICE_CHANGED','CREDENTIALS_UNAVAILABLE','COMPATIBILITY_CHANGED','SUBMISSION_DISABLED','JOURNAL_UNAVAILABLE') THEN RAISE EXCEPTION 'Invalid pre-submission refusal'; END IF;
 UPDATE esim_private.order_runs SET state='failed',receipt=jsonb_build_object('outcome','failed','source','before_submission','code',p_code),
  error_code=p_code,receipt_at=now(),next_check_at=NULL,lease=NULL,lease_until=NULL WHERE order_id=p_order_id;
 PERFORM esim_private.settle_order(p_order_id,false);
 UPDATE public.esim_orders SET status='failed',delivery_state='failed',updated_at=now() WHERE id=p_order_id;
 RETURN true;
END $$;

CREATE FUNCTION public.service_esim_record_topup_receipt(p_order_id uuid,p_submission_ref text,p_receipt jsonb) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE o public.esim_orders; r esim_private.order_runs; p public.user_esims; digest_value text;
BEGIN
 PERFORM esim_private.require_service();
 SELECT * INTO STRICT o FROM public.esim_orders WHERE id=p_order_id;
 PERFORM 1 FROM public.wallets WHERE user_id=o.user_id FOR UPDATE;
 SELECT * INTO STRICT p FROM public.user_esims WHERE id=o.recharge_profile_id FOR UPDATE;
 SELECT * INTO STRICT r FROM esim_private.order_runs WHERE order_id=o.id FOR UPDATE;
 IF o.operation_kind<>'fixed_recharge' OR r.submitted_at IS NULL OR r.submission_ref IS DISTINCT FROM p_submission_ref
  OR p_receipt->>'transaction_id' IS DISTINCT FROM r.submission_ref OR p_receipt->>'iccid' IS DISTINCT FROM o.catalogue_snapshot->>'iccid'
  OR p_receipt->>'supplier_profile_ref' IS DISTINCT FROM o.catalogue_snapshot->>'supplier_profile_ref'
  OR p.user_id IS DISTINCT FROM o.user_id OR p.supplier_account_id IS DISTINCT FROM r.account_id
  OR p.iccid IS DISTINCT FROM p_receipt->>'iccid' OR p.supplier_profile_ref IS DISTINCT FROM p_receipt->>'supplier_profile_ref'
  OR p_receipt->>'package_id' IS DISTINCT FROM o.bundle_name OR p_receipt->>'outcome'<>'success'
  OR nullif(p_receipt->>'topup_ref','') IS NULL OR length(p_receipt->>'topup_ref')>100 OR octet_length(p_receipt::text)>4096
  OR coalesce(p_receipt->>'total_bytes','')!~'^[0-9]{1,16}$' OR coalesce(p_receipt->>'used_bytes','')!~'^[0-9]{1,16}$'
  OR (p_receipt->>'used_bytes')::bigint>(p_receipt->>'total_bytes')::bigint OR (p_receipt->>'expires_at')::timestamptz IS NULL
  OR NOT isfinite((p_receipt->>'expires_at')::timestamptz) THEN RAISE EXCEPTION 'Unproven recharge receipt'; END IF;
 digest_value:=encode(sha256(convert_to(p_receipt::text,'UTF8')),'hex');
 IF r.receipt IS NOT NULL THEN
  IF r.receipt_hash IS DISTINCT FROM digest_value THEN RAISE EXCEPTION 'Conflicting receipt'; END IF;RETURN true;
 END IF;
 IF r.state NOT IN('submitted','reconciling','support_required') THEN RAISE EXCEPTION 'Invalid receipt state'; END IF;
 UPDATE esim_private.order_runs SET receipt=p_receipt,receipt_hash=digest_value,receipt_at=now(),state='reconciling',next_check_at=now(),
  provider_order_ref=p_receipt->>'topup_ref',error_code=NULL WHERE order_id=o.id;
 RETURN true;
END $$;

CREATE FUNCTION public.service_esim_adopt_purchase_reference(p_order_id uuid,p_submission_ref text,p_provider_order_ref text) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r esim_private.order_runs; o public.esim_orders;
BEGIN
 PERFORM esim_private.require_service();
 SELECT * INTO STRICT r FROM esim_private.order_runs WHERE order_id=p_order_id FOR UPDATE;
 SELECT * INTO STRICT o FROM public.esim_orders WHERE id=p_order_id;
 IF o.operation_kind<>'purchase' OR r.submission_ref IS DISTINCT FROM p_submission_ref OR r.submitted_at IS NULL
  OR nullif(p_provider_order_ref,'') IS NULL OR length(p_provider_order_ref)>100 THEN RAISE EXCEPTION 'Unproven purchase reference'; END IF;
 IF r.provider_order_ref IS NOT NULL AND r.provider_order_ref IS DISTINCT FROM p_provider_order_ref THEN RAISE EXCEPTION 'Conflicting purchase reference'; END IF;
 IF r.state='completed' THEN RETURN true; END IF;
 IF r.state NOT IN('submitted','reconciling','support_required') THEN RETURN false; END IF;
 UPDATE esim_private.order_runs SET provider_order_ref=p_provider_order_ref,state='reconciling',next_check_at=now(),
  lease=NULL,lease_until=NULL,error_code=NULL WHERE order_id=p_order_id;
 RETURN true;
END $$;

CREATE FUNCTION public.service_esim_settle_topup(p_order_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE o public.esim_orders; r esim_private.order_runs; p public.user_esims; q esim_private.recharge_quotes; receipt_value jsonb;
BEGIN
 PERFORM esim_private.require_service();
 SELECT * INTO STRICT o FROM public.esim_orders WHERE id=p_order_id;
 PERFORM 1 FROM public.wallets WHERE user_id=o.user_id FOR UPDATE;
 SELECT * INTO STRICT p FROM public.user_esims WHERE id=o.recharge_profile_id FOR UPDATE;
 SELECT * INTO STRICT r FROM esim_private.order_runs WHERE order_id=o.id FOR UPDATE;
 IF r.state='completed' AND r.settlement_state='captured' THEN RETURN '{"completed":true}'::jsonb; END IF;
 receipt_value:=r.receipt;
 IF o.operation_kind<>'fixed_recharge' OR receipt_value IS NULL OR receipt_value->>'outcome'<>'success'
  OR p.user_id IS DISTINCT FROM o.user_id OR p.iccid IS DISTINCT FROM receipt_value->>'iccid'
  OR p.supplier_profile_ref IS DISTINCT FROM receipt_value->>'supplier_profile_ref' THEN RAISE EXCEPTION 'Settlement binding changed'; END IF;
 SELECT * INTO STRICT q FROM esim_private.recharge_quotes WHERE id=o.recharge_quote_id;
 PERFORM esim_private.settle_order(o.id,true);
 INSERT INTO esim_private.entitlements(order_id,profile_id,account_id,supplier_topup_ref,package_id,allowance_bytes,duration_value,duration_unit,retail_total,currency,provider_expires_at,expiry_confirmed)
 VALUES(o.id,p.id,r.account_id,receipt_value->>'topup_ref',o.bundle_name,(q.retail_snapshot->>'allowance_bytes')::bigint,
 q.duration_value,q.duration_unit,o.total_amount_usd,'USD',(receipt_value->>'expires_at')::timestamptz,p.bundle_state IN('active','depleted'));
 UPDATE public.user_esims SET data_total_bytes=(receipt_value->>'total_bytes')::bigint,data_used_bytes=(receipt_value->>'used_bytes')::bigint,
  data_remaining_bytes=(receipt_value->>'total_bytes')::bigint-(receipt_value->>'used_bytes')::bigint,
  data_total_mb=floor((receipt_value->>'total_bytes')::numeric/1048576),
  data_remaining_mb=floor(((receipt_value->>'total_bytes')::numeric-(receipt_value->>'used_bytes')::numeric)/1048576),
  confirmed_expires_at=CASE WHEN bundle_state IN('active','depleted') THEN (receipt_value->>'expires_at')::timestamptz ELSE confirmed_expires_at END,
  expires_at=CASE WHEN bundle_state IN('active','depleted') THEN (receipt_value->>'expires_at')::timestamptz ELSE expires_at END,
  bundle_state=CASE WHEN bundle_state='depleted' THEN 'active' ELSE bundle_state END,last_observation_at=clock_timestamp(),
  last_usage_check=clock_timestamp(),usage_observed_at=NULL,usage_error_code=NULL WHERE id=p.id;
 PERFORM esim_private.open_alert_cycle(p.id,'recharge:'||o.id::text);
 DELETE FROM esim_private.topup_cache WHERE profile_id=p.id;
 UPDATE esim_private.profile_work SET next_check_at=now() WHERE profile_id=p.id;
 UPDATE esim_private.order_runs SET state='completed',lease=NULL,lease_until=NULL,next_check_at=NULL,error_code=NULL,updated_at=now() WHERE order_id=o.id;
 UPDATE public.esim_orders SET status='completed',delivery_state='completed',provider_order_ref=receipt_value->>'topup_ref',updated_at=now() WHERE id=o.id;
 RETURN '{"completed":true}'::jsonb;
END $$;

CREATE FUNCTION public.service_esim_record_rejection(p_order_id uuid,p_lease uuid,p_submission_ref text,p_code text) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r esim_private.order_runs; u uuid;
BEGIN
 PERFORM esim_private.require_service();
 SELECT user_id INTO STRICT u FROM public.esim_orders WHERE id=p_order_id;
 PERFORM 1 FROM public.wallets WHERE user_id=u FOR UPDATE;
 SELECT * INTO STRICT r FROM esim_private.order_runs WHERE order_id=p_order_id FOR UPDATE;
 IF r.state='failed' AND r.settlement_state IN('released','refunded') THEN RETURN true; END IF;
 IF p_lease IS NULL OR r.lease IS DISTINCT FROM p_lease OR r.lease_until<now() OR r.state<>'submitted'
  OR r.submission_ref IS DISTINCT FROM p_submission_ref OR p_code NOT IN('200005','200006','200007','200008','310241','310243') THEN RETURN false; END IF;
 UPDATE esim_private.order_runs SET state='failed',receipt=jsonb_build_object('outcome','failed','source','inline_validation_rejection',
  'transaction_id',p_submission_ref,'code',p_code),receipt_at=now(),next_check_at=NULL,error_code='PROVIDER_REJECTED' WHERE order_id=p_order_id;
 PERFORM esim_private.settle_order(p_order_id,false);
 UPDATE esim_private.order_runs SET lease=NULL,lease_until=NULL WHERE order_id=p_order_id;
 UPDATE public.esim_orders SET status='failed',delivery_state='failed',updated_at=now() WHERE id=p_order_id;
 RETURN true;
END $$;

CREATE FUNCTION public.get_esim_operation_history(p_profile_id uuid DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); result jsonb;
BEGIN
 PERFORM esim_private.require_live_owner(u);
 IF p_profile_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.user_esims WHERE id=p_profile_id AND user_id=u) THEN RETURN '[]'::jsonb; END IF;
 SELECT coalesce(jsonb_agg(value ORDER BY created_at DESC),'[]') INTO result FROM(
  SELECT o.created_at,jsonb_build_object('id',o.id,'profile_id',o.recharge_profile_id,'kind',o.operation_kind,'package_id',o.bundle_name,
   'retail_total',o.total_amount_usd,'currency','USD','status',o.status,'delivery_state',o.delivery_state,'created_at',o.created_at,
   'financial_state',coalesce(r.settlement_state,'support_required'),'funds_reserved',r.finance_kind='reserved' AND r.settlement_state='pending',
   'confirmed_expiry',CASE WHEN e.expiry_confirmed THEN e.provider_expires_at END,'duration_value',e.duration_value,'duration_unit',e.duration_unit,
   'support_required',o.delivery_state='support_required') value
  FROM public.esim_orders o LEFT JOIN esim_private.order_runs r ON r.order_id=o.id
  LEFT JOIN esim_private.entitlements e ON e.order_id=o.id WHERE o.user_id=u
   AND (p_profile_id IS NULL OR o.recharge_profile_id=p_profile_id OR o.id=(SELECT order_id FROM public.user_esims WHERE id=p_profile_id AND user_id=u))
  ORDER BY o.created_at DESC LIMIT 50) rows;
 RETURN result;
END $$;

CREATE FUNCTION public.admin_esim_operation_timeline(p_order_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
 PERFORM public.assert_admin();
 SELECT jsonb_build_object('order_id',o.id,'kind',o.operation_kind,'status',o.status,'delivery_state',o.delivery_state,
 'finance_kind',r.finance_kind,'settlement_state',r.settlement_state,'submitted_at',r.submitted_at,'receipt_at',r.receipt_at,
 'error_code',r.error_code,'attempts',r.attempts,'next_check_at',r.next_check_at,'has_hold',r.hold_id IS NOT NULL,
 'has_original_debit',r.debit_tx_id IS NOT NULL,'has_settlement',r.settlement_tx_id IS NOT NULL,'receipt_hash',r.receipt_hash,
 'events',(SELECT coalesce(jsonb_agg(jsonb_build_object('received_at',received_at,'status',status,'kind',kind)),'[]') FROM esim_private.events
  WHERE account_id=r.account_id AND (submission_ref=r.submission_ref OR order_ref=r.provider_order_ref))) INTO result
 FROM public.esim_orders o JOIN esim_private.order_runs r ON r.order_id=o.id WHERE o.id=p_order_id;
 RETURN result;
END $$;
