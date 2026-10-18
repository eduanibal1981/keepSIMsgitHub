-- =============================================================================
-- Migration: 20260908120000_sim_setup_orders_and_pay_per_refill.sql
-- Description: KeepSIMs Pay-Per-Refill Commercial Model & SIM Setup Orders
--   1. sim_setup_orders: Resumable setup tracking across deposits/restarts
--   2. In-flight protection on wallet_holds (carrier_in_flight)
--   3. Updated plan_price_net: Single initial refill + annual fee (eliminates 1yr upfront multiplication)
--   4. quote_premium_breakdown RPC: Authoritative itemized quote for client & server
--   5. Atomic RPCs: create_sim_setup_order, reserve_sim_setup_holds, capture_sim_setup_holds, release_sim_setup_holds
-- =============================================================================

-- 1. CARRIER IN-FLIGHT PROTECTION ON WALLET HOLDS
ALTER TABLE public.wallet_holds
  ADD COLUMN IF NOT EXISTS carrier_in_flight BOOLEAN NOT NULL DEFAULT false;

-- 2. SIM SETUP ORDERS TABLE
CREATE TABLE IF NOT EXISTS public.sim_setup_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  sim_line_id UUID REFERENCES public.sim_lines(id) ON DELETE CASCADE,
  carrier_rule_id UUID REFERENCES public.carrier_rules(id) ON DELETE SET NULL,
  plan TEXT NOT NULL CHECK (plan IN ('free', 'standard', 'premium')),
  phone_number TEXT NOT NULL,
  country_code TEXT,
  carrier_code TEXT,
  annual_fee_usd NUMERIC NOT NULL DEFAULT 0.00,
  first_refill_cost_usd NUMERIC NOT NULL DEFAULT 0.00,
  total_charge_usd NUMERIC NOT NULL DEFAULT 0.00,
  annual_fee_hold_id UUID REFERENCES public.wallet_holds(id) ON DELETE SET NULL,
  first_refill_hold_id UUID REFERENCES public.wallet_holds(id) ON DELETE SET NULL,
  provider TEXT,
  provider_tx_id TEXT,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (
    status IN ('draft', 'awaiting_funds', 'reserved', 'dispatching', 'active', 'failed', 'cancelled')
  ),
  failure_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sim_setup_orders_user 
  ON public.sim_setup_orders(user_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_sim_setup_orders_sim_line
  ON public.sim_setup_orders(sim_line_id);

-- RLS
ALTER TABLE public.sim_setup_orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_sim_setup_orders_select ON public.sim_setup_orders;
CREATE POLICY p_sim_setup_orders_select ON public.sim_setup_orders
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS p_sim_setup_orders_insert ON public.sim_setup_orders;
CREATE POLICY p_sim_setup_orders_insert ON public.sim_setup_orders
  FOR INSERT TO authenticated
  WITH CHECK (user_id = (SELECT auth.uid()));

-- =============================================================================
-- 3. UPDATED plan_price_net (Pay-Per-Refill Model)
-- =============================================================================
-- Replaces multi-refill upfront multiplication with 1 initial refill + annual fee.
-- =============================================================================
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
  v_base_fee             numeric;
  v_app_fee_pct          numeric;
  v_margin_pct           numeric;
  v_margin_flat          numeric;
  v_step                 integer;
  v_qualifying           numeric;
  v_from_cost            numeric;
  v_per_refill           numeric;
  v_fulfillment_gateway  text;
BEGIN
  SELECT COALESCE(config_value::numeric, 2.50) INTO v_base_fee
  FROM public.system_configs WHERE config_key = 'BASE_SERVICE_FEE_USD';
  v_base_fee := COALESCE(v_base_fee, 2.50);

  IF p_plan IS NULL OR p_plan = 'standard' THEN
    RETURN v_base_fee;
  END IF;

  IF p_plan <> 'premium' THEN
    RAISE EXCEPTION 'Unknown plan type: %', p_plan USING ERRCODE = '22023';
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

  -- PAY-PER-REFILL: 1st refill + annual subscription fee
  RETURN v_base_fee + v_per_refill;
END;
$function$;

REVOKE ALL ON FUNCTION public.plan_price_net(text, uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.plan_price_net(text, uuid, uuid) TO service_role;

-- =============================================================================
-- 4. RPC: quote_premium_breakdown
-- =============================================================================
-- Returns exact itemized breakdown for Premium setup (Annual Fee + 1st Refill)
-- =============================================================================
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
  v_base_fee             numeric;
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
  SELECT COALESCE(config_value::numeric, 2.50) INTO v_base_fee
  FROM public.system_configs WHERE config_key = 'BASE_SERVICE_FEE_USD';
  v_base_fee := COALESCE(v_base_fee, 2.50);

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

  v_total := round(v_base_fee + v_first_refill, 2);

  RETURN jsonb_build_object(
    'success', true,
    'carrier_rule_id', v_rule.id,
    'annual_fee_usd', round(v_base_fee, 2),
    'first_refill_cost_usd', v_first_refill,
    'total_charge_usd', v_total,
    'refill_interval_days', v_step,
    'provider_code', v_offer.provider_code,
    'offer_code', v_offer.offer_code,
    'delivery_type', v_offer.delivery_type
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.quote_premium_breakdown(UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quote_premium_breakdown(UUID, UUID) TO authenticated, service_role;

-- =============================================================================
-- 5. RPC: create_sim_setup_order
-- =============================================================================
CREATE OR REPLACE FUNCTION public.create_sim_setup_order(
  p_phone_number    TEXT,
  p_plan            TEXT,
  p_carrier_rule_id UUID DEFAULT NULL,
  p_country_code    TEXT DEFAULT NULL,
  p_carrier_code    TEXT DEFAULT NULL,
  p_sim_line_id     UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_user_id             UUID;
  v_breakdown           JSONB;
  v_annual_fee          NUMERIC := 0.00;
  v_first_refill        NUMERIC := 0.00;
  v_total               NUMERIC := 0.00;
  v_order_id            UUID;
  v_existing            RECORD;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF p_plan NOT IN ('free', 'standard', 'premium') THEN
    RAISE EXCEPTION 'Invalid plan: %', p_plan;
  END IF;

  IF p_plan = 'free' THEN
    v_annual_fee := 0.00;
    v_first_refill := 0.00;
    v_total := 0.00;
  ELSIF p_plan = 'standard' THEN
    SELECT COALESCE(config_value::numeric, 2.50) INTO v_annual_fee
    FROM public.system_configs WHERE config_key = 'BASE_SERVICE_FEE_USD';
    v_annual_fee := round(COALESCE(v_annual_fee, 2.50), 2);
    v_first_refill := 0.00;
    v_total := v_annual_fee;
  ELSE
    -- Premium
    v_breakdown := public.quote_premium_breakdown(p_carrier_rule_id, p_sim_line_id);
    v_annual_fee := (v_breakdown->>'annual_fee_usd')::numeric;
    v_first_refill := (v_breakdown->>'first_refill_cost_usd')::numeric;
    v_total := (v_breakdown->>'total_charge_usd')::numeric;
  END IF;

  -- Reuse existing draft order for same phone and plan if active
  SELECT * INTO v_existing
  FROM public.sim_setup_orders
  WHERE user_id = v_user_id 
    AND phone_number = p_phone_number 
    AND plan = p_plan 
    AND status IN ('draft', 'awaiting_funds')
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_existing.id IS NOT NULL THEN
    UPDATE public.sim_setup_orders
    SET annual_fee_usd = v_annual_fee,
        first_refill_cost_usd = v_first_refill,
        total_charge_usd = v_total,
        carrier_rule_id = COALESCE(p_carrier_rule_id, carrier_rule_id),
        sim_line_id = COALESCE(p_sim_line_id, sim_line_id),
        updated_at = now()
    WHERE id = v_existing.id
    RETURNING id INTO v_order_id;
  ELSE
    INSERT INTO public.sim_setup_orders (
      user_id, sim_line_id, carrier_rule_id, plan, phone_number,
      country_code, carrier_code, annual_fee_usd, first_refill_cost_usd,
      total_charge_usd, status, created_at, updated_at
    ) VALUES (
      v_user_id, p_sim_line_id, p_carrier_rule_id, p_plan, p_phone_number,
      p_country_code, p_carrier_code, v_annual_fee, v_first_refill,
      v_total, 'draft', now(), now()
    ) RETURNING id INTO v_order_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'plan', p_plan,
    'phone_number', p_phone_number,
    'annual_fee_usd', v_annual_fee,
    'first_refill_cost_usd', v_first_refill,
    'total_charge_usd', v_total,
    'status', 'draft'
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.create_sim_setup_order(TEXT, TEXT, UUID, TEXT, TEXT, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_sim_setup_order(TEXT, TEXT, UUID, TEXT, TEXT, UUID) TO authenticated, service_role;

-- =============================================================================
-- 6. RPC: reserve_sim_setup_holds
-- =============================================================================
CREATE OR REPLACE FUNCTION public.reserve_sim_setup_holds(p_order_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_user_id             UUID;
  v_order               RECORD;
  v_wallet              RECORD;
  v_held_amount         NUMERIC := 0.00;
  v_available           NUMERIC := 0.00;
  v_fee_hold_id         UUID;
  v_refill_hold_id      UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT * INTO v_order
  FROM public.sim_setup_orders
  WHERE id = p_order_id FOR UPDATE;

  IF v_order.id IS NULL THEN
    RAISE EXCEPTION 'Setup order not found: %', p_order_id;
  END IF;

  IF v_order.user_id <> v_user_id THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  IF v_order.status = 'reserved' AND v_order.annual_fee_hold_id IS NOT NULL THEN
    RETURN jsonb_build_object('success', true, 'status', 'reserved', 'order_id', p_order_id);
  END IF;

  IF v_order.status NOT IN ('draft', 'awaiting_funds') THEN
    RAISE EXCEPTION 'Cannot reserve holds for order in status: %', v_order.status;
  END IF;

  -- Lock wallet
  SELECT * INTO v_wallet
  FROM public.wallets
  WHERE user_id = v_user_id FOR UPDATE;

  IF v_wallet.id IS NULL THEN
    RAISE EXCEPTION 'Wallet not found for user';
  END IF;

  SELECT COALESCE(SUM(amount), 0.00) INTO v_held_amount
  FROM public.wallet_holds
  WHERE user_id = v_user_id AND status = 'active';

  v_available := v_wallet.balance - v_held_amount;

  IF v_available < v_order.total_charge_usd THEN
    UPDATE public.sim_setup_orders
    SET status = 'awaiting_funds', updated_at = now()
    WHERE id = p_order_id;

    RETURN jsonb_build_object(
      'success', false,
      'code', 'insufficient_funds',
      'available_balance', v_available,
      'required_balance', v_order.total_charge_usd,
      'shortfall', round(v_order.total_charge_usd - v_available, 2)
    );
  END IF;

  -- 1. Hold annual fee if > 0
  IF v_order.annual_fee_usd > 0 THEN
    v_fee_hold_id := public.reserve_wallet_funds(
      v_user_id,
      v_order.annual_fee_usd,
      'plan_fee',
      'setup_fee_' || p_order_id::text,
      'Annual KeepSIMs Protection Fee Hold',
      240 -- 4 hours TTL
    );
  END IF;

  -- 2. Hold first refill if > 0
  IF v_order.first_refill_cost_usd > 0 THEN
    v_refill_hold_id := public.reserve_wallet_funds(
      v_user_id,
      v_order.first_refill_cost_usd,
      'refill_scheduled',
      'setup_refill_' || p_order_id::text,
      'Initial SIM Recharge Hold',
      240 -- 4 hours TTL
    );
  END IF;

  UPDATE public.sim_setup_orders
  SET annual_fee_hold_id = v_fee_hold_id,
      first_refill_hold_id = v_refill_hold_id,
      status = 'reserved',
      updated_at = now()
  WHERE id = p_order_id;

  RETURN jsonb_build_object(
    'success', true,
    'status', 'reserved',
    'annual_fee_hold_id', v_fee_hold_id,
    'first_refill_hold_id', v_refill_hold_id,
    'total_charge_usd', v_order.total_charge_usd
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.reserve_sim_setup_holds(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reserve_sim_setup_holds(UUID) TO authenticated, service_role;

-- =============================================================================
-- 7. RPC: capture_sim_setup_holds
-- =============================================================================
CREATE OR REPLACE FUNCTION public.capture_sim_setup_holds(
  p_order_id       UUID,
  p_provider_tx_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_order         RECORD;
  v_line_id       UUID;
  v_interval_days INTEGER := 30;
BEGIN
  SELECT * INTO v_order
  FROM public.sim_setup_orders
  WHERE id = p_order_id FOR UPDATE;

  IF v_order.id IS NULL THEN
    RAISE EXCEPTION 'Setup order not found: %', p_order_id;
  END IF;

  IF v_order.status = 'active' THEN
    RETURN jsonb_build_object('success', true, 'status', 'active', 'already_captured', true);
  END IF;

  -- 1. Capture annual fee hold
  IF v_order.annual_fee_hold_id IS NOT NULL THEN
    PERFORM public.capture_wallet_hold(
      v_order.annual_fee_hold_id,
      'plan_fee_debit',
      'Annual Protection Fee (' || v_order.plan || ')',
      jsonb_build_object('setup_order_id', p_order_id, 'plan', v_order.plan)
    );
  END IF;

  -- 2. Capture initial refill hold
  IF v_order.first_refill_hold_id IS NOT NULL THEN
    PERFORM public.capture_wallet_hold(
      v_order.first_refill_hold_id,
      'topup_debit',
      'Initial SIM Recharge (' || v_order.phone_number || ')',
      jsonb_build_object('setup_order_id', p_order_id, 'provider_tx_id', p_provider_tx_id)
    );
  END IF;

  v_line_id := v_order.sim_line_id;

  -- 3. Activate SIM Line
  IF v_line_id IS NOT NULL THEN
    UPDATE public.sim_lines
    SET status = 'active',
        plan = v_order.plan,
        plan_expires_at = now() + INTERVAL '365 days',
        last_topup_date = now(),
        last_verified_at = now(),
        liveness_signal = 'recharge_confirmed',
        updated_at = now()
    WHERE id = v_line_id;

    -- Record plan payment
    INSERT INTO public.plan_payments (
      user_id, sim_line_id, plan, amount_usd, gateway, status,
      payment_reference, billing_model, created_at
    ) VALUES (
      v_order.user_id, v_line_id, v_order.plan, v_order.annual_fee_usd, 'wallet', 'completed',
      'setup_' || p_order_id::text, 'pay_per_refill', now()
    );

    -- Calculate cadence for next single scheduled refill
    IF v_order.plan = 'premium' AND v_order.carrier_rule_id IS NOT NULL THEN
      SELECT public.refill_interval_days(inactivity_limit_days, refill_interval_days_override)
      INTO v_interval_days
      FROM public.carrier_rules
      WHERE id = v_order.carrier_rule_id;

      IF v_interval_days IS NULL OR v_interval_days < 1 THEN
        v_interval_days := 30;
      END IF;

      -- Create initial recurring schedule anchored to this recharge date
      INSERT INTO public.scheduled_topups (
        user_id, sim_line_id, carrier_rule_id, frequency, execution_type,
        next_refill_date, status, created_at, updated_at
      ) VALUES (
        v_order.user_id, v_line_id, v_order.carrier_rule_id, 'custom', 'refill_custom',
        now() + (v_interval_days || ' days')::interval, 'pending', now(), now()
      ) ON CONFLICT DO NOTHING;
    END IF;
  END IF;

  UPDATE public.sim_setup_orders
  SET status = 'active',
      provider_tx_id = COALESCE(p_provider_tx_id, provider_tx_id),
      updated_at = now()
  WHERE id = p_order_id;

  RETURN jsonb_build_object(
    'success', true,
    'status', 'active',
    'sim_line_id', v_line_id,
    'plan', v_order.plan
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.capture_sim_setup_holds(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.capture_sim_setup_holds(UUID, TEXT) TO authenticated, service_role;

-- =============================================================================
-- 8. RPC: release_sim_setup_holds
-- =============================================================================
CREATE OR REPLACE FUNCTION public.release_sim_setup_holds(
  p_order_id UUID,
  p_reason   TEXT DEFAULT 'Recharge failed or cancelled'
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_order RECORD;
BEGIN
  SELECT * INTO v_order
  FROM public.sim_setup_orders
  WHERE id = p_order_id FOR UPDATE;

  IF v_order.id IS NULL THEN
    RAISE EXCEPTION 'Setup order not found: %', p_order_id;
  END IF;

  IF v_order.status = 'failed' THEN
    RETURN jsonb_build_object('success', true, 'status', 'failed', 'already_released', true);
  END IF;

  -- Release annual fee hold
  IF v_order.annual_fee_hold_id IS NOT NULL THEN
    PERFORM public.release_wallet_hold(v_order.annual_fee_hold_id, p_reason);
  END IF;

  -- Release initial refill hold
  IF v_order.first_refill_hold_id IS NOT NULL THEN
    PERFORM public.release_wallet_hold(v_order.first_refill_hold_id, p_reason);
  END IF;

  UPDATE public.sim_setup_orders
  SET status = 'failed',
      failure_reason = p_reason,
      updated_at = now()
  WHERE id = p_order_id;

  RETURN jsonb_build_object(
    'success', true,
    'status', 'failed',
    'restored_amount', v_order.total_charge_usd,
    'reason', p_reason
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.release_sim_setup_holds(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.release_sim_setup_holds(UUID, TEXT) TO authenticated, service_role;
