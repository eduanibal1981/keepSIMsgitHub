-- Migration: 20260915150000_enrich_setup_refill_metadata_and_activity.sql
-- Description:
--   1. Update trg_fn_log_topup_activity to include funding_kind in line_activity_log metadata.
--   2. Update dispatch_sim_setup_verification to resolve and record target_local_value and target_local_currency.
--   3. Update capture_sim_setup_holds to populate fee_rule_version, target_local_value, and target_local_currency on scheduled_topups.
--   4. Backfill target_local_value, target_local_currency, and fee_rule_version on the test line mini-refill schedule.

-- 1. Expose funding_kind in line_activity_log
CREATE OR REPLACE FUNCTION public.trg_fn_log_topup_activity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_event_type TEXT;
  v_metadata JSONB;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_event_type := CASE 
      WHEN NEW.retry_of IS NOT NULL THEN 'topup_retry_queued'
      ELSE 'topup_requested'
    END;

    v_metadata := jsonb_build_object(
      'amount', NEW.amount,
      'base_cost_usd', NEW.base_cost_usd,
      'execution_id', NEW.id,
      'execution_type', NEW.execution_type,
      'funding_kind', NEW.funding_kind,
      'provider', COALESCE(NEW.api_provider, 'zendit'),
      'offer_id', NEW.offer_id,
      'refill_channel', NEW.refill_channel
    );

    INSERT INTO public.line_activity_log (
      sim_line_id, user_id, event_type, description, metadata, created_at
    ) VALUES (
      NEW.sim_line_id, NEW.user_id, v_event_type, NULL, v_metadata, clock_timestamp()
    );

  ELSIF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    IF NEW.status = 'success' THEN
      v_event_type := 'topup_success';
      v_metadata := jsonb_build_object(
        'amount', NEW.amount,
        'execution_id', NEW.id,
        'execution_type', NEW.execution_type,
        'funding_kind', NEW.funding_kind,
        'provider', COALESCE(NEW.api_provider, 'zendit'),
        'transaction_id', NEW.reloadly_transaction_id,
        'refill_channel', NEW.refill_channel
      );
    ELSIF NEW.status = 'failed' THEN
      v_event_type := 'topup_failed';
      v_metadata := jsonb_build_object(
        'amount', NEW.amount,
        'execution_id', NEW.id,
        'execution_type', NEW.execution_type,
        'funding_kind', NEW.funding_kind,
        'provider', COALESCE(NEW.api_provider, 'zendit'),
        'failure_reason', COALESCE(NEW.failure_reason, 'Execution failed'),
        'refill_channel', NEW.refill_channel
      );
    ELSIF NEW.status = 'refunded' THEN
      v_event_type := 'topup_refunded';
      v_metadata := jsonb_build_object(
        'amount', NEW.amount,
        'execution_id', NEW.id,
        'execution_type', NEW.execution_type,
        'funding_kind', NEW.funding_kind,
        'refund_reason', COALESCE(NEW.failure_reason, 'Wallet refunded')
      );
    ELSIF NEW.status = 'cancelled' THEN
      v_event_type := 'topup_cancelled';
      v_metadata := jsonb_build_object(
        'amount', NEW.amount,
        'execution_id', NEW.id,
        'execution_type', NEW.execution_type,
        'funding_kind', NEW.funding_kind
      );
    ELSE
      RETURN NEW;
    END IF;

    INSERT INTO public.line_activity_log (
      sim_line_id, user_id, event_type, description, metadata, created_at
    ) VALUES (
      NEW.sim_line_id, NEW.user_id, v_event_type, NULL, v_metadata, clock_timestamp()
    );
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.trg_fn_log_topup_activity() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.trg_fn_log_topup_activity() TO service_role;

-- 2. Update dispatch_sim_setup_verification to capture local amount/currency
CREATE OR REPLACE FUNCTION public.dispatch_sim_setup_verification(p_order_id uuid, p_sim_line_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
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

  RETURN jsonb_build_object(
    'success', true,
    'execution_id', v_execution_id,
    'status', 'dispatching'
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.dispatch_sim_setup_verification(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dispatch_sim_setup_verification(uuid, uuid) TO authenticated, service_role;

-- 3. Update capture_sim_setup_holds to populate fee_rule_version and fallback target values
CREATE OR REPLACE FUNCTION public.capture_sim_setup_holds(
  p_order_id UUID,
  p_provider_tx_id TEXT DEFAULT NULL::TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
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

  -- 1. Capture annual fee hold
  IF v_order.annual_fee_hold_id IS NOT NULL THEN
    PERFORM public.capture_wallet_hold(
      v_order.annual_fee_hold_id,
      'plan_fee_debit',
      'Annual Protection Fee (' || v_order.plan || ')',
      jsonb_build_object('setup_order_id', p_order_id, 'plan', v_order.plan, 'order_type', 'plan_fee')
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

REVOKE ALL ON FUNCTION public.capture_sim_setup_holds(UUID, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.capture_sim_setup_holds(UUID, TEXT) TO service_role;

-- 4. Backfill target_local_value, target_local_currency, fee_rule_version on test mini refill schedules
UPDATE public.scheduled_topups s
SET target_local_value = COALESCE(s.target_local_value, o.source_amount_native),
    target_local_currency = COALESCE(s.target_local_currency, o.source_send_currency),
    fee_rule_version = COALESCE(s.fee_rule_version, 1),
    updated_at = now()
FROM public.provider_offers o
WHERE s.offer_id = o.offer_code
  AND s.schedule_type IN ('refill_mini', 'refill_custom')
  AND (s.target_local_value IS NULL OR s.target_local_currency IS NULL OR s.fee_rule_version IS NULL);
