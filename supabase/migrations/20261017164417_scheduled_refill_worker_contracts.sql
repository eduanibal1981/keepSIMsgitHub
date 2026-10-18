-- Task 10. Apply only after the coordinated wallet and Task 9 migrations.
BEGIN;

ALTER TABLE public.topup_executions ADD COLUMN scheduled_refill_submission jsonb;

CREATE FUNCTION public.scheduled_refill_route(p_execution public.topup_executions)
RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $$
  SELECT jsonb_build_object('provider',p_execution.api_provider,'offerId',p_execution.offer_id,
    'offerValue',p_execution.offer_value,'costUsd',p_execution.base_cost_usd,
    'feeUsd',p_execution.app_fee_usd,'totalChargeUsd',p_execution.amount,
    'targetLocalValue',p_execution.target_local_value,'targetLocalCurrency',p_execution.target_local_currency);
$$;

-- The caller locks the execution first. Wallet -> hold lock order agrees with
-- reserve/capture/release. Reject foreign or stale links; never repair them by
-- releasing someone else's reservation or accepting an unproven prepaid row.
CREATE FUNCTION public.assert_scheduled_refill_reservation(p_execution_id uuid,p_hold_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE e public.topup_executions; h public.wallet_holds;
BEGIN
  SELECT * INTO e FROM public.topup_executions WHERE id=p_execution_id;
  PERFORM 1 FROM public.wallets WHERE user_id=e.user_id FOR UPDATE;
  SELECT * INTO h FROM public.wallet_holds WHERE id=p_hold_id FOR UPDATE;
  IF e.id IS NULL OR h.id IS NULL OR e.execution_type NOT IN ('refill_mini','refill_custom')
    OR e.execution_type IS NULL OR e.wallet_hold_id IS DISTINCT FROM h.id
    OR coalesce(e.payment_gateway_code,'wallet')<>'wallet' OR e.funding_kind IS DISTINCT FROM 'wallet_due'
    OR h.user_id IS DISTINCT FROM e.user_id OR h.amount IS DISTINCT FROM e.amount
    OR e.amount IS NULL OR e.amount<=0 OR e.amount::text IN ('NaN','Infinity','-Infinity')
    OR e.amount<>round(e.amount,2) OR e.currency IS DISTINCT FROM 'USD'
    OR h.currency IS DISTINCT FROM e.currency OR h.order_type<>'refill_scheduled'
    OR (h.order_reference_id IS DISTINCT FROM 'exec_'||e.id::text
      AND h.order_reference_id !~ ('^exec_'||e.id::text||':[0-9a-f-]{36}$'))
    OR h.status NOT IN ('active','captured') OR h.recovery_contract_version<1
    OR NOT EXISTS(SELECT 1 FROM public.wallets WHERE id=h.wallet_id AND user_id=e.user_id AND currency=e.currency)
    OR NOT EXISTS(SELECT 1 FROM public.sim_lines WHERE id=e.sim_line_id AND user_id=e.user_id)
    OR EXISTS(SELECT 1 FROM public.topup_executions WHERE wallet_hold_id=h.id AND id<>e.id)
  THEN RAISE EXCEPTION 'Matching scheduled wallet reservation required'; END IF;
  IF h.status='active' THEN PERFORM public.assert_wallet_funding_integrity(h.wallet_id); END IF;
END;
$$;

-- The worker supplies a freshly resolved supplier route. The canonical fee
-- function must agree with it; the database never silently rounds away a quote
-- disagreement or raises the customer's authorization ceiling.
CREATE FUNCTION public.prepare_scheduled_refill(p_execution_id uuid,p_route jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE e public.topup_executions; h uuid; ref text; v_amount numeric; v_fee numeric; v_cost numeric;
BEGIN
  IF auth.jwt()->>'role' IS DISTINCT FROM 'service_role'
    AND current_setting('role',true) NOT IN ('none','postgres','supabase_admin') THEN
    RAISE EXCEPTION 'Service role required' USING ERRCODE='42501'; END IF;
  SELECT * INTO e FROM public.topup_executions WHERE id=p_execution_id FOR UPDATE;
  IF NOT FOUND OR e.execution_type NOT IN ('refill_mini','refill_custom') OR e.execution_type IS NULL
    OR e.status NOT IN ('processing','routing') OR e.carrier_in_flight
    OR e.reloadly_transaction_id IS NOT NULL OR e.scheduled_refill_submission IS NOT NULL
  THEN RAISE EXCEPTION 'Execution requires reconciliation'; END IF;
  IF coalesce(e.payment_gateway_code,'wallet')<>'wallet' OR e.funding_kind IS DISTINCT FROM 'wallet_due'
    OR e.currency IS DISTINCT FROM 'USD' OR coalesce(e.fulfillment_gateway,'API')<>'API' OR e.refill_channel IS NOT NULL
    OR NOT EXISTS(SELECT 1 FROM public.sim_lines WHERE id=e.sim_line_id AND user_id=e.user_id)
  THEN RAISE EXCEPTION 'Scheduled wallet funding required'; END IF;
  v_amount:=(p_route->>'totalChargeUsd')::numeric;
  v_cost:=(p_route->>'costUsd')::numeric;
  IF v_amount IS NULL OR v_amount<=0 OR v_amount::text IN ('NaN','Infinity','-Infinity') OR v_amount<>round(v_amount,2)
    OR v_amount>coalesce(e.max_authorized_usd,e.amount,0)
    OR coalesce(e.max_authorized_usd,e.amount,0)::text IN ('NaN','Infinity','-Infinity')
    OR v_cost IS NULL OR v_cost<=0 OR v_cost::text IN ('NaN','Infinity','-Infinity')
    OR (p_route->>'feeUsd')::numeric IS NULL OR (p_route->>'feeUsd')::numeric<0
    OR nullif(p_route->>'offerId','') IS NULL
    OR coalesce(p_route->>'provider','') NOT IN ('zendit','dtone','ding','reloadly')
  THEN RAISE EXCEPTION 'Invalid or unauthorized scheduled price'; END IF;
  -- The production fee trigger runs on INSERT only. Calling its underlying
  -- canonical policy here is essential when repricing an existing execution.
  v_fee:=coalesce(public.resolve_app_fee('refills',public.resolve_line_entitlement(e.sim_line_id)->>'effective_tier',v_cost),
    round(greatest(v_cost*0.03,0.03),2));
  IF v_amount IS DISTINCT FROM round(v_cost+v_fee,2) OR v_fee IS DISTINCT FROM (p_route->>'feeUsd')::numeric THEN
    RAISE EXCEPTION 'Scheduled price differs from database contract'; END IF;
  UPDATE public.topup_executions SET amount=v_amount,base_cost_usd=v_cost,
    app_fee_usd=v_fee,payment_gateway_code='wallet',
    api_provider=p_route->>'provider',offer_id=p_route->>'offerId',offer_value=(p_route->>'offerValue')::bigint,
    target_local_value=(p_route->>'targetLocalValue')::numeric,target_local_currency=p_route->>'targetLocalCurrency',
    updated_at=now() WHERE id=e.id RETURNING * INTO e;
  IF public.scheduled_refill_route(e) IS DISTINCT FROM p_route THEN
    RAISE EXCEPTION 'Scheduled price or route differs from database contract'; END IF;
  h:=e.wallet_hold_id;
  IF h IS NULL THEN
    ref:='exec_'||e.id::text;
    -- A safely stopped pre-submission attempt may have released the old hold.
    -- Serialize a new reservation identity under the same execution lock.
    IF EXISTS(SELECT 1 FROM public.wallet_holds WHERE order_type='refill_scheduled' AND order_reference_id=ref) THEN
      ref:=ref||':'||gen_random_uuid()::text; END IF;
    h:=public.reserve_wallet_funds(e.user_id,e.amount,'refill_scheduled',ref,'Scheduled refill',240);
    UPDATE public.topup_executions SET wallet_hold_id=h WHERE id=e.id;
  END IF;
  PERFORM public.assert_scheduled_refill_reservation(e.id,h);
  IF NOT EXISTS(SELECT 1 FROM public.wallet_holds WHERE id=h AND status='active'
    AND NOT carrier_in_flight AND expires_at>now()) THEN
    RAISE EXCEPTION 'Active unexpired scheduled reservation required'; END IF;
  RETURN jsonb_build_object('hold_id',h,'route',public.scheduled_refill_route(e));
END;
$$;

CREATE FUNCTION public.begin_scheduled_refill_submission(p_execution_id uuid,p_hold_id uuid,p_route jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE e public.topup_executions;
BEGIN
  IF auth.jwt()->>'role' IS DISTINCT FROM 'service_role'
    AND current_setting('role',true) NOT IN ('none','postgres','supabase_admin') THEN
    RAISE EXCEPTION 'Service role required' USING ERRCODE='42501'; END IF;
  SELECT * INTO e FROM public.topup_executions WHERE id=p_execution_id FOR UPDATE;
  IF NOT FOUND OR e.status NOT IN ('processing','routing') OR e.carrier_in_flight
    OR e.reloadly_transaction_id IS NOT NULL OR e.scheduled_refill_submission IS NOT NULL
    OR public.scheduled_refill_route(e) IS DISTINCT FROM p_route THEN
    RAISE EXCEPTION 'Execution requires reconciliation'; END IF;
  PERFORM public.assert_scheduled_refill_reservation(e.id,p_hold_id);
  IF NOT EXISTS(SELECT 1 FROM public.wallet_holds WHERE id=p_hold_id AND status='active'
    AND NOT carrier_in_flight AND expires_at>now()) THEN
    RAISE EXCEPTION 'Active unexpired scheduled reservation required'; END IF;
  UPDATE public.wallet_holds SET carrier_in_flight=true,updated_at=now() WHERE id=p_hold_id;
  UPDATE public.topup_executions SET carrier_in_flight=true,updated_at=now(),
    scheduled_refill_submission=jsonb_build_object('route',p_route,'user_id',e.user_id,
      'sim_line_id',e.sim_line_id,'hold_id',p_hold_id,'currency',e.currency)
    WHERE id=e.id;
END;
$$;

CREATE OR REPLACE FUNCTION public.settle_successful_execution(p_execution_id uuid,p_provider_tx_id text,
  p_hold_id uuid DEFAULT NULL,p_pin_code text DEFAULT NULL,p_pin_serial text DEFAULT NULL,
  p_redeem_instructions text DEFAULT NULL,p_metadata jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE e public.topup_executions; h public.wallet_holds; tx uuid;
BEGIN
  IF auth.jwt()->>'role' IS DISTINCT FROM 'service_role'
    AND current_setting('role',true) NOT IN ('none','postgres','supabase_admin') THEN
    RAISE EXCEPTION 'Service role required' USING ERRCODE='42501'; END IF;
  IF nullif(btrim(p_provider_tx_id),'') IS NULL THEN RAISE EXCEPTION 'Confirmed provider identity required'; END IF;
  SELECT * INTO e FROM public.topup_executions WHERE id=p_execution_id FOR UPDATE;
  -- Preserve the documented omitted-hold call shape, but always validate the
  -- stored link. No external-payment or missing-hold success is implied.
  p_hold_id:=coalesce(p_hold_id,e.wallet_hold_id);
  PERFORM public.assert_scheduled_refill_reservation(p_execution_id,p_hold_id);
  SELECT * INTO h FROM public.wallet_holds WHERE id=p_hold_id;
  IF e.scheduled_refill_submission IS DISTINCT FROM jsonb_build_object('route',public.scheduled_refill_route(e),
    'user_id',e.user_id,'sim_line_id',e.sim_line_id,'hold_id',h.id,'currency',e.currency) THEN
    RAISE EXCEPTION 'Persisted scheduled submission binding required'; END IF;
  IF e.status='success' THEN
    IF h.status<>'captured' OR e.reloadly_transaction_id IS DISTINCT FROM p_provider_tx_id
      OR (p_pin_code IS NOT NULL AND p_pin_code IS DISTINCT FROM e.pin_code)
      OR (p_pin_serial IS NOT NULL AND p_pin_serial IS DISTINCT FROM e.pin_serial)
      OR (p_redeem_instructions IS NOT NULL AND p_redeem_instructions IS DISTINCT FROM e.redeem_instructions) THEN
      RAISE EXCEPTION 'Settlement identity mismatch'; END IF;
  ELSIF NOT coalesce(e.carrier_in_flight,false) OR NOT h.carrier_in_flight OR h.status<>'active'
    OR (e.reloadly_transaction_id IS NOT NULL AND e.reloadly_transaction_id<>p_provider_tx_id) THEN
    RAISE EXCEPTION 'Persisted supplier submission required'; END IF;
  tx:=public.capture_wallet_hold(h.id,'topup_debit','Scheduled SIM refill',
    coalesce(p_metadata,'{}'::jsonb)||jsonb_build_object('execution_id',e.id,'sim_line_id',e.sim_line_id,
      'provider_tx_id',p_provider_tx_id,'provider',e.api_provider));
  IF NOT EXISTS(SELECT 1 FROM public.wallet_transactions WHERE id=tx AND wallet_id=h.wallet_id
    AND user_id=e.user_id AND amount=e.amount AND type='topup_debit' AND status='completed'
    AND metadata->>'execution_id'=e.id::text AND metadata->>'provider_tx_id'=p_provider_tx_id) THEN
    RAISE EXCEPTION 'Settlement receipt mismatch'; END IF;
  UPDATE public.wallet_holds SET carrier_in_flight=false,updated_at=now() WHERE id=h.id;
  UPDATE public.topup_executions SET status='success',reloadly_transaction_id=p_provider_tx_id,
    pin_code=coalesce(p_pin_code,pin_code),pin_serial=coalesce(p_pin_serial,pin_serial),
    redeem_instructions=coalesce(p_redeem_instructions,redeem_instructions),carrier_in_flight=false,
    failure_reason=NULL,executed_at=coalesce(executed_at,now()),completed_at=coalesce(completed_at,now()),updated_at=now()
    WHERE id=e.id;
  RETURN jsonb_build_object('success',true,'idempotent',e.status='success','execution_id',e.id,
    'provider_tx_id',p_provider_tx_id,'hold_id',h.id,'wallet_txn_id',tx);
END;
$$;

CREATE FUNCTION public.stop_scheduled_refill_before_submission(p_execution_id uuid,p_reason text,p_status text DEFAULT 'failed')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE e public.topup_executions; h public.wallet_holds;
BEGIN
  IF auth.jwt()->>'role' IS DISTINCT FROM 'service_role'
    AND current_setting('role',true) NOT IN ('none','postgres','supabase_admin') THEN
    RAISE EXCEPTION 'Service role required' USING ERRCODE='42501'; END IF;
  IF p_status IS NULL OR p_status NOT IN ('failed','awaiting_funds','awaiting_approval') THEN
    RAISE EXCEPTION 'Invalid pre-submission state'; END IF;
  SELECT * INTO e FROM public.topup_executions WHERE id=p_execution_id FOR UPDATE;
  IF NOT FOUND OR e.execution_type NOT IN ('refill_mini','refill_custom') OR e.execution_type IS NULL THEN
    RAISE EXCEPTION 'Scheduled execution required'; END IF;
  IF e.status NOT IN ('processing','routing') OR e.carrier_in_flight
    OR e.reloadly_transaction_id IS NOT NULL OR e.scheduled_refill_submission IS NOT NULL THEN
    RETURN jsonb_build_object('success',false,'reconciliation_required',true); END IF;
  IF e.wallet_hold_id IS NOT NULL THEN
    PERFORM public.assert_scheduled_refill_reservation(e.id,e.wallet_hold_id);
    SELECT * INTO h FROM public.wallet_holds WHERE id=e.wallet_hold_id;
    IF h.status<>'active' OR h.carrier_in_flight THEN
      RETURN jsonb_build_object('success',false,'reconciliation_required',true); END IF;
    PERFORM public.release_wallet_hold(h.id,'Scheduled refill stopped before submission');
  END IF;
  UPDATE public.topup_executions SET status=p_status,failure_reason=left(p_reason,500),
    wallet_hold_id=NULL,processing_since=NULL,updated_at=now() WHERE id=e.id;
  RETURN jsonb_build_object('success',true);
END;
$$;

-- Neither current client, Edge handler nor authoritative worker calls these.
-- The VM's legacy instant worker DOES: stop/replace it with Task 9's worker
-- during the coordinated release before retiring either API. Unexpected
-- catalog dependencies stop the release; never CASCADE away consumers.
DROP FUNCTION IF EXISTS public.update_execution_status(uuid,text,text) RESTRICT;
DROP FUNCTION IF EXISTS public.update_execution_status(uuid,text,text,text,text,text) RESTRICT;

REVOKE ALL ON FUNCTION public.scheduled_refill_route(public.topup_executions),
  public.assert_scheduled_refill_reservation(uuid,uuid),public.prepare_scheduled_refill(uuid,jsonb),
  public.begin_scheduled_refill_submission(uuid,uuid,jsonb),
  public.settle_successful_execution(uuid,text,uuid,text,text,text,jsonb),
  public.stop_scheduled_refill_before_submission(uuid,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.scheduled_refill_route(public.topup_executions),
  public.assert_scheduled_refill_reservation(uuid,uuid),public.prepare_scheduled_refill(uuid,jsonb),
  public.begin_scheduled_refill_submission(uuid,uuid,jsonb),
  public.settle_successful_execution(uuid,text,uuid,text,text,text,jsonb),
  public.stop_scheduled_refill_before_submission(uuid,text,text) TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;
