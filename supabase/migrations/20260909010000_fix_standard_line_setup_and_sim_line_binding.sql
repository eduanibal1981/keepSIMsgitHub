-- =============================================================================
-- Migration: 20260909010000_fix_standard_line_setup_and_sim_line_binding.sql
-- Description:
--   1. Update finalize_sim_setup_order to accept optional p_sim_line_id and
--      auto-bind to the user's sim line if missing.
--   2. Update capture_sim_setup_holds to:
--      a) Fallback to auto-binding sim_line_id by matching phone_number & user_id.
--      b) Ensure scheduled_topups amount for 'notify' schedule is always positive
--         (avoiding 0.00 violation for Standard plans with $0 initial refill).
-- =============================================================================

DROP FUNCTION IF EXISTS public.finalize_sim_setup_order(UUID);

CREATE OR REPLACE FUNCTION public.finalize_sim_setup_order(
  p_order_id UUID,
  p_sim_line_id UUID DEFAULT NULL::UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id        UUID := auth.uid();
  v_order          RECORD;
  v_execution      RECORD;
  v_target_line_id UUID;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;

  SELECT * INTO v_order
  FROM public.sim_setup_orders
  WHERE id = p_order_id AND user_id = v_user_id FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'Order not found'; END IF;

  -- If order doesn't have sim_line_id linked yet, resolve it
  IF v_order.sim_line_id IS NULL THEN
    v_target_line_id := p_sim_line_id;

    -- Fallback: resolve from user's sim_lines matching phone_number
    IF v_target_line_id IS NULL THEN
      SELECT id INTO v_target_line_id
      FROM public.sim_lines
      WHERE user_id = v_user_id AND phone_number = v_order.phone_number
      ORDER BY created_at DESC
      LIMIT 1;
    END IF;

    IF v_target_line_id IS NOT NULL THEN
      -- Validate ownership
      IF NOT EXISTS (SELECT 1 FROM public.sim_lines WHERE id = v_target_line_id AND user_id = v_user_id) THEN
        RAISE EXCEPTION 'SIM line not found or unauthorized';
      END IF;

      UPDATE public.sim_setup_orders
      SET sim_line_id = v_target_line_id,
          updated_at = now()
      WHERE id = p_order_id;

      SELECT * INTO v_order
      FROM public.sim_setup_orders
      WHERE id = p_order_id;
    END IF;
  END IF;

  IF v_order.status = 'active' THEN
    RETURN jsonb_build_object('success', true, 'status', 'active', 'plan', v_order.plan);
  END IF;

  IF v_order.status = 'failed' THEN
    RETURN jsonb_build_object('success', false, 'status', 'failed', 'reason', v_order.failure_reason);
  END IF;

  -- For Standard: can capture immediately if holds are reserved
  IF v_order.plan = 'standard' THEN
    RETURN public.capture_sim_setup_holds(p_order_id);
  END IF;

  -- For Premium: check execution outcome
  SELECT * INTO v_execution
  FROM public.topup_executions
  WHERE wallet_hold_id = v_order.first_refill_hold_id
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'status', 'dispatching', 'pending', true);
  END IF;

  IF v_execution.status = 'success' THEN
    RETURN public.capture_sim_setup_holds(p_order_id, v_execution.reloadly_transaction_id);
  ELSIF v_execution.status IN ('failed', 'cancelled') THEN
    RETURN public.release_sim_setup_holds(p_order_id, COALESCE(v_execution.failure_reason, 'Initial recharge failed'));
  ELSE
    -- Still routing / processing
    RETURN jsonb_build_object('success', false, 'status', 'dispatching', 'pending', true);
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.finalize_sim_setup_order(UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.finalize_sim_setup_order(UUID, UUID) TO authenticated, service_role;


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
  v_order         RECORD;
  v_line_id       UUID;
  v_interval_days INTEGER := 30;
  v_rule          RECORD;
  v_notify_amount NUMERIC := 1.00;
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

    -- Resolve valid positive notify amount (avoid 0.00 for Standard plans)
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

    -- 5b. For Premium lines, also create 'refill_mini' keep-alive schedule
    IF v_order.plan = 'premium' THEN
      INSERT INTO public.scheduled_topups (
        user_id, sim_line_id, amount, currency, frequency_days,
        next_execution_at, is_active, status, schedule_type, offer_id, offer_value
      ) VALUES (
        v_order.user_id,
        v_line_id,
        COALESCE(NULLIF(v_order.first_refill_cost_usd, 0), v_rule.minimum_topup_amount, 1.00),
        'USD',
        v_interval_days,
        now() + (v_interval_days || ' days')::interval,
        true,
        'active',
        'refill_mini',
        v_rule.offer_id,
        v_rule.offer_value
      )
      ON CONFLICT (sim_line_id, schedule_type)
      DO UPDATE SET
        amount = EXCLUDED.amount,
        currency = EXCLUDED.currency,
        frequency_days = EXCLUDED.frequency_days,
        next_execution_at = EXCLUDED.next_execution_at,
        is_active = true,
        status = 'active',
        offer_id = EXCLUDED.offer_id,
        offer_value = EXCLUDED.offer_value,
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
