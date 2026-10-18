-- A4 security sweep (Phase A closeout).
-- Sources: Supabase security advisor run 2026-07-16 + manual RLS/function audit.
--
-- 1. Pin search_path on every function the linter flagged.
-- 2. Add ownership checks to client-callable SECURITY DEFINER RPCs that
--    trusted their arguments (IDOR): get_wallet_forecast,
--    reschedule_mini_refill, reset_mini_refill_to_default, apply_referral.
--    Service-role calls (auth.uid() IS NULL) stay unrestricted — workers use
--    these RPCs.
-- 3. Revoke client EXECUTE on trigger-only and server-only functions.
-- 4. sim_line_details_view -> security_invoker.
-- 5. Storage: drop world-listing policy on support_attachments; per-user
--    folder scoping (app uploads to "<user_id>/<file>").
-- 6. Money constraints: CHECK (amount > 0) on ledger + execution + schedule
--    amounts. wallet_transactions constraint is NOT VALID: one legacy $0
--    "Simulated Auto-Refill" test row (d41a37a3) predates it.
-- 7. Policy tightening: profiles readable only by self/household/power user
--    (was: every authenticated user could read all profiles);
--    test_cases restricted to power users (was: any authenticated user);
--    drop client DELETE on topup_executions (audit trail).

-- ---------------------------------------------------------------
-- 1. search_path pinning
-- ---------------------------------------------------------------
ALTER FUNCTION public.calculate_topup_fees() SET search_path = 'public';
ALTER FUNCTION public.check_free_lines_limit() SET search_path = 'public';
ALTER FUNCTION public.check_topup_rate_limit() SET search_path = 'public';
ALTER FUNCTION public.deduct_wallet_atomic(uuid, numeric) SET search_path = 'public';
ALTER FUNCTION public.get_current_context() SET search_path = 'public';
ALTER FUNCTION public.handle_new_household_member() SET search_path = 'public';
ALTER FUNCTION public.is_user_suspended() SET search_path = 'public';
ALTER FUNCTION public.process_due_notifications() SET search_path = 'public';
ALTER FUNCTION public.protect_is_power_user() SET search_path = 'public';
ALTER FUNCTION public.refund_wallet_atomic(uuid, numeric) SET search_path = 'public';
ALTER FUNCTION public.reschedule_mini_refill(uuid, timestamp with time zone) SET search_path = 'public';
ALTER FUNCTION public.reset_mini_refill_to_default(uuid) SET search_path = 'public';
ALTER FUNCTION public.resolve_pending_household_invites() SET search_path = 'public';
ALTER FUNCTION public.route_topup_execution() SET search_path = 'public';
ALTER FUNCTION public.schedule_delayed_notification(uuid, text, text, text, integer) SET search_path = 'public';
ALTER FUNCTION public.sync_power_user_claim() SET search_path = 'public';
ALTER FUNCTION public.sync_suspended_claim() SET search_path = 'public';
ALTER FUNCTION public.trg_fn_dispatch_notification() SET search_path = 'public';
ALTER FUNCTION public.trg_scheduled_topup_health_sync() SET search_path = 'public';
ALTER FUNCTION public.update_line_health() SET search_path = 'public';
ALTER FUNCTION public.update_sim_line_last_topup_at() SET search_path = 'public';
ALTER FUNCTION public.update_test_cases_updated_at() SET search_path = 'public';
ALTER FUNCTION public.update_updated_at() SET search_path = 'public';

-- ---------------------------------------------------------------
-- 2. Ownership checks in client-callable SECURITY DEFINER RPCs
-- ---------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_wallet_forecast(p_user_id uuid)
 RETURNS TABLE(current_balance numeric, avg_daily_spend numeric, estimated_days_remaining integer, active_lines_count integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_balance NUMERIC;
  v_30d_spend NUMERIC;
  v_daily_avg NUMERIC;
  v_lines INTEGER;
BEGIN
  -- Clients may only query their own forecast; service role (no JWT) is free.
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_id THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT w.balance INTO v_balance
  FROM public.wallets w
  WHERE w.user_id = p_user_id;

  SELECT COUNT(*) INTO v_lines
  FROM public.sim_lines sl
  WHERE sl.user_id = p_user_id AND sl.status = 'active';

  SELECT COALESCE(SUM(wt.amount), 0) INTO v_30d_spend
  FROM public.wallet_transactions wt
  WHERE wt.user_id = p_user_id
    AND wt.type = 'topup_debit'
    AND wt.status = 'completed'
    AND wt.created_at >= NOW() - INTERVAL '30 days';

  v_daily_avg := v_30d_spend / 30.0;

  RETURN QUERY SELECT
    COALESCE(v_balance, 0.00),
    ROUND(COALESCE(v_daily_avg, 0.00), 2),
    CASE WHEN v_daily_avg > 0 THEN (v_balance / v_daily_avg)::INTEGER ELSE 9999 END,
    COALESCE(v_lines, 0);
END;
$function$;

CREATE OR REPLACE FUNCTION public.reschedule_mini_refill(p_sim_line_id uuid, p_new_date timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  -- Owner or accepted household manager only; service role (no JWT) is free.
  IF auth.uid() IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.sim_lines sl
    WHERE sl.id = p_sim_line_id
      AND (sl.user_id = auth.uid()
           OR EXISTS (SELECT 1 FROM public.household_members hm
                      WHERE hm.owner_id = sl.user_id
                        AND hm.member_id = auth.uid()
                        AND hm.invite_status = 'accepted'
                        AND hm.role = 'manager'))
  ) THEN
    RAISE EXCEPTION 'Not authorized to modify this SIM line schedule';
  END IF;

  UPDATE public.scheduled_topups
  SET next_execution_at = p_new_date,
      updated_at = NOW()
  WHERE sim_line_id = p_sim_line_id AND schedule_type = 'refill_mini';

  UPDATE public.topup_executions
  SET execution_time = p_new_date
  WHERE id = (
    SELECT id FROM public.topup_executions
    WHERE sim_line_id = p_sim_line_id
      AND execution_type = 'refill_mini'
      AND status = 'pending'
      AND execution_time > NOW() + INTERVAL '1 hour'
    ORDER BY execution_time ASC
    LIMIT 1
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.reset_mini_refill_to_default(p_sim_line_id uuid)
 RETURNS timestamp with time zone
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_next_topup_due timestamp with time zone;
  v_frequency_days integer;
  v_buffer_days integer;
  v_default_date timestamp with time zone;
BEGIN
  -- Owner or accepted household manager only; service role (no JWT) is free.
  IF auth.uid() IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.sim_lines sl
    WHERE sl.id = p_sim_line_id
      AND (sl.user_id = auth.uid()
           OR EXISTS (SELECT 1 FROM public.household_members hm
                      WHERE hm.owner_id = sl.user_id
                        AND hm.member_id = auth.uid()
                        AND hm.invite_status = 'accepted'
                        AND hm.role = 'manager'))
  ) THEN
    RAISE EXCEPTION 'Not authorized to modify this SIM line schedule';
  END IF;

  SELECT next_topup_due INTO v_next_topup_due
  FROM public.sim_lines
  WHERE id = p_sim_line_id;

  SELECT frequency_days INTO v_frequency_days
  FROM public.scheduled_topups
  WHERE sim_line_id = p_sim_line_id AND schedule_type = 'refill_mini';

  IF v_next_topup_due IS NULL OR v_frequency_days IS NULL THEN
    v_default_date := NOW() + INTERVAL '85 days';
  ELSE
    IF v_frequency_days >= 85 THEN
      v_buffer_days := 5;
    ELSIF v_frequency_days = 30 THEN
      v_buffer_days := 2;
    ELSIF v_frequency_days = 14 THEN
      v_buffer_days := 1;
    ELSE
      v_buffer_days := 0;
    END IF;

    v_default_date := v_next_topup_due - (v_buffer_days * INTERVAL '1 day');
  END IF;

  IF v_default_date < NOW() THEN
    v_default_date := NOW();
  END IF;

  UPDATE public.scheduled_topups
  SET next_execution_at = v_default_date,
      updated_at = NOW()
  WHERE sim_line_id = p_sim_line_id AND schedule_type = 'refill_mini';

  UPDATE public.topup_executions
  SET execution_time = v_default_date
  WHERE id = (
    SELECT id FROM public.topup_executions
    WHERE sim_line_id = p_sim_line_id
      AND execution_type = 'refill_mini'
      AND status = 'pending'
      AND execution_time > NOW() + INTERVAL '1 hour'
    ORDER BY execution_time ASC
    LIMIT 1
  );

  RETURN v_default_date;
END;
$function$;

CREATE OR REPLACE FUNCTION public.apply_referral(p_referred_id uuid, p_referral_code text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_referrer_id UUID;
  v_already_referred_by TEXT;
BEGIN
  -- Defense in depth (EXECUTE is service-role-only today): a JWT caller may
  -- only apply a code to themselves.
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_referred_id THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  p_referral_code := UPPER(TRIM(p_referral_code));

  SELECT id INTO v_referrer_id
  FROM public.profiles
  WHERE UPPER(referral_code) = p_referral_code;

  IF v_referrer_id IS NULL THEN
    RAISE EXCEPTION 'Invalid referral code';
  END IF;

  IF v_referrer_id = p_referred_id THEN
    RAISE EXCEPTION 'You cannot refer yourself';
  END IF;

  SELECT referred_by INTO v_already_referred_by
  FROM public.profiles
  WHERE id = p_referred_id;

  IF v_already_referred_by IS NOT NULL THEN
    RAISE EXCEPTION 'You have already applied a referral code';
  END IF;

  UPDATE public.profiles
  SET referred_by = p_referral_code
  WHERE id = p_referred_id;

  INSERT INTO public.referrals (
    referrer_id, referred_id, referral_code, reward_amount, referrer_credited, referred_credited
  ) VALUES (
    v_referrer_id, p_referred_id, p_referral_code, 2.00, TRUE, TRUE
  );

  PERFORM public.credit_wallet(
    v_referrer_id,
    2.00,
    'referral_credit',
    'Referral reward for inviting friend (' || p_referral_code || ')',
    'ref_' || p_referred_id::text
  );

  PERFORM public.credit_wallet(
    p_referred_id,
    2.00,
    'referral_credit',
    'Welcome bonus for code ' || p_referral_code,
    'ref_' || v_referrer_id::text
  );

  INSERT INTO public.notifications (user_id, category, title, body)
  VALUES (
    v_referrer_id,
    'referral_reward',
    'Referral Reward Credited! 🎁',
    'You earned $2.00 wallet credit for successfully referring a friend.'
  );

  INSERT INTO public.notifications (user_id, category, title, body)
  VALUES (
    p_referred_id,
    'referral_reward',
    'Welcome Bonus Credited! 🎉',
    'You earned $2.00 welcome credit for applying referral code ' || p_referral_code || '.'
  );
END;
$function$;

-- ---------------------------------------------------------------
-- 3. EXECUTE revokes
-- ---------------------------------------------------------------
-- Trigger-only functions: clients must never call these via /rest/v1/rpc.
-- (Trigger firing does not require EXECUTE for the DML user.)
REVOKE EXECUTE ON FUNCTION public.check_free_lines_limit() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.check_topup_rate_limit() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_new_household_member() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.protect_is_power_user() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.resolve_pending_household_invites() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.route_topup_execution() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.sync_power_user_claim() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.sync_suspended_claim() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_fn_dispatch_notification() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_scheduled_topup_health_sync() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.update_line_health() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.update_sim_line_last_topup_at() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.update_test_cases_updated_at() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.update_updated_at() FROM PUBLIC, anon, authenticated;

-- Server/cron-only RPCs.
REVOKE EXECUTE ON FUNCTION public.process_due_notifications() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_due_notifications() TO service_role;
REVOKE EXECUTE ON FUNCTION public.schedule_delayed_notification(uuid, text, text, text, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.schedule_delayed_notification(uuid, text, text, text, integer) TO service_role;

-- Signed-in-only RPCs: drop anon (and default PUBLIC) access, keep authenticated.
REVOKE EXECUTE ON FUNCTION public.calculate_health_score(uuid, text, timestamp with time zone) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.calculate_topup_fees() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_current_context() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_wallet_forecast(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.reschedule_mini_refill(uuid, timestamp with time zone) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.reset_mini_refill_to_default(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.calculate_health_score(uuid, text, timestamp with time zone) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.calculate_topup_fees() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_current_context() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_wallet_forecast(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.reschedule_mini_refill(uuid, timestamp with time zone) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.reset_mini_refill_to_default(uuid) TO authenticated, service_role;
-- is_power_user / is_user_suspended stay executable by anon+authenticated:
-- they are referenced inside RLS policy expressions evaluated as those roles.

-- ---------------------------------------------------------------
-- 4. View: enforce the querying user's RLS
-- ---------------------------------------------------------------
ALTER VIEW public.sim_line_details_view SET (security_invoker = on);

-- ---------------------------------------------------------------
-- 5. Storage policies for support_attachments
-- ---------------------------------------------------------------
DROP POLICY IF EXISTS "Users can view attachments" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload their own attachments" ON storage.objects;

CREATE POLICY "Users can upload own support attachments" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'support_attachments'
              AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Users can view own support attachments" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'support_attachments'
         AND (storage.foldername(name))[1] = auth.uid()::text);

-- ---------------------------------------------------------------
-- 6. Money constraints
-- ---------------------------------------------------------------
-- NOT VALID: one legacy $0 "Simulated Auto-Refill" test row (d41a37a3-...)
-- predates the constraint; all new rows are checked.
ALTER TABLE public.wallet_transactions
  ADD CONSTRAINT wallet_transactions_amount_positive CHECK (amount > 0) NOT VALID;
ALTER TABLE public.topup_executions
  ADD CONSTRAINT topup_executions_amount_positive CHECK (amount > 0);
ALTER TABLE public.scheduled_topups
  ADD CONSTRAINT scheduled_topups_amount_positive CHECK (amount > 0);

-- ---------------------------------------------------------------
-- 7. Policy tightening
-- ---------------------------------------------------------------
-- profiles: was USING (true) for authenticated — every user could read every
-- profile (incl. phone numbers). Restrict to self, household counterpart, or
-- power user.
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
CREATE POLICY "Users can view own or household profiles" ON public.profiles
  FOR SELECT TO authenticated
  USING (
    auth.uid() = id
    OR is_power_user(auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.household_members hm
      WHERE hm.invite_status = 'accepted'
        AND ((hm.owner_id = profiles.id AND hm.member_id = auth.uid())
          OR (hm.member_id = profiles.id AND hm.owner_id = auth.uid()))
    )
  );

-- test_cases: dev table; was readable/writable by any authenticated user.
DROP POLICY IF EXISTS "Allow authenticated users to delete test cases" ON public.test_cases;
DROP POLICY IF EXISTS "Allow authenticated users to insert test cases" ON public.test_cases;
DROP POLICY IF EXISTS "Allow authenticated users to read test cases" ON public.test_cases;
DROP POLICY IF EXISTS "Allow authenticated users to update test cases" ON public.test_cases;
CREATE POLICY "Power users can manage test cases" ON public.test_cases
  FOR ALL TO authenticated
  USING (is_power_user(auth.uid()))
  WITH CHECK (is_power_user(auth.uid()));

-- topup_executions: execution history is an audit trail; clients don't delete
-- it (no app code path does).
DROP POLICY IF EXISTS "Users can delete own topup executions" ON public.topup_executions;
