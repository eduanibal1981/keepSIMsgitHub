-- D3b: Fix foreign key delete actions so auth.users DELETE (from purge-accounts Edge Function)
-- is never blocked by orphaned rows in public tables.
--
-- wallets: CASCADE (wallet row itself should be removed when auth user is deleted)
-- All other audit/history tables: SET NULL (preserve the row for auditing, just detach the FK)

-- wallets.user_id → CASCADE
ALTER TABLE public.wallets
  DROP CONSTRAINT IF EXISTS wallets_user_id_fkey,
  ADD CONSTRAINT wallets_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- security_logs.user_id → SET NULL
ALTER TABLE public.security_logs
  DROP CONSTRAINT IF EXISTS security_logs_user_id_fkey,
  ADD CONSTRAINT security_logs_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

-- referral_points.referrer_id → SET NULL
ALTER TABLE public.referral_points
  DROP CONSTRAINT IF EXISTS referral_points_referrer_id_fkey,
  ADD CONSTRAINT referral_points_referrer_id_fkey
    FOREIGN KEY (referrer_id) REFERENCES auth.users(id) ON DELETE SET NULL;

-- referral_points.referred_user_id → SET NULL
ALTER TABLE public.referral_points
  DROP CONSTRAINT IF EXISTS referral_points_referred_user_id_fkey,
  ADD CONSTRAINT referral_points_referred_user_id_fkey
    FOREIGN KEY (referred_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

-- referrals.referrer_id → SET NULL
ALTER TABLE public.referrals
  DROP CONSTRAINT IF EXISTS referrals_referrer_id_fkey,
  ADD CONSTRAINT referrals_referrer_id_fkey
    FOREIGN KEY (referrer_id) REFERENCES auth.users(id) ON DELETE SET NULL;

-- referrals.referred_user_id → SET NULL
ALTER TABLE public.referrals
  DROP CONSTRAINT IF EXISTS referrals_referred_user_id_fkey,
  ADD CONSTRAINT referrals_referred_user_id_fkey
    FOREIGN KEY (referred_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

-- wallet_transactions.user_id → SET NULL
ALTER TABLE public.wallet_transactions
  DROP CONSTRAINT IF EXISTS wallet_transactions_user_id_fkey,
  ADD CONSTRAINT wallet_transactions_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

-- plan_payments.user_id → SET NULL
ALTER TABLE public.plan_payments
  DROP CONSTRAINT IF EXISTS plan_payments_user_id_fkey,
  ADD CONSTRAINT plan_payments_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

-- esim_orders.user_id → SET NULL
ALTER TABLE public.esim_orders
  DROP CONSTRAINT IF EXISTS esim_orders_user_id_fkey,
  ADD CONSTRAINT esim_orders_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

-- user_esims.user_id → SET NULL
ALTER TABLE public.user_esims
  DROP CONSTRAINT IF EXISTS user_esims_user_id_fkey,
  ADD CONSTRAINT user_esims_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

-- topup_executions.user_id → SET NULL
ALTER TABLE public.topup_executions
  DROP CONSTRAINT IF EXISTS topup_executions_user_id_fkey,
  ADD CONSTRAINT topup_executions_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

---

-- Helper SQL RPCs for purge-accounts Edge Function (v7+)
-- delete_auth_user_by_id: Deletes user via direct SQL instead of GoTrue Admin API
-- (bypasses GoTrue "Database error loading user" 500 bug with synthetic users)
CREATE OR REPLACE FUNCTION public.delete_auth_user_by_id(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Delete dependent rows not covered by CASCADE FKs
  DELETE FROM public.user_preferences WHERE user_id = p_user_id;

  -- Delete auth user (CASCADE FKs handle identities, sessions, profiles, etc.)
  DELETE FROM auth.users WHERE id = p_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_auth_user_by_id(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_auth_user_by_id(uuid) TO service_role;

-- check_auth_user_exists: Returns true if user still exists in auth.users (fallback check)
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

REVOKE ALL ON FUNCTION public.check_auth_user_exists(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_auth_user_exists(uuid) TO service_role;
