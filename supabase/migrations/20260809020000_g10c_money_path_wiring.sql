-- ============================================================================
-- G10c — Device binding + velocity anti-fraud, part 3: the money paths call it.
--
-- Four client-callable RPCs gain one optional trailing `p_device_id text
-- DEFAULT NULL` and one call to `guard_money_action()`. Nothing else in any of
-- the four bodies changes — the diff against the pre-G10 definitions is the
-- parameter, the guard block, and nothing else. That is deliberate: the
-- regression proof (an ordinary user on an ordinary device takes an identical
-- code path) matters more than the feature proof.
--
-- ── Decisions worth not re-deriving ────────────────────────────────────────
--
-- 1. DROP THEN CREATE, NOT `CREATE OR REPLACE`. Adding a parameter to a
--    Postgres function does not replace it, it **overloads** it — and two
--    overloads is `PGRST203` from PostgREST, which is exactly what silently
--    broke both refill money paths between D5b and F2b. Each function is
--    dropped by its full identity argument list first, and its grants are
--    re-issued afterwards because DROP takes them with it.
--
-- 2. THE NEW PARAMETER IS LAST AND DEFAULTS TO NULL, so a shipped APK that
--    knows nothing about it keeps resolving to the same function and keeps
--    working. `p_device_id => NULL` is indistinguishable from an old client,
--    and both are scored as `missing_device_id` rather than treated as clean.
--
-- 3. THE GUARD SITS AFTER ALL VALIDATION AND IMMEDIATELY BEFORE MONEY MOVES.
--    Not at the top: an attacker probing SIM line ids or offer ids would
--    otherwise fill `device_money_events` with attempts that were never
--    payments, and the velocity counts would be measuring their probing rather
--    than their spending. Not after: the point is to stop the debit.
--    Consequence worth knowing — the idempotent early returns in
--    `transfer_wallet_credit` (`already_sent`) and `pay_plan_fee_from_wallet`
--    (`already_paid`) happen *before* the guard, so a retried request replays
--    the original answer and does not log a second attempt.
--
-- 4. EACH FUNCTION REFUSES IN ITS OWN EXISTING DIALECT. `request_instant_refill`
--    raises (new SQLSTATE **KS451**, which does not collide with the KS402 /
--    KS403 / KS429 already in use); the other three return
--    `{success:false, code:'DEVICE_BLOCKED', …}` because that is what their
--    callers already parse. Three refusal shapes is not inconsistency, it is
--    three contracts left alone.
--
-- 5. NOTHING IS RAISED FROM INSIDE `enforce_rate_limit`'s CALL TREE.
--    `guard_money_action` returns jsonb and the caller raises. That is the only
--    safe shape: `enforce_rate_limit` ends in `WHEN OTHERS THEN RAISE NOTICE`
--    and re-raises only KS429/KS403, so anything thrown beneath it is swallowed
--    and fails open on a money path.
--
-- 6. `blocked` IS THE ONLY FIELD THE CALLERS LOOK AT. It is
--    `DEVICE_RISK_ENFORCE AND decision = 'deny'`, so with the shipped config
--    (`enforce = false`) every one of these four functions behaves exactly as it
--    did yesterday while still writing the event and the `security_logs` row.
--    `challenge` is recorded and never blocks: there is no step-up
--    authentication in this product to challenge with, and inventing one that
--    silently declines payments would be worse than flagging them.
-- ============================================================================


-- ---------------------------------------------------------------------------
-- 1. request_instant_refill — the raising one.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.request_instant_refill(uuid, text, text, numeric);

CREATE OR REPLACE FUNCTION public.request_instant_refill(
  p_sim_line_id uuid,
  p_offer_id text,
  p_payment_gateway_code text,
  p_amount_usd numeric DEFAULT NULL::numeric,
  p_device_id text DEFAULT NULL::text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_iso          text;
  v_zen_carrier  text;
  v_offer        RECORD;
  v_base         numeric;
  v_value        numeric;
  v_execution_id uuid;
  v_line_owner   uuid;
  v_payer        uuid;
  v_acting       uuid;
  v_charged      numeric;
  v_chk          RECORD;
  v_guard        jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_suspended = true) THEN
    RAISE EXCEPTION 'Account is suspended. Refills are disabled.';
  END IF;

  PERFORM public.enforce_rate_limit('instant_refill', auth.uid()::text);

  SELECT co.iso_code, ca.zen_carrier, sl.user_id
  INTO v_iso, v_zen_carrier, v_line_owner
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

  -- G10: everything above is validation; from here money moves.
  v_guard := public.guard_money_action('instant_refill', v_base, p_device_id, NULL, auth.uid());
  IF (v_guard ->> 'blocked')::boolean THEN
    RAISE EXCEPTION USING
      ERRCODE = 'KS451',
      MESSAGE = 'DEVICE_BLOCKED:' || COALESCE(v_guard ->> 'reason', 'unknown'),
      DETAIL  = 'device risk score ' || COALESCE(v_guard ->> 'score', '?'),
      HINT    = 'This payment was stopped by a security check on this device.';
  END IF;

  v_payer  := public.resolve_household_payer(auth.uid(), v_line_owner);
  v_acting := CASE WHEN v_payer <> auth.uid() THEN auth.uid() END;

  INSERT INTO public.topup_executions (
    sim_line_id, user_id, acting_user_id, amount, base_cost_usd, payment_gateway_code,
    currency, status, execution_type, execution_time, offer_id, offer_value
  ) VALUES (
    p_sim_line_id, v_payer, v_acting, v_base, v_base, p_payment_gateway_code,
    'USD', 'pending', 'refill_instant', now(), p_offer_id, v_value
  )
  RETURNING id, amount INTO v_execution_id, v_charged;

  IF v_acting IS NOT NULL THEN
    SELECT * INTO v_chk
    FROM public.household_spend_check(v_payer, v_acting, v_charged, v_execution_id);

    IF NOT v_chk.allowed THEN
      RAISE EXCEPTION 'HOUSEHOLD_CAP:%:%:%:%',
        v_chk.reason, v_chk.monthly_cap, v_chk.spent_mtd, v_chk.remaining_usd
        USING ERRCODE = 'KS402';
    END IF;
  END IF;

  RETURN v_execution_id;
END;
$function$;

REVOKE ALL     ON FUNCTION public.request_instant_refill(uuid, text, text, numeric, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.request_instant_refill(uuid, text, text, numeric, text) TO authenticated, service_role;


-- ---------------------------------------------------------------------------
-- 2. request_esim_purchase.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.request_esim_purchase(text, integer);

CREATE OR REPLACE FUNCTION public.request_esim_purchase(
  p_offer_id text,
  p_quantity integer DEFAULT 1,
  p_device_id text DEFAULT NULL::text
)
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
  v_guard jsonb;
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
  WHERE bundle_name = p_offer_id AND is_active = true
  LIMIT 1;

  IF v_offer IS NULL OR v_offer.bundle_name IS NULL THEN
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

  -- G10: last checkpoint before an order exists and the wallet is debited.
  v_guard := public.guard_money_action('esim_purchase', v_total_cost, p_device_id, NULL, v_user_id);
  IF (v_guard ->> 'blocked')::boolean THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'DEVICE_BLOCKED',
      'reason', v_guard ->> 'reason',
      'error', 'This purchase was stopped by a security check on this device. Contact support if this is a mistake.'
    );
  END IF;

  INSERT INTO public.esim_orders (
    user_id, offer_id, bundle_name, provider, quantity, wholesale_price_usd, retail_price_usd, markup_percent, total_amount_usd, status
  ) VALUES (
    v_user_id, p_offer_id, v_offer.bundle_name, v_offer.provider, p_quantity, v_offer.wholesale_price_usd, v_retail_price, v_markup_percent, v_total_cost, 'pending'
  ) RETURNING id INTO v_order_id;

  v_txn_ref := 'esim_' || v_order_id::text;

  PERFORM public.debit_wallet_for_topup(
    p_user_id => v_user_id,
    p_sim_line_id => NULL,
    p_amount => v_total_cost,
    p_description => 'eSIM Purchase: ' || v_offer.bundle_name,
    p_reference_id => v_txn_ref,
    p_txn_type => 'esim_purchase_debit'
  );

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'retail_price_usd', v_retail_price,
    'total_amount_usd', v_total_cost,
    'status', 'pending'
  );
END;
$function$;

REVOKE ALL     ON FUNCTION public.request_esim_purchase(text, integer, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.request_esim_purchase(text, integer, text) TO authenticated, service_role;


-- ---------------------------------------------------------------------------
-- 3. pay_plan_fee_from_wallet.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.pay_plan_fee_from_wallet(text, uuid);

CREATE OR REPLACE FUNCTION public.pay_plan_fee_from_wallet(
  p_reference_id text,
  p_sim_line_id uuid DEFAULT NULL::uuid,
  p_device_id text DEFAULT NULL::text
)
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
  v_guard jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  IF EXISTS (SELECT 1 FROM public.profiles WHERE id = v_user_id AND is_suspended = true) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Account is suspended.');
  END IF;

  IF p_sim_line_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.sim_lines WHERE id = p_sim_line_id AND user_id = v_user_id) THEN
    RAISE EXCEPTION 'SIM line % does not belong to user %', p_sim_line_id, v_user_id;
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
    RAISE EXCEPTION 'Insufficient wallet balance ($%) for annual plan fee ($%).', v_balance, v_fee;
  END IF;

  -- G10: after the idempotency check, so a retry never logs twice.
  v_guard := public.guard_money_action('plan_fee', v_fee, p_device_id, p_reference_id, v_user_id);
  IF (v_guard ->> 'blocked')::boolean THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'DEVICE_BLOCKED',
      'reason', v_guard ->> 'reason',
      'error', 'This payment was stopped by a security check on this device. Contact support if this is a mistake.'
    );
  END IF;

  PERFORM public.debit_wallet_for_topup(
    v_user_id, p_sim_line_id, v_fee, 'Annual Plan Fee Debit', p_reference_id, 'plan_fee_debit'
  );

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

REVOKE ALL     ON FUNCTION public.pay_plan_fee_from_wallet(text, uuid, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.pay_plan_fee_from_wallet(text, uuid, text) TO authenticated, service_role;


-- ---------------------------------------------------------------------------
-- 4. transfer_wallet_credit (G3's gifting path).
--
-- The guard goes in after the giftable-balance check and before
-- `debit_wallet_for_topup`, which is the last statement before the two wallets
-- are locked and moved. Note the KS429 handling above it is unchanged: a
-- rate-limited transfer never reaches the guard and never logs an attempt.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.transfer_wallet_credit(text, numeric, text, text);

CREATE OR REPLACE FUNCTION public.transfer_wallet_credit(
  p_recipient_email text,
  p_amount numeric,
  p_reference_id text DEFAULT NULL::text,
  p_note text DEFAULT NULL::text,
  p_device_id text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_sender_id       UUID := auth.uid();
  v_sender_email    TEXT;
  v_sender_name     TEXT;
  v_recipient_id    UUID;
  v_recipient_email TEXT;
  v_recipient_name  TEXT;
  v_email           TEXT;
  v_amount          NUMERIC(10,2);
  v_ref             TEXT;
  v_note            TEXT;
  v_min             NUMERIC := 1.00;
  v_max             NUMERIC := 100.00;
  v_daily_max       NUMERIC := 250.00;
  v_sent_today      NUMERIC;
  v_balance         NUMERIC;
  v_giftable        NUMERIC;
  v_existing        public.wallet_transactions%ROWTYPE;
  v_wallet_id       UUID;
  v_before          NUMERIC;
  v_after           NUMERIC;
  v_debit_id        UUID;
  v_credit_id       UUID;
  v_lock            RECORD;
  v_amount_text     TEXT;
  v_guard           JSONB;
BEGIN
  IF v_sender_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'code', 'UNAUTHORIZED',
                              'error', 'You must be signed in to send credit.');
  END IF;

  v_note := NULLIF(LEFT(TRIM(COALESCE(p_note, '')), 140), '');
  v_ref  := NULLIF(TRIM(COALESCE(p_reference_id, '')), '');
  IF v_ref IS NULL THEN
    v_ref := 'gift_' || LEFT(v_sender_id::text, 8) || '_'
             || (EXTRACT(EPOCH FROM clock_timestamp()) * 1000000)::bigint::text;
  END IF;

  SELECT * INTO v_existing
  FROM public.wallet_transactions
  WHERE reference_id = v_ref AND type = 'gift_sent' AND user_id = v_sender_id;

  IF v_existing.id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', true,
      'already_sent', true,
      'transaction_id', v_existing.id,
      'reference_id', v_ref,
      'amount', v_existing.amount,
      'recipient_email', v_existing.metadata #>> '{gift,counterparty_email}',
      'recipient_name', v_existing.metadata #>> '{gift,counterparty_name}'
    );
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'code', 'INVALID_AMOUNT',
                              'error', 'Enter an amount greater than zero.');
  END IF;
  v_amount := ROUND(p_amount, 2);

  SELECT COALESCE(MAX(CASE WHEN config_key = 'GIFT_MIN_USD'       THEN config_value::numeric END), 1.00),
         COALESCE(MAX(CASE WHEN config_key = 'GIFT_MAX_USD'       THEN config_value::numeric END), 100.00),
         COALESCE(MAX(CASE WHEN config_key = 'GIFT_DAILY_MAX_USD' THEN config_value::numeric END), 250.00)
    INTO v_min, v_max, v_daily_max
  FROM public.system_configs
  WHERE config_key IN ('GIFT_MIN_USD', 'GIFT_MAX_USD', 'GIFT_DAILY_MAX_USD');

  IF v_amount < v_min THEN
    RETURN jsonb_build_object('success', false, 'code', 'BELOW_MINIMUM',
      'error', 'The smallest gift is $' || to_char(v_min, 'FM99999990.00') || '.',
      'minimum', v_min);
  END IF;

  IF v_amount > v_max THEN
    RETURN jsonb_build_object('success', false, 'code', 'ABOVE_MAXIMUM',
      'error', 'The largest single gift is $' || to_char(v_max, 'FM99999990.00') || '.',
      'maximum', v_max);
  END IF;

  IF EXISTS (SELECT 1 FROM public.profiles
             WHERE id = v_sender_id AND is_suspended = true) THEN
    RETURN jsonb_build_object('success', false, 'code', 'SENDER_SUSPENDED',
                              'error', 'Your account is suspended.');
  END IF;

  IF EXISTS (SELECT 1 FROM public.account_deletions
             WHERE user_id = v_sender_id
               AND status IN ('requested', 'frozen', 'draining')) THEN
    RETURN jsonb_build_object('success', false, 'code', 'SENDER_CLOSING',
      'error', 'Your account is scheduled for deletion, so transfers are closed.');
  END IF;

  v_email := LOWER(TRIM(COALESCE(p_recipient_email, '')));
  IF v_email = '' OR v_email NOT LIKE '%_@_%.__%' THEN
    RETURN jsonb_build_object('success', false, 'code', 'INVALID_EMAIL',
                              'error', 'Enter a valid email address.');
  END IF;

  BEGIN
    PERFORM public.enforce_rate_limit('gift_credit', v_sender_id::text);
  EXCEPTION WHEN SQLSTATE 'KS429' THEN
    RETURN jsonb_build_object(
      'success', false, 'code', 'KS429',
      'error', 'Too many transfers just now. Try again in a little while.');
  END;

  SELECT u.id, u.email INTO v_recipient_id, v_recipient_email
  FROM auth.users u
  WHERE LOWER(u.email) = v_email
    AND u.deleted_at IS NULL
    AND COALESCE(u.is_anonymous, false) = false;

  IF v_recipient_id IS NULL THEN
    INSERT INTO public.security_logs (user_id, event_type, description, metadata)
    VALUES (v_sender_id, 'gift_recipient_not_found',
            'Wallet gift attempted to an address with no KeepSIMs account',
            jsonb_build_object('email_hash',
                               encode(sha256(v_email::bytea), 'hex')));

    RETURN jsonb_build_object('success', false, 'code', 'RECIPIENT_NOT_FOUND',
      'error', 'No KeepSIMs account uses that email address yet.');
  END IF;

  IF v_recipient_id = v_sender_id THEN
    RETURN jsonb_build_object('success', false, 'code', 'CANNOT_GIFT_SELF',
                              'error', 'You cannot send credit to yourself.');
  END IF;

  IF EXISTS (SELECT 1 FROM public.profiles
             WHERE id = v_recipient_id AND is_suspended = true)
     OR EXISTS (SELECT 1 FROM public.account_deletions
                WHERE user_id = v_recipient_id
                  AND status IN ('requested', 'frozen', 'draining', 'drained')) THEN
    RETURN jsonb_build_object('success', false, 'code', 'RECIPIENT_UNAVAILABLE',
      'error', 'That account cannot receive credit right now.');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.wallets WHERE user_id = v_recipient_id) THEN
    RETURN jsonb_build_object('success', false, 'code', 'RECIPIENT_UNAVAILABLE',
      'error', 'That account cannot receive credit right now.');
  END IF;

  SELECT COALESCE(SUM(amount), 0) INTO v_sent_today
  FROM public.wallet_transactions
  WHERE user_id = v_sender_id
    AND type = 'gift_sent'
    AND status = 'completed'
    AND created_at > (clock_timestamp() - INTERVAL '24 hours');

  IF v_sent_today + v_amount > v_daily_max THEN
    RETURN jsonb_build_object('success', false, 'code', 'DAILY_LIMIT',
      'error', 'That would pass your $' || to_char(v_daily_max, 'FM99999990.00')
               || ' daily transfer limit. Sent in the last 24 hours: $'
               || to_char(v_sent_today, 'FM99999990.00') || '.',
      'daily_max', v_daily_max, 'sent_today', v_sent_today);
  END IF;

  FOR v_lock IN
    SELECT id FROM public.wallets
    WHERE user_id IN (v_sender_id, v_recipient_id)
    ORDER BY user_id
  LOOP
    PERFORM 1 FROM public.wallets WHERE id = v_lock.id FOR UPDATE;
  END LOOP;

  SELECT COALESCE(balance, 0) INTO v_balance
  FROM public.wallets WHERE user_id = v_sender_id;

  IF v_balance < v_amount THEN
    RETURN jsonb_build_object('success', false, 'code', 'INSUFFICIENT_FUNDS',
      'error', 'Your balance is $' || to_char(v_balance, 'FM99999990.00') || '.',
      'balance', v_balance);
  END IF;

  SELECT LEAST(
           v_balance,
           GREATEST(
             COALESCE(SUM(amount) FILTER (WHERE type IN ('deposit', 'gift_received')), 0)
             - COALESCE(SUM(amount) FILTER (WHERE type = 'gift_sent'), 0),
             0)
         )
    INTO v_giftable
  FROM public.wallet_transactions
  WHERE user_id = v_sender_id AND status = 'completed';

  IF v_amount > COALESCE(v_giftable, 0) THEN
    RETURN jsonb_build_object('success', false, 'code', 'NOT_GIFTABLE',
      'error', 'Only credit you added yourself can be sent on. Available to '
               || 'send: $' || to_char(COALESCE(v_giftable, 0), 'FM99999990.00') || '.',
      'giftable', COALESCE(v_giftable, 0),
      'balance', v_balance);
  END IF;

  -- G10: the last checkpoint before two wallets move.
  v_guard := public.guard_money_action('gift_send', v_amount, p_device_id, v_ref, v_sender_id);
  IF (v_guard ->> 'blocked')::boolean THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'DEVICE_BLOCKED',
      'reason', v_guard ->> 'reason',
      'error', 'This transfer was stopped by a security check on this device. Contact support if this is a mistake.');
  END IF;

  SELECT u.email, p.full_name INTO v_sender_email, v_sender_name
  FROM auth.users u
  LEFT JOIN public.profiles p ON p.id = u.id
  WHERE u.id = v_sender_id;

  SELECT full_name INTO v_recipient_name
  FROM public.profiles WHERE id = v_recipient_id;

  v_debit_id := public.debit_wallet_for_topup(
    v_sender_id, NULL, v_amount,
    'Gift to ' || COALESCE(NULLIF(v_recipient_name, ''), v_recipient_email),
    v_ref, 'gift_sent'
  );

  SELECT id, balance INTO v_wallet_id, v_before
  FROM public.wallets WHERE user_id = v_recipient_id FOR UPDATE;

  v_after := v_before + v_amount;

  UPDATE public.wallets
  SET balance = v_after,
      total_deposited = COALESCE(total_deposited, 0) + v_amount
  WHERE id = v_wallet_id;

  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, amount, balance_before, balance_after,
    description, reference_id, status, metadata
  ) VALUES (
    v_wallet_id, v_recipient_id, 'gift_received', v_amount, v_before, v_after,
    'Gift from ' || COALESCE(NULLIF(v_sender_name, ''), v_sender_email),
    v_ref, 'completed',
    jsonb_build_object('gift', jsonb_strip_nulls(jsonb_build_object(
      'direction', 'received',
      'counterparty_user_id', v_sender_id,
      'counterparty_email', v_sender_email,
      'counterparty_name', NULLIF(v_sender_name, ''),
      'note', v_note)))
  ) RETURNING id INTO v_credit_id;

  UPDATE public.wallet_transactions
  SET metadata = jsonb_build_object('gift', jsonb_strip_nulls(jsonb_build_object(
        'direction', 'sent',
        'counterparty_user_id', v_recipient_id,
        'counterparty_email', v_recipient_email,
        'counterparty_name', NULLIF(v_recipient_name, ''),
        'note', v_note)))
  WHERE id = v_debit_id;

  v_amount_text := to_char(v_amount, 'FM99999990.00');

  INSERT INTO public.notifications (user_id, category, title, body, action_url)
  VALUES (
    v_recipient_id,
    'wallet_credit',
    'You received $' || v_amount_text,
    COALESCE(NULLIF(v_sender_name, ''), v_sender_email)
      || ' sent you $' || v_amount_text || ' of KeepSIMs credit.'
      || CASE WHEN v_note IS NULL THEN '' ELSE ' "' || v_note || '"' END,
    '/wallet'
  );

  RETURN jsonb_build_object(
    'success', true,
    'already_sent', false,
    'reference_id', v_ref,
    'amount', v_amount,
    'transaction_id', v_debit_id,
    'credit_transaction_id', v_credit_id,
    'recipient_email', v_recipient_email,
    'recipient_name', NULLIF(v_recipient_name, ''),
    'balance_after', v_balance - v_amount
  );
END;
$function$;

REVOKE ALL     ON FUNCTION public.transfer_wallet_credit(text, numeric, text, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.transfer_wallet_credit(text, numeric, text, text, text) TO authenticated, service_role;
