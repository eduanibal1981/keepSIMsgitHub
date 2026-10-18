-- Migration: Add setup_refill order_type to wallet_holds and update reserve_sim_setup_holds
-- Makes setup refill holds distinct from scheduled/instant refills for clear accounting and debugging.

-- 1. Update wallet_holds check constraint
ALTER TABLE public.wallet_holds DROP CONSTRAINT IF EXISTS wallet_holds_order_type_check;
ALTER TABLE public.wallet_holds ADD CONSTRAINT wallet_holds_order_type_check
  CHECK (order_type = ANY (ARRAY[
    'refill_instant'::text,
    'refill_scheduled'::text,
    'setup_refill'::text,
    'plan_fee'::text,
    'esim_purchase'::text,
    'call_budget'::text,
    'offline_voucher'::text,
    'refund_request'::text,
    'line_verification'::text
  ]));

-- 2. Update reserve_sim_setup_holds to use 'setup_refill'
CREATE OR REPLACE FUNCTION public.reserve_sim_setup_holds(p_order_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_user_id             UUID;
  v_order               RECORD;
  v_wallet              RECORD;
  v_held_amount         NUMERIC := 0.00;
  v_available           NUMERIC := 0.00;
  v_fee_hold_id         UUID;
  v_refill_hold_id      UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT * INTO v_order
  FROM public.sim_setup_orders
  WHERE id = p_order_id FOR UPDATE;

  IF v_order.id IS NULL THEN
    RAISE EXCEPTION 'Setup order not found: %', p_order_id;
  END IF;

  IF v_order.user_id <> v_user_id THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  IF v_order.status = 'reserved' AND v_order.annual_fee_hold_id IS NOT NULL THEN
    RETURN jsonb_build_object('success', true, 'status', 'reserved', 'order_id', p_order_id);
  END IF;

  IF v_order.status NOT IN ('draft', 'awaiting_funds') THEN
    RAISE EXCEPTION 'Cannot reserve holds for order in status: %', v_order.status;
  END IF;

  -- Lock wallet
  SELECT * INTO v_wallet
  FROM public.wallets
  WHERE user_id = v_user_id FOR UPDATE;

  IF v_wallet.id IS NULL THEN
    RAISE EXCEPTION 'Wallet not found for user';
  END IF;

  SELECT COALESCE(SUM(amount), 0.00) INTO v_held_amount
  FROM public.wallet_holds
  WHERE user_id = v_user_id AND status = 'active';

  v_available := v_wallet.balance - v_held_amount;

  IF v_available < v_order.total_charge_usd THEN
    UPDATE public.sim_setup_orders
    SET status = 'awaiting_funds', updated_at = now()
    WHERE id = p_order_id;

    RETURN jsonb_build_object(
      'success', false,
      'code', 'insufficient_funds',
      'available_balance', v_available,
      'required_balance', v_order.total_charge_usd,
      'shortfall', round(v_order.total_charge_usd - v_available, 2)
    );
  END IF;

  -- 1. Hold annual fee if > 0
  IF v_order.annual_fee_usd > 0 THEN
    v_fee_hold_id := public.reserve_wallet_funds(
      v_user_id,
      v_order.annual_fee_usd,
      'plan_fee',
      'setup_fee_' || p_order_id::text,
      'Annual KeepSIMs Protection Fee Hold',
      240
    );
  END IF;

  -- 2. Hold first refill as 'setup_refill' if > 0
  IF v_order.first_refill_cost_usd > 0 THEN
    v_refill_hold_id := public.reserve_wallet_funds(
      v_user_id,
      v_order.first_refill_cost_usd,
      'setup_refill',
      'setup_refill_' || p_order_id::text,
      'Initial SIM Setup Refill Hold',
      240
    );
  END IF;

  UPDATE public.sim_setup_orders
  SET annual_fee_hold_id = v_fee_hold_id,
      first_refill_hold_id = v_refill_hold_id,
      status = 'reserved',
      updated_at = now()
  WHERE id = p_order_id;

  RETURN jsonb_build_object(
    'success', true,
    'status', 'reserved',
    'annual_fee_hold_id', v_fee_hold_id,
    'first_refill_hold_id', v_refill_hold_id,
    'total_charge_usd', v_order.total_charge_usd
  );
END;
$function$;
