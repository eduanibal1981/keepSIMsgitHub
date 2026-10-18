-- Task 11. Coordinated financial release only; never backfill submission proof.
BEGIN;
ALTER TABLE public.topup_executions ADD COLUMN supplier_recovery_version smallint NOT NULL DEFAULT 0;
-- Only executions INSERTed after compatible workers take over receive proof.
ALTER TABLE public.topup_executions ALTER COLUMN supplier_recovery_version SET DEFAULT 2;
ALTER TABLE public.topup_executions ADD COLUMN supplier_recovery_required_at timestamptz;
CREATE FUNCTION public.guard_supplier_recovery_version()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
  -- SECURITY INVOKER distinguishes a trusted definer insertion from a direct
  -- client table write. A customer cannot manufacture recovery provenance.
  IF current_user NOT IN ('postgres','supabase_admin','service_role') THEN
    IF TG_OP='INSERT' THEN NEW.supplier_recovery_version:=0; NEW.supplier_recovery_required_at:=NULL;
    ELSIF NEW.supplier_recovery_version IS DISTINCT FROM OLD.supplier_recovery_version
      OR NEW.supplier_recovery_required_at IS DISTINCT FROM OLD.supplier_recovery_required_at THEN
      RAISE EXCEPTION 'Server-owned recovery provenance' USING ERRCODE='42501'; END IF;
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.guard_supplier_recovery_version() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER guard_supplier_recovery_version BEFORE INSERT OR UPDATE ON public.topup_executions
  FOR EACH ROW EXECUTE FUNCTION public.guard_supplier_recovery_version();
CREATE TABLE public.refill_supplier_submissions (
  execution_id uuid PRIMARY KEY REFERENCES public.topup_executions(id),
  hold_id uuid NOT NULL REFERENCES public.wallet_holds(id),
  provider text NOT NULL CHECK(provider IN ('dtone','zendit','reloadly','ding')),
  external_reference text NOT NULL,
  binding jsonb NOT NULL,
  outcome text NOT NULL DEFAULT 'unknown' CHECK(outcome IN ('unknown','pending','success','failed','operator')),
  provider_transaction_id text,
  attempts integer NOT NULL DEFAULT 0 CHECK(attempts>=0),
  next_check_at timestamptz NOT NULL DEFAULT (now()+interval '10 minutes'),
  claim_token uuid,
  lease_until timestamptz,
  review_required_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(provider,external_reference)
);
CREATE UNIQUE INDEX refill_supplier_identity ON public.refill_supplier_submissions(provider,provider_transaction_id)
  WHERE provider_transaction_id IS NOT NULL;
CREATE INDEX refill_supplier_due ON public.refill_supplier_submissions(next_check_at)
  WHERE outcome IN ('unknown','pending');
ALTER TABLE public.refill_supplier_submissions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.refill_supplier_submissions FROM PUBLIC,anon,authenticated,service_role;
GRANT SELECT ON public.refill_supplier_submissions TO service_role;

CREATE FUNCTION public.assert_supplier_recovery_caller(p_allow_scheduler boolean DEFAULT false)
RETURNS void LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
  IF current_setting('role',true)='service_role' AND auth.jwt()->>'role'='service_role' THEN RETURN; END IF;
  IF current_setting('role',true) IN ('none','postgres') AND session_user='postgres' THEN RETURN; END IF;
  RAISE EXCEPTION 'Trusted recovery role required' USING ERRCODE='42501';
END;
$$;

CREATE FUNCTION public.record_refill_supplier_submission(p_execution_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE e public.topup_executions; ref text;
BEGIN
  SELECT * INTO e FROM public.topup_executions WHERE id=p_execution_id;
  IF e.supplier_recovery_version<>2 OR e.api_provider IS NULL OR e.api_provider NOT IN ('dtone','zendit','reloadly','ding') THEN
    RAISE EXCEPTION 'Legacy or unsupported submission requires reconciliation'; END IF;
  -- Reservation assertions already hold the payer's wallet lock. Sibling
  -- submissions serialize through that same wallet before checking this guard.
  -- Even a legacy failed row must block another purchase while unresolved.
  IF EXISTS(SELECT 1 FROM public.topup_executions p
    LEFT JOIN public.wallet_holds h ON h.id=p.wallet_hold_id
    LEFT JOIN public.refill_supplier_submissions s ON s.execution_id=p.id
    WHERE p.sim_line_id=e.sim_line_id AND p.id<>e.id
      AND NOT (p.status='success' AND coalesce(h.status='captured',false))
      AND ((s.execution_id IS NOT NULL AND s.outcome NOT IN ('success','failed'))
        OR p.carrier_in_flight OR h.carrier_in_flight OR p.reloadly_transaction_id IS NOT NULL)) THEN
    RAISE EXCEPTION 'Previous supplier operation requires reconciliation'; END IF;
  ref:=CASE e.api_provider WHEN 'dtone' THEN 'dt_' WHEN 'zendit' THEN 'z_' WHEN 'reloadly' THEN 'rl_' WHEN 'ding' THEN 'd_' END||e.id::text;
  INSERT INTO public.refill_supplier_submissions(execution_id,hold_id,provider,external_reference,binding)
    VALUES(e.id,e.wallet_hold_id,e.api_provider,ref,jsonb_build_object('user_id',e.user_id,'sim_line_id',e.sim_line_id,
      'currency',e.currency,'hold_id',e.wallet_hold_id,'route',public.scheduled_refill_route(e)));
END;
$$;
CREATE OR REPLACE FUNCTION public.begin_refill_submission(p_execution_id uuid,p_hold_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE e public.topup_executions;
BEGIN
  PERFORM public.assert_supplier_recovery_caller();
  PERFORM public.lock_refill_setup_order(p_execution_id);
  SELECT * INTO e FROM public.topup_executions WHERE id=p_execution_id FOR UPDATE;
  IF NOT FOUND OR e.status NOT IN ('processing','routing') OR e.carrier_in_flight
    OR e.reloadly_transaction_id IS NOT NULL THEN RAISE EXCEPTION 'Execution requires reconciliation'; END IF;
  PERFORM public.assert_instant_refill_reservation(e.id,p_hold_id);
  IF NOT EXISTS(SELECT 1 FROM public.wallet_holds WHERE id=p_hold_id AND status='active'
    AND NOT carrier_in_flight AND expires_at>now()) THEN
    RAISE EXCEPTION 'Matching active wallet reservation required';
  END IF;
  UPDATE public.wallet_holds SET carrier_in_flight=true,updated_at=now() WHERE id=p_hold_id;
  UPDATE public.topup_executions SET carrier_in_flight=true,updated_at=now() WHERE id=e.id;
  PERFORM public.record_refill_supplier_submission(e.id);
END;
$$;

CREATE OR REPLACE FUNCTION public.begin_scheduled_refill_submission(p_execution_id uuid,p_hold_id uuid,p_route jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE e public.topup_executions;
BEGIN
  PERFORM public.assert_supplier_recovery_caller();
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
  PERFORM public.record_refill_supplier_submission(e.id);
END;
$$;

CREATE FUNCTION public.claim_refill_supplier_reconciliation(p_limit integer DEFAULT 10)
RETURNS SETOF public.refill_supplier_submissions LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  PERFORM public.assert_supplier_recovery_caller();
  IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 25 THEN RAISE EXCEPTION 'Invalid reconciliation limit'; END IF;
  -- Repeated process crashes also exhaust the retry budget.
  WITH exhausted AS (
    SELECT execution_id FROM public.refill_supplier_submissions WHERE outcome IN ('unknown','pending')
      AND attempts>=12 AND (lease_until IS NULL OR lease_until<now())
      ORDER BY next_check_at LIMIT p_limit FOR UPDATE SKIP LOCKED
  ), flagged AS (
    UPDATE public.refill_supplier_submissions SET outcome='operator',review_required_at=now(),updated_at=now()
      WHERE execution_id IN (SELECT execution_id FROM exhausted) RETURNING execution_id,hold_id
  ) INSERT INTO public.system_alerts(kind,message,details)
      SELECT 'supplier_reconciliation_required','Reconciliation retry budget exhausted; reservation retained',
        jsonb_build_object('execution_id',execution_id,'hold_id',hold_id) FROM flagged;
  RETURN QUERY WITH due AS (
    SELECT execution_id FROM public.refill_supplier_submissions
    WHERE outcome IN ('unknown','pending') AND attempts<12 AND next_check_at<=now()
      AND (lease_until IS NULL OR lease_until<now())
    ORDER BY next_check_at,execution_id LIMIT p_limit FOR UPDATE SKIP LOCKED
  ) UPDATE public.refill_supplier_submissions s SET claim_token=gen_random_uuid(),
      lease_until=now()+interval '10 minutes',attempts=attempts+1,updated_at=now()
    FROM due WHERE s.execution_id=due.execution_id RETURNING s.*;
END;
$$;

CREATE FUNCTION public.complete_refill_supplier_reconciliation(p_execution_id uuid,p_claim_token uuid,
  p_outcome text,p_provider_tx_id text DEFAULT NULL,p_pin_code text DEFAULT NULL,
  p_pin_serial text DEFAULT NULL,p_redeem_instructions text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE s public.refill_supplier_submissions; e public.topup_executions; h public.wallet_holds;
  o public.sim_setup_orders; result jsonb; v_outcome text:=p_outcome;
BEGIN
  PERFORM public.assert_supplier_recovery_caller();
  IF p_outcome IS NULL OR p_outcome NOT IN ('success','failed','pending','unknown','operator') THEN
    RAISE EXCEPTION 'Invalid supplier outcome'; END IF;
  -- Agrees with setup finalization and worker settlement. Claim only locks the
  -- queue in its short transaction; never hold a DB lock during provider I/O.
  PERFORM public.lock_refill_setup_order(p_execution_id);
  SELECT * INTO e FROM public.topup_executions WHERE id=p_execution_id FOR UPDATE;
  PERFORM 1 FROM public.wallets WHERE user_id=e.user_id FOR UPDATE;
  SELECT * INTO h FROM public.wallet_holds WHERE id=e.wallet_hold_id FOR UPDATE;
  SELECT * INTO s FROM public.refill_supplier_submissions WHERE execution_id=p_execution_id FOR UPDATE;
  IF s.execution_id IS NULL OR p_claim_token IS NULL OR s.claim_token IS DISTINCT FROM p_claim_token THEN
    RAISE EXCEPTION 'Reconciliation lease unavailable'; END IF;
  IF s.outcome IN ('success','failed') AND (s.outcome IS DISTINCT FROM p_outcome OR s.provider_transaction_id IS DISTINCT FROM p_provider_tx_id) THEN
    RAISE EXCEPTION 'Reconciliation identity mismatch'; END IF;
  IF s.outcome IN ('success','failed','operator') THEN
    RETURN jsonb_build_object('outcome',s.outcome,'idempotent',true); END IF;
  IF s.lease_until IS NULL OR s.lease_until<now() THEN RAISE EXCEPTION 'Reconciliation lease unavailable'; END IF;
  IF s.binding IS DISTINCT FROM jsonb_build_object('user_id',e.user_id,'sim_line_id',e.sim_line_id,
    'currency',e.currency,'hold_id',e.wallet_hold_id,'route',public.scheduled_refill_route(e))
    OR e.supplier_recovery_version<>2 OR s.provider IS DISTINCT FROM e.api_provider
    OR s.hold_id IS DISTINCT FROM e.wallet_hold_id THEN
    v_outcome:='operator';
  END IF;
  IF v_outcome IN ('success','failed') AND (nullif(btrim(p_provider_tx_id),'') IS NULL
    OR (s.provider<>'zendit' AND p_provider_tx_id=s.external_reference)) THEN
    RAISE EXCEPTION 'Confirmed supplier transaction required'; END IF;
  IF v_outcome='failed' AND (e.status='success' OR h.status='captured' OR e.reloadly_transaction_id IS NOT NULL) THEN
    v_outcome:='operator'; END IF;
  IF v_outcome IN ('success','failed') THEN
    -- Atomic subtransaction: a capture/finalization failure retains ALL money
    -- and delivery state and becomes a durable operator item, without exposing
    -- provider payloads or SQL errors in alerts.
    BEGIN
      IF e.execution_type IN ('refill_mini','refill_custom') THEN
        PERFORM public.assert_scheduled_refill_reservation(e.id,h.id);
      ELSIF e.execution_type='refill_instant' THEN
        PERFORM public.assert_instant_refill_reservation(e.id,h.id);
      ELSE RAISE EXCEPTION 'Unsupported supplier execution'; END IF;
      IF v_outcome='success' THEN
        IF e.execution_type='refill_instant' THEN
          result:=public.settle_instant_refill_execution(e.id,p_provider_tx_id,h.id,p_pin_code,p_pin_serial,p_redeem_instructions);
        ELSE
          result:=public.settle_successful_execution(e.id,p_provider_tx_id,h.id,p_pin_code,p_pin_serial,p_redeem_instructions);
        END IF;
        SELECT * INTO o FROM public.sim_setup_orders WHERE first_refill_hold_id=h.id;
        IF o.id IS NOT NULL THEN
          result:=public.finalize_sim_setup_order(o.id,o.sim_line_id);
          IF result->>'success' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Setup reconciliation required'; END IF;
        END IF;
      ELSE
        IF h.status<>'active' OR NOT h.carrier_in_flight OR NOT e.carrier_in_flight THEN
          RAISE EXCEPTION 'Submitted reservation required'; END IF;
        UPDATE public.topup_executions SET status='failed',carrier_in_flight=false,
          failure_reason='Supplier confirmed terminal failure',completed_at=now(),updated_at=now() WHERE id=e.id;
        UPDATE public.wallet_holds SET carrier_in_flight=false WHERE id=h.id;
        PERFORM public.release_wallet_hold(h.id,'Supplier confirmed terminal failure');
        SELECT * INTO o FROM public.sim_setup_orders WHERE first_refill_hold_id=h.id;
        IF o.id IS NOT NULL THEN PERFORM public.release_sim_setup_holds(o.id,'Supplier confirmed terminal failure'); END IF;
      END IF;
      UPDATE public.refill_supplier_submissions SET provider_transaction_id=p_provider_tx_id WHERE execution_id=e.id;
    EXCEPTION WHEN OTHERS THEN v_outcome:='operator';
    END;
  END IF;
  IF v_outcome IN ('unknown','pending') AND s.attempts>=12 THEN v_outcome:='operator'; END IF;
  UPDATE public.refill_supplier_submissions SET outcome=v_outcome,
    next_check_at=now()+make_interval(secs=>least(21600,60*power(2,least(s.attempts,8)))::integer),
    lease_until=NULL,updated_at=now(),
    review_required_at=CASE WHEN v_outcome='operator' THEN coalesce(review_required_at,now()) ELSE review_required_at END
    WHERE execution_id=e.id;
  IF v_outcome='operator' AND s.review_required_at IS NULL THEN
    INSERT INTO public.system_alerts(kind,message,details)
      VALUES('supplier_reconciliation_required','Supplier outcome requires operator review; reservation retained',
        jsonb_build_object('execution_id',e.id,'hold_id',s.hold_id));
  END IF;
  RETURN jsonb_build_object('outcome',v_outcome,'execution_id',e.id);
END;
$$;

-- Safe release requires positive post-cutover provenance plus the complete
-- reservation binding, not the absence of a newly defaulted in-flight flag.
CREATE OR REPLACE FUNCTION public.recover_expired_wallet_holds(p_limit integer DEFAULT 100)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE h public.wallet_holds; e public.topup_executions; o public.sim_setup_orders;
  candidate uuid; v_safe boolean; v_released integer:=0; v_review integer:=0;
BEGIN
  PERFORM public.assert_supplier_recovery_caller(true);
  IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Invalid recovery limit'; END IF;
  FOR candidate IN SELECT id FROM public.wallet_holds WHERE status='active' AND expires_at<now()
    AND recovery_required_at IS NULL ORDER BY expires_at,id LIMIT p_limit
  LOOP
    v_safe:=false;
    SELECT * INTO h FROM public.wallet_holds WHERE id=candidate;
    -- Setup -> execution -> wallet -> hold. No hold lock is taken first.
    SELECT * INTO o FROM public.sim_setup_orders WHERE h.id IN (annual_fee_hold_id,first_refill_hold_id) FOR UPDATE;
    SELECT * INTO e FROM public.topup_executions WHERE wallet_hold_id=coalesce(o.first_refill_hold_id,h.id)
      ORDER BY created_at LIMIT 1 FOR UPDATE SKIP LOCKED;
    PERFORM 1 FROM public.wallets WHERE id=h.wallet_id FOR UPDATE SKIP LOCKED;
    IF NOT FOUND THEN CONTINUE; END IF;
    SELECT * INTO h FROM public.wallet_holds WHERE id=candidate AND status='active' FOR UPDATE SKIP LOCKED;
    IF NOT FOUND THEN CONTINUE; END IF;
    IF e.id IS NOT NULL AND e.supplier_recovery_version=2 AND e.status IN ('failed','cancelled')
      AND e.reloadly_transaction_id IS NULL AND NOT e.carrier_in_flight AND NOT h.carrier_in_flight
      AND h.recovery_contract_version>=1 AND NOT EXISTS(
        SELECT 1 FROM public.refill_supplier_submissions WHERE execution_id=e.id)
    THEN
      BEGIN
        IF e.execution_type IN ('refill_mini','refill_custom') THEN
          PERFORM public.assert_scheduled_refill_reservation(e.id,e.wallet_hold_id);
        ELSIF e.execution_type='refill_instant' THEN
          PERFORM public.assert_instant_refill_reservation(e.id,e.wallet_hold_id);
        ELSE RAISE EXCEPTION 'Unsupported recovery operation'; END IF;
        IF o.id IS NOT NULL THEN
          PERFORM public.release_sim_setup_holds(o.id,'Recovery: proven pre-submission failure');
        ELSE PERFORM public.release_wallet_hold(h.id,'Recovery: proven pre-submission failure'); END IF;
        v_safe:=true;
      EXCEPTION WHEN OTHERS THEN v_safe:=false;
      END;
    END IF;
    IF v_safe THEN v_released:=v_released+1;
    ELSE
      UPDATE public.wallet_holds SET recovery_required_at=now(),updated_at=now() WHERE id=h.id;
      INSERT INTO public.system_alerts(kind,message,details)
        VALUES('wallet_hold_reconciliation_required','Expired reservation requires operator reconciliation',jsonb_build_object('hold_id',h.id));
      v_review:=v_review+1;
    END IF;
  END LOOP;
  -- Payouts remain reserved. This does not authorize resubmission.
  WITH stale AS (SELECT id FROM public.wallet_refund_items WHERE status='processing'
    AND claimed_at<now()-interval '30 minutes' ORDER BY claimed_at LIMIT p_limit FOR UPDATE SKIP LOCKED)
  UPDATE public.wallet_refund_items SET status='reconciliation_required',claim_token=NULL,updated_at=now()
    WHERE id IN (SELECT id FROM stale);
  RETURN jsonb_build_object('released',v_released,'review_required',v_review);
END;
$$;

CREATE OR REPLACE FUNCTION public.reap_stuck_executions(p_stuck_after_minutes integer DEFAULT 10,p_max_retries integer DEFAULT 3)
RETURNS TABLE(requeued integer,dead_lettered integer) LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE e public.topup_executions; candidate uuid; v_requeued integer:=0; v_dead integer:=0; safe boolean; setup_id uuid;
BEGIN
  PERFORM public.assert_supplier_recovery_caller(true);
  IF p_stuck_after_minutes IS NULL OR p_stuck_after_minutes NOT BETWEEN 5 AND 1440
    OR p_max_retries IS NULL OR p_max_retries NOT BETWEEN 1 AND 10 THEN RAISE EXCEPTION 'Invalid reaper bounds' USING ERRCODE='22023'; END IF;
  FOR candidate IN SELECT id FROM public.topup_executions WHERE status IN ('processing','routing')
    AND supplier_recovery_required_at IS NULL
    AND coalesce(processing_since,created_at)<now()-make_interval(mins=>p_stuck_after_minutes)
    ORDER BY coalesce(processing_since,created_at),id LIMIT 100
  LOOP
    PERFORM public.lock_refill_setup_order(candidate);
    SELECT * INTO e FROM public.topup_executions WHERE id=candidate AND status IN ('processing','routing') FOR UPDATE SKIP LOCKED;
    IF NOT FOUND THEN CONTINUE; END IF;
    safe:=e.supplier_recovery_version=2 AND NOT e.carrier_in_flight AND e.reloadly_transaction_id IS NULL
      AND NOT EXISTS(SELECT 1 FROM public.refill_supplier_submissions WHERE execution_id=e.id)
      AND NOT EXISTS(SELECT 1 FROM public.wallet_holds WHERE id=e.wallet_hold_id
        AND (carrier_in_flight OR status<>'active' OR recovery_contract_version<1));
    IF safe AND e.reaper_retries<p_max_retries THEN
      UPDATE public.topup_executions SET status='pending',
        reaper_retries=reaper_retries+1,processing_since=NULL,updated_at=now() WHERE id=e.id;
      v_requeued:=v_requeued+1;
    ELSE
      -- Submitted rows remain in the durable reconciliation queue, never pending.
      UPDATE public.topup_executions SET status=CASE WHEN safe THEN 'failed' ELSE status END,
        supplier_recovery_required_at=now(),failure_reason='Recovery required; automatic purchase retry blocked',
        completed_at=CASE WHEN safe THEN now() ELSE completed_at END,updated_at=now() WHERE id=e.id;
      v_dead:=v_dead+1;
      IF safe AND e.wallet_hold_id IS NOT NULL THEN
        BEGIN
          IF e.execution_type IN ('refill_mini','refill_custom') THEN
            PERFORM public.assert_scheduled_refill_reservation(e.id,e.wallet_hold_id);
          ELSIF e.execution_type='refill_instant' THEN
            PERFORM public.assert_instant_refill_reservation(e.id,e.wallet_hold_id);
          ELSE RAISE EXCEPTION 'Unsupported recovery operation'; END IF;
          SELECT id INTO setup_id FROM public.sim_setup_orders WHERE first_refill_hold_id=e.wallet_hold_id;
          IF setup_id IS NOT NULL THEN PERFORM public.release_sim_setup_holds(setup_id,'Reaper: proven pre-submission failure');
          ELSE PERFORM public.release_wallet_hold(e.wallet_hold_id,'Reaper: proven pre-submission failure'); END IF;
        EXCEPTION WHEN OTHERS THEN NULL; -- Operator item below records unresolved recovery.
        END;
      END IF;
      IF NOT EXISTS(SELECT 1 FROM public.refill_supplier_submissions WHERE execution_id=e.id) THEN
        INSERT INTO public.system_alerts(kind,message,details) VALUES('supplier_reconciliation_required',
          'Execution requires operator review before retry or release',jsonb_build_object('execution_id',e.id,'hold_id',e.wallet_hold_id));
      END IF;
    END IF;
  END LOOP;
  PERFORM public.recover_expired_wallet_holds(100);
  RETURN QUERY SELECT v_requeued,v_dead;
END;
$$;
REVOKE ALL ON FUNCTION public.assert_supplier_recovery_caller(boolean),public.record_refill_supplier_submission(uuid),
  public.claim_refill_supplier_reconciliation(integer),public.complete_refill_supplier_reconciliation(uuid,uuid,text,text,text,text,text),
  public.reap_stuck_executions(integer,integer),public.recover_expired_wallet_holds(integer) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.claim_refill_supplier_reconciliation(integer),
  public.complete_refill_supplier_reconciliation(uuid,uuid,text,text,text,text,text),
  public.reap_stuck_executions(integer,integer),public.recover_expired_wallet_holds(integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.reap_stuck_executions(integer,integer),public.recover_expired_wallet_holds(integer) TO postgres;
CREATE OR REPLACE FUNCTION public.fail_instant_refill_before_submission(p_execution_id uuid,p_hold_id uuid,p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE e public.topup_executions; h public.wallet_holds;
BEGIN
  PERFORM public.lock_refill_setup_order(p_execution_id);
  SELECT * INTO e FROM public.topup_executions WHERE id=p_execution_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Execution unavailable'; END IF;
  IF e.supplier_recovery_version<>2 OR EXISTS(SELECT 1 FROM public.refill_supplier_submissions WHERE execution_id=e.id) OR e.status='success' OR e.carrier_in_flight OR e.reloadly_transaction_id IS NOT NULL THEN
    RETURN jsonb_build_object('success',false,'reconciliation_required',true); END IF;
  IF e.wallet_hold_id IS DISTINCT FROM p_hold_id THEN RAISE EXCEPTION 'Reservation binding mismatch'; END IF;
  IF p_hold_id IS NOT NULL THEN
    PERFORM 1 FROM public.wallets WHERE user_id=e.user_id FOR UPDATE;
    SELECT * INTO h FROM public.wallet_holds WHERE id=p_hold_id FOR UPDATE;
    IF h.id IS NULL OR h.user_id IS DISTINCT FROM e.user_id OR NOT EXISTS(
      SELECT 1 FROM public.wallets WHERE id=h.wallet_id AND user_id=e.user_id AND currency=h.currency
    ) THEN RAISE EXCEPTION 'Reservation binding mismatch'; END IF;
    IF h.carrier_in_flight OR h.status='captured' OR h.recovery_contract_version<1 THEN
      RETURN jsonb_build_object('success',false,'reconciliation_required',true); END IF;
    IF h.status='active' THEN PERFORM public.assert_instant_refill_reservation(e.id,h.id);
      PERFORM public.release_wallet_hold(h.id,p_reason); END IF;
  END IF;
  UPDATE public.topup_executions SET status='failed',failure_reason=p_reason,updated_at=now() WHERE id=e.id;
  RETURN jsonb_build_object('success',true,'status','failed');
END;
$$;

CREATE OR REPLACE FUNCTION public.stop_scheduled_refill_before_submission(p_execution_id uuid,p_reason text,p_status text DEFAULT 'failed')
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
  IF e.supplier_recovery_version<>2 OR EXISTS(SELECT 1 FROM public.refill_supplier_submissions WHERE execution_id=e.id) OR e.status NOT IN ('processing','routing') OR e.carrier_in_flight
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

CREATE OR REPLACE FUNCTION public.prepare_scheduled_refill(p_execution_id uuid,p_route jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE e public.topup_executions; h uuid; ref text; v_amount numeric; v_fee numeric; v_cost numeric;
BEGIN
  IF auth.jwt()->>'role' IS DISTINCT FROM 'service_role'
    AND current_setting('role',true) NOT IN ('none','postgres','supabase_admin') THEN
    RAISE EXCEPTION 'Service role required' USING ERRCODE='42501'; END IF;
  SELECT * INTO e FROM public.topup_executions WHERE id=p_execution_id FOR UPDATE;
  IF NOT FOUND OR e.execution_type NOT IN ('refill_mini','refill_custom') OR e.execution_type IS NULL
    OR e.status NOT IN ('processing','routing') OR e.supplier_recovery_version<>2 OR e.carrier_in_flight
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

CREATE OR REPLACE FUNCTION public.release_sim_setup_holds(p_order_id uuid,p_reason text DEFAULT 'Recharge failed or cancelled')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE o public.sim_setup_orders;
BEGIN
  SELECT * INTO o FROM public.sim_setup_orders WHERE id=p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Setup unavailable'; END IF;
  IF EXISTS(SELECT 1 FROM public.topup_executions WHERE wallet_hold_id=o.first_refill_hold_id AND supplier_recovery_version<>2) THEN
    RAISE EXCEPTION 'Legacy setup execution requires reconciliation'; END IF;
  PERFORM public.assert_setup_hold_bindings(o.id);
  PERFORM 1 FROM public.topup_executions WHERE wallet_hold_id=o.first_refill_hold_id FOR UPDATE;
  PERFORM 1 FROM public.wallets WHERE user_id=o.user_id FOR UPDATE;
  IF EXISTS(SELECT 1 FROM public.wallet_holds WHERE id IN (o.annual_fee_hold_id,o.first_refill_hold_id)
    AND status='active' AND recovery_contract_version<1) THEN
    RAISE EXCEPTION 'Legacy setup requires reconciliation'; END IF;
  IF o.status='active' OR o.provider_tx_id IS NOT NULL OR EXISTS(
    SELECT 1 FROM public.wallet_holds WHERE id IN (o.annual_fee_hold_id,o.first_refill_hold_id)
      AND (carrier_in_flight OR status='captured')
  ) OR EXISTS(SELECT 1 FROM public.topup_executions WHERE wallet_hold_id=o.first_refill_hold_id
    AND (status IN ('processing','success') OR reloadly_transaction_id IS NOT NULL OR carrier_in_flight)) THEN
    RAISE EXCEPTION 'Delivery reconciliation required before releasing setup funds';
  END IF;
  PERFORM public.release_wallet_hold(id,p_reason) FROM public.wallet_holds
    WHERE id IN (o.annual_fee_hold_id,o.first_refill_hold_id) AND status='active';
  UPDATE public.sim_setup_orders SET status='failed',failure_reason=p_reason,updated_at=now() WHERE id=o.id;
  RETURN jsonb_build_object('success',false,'status','failed','reason',p_reason);
END;
$$;
NOTIFY pgrst,'reload schema';
COMMIT;
