-- Migration: 20260915130000_fix_setup_schedule_pricing_and_queue_sync.sql
-- Description:
--   1. Update capture_sim_setup_holds to populate base_cost_usd, app_fee_usd, amount,
--      max_authorized_usd, preferred_provider, offer_id, and intent_kind from the setup execution snapshot.
--   2. Update trg_fn_sync_custom_refill_queue so that missing base_cost_usd does not cause
--      already-inclusive amounts to be treated as supplier base cost and marked up again.
--   3. Safely repair the unsubmitted future pending execution (c3dad031-c9dc-48d0-8d69-f5cae8fe6c97)
--      and its parent schedule (190b8d8d-a61e-4c1b-a307-68513f9a903f) to the verified Ding STC route.

-- 1. UPDATE capture_sim_setup_holds
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

      INSERT INTO public.scheduled_topups (
        user_id, sim_line_id, amount, base_cost_usd, app_fee_usd, max_authorized_usd,
        currency, frequency_days, next_execution_at, is_active, status, schedule_type,
        offer_id, offer_value, preferred_provider, pricing_tier, intent_kind,
        target_local_value, target_local_currency, engine_version
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
        2
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

-- 2. UPDATE trg_fn_sync_custom_refill_queue
CREATE OR REPLACE FUNCTION public.trg_fn_sync_custom_refill_queue()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  -- Only process custom and mini automated refills; ignore reminders (notify)
  IF NEW.schedule_type NOT IN ('refill_custom', 'refill_mini') THEN
    RETURN NEW;
  END IF;

  -- 1. No-op check: if nothing changed at all, exit immediately
  IF TG_OP = 'UPDATE'
     AND NEW.amount IS NOT DISTINCT FROM OLD.amount
     AND NEW.currency IS NOT DISTINCT FROM OLD.currency
     AND NEW.next_execution_at IS NOT DISTINCT FROM OLD.next_execution_at
     AND NEW.is_active IS NOT DISTINCT FROM OLD.is_active
     AND NEW.offer_id IS NOT DISTINCT FROM OLD.offer_id
     AND NEW.offer_value IS NOT DISTINCT FROM OLD.offer_value
     AND NEW.base_cost_usd IS NOT DISTINCT FROM OLD.base_cost_usd
     AND NEW.app_fee_usd IS NOT DISTINCT FROM OLD.app_fee_usd
     AND NEW.target_local_value IS NOT DISTINCT FROM OLD.target_local_value
     AND NEW.target_local_currency IS NOT DISTINCT FROM OLD.target_local_currency
     AND NEW.max_authorized_usd IS NOT DISTINCT FROM OLD.max_authorized_usd
     AND NEW.engine_version IS NOT DISTINCT FROM OLD.engine_version
     AND NEW.intent_kind IS NOT DISTINCT FROM OLD.intent_kind
     AND NEW.preferred_provider IS NOT DISTINCT FROM OLD.preferred_provider THEN
    RETURN NEW;
  END IF;

  -- 2. Cap-only update: if ONLY max_authorized_usd changed (e.g. from approve_refill_execution),
  -- update pending executions in-place without cancelling or rescheduling them.
  IF TG_OP = 'UPDATE'
     AND NEW.amount IS NOT DISTINCT FROM OLD.amount
     AND NEW.currency IS NOT DISTINCT FROM OLD.currency
     AND NEW.next_execution_at IS NOT DISTINCT FROM OLD.next_execution_at
     AND NEW.is_active IS NOT DISTINCT FROM OLD.is_active
     AND NEW.offer_id IS NOT DISTINCT FROM OLD.offer_id
     AND NEW.offer_value IS NOT DISTINCT FROM OLD.offer_value
     AND NEW.base_cost_usd IS NOT DISTINCT FROM OLD.base_cost_usd
     AND NEW.app_fee_usd IS NOT DISTINCT FROM OLD.app_fee_usd
     AND NEW.target_local_value IS NOT DISTINCT FROM OLD.target_local_value
     AND NEW.target_local_currency IS NOT DISTINCT FROM OLD.target_local_currency
     AND NEW.engine_version IS NOT DISTINCT FROM OLD.engine_version
     AND NEW.intent_kind IS NOT DISTINCT FROM OLD.intent_kind
     AND NEW.preferred_provider IS NOT DISTINCT FROM OLD.preferred_provider
     AND NEW.max_authorized_usd IS DISTINCT FROM OLD.max_authorized_usd THEN
    UPDATE public.topup_executions
    SET max_authorized_usd = NEW.max_authorized_usd,
        updated_at = now()
    WHERE scheduled_topup_id = NEW.id
      AND status IN ('pending', 'pending_payment', 'awaiting_approval', 'awaiting_funds');
    RETURN NEW;
  END IF;

  IF COALESCE(NEW.is_active, false) THEN
    -- Check if identical pending execution already exists with matching cap, pricing, and intent
    IF EXISTS (
      SELECT 1 FROM public.topup_executions t
      WHERE t.scheduled_topup_id = NEW.id
        AND t.status = 'pending'
        AND t.execution_time = NEW.next_execution_at
        AND t.amount = NEW.amount
        AND t.offer_id IS NOT DISTINCT FROM NEW.offer_id
        AND t.offer_value IS NOT DISTINCT FROM NEW.offer_value
        AND t.base_cost_usd IS NOT DISTINCT FROM NEW.base_cost_usd
        AND t.target_local_value IS NOT DISTINCT FROM NEW.target_local_value
        AND t.target_local_currency IS NOT DISTINCT FROM NEW.target_local_currency
        AND t.max_authorized_usd IS NOT DISTINCT FROM COALESCE(NEW.max_authorized_usd, NEW.amount)
        AND t.api_provider IS NOT DISTINCT FROM NEW.preferred_provider
        AND t.engine_version IS NOT DISTINCT FROM COALESCE(NEW.engine_version, 2)
        AND t.intent_kind IS NOT DISTINCT FROM COALESCE(NEW.intent_kind, 'exact_airtime')
    ) THEN
      RETURN NEW;
    END IF;

    -- Cancel existing future unsubmitted executions (preserve any execution currently due or approved for now)
    UPDATE public.topup_executions
    SET status = 'cancelled', completed_at = now()
    WHERE scheduled_topup_id = NEW.id
      AND status IN ('pending', 'pending_payment', 'awaiting_approval', 'awaiting_funds')
      AND execution_time > now();

    -- Only insert a new execution if one for next_execution_at does not already exist
    IF NOT EXISTS (
      SELECT 1 FROM public.topup_executions t
      WHERE t.scheduled_topup_id = NEW.id
        AND t.status = 'pending'
        AND t.execution_time = NEW.next_execution_at
    ) THEN
      INSERT INTO public.topup_executions (
        sim_line_id, user_id, amount, base_cost_usd, app_fee_usd, currency, status,
        execution_type, execution_time, offer_id, offer_value,
        payment_gateway_code, scheduled_topup_id, api_provider,
        target_local_value, target_local_currency, max_authorized_usd,
        engine_version, intent_kind, attempted_providers, carrier_in_flight
      ) VALUES (
        NEW.sim_line_id, NEW.user_id, NEW.amount, NEW.base_cost_usd, NEW.app_fee_usd,
        COALESCE(NEW.currency, 'USD'), 'pending',
        NEW.schedule_type, NEW.next_execution_at, NEW.offer_id, NEW.offer_value,
        'wallet', NEW.id, NEW.preferred_provider,
        NEW.target_local_value, NEW.target_local_currency, COALESCE(NEW.max_authorized_usd, NEW.amount),
        COALESCE(NEW.engine_version, 2), COALESCE(NEW.intent_kind, 'exact_airtime'),
        ARRAY[]::text[], FALSE
      );
    END IF;
  ELSE
    -- Schedule paused or deactivated: cancel unsubmitted executions across all waiting states
    UPDATE public.topup_executions
    SET status = 'cancelled', completed_at = now()
    WHERE scheduled_topup_id = NEW.id
      AND status IN ('pending', 'pending_payment', 'awaiting_approval', 'awaiting_funds');
  END IF;

  RETURN NEW;
END;
$$;

-- 3. TARGETED DATA REPAIR FOR TEST LINE ROWS (Preserving all completed monetary rows)
-- Repair unsubmitted future pending execution and its parent schedule
UPDATE public.topup_executions
SET base_cost_usd = 6.9701,
    app_fee_usd = 0.21,
    amount = 7.18,
    max_authorized_usd = 7.18,
    offer_id = 'XCSASA72721',
    api_provider = 'ding',
    executed_at = NULL,
    updated_at = now()
WHERE id = 'c3dad031-c9dc-48d0-8d69-f5cae8fe6c97'
  AND status = 'pending';

UPDATE public.scheduled_topups
SET base_cost_usd = 6.9701,
    app_fee_usd = 0.21,
    amount = 7.18,
    max_authorized_usd = 7.18,
    offer_id = 'XCSASA72721',
    preferred_provider = 'ding',
    updated_at = now()
WHERE id = '190b8d8d-a61e-4c1b-a307-68513f9a903f';

-- Synchronize line health and next topup due for test SIM
UPDATE public.sim_lines
SET health_score = 100,
    next_topup_due = '2027-02-15 10:23:26.496436+00',
    updated_at = now()
WHERE id = 'da7eb107-1a84-4a87-a563-4aacba4ed86f';
