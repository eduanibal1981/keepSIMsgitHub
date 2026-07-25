-- Migration: 20260729000000_d3_account_deletion.sql
-- Description: D3 Account Deletion State Machine, FK SET NULL Anonymisation, GDPR Data Export & Cron Schedules

-- ── 1. Create account_deletions Table ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.account_deletions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid UNIQUE,
  email_hash text NOT NULL,
  status text NOT NULL DEFAULT 'requested'
    CHECK (status IN ('requested', 'frozen', 'draining', 'drained', 'purged', 'auth_deleted', 'cancelled')),
  wallet_balance_at_request numeric(10,2) NOT NULL DEFAULT 0.00,
  dust_forfeited boolean NOT NULL DEFAULT false,
  reason text,
  actor_id uuid,
  ip_address text,
  requested_at timestamptz NOT NULL DEFAULT now(),
  scheduled_purge_at timestamptz NOT NULL,
  frozen_at timestamptz,
  drained_at timestamptz,
  purged_at timestamptz,
  auth_deleted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.account_deletions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "account_deletions_select_own" ON public.account_deletions;
CREATE POLICY "account_deletions_select_own" ON public.account_deletions
  FOR SELECT USING (auth.uid() = user_id);

-- Client writes strictly denied.

-- ── 2. Create retired_referral_codes Table ───────────────────────────────────
CREATE TABLE IF NOT EXISTS public.retired_referral_codes (
  code text PRIMARY KEY,
  retired_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.retired_referral_codes ENABLE ROW LEVEL SECURITY;
-- Read-only system table.

-- ── 3. FK Cascade Adjustments (CASCADE → SET NULL) ───────────────────────────

-- 3a. wallets
ALTER TABLE public.wallets
  ALTER COLUMN user_id DROP NOT NULL,
  DROP CONSTRAINT IF EXISTS wallets_user_id_fkey,
  ADD CONSTRAINT wallets_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

-- 3b. wallet_transactions
ALTER TABLE public.wallet_transactions
  DROP CONSTRAINT IF EXISTS wallet_transactions_user_id_fkey,
  ADD CONSTRAINT wallet_transactions_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

-- 3c. plan_payments
ALTER TABLE public.plan_payments
  DROP CONSTRAINT IF EXISTS plan_payments_user_id_fkey,
  ADD CONSTRAINT plan_payments_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

-- 3d. esim_orders
ALTER TABLE public.esim_orders
  DROP CONSTRAINT IF EXISTS esim_orders_user_id_fkey,
  ADD CONSTRAINT esim_orders_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

-- 3e. user_esims
ALTER TABLE public.user_esims
  DROP CONSTRAINT IF EXISTS user_esims_user_id_fkey,
  ADD CONSTRAINT user_esims_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

-- 3f. topup_executions
ALTER TABLE public.topup_executions
  DROP CONSTRAINT IF EXISTS topup_executions_user_id_fkey,
  ADD CONSTRAINT topup_executions_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

-- 3g. referral_points (Fix C5 referred user deletion bug)
ALTER TABLE public.referral_points
  DROP CONSTRAINT IF EXISTS referral_points_referrer_id_fkey,
  ADD CONSTRAINT referral_points_referrer_id_fkey
    FOREIGN KEY (referrer_id) REFERENCES auth.users(id) ON DELETE SET NULL,
  DROP CONSTRAINT IF EXISTS referral_points_referred_user_id_fkey,
  ADD CONSTRAINT referral_points_referred_user_id_fkey
    FOREIGN KEY (referred_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

-- 3h. referrals
ALTER TABLE public.referrals
  DROP CONSTRAINT IF EXISTS referrals_referrer_id_fkey,
  ADD CONSTRAINT referrals_referrer_id_fkey
    FOREIGN KEY (referrer_id) REFERENCES auth.users(id) ON DELETE SET NULL,
  DROP CONSTRAINT IF EXISTS referrals_referred_user_id_fkey,
  ADD CONSTRAINT referrals_referred_user_id_fkey
    FOREIGN KEY (referred_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

-- ── 4. System Config Seeds ───────────────────────────────────────────────────
INSERT INTO public.system_configs (config_key, config_value) VALUES
  ('ACCOUNT_DELETION_GRACE_DAYS', '14'),
  ('WALLET_DUST_FORFEIT_USD', '1.00'),
  ('RATE_LIMIT_ACCOUNT_DELETE', '3/1440'),
  ('RATE_LIMIT_DATA_EXPORT', '2/1440')
ON CONFLICT (config_key) DO UPDATE SET config_value = EXCLUDED.config_value;

-- ── 5. Drive-by #3 & #7 Fixes ───────────────────────────────────────────────────

-- Drive-by #3: Fix check_topup_rate_limit trigger to key on auth.uid() when available
-- so service_role offline refills (where auth.uid() IS NULL) bypass user rate limit.
CREATE OR REPLACE FUNCTION public.check_topup_rate_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_effective_user_id text;
BEGIN
  -- Determine effective user ID: use auth.uid() if present, else omit user rate limit for service_role
  IF auth.uid() IS NOT NULL THEN
    v_effective_user_id := auth.uid()::text;
    PERFORM public.enforce_rate_limit('instant_refill', v_effective_user_id);
  END IF;

  -- 10-second per-SIM line cooldown check (applies to all inserts)
  IF EXISTS (
    SELECT 1 FROM public.topup_executions
    WHERE sim_line_id = NEW.sim_line_id
      AND created_at > (clock_timestamp() - INTERVAL '10 seconds')
  ) THEN
    RAISE EXCEPTION 'COOLDOWN_ACTIVE: Please wait 10 seconds between refill requests for line %', NEW.sim_line_id;
  END IF;

  RETURN NEW;
END;
$$;

-- Drive-by #7: Lock down stray public storage bucket support_attachments if present
UPDATE storage.buckets
SET public = false
WHERE id = 'support_attachments';

-- ── 6. Account Deletion RPCs ──────────────────────────────────────────────────

-- 6a. request_account_deletion
CREATE OR REPLACE FUNCTION public.request_account_deletion(
  p_reason text DEFAULT NULL,
  p_forfeit_dust boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_email text;
  v_email_hash text;
  v_balance numeric(10,2) := 0.00;
  v_grace_days int := 14;
  v_dust_limit numeric(10,2) := 1.00;
  v_scheduled_purge timestamptz;
  v_existing RECORD;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  -- Enforce rate limit
  PERFORM public.enforce_rate_limit('account_delete', v_user_id::text);

  -- Check if already requested
  SELECT * INTO v_existing
  FROM public.account_deletions
  WHERE user_id = v_user_id AND status IN ('requested', 'frozen', 'draining');

  IF FOUND THEN
    RETURN jsonb_build_object(
      'success', true,
      'already_requested', true,
      'status', v_existing.status,
      'scheduled_purge_at', v_existing.scheduled_purge_at,
      'wallet_balance', v_existing.wallet_balance_at_request
    );
  END IF;

  -- Fetch user email
  SELECT email INTO v_email FROM auth.users WHERE id = v_user_id;
  IF v_email IS NULL THEN
    v_email := v_user_id::text || '@deleted.local';
  END IF;
  v_email_hash := encode(sha256(lower(trim(v_email))::bytea), 'hex');

  -- Fetch current wallet balance
  SELECT COALESCE(balance, 0.00) INTO v_balance
  FROM public.wallets
  WHERE user_id = v_user_id;

  -- Read config seeds
  BEGIN
    SELECT config_value::int INTO v_grace_days
    FROM public.system_configs WHERE config_key = 'ACCOUNT_DELETION_GRACE_DAYS';
  EXCEPTION WHEN OTHERS THEN v_grace_days := 14; END;
  IF v_grace_days IS NULL OR v_grace_days <= 0 THEN v_grace_days := 14; END IF;

  BEGIN
    SELECT config_value::numeric INTO v_dust_limit
    FROM public.system_configs WHERE config_key = 'WALLET_DUST_FORFEIT_USD';
  EXCEPTION WHEN OTHERS THEN v_dust_limit := 1.00; END;
  IF v_dust_limit IS NULL THEN v_dust_limit := 1.00; END IF;

  -- Balance policy check
  IF v_balance >= v_dust_limit AND NOT p_forfeit_dust THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'WALLET_BALANCE_EXCEEDS_DUST_LIMIT',
      'error', 'Wallet balance exceeds dust limit ($' || v_dust_limit::text || '). Please spend your balance or contact support.',
      'wallet_balance', v_balance,
      'dust_limit', v_dust_limit
    );
  END IF;

  v_scheduled_purge := clock_timestamp() + (v_grace_days || ' days')::interval;

  -- Create deletion record
  INSERT INTO public.account_deletions (
    user_id, email_hash, status, wallet_balance_at_request,
    dust_forfeited, reason, actor_id, scheduled_purge_at
  ) VALUES (
    v_user_id, v_email_hash, 'requested', v_balance,
    (v_balance < v_dust_limit AND p_forfeit_dust), p_reason, v_user_id, v_scheduled_purge
  );

  -- Immediate freeze actions
  UPDATE public.profiles SET is_suspended = true WHERE id = v_user_id;
  UPDATE public.scheduled_topups SET is_active = false WHERE sim_line_id IN (
    SELECT id FROM public.sim_lines WHERE user_id = v_user_id
  );

  -- Cancel pending non-routing topups
  PERFORM public.cancel_topup_execution(id)
  FROM public.topup_executions
  WHERE user_id = v_user_id AND status IN ('pending', 'pending_payment');

  RETURN jsonb_build_object(
    'success', true,
    'status', 'requested',
    'scheduled_purge_at', v_scheduled_purge,
    'wallet_balance', v_balance,
    'grace_days', v_grace_days
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.request_account_deletion(text, boolean) TO authenticated;

-- 6b. cancel_account_deletion
CREATE OR REPLACE FUNCTION public.cancel_account_deletion()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_existing RECORD;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  SELECT * INTO v_existing
  FROM public.account_deletions
  WHERE user_id = v_user_id AND status IN ('requested', 'frozen');

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'No active pending account deletion found.');
  END IF;

  IF v_existing.scheduled_purge_at <= clock_timestamp() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Grace period has expired. Deletion is already in progress.');
  END IF;

  UPDATE public.account_deletions
  SET status = 'cancelled', updated_at = clock_timestamp()
  WHERE id = v_existing.id;

  -- Re-enable profile
  UPDATE public.profiles SET is_suspended = false WHERE id = v_user_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.cancel_account_deletion() TO authenticated;

-- ── 7. State-Machine Purge Function ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.purge_deleted_accounts()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  rec RECORD;
  v_in_flight_count int;
  v_secret text;
  v_purged_count int := 0;
  v_ref_code text;
BEGIN
  -- 1. Advance 'requested' to 'frozen' when scheduled_purge_at <= now()
  UPDATE public.account_deletions
  SET status = 'frozen', frozen_at = clock_timestamp(), updated_at = clock_timestamp()
  WHERE status = 'requested' AND scheduled_purge_at <= clock_timestamp();

  -- 2. Process 'frozen' accounts -> 'draining' / 'drained'
  FOR rec IN SELECT * FROM public.account_deletions WHERE status IN ('frozen', 'draining') LOOP
    -- Drain check: refuse to advance if executions are routing or eSIM orders pending
    SELECT COUNT(*) INTO v_in_flight_count
    FROM public.topup_executions
    WHERE user_id = rec.user_id AND status = 'routing';

    IF v_in_flight_count = 0 THEN
      SELECT COUNT(*) INTO v_in_flight_count
      FROM public.esim_orders
      WHERE user_id = rec.user_id AND status IN ('pending', 'processing');
    END IF;

    IF v_in_flight_count > 0 THEN
      -- Stay in frozen/draining state, alert if stuck > 72h
      IF rec.scheduled_purge_at < (clock_timestamp() - INTERVAL '72 hours') THEN
        INSERT INTO public.system_alerts (kind, message, details)
        VALUES (
          'account_purge_stuck',
          'Account deletion stuck in draining state >72h for user ' || rec.user_id::text,
          jsonb_build_object('user_id', rec.user_id, 'in_flight_count', v_in_flight_count)
        );
      END IF;
      CONTINUE; -- Skip purge for this user on this sweep
    END IF;

    -- Update to draining
    UPDATE public.account_deletions
    SET status = 'draining', drained_at = COALESCE(drained_at, clock_timestamp()), updated_at = clock_timestamp()
    WHERE id = rec.id;

    -- 3. Perform Purge & Anonymisation
    -- Capture referral code for tombstoning
    SELECT referral_code INTO v_ref_code FROM public.profiles WHERE id = rec.user_id;
    IF v_ref_code IS NOT NULL AND length(trim(v_ref_code)) > 0 THEN
      INSERT INTO public.retired_referral_codes (code) VALUES (upper(trim(v_ref_code)))
      ON CONFLICT DO NOTHING;
    END IF;

    -- Anonymise financial & ledger tables
    UPDATE public.wallets SET user_id = NULL WHERE user_id = rec.user_id;
    UPDATE public.wallet_transactions SET user_id = NULL WHERE user_id = rec.user_id;
    UPDATE public.plan_payments SET user_id = NULL WHERE user_id = rec.user_id;
    UPDATE public.esim_orders SET user_id = NULL WHERE user_id = rec.user_id;
    UPDATE public.user_esims SET user_id = NULL WHERE user_id = rec.user_id;
    UPDATE public.topup_executions SET user_id = NULL WHERE user_id = rec.user_id;

    -- Delete operational tables
    DELETE FROM public.line_activity_log WHERE sim_line_id IN (SELECT id FROM public.sim_lines WHERE user_id = rec.user_id);
    DELETE FROM public.scheduled_topups WHERE sim_line_id IN (SELECT id FROM public.sim_lines WHERE user_id = rec.user_id);
    DELETE FROM public.offline_refill_settings WHERE user_id = rec.user_id;
    DELETE FROM public.sim_lines WHERE user_id = rec.user_id;
    DELETE FROM public.ticket_messages WHERE user_id = rec.user_id OR ticket_id IN (SELECT id FROM public.support_tickets WHERE user_id = rec.user_id);
    DELETE FROM public.support_tickets WHERE user_id = rec.user_id;
    DELETE FROM public.alert_settings WHERE user_id = rec.user_id;
    DELETE FROM public.notification_channels WHERE user_id = rec.user_id;
    DELETE FROM public.notifications WHERE user_id = rec.user_id;
    DELETE FROM public.device_push_tokens WHERE user_id = rec.user_id;

    UPDATE public.account_deletions
    SET status = 'purged', purged_at = clock_timestamp(), updated_at = clock_timestamp()
    WHERE id = rec.id;

    v_purged_count := v_purged_count + 1;

    -- 4. Invoke purge-accounts Edge Function via pg_net to delete auth user & storage objects
    SELECT decrypted_secret INTO v_secret
    FROM vault.decrypted_secrets WHERE name = 'dispatch_shared_secret' LIMIT 1;

    PERFORM net.http_post(
      url := 'https://zwxswagokhgbuzrrbnhr.supabase.co/functions/v1/purge-accounts',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-keep-sims-secret', COALESCE(v_secret, '')
      ),
      body := jsonb_build_object('user_id', rec.user_id)
    );
  END LOOP;

  RETURN jsonb_build_object('success', true, 'purged_count', v_purged_count);
END;
$$;

-- ── 8. GDPR Data Export RPC ───────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.export_user_data()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_profile jsonb;
  v_sim_lines jsonb;
  v_schedules jsonb;
  v_executions jsonb;
  v_wallet jsonb;
  v_wallet_txns jsonb;
  v_plan_payments jsonb;
  v_esim_orders jsonb;
  v_user_esims jsonb;
  v_referral_points jsonb;
  v_referral_redemptions jsonb;
  v_notifications jsonb;
  v_alert_settings jsonb;
  v_channels jsonb;
  v_tickets jsonb;
  v_push_tokens jsonb;
  v_security_logs jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  -- Rate limit check (2 / 24h)
  PERFORM public.enforce_rate_limit('data_export', v_user_id::text);

  SELECT to_jsonb(p) INTO v_profile FROM public.profiles p WHERE id = v_user_id;
  SELECT COALESCE(jsonb_agg(to_jsonb(l)), '[]'::jsonb) INTO v_sim_lines FROM public.sim_lines l WHERE user_id = v_user_id;
  SELECT COALESCE(jsonb_agg(to_jsonb(s)), '[]'::jsonb) INTO v_schedules FROM public.scheduled_topups s WHERE sim_line_id IN (SELECT id FROM public.sim_lines WHERE user_id = v_user_id);
  SELECT COALESCE(jsonb_agg(to_jsonb(e)), '[]'::jsonb) INTO v_executions FROM public.topup_executions e WHERE user_id = v_user_id;
  SELECT to_jsonb(w) INTO v_wallet FROM public.wallets w WHERE user_id = v_user_id;
  SELECT COALESCE(jsonb_agg(to_jsonb(wt)), '[]'::jsonb) INTO v_wallet_txns FROM public.wallet_transactions wt WHERE user_id = v_user_id;
  SELECT COALESCE(jsonb_agg(to_jsonb(pp)), '[]'::jsonb) INTO v_plan_payments FROM public.plan_payments pp WHERE user_id = v_user_id;
  SELECT COALESCE(jsonb_agg(to_jsonb(eo)), '[]'::jsonb) INTO v_esim_orders FROM public.esim_orders eo WHERE user_id = v_user_id;
  SELECT COALESCE(jsonb_agg(to_jsonb(ue)), '[]'::jsonb) INTO v_user_esims FROM public.user_esims ue WHERE user_id = v_user_id;
  SELECT COALESCE(jsonb_agg(to_jsonb(rp)), '[]'::jsonb) INTO v_referral_points FROM public.referral_points rp WHERE referrer_id = v_user_id;
  SELECT COALESCE(jsonb_agg(to_jsonb(rr)), '[]'::jsonb) INTO v_referral_redemptions FROM public.referral_redemptions rr WHERE user_id = v_user_id;
  SELECT COALESCE(jsonb_agg(to_jsonb(n)), '[]'::jsonb) INTO v_notifications FROM public.notifications n WHERE user_id = v_user_id;
  SELECT COALESCE(jsonb_agg(to_jsonb(a)), '[]'::jsonb) INTO v_alert_settings FROM public.alert_settings a WHERE user_id = v_user_id;
  SELECT COALESCE(jsonb_agg(to_jsonb(c)), '[]'::jsonb) INTO v_channels FROM public.notification_channels c WHERE user_id = v_user_id;
  SELECT COALESCE(jsonb_agg(to_jsonb(t)), '[]'::jsonb) INTO v_tickets FROM public.support_tickets t WHERE user_id = v_user_id;
  SELECT COALESCE(jsonb_agg(to_jsonb(d)), '[]'::jsonb) INTO v_push_tokens FROM public.device_push_tokens d WHERE user_id = v_user_id;
  SELECT COALESCE(jsonb_agg(to_jsonb(sl)), '[]'::jsonb) INTO v_security_logs FROM public.security_logs sl WHERE user_id = v_user_id;

  RETURN jsonb_build_object(
    'exported_at', clock_timestamp(),
    'user_id', v_user_id,
    'profile', v_profile,
    'sim_lines', v_sim_lines,
    'scheduled_topups', v_schedules,
    'topup_executions', v_executions,
    'wallet', v_wallet,
    'wallet_transactions', v_wallet_txns,
    'plan_payments', v_plan_payments,
    'esim_orders', v_esim_orders,
    'user_esims', v_user_esims,
    'referral_points', v_referral_points,
    'referral_redemptions', v_referral_redemptions,
    'notifications', v_notifications,
    'alert_settings', v_alert_settings,
    'notification_channels', v_channels,
    'support_tickets', v_tickets,
    'device_push_tokens', v_push_tokens,
    'security_logs', v_security_logs
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.export_user_data() TO authenticated;

-- ── 9. Schedule Cron Jobs in Migration (Drive-by #4 & D3) ───────────────────
SELECT cron.schedule('purge-deleted-accounts-hourly', '0 * * * *', 'SELECT public.purge_deleted_accounts();')
WHERE NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'purge-deleted-accounts-hourly');

SELECT cron.schedule('check-rate-limit-health', '30 * * * *', 'SELECT public.check_rate_limit_health();')
WHERE NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'check-rate-limit-health');

SELECT cron.schedule('prune-rate-limit-data', '0 3 * * *', 'SELECT public.prune_rate_limit_data();')
WHERE NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'prune-rate-limit-data');
