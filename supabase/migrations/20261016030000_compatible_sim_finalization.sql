BEGIN;

-- RESTRICT deliberately fails deployment if an unreviewed dependency exists.
DROP FUNCTION public.finalize_sim_setup_order(uuid,text);

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

-- The capture helper is replaced below in this same transaction.
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
  ) THEN RAISE EXCEPTION 'Annual fee reservation required'; END IF;
  IF v_order.plan='premium' THEN
    SELECT * INTO v_execution FROM public.topup_executions
      WHERE wallet_hold_id=v_order.first_refill_hold_id AND user_id=v_order.user_id
        AND sim_line_id=v_order.sim_line_id AND status='success'
        AND reloadly_transaction_id IS NOT NULL ORDER BY created_at DESC LIMIT 1;
    IF v_execution.id IS NULL THEN RAISE EXCEPTION 'Confirmed initial delivery required'; END IF;
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

CREATE OR REPLACE FUNCTION public.release_sim_setup_holds(p_order_id uuid,p_reason text DEFAULT 'Recharge failed or cancelled')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE o public.sim_setup_orders;
BEGIN
  SELECT * INTO o FROM public.sim_setup_orders WHERE id=p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Setup unavailable'; END IF;
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

NOTIFY pgrst, 'reload schema';
COMMIT;
