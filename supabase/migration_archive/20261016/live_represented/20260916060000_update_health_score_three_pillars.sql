-- Migration: 20260916060000_update_health_score_three_pillars.sql
-- Description:
--   1. Refine calculate_health_score to 3 pillars (100 pts total):
--      - 25 pts: Real Live Verification (checks line_verification_attempts and line_activity_log)
--      - 25 pts: Auto-Notify schedule active (scheduled_topups where schedule_type = 'notify')
--      - 50 pts: Last refill date within carrier rule days (inactivity_limit_days)
--        * No recharge recorded: 0 pts
--        * Last recharge older than carrier rule days: 0 pts
--      - Auto-refill removed from scoring so standard & free plans can reach 100%
--   2. Update finalize_sim_setup_order so onboarding never auto-verifies lines without real live testing.
--   3. Reset verification_status = 'unverified' and is_carrier_verified = false on lines without succeeded live verification.
--   4. Re-calculate health_score across all SIM lines.

-- 1. Refine calculate_health_score
CREATE OR REPLACE FUNCTION public.calculate_health_score(
  p_sim_line_id uuid,
  p_status text,
  p_last_topup_at timestamp with time zone
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_is_verified BOOLEAN := false;
  v_has_notify_schedule BOOLEAN := false;
  v_expiration_days INTEGER := 90;
  v_rule_days INTEGER;
  v_score INTEGER := 0;
BEGIN
  -- Pillar 1: Real Live Verification (25 pts)
  -- ONLY awarded if real live verification has succeeded (SMS DLR or missed call).
  -- Format checking or active status during line onboarding does NOT grant points.
  SELECT EXISTS(
    SELECT 1 FROM public.line_verification_attempts
    WHERE sim_line_id = p_sim_line_id
      AND outcome = 'succeeded'
  ) INTO v_is_verified;

  IF NOT v_is_verified THEN
    SELECT EXISTS(
      SELECT 1 FROM public.line_activity_log
      WHERE sim_line_id = p_sim_line_id
        AND (
          description ILIKE '%live verified active%'
          OR description ILIKE '%verified active via%'
        )
    ) INTO v_is_verified;
  END IF;

  IF v_is_verified THEN
    v_score := v_score + 25;
  END IF;

  -- Pillar 2: Auto-Notify alerts configured & active (25 pts)
  SELECT EXISTS(
    SELECT 1 FROM public.scheduled_topups
    WHERE sim_line_id = p_sim_line_id
      AND status = 'active'
      AND is_active = true
      AND schedule_type = 'notify'
  ) INTO v_has_notify_schedule;

  IF v_has_notify_schedule THEN
    v_score := v_score + 25;
  END IF;

  -- Pillar 3: Last refill date within carrier rule window (50 pts)
  -- The ground truth: recorded either in-app or from outside recharge.
  -- Awarded 50 points IF AND ONLY IF recorded AND within carrier rule limit days.
  -- - No recharge recorded: 0 pts
  -- - Last recharge older than carrier limit days: 0 pts
  SELECT cr.inactivity_limit_days INTO v_rule_days
  FROM public.sim_lines sl
  LEFT JOIN public.carrier_rules cr ON (cr.id = sl.carrier_rule_id OR cr.carrier_id = sl.carrier_id)
  WHERE sl.id = p_sim_line_id
  LIMIT 1;

  IF v_rule_days IS NOT NULL AND v_rule_days > 0 THEN
    v_expiration_days := v_rule_days;
  END IF;

  IF p_last_topup_at IS NOT NULL AND p_last_topup_at >= NOW() - (v_expiration_days || ' days')::INTERVAL THEN
    v_score := v_score + 50;
  END IF;

  RETURN LEAST(100, GREATEST(0, v_score));
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.calculate_health_score(uuid, text, timestamp with time zone) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.calculate_health_score(uuid, text, timestamp with time zone) TO authenticated, service_role;

-- 2. Update finalize_sim_setup_order to omit automatic verification
CREATE OR REPLACE FUNCTION public.finalize_sim_setup_order(
  p_order_id UUID,
  p_provider_tx_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order            public.sim_setup_orders%ROWTYPE;
  v_line_id          UUID;
  v_rule             public.carrier_rules%ROWTYPE;
  v_sched_id         UUID;
  v_interval_days    INTEGER;
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

  -- 3. Activate SIM Line (keep unverified until user performs real live verification)
  UPDATE public.sim_lines
  SET status = 'active',
      plan_type = v_order.plan,
      protection_tier = CASE WHEN v_order.plan = 'free' THEN 'basic' ELSE v_order.plan END,
      plan_expires_at = now() + INTERVAL '365 days',
      last_topup_at = CASE WHEN v_order.plan = 'premium' THEN now() ELSE last_topup_at END,
      carrier_status = 'active',
      updated_at = now()
  WHERE id = v_line_id;

  -- 4. Record plan payment
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

  -- 5. Create Schedules
  IF v_order.plan IN ('standard', 'premium', 'free') THEN
    INSERT INTO public.scheduled_topups (
      user_id, sim_line_id, schedule_type, status, is_active,
      target_channel, interval_days, next_execution_at,
      created_at, updated_at
    ) VALUES (
      v_order.user_id,
      v_line_id,
      'notify',
      'active',
      true,
      'in_app',
      30,
      now() + INTERVAL '30 days',
      now(),
      now()
    )
    ON CONFLICT DO NOTHING;
  END IF;

  IF v_order.plan = 'premium' THEN
    SELECT * INTO v_rule
    FROM public.carrier_rules
    WHERE carrier_id = (SELECT carrier_id FROM public.sim_lines WHERE id = v_line_id)
    LIMIT 1;

    v_interval_days := COALESCE(
      v_rule.refill_interval_days_override,
      GREATEST(1, COALESCE(v_rule.inactivity_limit_days, 90) - COALESCE(v_rule.grace_period_days, 3))
    );

    IF v_rule.id IS NOT NULL THEN
      v_offer_id := v_rule.offer_id;
      v_offer_value := v_rule.offer_value;
      v_intent_kind := COALESCE(v_rule.activity_requirement, 'exact_airtime');
      v_target_local_val := v_rule.minimum_topup_amount;
      v_target_local_cur := v_rule.inapp_pricing_currency;
    END IF;

    SELECT provider INTO v_provider
    FROM public.carrier_provider_map
    WHERE carrier_id = (SELECT carrier_id FROM public.sim_lines WHERE id = v_line_id)
      AND is_enabled = true
    ORDER BY priority ASC
    LIMIT 1;

    INSERT INTO public.scheduled_topups (
      user_id, sim_line_id, schedule_type, status, is_active,
      amount, target_channel, interval_days, next_execution_at,
      metadata, created_at, updated_at
    ) VALUES (
      v_order.user_id,
      v_line_id,
      'refill_mini',
      'active',
      true,
      COALESCE(v_rule.inapp_pricing, 5.00),
      'auto',
      v_interval_days,
      now() + (v_interval_days || ' days')::INTERVAL,
      jsonb_build_object(
        'carrier_rule_id', v_rule.id,
        'offer_id', v_offer_id,
        'offer_value', v_offer_value,
        'provider', v_provider,
        'intent_kind', v_intent_kind,
        'target_local_value', v_target_local_val,
        'target_local_currency', v_target_local_cur,
        'fee_rule_version', v_fee_rule_ver,
        'auto_configured', true
      ),
      now(),
      now()
    )
    RETURNING id INTO v_sched_id;

    IF v_sched_id IS NOT NULL THEN
      PERFORM public.queue_premium_refill_executions(
        v_line_id,
        v_sched_id,
        now() + INTERVAL '365 days'
      );
    END IF;
  END IF;

  -- 6. Mark setup order active
  UPDATE public.sim_setup_orders
  SET status = 'active',
      updated_at = now()
  WHERE id = p_order_id;

  RETURN jsonb_build_object(
    'success', true,
    'status', 'active',
    'sim_line_id', v_line_id
  );
END;
$$;

-- 3. Reset verification_status on lines that were never live verified
UPDATE public.sim_lines sl
SET verification_status = 'unverified',
    is_carrier_verified = false,
    updated_at = now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.line_verification_attempts a
  WHERE a.sim_line_id = sl.id AND a.outcome = 'succeeded'
)
AND NOT EXISTS (
  SELECT 1 FROM public.line_activity_log l
  WHERE l.sim_line_id = sl.id AND (
    l.description ILIKE '%live verified active%' OR l.description ILIKE '%verified active via%'
  )
);

-- 4. Re-calculate health_score across all SIM lines
UPDATE public.sim_lines sl
SET health_score = public.calculate_health_score(sl.id, sl.status, sl.last_topup_at);
