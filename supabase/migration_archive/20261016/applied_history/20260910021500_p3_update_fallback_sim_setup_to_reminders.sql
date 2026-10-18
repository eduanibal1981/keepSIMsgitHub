-- =============================================================================
-- Migration: 20260910021500_p3_update_fallback_sim_setup_to_reminders.sql
-- Description:
--   Updates fallback_sim_setup_to_reminders to support Permanent Free (C13):
--   plan_expires_at is set to NULL for Free, no 6-month grant limit blocking.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fallback_sim_setup_to_reminders(
  p_order_id      UUID,
  p_sim_line_id   UUID,
  p_fallback_plan TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id           UUID := auth.uid();
  v_order             RECORD;
  v_line              RECORD;
  v_norm_phone        TEXT;
  v_wallet            RECORD;
  v_held_amount       NUMERIC := 0.00;
  v_available         NUMERIC := 0.00;
  v_std_fee           NUMERIC := 2.50;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;

  SELECT * INTO v_order
  FROM public.sim_setup_orders
  WHERE id = p_order_id AND user_id = v_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Setup order not found';
  END IF;

  SELECT * INTO v_line
  FROM public.sim_lines
  WHERE id = p_sim_line_id AND user_id = v_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'SIM line not found';
  END IF;

  v_norm_phone := v_order.phone_number;

  IF p_fallback_plan = 'free' THEN
    -- Update line to Permanent Free
    UPDATE public.sim_lines
    SET plan_type = 'free',
        protection_tier = 'basic',
        plan_expires_at = NULL,
        carrier_status = 'pending',
        verification_status = 'unverified',
        updated_at = now()
    WHERE id = p_sim_line_id;

    -- Cancel any active refill executions or schedules
    UPDATE public.topup_executions
    SET status = 'cancelled', failure_reason = 'fallback_to_free'
    WHERE sim_line_id = p_sim_line_id AND status = 'pending';

    UPDATE public.scheduled_topups
    SET is_active = false, status = 'paused'
    WHERE sim_line_id = p_sim_line_id AND schedule_type <> 'notify';

    RETURN jsonb_build_object(
      'success', true,
      'plan', 'free',
      'expires_at', null
    );

  ELSIF p_fallback_plan = 'standard' THEN
    SELECT COALESCE(config_value::numeric, 2.50) INTO v_std_fee
    FROM public.system_configs WHERE config_key = 'MEMBERSHIP_FEE_STANDARD_USD';

    -- Check wallet balance for annual fee
    SELECT * INTO v_wallet
    FROM public.wallets
    WHERE user_id = v_user_id FOR UPDATE;

    IF v_wallet.id IS NULL THEN
      RAISE EXCEPTION 'Wallet not found';
    END IF;

    SELECT COALESCE(SUM(amount), 0.00) INTO v_held_amount
    FROM public.wallet_holds
    WHERE user_id = v_user_id AND status = 'active';

    v_available := v_wallet.balance - v_held_amount;

    IF v_available < v_std_fee THEN
      RETURN jsonb_build_object(
        'success', false,
        'code', 'insufficient_funds',
        'available_balance', v_available,
        'required', v_std_fee
      );
    END IF;

    -- Debit fee
    UPDATE public.wallets
    SET balance = balance - v_std_fee, updated_at = now()
    WHERE user_id = v_user_id;

    INSERT INTO public.wallet_transactions (
      user_id, type, amount, balance_after, description, reference_id
    ) VALUES (
      v_user_id,
      'plan_fee_debit',
      v_std_fee,
      v_wallet.balance - v_std_fee,
      'Annual Protection Fee (Standard fallback)',
      'std_fallback_' || p_order_id::text
    );

    INSERT INTO public.plan_payments (
      user_id, sim_line_id, capture_id, order_id, kind, gross_usd, net_usd,
      paypal_fee_usd, metadata, created_at
    ) VALUES (
      v_user_id,
      p_sim_line_id,
      'std_fallback_' || p_order_id::text,
      p_order_id::text,
      'plan',
      v_std_fee,
      v_std_fee,
      0.00,
      jsonb_build_object('billing_model', 'pay_per_refill', 'plan', 'standard', 'fallback_from_order', p_order_id),
      now()
    );

    -- Update line to Standard
    UPDATE public.sim_lines
    SET plan_type = 'standard',
        protection_tier = 'standard',
        plan_expires_at = now() + interval '365 days',
        carrier_status = 'pending',
        verification_status = 'unverified',
        updated_at = now()
    WHERE id = p_sim_line_id;

    -- Cancel any active refill executions or schedules
    UPDATE public.topup_executions
    SET status = 'cancelled', failure_reason = 'fallback_to_standard'
    WHERE sim_line_id = p_sim_line_id AND status = 'pending';

    UPDATE public.scheduled_topups
    SET is_active = false, status = 'paused'
    WHERE sim_line_id = p_sim_line_id AND schedule_type <> 'notify';

    RETURN jsonb_build_object(
      'success', true,
      'plan', 'standard',
      'expires_at', now() + interval '365 days'
    );
  ELSE
    RAISE EXCEPTION 'Invalid fallback plan: %', p_fallback_plan;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fallback_sim_setup_to_reminders(UUID, UUID, TEXT) TO authenticated, service_role;
