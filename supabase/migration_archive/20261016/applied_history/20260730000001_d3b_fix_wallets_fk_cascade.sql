-- D3b: Fix foreign key delete actions and secure RPCs for account deletion pipeline.
--
-- Compliance with D3 Design §2 ("anonymise the money, delete the person"):
-- All financial and audit tables (wallets, wallet_transactions, plan_payments, esim_orders, etc.)
-- use ON DELETE SET NULL so financial transaction records are preserved upon user purge.

-- 1. Restore FK constraints to ON DELETE SET NULL
ALTER TABLE public.wallets
  DROP CONSTRAINT IF EXISTS wallets_user_id_fkey,
  ADD CONSTRAINT wallets_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.security_logs
  DROP CONSTRAINT IF EXISTS security_logs_user_id_fkey,
  ADD CONSTRAINT security_logs_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.referral_points
  DROP CONSTRAINT IF EXISTS referral_points_referrer_id_fkey,
  ADD CONSTRAINT referral_points_referrer_id_fkey
    FOREIGN KEY (referrer_id) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.referral_points
  DROP CONSTRAINT IF EXISTS referral_points_referred_user_id_fkey,
  ADD CONSTRAINT referral_points_referred_user_id_fkey
    FOREIGN KEY (referred_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.referrals
  DROP CONSTRAINT IF EXISTS referrals_referrer_id_fkey,
  ADD CONSTRAINT referrals_referrer_id_fkey
    FOREIGN KEY (referrer_id) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.referrals
  DROP CONSTRAINT IF EXISTS referrals_referred_user_id_fkey,
  ADD CONSTRAINT referrals_referred_user_id_fkey
    FOREIGN KEY (referred_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.wallet_transactions
  DROP CONSTRAINT IF EXISTS wallet_transactions_user_id_fkey,
  ADD CONSTRAINT wallet_transactions_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.plan_payments
  DROP CONSTRAINT IF EXISTS plan_payments_user_id_fkey,
  ADD CONSTRAINT plan_payments_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.esim_orders
  DROP CONSTRAINT IF EXISTS esim_orders_user_id_fkey,
  ADD CONSTRAINT esim_orders_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.user_esims
  DROP CONSTRAINT IF EXISTS user_esims_user_id_fkey,
  ADD CONSTRAINT user_esims_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.topup_executions
  DROP CONSTRAINT IF EXISTS topup_executions_user_id_fkey,
  ADD CONSTRAINT topup_executions_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

-- 2. Guarded RPC for purge-accounts Edge Function (v8)
CREATE OR REPLACE FUNCTION public.delete_auth_user_by_id(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status text;
BEGIN
  -- GUARD: Refuse any user_id whose account_deletions.status <> 'purged'
  SELECT status INTO v_status
  FROM public.account_deletions
  WHERE user_id = p_user_id
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_status IS NULL OR v_status <> 'purged' THEN
    RAISE EXCEPTION 'FORBIDDEN: User account status is not purged (current status: %)', COALESCE(v_status, 'none')
      USING ERRCODE = '42501';
  END IF;

  -- Delete dependent rows without FK (like user_preferences)
  DELETE FROM public.user_preferences WHERE user_id = p_user_id;

  -- Delete auth user
  DELETE FROM auth.users WHERE id = p_user_id;
END;
$$;

-- REVOKE FROM PUBLIC, anon, and authenticated
REVOKE EXECUTE ON FUNCTION public.delete_auth_user_by_id(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.delete_auth_user_by_id(uuid) TO service_role;

-- 3. Fallback verification RPC
CREATE OR REPLACE FUNCTION public.check_auth_user_exists(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_exists boolean;
BEGIN
  SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = p_user_id) INTO v_exists;
  RETURN v_exists;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.check_auth_user_exists(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_auth_user_exists(uuid) TO service_role;
