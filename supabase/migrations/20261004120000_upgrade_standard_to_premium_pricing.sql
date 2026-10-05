-- =============================================================================
-- Migration: 20261004120000_upgrade_standard_to_premium_pricing.sql
-- Description:
--   1. Fair Upgrade Pricing: When an existing Standard SIM line upgrades to Premium,
--      deduct the $2.50 already paid for Standard from the $5.00 Premium fee ($5.00 - $2.50 = $2.50 delta).
--   2. Dynamic Pay-Per-Refill: Today's charge includes the $2.50 upgrade fee + 1st SIM recharge.
--   3. Upgrade Reward: Extends protection for 1 full year (365 days) from the point of upgrade.
--   4. Updates quote_premium_breakdown, plan_price_net, quote_sim_setup, and pay_plan_fee_from_wallet.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. UPDATED plan_price_net
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.plan_price_net(
  p_plan            text DEFAULT 'standard'::text,
  p_sim_line_id     uuid DEFAULT NULL::uuid,
  p_carrier_rule_id uuid DEFAULT NULL::uuid
) RETURNS numeric
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_rule                 record;
  v_offer                record;
  v_standard_fee         numeric;
  v_premium_fee          numeric;
  v_membership_fee       numeric;
  v_is_standard_upgrade  boolean := false;
  v_existing_line        record;
  v_app_fee_pct          numeric;
  v_margin_pct           numeric;
  v_margin_flat          numeric;
  v_step                 integer;
  v_qualifying           numeric;
  v_from_cost            numeric;
  v_per_refill           numeric;
  v_fulfillment_gateway  text;
BEGIN
  -- Read standard and premium membership fees
  SELECT COALESCE(config_value::numeric, 2.50) INTO v_standard_fee
  FROM public.system_configs WHERE config_key = 'MEMBERSHIP_FEE_STANDARD_USD';
  IF v_standard_fee IS NULL OR v_standard_fee <= 0 THEN
    SELECT COALESCE(config_value::numeric, 2.50) INTO v_standard_fee
    FROM public.system_configs WHERE config_key = 'BASE_SERVICE_FEE_USD';
  END IF;
  v_standard_fee := COALESCE(v_standard_fee, 2.50);

  SELECT COALESCE(config_value::numeric, 5.00) INTO v_premium_fee
  FROM public.system_configs WHERE config_key = 'MEMBERSHIP_FEE_PREMIUM_USD';
  v_premium_fee := COALESCE(v_premium_fee, 5.00);

  IF p_plan IS NULL OR lower(p_plan) = 'standard' THEN
    RETURN v_standard_fee;
  END IF;

  IF lower(p_plan) <> 'premium' THEN
    RAISE EXCEPTION 'Unknown plan type: %', p_plan USING ERRCODE = '22023';
  END IF;

  -- Check if upgrading an existing active Standard line
  IF p_sim_line_id IS NOT NULL THEN
    SELECT plan_type, protection_tier INTO v_existing_line
    FROM public.sim_lines WHERE id = p_sim_line_id;
    IF FOUND AND (lower(COALESCE(v_existing_line.plan_type, '')) = 'standard'
                  OR lower(COALESCE(v_existing_line.protection_tier, '')) = 'standard') THEN
      v_is_standard_upgrade := true;
    END IF;
  END IF;

  IF v_is_standard_upgrade THEN
    -- Reward credit: pay only the difference ($5.00 - $2.50 = $2.50)
    v_membership_fee := GREATEST(0.00, v_premium_fee - v_standard_fee);
  ELSE
    v_membership_fee := v_premium_fee;
  END IF;

  -- Resolve carrier rule
  SELECT cr.carrier_id, cr.minimum_topup_amount, cr.inactivity_limit_days,
         cr.refill_interval_days_override, cr.inapp_pricing,
         cr.activity_requirement, cr.validity_qualifying_topup_amount
  INTO v_rule
  FROM public.carrier_rules cr
  WHERE cr.id = COALESCE(
          p_carrier_rule_id,
          (SELECT sl.carrier_rule_id FROM public.sim_lines sl WHERE sl.id = p_sim_line_id),
          (SELECT cr2.id
             FROM public.carrier_rules cr2
             JOIN public.sim_lines sl2 ON sl2.carrier_id = cr2.carrier_id
            WHERE sl2.id = p_sim_line_id
            ORDER BY cr2.created_at DESC
            LIMIT 1));

  IF NOT FOUND OR v_rule.minimum_topup_amount IS NULL OR v_rule.minimum_topup_amount <= 0 THEN
    RAISE EXCEPTION 'No carrier rule with a top-up price exists for this plan'
      USING ERRCODE = '22023';
  END IF;

  IF v_rule.activity_requirement = 'usage_required' THEN
    RAISE EXCEPTION
      'This carrier only resets its inactivity clock on an outgoing call, SMS or data session, so automated refills cannot keep the line active.'
      USING ERRCODE = 'KS422';
  END IF;

  IF v_rule.activity_requirement = 'min_denomination'
     AND v_rule.validity_qualifying_topup_amount IS NOT NULL
     AND v_rule.minimum_topup_amount < v_rule.validity_qualifying_topup_amount THEN
    RAISE EXCEPTION
      'Carrier rule refills % but this carrier only grants line validity from %',
      v_rule.minimum_topup_amount, v_rule.validity_qualifying_topup_amount
      USING ERRCODE = 'KS422';
  END IF;

  v_step := public.refill_interval_days(
              v_rule.inactivity_limit_days, v_rule.refill_interval_days_override);

  IF v_step IS NULL OR v_step < 1 THEN
    RAISE EXCEPTION 'Carrier rule has no usable deactivation window'
      USING ERRCODE = '22023';
  END IF;

  SELECT COALESCE(config_value::numeric, 3.0) INTO v_app_fee_pct
  FROM public.system_configs WHERE config_key = 'APP_FEE_PERCENT';
  SELECT COALESCE(config_value::numeric, 5.0) INTO v_margin_pct
  FROM public.system_configs WHERE config_key = 'PREMIUM_MARGIN_PERCENT';
  SELECT COALESCE(config_value::numeric, 0.324) INTO v_margin_flat
  FROM public.system_configs WHERE config_key = 'PREMIUM_MARGIN_PER_REFILL_USD';
  v_app_fee_pct := COALESCE(v_app_fee_pct, 3.0);
  v_margin_pct  := COALESCE(v_margin_pct, 5.0);
  v_margin_flat := COALESCE(v_margin_flat, 0.324);

  v_qualifying := COALESCE(v_rule.validity_qualifying_topup_amount,
                           v_rule.minimum_topup_amount);

  SELECT * INTO v_offer
  FROM public.carrier_refill_offer(v_rule.carrier_id, v_qualifying);

  IF v_offer.offer_code IS NULL THEN
    RAISE EXCEPTION
      'No supplier currently sells a top-up for this carrier that reaches the % USD its validity rules require, so premium cannot be fulfilled.',
      to_char(v_qualifying, 'FM999990.00')
      USING ERRCODE = 'KS422';
  END IF;

  v_from_cost := v_offer.price_usd * (1.0 + ((v_app_fee_pct + v_margin_pct) / 100.0))
                 + v_margin_flat;

  SELECT COALESCE(c.fulfillment_gateway, 'API') INTO v_fulfillment_gateway
  FROM public.carriers c
  WHERE c.id = v_rule.carrier_id;

  IF v_fulfillment_gateway = 'API' THEN
    v_per_refill := v_from_cost;
  ELSE
    v_per_refill := GREATEST(COALESCE(v_rule.inapp_pricing, 0), v_from_cost);
  END IF;

  -- PAY-PER-REFILL: 1st refill + membership fee (full $5.00 or upgrade delta $2.50)
  RETURN v_membership_fee + v_per_refill;
END;
$function$;

REVOKE ALL ON FUNCTION public.plan_price_net(text, uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.plan_price_net(text, uuid, uuid) TO service_role;

-- -----------------------------------------------------------------------------
-- 2. UPDATED quote_premium_breakdown
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.quote_premium_breakdown(
  p_carrier_rule_id UUID DEFAULT NULL,
  p_sim_line_id     UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_rule                 record;
  v_offer                record;
  v_standard_fee         numeric;
  v_premium_fee          numeric;
  v_annual_fee           numeric;
  v_upgrade_credit       numeric := 0.00;
  v_is_upgrade           boolean := false;
  v_existing_line        record;
  v_app_fee_pct          numeric;
  v_margin_pct           numeric;
  v_margin_flat          numeric;
  v_step                 integer;
  v_qualifying           numeric;
  v_from_cost            numeric;
  v_first_refill         numeric;
  v_total                numeric;
  v_fulfillment_gateway  text;
BEGIN
  -- Read standard and premium membership fees
  SELECT COALESCE(config_value::numeric, 2.50) INTO v_standard_fee
  FROM public.system_configs WHERE config_key = 'MEMBERSHIP_FEE_STANDARD_USD';
  IF v_standard_fee IS NULL OR v_standard_fee <= 0 THEN
    SELECT COALESCE(config_value::numeric, 2.50) INTO v_standard_fee
    FROM public.system_configs WHERE config_key = 'BASE_SERVICE_FEE_USD';
  END IF;
  v_standard_fee := COALESCE(v_standard_fee, 2.50);

  SELECT COALESCE(config_value::numeric, 5.00) INTO v_premium_fee
  FROM public.system_configs WHERE config_key = 'MEMBERSHIP_FEE_PREMIUM_USD';
  v_premium_fee := COALESCE(v_premium_fee, 5.00);

  -- Check if upgrading an existing Standard line
  IF p_sim_line_id IS NOT NULL THEN
    SELECT plan_type, protection_tier INTO v_existing_line
    FROM public.sim_lines WHERE id = p_sim_line_id;
    IF FOUND AND (lower(COALESCE(v_existing_line.plan_type, '')) = 'standard'
                  OR lower(COALESCE(v_existing_line.protection_tier, '')) = 'standard') THEN
      v_is_upgrade := true;
      v_upgrade_credit := v_standard_fee;
    END IF;
  END IF;

  IF v_is_upgrade THEN
    v_annual_fee := round(GREATEST(0.00, v_premium_fee - v_standard_fee), 2);
  ELSE
    v_annual_fee := round(v_premium_fee, 2);
  END IF;

  -- Resolve carrier rule
  SELECT cr.id, cr.carrier_id, cr.minimum_topup_amount, cr.inactivity_limit_days,
         cr.refill_interval_days_override, cr.inapp_pricing,
         cr.activity_requirement, cr.validity_qualifying_topup_amount
  INTO v_rule
  FROM public.carrier_rules cr
  WHERE cr.id = COALESCE(
          p_carrier_rule_id,
          (SELECT sl.carrier_rule_id FROM public.sim_lines sl WHERE sl.id = p_sim_line_id),
          (SELECT cr2.id
             FROM public.carrier_rules cr2
             JOIN public.sim_lines sl2 ON sl2.carrier_id = cr2.carrier_id
            WHERE sl2.id = p_sim_line_id
            ORDER BY cr2.created_at DESC
            LIMIT 1));

  IF NOT FOUND OR v_rule.minimum_topup_amount IS NULL OR v_rule.minimum_topup_amount <= 0 THEN
    RAISE EXCEPTION 'No carrier rule with a top-up price exists for this plan'
      USING ERRCODE = '22023';
  END IF;

  v_step := public.refill_interval_days(
              v_rule.inactivity_limit_days, v_rule.refill_interval_days_override);

  SELECT COALESCE(config_value::numeric, 3.0) INTO v_app_fee_pct
  FROM public.system_configs WHERE config_key = 'APP_FEE_PERCENT';
  SELECT COALESCE(config_value::numeric, 5.0) INTO v_margin_pct
  FROM public.system_configs WHERE config_key = 'PREMIUM_MARGIN_PERCENT';
  SELECT COALESCE(config_value::numeric, 0.324) INTO v_margin_flat
  FROM public.system_configs WHERE config_key = 'PREMIUM_MARGIN_PER_REFILL_USD';
  v_app_fee_pct := COALESCE(v_app_fee_pct, 3.0);
  v_margin_pct  := COALESCE(v_margin_pct, 5.0);
  v_margin_flat := COALESCE(v_margin_flat, 0.324);

  v_qualifying := COALESCE(v_rule.validity_qualifying_topup_amount,
                           v_rule.minimum_topup_amount);

  SELECT * INTO v_offer
  FROM public.carrier_refill_offer(v_rule.carrier_id, v_qualifying);

  IF v_offer.offer_code IS NULL THEN
    RAISE EXCEPTION
      'No supplier currently sells a top-up for this carrier that reaches the % USD its validity rules require.',
      to_char(v_qualifying, 'FM999990.00')
      USING ERRCODE = 'KS422';
  END IF;

  v_from_cost := v_offer.price_usd * (1.0 + ((v_app_fee_pct + v_margin_pct) / 100.0))
                 + v_margin_flat;

  SELECT COALESCE(c.fulfillment_gateway, 'API') INTO v_fulfillment_gateway
  FROM public.carriers c
  WHERE c.id = v_rule.carrier_id;

  IF v_fulfillment_gateway = 'API' THEN
    v_first_refill := round(v_from_cost, 2);
  ELSE
    v_first_refill := round(GREATEST(COALESCE(v_rule.inapp_pricing, 0), v_from_cost), 2);
  END IF;

  v_total := round(v_annual_fee + v_first_refill, 2);

  RETURN jsonb_build_object(
    'success', true,
    'carrier_rule_id', v_rule.id,
    'annual_fee_usd', v_annual_fee,
    'first_refill_cost_usd', v_first_refill,
    'total_charge_usd', v_total,
    'full_annual_fee_usd', round(v_premium_fee, 2),
    'upgrade_credit_usd', round(v_upgrade_credit, 2),
    'is_upgrade', v_is_upgrade,
    'refill_interval_days', v_step,
    'provider_code', v_offer.provider_code,
    'offer_code', v_offer.offer_code,
    'source', 'catalog_pay_per_refill'
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.quote_premium_breakdown(UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quote_premium_breakdown(UUID, UUID) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 3. UPDATED quote_sim_setup
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.quote_sim_setup(
  p_phone_number    TEXT,
  p_plan            TEXT,
  p_carrier_rule_id UUID DEFAULT NULL,
  p_sim_line_id     UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_annual_fee       NUMERIC := 0.00;
  v_first_refill     NUMERIC := 0.00;
  v_total            NUMERIC := 0.00;
  v_interval_days    INTEGER := 30;
  v_free_eligible    BOOLEAN := true;
  v_premium_quote    JSONB;
  v_standard_fee     NUMERIC := 2.50;
  v_is_upgrade       BOOLEAN := false;
  v_upgrade_credit   NUMERIC := 0.00;
  v_full_annual_fee  NUMERIC := 5.00;
BEGIN
  -- Check Free eligibility
  SELECT NOT EXISTS (
    SELECT 1 FROM public.free_line_grants
    WHERE phone_e164 = p_phone_number
      AND (p_sim_line_id IS NULL OR sim_line_id <> p_sim_line_id)
  ) INTO v_free_eligible;

  IF p_plan = 'free' THEN
    v_annual_fee := 0.00;
    v_first_refill := 0.00;
    v_total := 0.00;
  ELSIF p_plan = 'standard' THEN
    SELECT COALESCE(config_value::numeric, 2.50) INTO v_standard_fee
    FROM public.system_configs WHERE config_key = 'MEMBERSHIP_FEE_STANDARD_USD';
    IF v_standard_fee IS NULL OR v_standard_fee <= 0 THEN
      SELECT COALESCE(config_value::numeric, 2.50) INTO v_standard_fee
      FROM public.system_configs WHERE config_key = 'BASE_SERVICE_FEE_USD';
    END IF;
    v_annual_fee := round(COALESCE(v_standard_fee, 2.50), 2);
    v_first_refill := 0.00;
    v_total := v_annual_fee;
  ELSIF p_plan = 'premium' THEN
    v_premium_quote := public.quote_premium_breakdown(p_carrier_rule_id, p_sim_line_id);
    v_annual_fee := (v_premium_quote->>'annual_fee_usd')::numeric;
    v_first_refill := (v_premium_quote->>'first_refill_cost_usd')::numeric;
    v_total := (v_premium_quote->>'total_charge_usd')::numeric;
    v_interval_days := (v_premium_quote->>'refill_interval_days')::integer;
    v_is_upgrade := COALESCE((v_premium_quote->>'is_upgrade')::boolean, false);
    v_upgrade_credit := COALESCE((v_premium_quote->>'upgrade_credit_usd')::numeric, 0.00);
    v_full_annual_fee := COALESCE((v_premium_quote->>'full_annual_fee_usd')::numeric, 5.00);
  ELSE
    RAISE EXCEPTION 'Invalid plan: %', p_plan;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'plan', p_plan,
    'phone_number', p_phone_number,
    'annual_fee_usd', v_annual_fee,
    'first_refill_cost_usd', v_first_refill,
    'total_charge_usd', v_total,
    'refill_interval_days', v_interval_days,
    'free_eligible', v_free_eligible,
    'is_upgrade', v_is_upgrade,
    'upgrade_credit_usd', v_upgrade_credit,
    'full_annual_fee_usd', v_full_annual_fee
  );
END;
$$;

REVOKE ALL ON FUNCTION public.quote_sim_setup(TEXT, TEXT, UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quote_sim_setup(TEXT, TEXT, UUID, UUID) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 4. UPDATED pay_plan_fee_from_wallet
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.pay_plan_fee_from_wallet(
  p_reference_id    text,
  p_sim_line_id     uuid DEFAULT NULL::uuid,
  p_device_id       text DEFAULT NULL::text,
  p_plan            text DEFAULT 'standard'::text,
  p_carrier_rule_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id     uuid := auth.uid();
  v_plan        text := lower(coalesce(p_plan, 'standard'));
  v_fee         numeric(10,2);
  v_balance     numeric(10,2);
  v_existing    RECORD;
  v_guard       jsonb;
  v_line        RECORD;
  v_desc        text;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  IF EXISTS (SELECT 1 FROM public.profiles WHERE id = v_user_id AND is_suspended = true) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Account is suspended.');
  END IF;

  IF p_sim_line_id IS NOT NULL AND NOT EXISTS (
       SELECT 1 FROM public.sim_lines WHERE id = p_sim_line_id AND user_id = v_user_id) THEN
    RAISE EXCEPTION 'SIM line % does not belong to user %', p_sim_line_id, v_user_id;
  END IF;

  PERFORM public.enforce_rate_limit('plan_fee', v_user_id::text);

  -- Idempotency first: a replay is answered from the ledger, never re-priced.
  SELECT id, amount INTO v_existing
  FROM public.wallet_transactions
  WHERE reference_id = p_reference_id AND type = 'plan_fee_debit';

  IF FOUND THEN
    RETURN jsonb_build_object(
      'success', true,
      'already_paid', true,
      'transaction_id', v_existing.id,
      'amount', v_existing.amount,
      'plan', v_plan,
      'reference_id', p_reference_id
    );
  END IF;

  -- Priced server-side with upgrade credit if applicable
  v_fee := round(public.plan_price_net(v_plan, p_sim_line_id, p_carrier_rule_id), 2);

  IF v_fee IS NULL OR v_fee <= 0 THEN
    RAISE EXCEPTION 'Plan % has no usable price', v_plan USING ERRCODE = '22023';
  END IF;

  SELECT COALESCE(balance, 0.00) INTO v_balance
  FROM public.wallets WHERE user_id = v_user_id;

  IF v_balance < v_fee THEN
    RAISE EXCEPTION 'Insufficient wallet balance ($%) for plan fee ($%).', v_balance, v_fee;
  END IF;

  v_guard := public.guard_money_action('plan_fee', v_fee, p_device_id, p_reference_id, v_user_id);
  IF (v_guard ->> 'blocked')::boolean THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'DEVICE_BLOCKED',
      'reason', v_guard ->> 'reason',
      'error', 'This payment was stopped by a security check on this device. Contact support if this is a mistake.'
    );
  END IF;

  v_desc := 'Annual Plan Fee Debit (' || v_plan || ')';
  IF p_sim_line_id IS NOT NULL THEN
    SELECT plan_type INTO v_line FROM public.sim_lines WHERE id = p_sim_line_id;
    IF FOUND AND v_line.plan_type = 'standard' AND v_plan = 'premium' THEN
      v_desc := 'Plan Upgrade Debit (Standard to Premium, $2.50 credit applied)';
    END IF;
  END IF;

  PERFORM public.debit_wallet_for_topup(
    v_user_id, p_sim_line_id, v_fee,
    v_desc,
    p_reference_id, 'plan_fee_debit'
  );

  -- Atomic update of SIM Line: plan_type, protection_tier, and fresh 365-day reward!
  IF p_sim_line_id IS NOT NULL THEN
    UPDATE public.sim_lines
    SET plan_type = v_plan,
        protection_tier = CASE WHEN v_plan = 'free' THEN 'basic' ELSE v_plan END,
        plan_expires_at = clock_timestamp() + INTERVAL '365 days',
        updated_at = clock_timestamp()
    WHERE id = p_sim_line_id AND user_id = v_user_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'amount', v_fee,
    'plan', v_plan,
    'reference_id', p_reference_id
  );
END;
$function$;

REVOKE ALL     ON FUNCTION public.pay_plan_fee_from_wallet(text, uuid, text, text, uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.pay_plan_fee_from_wallet(text, uuid, text, text, uuid) TO authenticated, service_role;

COMMIT;
