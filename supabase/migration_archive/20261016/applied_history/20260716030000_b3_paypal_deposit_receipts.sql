-- B3: PayPal webhook hardening + receipts (DB side). Applied to live 2026-07-16.
-- 1) Receipt payload storage on the ledger (gross, fees, method, external ids).
ALTER TABLE public.wallet_transactions ADD COLUMN IF NOT EXISTS metadata jsonb;

-- 2) Idempotency for webhook-credited deposits: one deposit per PayPal capture.
--    Scoped to 'paypal_%' because the legacy 'welcome_bonus' reference is
--    intentionally shared across users.
CREATE UNIQUE INDEX IF NOT EXISTS uq_wallet_transactions_paypal_capture
  ON public.wallet_transactions (reference_id)
  WHERE type = 'deposit' AND reference_id LIKE 'paypal_%';

-- 3) Deposit credit used exclusively by the paypal-webhook Edge Function.
--    Same shape as credit_wallet but carries the receipt metadata and is the
--    only deposit path left once wallet_transact's client 'deposit' action is
--    removed.
CREATE FUNCTION public.credit_wallet_for_deposit(
  p_user_id uuid,
  p_amount numeric,
  p_description text DEFAULT 'Wallet deposit'::text,
  p_reference_id text DEFAULT NULL::text,
  p_metadata jsonb DEFAULT NULL::jsonb
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
    RAISE EXCEPTION 'Deposit amount must be positive, got %', p_amount;
  END IF;

  SELECT id, balance INTO v_wallet_id, v_balance_before
  FROM public.wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    RAISE EXCEPTION 'Wallet not found for user %', p_user_id;
  END IF;

  v_balance_after := v_balance_before + p_amount;

  UPDATE public.wallets
  SET balance = v_balance_after,
      total_deposited = total_deposited + p_amount
  WHERE id = v_wallet_id;

  -- Duplicate PayPal capture reference raises unique_violation and rolls the
  -- whole credit back (webhook retries are idempotent).
  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, amount, balance_before, balance_after,
    description, reference_id, status, metadata
  ) VALUES (
    v_wallet_id, p_user_id, 'deposit', p_amount, v_balance_before, v_balance_after,
    p_description, p_reference_id, 'completed', p_metadata
  ) RETURNING id INTO v_txn_id;

  RETURN v_txn_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.credit_wallet_for_deposit(uuid, numeric, text, text, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.credit_wallet_for_deposit(uuid, numeric, text, text, jsonb) TO service_role;
