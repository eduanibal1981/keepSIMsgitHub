-- Migration: 20260730000000_d3b_purge_pipeline_and_drift.sql
-- Description: D3b Purge Pipeline Hardening, Wallet Settlement, Drift Capture & Privacy Enhancements

-- ── 1. Apply Referral Function (Capture Live Drift) ─────────────────────────
CREATE OR REPLACE FUNCTION public.apply_referral(p_referred_id uuid, p_referral_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_referrer_id uuid;
  v_already_referred_by text;
  v_allowed boolean;
  v_retry_sec int;
  v_email text;
  v_email_hash text;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_referred_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  SELECT allowed, retry_after_seconds INTO v_allowed, v_retry_sec
  FROM public.consume_rate_limit('apply_referral', p_referred_id::text, 5, 5.0/60.0, clock_timestamp());

  IF NOT v_allowed THEN
    RETURN jsonb_build_object('success', false, 'code', 'KS429', 'error', 'RATE_LIMITED:apply_referral:' || v_retry_sec, 'retry_after', v_retry_sec);
  END IF;

  p_referral_code := UPPER(TRIM(COALESCE(p_referral_code, '')));

  -- Check if code is retired
  IF EXISTS (SELECT 1 FROM public.retired_referral_codes WHERE code = p_referral_code) THEN
    RETURN jsonb_build_object('success', false, 'error', 'This referral code has been retired');
  END IF;

  SELECT id INTO v_referrer_id
  FROM public.profiles
  WHERE UPPER(referral_code) = p_referral_code;

  IF v_referrer_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid referral code');
  END IF;

  IF v_referrer_id = p_referred_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'You cannot refer yourself');
  END IF;

  SELECT referred_by INTO v_already_referred_by
  FROM public.profiles
  WHERE id = p_referred_id;

  IF v_already_referred_by IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'You have already applied a referral code');
  END IF;

  -- Anti-abuse: check if user's email hash was in account_deletions within last 90 days
  SELECT email INTO v_email FROM auth.users WHERE id = p_referred_id;
  IF v_email IS NOT NULL THEN
    v_email_hash := encode(sha256(lower(trim(v_email))::bytea), 'hex');
    IF EXISTS (
      SELECT 1 FROM public.account_deletions
      WHERE email_hash = v_email_hash
        AND requested_at > (clock_timestamp() - INTERVAL '90 days')
    ) THEN
      RETURN jsonb_build_object('success', false, 'error', 'Re-registered accounts are ineligible for referral bonuses');
    END IF;
  END IF;

  UPDATE public.profiles
  SET referred_by = p_referral_code
  WHERE id = p_referred_id;

  INSERT INTO public.referrals (referrer_id, referred_user_id, code)
  VALUES (v_referrer_id, p_referred_id, p_referral_code);

  RETURN jsonb_build_object('success', true);
END;
$function$;

-- ── 2. Wallet Transactions Type Check Update ────────────────────────────────
ALTER TABLE public.wallet_transactions
  DROP CONSTRAINT IF EXISTS wallet_transactions_type_check;

ALTER TABLE public.wallet_transactions
  ADD CONSTRAINT wallet_transactions_type_check
  CHECK (type = ANY (ARRAY[
    'deposit'::text, 'topup_debit'::text, 'refund'::text, 'referral_credit'::text,
    'welcome_home_debit'::text, 'auto_fund'::text, 'plan_fee_debit'::text,
    'esim_purchase_debit'::text, 'wallet_settlement'::text, 'wallet_forfeit'::text
  ]));

-- ── 3. Referral Points sim_line_id FK (SET NULL) ────────────────────────────
ALTER TABLE public.referral_points
  DROP CONSTRAINT IF EXISTS referral_points_sim_line_id_fkey,
  ADD CONSTRAINT referral_points_sim_line_id_fkey
    FOREIGN KEY (sim_line_id) REFERENCES public.sim_lines(id) ON DELETE SET NULL;

-- ── 4. Dedicated Consent Table ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_consents (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  analytics_consent boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.user_consents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_consents_select_own" ON public.user_consents;
CREATE POLICY "user_consents_select_own" ON public.user_consents
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "user_consents_insert_own" ON public.user_consents;
CREATE POLICY "user_consents_insert_own" ON public.user_consents
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "user_consents_update_own" ON public.user_consents;
CREATE POLICY "user_consents_update_own" ON public.user_consents
  FOR UPDATE USING (auth.uid() = user_id);

-- ── 5. Fix check_topup_rate_limit Trigger Function ───────────────────────────
CREATE OR REPLACE FUNCTION public.check_topup_rate_limit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  -- Only enforce 10-second per-SIM line cooldown for refill_instant executions
  IF NEW.execution_type = 'refill_instant' THEN
    IF EXISTS (
      SELECT 1 FROM public.topup_executions
      WHERE sim_line_id = NEW.sim_line_id
        AND execution_type = 'refill_instant'
        AND created_at > (clock_timestamp() - INTERVAL '10 seconds')
        AND id <> NEW.id
    ) THEN
      RAISE EXCEPTION 'COOLDOWN_ACTIVE: Please wait 10 seconds between refill requests for line %', NEW.sim_line_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

-- ── 6. Add Suspension Checks to SECURITY DEFINER Money RPCs ─────────────────
DROP FUNCTION IF EXISTS public.request_esim_purchase(text, integer);
CREATE OR REPLACE FUNCTION public.request_esim_purchase(p_offer_id text, p_quantity integer DEFAULT 1)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_offer RECORD;
  v_markup_percent numeric := 30.0;
  v_retail_price numeric(10,2);
  v_total_cost numeric(10,2);
  v_wallet_balance numeric(10,2);
  v_order_id uuid;
  v_txn_ref text;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  IF EXISTS (SELECT 1 FROM public.profiles WHERE id = v_user_id AND is_suspended = true) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Account is suspended. Purchases are disabled.');
  END IF;

  PERFORM public.enforce_rate_limit('esim_purchase', v_user_id::text);

  IF p_quantity IS NULL OR p_quantity < 1 OR p_quantity > 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Quantity must be between 1 and 3');
  END IF;

  SELECT * INTO v_offer
  FROM public.esim_offers_cache
  WHERE offer_id = p_offer_id AND is_active = true;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'eSIM offer not found or inactive');
  END IF;

  BEGIN
    SELECT config_value::numeric INTO v_markup_percent
    FROM public.system_configs WHERE config_key = 'ESIM_MARKUP_PERCENT';
  EXCEPTION WHEN OTHERS THEN v_markup_percent := 30.0; END;
  IF v_markup_percent IS NULL THEN v_markup_percent := 30.0; END IF;

  v_retail_price := round(v_offer.wholesale_price_usd * (1.0 + (v_markup_percent / 100.0)), 2);
  v_total_cost := v_retail_price * p_quantity;

  SELECT COALESCE(balance, 0.00) INTO v_wallet_balance
  FROM public.wallets WHERE user_id = v_user_id;

  IF v_wallet_balance < v_total_cost THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'INSUFFICIENT_FUNDS',
      'error', 'Insufficient wallet balance. Required: $' || v_total_cost::text || ', Available: $' || v_wallet_balance::text
    );
  END IF;

  INSERT INTO public.esim_orders (
    user_id, offer_id, quantity, wholesale_price_usd, retail_price_usd, total_amount_usd, status
  ) VALUES (
    v_user_id, p_offer_id, p_quantity, v_offer.wholesale_price_usd, v_retail_price, v_total_cost, 'pending'
  ) RETURNING id INTO v_order_id;

  v_txn_ref := 'esim_' || v_order_id::text;
  PERFORM public.debit_wallet_for_topup(v_user_id, v_total_cost, 'esim_purchase_debit', v_txn_ref);

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'retail_price_usd', v_retail_price,
    'total_amount_usd', v_total_cost,
    'status', 'pending'
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.request_instant_refill(p_sim_line_id uuid, p_offer_id text, p_payment_gateway_code text, p_amount_usd numeric DEFAULT NULL::numeric)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_iso text;
  v_zen_carrier text;
  v_offer RECORD;
  v_base numeric;
  v_value numeric;
  v_execution_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_suspended = true) THEN
    RAISE EXCEPTION 'Account is suspended. Refills are disabled.';
  END IF;

  PERFORM public.enforce_rate_limit('instant_refill', auth.uid()::text);

  SELECT co.iso_code, ca.zen_carrier
  INTO v_iso, v_zen_carrier
  FROM public.sim_lines sl
  JOIN public.countries co ON co.id = sl.country_id
  JOIN public.carriers ca ON ca.id = sl.carrier_id
  WHERE sl.id = p_sim_line_id
    AND (sl.user_id = auth.uid()
         OR EXISTS (SELECT 1 FROM public.household_members hm
                    WHERE hm.owner_id = sl.user_id
                      AND hm.member_id = auth.uid()
                      AND hm.invite_status = 'accepted'
                      AND hm.role = 'manager'));

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Not authorized to refill this SIM line';
  END IF;

  IF v_zen_carrier IS NULL THEN
    RAISE EXCEPTION 'This carrier has no online top-up catalog';
  END IF;

  SELECT * INTO v_offer
  FROM public.zendit_offers_cache z
  WHERE z.offer_id = p_offer_id
    AND z.country_code = v_iso
    AND z.zen_carrier = v_zen_carrier;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Offer % is not available for this SIM line', p_offer_id;
  END IF;

  IF v_offer.refreshed_at < now() - interval '24 hours' THEN
    RAISE EXCEPTION 'Offer pricing is temporarily unavailable. Please try again later.';
  END IF;

  IF v_offer.price_type = 'FIXED' THEN
    v_base := v_offer.price_fixed_usd;
    v_value := NULL;
  ELSE
    IF p_amount_usd IS NULL THEN
      RAISE EXCEPTION 'This offer requires an amount';
    END IF;
    v_base := round(p_amount_usd, 2);
    IF v_base < v_offer.price_min_usd - 0.01 OR v_base > v_offer.price_max_usd + 0.01 THEN
      RAISE EXCEPTION 'Amount % is outside this offer''s %-% USD range',
        v_base, v_offer.price_min_usd, v_offer.price_max_usd;
    END IF;
    v_value := least(v_offer.send_max, greatest(v_offer.send_min, round(
      v_offer.send_min
      + CASE WHEN v_offer.price_max_usd - v_offer.price_min_usd > 0
             THEN (v_base - v_offer.price_min_usd)
                  * (v_offer.send_max - v_offer.send_min)
                  / (v_offer.price_max_usd - v_offer.price_min_usd)
             ELSE 0 END)));
  END IF;

  IF v_base IS NULL OR v_base <= 0 THEN
    RAISE EXCEPTION 'Offer % has no usable price', p_offer_id;
  END IF;

  INSERT INTO public.topup_executions (
    sim_line_id, user_id, amount, base_cost_usd, payment_gateway_code,
    currency, status, execution_type, execution_time, offer_id, offer_value
  ) VALUES (
    p_sim_line_id, auth.uid(), v_base, v_base, p_payment_gateway_code,
    'USD', 'pending', 'refill_instant', now(), p_offer_id, v_value
  )
  RETURNING id INTO v_execution_id;

  RETURN v_execution_id;
END;
$function$;

DROP FUNCTION IF EXISTS public.pay_plan_fee_from_wallet(text, uuid);
CREATE OR REPLACE FUNCTION public.pay_plan_fee_from_wallet(p_reference_id text, p_sim_line_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_fee numeric(10,2) := 2.50;
  v_balance numeric(10,2);
  v_existing_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  IF EXISTS (SELECT 1 FROM public.profiles WHERE id = v_user_id AND is_suspended = true) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Account is suspended.');
  END IF;

  PERFORM public.enforce_rate_limit('plan_fee', v_user_id::text);

  BEGIN
    SELECT config_value::numeric INTO v_fee
    FROM public.system_configs WHERE config_key = 'BASE_SERVICE_FEE_USD';
  EXCEPTION WHEN OTHERS THEN v_fee := 2.50; END;
  IF v_fee IS NULL OR v_fee <= 0 THEN v_fee := 2.50; END IF;

  SELECT id INTO v_existing_id
  FROM public.wallet_transactions
  WHERE reference_id = p_reference_id AND type = 'plan_fee_debit';

  IF v_existing_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', true,
      'already_paid', true,
      'transaction_id', v_existing_id,
      'amount', v_fee
    );
  END IF;

  SELECT COALESCE(balance, 0.00) INTO v_balance
  FROM public.wallets WHERE user_id = v_user_id;

  IF v_balance < v_fee THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'INSUFFICIENT_FUNDS',
      'error', 'Insufficient wallet balance ($' || v_balance::text || ') for annual plan fee ($' || v_fee::text || ').'
    );
  END IF;

  PERFORM public.debit_wallet_for_topup(v_user_id, v_fee, 'plan_fee_debit', p_reference_id);

  IF p_sim_line_id IS NOT NULL THEN
    UPDATE public.sim_lines
    SET plan_expires_at = clock_timestamp() + INTERVAL '365 days',
        updated_at = clock_timestamp()
    WHERE id = p_sim_line_id AND user_id = v_user_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'amount', v_fee,
    'reference_id', p_reference_id
  );
END;
$function$;

DROP FUNCTION IF EXISTS public.redeem_referral_points();
CREATE OR REPLACE FUNCTION public.redeem_referral_points()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_earned bigint := 0;
  v_spent bigint := 0;
  v_available int := 0;
  v_redemption_id uuid;
  v_txn_ref text;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  IF EXISTS (SELECT 1 FROM public.profiles WHERE id = v_user_id AND is_suspended = true) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Account is suspended.');
  END IF;

  PERFORM public.enforce_rate_limit('referral_redeem', v_user_id::text);

  SELECT COALESCE(SUM(points), 0) INTO v_earned
  FROM public.referral_points WHERE referrer_id = v_user_id;

  SELECT COALESCE(SUM(points_spent), 0) INTO v_spent
  FROM public.referral_redemptions WHERE user_id = v_user_id;

  v_available := (v_earned - v_spent)::int;

  IF v_available < 10 THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'INSUFFICIENT_POINTS',
      'error', 'Insufficient referral points. Required: 10 points ($2.00 reward), Available: ' || v_available::text
    );
  END IF;

  v_redemption_id := gen_random_uuid();
  v_txn_ref := 'refredeem_' || v_redemption_id::text;

  INSERT INTO public.referral_redemptions (id, user_id, points_spent)
  VALUES (v_redemption_id, v_user_id, 10);

  PERFORM public.credit_wallet_for_deposit(v_user_id, 2.00, 'referral_credit', v_txn_ref);

  RETURN jsonb_build_object(
    'success', true,
    'redemption_id', v_redemption_id,
    'points_spent', 10,
    'reward_amount_usd', 2.00,
    'remaining_points', v_available - 10
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.pay_plan_fee_from_wallet(text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.redeem_referral_points() TO authenticated;

-- ── 7. Request Account Deletion RPC Update (Strict Above-Dust Block) ────────
DROP FUNCTION IF EXISTS public.request_account_deletion(text, boolean);
CREATE OR REPLACE FUNCTION public.request_account_deletion(
  p_reason text DEFAULT NULL,
  p_forfeit_dust boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
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

  PERFORM public.enforce_rate_limit('account_delete', v_user_id::text);

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

  SELECT email INTO v_email FROM auth.users WHERE id = v_user_id;
  IF v_email IS NULL THEN
    v_email := v_user_id::text || '@deleted.local';
  END IF;
  v_email_hash := encode(sha256(lower(trim(v_email))::bytea), 'hex');

  SELECT COALESCE(balance, 0.00) INTO v_balance
  FROM public.wallets
  WHERE user_id = v_user_id;

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

  IF v_balance >= v_dust_limit THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'WALLET_BALANCE_EXCEEDS_DUST_LIMIT',
      'error', 'Wallet balance exceeds dust limit ($' || v_dust_limit::text || '). Please spend your balance or contact support for payout.',
      'wallet_balance', v_balance,
      'dust_limit', v_dust_limit
    );
  END IF;

  IF v_balance > 0 AND v_balance < v_dust_limit AND NOT p_forfeit_dust THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'MUST_ACCEPT_DUST_FORFEIT',
      'error', 'Please confirm forfeit of dust balance ($' || v_balance::text || ').',
      'wallet_balance', v_balance
    );
  END IF;

  v_scheduled_purge := clock_timestamp() + (v_grace_days || ' days')::interval;

  INSERT INTO public.account_deletions (
    user_id, email_hash, status, wallet_balance_at_request,
    dust_forfeited, reason, actor_id, scheduled_purge_at
  ) VALUES (
    v_user_id, v_email_hash, 'requested', v_balance,
    (v_balance < v_dust_limit AND p_forfeit_dust), p_reason, v_user_id, v_scheduled_purge
  );

  UPDATE public.profiles SET is_suspended = true WHERE id = v_user_id;
  UPDATE public.scheduled_topups SET is_active = false WHERE sim_line_id IN (
    SELECT id FROM public.sim_lines WHERE user_id = v_user_id
  );

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
$function$;

GRANT EXECUTE ON FUNCTION public.request_account_deletion(text, boolean) TO authenticated;

-- ── 8. Purge Deleted Accounts Function Update (Wallet Settlement & FK Fix) ─
DROP FUNCTION IF EXISTS public.purge_deleted_accounts();
CREATE OR REPLACE FUNCTION public.purge_deleted_accounts()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  rec RECORD;
  v_wallet RECORD;
  v_in_flight_count int;
  v_secret text;
  v_purged_count int := 0;
  v_ref_code text;
BEGIN
  UPDATE public.account_deletions
  SET status = 'frozen', frozen_at = clock_timestamp(), updated_at = clock_timestamp()
  WHERE status = 'requested' AND scheduled_purge_at <= clock_timestamp();

  FOR rec IN SELECT * FROM public.account_deletions WHERE status IN ('frozen', 'draining') LOOP
    SELECT COUNT(*) INTO v_in_flight_count
    FROM public.topup_executions
    WHERE user_id = rec.user_id AND status = 'routing';

    IF v_in_flight_count = 0 THEN
      SELECT COUNT(*) INTO v_in_flight_count
      FROM public.esim_orders
      WHERE user_id = rec.user_id AND status IN ('pending', 'processing');
    END IF;

    IF v_in_flight_count > 0 THEN
      IF rec.scheduled_purge_at < (clock_timestamp() - INTERVAL '72 hours') THEN
        INSERT INTO public.system_alerts (kind, message, details)
        VALUES (
          'account_purge_stuck',
          'Account deletion stuck in draining state >72h for user ' || rec.user_id::text,
          jsonb_build_object('user_id', rec.user_id, 'in_flight_count', v_in_flight_count)
        );
      END IF;
      CONTINUE;
    END IF;

    UPDATE public.account_deletions
    SET status = 'draining', drained_at = COALESCE(drained_at, clock_timestamp()), updated_at = clock_timestamp()
    WHERE id = rec.id;

    SELECT referral_code INTO v_ref_code FROM public.profiles WHERE id = rec.user_id;
    IF v_ref_code IS NOT NULL AND length(trim(v_ref_code)) > 0 THEN
      INSERT INTO public.retired_referral_codes (code) VALUES (upper(trim(v_ref_code)))
      ON CONFLICT DO NOTHING;
    END IF;

    FOR v_wallet IN SELECT * FROM public.wallets WHERE user_id = rec.user_id LOOP
      IF v_wallet.balance <> 0 THEN
        INSERT INTO public.wallet_transactions (
          wallet_id, user_id, amount, balance_before, balance_after, type, description, reference_id
        ) VALUES (
          v_wallet.id, rec.user_id, v_wallet.balance, v_wallet.balance, 0.00,
          CASE WHEN rec.dust_forfeited THEN 'wallet_forfeit' ELSE 'wallet_settlement' END,
          'Account purge wallet balance zeroing',
          'purge_' || rec.id
        );
      END IF;
      UPDATE public.wallets SET balance = 0.00, user_id = NULL WHERE id = v_wallet.id;
    END LOOP;

    UPDATE public.referral_points
    SET sim_line_id = NULL
    WHERE sim_line_id IN (SELECT id FROM public.sim_lines WHERE user_id = rec.user_id);

    UPDATE public.wallet_transactions SET user_id = NULL WHERE user_id = rec.user_id;
    UPDATE public.plan_payments SET user_id = NULL WHERE user_id = rec.user_id;
    UPDATE public.esim_orders SET user_id = NULL WHERE user_id = rec.user_id;
    UPDATE public.user_esims SET user_id = NULL WHERE user_id = rec.user_id;
    UPDATE public.topup_executions SET user_id = NULL WHERE user_id = rec.user_id;

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
    DELETE FROM public.user_consents WHERE user_id = rec.user_id;

    UPDATE public.account_deletions
    SET status = 'purged', purged_at = clock_timestamp(), updated_at = clock_timestamp()
    WHERE id = rec.id;

    v_purged_count := v_purged_count + 1;

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
$function$;

-- ── 9. Expand export_user_data RPC ──────────────────────────────────────────
DROP FUNCTION IF EXISTS public.export_user_data();
CREATE OR REPLACE FUNCTION public.export_user_data()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
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
  v_referrals jsonb;
  v_notifications jsonb;
  v_alert_settings jsonb;
  v_channels jsonb;
  v_tickets jsonb;
  v_ticket_messages jsonb;
  v_line_activity_log jsonb;
  v_offline_settings jsonb;
  v_offline_events jsonb;
  v_household_members jsonb;
  v_notification_deliveries jsonb;
  v_push_tokens jsonb;
  v_security_logs jsonb;
  v_consents jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

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

  -- Redact counterparty referred_user_id to stable opaque hash
  SELECT COALESCE(jsonb_agg(jsonb_set(to_jsonb(rp), '{referred_user_id}', to_jsonb(encode(sha256(COALESCE(rp.referred_user_id::text, '')::bytea), 'hex')))), '[]'::jsonb)
  INTO v_referral_points FROM public.referral_points rp WHERE referrer_id = v_user_id;

  SELECT COALESCE(jsonb_agg(to_jsonb(rr)), '[]'::jsonb) INTO v_referral_redemptions FROM public.referral_redemptions rr WHERE user_id = v_user_id;

  SELECT COALESCE(jsonb_agg(jsonb_set(to_jsonb(rf), '{referred_user_id}', to_jsonb(encode(sha256(COALESCE(rf.referred_user_id::text, '')::bytea), 'hex')))), '[]'::jsonb)
  INTO v_referrals FROM public.referrals rf WHERE referrer_id = v_user_id;

  SELECT COALESCE(jsonb_agg(to_jsonb(n)), '[]'::jsonb) INTO v_notifications FROM public.notifications n WHERE user_id = v_user_id;
  SELECT COALESCE(jsonb_agg(to_jsonb(a)), '[]'::jsonb) INTO v_alert_settings FROM public.alert_settings a WHERE user_id = v_user_id;
  SELECT COALESCE(jsonb_agg(to_jsonb(c)), '[]'::jsonb) INTO v_channels FROM public.notification_channels c WHERE user_id = v_user_id;
  SELECT COALESCE(jsonb_agg(to_jsonb(t)), '[]'::jsonb) INTO v_tickets FROM public.support_tickets t WHERE user_id = v_user_id;
  SELECT COALESCE(jsonb_agg(to_jsonb(tm)), '[]'::jsonb) INTO v_ticket_messages FROM public.ticket_messages tm WHERE user_id = v_user_id OR ticket_id IN (SELECT id FROM public.support_tickets WHERE user_id = v_user_id);
  SELECT COALESCE(jsonb_agg(to_jsonb(act)), '[]'::jsonb) INTO v_line_activity_log FROM public.line_activity_log act WHERE sim_line_id IN (SELECT id FROM public.sim_lines WHERE user_id = v_user_id);
  SELECT COALESCE(jsonb_agg(to_jsonb(ors)), '[]'::jsonb) INTO v_offline_settings FROM public.offline_refill_settings ors WHERE user_id = v_user_id;
  SELECT COALESCE(jsonb_agg(to_jsonb(ore)), '[]'::jsonb) INTO v_offline_events FROM public.offline_refill_events ore WHERE user_id = v_user_id;

  SELECT COALESCE(jsonb_agg(jsonb_set(to_jsonb(hm), '{member_id}', to_jsonb(encode(sha256(COALESCE(hm.member_id::text, '')::bytea), 'hex')))), '[]'::jsonb)
  INTO v_household_members FROM public.household_members hm WHERE owner_id = v_user_id;

  SELECT COALESCE(jsonb_agg(to_jsonb(nd)), '[]'::jsonb) INTO v_notification_deliveries FROM public.notification_deliveries nd WHERE user_id = v_user_id;
  SELECT COALESCE(jsonb_agg(to_jsonb(d)), '[]'::jsonb) INTO v_push_tokens FROM public.device_push_tokens d WHERE user_id = v_user_id;
  SELECT COALESCE(jsonb_agg(to_jsonb(sl)), '[]'::jsonb) INTO v_security_logs FROM public.security_logs sl WHERE user_id = v_user_id;
  SELECT COALESCE(jsonb_agg(to_jsonb(uc)), '[]'::jsonb) INTO v_consents FROM public.user_consents uc WHERE user_id = v_user_id;

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
    'referrals', v_referrals,
    'referral_points', v_referral_points,
    'referral_redemptions', v_referral_redemptions,
    'notifications', v_notifications,
    'alert_settings', v_alert_settings,
    'notification_channels', v_channels,
    'support_tickets', v_tickets,
    'ticket_messages', v_ticket_messages,
    'line_activity_log', v_line_activity_log,
    'offline_refill_settings', v_offline_settings,
    'offline_refill_events', v_offline_events,
    'household_members', v_household_members,
    'notification_deliveries', v_notification_deliveries,
    'device_push_tokens', v_push_tokens,
    'security_logs', v_security_logs,
    'user_consents', v_consents
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.export_user_data() TO authenticated;

-- Record in schema_migrations
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260729000000'), ('20260730000000') ON CONFLICT DO NOTHING;
