-- ============================================================================
-- Migration: Fix dispatch_sim_setup_verification provider & base_cost + capture_sim_setup_holds carrier_status
-- ============================================================================

CREATE OR REPLACE FUNCTION public.route_topup_execution()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE 
  v_gateway VARCHAR; 
  v_api_provider text;
BEGIN
  IF NEW.status IN ('pending', 'pending_payment', 'routing') THEN
    SELECT ca.fulfillment_gateway, m.provider INTO v_gateway, v_api_provider
    FROM public.sim_lines sl
    JOIN public.carriers ca ON sl.carrier_id = ca.id
    LEFT JOIN public.carrier_provider_map m ON m.carrier_id = ca.id AND m.is_primary
    WHERE sl.id = NEW.sim_line_id;

    IF NEW.fulfillment_gateway IS NULL THEN
      IF v_gateway IS NULL THEN
        SELECT config_value INTO v_gateway FROM public.system_configs
         WHERE config_key = 'ACTIVE_FULFILLMENT_METHOD' LIMIT 1;
        IF v_gateway IS NULL THEN v_gateway := 'MANUAL'; END IF;
      END IF;

      IF v_gateway = 'TASKER_SCRIPT' AND NEW.execution_type = 'refill_instant' THEN 
        v_gateway := 'API'; 
      END IF;

      IF v_gateway = 'TASKER_SCRIPT' AND NOT EXISTS (
        SELECT 1 FROM public.sim_lines sl2
        JOIN public.refill_scripts rs ON rs.carrier_id = sl2.carrier_id
        WHERE sl2.id = NEW.sim_line_id AND rs.is_enabled
          AND NEW.execution_type = ANY (rs.allowed_execution_types)) THEN
        v_gateway := 'API';
      END IF;

      NEW.fulfillment_gateway := v_gateway;
    END IF;

    -- Always populate api_provider if not already set
    NEW.api_provider := COALESCE(NEW.api_provider, v_api_provider);

    IF NEW.execution_type = 'refill_instant' AND NEW.status = 'pending' THEN 
      NEW.status := 'routing'; 
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.dispatch_sim_setup_verification(p_order_id uuid, p_sim_line_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id       UUID := auth.uid();
  v_order         RECORD;
  v_line          RECORD;
  v_rule          RECORD;
  v_offer         RECORD;
  v_execution_id  UUID;
  v_offer_id      TEXT;
  v_offer_value   BIGINT;
  v_provider      TEXT;
  v_base_cost     NUMERIC;
  v_qualifying    NUMERIC;
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
  WHERE id = p_sim_line_id AND user_id = v_user_id;

  IF NOT FOUND THEN RAISE EXCEPTION 'SIM line not found'; END IF;

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
    now()
  ) RETURNING id INTO v_execution_id;

  RETURN jsonb_build_object(
    'success', true,
    'execution_id', v_execution_id,
    'status', 'dispatching'
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.capture_sim_setup_holds(p_order_id uuid, p_provider_tx_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_order         RECORD;
  v_line_id       UUID;
  v_interval_days INTEGER := 30;
  v_rule          RECORD;
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

  -- 1. Capture annual fee hold
  IF v_order.annual_fee_hold_id IS NOT NULL THEN
    PERFORM public.capture_wallet_hold(
      v_order.annual_fee_hold_id,
      'plan_fee_debit',
      'Annual Protection Fee (' || v_order.plan || ')',
      jsonb_build_object('setup_order_id', p_order_id, 'plan', v_order.plan)
    );
  END IF;

  -- 2. Capture initial refill hold
  IF v_order.first_refill_hold_id IS NOT NULL THEN
    PERFORM public.capture_wallet_hold(
      v_order.first_refill_hold_id,
      'topup_debit',
      'Initial SIM Recharge (' || v_order.phone_number || ')',
      jsonb_build_object('setup_order_id', p_order_id, 'provider_tx_id', p_provider_tx_id)
    );
  END IF;

  v_line_id := v_order.sim_line_id;
  IF v_line_id IS NULL THEN
    RAISE EXCEPTION 'Cannot activate setup order without an associated sim_line_id: %', p_order_id;
  END IF;

  -- 3. Activate SIM Line with valid carrier_status ('active')
  UPDATE public.sim_lines
  SET status = 'active',
      plan_type = v_order.plan,
      protection_tier = CASE WHEN v_order.plan = 'free' THEN 'basic' ELSE v_order.plan END,
      plan_expires_at = now() + INTERVAL '365 days',
      last_topup_at = CASE WHEN v_order.plan = 'premium' THEN now() ELSE last_topup_at END,
      carrier_verified_at = now(),
      is_carrier_verified = true,
      carrier_status = 'active',
      verification_status = 'verified',
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

  -- 5. Calculate cadence and schedule single next occurrence for Premium
  IF v_order.plan = 'premium' AND v_order.carrier_rule_id IS NOT NULL THEN
    SELECT * INTO v_rule FROM public.carrier_rules WHERE id = v_order.carrier_rule_id;
    IF FOUND THEN
      v_interval_days := public.refill_interval_days(v_rule.inactivity_limit_days, v_rule.refill_interval_days_override);
      IF v_interval_days IS NULL OR v_interval_days < 1 THEN
        v_interval_days := 30;
      END IF;

      INSERT INTO public.scheduled_topups (
        user_id, sim_line_id, amount, currency, frequency_days,
        next_execution_at, is_active, status, schedule_type, offer_id, offer_value
      ) VALUES (
        v_order.user_id,
        v_line_id,
        v_order.first_refill_cost_usd,
        'USD',
        v_interval_days,
        now() + (v_interval_days || ' days')::interval,
        true,
        'active',
        'refill_custom',
        v_rule.offer_id,
        v_rule.offer_value
      );
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
