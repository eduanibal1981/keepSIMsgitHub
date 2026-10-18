-- B2: debit_wallet_for_topup gains p_reference_id so per-execution debits are
-- idempotent (paired with unique index uq_wallet_transactions_debit_ref), plus
-- the positive-amount guard credit_wallet_for_refund already has.
-- Signature changes (new defaulted param), so drop + recreate; existing callers
-- (wallet_transact Edge Function) use named params and are unaffected.
-- Applied to live 2026-07-16.
DROP FUNCTION public.debit_wallet_for_topup(uuid, uuid, numeric, text);

CREATE FUNCTION public.debit_wallet_for_topup(
  p_user_id uuid,
  p_sim_line_id uuid,
  p_amount numeric,
  p_description text DEFAULT 'SIM top-up'::text,
  p_reference_id text DEFAULT NULL::text
)
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
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Debit amount must be positive, got %', p_amount;
  END IF;

  -- Lock the wallet row
  SELECT id, balance INTO v_wallet_id, v_balance_before
  FROM public.wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    RAISE EXCEPTION 'Wallet not found for user %', p_user_id;
  END IF;

  IF v_balance_before < p_amount THEN
    RAISE EXCEPTION 'Insufficient wallet balance. Have: %, Need: %', v_balance_before, p_amount;
  END IF;

  v_balance_after := v_balance_before - p_amount;

  -- Update wallet balance
  UPDATE public.wallets
  SET balance = v_balance_after,
      total_spent = total_spent + p_amount
  WHERE id = v_wallet_id;

  -- Record transaction; a duplicate p_reference_id raises unique_violation and
  -- rolls the whole debit back (idempotency per execution).
  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, amount, balance_before, balance_after,
    description, reference_id, sim_line_id, status
  ) VALUES (
    v_wallet_id, p_user_id, 'topup_debit', p_amount, v_balance_before, v_balance_after,
    p_description, p_reference_id, p_sim_line_id, 'completed'
  ) RETURNING id INTO v_txn_id;

  RETURN v_txn_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.debit_wallet_for_topup(uuid, uuid, numeric, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.debit_wallet_for_topup(uuid, uuid, numeric, text, text) TO service_role;
