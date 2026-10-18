-- ============================================================================
-- F2: close the wallet-draining hole on debit_wallet_for_topup
--
-- Finding F-2 (doc/PRODUCTION_PLAN_REVIEW.md § 1), proven live by the reviewer:
--
--   POST /rest/v1/rpc/debit_wallet_for_topup   (apikey + Authorization = anon key)
--   {"p_user_id":"<any user>","p_amount":-1, ...}
--   -> HTTP 400 {"code":"P0001","message":"Debit amount must be positive, got -1"}
--
-- A P0001 raised from *inside* the body means the permission check passed. With a
-- positive amount and any real p_user_id it debits that user's wallet and writes a
-- ledger row. The anon key ships inside the APK (lib/core/supabase_client.dart), so
-- "anyone" is literal.
--
-- Root cause: there are TWO overloads. The 5-arg one was correctly locked down by
-- 20260716022000_b2_debit_wallet_reference_id (REVOKE + GRANT to service_role), but
-- the later 6-arg one (p_txn_type) was created without a REVOKE and inherited
-- Postgres' default GRANT EXECUTE TO PUBLIC. Its ACL was:
--   {=X/postgres, postgres=X/postgres, anon=X/postgres, authenticated=X/postgres, service_role=X/postgres}
--
-- ---------------------------------------------------------------------------
-- Why the guard here differs from F-1's
-- ---------------------------------------------------------------------------
-- credit_wallet_for_refund is only ever called by workers and by a SECURITY DEFINER
-- reaper, so "reject any JWT that is not service_role" was sufficient there.
--
-- The debit is different: it is called from INSIDE two user-facing SECURITY DEFINER
-- RPCs, request_esim_purchase() and pay_plan_fee_from_wallet(), which a signed-in
-- user invokes directly. request.jwt.claims is a transaction-scoped setting, so it
-- still reads role=authenticated inside those nested calls. Copying F-1's guard
-- verbatim would have blocked every eSIM purchase and every wallet-funded plan fee.
--
-- The discriminator used instead is call depth: a PostgREST RPC call is always the
-- top plpgsql frame, an internal call never is. GET DIAGNOSTICS PG_CONTEXT returns
-- one line per frame, so a JWT-bearing caller is allowed only when it arrived
-- through another server-side function (which does its own ownership and pricing
-- checks). Verified: top-level = 1 frame, nested = 2+.
--
-- Both overloads are kept. The review suggested dropping the 5-arg one, but
-- track_functions is off on this database so there is no call-count evidence for
-- which overload PostgREST resolves for worker_instant_refill.js and the
-- wallet_transact Edge Function, and guessing wrong breaks the primary refill path.
-- Instead both are locked to service_role, both are guarded, and
-- f2_debit_wallet_grant_tests.sql pins the overload count at 2 so a third cannot
-- appear unnoticed.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 5-arg overload (already service_role-only; gains the guard for symmetry)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.debit_wallet_for_topup(
  p_user_id UUID,
  p_sim_line_id UUID,
  p_amount NUMERIC,
  p_description TEXT DEFAULT 'SIM top-up',
  p_reference_id TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_raw_claims TEXT;
  v_jwt_role TEXT;
  v_ctx TEXT;
  v_wallet_id UUID;
  v_balance_before NUMERIC;
  v_balance_after NUMERIC;
  v_txn_id UUID;
BEGIN
  v_raw_claims := current_setting('request.jwt.claims', true);
  IF v_raw_claims IS NOT NULL AND v_raw_claims <> '' THEN
    v_jwt_role := (v_raw_claims::jsonb) ->> 'role';
    IF v_jwt_role IS DISTINCT FROM 'service_role' THEN
      GET DIAGNOSTICS v_ctx = PG_CONTEXT;
      IF coalesce(array_length(string_to_array(v_ctx, E'\n'), 1), 1) < 2 THEN
        RAISE EXCEPTION 'debit_wallet_for_topup is not directly callable by role %', COALESCE(v_jwt_role, '<none>')
          USING ERRCODE = 'KS403';
      END IF;
    END IF;
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Debit amount must be positive, got %', p_amount;
  END IF;

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

  UPDATE public.wallets
  SET balance = v_balance_after,
      total_spent = total_spent + p_amount
  WHERE id = v_wallet_id;

  -- A duplicate p_reference_id raises unique_violation and rolls the whole debit
  -- back (idempotency per execution).
  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, amount, balance_before, balance_after,
    description, reference_id, sim_line_id, status
  ) VALUES (
    v_wallet_id, p_user_id, 'topup_debit', p_amount, v_balance_before, v_balance_after,
    p_description, p_reference_id, p_sim_line_id, 'completed'
  ) RETURNING id INTO v_txn_id;

  RETURN v_txn_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- 6-arg overload — this is the one that was open to PUBLIC/anon
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.debit_wallet_for_topup(
  p_user_id UUID,
  p_sim_line_id UUID,
  p_amount NUMERIC,
  p_description TEXT DEFAULT 'SIM top-up',
  p_reference_id TEXT DEFAULT NULL,
  p_txn_type TEXT DEFAULT 'topup_debit'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_raw_claims TEXT;
  v_jwt_role TEXT;
  v_ctx TEXT;
  v_wallet_id UUID;
  v_balance_before NUMERIC;
  v_balance_after NUMERIC;
  v_txn_id UUID;
BEGIN
  v_raw_claims := current_setting('request.jwt.claims', true);
  IF v_raw_claims IS NOT NULL AND v_raw_claims <> '' THEN
    v_jwt_role := (v_raw_claims::jsonb) ->> 'role';
    IF v_jwt_role IS DISTINCT FROM 'service_role' THEN
      GET DIAGNOSTICS v_ctx = PG_CONTEXT;
      IF coalesce(array_length(string_to_array(v_ctx, E'\n'), 1), 1) < 2 THEN
        RAISE EXCEPTION 'debit_wallet_for_topup is not directly callable by role %', COALESCE(v_jwt_role, '<none>')
          USING ERRCODE = 'KS403';
      END IF;
    END IF;
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Debit amount must be positive, got %', p_amount;
  END IF;

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

  UPDATE public.wallets
  SET balance = v_balance_after,
      total_spent = total_spent + p_amount
  WHERE id = v_wallet_id;

  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, amount, balance_before, balance_after,
    description, reference_id, sim_line_id, status
  ) VALUES (
    v_wallet_id, p_user_id, COALESCE(p_txn_type, 'topup_debit'), p_amount, v_balance_before, v_balance_after,
    p_description, p_reference_id, p_sim_line_id, 'completed'
  ) RETURNING id INTO v_txn_id;

  RETURN v_txn_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- Grants. Signature-qualified: an unqualified REVOKE on an overloaded name errors
-- out, and getting this wrong on the 6-arg signature is precisely what F-2 was.
-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.debit_wallet_for_topup(UUID, UUID, NUMERIC, TEXT, TEXT)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.debit_wallet_for_topup(UUID, UUID, NUMERIC, TEXT, TEXT)
  TO service_role;

REVOKE ALL ON FUNCTION public.debit_wallet_for_topup(UUID, UUID, NUMERIC, TEXT, TEXT, TEXT)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.debit_wallet_for_topup(UUID, UUID, NUMERIC, TEXT, TEXT, TEXT)
  TO service_role;

COMMENT ON FUNCTION public.debit_wallet_for_topup(UUID, UUID, NUMERIC, TEXT, TEXT) IS
  'Debits a wallet for a top-up. service_role ONLY, or nested inside another server-side '
  'function. Never grant to anon/authenticated — see F-2 in doc/PRODUCTION_PLAN_REVIEW.md; '
  'regression test supabase/tests/f2_debit_wallet_grant_tests.sql.';

COMMENT ON FUNCTION public.debit_wallet_for_topup(UUID, UUID, NUMERIC, TEXT, TEXT, TEXT) IS
  'Debits a wallet for a top-up with a caller-chosen ledger type. service_role ONLY, or '
  'nested inside another server-side function (request_esim_purchase, pay_plan_fee_from_wallet). '
  'This overload was EXECUTE-to-PUBLIC until 2026-07-29 — see F-2 in '
  'doc/PRODUCTION_PLAN_REVIEW.md; regression test supabase/tests/f2_debit_wallet_grant_tests.sql.';
