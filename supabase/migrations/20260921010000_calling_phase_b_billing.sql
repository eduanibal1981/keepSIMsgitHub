-- ============================================================================
-- Migration: 20260921010000_calling_phase_b_billing.sql
-- Feature: Atomic Call Wallet Holds Partial Settlement & CDR Integration (F06, F07)
-- ============================================================================

-- 1. Security-Definer RPC: Atomic Partial Hold Settlement
CREATE OR REPLACE FUNCTION public.settle_call_wallet_hold(
  p_hold_id UUID,
  p_actual_cost NUMERIC,
  p_description TEXT DEFAULT 'International Call',
  p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_hold RECORD;
  v_wallet RECORD;
  v_balance_after NUMERIC;
  v_txn_id UUID;
  v_alloc RECORD;
  v_to_consume NUMERIC;
  v_lot_consume NUMERIC;
BEGIN
  -- Lock hold
  SELECT * INTO v_hold
  FROM public.wallet_holds
  WHERE id = p_hold_id
  FOR UPDATE;

  IF v_hold.id IS NULL THEN
    RAISE EXCEPTION 'Hold not found: %', p_hold_id;
  END IF;

  -- Idempotency check: if already captured, return existing transaction
  IF v_hold.status = 'captured' THEN
    SELECT id INTO v_txn_id
    FROM public.wallet_transactions
    WHERE reference_id = 'hold_' || p_hold_id::text;
    IF v_txn_id IS NOT NULL THEN
      RETURN v_txn_id;
    END IF;
  END IF;

  IF v_hold.status = 'released' THEN
    RETURN NULL;
  END IF;

  IF v_hold.status != 'active' THEN
    RAISE EXCEPTION 'Cannot settle hold in status: %', v_hold.status;
  END IF;

  -- If actual cost is zero or negative (e.g. unanswered call), release the hold completely
  IF p_actual_cost IS NULL OR p_actual_cost <= 0 THEN
    UPDATE public.wallet_holds
    SET status = 'released',
        released_at = now(),
        updated_at = now()
    WHERE id = p_hold_id;
    RETURN NULL;
  END IF;

  -- Cap actual cost to held amount if rounding exceeds
  IF p_actual_cost > v_hold.amount THEN
    p_actual_cost := v_hold.amount;
  END IF;

  -- Lock wallet
  SELECT * INTO v_wallet
  FROM public.wallets
  WHERE id = v_hold.wallet_id
  FOR UPDATE;

  IF v_wallet.balance < p_actual_cost THEN
    RAISE EXCEPTION 'Invariant violation: wallet balance % is less than actual cost %', v_wallet.balance, p_actual_cost;
  END IF;

  v_balance_after := v_wallet.balance - p_actual_cost;

  -- Update wallet balance
  UPDATE public.wallets
  SET balance = v_balance_after,
      total_spent = total_spent + p_actual_cost,
      updated_at = now()
  WHERE id = v_wallet.id;

  -- Consume funding lots FIFO only up to p_actual_cost
  v_to_consume := p_actual_cost;
  FOR v_alloc IN
    SELECT * FROM public.wallet_hold_allocations
    WHERE hold_id = p_hold_id
    ORDER BY id ASC
  LOOP
    EXIT WHEN v_to_consume <= 0;
    v_lot_consume := LEAST(v_alloc.amount, v_to_consume);

    UPDATE public.wallet_funding_lots
    SET remaining_amount = remaining_amount - v_lot_consume,
        status = CASE WHEN remaining_amount - v_lot_consume = 0 THEN 'fully_consumed' ELSE status END,
        updated_at = now()
    WHERE id = v_alloc.lot_id;

    v_to_consume := v_to_consume - v_lot_consume;
  END LOOP;

  -- Mark hold captured
  UPDATE public.wallet_holds
  SET status = 'captured',
      captured_at = now(),
      updated_at = now()
  WHERE id = p_hold_id;

  -- Record ledger transaction
  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, amount, balance_before, balance_after,
    description, reference_id, status, metadata, created_at
  ) VALUES (
    v_wallet.id, v_hold.user_id, 'call_debit', p_actual_cost, v_wallet.balance, v_balance_after,
    COALESCE(p_description, 'International Call'),
    'hold_' || p_hold_id::text,
    'completed',
    jsonb_build_object(
      'hold_id', p_hold_id,
      'order_type', v_hold.order_type,
      'order_reference_id', v_hold.order_reference_id,
      'held_amount', v_hold.amount,
      'settled_amount', p_actual_cost
    ) || COALESCE(p_metadata, '{}'::jsonb),
    now()
  ) RETURNING id INTO v_txn_id;

  RETURN v_txn_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.settle_call_wallet_hold(UUID, NUMERIC, TEXT, JSONB) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.settle_call_wallet_hold(UUID, NUMERIC, TEXT, JSONB) TO service_role;

-- 2. Update finish_media_call to settle active call holds atomically
CREATE OR REPLACE FUNCTION public.finish_media_call(p_call_id uuid, p_ended_at timestamptz,
  p_status text, p_error text, p_payload jsonb)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE
  r public.call_records%rowtype;
  v_hold RECORD;
  seconds integer := 0;
  cost numeric := 0;
  v_txn_id uuid;
BEGIN
  SELECT * INTO r FROM public.call_records WHERE id = p_call_id FOR UPDATE;
  IF NOT FOUND OR r.call_type <> 'app_to_phone_webrtc' THEN RETURN; END IF;
  IF r.status IN ('completed','declined','busy','no_answer','cancelled','failed') THEN RETURN; END IF;

  IF r.answered_at IS NOT NULL THEN
    seconds := GREATEST(0, CEIL(EXTRACT(EPOCH FROM (p_ended_at - r.answered_at)))::INTEGER);
    cost := ROUND(seconds * r.rate_per_minute_usd / 60, 4);
  END IF;

  -- Check for existing active hold for this call
  SELECT * INTO v_hold
  FROM public.wallet_holds
  WHERE order_type = 'call_budget'
    AND order_reference_id = p_call_id::text
    AND status = 'active'
  LIMIT 1;

  IF v_hold.id IS NOT NULL THEN
    v_txn_id := public.settle_call_wallet_hold(
      v_hold.id,
      cost,
      'International call to ' || COALESCE(r.destination_number, ''),
      jsonb_build_object('call_id', r.id, 'duration_seconds', seconds)
    );
  ELSIF cost > 0 THEN
    -- Fallback legacy path without pre-reserved hold
    v_txn_id := public.debit_wallet_for_call(r.user_id, r.id, cost, 'International call');
  END IF;

  UPDATE public.call_records SET
    status = CASE WHEN r.answered_at IS NOT NULL THEN 'completed' ELSE p_status END,
    ended_at = p_ended_at,
    duration_seconds = seconds,
    billed_duration_seconds = seconds,
    total_cost_usd = cost,
    wallet_txn_id = COALESCE(v_txn_id, wallet_txn_id),
    error_message = p_error,
    raw_cdr = p_payload,
    telnyx_hangup_cause = p_payload->>'hangup_cause',
    hangup_source = p_payload->>'hangup_source'
  WHERE id = r.id;
END;
$$;

REVOKE ALL ON FUNCTION public.finish_media_call(uuid,timestamptz,text,text,jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.finish_media_call(uuid,timestamptz,text,text,jsonb) TO service_role;
