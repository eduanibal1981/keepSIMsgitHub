-- ============================================================================
-- F1: close the wallet-minting hole on credit_wallet_for_refund
--
-- Finding F-1 (doc/PRODUCTION_PLAN_REVIEW.md § 1): the 6-argument
-- credit_wallet_for_refund is SECURITY DEFINER and was EXECUTE-granted to
-- `authenticated` by 20260801010000_d5b_observability_and_plan_tier_hardening
-- (lines 171-172). The body validates only that p_amount > 0 and that the
-- wallet exists — no caller check at all. Any account that can sign up could
--
--   POST /rest/v1/rpc/credit_wallet_for_refund
--   {"p_user_id":"<self>","p_amount":100000,"p_type":"refund", ...}
--
-- and mint balance out of nothing, with a wallet_transactions row that reads as
-- a legitimate refund in the ledger.
--
-- Nothing in the client calls this RPC. The only callers are:
--   * servers/worker_instant_refill.js:270      (service_role key)
--   * servers/worker_esim_fulfillment.js:241    (service_role key)
--   * public.reap_stale_esim_orders()           (SECURITY DEFINER, owner postgres)
-- so removing the `authenticated` grant breaks no working path.
--
-- Two layers, because the grant has already drifted back once:
--   1. EXECUTE revoked from PUBLIC/anon/authenticated, granted to service_role.
--   2. An in-body guard that refuses any call arriving over PostgREST under a
--      JWT role other than service_role, so a future accidental re-grant is not
--      instantly fatal.
--
-- On the guard: it keys on the `request.jwt.claims` GUC, NOT on current_user
-- and NOT on `auth.uid() <> p_user_id`.
--   * current_user is useless here — inside a SECURITY DEFINER function it is
--     the function owner (postgres), which is what made D5c's tamper guard dead
--     code.
--   * `auth.uid() <> p_user_id` would not stop this exploit at all: the attack
--     credits the attacker's OWN wallet, so the ids match.
-- PostgREST always populates request.jwt.claims (role=anon when only the
-- publishable key is presented), so an HTTP-originated call can never reach the
-- body unnoticed. pg_cron, psql-as-postgres and other SECURITY DEFINER callers
-- have no such GUC and are unaffected. Malformed claims fail the ::jsonb cast,
-- i.e. fail closed.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.credit_wallet_for_refund(
  p_user_id UUID,
  p_amount NUMERIC,
  p_reference_id TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL,
  p_sim_line_id UUID DEFAULT NULL,
  p_type TEXT DEFAULT 'refund'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_raw_claims TEXT;
  v_jwt_role TEXT;
  v_wallet_id UUID;
  v_balance_before NUMERIC;
  v_balance_after NUMERIC;
  v_txn_id UUID;
BEGIN
  -- Layer 2: refuse anything that reached us over PostgREST as a non-service role.
  v_raw_claims := current_setting('request.jwt.claims', true);
  IF v_raw_claims IS NOT NULL AND v_raw_claims <> '' THEN
    v_jwt_role := (v_raw_claims::jsonb) ->> 'role';
    IF v_jwt_role IS DISTINCT FROM 'service_role' THEN
      RAISE EXCEPTION 'credit_wallet_for_refund is not callable by role %', COALESCE(v_jwt_role, '<none>')
        USING ERRCODE = 'KS403';
    END IF;
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Refund amount must be positive, got %', p_amount;
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
      total_spent = GREATEST(0, total_spent - p_amount)
  WHERE id = v_wallet_id;

  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, amount, balance_before, balance_after,
    description, reference_id, sim_line_id, status
  ) VALUES (
    v_wallet_id, p_user_id, COALESCE(p_type, 'refund'), p_amount, v_balance_before, v_balance_after,
    p_description, p_reference_id, p_sim_line_id, 'completed'
  ) RETURNING id INTO v_txn_id;

  RETURN v_txn_id;
END;
$$;

-- Layer 1. CREATE OR REPLACE preserves the existing ACL, so the revoke has to
-- be explicit. Signature-qualified on purpose: an unqualified REVOKE silently
-- does nothing the day a second overload appears (that is exactly how F-2's
-- 6-arg debit_wallet_for_topup ended up executable by PUBLIC).
REVOKE ALL ON FUNCTION public.credit_wallet_for_refund(UUID, NUMERIC, TEXT, TEXT, UUID, TEXT)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.credit_wallet_for_refund(UUID, NUMERIC, TEXT, TEXT, UUID, TEXT)
  TO service_role;

COMMENT ON FUNCTION public.credit_wallet_for_refund(UUID, NUMERIC, TEXT, TEXT, UUID, TEXT) IS
  'Credits a wallet as a refund. service_role ONLY (workers + reap_stale_esim_orders). '
  'Never grant to anon/authenticated — see F-1 in doc/PRODUCTION_PLAN_REVIEW.md; '
  'regression test supabase/tests/f1_wallet_refund_grant_tests.sql.';
