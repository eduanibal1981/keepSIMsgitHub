-- Captured live deposit function on 2026-10-17. No customer data.
CREATE OR REPLACE FUNCTION public.credit_wallet_for_deposit(p_user_id uuid, p_amount numeric, p_description text DEFAULT 'Wallet deposit'::text, p_reference_id text DEFAULT NULL::text, p_metadata jsonb DEFAULT NULL::jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_wallet_id UUID;
  v_balance_before NUMERIC;
  v_balance_after NUMERIC;
  v_txn_id UUID;
  v_order_id TEXT;
  v_capture_id TEXT;
  v_origin TEXT := 'paypal_deposit';
  v_is_refundable BOOLEAN := true;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Deposit amount must be positive, got %', p_amount;
  END IF;

  SELECT id, balance INTO v_wallet_id, v_balance_before
  FROM public.wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    INSERT INTO public.wallets (
      user_id, balance, currency, auto_fund_enabled, total_deposited, total_spent
    ) VALUES (
      p_user_id, p_amount, 'USD', false, p_amount, 0.00
    ) RETURNING id, balance - p_amount INTO v_wallet_id, v_balance_before;
    v_balance_after := p_amount;
  ELSE
    v_balance_after := v_balance_before + p_amount;
    UPDATE public.wallets
    SET balance = v_balance_after,
        total_deposited = total_deposited + p_amount,
        updated_at = now()
    WHERE id = v_wallet_id;
  END IF;

  -- Record transaction
  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, amount, balance_before, balance_after,
    description, reference_id, status, metadata, created_at
  ) VALUES (
    v_wallet_id, p_user_id, 'deposit', p_amount, v_balance_before, v_balance_after,
    p_description, p_reference_id, 'completed', p_metadata, now()
  ) RETURNING id INTO v_txn_id;

  -- Extract order/capture ID from metadata if present
  IF p_metadata IS NOT NULL THEN
    v_order_id := p_metadata->>'order_id';
    v_capture_id := p_metadata->>'paypal_capture_id';
  END IF;
  IF v_capture_id IS NULL AND p_reference_id LIKE 'paypal_%' THEN
    v_capture_id := replace(p_reference_id, 'paypal_', '');
  END IF;

  -- Record funding source lot
  INSERT INTO public.wallet_funding_lots (
    wallet_id, user_id, origin_type, original_reference_id, original_order_id,
    currency, funded_amount, remaining_amount, is_refundable, refund_deadline, status, created_at
  ) VALUES (
    v_wallet_id, p_user_id, v_origin, COALESCE(v_capture_id, p_reference_id), v_order_id,
    'USD', p_amount, p_amount, v_is_refundable, now() + interval '180 days', 'active', now()
  ) ON CONFLICT (user_id, original_reference_id) WHERE original_reference_id IS NOT NULL
  DO NOTHING;

  RETURN v_txn_id;
END;
$function$;
REVOKE ALL ON FUNCTION public.credit_wallet_for_deposit(uuid,numeric,text,text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.credit_wallet_for_deposit(uuid,numeric,text,text,jsonb) TO service_role;
