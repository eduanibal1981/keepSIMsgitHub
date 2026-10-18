BEGIN;


CREATE OR REPLACE FUNCTION public.assert_setup_hold_bindings(p_order_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE o public.sim_setup_orders;
BEGIN
  SELECT * INTO o FROM public.sim_setup_orders WHERE id=p_order_id;
  IF EXISTS(SELECT 1 FROM public.wallet_holds h WHERE id IN(o.annual_fee_hold_id,o.first_refill_hold_id)
    AND (h.user_id IS DISTINCT FROM o.user_id OR h.currency<>'USD'
      OR NOT EXISTS(SELECT 1 FROM public.wallets WHERE id=h.wallet_id AND user_id=o.user_id AND currency=h.currency)
      OR (h.id=o.annual_fee_hold_id AND (h.order_type<>'plan_fee' OR h.amount<>o.annual_fee_usd
        OR h.order_reference_id NOT IN ('setup_fee_'||o.id::text,'std_fallback_'||o.id::text)))
      OR (h.id=o.first_refill_hold_id AND (h.order_type<>'setup_refill' OR h.amount<>o.first_refill_cost_usd
        OR h.order_reference_id<>'setup_refill_'||o.id::text)))) THEN
    RAISE EXCEPTION 'Setup reservation binding mismatch'; END IF;
END;
$$;

-- Lock setup orders before executions/wallets, matching finalization/fallback.
CREATE OR REPLACE FUNCTION public.lock_refill_setup_order(p_execution_id uuid)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
  SELECT 1 FROM public.sim_setup_orders WHERE first_refill_hold_id=(
    SELECT wallet_hold_id FROM public.topup_executions WHERE id=p_execution_id
  ) FOR UPDATE;
$$;

-- Called only while the execution is locked. A populated hold ID is not proof
-- of payment: validate the actual wallet, operation, reference and allocations.
CREATE OR REPLACE FUNCTION public.assert_instant_refill_reservation(p_execution_id uuid,p_hold_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE e public.topup_executions; h public.wallet_holds; o public.sim_setup_orders;
BEGIN
  SELECT * INTO e FROM public.topup_executions WHERE id=p_execution_id;
  PERFORM 1 FROM public.wallets WHERE user_id=e.user_id FOR UPDATE;
  SELECT * INTO h FROM public.wallet_holds WHERE id=p_hold_id FOR UPDATE;
  IF e.id IS NULL OR h.id IS NULL OR e.wallet_hold_id IS DISTINCT FROM h.id
    OR h.user_id IS DISTINCT FROM e.user_id OR h.amount IS DISTINCT FROM e.amount
    OR e.amount<=0 OR e.currency IS DISTINCT FROM 'USD' OR h.currency IS DISTINCT FROM e.currency
    OR coalesce(e.payment_gateway_code,'wallet')<>'wallet'
    OR (e.funding_kind='setup_hold' AND h.order_type<>'setup_refill')
    OR h.status NOT IN ('active','captured') OR h.recovery_contract_version<1
    OR NOT EXISTS(SELECT 1 FROM public.wallets WHERE id=h.wallet_id AND user_id=e.user_id AND currency=e.currency)
    OR NOT EXISTS(SELECT 1 FROM public.sim_lines WHERE id=e.sim_line_id AND user_id=e.user_id)
    OR EXISTS(SELECT 1 FROM public.topup_executions WHERE wallet_hold_id=h.id AND id<>e.id)
  THEN RAISE EXCEPTION 'Matching active wallet reservation required'; END IF;
  IF h.order_type='setup_refill' THEN
    SELECT * INTO o FROM public.sim_setup_orders WHERE first_refill_hold_id=h.id;
    IF o.id IS NULL OR o.user_id IS DISTINCT FROM e.user_id OR o.sim_line_id IS DISTINCT FROM e.sim_line_id
      OR o.plan<>'premium' OR o.status NOT IN ('reserved','dispatching','active')
      OR o.first_refill_cost_usd IS DISTINCT FROM e.amount
      OR h.order_reference_id IS DISTINCT FROM 'setup_refill_'||o.id::text
      OR NOT EXISTS(SELECT 1 FROM public.sim_lines WHERE id=o.sim_line_id AND phone_number=o.phone_number)
      OR (o.annual_fee_usd>0 AND NOT EXISTS(SELECT 1 FROM public.wallet_holds f
        WHERE f.id=o.annual_fee_hold_id AND f.user_id=o.user_id AND f.wallet_id=h.wallet_id
          AND f.currency=h.currency AND f.amount=o.annual_fee_usd AND f.order_type='plan_fee'
          AND f.order_reference_id='setup_fee_'||o.id::text AND f.status IN ('active','captured')))
    THEN RAISE EXCEPTION 'Setup reservation binding mismatch'; END IF;
  ELSIF h.order_type<>'refill_instant' OR h.order_reference_id NOT IN (e.id::text,'exec_'||e.id::text) THEN
    RAISE EXCEPTION 'Execution reservation binding mismatch';
  END IF;
  IF h.status='active' THEN PERFORM public.assert_wallet_funding_integrity(h.wallet_id); END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.begin_refill_submission(p_execution_id uuid,p_hold_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE e public.topup_executions;
BEGIN
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
END;
$$;

CREATE OR REPLACE FUNCTION public.settle_instant_refill_execution(p_execution_id uuid,p_provider_tx_id text,p_hold_id uuid,
  p_pin_code text DEFAULT NULL,p_pin_serial text DEFAULT NULL,p_redeem_instructions text DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE e public.topup_executions; h public.wallet_holds; v_tx uuid;
BEGIN
  IF nullif(btrim(p_provider_tx_id),'') IS NULL THEN RAISE EXCEPTION 'Confirmed provider identity required'; END IF;
  PERFORM public.lock_refill_setup_order(p_execution_id);
  SELECT * INTO e FROM public.topup_executions WHERE id=p_execution_id FOR UPDATE;
  PERFORM public.assert_instant_refill_reservation(p_execution_id,p_hold_id);
  SELECT * INTO h FROM public.wallet_holds WHERE id=p_hold_id;
  IF e.status='success' THEN
    IF e.reloadly_transaction_id IS DISTINCT FROM p_provider_tx_id OR h.status<>'captured' THEN
      RAISE EXCEPTION 'Settlement identity mismatch'; END IF;
  ELSIF NOT coalesce(e.carrier_in_flight,false) OR NOT h.carrier_in_flight OR h.status<>'active'
    OR (e.reloadly_transaction_id IS NOT NULL AND e.reloadly_transaction_id<>p_provider_tx_id) THEN
    RAISE EXCEPTION 'Persisted supplier submission required';
  END IF;
  -- Untrusted metadata cannot override the authoritative execution/provider keys.
  v_tx:=public.capture_wallet_hold(h.id,'topup_debit','Instant SIM refill',
    coalesce(p_metadata,'{}'::jsonb)||jsonb_build_object('execution_id',e.id,
      'sim_line_id',e.sim_line_id,'provider_tx_id',p_provider_tx_id));
  IF NOT EXISTS(SELECT 1 FROM public.wallet_transactions WHERE id=v_tx
    AND metadata->>'execution_id'=e.id::text AND metadata->>'provider_tx_id'=p_provider_tx_id) THEN
    RAISE EXCEPTION 'Settlement receipt mismatch'; END IF;
  UPDATE public.wallet_holds SET carrier_in_flight=false,updated_at=now() WHERE id=h.id;
  UPDATE public.topup_executions SET status='success',reloadly_transaction_id=p_provider_tx_id,
    pin_code=coalesce(p_pin_code,pin_code),pin_serial=coalesce(p_pin_serial,pin_serial),
    redeem_instructions=coalesce(p_redeem_instructions,redeem_instructions),
    executed_at=coalesce(executed_at,now()),completed_at=coalesce(completed_at,now()),
    failure_reason=NULL,carrier_in_flight=false,updated_at=now() WHERE id=e.id;
  RETURN jsonb_build_object('success',true,'execution_id',e.id,'wallet_txn_id',v_tx,'idempotent',e.status='success');
END;
$$;

-- A stale worker must never release a reservation or downgrade delivered work.
CREATE OR REPLACE FUNCTION public.fail_instant_refill_before_submission(p_execution_id uuid,p_hold_id uuid,p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE e public.topup_executions; h public.wallet_holds;
BEGIN
  PERFORM public.lock_refill_setup_order(p_execution_id);
  SELECT * INTO e FROM public.topup_executions WHERE id=p_execution_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Execution unavailable'; END IF;
  IF e.status='success' OR e.carrier_in_flight OR e.reloadly_transaction_id IS NOT NULL THEN
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

CREATE OR REPLACE FUNCTION public.capture_sim_setup_holds(
  p_order_id UUID,
  p_provider_tx_id TEXT DEFAULT NULL::TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_order            RECORD;
  v_line_id          UUID;
  v_interval_days    INTEGER := 30;
  v_rule             RECORD;
  v_notify_amount    NUMERIC := 1.00;
  v_execution        RECORD;
  v_base_cost        NUMERIC := NULL;
  v_app_fee          NUMERIC := NULL;
  v_refill_amount    NUMERIC := NULL;
  v_offer_id         TEXT := NULL;
  v_offer_value      BIGINT := NULL;
  v_provider         TEXT := NULL;
  v_intent_kind      TEXT := 'exact_airtime';
  v_target_local_val NUMERIC := NULL;
  v_target_local_cur TEXT := NULL;
  v_fee_rule_ver     INTEGER := NULL;
BEGIN
  SELECT * INTO v_order
  FROM public.sim_setup_orders
  WHERE id = p_order_id FOR UPDATE;

  IF v_order.id IS NULL THEN
    RAISE EXCEPTION 'Setup order not found: %', p_order_id;
  END IF;

  PERFORM 1 FROM public.sim_lines WHERE id=v_order.sim_line_id AND user_id=v_order.user_id
    AND phone_number=v_order.phone_number FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Owned matching line required'; END IF;
  PERFORM public.assert_setup_hold_bindings(v_order.id);
  IF v_order.plan='standard' AND (v_order.first_refill_hold_id IS NOT NULL OR v_order.first_refill_cost_usd<>0) THEN
    RAISE EXCEPTION 'Standard setup must not include a refill reservation'; END IF;
  IF v_order.status = 'active' THEN
    RETURN jsonb_build_object('success', true, 'status', 'active', 'already_captured', true);
  END IF;

  IF v_order.status NOT IN ('reserved','dispatching') OR v_order.plan NOT IN ('standard','premium') THEN
    RAISE EXCEPTION 'Invalid setup capture state';
  END IF;
  PERFORM 1 FROM public.sim_lines WHERE id=v_order.sim_line_id
    AND user_id=v_order.user_id AND phone_number=v_order.phone_number FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Owned matching line required'; END IF;
  IF v_order.annual_fee_usd>0 AND NOT EXISTS (
    SELECT 1 FROM public.wallet_holds WHERE id=v_order.annual_fee_hold_id
      AND user_id=v_order.user_id AND amount=v_order.annual_fee_usd
      AND status IN ('active','captured') AND order_type='plan_fee'
      AND order_reference_id IN ('setup_fee_'||v_order.id::text,'std_fallback_'||v_order.id::text)
      AND currency='USD' AND wallet_id=(SELECT id FROM public.wallets WHERE user_id=v_order.user_id AND currency='USD')
  ) THEN RAISE EXCEPTION 'Annual fee reservation required'; END IF;
  IF v_order.plan='premium' THEN
    SELECT * INTO v_execution FROM public.topup_executions
      WHERE wallet_hold_id=v_order.first_refill_hold_id AND user_id=v_order.user_id
        AND sim_line_id=v_order.sim_line_id AND status='success'
        AND reloadly_transaction_id IS NOT NULL ORDER BY created_at DESC LIMIT 1;
    IF v_execution.id IS NULL THEN RAISE EXCEPTION 'Confirmed initial delivery required'; END IF;
    PERFORM public.assert_instant_refill_reservation(v_execution.id,v_order.first_refill_hold_id);
    IF NOT EXISTS(SELECT 1 FROM public.wallet_holds h JOIN public.wallet_transactions t
      ON t.reference_id='hold_'||h.id::text WHERE h.id=v_order.first_refill_hold_id AND h.status='captured'
      AND t.type='topup_debit' AND t.status='completed' AND t.amount=v_order.first_refill_cost_usd
      AND t.wallet_id=h.wallet_id AND t.user_id=v_order.user_id
      AND t.metadata->>'execution_id'=v_execution.id::text
      AND t.metadata->>'provider_tx_id'=v_execution.reloadly_transaction_id) THEN
      RAISE EXCEPTION 'Settled initial delivery receipt required'; END IF;
    p_provider_tx_id:=v_execution.reloadly_transaction_id;
    IF NOT EXISTS (SELECT 1 FROM public.wallet_holds WHERE id=v_order.first_refill_hold_id
      AND user_id=v_order.user_id AND amount=v_order.first_refill_cost_usd
      AND status IN ('active','captured')) THEN RAISE EXCEPTION 'Refill reservation required'; END IF;
  END IF;

  -- 1. Capture annual fee hold
  IF v_order.annual_fee_hold_id IS NOT NULL THEN
    PERFORM public.capture_wallet_hold(
      v_order.annual_fee_hold_id,
      'plan_fee_debit',
      'Annual Protection Fee (' || v_order.plan || ')',
      jsonb_build_object('setup_order_id', p_order_id, 'sim_line_id',v_order.sim_line_id, 'plan', v_order.plan, 'order_type', 'plan_fee')
    );
  END IF;

  -- 2. Capture initial refill hold
  IF v_order.first_refill_hold_id IS NOT NULL THEN
    PERFORM public.capture_wallet_hold(
      v_order.first_refill_hold_id,
      'topup_debit',
      'Initial SIM Recharge (' || v_order.phone_number || ')',
      jsonb_build_object('setup_order_id', p_order_id, 'provider_tx_id', p_provider_tx_id, 'order_type', 'setup_refill')
    );
  END IF;

  v_line_id := v_order.sim_line_id;
  IF v_line_id IS NULL THEN
    -- Resilient fallback: link matching SIM line if user already created it
    SELECT id INTO v_line_id
    FROM public.sim_lines
    WHERE user_id = v_order.user_id AND phone_number = v_order.phone_number
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_line_id IS NOT NULL THEN
      UPDATE public.sim_setup_orders
      SET sim_line_id = v_line_id, updated_at = now()
      WHERE id = p_order_id;
    ELSE
      RAISE EXCEPTION 'Cannot activate setup order without an associated sim_line_id: %', p_order_id;
    END IF;
  END IF;

  IF v_order.plan='standard' THEN
    UPDATE public.scheduled_topups SET is_active=false,status='paused',updated_at=now()
      WHERE sim_line_id=v_line_id AND schedule_type<>'notify';
  END IF;
  -- 3. Activate SIM Line with valid carrier_status ('active')
  UPDATE public.sim_lines
  SET status = 'active',
      plan_type = v_order.plan,
      protection_tier = CASE WHEN v_order.plan = 'free' THEN 'basic' ELSE v_order.plan END,
      plan_expires_at = now() + INTERVAL '365 days',
      last_topup_at = CASE WHEN v_order.plan = 'premium' THEN now() ELSE last_topup_at END,
      updated_at = now()
  WHERE id = v_line_id;

  -- 4. Record plan payment with EXACT column names
  IF v_order.annual_fee_usd > 0 THEN
    INSERT INTO public.plan_payments (
      user_id, sim_line_id, capture_id, order_id, kind, gross_usd, net_usd,
      paypal_fee_usd, metadata, created_at
    ) VALUES (
      v_order.user_id,
      v_line_id,
      COALESCE(v_order.annual_fee_hold_id::text, 'setup_' || p_order_id::text),
      p_order_id::text,
      'plan',
      v_order.annual_fee_usd,
      v_order.annual_fee_usd,
      0.00,
      jsonb_build_object('billing_model', 'pay_per_refill', 'plan', v_order.plan, 'setup_order_id', p_order_id),
      now()
    );
  END IF;

  -- 5. Calculate cadence and schedule next occurrences
  IF v_order.carrier_rule_id IS NOT NULL THEN
    SELECT * INTO v_rule FROM public.carrier_rules WHERE id = v_order.carrier_rule_id;
  ELSE
    SELECT cr.* INTO v_rule
    FROM public.sim_lines sl
    JOIN public.carrier_rules cr ON cr.id = sl.carrier_rule_id OR cr.carrier_id = sl.carrier_id
    WHERE sl.id = v_line_id
    LIMIT 1;
  END IF;

  IF v_rule.id IS NOT NULL THEN
    v_interval_days := public.refill_interval_days(v_rule.inactivity_limit_days, v_rule.refill_interval_days_override);
    IF v_interval_days IS NULL OR v_interval_days < 1 THEN
      v_interval_days := 30;
    END IF;

    -- Resolve valid positive notify amount
    v_notify_amount := COALESCE(
      NULLIF(v_order.first_refill_cost_usd, 0),
      NULLIF(v_rule.minimum_topup_amount, 0),
      NULLIF(v_rule.recommended_topup_amount, 0),
      1.00
    );

    -- 5a. Always create 'notify' schedule for user alert reminders
    INSERT INTO public.scheduled_topups (
      user_id, sim_line_id, amount, currency, frequency_days,
      next_execution_at, is_active, status, schedule_type
    ) VALUES (
      v_order.user_id,
      v_line_id,
      v_notify_amount,
      'USD',
      v_interval_days,
      now() + (v_interval_days || ' days')::interval,
      true,
      'active',
      'notify'
    )
    ON CONFLICT (sim_line_id, schedule_type)
    DO UPDATE SET
      amount = EXCLUDED.amount,
      frequency_days = EXCLUDED.frequency_days,
      next_execution_at = EXCLUDED.next_execution_at,
      is_active = true,
      status = 'active',
      updated_at = now();

    -- 5b. For Premium lines, look up execution snapshot to establish a coherent pricing contract
    IF v_order.plan = 'premium' THEN
      SELECT * INTO v_execution
      FROM public.topup_executions
      WHERE wallet_hold_id = v_order.first_refill_hold_id
      ORDER BY created_at DESC
      LIMIT 1;

      IF v_execution.id IS NOT NULL THEN
        v_offer_id := v_execution.offer_id;
        v_offer_value := v_execution.offer_value;
        v_provider := v_execution.api_provider;
        v_base_cost := v_execution.base_cost_usd;
        v_app_fee := COALESCE(
          v_execution.app_fee_usd,
          round(v_order.first_refill_cost_usd - COALESCE(v_execution.base_cost_usd, 0), 2)
        );
        v_refill_amount := v_order.first_refill_cost_usd;
        v_intent_kind := COALESCE(v_execution.intent_kind, 'exact_airtime');
        v_target_local_val := v_execution.target_local_value;
        v_target_local_cur := v_execution.target_local_currency;
      ELSE
        v_offer_id := v_rule.offer_id;
        v_offer_value := v_rule.offer_value;
        v_refill_amount := COALESCE(NULLIF(v_order.first_refill_cost_usd, 0), v_rule.minimum_topup_amount, 1.00);
      END IF;

      -- Resolve active fee rule version
      SELECT version INTO v_fee_rule_ver
      FROM public.app_fee_rules
      WHERE appfees_item = 'refills'
      ORDER BY (status = 'published') DESC, version DESC
      LIMIT 1;

      -- Fallback lookup for target local currency and value if missing
      IF (v_target_local_val IS NULL OR v_target_local_cur IS NULL) AND v_offer_id IS NOT NULL THEN
        SELECT source_amount_native, source_send_currency
        INTO v_target_local_val, v_target_local_cur
        FROM public.provider_offers
        WHERE offer_code = v_offer_id
          AND (v_rule.carrier_id IS NULL OR carrier_id = v_rule.carrier_id)
        ORDER BY is_active DESC, updated_at DESC
        LIMIT 1;
      END IF;

      INSERT INTO public.scheduled_topups (
        user_id, sim_line_id, amount, base_cost_usd, app_fee_usd, max_authorized_usd,
        currency, frequency_days, next_execution_at, is_active, status, schedule_type,
        offer_id, offer_value, preferred_provider, pricing_tier, intent_kind,
        target_local_value, target_local_currency, engine_version, fee_rule_version
      ) VALUES (
        v_order.user_id,
        v_line_id,
        v_refill_amount,
        v_base_cost,
        v_app_fee,
        v_refill_amount,
        'USD',
        v_interval_days,
        now() + (v_interval_days || ' days')::interval,
        true,
        'active',
        'refill_mini',
        v_offer_id,
        v_offer_value,
        v_provider,
        'premium',
        v_intent_kind,
        v_target_local_val,
        v_target_local_cur,
        2,
        COALESCE(v_fee_rule_ver, 1)
      )
      ON CONFLICT (sim_line_id, schedule_type)
      DO UPDATE SET
        amount = EXCLUDED.amount,
        base_cost_usd = EXCLUDED.base_cost_usd,
        app_fee_usd = EXCLUDED.app_fee_usd,
        max_authorized_usd = EXCLUDED.max_authorized_usd,
        currency = EXCLUDED.currency,
        frequency_days = EXCLUDED.frequency_days,
        next_execution_at = EXCLUDED.next_execution_at,
        is_active = true,
        status = 'active',
        offer_id = EXCLUDED.offer_id,
        offer_value = EXCLUDED.offer_value,
        preferred_provider = EXCLUDED.preferred_provider,
        pricing_tier = EXCLUDED.pricing_tier,
        intent_kind = EXCLUDED.intent_kind,
        target_local_value = EXCLUDED.target_local_value,
        target_local_currency = EXCLUDED.target_local_currency,
        engine_version = EXCLUDED.engine_version,
        fee_rule_version = EXCLUDED.fee_rule_version,
        updated_at = now();
    END IF;
  END IF;

  UPDATE public.sim_setup_orders
  SET status = 'active',
      provider_tx_id = COALESCE(p_provider_tx_id, provider_tx_id),
      updated_at = now()
  WHERE id = p_order_id;

  RETURN jsonb_build_object(
    'success', true,
    'status', 'active',
    'sim_line_id', v_line_id,
    'plan', v_order.plan
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.capture_sim_setup_holds(uuid,text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.capture_sim_setup_holds(uuid,text) TO service_role;


DROP FUNCTION IF EXISTS public.finalize_sim_setup_order(uuid,text) RESTRICT;
CREATE OR REPLACE FUNCTION public.finalize_sim_setup_order(
  p_order_id uuid, p_sim_line_id uuid DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_order public.sim_setup_orders;
  v_execution public.topup_executions;
  v_line_id uuid;
  v_service boolean := coalesce(auth.role(),'')='service_role';
BEGIN
  IF auth.uid() IS NULL AND NOT v_service THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_order FROM public.sim_setup_orders WHERE id=p_order_id FOR UPDATE;
  IF v_order.id IS NULL OR (NOT v_service AND v_order.user_id IS DISTINCT FROM auth.uid()) THEN
    RAISE EXCEPTION 'Setup order unavailable' USING ERRCODE='42501';
  END IF;
  IF p_sim_line_id IS NOT NULL AND v_order.sim_line_id IS NOT NULL
    AND p_sim_line_id<>v_order.sim_line_id THEN
    RAISE EXCEPTION 'Setup order is bound to another line' USING ERRCODE='22023';
  END IF;
  v_line_id:=coalesce(v_order.sim_line_id,p_sim_line_id);
  IF v_line_id IS NULL THEN
    SELECT id INTO v_line_id FROM public.sim_lines
    WHERE user_id=v_order.user_id AND phone_number=v_order.phone_number
    ORDER BY created_at DESC LIMIT 1;
  END IF;
  PERFORM 1 FROM public.sim_lines WHERE id=v_line_id AND user_id=v_order.user_id
    AND phone_number=v_order.phone_number FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Owned matching SIM line required' USING ERRCODE='42501'; END IF;
  -- Authorization and binding checks precede every idempotent return.
  IF v_order.status='active' THEN
    RETURN jsonb_build_object('success',true,'status','active','plan',v_order.plan,'sim_line_id',v_line_id);
  END IF;
  IF v_order.status IN ('failed','cancelled') THEN
    RETURN jsonb_build_object('success',false,'status',v_order.status);
  END IF;
  IF v_order.status NOT IN ('reserved','dispatching') THEN
    RAISE EXCEPTION 'Setup order is not reserved' USING ERRCODE='22023';
  END IF;
  UPDATE public.sim_setup_orders SET sim_line_id=v_line_id,updated_at=now() WHERE id=p_order_id;
  IF v_order.plan='standard' THEN RETURN public.capture_sim_setup_holds(p_order_id); END IF;
  IF v_order.plan<>'premium' THEN RAISE EXCEPTION 'Unsupported finalization plan'; END IF;
  SELECT * INTO v_execution FROM public.topup_executions
    WHERE wallet_hold_id=v_order.first_refill_hold_id AND user_id=v_order.user_id
      AND sim_line_id=v_line_id ORDER BY created_at DESC LIMIT 1 FOR UPDATE;
  IF v_execution.status='success' AND v_execution.reloadly_transaction_id IS NOT NULL THEN
    RETURN public.capture_sim_setup_holds(p_order_id,v_execution.reloadly_transaction_id);
  END IF;
  IF v_execution.status IN ('failed','cancelled') AND v_execution.reloadly_transaction_id IS NULL
    AND NOT coalesce(v_execution.carrier_in_flight,false) AND NOT EXISTS(
      SELECT 1 FROM public.wallet_holds WHERE id=v_order.first_refill_hold_id
        AND (carrier_in_flight OR recovery_contract_version<1)
    ) THEN RETURN public.release_sim_setup_holds(p_order_id,'Initial delivery failed before provider submission'); END IF;
  -- Failure may be an ambiguous submission; only cancellation/recovery decides
  -- when reservations can be released. Never release based on status alone.
  RETURN jsonb_build_object('success',false,'status',v_order.status,'pending',true);
END;
$$;
REVOKE ALL ON FUNCTION public.finalize_sim_setup_order(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.finalize_sim_setup_order(uuid,uuid) TO authenticated,service_role;


CREATE OR REPLACE FUNCTION public.release_sim_setup_holds(p_order_id uuid,p_reason text DEFAULT 'Recharge failed or cancelled')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE o public.sim_setup_orders;
BEGIN
  SELECT * INTO o FROM public.sim_setup_orders WHERE id=p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Setup unavailable'; END IF;
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
REVOKE ALL ON FUNCTION public.release_sim_setup_holds(uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.release_sim_setup_holds(uuid,text) TO service_role;


CREATE OR REPLACE FUNCTION public.fallback_sim_setup_to_reminders(p_order_id uuid,p_sim_line_id uuid,p_fallback_plan text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE o public.sim_setup_orders; v_fee numeric; v_hold uuid; v_available numeric; v_days integer;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  SELECT * INTO o FROM public.sim_setup_orders WHERE id=p_order_id AND user_id=auth.uid() FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Setup unavailable' USING ERRCODE='42501'; END IF;
  PERFORM 1 FROM public.sim_lines WHERE id=p_sim_line_id AND user_id=o.user_id AND phone_number=o.phone_number FOR UPDATE;
  IF NOT FOUND OR (o.sim_line_id IS NOT NULL AND o.sim_line_id<>p_sim_line_id) THEN
    RAISE EXCEPTION 'Matching owned SIM required' USING ERRCODE='42501'; END IF;
  IF p_fallback_plan IS NULL OR p_fallback_plan NOT IN ('free','standard') THEN RAISE EXCEPTION 'Invalid fallback plan'; END IF;
  IF o.status='active' THEN
    IF o.plan=p_fallback_plan THEN RETURN jsonb_build_object('success',true,'plan',o.plan,'already_captured',true); END IF;
    RAISE EXCEPTION 'Active setup cannot be replaced';
  END IF;
  PERFORM public.assert_setup_hold_bindings(o.id);
  PERFORM 1 FROM public.topup_executions WHERE wallet_hold_id=o.first_refill_hold_id FOR UPDATE;
  PERFORM 1 FROM public.wallets WHERE user_id=o.user_id FOR UPDATE;
  IF EXISTS(SELECT 1 FROM public.wallet_holds WHERE id IN (o.annual_fee_hold_id,o.first_refill_hold_id)
    AND status='active' AND recovery_contract_version<1) THEN
    RAISE EXCEPTION 'Legacy setup requires reconciliation'; END IF;
  IF o.status='dispatching' OR o.provider_tx_id IS NOT NULL OR EXISTS(
    SELECT 1 FROM public.topup_executions WHERE wallet_hold_id=o.first_refill_hold_id
      AND (status IN ('processing','success') OR reloadly_transaction_id IS NOT NULL OR carrier_in_flight)
  ) OR EXISTS(SELECT 1 FROM public.wallet_holds WHERE id IN (o.annual_fee_hold_id,o.first_refill_hold_id)
      AND (carrier_in_flight OR status='captured')) THEN
    RAISE EXCEPTION 'Setup requires delivery reconciliation before fallback';
  END IF;
  -- Lock the wallet before releasing or replacing reservations.
  PERFORM 1 FROM public.wallets WHERE user_id=o.user_id FOR UPDATE;
  PERFORM public.release_wallet_hold(id,'Switching to reminder protection') FROM public.wallet_holds
    WHERE id IN (o.annual_fee_hold_id,o.first_refill_hold_id) AND status='active';
  UPDATE public.topup_executions SET status='cancelled',failure_reason='Reminder protection selected',updated_at=now()
    WHERE wallet_hold_id=o.first_refill_hold_id AND status IN ('pending','routing','awaiting_funds');
  IF p_fallback_plan='standard' THEN
    v_fee:=public.membership_fee_usd('standard');
    SELECT w.balance-coalesce((SELECT sum(amount) FROM public.wallet_holds WHERE wallet_id=w.id AND status='active'),0)
      INTO v_available FROM public.wallets w WHERE w.user_id=o.user_id;
    IF v_available IS NULL OR v_available<v_fee THEN
      UPDATE public.sim_setup_orders SET plan='standard',status='awaiting_funds',sim_line_id=p_sim_line_id,
        annual_fee_usd=v_fee,first_refill_cost_usd=0,total_charge_usd=v_fee,annual_fee_hold_id=NULL,first_refill_hold_id=NULL,updated_at=now() WHERE id=o.id;
      RETURN jsonb_build_object('success',false,'code','insufficient_funds','available_balance',coalesce(v_available,0),'required',v_fee);
    END IF;
    IF v_fee>0 THEN v_hold:=public.reserve_wallet_funds(o.user_id,v_fee,'plan_fee','std_fallback_'||o.id); END IF;
    UPDATE public.sim_setup_orders SET plan='standard',status='reserved',sim_line_id=p_sim_line_id,
      annual_fee_usd=v_fee,first_refill_cost_usd=0,total_charge_usd=v_fee,
      annual_fee_hold_id=v_hold,first_refill_hold_id=NULL,updated_at=now() WHERE id=o.id;
    RETURN public.capture_sim_setup_holds(o.id);
  END IF;
  SELECT public.refill_interval_days(inactivity_limit_days,refill_interval_days_override)
    INTO v_days FROM public.carrier_rules WHERE id=o.carrier_rule_id;
  INSERT INTO public.scheduled_topups(user_id,sim_line_id,amount,currency,frequency_days,
    next_execution_at,is_active,status,schedule_type)
    VALUES(o.user_id,p_sim_line_id,coalesce(nullif(o.first_refill_cost_usd,0),1),'USD',
      coalesce(v_days,30),now()+make_interval(days=>coalesce(v_days,30)),true,'active','notify')
    ON CONFLICT(sim_line_id,schedule_type) DO UPDATE SET is_active=true,status='active',updated_at=now();
  UPDATE public.sim_lines SET plan_type='free',protection_tier='basic',plan_expires_at=NULL,updated_at=now() WHERE id=p_sim_line_id;
  UPDATE public.scheduled_topups SET is_active=false,status='paused',updated_at=now()
    WHERE sim_line_id=p_sim_line_id AND schedule_type<>'notify';
  UPDATE public.sim_setup_orders SET plan='free',status='active',sim_line_id=p_sim_line_id,annual_fee_usd=0,
    first_refill_cost_usd=0,total_charge_usd=0,annual_fee_hold_id=NULL,first_refill_hold_id=NULL,updated_at=now() WHERE id=o.id;
  RETURN jsonb_build_object('success',true,'plan','free','expires_at',NULL);
END;
$$;
REVOKE ALL ON FUNCTION public.fallback_sim_setup_to_reminders(uuid,uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.fallback_sim_setup_to_reminders(uuid,uuid,text) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.dispatch_sim_setup_verification(p_order_id uuid, p_sim_line_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_user_id          UUID := auth.uid();
  v_order            RECORD;
  v_line             RECORD;
  v_rule             RECORD;
  v_offer            RECORD;
  v_execution_id     UUID;
  v_offer_id         TEXT;
  v_offer_value      BIGINT;
  v_provider         TEXT;
  v_base_cost        NUMERIC;
  v_qualifying       NUMERIC;
  v_target_local_val NUMERIC := NULL;
  v_target_local_cur TEXT := NULL;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;

  SELECT * INTO v_order
  FROM public.sim_setup_orders
  WHERE id = p_order_id AND user_id = v_user_id FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'Order not found'; END IF;

  IF v_order.status NOT IN ('reserved', 'dispatching') THEN
    RAISE EXCEPTION 'Order must be reserved to dispatch verification, currently: %', v_order.status;
  END IF;

  SELECT * INTO v_line
  FROM public.sim_lines
  WHERE id = p_sim_line_id AND user_id = v_user_id AND phone_number=v_order.phone_number FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'SIM line not found'; END IF;

  IF v_order.plan<>'premium' OR v_order.first_refill_hold_id IS NULL
    OR (v_order.sim_line_id IS NOT NULL AND v_order.sim_line_id<>p_sim_line_id) THEN
    RAISE EXCEPTION 'Setup order is bound to another line or has no refill'; END IF;

  -- Link line to order
  UPDATE public.sim_setup_orders
  SET sim_line_id = p_sim_line_id,
      status = 'dispatching',
      updated_at = now()
  WHERE id = p_order_id;

  -- If an execution already exists for this order, return it
  SELECT id INTO v_execution_id
  FROM public.topup_executions
  WHERE wallet_hold_id = v_order.first_refill_hold_id
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_execution_id IS NOT NULL THEN
    PERFORM public.assert_instant_refill_reservation(v_execution_id,v_order.first_refill_hold_id);
    RETURN jsonb_build_object('success', true, 'execution_id', v_execution_id, 'status', 'dispatching');
  END IF;

  -- Resolve carrier rule & offer
  IF v_order.carrier_rule_id IS NOT NULL THEN
    SELECT * INTO v_rule FROM public.carrier_rules WHERE id = v_order.carrier_rule_id;
  ELSE
    SELECT * INTO v_rule FROM public.carrier_rules WHERE carrier_id = v_line.carrier_id ORDER BY created_at DESC LIMIT 1;
  END IF;

  IF FOUND THEN
    v_qualifying := COALESCE(v_rule.validity_qualifying_topup_amount, v_rule.minimum_topup_amount);
    
    -- Canonical supplier offer lookup
    SELECT * INTO v_offer
    FROM public.carrier_refill_offer(v_line.carrier_id, v_qualifying);

    IF v_offer.offer_code IS NOT NULL THEN
      v_offer_id := v_offer.offer_code;
      v_offer_value := CASE WHEN v_offer.offer_value IS NOT NULL THEN v_offer.offer_value::bigint ELSE NULL END;
      v_provider := v_offer.provider_code;
      v_base_cost := v_offer.price_usd;

      SELECT source_send_currency, source_amount_native
      INTO v_target_local_cur, v_target_local_val
      FROM public.provider_offers
      WHERE offer_code = v_offer_id AND carrier_id = v_line.carrier_id AND is_active
      LIMIT 1;
    ELSE
      v_offer_id := v_rule.offer_id;
      v_offer_value := v_rule.offer_value;
      SELECT m.provider INTO v_provider
      FROM public.carrier_provider_map m
      WHERE m.carrier_id = v_line.carrier_id AND m.is_primary AND m.is_enabled;
      v_base_cost := v_rule.minimum_topup_amount;
    END IF;
  END IF;

  IF v_base_cost IS NULL THEN
    v_base_cost := v_order.first_refill_cost_usd;
  END IF;

  INSERT INTO public.topup_executions (
    sim_line_id,
    user_id,
    amount,
    base_cost_usd,
    currency,
    execution_type,
    status,
    wallet_hold_id,
    funding_kind,
    offer_id,
    offer_value,
    api_provider,
    attempted_providers,
    fulfillment_gateway,
    target_local_value,
    target_local_currency,
    engine_version,
    intent_kind,
    created_at
  ) VALUES (
    p_sim_line_id,
    v_user_id,
    v_order.first_refill_cost_usd,
    v_base_cost,
    'USD',
    'refill_instant',
    'routing',
    v_order.first_refill_hold_id,
    'setup_hold',
    v_offer_id,
    v_offer_value,
    v_provider,
    CASE WHEN v_provider IS NOT NULL THEN ARRAY[v_provider] ELSE NULL END,
    'API',
    v_target_local_val,
    v_target_local_cur,
    2,
    'exact_airtime',
    now()
  ) RETURNING id INTO v_execution_id;

  PERFORM public.assert_instant_refill_reservation(v_execution_id,v_order.first_refill_hold_id);
  RETURN jsonb_build_object(
    'success', true,
    'execution_id', v_execution_id,
    'status', 'dispatching'
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.dispatch_sim_setup_verification(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dispatch_sim_setup_verification(uuid, uuid) TO authenticated, service_role;


REVOKE ALL ON FUNCTION public.lock_refill_setup_order(uuid),public.assert_instant_refill_reservation(uuid,uuid)
  FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.begin_refill_submission(uuid,uuid),
  public.settle_instant_refill_execution(uuid,text,uuid,text,text,text,jsonb),
  public.fail_instant_refill_before_submission(uuid,uuid,text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.begin_refill_submission(uuid,uuid),
  public.settle_instant_refill_execution(uuid,text,uuid,text,text,text,jsonb),
  public.fail_instant_refill_before_submission(uuid,uuid,text) TO service_role;

CREATE OR REPLACE FUNCTION public.cancel_sim_setup_order(p_order_id uuid,p_reason text DEFAULT 'Cancelled by user')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE o public.sim_setup_orders;
BEGIN
  SELECT * INTO o FROM public.sim_setup_orders WHERE id=p_order_id FOR UPDATE;
  IF o.id IS NULL OR auth.uid() IS NULL OR o.user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Setup unavailable' USING ERRCODE='42501'; END IF;
  IF o.status='cancelled' THEN RETURN jsonb_build_object('success',true,'status','cancelled'); END IF;
  PERFORM public.release_sim_setup_holds(o.id,p_reason);
  UPDATE public.topup_executions SET status='cancelled',failure_reason=p_reason,updated_at=now()
    WHERE wallet_hold_id=o.first_refill_hold_id AND status IN ('pending','routing','awaiting_funds');
  UPDATE public.sim_setup_orders SET status='cancelled',updated_at=now() WHERE id=o.id;
  RETURN jsonb_build_object('success',true,'status','cancelled');
END;
$$;
REVOKE ALL ON FUNCTION public.cancel_sim_setup_order(uuid,text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.cancel_sim_setup_order(uuid,text) TO authenticated;
REVOKE ALL ON FUNCTION public.assert_setup_hold_bindings(uuid) FROM PUBLIC,anon,authenticated,service_role;

NOTIFY pgrst, 'reload schema';
COMMIT;
