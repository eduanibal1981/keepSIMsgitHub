-- D2 — Rate Limiting (Auth, Money RPCs, Edge Functions)
-- Migration: 20260728000000_d2_rate_limiting.sql
--
-- FAIL-OPEN FOR MONEY, FAIL-CLOSED FOR COST SURFACES:
-- Money RPCs already have balance, ownership, idempotency, and offer validation
-- limits. Their rate bucket is anti-abuse, and must never be the reason a
-- legitimate payment fails. Cost surfaces (detect-country, webhooks) have no
-- economic bound, so they fail closed.

BEGIN;

-- ── 1. Create rate_limit_buckets table ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.rate_limit_buckets (
  bucket     text NOT NULL,
  key        text NOT NULL,
  tokens     numeric NOT NULL,
  updated_at timestamptz NOT NULL,
  PRIMARY KEY (bucket, key)
);

ALTER TABLE public.rate_limit_buckets ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.rate_limit_buckets FROM anon, authenticated;

-- ── 2. Create consume_rate_limit function ────────────────────────────────────
CREATE OR REPLACE FUNCTION public.consume_rate_limit(
  p_bucket text,
  p_key text,
  p_capacity int,
  p_refill_per_minute numeric,
  p_now timestamptz DEFAULT clock_timestamp()
)
RETURNS TABLE (allowed boolean, retry_after_seconds int)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_tokens numeric;
  v_updated_at timestamptz;
  v_elapsed numeric;
  v_refill numeric;
  v_new_tokens numeric;
  v_needed numeric;
  v_retry_sec int;
BEGIN
  -- Rule 2: Skip check entirely if key is NULL or empty (service_role / background workers)
  IF p_key IS NULL OR p_key = '' THEN
    RETURN QUERY SELECT true, 0;
    RETURN;
  END IF;

  p_bucket := LOWER(p_bucket);

  -- Atomic row lock
  SELECT tokens, updated_at INTO v_tokens, v_updated_at
  FROM public.rate_limit_buckets
  WHERE bucket = p_bucket AND key = p_key
  FOR UPDATE;

  IF NOT FOUND THEN
    -- First call: initialize with capacity - 1 token (consume 1 token)
    INSERT INTO public.rate_limit_buckets (bucket, key, tokens, updated_at)
    VALUES (p_bucket, p_key, GREATEST(0, p_capacity - 1), p_now)
    ON CONFLICT (bucket, key) DO UPDATE
      SET tokens = EXCLUDED.tokens, updated_at = EXCLUDED.updated_at;

    RETURN QUERY SELECT true, 0;
    RETURN;
  END IF;

  -- Calculate elapsed time and refilled tokens using clock_timestamp()
  v_elapsed := GREATEST(0, EXTRACT(EPOCH FROM (p_now - v_updated_at)));
  v_refill := v_elapsed * (p_refill_per_minute / 60.0);
  v_new_tokens := LEAST(p_capacity::numeric, v_tokens + v_refill);

  IF v_new_tokens >= 1.0 THEN
    UPDATE public.rate_limit_buckets
    SET tokens = v_new_tokens - 1.0, updated_at = p_now
    WHERE bucket = p_bucket AND key = p_key;

    RETURN QUERY SELECT true, 0;
  ELSE
    -- Rejection logic
    v_needed := 1.0 - v_new_tokens;
    IF p_refill_per_minute > 0 THEN
      v_retry_sec := GREATEST(1, CEIL(v_needed / (p_refill_per_minute / 60.0))::int);
    ELSE
      v_retry_sec := 60;
    END IF;

    UPDATE public.rate_limit_buckets
    SET tokens = v_new_tokens, updated_at = p_now
    WHERE bucket = p_bucket AND key = p_key;

    -- Log rejection to security_logs
    INSERT INTO public.security_logs (user_id, event_type, description, metadata)
    VALUES (
      CASE WHEN auth.uid() IS NOT NULL THEN auth.uid() ELSE NULL END,
      'rate_limited',
      'Rate limit exceeded for ' || p_bucket,
      jsonb_build_object('bucket', p_bucket, 'key', p_key, 'retry_after', v_retry_sec)
    );

    RETURN QUERY SELECT false, v_retry_sec;
  END IF;
END;
$$;

-- ── 3. Helper: enforce_rate_limit ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.enforce_rate_limit(
  p_bucket text,
  p_key text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_config text;
  v_cap int := 10;
  v_minutes numeric := 60;
  v_refill_rate numeric;
  v_allowed boolean;
  v_retry_sec int;
  v_slash_pos int;
BEGIN
  -- Skip if key is null (e.g. auth.uid() IS NULL for background workers)
  IF p_key IS NULL OR p_key = '' THEN
    RETURN;
  END IF;

  p_bucket := LOWER(p_bucket);

  -- Fetch config from system_configs: RATE_LIMIT_<UPPER(p_bucket)>
  SELECT config_value INTO v_config
  FROM public.system_configs
  WHERE config_key = 'RATE_LIMIT_' || UPPER(p_bucket);

  IF v_config IS NOT NULL AND v_config LIKE '%/%' THEN
    BEGIN
      v_slash_pos := POSITION('/' IN v_config);
      v_cap := SUBSTRING(v_config FROM 1 FOR v_slash_pos - 1)::int;
      v_minutes := SUBSTRING(v_config FROM v_slash_pos + 1)::numeric;
    EXCEPTION WHEN OTHERS THEN
      v_cap := 10;
      v_minutes := 60;
    END;
  END IF;

  IF v_minutes <= 0 THEN v_minutes := 60; END IF;
  v_refill_rate := v_cap::numeric / v_minutes;

  -- Consume token
  SELECT allowed, retry_after_seconds INTO v_allowed, v_retry_sec
  FROM public.consume_rate_limit(p_bucket, p_key, v_cap, v_refill_rate, clock_timestamp());

  IF NOT v_allowed THEN
    RAISE EXCEPTION USING ERRCODE = 'KS429', MESSAGE = 'RATE_LIMITED:' || p_bucket || ':' || v_retry_sec;
  END IF;
EXCEPTION
  WHEN SQLSTATE 'KS429' THEN
    RAISE;
  WHEN OTHERS THEN
    -- Fail open for money RPCs on internal limiter errors
    RAISE NOTICE 'Limiter error for bucket %: %', p_bucket, SQLERRM;
END;
$$;

-- ── 4. Seed system_configs ───────────────────────────────────────────────────
INSERT INTO public.system_configs (config_key, config_value) VALUES
  ('RATE_LIMIT_ESIM_PURCHASE', '5/60'),
  ('RATE_LIMIT_INSTANT_REFILL', '10/60'),
  ('RATE_LIMIT_PLAN_FEE', '10/60'),
  ('RATE_LIMIT_REFERRAL_REDEEM', '5/60'),
  ('RATE_LIMIT_APPLY_REFERRAL', '5/60'),
  ('RATE_LIMIT_DETECT_COUNTRY', '12/60'),
  ('RATE_LIMIT_WALLET_DEDUCT', '20/60'),
  ('RATE_LIMIT_WEBHOOK_IP', '60/1')
ON CONFLICT (config_key) DO NOTHING;

-- ── 5. Update 5 Money RPCs ───────────────────────────────────────────────────

-- 5a. request_esim_purchase
CREATE OR REPLACE FUNCTION public.request_esim_purchase(
  p_offer_id TEXT,
  p_quantity INT DEFAULT 1
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_wallet_id UUID;
  v_provider TEXT;
  v_bundle_name TEXT;
  v_offer RECORD;
  v_markup_str TEXT;
  v_markup NUMERIC(5,2);
  v_retail_unit NUMERIC(10,2);
  v_total_cost NUMERIC(10,2);
  v_wallet_balance NUMERIC(10,2);
  v_order_id UUID;
  v_reference_id TEXT;
  v_existing_txn RECORD;
BEGIN
  -- 1. Verify caller authentication
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'UNAUTHORIZED: User must be authenticated to purchase an eSIM.';
  END IF;

  -- Rate limit check
  PERFORM public.enforce_rate_limit('esim_purchase', v_user_id::text);

  -- 2. Validate quantity (cap <= 3)
  IF p_quantity IS NULL OR p_quantity < 1 OR p_quantity > 3 THEN
    RAISE EXCEPTION 'INVALID_QUANTITY: Quantity must be between 1 and 3.';
  END IF;

  -- 3. Fetch offer from esim_offers_cache
  SELECT * INTO v_offer
  FROM public.esim_offers_cache
  WHERE (provider || '_' || bundle_name = p_offer_id)
     OR (bundle_name = p_offer_id)
  ORDER BY is_active DESC, updated_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'OFFER_NOT_FOUND: Offer % is unknown or invalid.', p_offer_id;
  END IF;

  IF v_offer.is_active IS NOT TRUE THEN
    RAISE EXCEPTION 'OFFER_INACTIVE: Offer % is currently unavailable.', p_offer_id;
  END IF;

  IF v_offer.updated_at < (NOW() - INTERVAL '24 hours') THEN
    RAISE EXCEPTION 'STALE_CATALOG_CACHE: Offer catalog is stale (>24h old). Purchase halted for safety.';
  END IF;

  v_provider := v_offer.provider;
  v_bundle_name := v_offer.bundle_name;

  -- 4. Calculate markup and retail price
  SELECT config_value INTO v_markup_str
  FROM public.system_configs
  WHERE config_key = 'ESIM_MARKUP_PERCENT';

  IF v_markup_str IS NULL THEN
    v_markup := 30.00;
  ELSE
    v_markup := v_markup_str::NUMERIC;
  END IF;

  v_retail_unit := round(v_offer.wholesale_price_usd * (1.00 + v_markup / 100.00), 2);
  v_total_cost := v_retail_unit * p_quantity;

  -- 5. Check user wallet balance
  SELECT id, balance INTO v_wallet_id, v_wallet_balance
  FROM public.wallets
  WHERE user_id = v_user_id
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    RAISE EXCEPTION 'WALLET_NOT_FOUND: User wallet does not exist.';
  END IF;

  IF v_wallet_balance < v_total_cost THEN
    RAISE EXCEPTION 'INSUFFICIENT_WALLET_BALANCE: Required $%, Available $%.', v_total_cost, v_wallet_balance;
  END IF;

  -- 6. Insert pending order
  INSERT INTO public.esim_orders (
    user_id, provider, bundle_name, quantity, wholesale_price_usd, retail_price_usd, markup_percent, status
  ) VALUES (
    v_user_id, v_provider, v_bundle_name, p_quantity, v_offer.wholesale_price_usd, v_retail_unit, v_markup, 'pending'
  ) RETURNING id INTO v_order_id;

  -- 7. Debit user wallet idempotently using reference esim_<order_id>
  v_reference_id := 'esim_' || v_order_id::TEXT;

  SELECT * INTO v_existing_txn
  FROM public.wallet_transactions
  WHERE reference_id = v_reference_id AND type = 'esim_purchase_debit';

  IF NOT FOUND THEN
    UPDATE public.wallets
    SET balance = balance - v_total_cost, updated_at = NOW()
    WHERE id = v_wallet_id;

    INSERT INTO public.wallet_transactions (
      user_id, wallet_id, amount, balance_before, balance_after, type, reference_id, description
    ) VALUES (
      v_user_id, v_wallet_id, v_total_cost, v_wallet_balance, v_wallet_balance - v_total_cost,
      'esim_purchase_debit', v_reference_id, 'eSIM purchase: ' || v_bundle_name || ' (x' || p_quantity::TEXT || ')'
    );
  END IF;

  RETURN v_order_id;
END;
$$;

REVOKE ALL ON FUNCTION public.request_esim_purchase(TEXT, INT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.request_esim_purchase(TEXT, INT) TO authenticated;

-- 5b. request_instant_refill
CREATE OR REPLACE FUNCTION public.request_instant_refill(
  p_sim_line_id uuid,
  p_offer_id text,
  p_payment_gateway_code text,
  p_amount_usd numeric DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
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

  -- Rate limit check
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
$$;

REVOKE ALL ON FUNCTION public.request_instant_refill(uuid, text, text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.request_instant_refill(uuid, text, text, numeric) TO authenticated;

-- 5c. pay_plan_fee_from_wallet
CREATE OR REPLACE FUNCTION public.pay_plan_fee_from_wallet(
  p_reference_id text,
  p_sim_line_id uuid default null
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_fee numeric;
  v_wallet_id uuid;
  v_balance_before numeric;
  v_balance_after numeric;
  v_txn_id uuid;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Rate limit check
  PERFORM public.enforce_rate_limit('plan_fee', v_user::text);

  IF p_reference_id IS NULL OR length(trim(p_reference_id)) < 8 THEN
    RAISE EXCEPTION 'A reference id of at least 8 characters is required';
  END IF;

  IF p_sim_line_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.sim_lines
    WHERE id = p_sim_line_id AND user_id = v_user
  ) THEN
    RAISE EXCEPTION 'SIM line % does not belong to the caller', p_sim_line_id;
  END IF;

  BEGIN
    SELECT config_value::numeric INTO v_fee
    FROM public.system_configs
    WHERE config_key = 'BASE_SERVICE_FEE_USD';
  EXCEPTION WHEN OTHERS THEN
    v_fee := null;
  END;

  IF v_fee IS NULL OR v_fee <= 0 OR v_fee > 1000 THEN
    v_fee := 2.50;
  END IF;

  SELECT id, balance INTO v_wallet_id, v_balance_before
  FROM public.wallets
  WHERE user_id = v_user
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    RAISE EXCEPTION 'Wallet not found for user %', v_user;
  END IF;

  SELECT id INTO v_txn_id
  FROM public.wallet_transactions
  WHERE type = 'plan_fee_debit' AND reference_id = p_reference_id;
  IF v_txn_id IS NOT NULL THEN
    RETURN v_txn_id;
  END IF;

  IF v_balance_before < v_fee THEN
    RAISE EXCEPTION 'Insufficient wallet balance. Have: %, Need: %', v_balance_before, v_fee;
  END IF;

  v_balance_after := v_balance_before - v_fee;

  UPDATE public.wallets
  SET balance = v_balance_after, total_spent = total_spent + v_fee
  WHERE id = v_wallet_id;

  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, amount, balance_before, balance_after,
    description, reference_id, sim_line_id, status
  ) VALUES (
    v_wallet_id, v_user, 'plan_fee_debit', v_fee, v_balance_before,
    v_balance_after, 'Yearly plan service fee', p_reference_id,
    p_sim_line_id, 'completed'
  ) RETURNING id INTO v_txn_id;

  RETURN v_txn_id;
END;
$$;

REVOKE ALL ON FUNCTION public.pay_plan_fee_from_wallet(text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pay_plan_fee_from_wallet(text, uuid) TO authenticated, service_role;

-- 5d. redeem_referral_points
CREATE OR REPLACE FUNCTION public.redeem_referral_points()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_total_points int := 0;
  v_spent_points int := 0;
  v_balance int := 0;
  v_ref text;
  v_txn_id uuid;
  v_redemption_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Rate limit check
  PERFORM public.enforce_rate_limit('referral_redeem', v_user_id::text);

  PERFORM 1 FROM public.referral_points WHERE referrer_id = v_user_id FOR UPDATE;
  PERFORM 1 FROM public.referral_redemptions WHERE user_id = v_user_id FOR UPDATE;

  SELECT COALESCE(SUM(points), 0) INTO v_total_points
  FROM public.referral_points
  WHERE referrer_id = v_user_id;

  SELECT COALESCE(SUM(points_spent), 0) INTO v_spent_points
  FROM public.referral_redemptions
  WHERE user_id = v_user_id;

  v_balance := v_total_points - v_spent_points;

  IF v_balance < 10 THEN
    RAISE EXCEPTION 'Insufficient points balance for redemption (10 points required, current balance: %)', v_balance;
  END IF;

  v_ref := 'refredeem_' || gen_random_uuid()::text;

  PERFORM public.credit_wallet(
    v_user_id, 2.00, 'referral_credit', 'Redeemed 10 referral points for $2.00 wallet credit', v_ref
  );

  SELECT id INTO v_txn_id
  FROM public.wallet_transactions
  WHERE type = 'referral_credit' AND reference_id = v_ref;

  INSERT INTO public.referral_redemptions (user_id, points_spent, wallet_txn_id)
  VALUES (v_user_id, 10, v_txn_id)
  RETURNING id INTO v_redemption_id;

  RETURN jsonb_build_object(
    'success', true,
    'redemption_id', v_redemption_id,
    'wallet_txn_id', v_txn_id,
    'points_spent', 10,
    'remaining_points', v_balance - 10
  );
END;
$$;

REVOKE ALL ON FUNCTION public.redeem_referral_points() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.redeem_referral_points() TO authenticated;

-- 5e. apply_referral
CREATE OR REPLACE FUNCTION public.apply_referral(
  p_referred_id uuid,
  p_referral_code text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_referrer_id uuid;
  v_already_referred_by text;
  v_key text;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_referred_id THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  -- Rate limit check (enumeration defense)
  v_key := COALESCE(auth.uid(), p_referred_id)::text;
  PERFORM public.enforce_rate_limit('apply_referral', v_key);

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

  INSERT INTO public.referrals (referrer_id, referred_user_id, code)
  VALUES (v_referrer_id, p_referred_id, p_referral_code);
END;
$$;

REVOKE ALL ON FUNCTION public.apply_referral(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.apply_referral(uuid, text) TO authenticated;

-- ── 6. Update check_topup_rate_limit trigger function ─────────────────────────
CREATE OR REPLACE FUNCTION public.check_topup_rate_limit()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
BEGIN
  IF NEW.execution_type = 'refill_instant' THEN
    -- 1. Per SIM Line rate limit (10 seconds)
    IF EXISTS (
      SELECT 1 FROM public.topup_executions
      WHERE sim_line_id = NEW.sim_line_id
        AND execution_type = 'refill_instant'
        AND created_at > (NOW() - INTERVAL '10 seconds')
    ) THEN
      RAISE EXCEPTION USING ERRCODE = 'KS429', MESSAGE = 'Rate limit exceeded: RATE_LIMITED:topup_line:10';
    END IF;

    -- 2. Per User rate limit (instant_refill bucket)
    IF NEW.user_id IS NOT NULL THEN
      PERFORM public.enforce_rate_limit('instant_refill', NEW.user_id::text);
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- ── 7. Observability & Health Jobs ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.check_rate_limit_health()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_count int;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM public.security_logs
  WHERE event_type = 'rate_limited'
    AND created_at > (NOW() - INTERVAL '1 hour');

  IF v_count >= 20 THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.system_alerts
      WHERE kind = 'sustained_rate_limits'
        AND created_at > (NOW() - INTERVAL '6 hours')
    ) THEN
      INSERT INTO public.system_alerts (kind, severity, title, details)
      VALUES (
        'sustained_rate_limits',
        'warning',
        'Sustained Rate Limit Rejections',
        jsonb_build_object('rejections_past_hour', v_count)
      );
    END IF;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.prune_rate_limit_data()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  DELETE FROM public.security_logs
  WHERE created_at < NOW() - INTERVAL '90 days';

  DELETE FROM public.rate_limit_buckets
  WHERE updated_at < NOW() - INTERVAL '7 days';
END;
$$;

COMMIT;
