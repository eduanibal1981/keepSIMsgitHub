BEGIN;

-- The marker must commit before calling the supplier. A timeout after this RPC
-- retains the reservation, even if the worker never receives the RPC response.
CREATE FUNCTION public.begin_refill_submission(p_execution_id uuid,p_hold_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE e public.topup_executions; h public.wallet_holds;
BEGIN
  SELECT * INTO e FROM public.topup_executions WHERE id=p_execution_id FOR UPDATE;
  IF NOT FOUND OR e.status NOT IN ('processing','routing') OR e.carrier_in_flight
    OR e.reloadly_transaction_id IS NOT NULL THEN RAISE EXCEPTION 'Execution requires reconciliation'; END IF;
  PERFORM 1 FROM public.wallets WHERE user_id=e.user_id FOR UPDATE;
  SELECT * INTO h FROM public.wallet_holds WHERE id=p_hold_id FOR UPDATE;
  IF h.id IS NULL OR h.user_id IS DISTINCT FROM e.user_id OR h.amount IS DISTINCT FROM e.amount
    OR h.status<>'active' OR h.carrier_in_flight OR h.recovery_contract_version<1 OR
    (e.wallet_hold_id IS NOT NULL AND e.wallet_hold_id<>h.id) THEN
    RAISE EXCEPTION 'Matching active wallet reservation required';
  END IF;
  UPDATE public.wallet_holds SET carrier_in_flight=true,updated_at=now() WHERE id=h.id;
  UPDATE public.topup_executions SET carrier_in_flight=true,wallet_hold_id=h.id,updated_at=now() WHERE id=e.id;
END;
$$;
REVOKE ALL ON FUNCTION public.begin_refill_submission(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.begin_refill_submission(uuid,uuid) TO service_role;

CREATE FUNCTION public.settle_instant_refill_execution(p_execution_id uuid,p_provider_tx_id text,p_hold_id uuid,
  p_pin_code text DEFAULT NULL,p_pin_serial text DEFAULT NULL,p_redeem_instructions text DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE e public.topup_executions; h public.wallet_holds; v_result jsonb;
BEGIN
  IF nullif(btrim(p_provider_tx_id),'') IS NULL THEN RAISE EXCEPTION 'Confirmed provider identity required'; END IF;
  SELECT * INTO e FROM public.topup_executions WHERE id=p_execution_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Execution unavailable'; END IF;
  PERFORM 1 FROM public.wallets WHERE user_id=e.user_id FOR UPDATE;
  SELECT * INTO h FROM public.wallet_holds WHERE id=p_hold_id FOR UPDATE;
  IF h.id IS NULL OR h.user_id IS DISTINCT FROM e.user_id OR h.amount IS DISTINCT FROM e.amount
    OR h.status NOT IN ('active','captured') OR e.wallet_hold_id IS DISTINCT FROM h.id THEN
    RAISE EXCEPTION 'Matching funded execution required';
  END IF;
  v_result:=public.settle_successful_execution(p_execution_id,p_provider_tx_id,p_hold_id,
    p_pin_code,p_pin_serial,p_redeem_instructions,p_metadata);
  UPDATE public.wallet_holds SET carrier_in_flight=false,updated_at=now() WHERE id=h.id;
  UPDATE public.topup_executions SET carrier_in_flight=false,updated_at=now() WHERE id=e.id;
  RETURN v_result;
END;
$$;
REVOKE ALL ON FUNCTION public.settle_instant_refill_execution(uuid,text,uuid,text,text,text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.settle_instant_refill_execution(uuid,text,uuid,text,text,text,jsonb) TO service_role;
COMMIT;
