-- Task 13. Local only; deploy with make-call and telnyx-cdr after wallet Task 7
-- and callback authentication Task 4. Existing calls remain version 0.
BEGIN;
ALTER TABLE public.call_records
  ADD COLUMN budget_contract_version smallint NOT NULL DEFAULT 0 CHECK (budget_contract_version IN (0,1)),
  ADD COLUMN connection_fee_usd numeric NOT NULL DEFAULT 0,
  ADD COLUMN reserved_budget_usd numeric,
  ADD COLUMN wallet_hold_id uuid REFERENCES public.wallet_holds(id),
  ADD COLUMN max_duration_seconds integer,
  ADD COLUMN billing_state text NOT NULL DEFAULT 'legacy' CHECK (billing_state IN
    ('legacy','reserved','submitting','active','termination_pending','reconciliation_required','settled')),
  ADD COLUMN reconciliation_reason text,
  ADD COLUMN app_submission_at timestamptz,
  ADD COLUMN destination_submission_at timestamptz,
  ADD COLUMN destination_answered_at timestamptz,
  ADD COLUMN destination_ended_at timestamptz,
  ADD COLUMN destination_terminal_status text,
  ADD COLUMN destination_terminal_payload jsonb,
  ADD COLUMN observed_cost_usd numeric;
ALTER TABLE public.call_records ADD CONSTRAINT call_budget_snapshot_check CHECK (
  budget_contract_version=0 OR (
    wallet_hold_id IS NOT NULL AND reserved_budget_usd IS NOT NULL AND max_duration_seconds IS NOT NULL
    AND billing_increment_seconds IS NOT NULL AND reserved_budget_usd>0 AND reserved_budget_usd=round(reserved_budget_usd,2)
    AND max_duration_seconds BETWEEN 30 AND 300 AND rate_per_minute_usd>0
    AND billing_increment_seconds>0 AND connection_fee_usd>=0
    AND rate_per_minute_usd::text NOT IN ('NaN','Infinity','-Infinity')
    AND connection_fee_usd::text NOT IN ('NaN','Infinity','-Infinity')
    AND reserved_budget_usd::text NOT IN ('NaN','Infinity','-Infinity')));
CREATE UNIQUE INDEX call_budget_hold_unique ON public.call_records(wallet_hold_id) WHERE wallet_hold_id IS NOT NULL;
-- Do not impose uniqueness on unreconciled legacy keys; wallet locking serializes
-- the service creation API and this index protects all new contracts.
CREATE UNIQUE INDEX call_budget_key_unique ON public.call_records(user_id,idempotency_key)
  WHERE budget_contract_version=1;

-- One exact-decimal formula for accepting duration and settling it. Unanswered
-- calls (zero seconds) have no connection fee; a bridge is at least one second.
CREATE FUNCTION public.media_call_cost(p_rate numeric,p_fee numeric,p_increment integer,p_seconds integer)
RETURNS numeric LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path='' AS $$
BEGIN
  IF p_rate IS NULL OR p_rate<=0 OR p_rate::text IN ('NaN','Infinity','-Infinity')
    OR p_fee IS NULL OR p_fee<0 OR p_fee::text IN ('NaN','Infinity','-Infinity')
    OR p_increment IS NULL OR p_increment NOT BETWEEN 1 AND 300 OR p_seconds IS NULL OR p_seconds<0
  THEN RAISE EXCEPTION 'Invalid call pricing inputs'; END IF;
  IF p_seconds=0 THEN RETURN 0; END IF;
  RETURN round(p_fee+ceil(p_seconds::numeric/p_increment)*p_increment*p_rate/60,2);
END $$;

CREATE FUNCTION public.assert_media_call_reservation(p_call_id uuid,p_for_submission boolean DEFAULT false)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.call_records; h public.wallet_holds;
BEGIN
  IF current_setting('role',true) IS DISTINCT FROM 'service_role' THEN RAISE EXCEPTION 'Trusted call service required' USING ERRCODE='42501'; END IF;
  SELECT * INTO r FROM public.call_records WHERE id=p_call_id;
  PERFORM 1 FROM public.wallets WHERE user_id=r.user_id FOR UPDATE;
  SELECT * INTO h FROM public.wallet_holds WHERE id=r.wallet_hold_id FOR UPDATE;
  IF r.id IS NULL OR r.budget_contract_version<>1 OR h.id IS NULL
    OR h.user_id IS DISTINCT FROM r.user_id OR h.order_type<>'call_budget'
    OR h.order_reference_id IS DISTINCT FROM r.id::text OR h.currency<>'USD'
    OR h.amount IS DISTINCT FROM r.reserved_budget_usd OR h.status<>'active'
    OR h.recovery_contract_version<1
    OR NOT EXISTS(SELECT 1 FROM public.wallets WHERE id=h.wallet_id AND user_id=r.user_id AND currency='USD')
    OR (p_for_submission AND h.expires_at<=now())
  THEN RAISE EXCEPTION 'Matching active call reservation required'; END IF;
  PERFORM public.assert_wallet_funding_integrity(h.wallet_id);
END $$;

CREATE FUNCTION public.prepare_budgeted_media_call(p_user_id uuid,p_request jsonb,p_media_session_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.call_records; tariff record; w public.wallets; hold_id uuid;
  available numeric; budget numeric; duration_limit integer; key text:=p_request->>'idempotency_key';
BEGIN
  IF current_setting('role',true) IS DISTINCT FROM 'service_role' THEN RAISE EXCEPTION 'Trusted call service required' USING ERRCODE='42501'; END IF;
  IF nullif(btrim(key),'') IS NULL OR length(key)>200 OR coalesce(p_request->>'destination_number','') !~ '^\+[0-9]{7,15}$'
  THEN RAISE EXCEPTION 'Valid call destination and idempotency key required'; END IF;
  SELECT * INTO w FROM public.wallets WHERE user_id=p_user_id FOR UPDATE;
  IF NOT FOUND OR w.currency<>'USD' THEN RAISE EXCEPTION 'USD wallet required'; END IF;
  SELECT * INTO r FROM public.call_records WHERE user_id=p_user_id AND idempotency_key=key ORDER BY created_at LIMIT 1;
  IF FOUND THEN
    IF r.destination_number IS DISTINCT FROM p_request->>'destination_number'
      OR r.effective_caller_id IS DISTINCT FROM p_request->>'effective_caller_id'
      OR r.sim_line_id IS DISTINCT FROM nullif(p_request->>'sim_line_id','')::uuid
    THEN RAISE EXCEPTION 'Call idempotency terms mismatch'; END IF;
    RETURN jsonb_build_object('call',to_jsonb(r),'created',false,'posted_balance',w.balance,
      'available_balance',w.balance-coalesce((SELECT sum(amount) FROM public.wallet_holds WHERE wallet_id=w.id AND status='active'),0));
  END IF;
  IF nullif(p_request->>'sim_line_id','') IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.sim_lines
    WHERE id=(p_request->>'sim_line_id')::uuid AND user_id=p_user_id) THEN RAISE EXCEPTION 'Owned SIM line required'; END IF;
  SELECT * INTO tariff FROM public.get_call_rate_for_number(p_request->>'destination_number',p_user_id);
  IF tariff.id IS NULL OR tariff.rate_per_minute_usd IS NULL OR tariff.rate_per_minute_usd<=0
    OR tariff.rate_per_minute_usd::text IN ('NaN','Infinity','-Infinity')
    OR tariff.connection_fee_usd IS NULL OR tariff.connection_fee_usd<0
    OR tariff.connection_fee_usd::text IN ('NaN','Infinity','-Infinity')
    OR tariff.billing_increment_seconds IS NULL OR tariff.billing_increment_seconds NOT BETWEEN 1 AND 300
  THEN RAISE EXCEPTION 'Valid call tariff required'; END IF;
  PERFORM public.assert_wallet_funding_integrity(w.id);
  available:=w.balance-coalesce((SELECT sum(amount) FROM public.wallet_holds WHERE wallet_id=w.id AND status='active'),0);
  -- USD ledger and funding lots use cents. Round once after applying fee/increment.
  budget:=least(available,greatest(0.01,public.media_call_cost(tariff.rate_per_minute_usd,tariff.connection_fee_usd,tariff.billing_increment_seconds,300)));
  SELECT max(s) INTO duration_limit FROM generate_series(30,300) s WHERE
    public.media_call_cost(tariff.rate_per_minute_usd,tariff.connection_fee_usd,tariff.billing_increment_seconds,s)<=budget;
  IF budget<=0 OR duration_limit IS NULL THEN RAISE EXCEPTION 'Insufficient available call funds'; END IF;
  -- Claim the owned audio session in the same transaction as the call and hold.
  PERFORM 1 FROM public.call_media_sessions WHERE id=p_media_session_id AND user_id=p_user_id
    AND call_record_id IS NULL AND expires_at>now() AND NOT cleaned_up FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Call audio session expired or already used'; END IF;
  INSERT INTO public.call_records(user_id,sim_line_id,call_type,caller_number,requested_caller_id,effective_caller_id,
    caller_id_type,policy_reason,policy_version,destination_number,destination_country_code,destination_country_name,
    rate_per_minute_usd,billing_increment_seconds,connection_fee_usd,idempotency_key)
  VALUES(p_user_id,nullif(p_request->>'sim_line_id','')::uuid,'app_to_phone_webrtc',p_request->>'effective_caller_id',
    p_request->>'requested_caller_id',p_request->>'effective_caller_id',p_request->>'caller_id_type',p_request->>'policy_reason',
    '2026-10-18',p_request->>'destination_number',tariff.country_code,tariff.country_name,
    tariff.rate_per_minute_usd,tariff.billing_increment_seconds,tariff.connection_fee_usd,key) RETURNING * INTO r;
  hold_id:=public.reserve_wallet_funds(p_user_id,budget,'call_budget',r.id::text,'Call budget',60);
  UPDATE public.call_records SET budget_contract_version=1,wallet_hold_id=hold_id,reserved_budget_usd=budget,
    max_duration_seconds=duration_limit,billing_state='reserved' WHERE id=r.id RETURNING * INTO r;
  UPDATE public.call_media_sessions SET call_record_id=r.id WHERE id=p_media_session_id;
  RETURN jsonb_build_object('call',to_jsonb(r),'created',true,'posted_balance',w.balance,'available_balance',available-budget);
END $$;

-- Durable submission markers, never stolen/reissued when a provider response is
-- lost. Telnyx command_id deduplication alone only lasts 60 seconds.
CREATE FUNCTION public.begin_media_call_leg(p_call_id uuid,p_leg text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.call_records;
BEGIN
  IF current_setting('role',true) IS DISTINCT FROM 'service_role' THEN RAISE EXCEPTION 'Trusted call service required' USING ERRCODE='42501'; END IF;
  PERFORM 1 FROM public.wallets WHERE user_id=(SELECT user_id FROM public.call_records WHERE id=p_call_id) FOR UPDATE;
  SELECT * INTO r FROM public.call_records WHERE id=p_call_id FOR UPDATE;
  IF p_leg IS NULL OR p_leg NOT IN ('app','destination') THEN RAISE EXCEPTION 'Invalid call leg'; END IF;
  IF r.id IS NULL OR r.billing_state='settled' OR r.cancellation_requested_at IS NOT NULL
    OR r.destination_ended_at IS NOT NULL OR r.status IN ('completed','failed','cancelled','declined','busy','no_answer')
    OR (p_leg='app' AND r.app_submission_at IS NOT NULL)
    OR (p_leg='destination' AND r.destination_submission_at IS NOT NULL)
  THEN RETURN jsonb_build_object('dispatch',false); END IF;
  PERFORM public.assert_media_call_reservation(r.id,true);
  IF p_leg='destination' AND (r.app_submission_at IS NULL OR r.telnyx_call_control_id_leg_a IS NULL OR
    NOT EXISTS(SELECT 1 FROM public.call_media_sessions WHERE call_record_id=r.id AND media_ready AND app_answered AND NOT cleaned_up))
  THEN RETURN jsonb_build_object('dispatch',false); END IF;
  UPDATE public.call_records SET
    app_submission_at=CASE WHEN p_leg='app' THEN now() ELSE app_submission_at END,
    destination_submission_at=CASE WHEN p_leg='destination' THEN now() ELSE destination_submission_at END,
    billing_state='submitting' WHERE id=r.id RETURNING * INTO r;
  RETURN jsonb_build_object('dispatch',true,'call',to_jsonb(r));
END $$;

CREATE FUNCTION public.request_media_call_termination(p_call_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.call_records;
BEGIN
  IF current_setting('role',true) IS DISTINCT FROM 'service_role' THEN RAISE EXCEPTION 'Trusted call service required' USING ERRCODE='42501'; END IF;
  PERFORM 1 FROM public.wallets WHERE user_id=(SELECT user_id FROM public.call_records WHERE id=p_call_id) FOR UPDATE;
  SELECT * INTO r FROM public.call_records WHERE id=p_call_id FOR UPDATE;
  IF r.id IS NULL OR r.billing_state='settled' THEN RETURN; END IF;
  UPDATE public.call_records SET cancellation_requested_at=coalesce(cancellation_requested_at,now()),
    billing_state='termination_pending' WHERE id=r.id;
  IF r.budget_contract_version=1 AND r.app_submission_at IS NULL THEN
    PERFORM public.assert_media_call_reservation(r.id);
    PERFORM public.settle_call_wallet_hold(r.wallet_hold_id,0,'Call cancelled before submission');
    UPDATE public.call_records SET status='cancelled',ended_at=now(),billing_state='settled' WHERE id=r.id;
  END IF;
END $$;

-- The money commit, call result, and funding provenance commit together. Legacy
-- calls never fall back to an unreserved debit. Unknown evidence retains money.
CREATE OR REPLACE FUNCTION public.finish_media_call(p_call_id uuid,p_ended_at timestamptz,
  p_status text,p_error text,p_payload jsonb)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE r public.call_records; seconds integer:=0; billed integer:=0; cost numeric:=0; txn uuid;
BEGIN
  PERFORM 1 FROM public.wallets WHERE user_id=(SELECT user_id FROM public.call_records WHERE id=p_call_id) FOR UPDATE;
  SELECT * INTO r FROM public.call_records WHERE id=p_call_id FOR UPDATE;
  IF r.id IS NULL OR r.call_type<>'app_to_phone_webrtc' OR r.billing_state='settled' THEN RETURN; END IF;
  IF r.budget_contract_version<>1 THEN
    UPDATE public.call_records SET billing_state='reconciliation_required',reconciliation_reason='legacy_call_budget' WHERE id=r.id;
    RETURN;
  END IF;
  IF p_ended_at IS NULL OR NOT isfinite(p_ended_at) OR p_ended_at<r.started_at
    OR p_status IS NULL OR p_status NOT IN ('completed','declined','busy','no_answer','cancelled','failed')
  THEN RAISE EXCEPTION 'Valid provider terminal evidence required'; END IF;
  IF r.destination_submission_at IS NOT NULL AND (r.destination_ended_at IS NULL OR
    r.destination_ended_at IS DISTINCT FROM p_ended_at OR r.destination_terminal_payload IS DISTINCT FROM p_payload) THEN
    RAISE EXCEPTION 'Stored destination termination evidence required';
  END IF;
  IF r.destination_submission_at IS NOT NULL AND r.answered_at IS NULL AND
    (r.destination_answered_at IS NOT NULL OR NOT (
      coalesce(p_payload->>'sip_hangup_cause','') IN ('603','486','408','480','404','484','410') OR
      coalesce(p_payload->>'hangup_cause','') IN ('user_busy','no_answer','timeout','unallocated_number')))
  THEN
    UPDATE public.call_records SET billing_state='reconciliation_required',reconciliation_reason='awaiting_bridge_or_unanswered_evidence' WHERE id=r.id;
    RETURN;
  END IF;
  PERFORM public.assert_media_call_reservation(r.id);
  IF r.answered_at IS NOT NULL THEN
    IF p_ended_at<r.answered_at THEN RAISE EXCEPTION 'Call end precedes bridge'; END IF;
    -- A confirmed bridge of less than a second uses one billing increment.
    seconds:=greatest(1,ceil(extract(epoch FROM p_ended_at-r.answered_at))::integer);
    billed:=ceil(seconds::numeric/r.billing_increment_seconds)*r.billing_increment_seconds;
    cost:=public.media_call_cost(r.rate_per_minute_usd,r.connection_fee_usd,r.billing_increment_seconds,seconds);
  END IF;
  txn:=public.settle_call_wallet_hold(r.wallet_hold_id,least(cost,r.reserved_budget_usd),'International call',
    jsonb_build_object('call_id',r.id,'duration_seconds',seconds,'billed_duration_seconds',billed,
      'observed_cost_usd',cost,'connection_fee_usd',r.connection_fee_usd,'budget_contract_version',1));
  UPDATE public.call_records SET status=CASE WHEN r.answered_at IS NOT NULL THEN 'completed' ELSE p_status END,
    ended_at=p_ended_at,duration_seconds=seconds,billed_duration_seconds=billed,observed_cost_usd=cost,
    total_cost_usd=least(cost,r.reserved_budget_usd),wallet_txn_id=txn,billing_state='settled',
    reconciliation_reason=CASE WHEN cost>r.reserved_budget_usd OR seconds>r.max_duration_seconds THEN 'provider_duration_overrun' END,
    error_message=p_error,raw_cdr=p_payload,telnyx_hangup_cause=p_payload->>'hangup_cause',hangup_source=p_payload->>'hangup_source'
    WHERE id=r.id;
END $$;

-- Persist evidence independently of the financial attempt. If settlement rolls
-- back, a provider retry (or an operator replay) can use these stored facts.
CREATE FUNCTION public.record_media_call_evidence(p_call_id uuid,p_leg text,p_event_type text,
  p_occurred_at timestamptz,p_payload jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.call_records; control_id text:=p_payload->>'call_control_id'; expected text;
BEGIN
  IF current_setting('role',true) IS DISTINCT FROM 'service_role' THEN RAISE EXCEPTION 'Trusted call service required' USING ERRCODE='42501'; END IF;
  PERFORM 1 FROM public.wallets WHERE user_id=(SELECT user_id FROM public.call_records WHERE id=p_call_id) FOR UPDATE;
  SELECT * INTO r FROM public.call_records WHERE id=p_call_id FOR UPDATE;
  IF r.id IS NULL OR p_leg IS NULL OR p_leg NOT IN ('app','destination') OR nullif(control_id,'') IS NULL
    OR p_occurred_at IS NULL OR NOT isfinite(p_occurred_at) OR p_occurred_at<r.started_at THEN RAISE EXCEPTION 'Invalid call evidence'; END IF;
  expected:=CASE WHEN p_leg='app' THEN r.telnyx_call_control_id_leg_a ELSE r.telnyx_call_control_id_leg_b END;
  IF expected IS NOT NULL AND expected<>control_id THEN RAISE EXCEPTION 'Call leg mismatch'; END IF;
  IF r.budget_contract_version=1 AND ((p_leg='app' AND r.app_submission_at IS NULL) OR
    (p_leg='destination' AND r.destination_submission_at IS NULL)) THEN RAISE EXCEPTION 'Call leg was not submitted'; END IF;
  UPDATE public.call_records SET
    telnyx_call_control_id_leg_a=CASE WHEN p_leg='app' THEN control_id ELSE telnyx_call_control_id_leg_a END,
    telnyx_call_control_id_leg_b=CASE WHEN p_leg='destination' THEN control_id ELSE telnyx_call_control_id_leg_b END WHERE id=r.id;
  IF r.billing_state='settled' THEN RETURN; END IF;
  IF p_event_type='call.bridged' AND p_leg='destination' THEN
    UPDATE public.call_records SET answered_at=least(answered_at,p_occurred_at),
      status=CASE WHEN destination_ended_at IS NULL THEN 'in_progress' ELSE status END,
      billing_state=CASE WHEN destination_ended_at IS NULL THEN 'active' ELSE billing_state END WHERE id=r.id;
  ELSIF p_event_type='call.ringing' AND p_leg='destination' THEN
    UPDATE public.call_records SET status='ringing' WHERE id=r.id AND status='initiated' AND destination_ended_at IS NULL;
  ELSIF p_event_type='call.answered' AND p_leg='destination' THEN
    UPDATE public.call_records SET destination_answered_at=least(destination_answered_at,p_occurred_at) WHERE id=r.id;
  ELSIF p_event_type='call.hangup' AND p_leg='destination' THEN
    -- First destination terminal evidence is immutable; an inconsistent second
    -- terminal event requires investigation rather than another charge.
    IF r.destination_ended_at IS NOT NULL AND (r.destination_ended_at<>p_occurred_at OR r.destination_terminal_payload IS DISTINCT FROM p_payload) THEN
      RAISE EXCEPTION 'Conflicting destination termination evidence'; END IF;
    UPDATE public.call_records SET destination_ended_at=p_occurred_at,destination_terminal_payload=p_payload,
      destination_terminal_status=CASE WHEN p_payload->>'sip_hangup_cause'='603' THEN 'declined'
        WHEN p_payload->>'sip_hangup_cause'='486' OR p_payload->>'hangup_cause'='user_busy' THEN 'busy'
        WHEN p_payload->>'sip_hangup_cause' IN ('408','480') OR p_payload->>'hangup_cause' IN ('timeout','no_answer') THEN 'no_answer'
        WHEN cancellation_requested_at IS NOT NULL THEN 'cancelled' ELSE 'failed' END,
      billing_state='termination_pending' WHERE id=r.id;
  ELSIF p_event_type='call.hangup' AND p_leg='app' THEN
    UPDATE public.call_records SET cancellation_requested_at=coalesce(cancellation_requested_at,p_occurred_at),
      billing_state='termination_pending' WHERE id=r.id;
  END IF;
END $$;

DO $$ DECLARE sig text; BEGIN
  FOREACH sig IN ARRAY ARRAY[
    'media_call_cost(numeric,numeric,integer,integer)','assert_media_call_reservation(uuid,boolean)','prepare_budgeted_media_call(uuid,jsonb,uuid)',
    'begin_media_call_leg(uuid,text)','request_media_call_termination(uuid)',
    'record_media_call_evidence(uuid,text,text,timestamp with time zone,jsonb)',
    'finish_media_call(uuid,timestamp with time zone,text,text,jsonb)'] LOOP
    EXECUTE 'REVOKE ALL ON FUNCTION public.'||sig||' FROM PUBLIC,anon,authenticated,service_role';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.'||sig||' TO service_role';
  END LOOP;
END $$;
COMMIT;
