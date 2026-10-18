-- =============================================================================
-- Migration: 20260908180000_v2_canonical_sim_setup_and_free_grants.sql
-- Description:
--   1. Global free_line_grants registry (6 calendar months per E.164 phone number)
--   2. Drop legacy 1-free-line-per-account limit (check_free_lines_limit)
--   3. Enforce free grant eligibility via trigger trg_enforce_free_grant_eligibility
--   4. Fix has_paid_premium_entitlement (remove unbound payment reuse vulnerability)
--   5. Fix topup_executions schema (add awaiting_funds to status check, add updated_at, wallet_hold_id, funding_kind)
--   6. Revoke insecure authenticated access on sim_setup_orders INSERT and hold capture/release
--   7. Repair capture_sim_setup_holds column references for sim_lines, plan_payments, scheduled_topups
--   8. Add owner-authorized cancel_sim_setup_order RPC
--   9. Add atomic fallback_sim_setup_to_reminders RPC (Free $0 or Standard $2.50)
--  10. Add quote_sim_setup authoritative unified pricing RPC
-- =============================================================================

-- 1. GLOBAL FREE LINE GRANTS REGISTRY
CREATE TABLE IF NOT EXISTS public.free_line_grants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone_e164 TEXT NOT NULL UNIQUE,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  sim_line_id UUID REFERENCES public.sim_lines(id) ON DELETE SET NULL,
  starts_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ends_at TIMESTAMPTZ NOT NULL,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'expired', 'revoked')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_free_line_grants_phone ON public.free_line_grants(phone_e164);
CREATE INDEX IF NOT EXISTS idx_free_line_grants_user ON public.free_line_grants(user_id);

ALTER TABLE public.free_line_grants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_free_line_grants_select ON public.free_line_grants;
CREATE POLICY p_free_line_grants_select ON public.free_line_grants
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

REVOKE INSERT, UPDATE, DELETE ON public.free_line_grants FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.free_line_grants TO service_role;

-- 2. DROP LEGACY 1-FREE-LINE-PER-ACCOUNT RESTRICTIONS
DROP TRIGGER IF EXISTS enforce_free_line_limit ON public.sim_lines;
DROP FUNCTION IF EXISTS public.check_free_lines_limit();

-- 3. TRIGGER FOR 6-MONTH FREE GRANT CREATION & PHONE ELIGIBILITY
CREATE OR REPLACE FUNCTION public.check_free_grant_eligibility()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_grant RECORD;
BEGIN
  IF NEW.plan_type = 'free' THEN
    SELECT * INTO v_grant
    FROM public.free_line_grants
    WHERE phone_e164 = NEW.phone_number;

    IF FOUND THEN
      -- If grant exists and belongs to a different line, reject
      IF v_grant.sim_line_id IS NOT NULL AND v_grant.sim_line_id <> NEW.id THEN
        RAISE EXCEPTION 'This phone number has already used its 6-month Free protection period. Please select Standard or Premium.'
          USING ERRCODE = 'KS403';
      END IF;
      -- Preserve remaining term
      NEW.plan_expires_at := v_grant.ends_at;
    ELSE
      -- Fresh 6-month term
      NEW.plan_expires_at := now() + interval '6 months';
    END IF;
    NEW.protection_tier := 'basic';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_free_grant_eligibility ON public.sim_lines;
CREATE TRIGGER trg_check_free_grant_eligibility
  BEFORE INSERT OR UPDATE OF plan_type ON public.sim_lines
  FOR EACH ROW
  EXECUTE FUNCTION public.check_free_grant_eligibility();

CREATE OR REPLACE FUNCTION public.record_free_grant_after_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF NEW.plan_type = 'free' THEN
    INSERT INTO public.free_line_grants (
      phone_e164, user_id, sim_line_id, starts_at, ends_at, status
    ) VALUES (
      NEW.phone_number,
      NEW.user_id,
      NEW.id,
      now(),
      COALESCE(NEW.plan_expires_at, now() + interval '6 months'),
      'active'
    )
    ON CONFLICT (phone_e164) DO UPDATE
      SET sim_line_id = EXCLUDED.sim_line_id,
          user_id = EXCLUDED.user_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_record_free_grant_after_insert ON public.sim_lines;
CREATE TRIGGER trg_record_free_grant_after_insert
  AFTER INSERT ON public.sim_lines
  FOR EACH ROW
  EXECUTE FUNCTION public.record_free_grant_after_insert();

-- 4. FIX has_paid_premium_entitlement (D04: remove unbound payment reuse)
CREATE OR REPLACE FUNCTION public.has_paid_premium_entitlement(p_sim_line_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_line   RECORD;
  v_window timestamptz;
BEGIN
  SELECT sl.user_id, sl.plan_type, sl.plan_expires_at
  INTO v_line
  FROM public.sim_lines sl
  WHERE sl.id = p_sim_line_id;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF lower(coalesce(v_line.plan_type, '')) <> 'premium' THEN
    RETURN false;
  END IF;

  IF EXISTS (SELECT 1 FROM public.premium_entitlement_grandfather g
             WHERE g.sim_line_id = p_sim_line_id) THEN
    RETURN true;
  END IF;

  IF v_line.plan_expires_at IS NULL OR v_line.plan_expires_at <= now() THEN
    RETURN false;
  END IF;

  v_window := v_line.plan_expires_at - interval '366 days';

  -- Strictly require sim_line_id to match. Never accept unbound account payments.
  IF EXISTS (
    SELECT 1 FROM public.plan_payments pp
    WHERE pp.kind = 'plan'
      AND pp.sim_line_id = p_sim_line_id
      AND pp.created_at >= v_window
  ) THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$$;

REVOKE ALL ON FUNCTION public.has_paid_premium_entitlement(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.has_paid_premium_entitlement(uuid) TO service_role;

-- 5. TOPUP_EXECUTIONS SCHEMA HARDENING (D18)
ALTER TABLE public.topup_executions DROP CONSTRAINT IF EXISTS topup_executions_status_check;
ALTER TABLE public.topup_executions ADD CONSTRAINT topup_executions_status_check
  CHECK (status = ANY (ARRAY[
    'pending'::text,
    'pending_payment'::text,
    'awaiting_funds'::text,
    'processing'::text,
    'routing'::text,
    'success'::text,
    'failed'::text,
    'refunded'::text,
    'cancelled'::text
  ]));

ALTER TABLE public.topup_executions ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE public.topup_executions ADD COLUMN IF NOT EXISTS wallet_hold_id UUID REFERENCES public.wallet_holds(id) ON DELETE SET NULL;
ALTER TABLE public.topup_executions ADD COLUMN IF NOT EXISTS funding_kind TEXT DEFAULT 'wallet_due';

-- 6. SIM_SETUP_ORDERS SECURITY HARDENING (D05, D06)
DROP POLICY IF EXISTS p_sim_setup_orders_insert ON public.sim_setup_orders;
REVOKE INSERT ON public.sim_setup_orders FROM PUBLIC, anon, authenticated;

-- 7. REPAIR capture_sim_setup_holds (D07)
CREATE OR REPLACE FUNCTION public.capture_sim_setup_holds(
  p_order_id       UUID,
  p_provider_tx_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_order         RECORD;
  v_line_id       UUID;
  v_interval_days INTEGER := 30;
  v_rule          RECORD;
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
  IF v_line_id IS NULL THEN
    RAISE EXCEPTION 'Cannot activate setup order without an associated sim_line_id: %', p_order_id;
  END IF;

  -- 3. Activate SIM Line with EXACT column names
  UPDATE public.sim_lines
  SET status = 'active',
      plan_type = v_order.plan,
      protection_tier = CASE WHEN v_order.plan = 'free' THEN 'basic' ELSE v_order.plan END,
      plan_expires_at = now() + INTERVAL '365 days',
      last_topup_at = CASE WHEN v_order.plan = 'premium' THEN now() ELSE last_topup_at END,
      carrier_verified_at = now(),
      is_carrier_verified = true,
      carrier_status = 'confirmed',
      verification_status = 'verified',
      updated_at = now()
  WHERE id = v_line_id;

  -- 4. Record plan payment with EXACT column names
  IF v_order.annual_fee_usd > 0 THEN
    INSERT INTO public.plan_payments (
      user_id, sim_line_id, capture_id, order_id, kind, gross_usd, net_usd,
      paypal_fee_usd, metadata, created_at
    ) VALUES (
      v_order.user_id,
      v_line_id,
      COALESCE(v_order.annual_fee_hold_id::text, 'setup_' || p_order_id::text),
      p_order_id::text,
      'plan',
      v_order.annual_fee_usd,
      v_order.annual_fee_usd,
      0.00,
      jsonb_build_object('billing_model', 'pay_per_refill', 'plan', v_order.plan, 'setup_order_id', p_order_id),
      now()
    );
  END IF;

  -- 5. Calculate cadence and schedule single next occurrence for Premium
  IF v_order.plan = 'premium' AND v_order.carrier_rule_id IS NOT NULL THEN
    SELECT * INTO v_rule FROM public.carrier_rules WHERE id = v_order.carrier_rule_id;
    IF FOUND THEN
      v_interval_days := public.refill_interval_days(v_rule.inactivity_limit_days, v_rule.refill_interval_days_override);
      IF v_interval_days IS NULL OR v_interval_days < 1 THEN
        v_interval_days := 30;
      END IF;

      INSERT INTO public.scheduled_topups (
        user_id, sim_line_id, amount, currency, frequency_days,
        next_execution_at, is_active, status, schedule_type, offer_id, offer_value
      ) VALUES (
        v_order.user_id,
        v_line_id,
        v_order.first_refill_cost_usd,
        'USD',
        v_interval_days,
        now() + (v_interval_days || ' days')::interval,
        true,
        'active',
        'refill_custom',
        v_rule.offer_id,
        v_rule.offer_value
      );
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
$$;

REVOKE ALL ON FUNCTION public.capture_sim_setup_holds(UUID, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.capture_sim_setup_holds(UUID, TEXT) TO service_role;

REVOKE ALL ON FUNCTION public.release_sim_setup_holds(UUID, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.release_sim_setup_holds(UUID, TEXT) TO service_role;

-- 8. OWNER-AUTHORIZED CANCEL SETUP RPC
CREATE OR REPLACE FUNCTION public.cancel_sim_setup_order(
  p_order_id UUID,
  p_reason   TEXT DEFAULT 'Cancelled by user'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_order   RECORD;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;

  SELECT * INTO v_order
  FROM public.sim_setup_orders
  WHERE id = p_order_id FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Setup order not found: %', p_order_id;
  END IF;

  IF v_order.user_id <> v_user_id THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  IF v_order.status IN ('active', 'dispatching') THEN
    RAISE EXCEPTION 'Cannot cancel setup order in status: %', v_order.status;
  END IF;

  IF v_order.status = 'cancelled' THEN
    RETURN jsonb_build_object('success', true, 'status', 'cancelled', 'already_cancelled', true);
  END IF;

  -- Release holds if any
  IF v_order.annual_fee_hold_id IS NOT NULL THEN
    PERFORM public.release_wallet_hold(v_order.annual_fee_hold_id, p_reason);
  END IF;

  IF v_order.first_refill_hold_id IS NOT NULL THEN
    PERFORM public.release_wallet_hold(v_order.first_refill_hold_id, p_reason);
  END IF;

  UPDATE public.sim_setup_orders
  SET status = 'cancelled',
      failure_reason = p_reason,
      updated_at = now()
  WHERE id = p_order_id;

  RETURN jsonb_build_object('success', true, 'status', 'cancelled');
END;
$$;

REVOKE ALL ON FUNCTION public.cancel_sim_setup_order(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_sim_setup_order(UUID, TEXT) TO authenticated, service_role;

-- 9. ATOMIC FALLBACK RPC: fallback_sim_setup_to_reminders
CREATE OR REPLACE FUNCTION public.fallback_sim_setup_to_reminders(
  p_order_id      UUID,
  p_sim_line_id   UUID,
  p_fallback_plan TEXT -- 'free' or 'standard'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id           UUID := auth.uid();
  v_order             RECORD;
  v_line              RECORD;
  v_norm_phone        TEXT;
  v_already_used_free BOOLEAN;
  v_wallet            RECORD;
  v_held_amount       NUMERIC := 0.00;
  v_available         NUMERIC := 0.00;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;

  SELECT * INTO v_order
  FROM public.sim_setup_orders
  WHERE id = p_order_id AND user_id = v_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Setup order not found';
  END IF;

  SELECT * INTO v_line
  FROM public.sim_lines
  WHERE id = p_sim_line_id AND user_id = v_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'SIM line not found';
  END IF;

  v_norm_phone := v_order.phone_number;

  IF p_fallback_plan = 'free' THEN
    -- Check global 6-month free registry
    SELECT EXISTS (
      SELECT 1 FROM public.free_line_grants
      WHERE phone_e164 = v_norm_phone AND (sim_line_id IS NULL OR sim_line_id <> p_sim_line_id)
    ) INTO v_already_used_free;

    IF v_already_used_free THEN
      RETURN jsonb_build_object(
        'success', false,
        'code', 'already_used_free',
        'message', 'This phone number has already used its 6-month Free protection period.'
      );
    END IF;

    -- Record global grant
    INSERT INTO public.free_line_grants (
      phone_e164, user_id, sim_line_id, starts_at, ends_at, status
    ) VALUES (
      v_norm_phone, v_user_id, p_sim_line_id, now(), now() + interval '6 months', 'active'
    )
    ON CONFLICT (phone_e164) DO UPDATE
      SET sim_line_id = EXCLUDED.sim_line_id,
          user_id = EXCLUDED.user_id,
          status = 'active';

    -- Update line to Free
    UPDATE public.sim_lines
    SET plan_type = 'free',
        protection_tier = 'basic',
        plan_expires_at = now() + interval '6 months',
        carrier_status = 'pending',
        verification_status = 'unverified',
        updated_at = now()
    WHERE id = p_sim_line_id;

    -- Cancel any active refill executions or schedules
    UPDATE public.topup_executions
    SET status = 'cancelled', failure_reason = 'fallback_to_free'
    WHERE sim_line_id = p_sim_line_id AND status = 'pending';

    UPDATE public.scheduled_topups
    SET is_active = false, status = 'paused'
    WHERE sim_line_id = p_sim_line_id AND schedule_type <> 'notify';

    RETURN jsonb_build_object(
      'success', true,
      'plan', 'free',
      'expires_at', now() + interval '6 months'
    );

  ELSIF p_fallback_plan = 'standard' THEN
    -- Check wallet balance for $2.50 annual fee
    SELECT * INTO v_wallet
    FROM public.wallets
    WHERE user_id = v_user_id FOR UPDATE;

    IF v_wallet.id IS NULL THEN
      RAISE EXCEPTION 'Wallet not found';
    END IF;

    SELECT COALESCE(SUM(amount), 0.00) INTO v_held_amount
    FROM public.wallet_holds
    WHERE user_id = v_user_id AND status = 'active';

    v_available := v_wallet.balance - v_held_amount;

    IF v_available < 2.50 THEN
      RETURN jsonb_build_object(
        'success', false,
        'code', 'insufficient_funds',
        'available_balance', v_available,
        'required', 2.50
      );
    END IF;

    -- Debit $2.50 fee
    UPDATE public.wallets
    SET balance = balance - 2.50, updated_at = now()
    WHERE user_id = v_user_id;

    INSERT INTO public.wallet_transactions (
      user_id, type, amount, balance_after, description, reference_id
    ) VALUES (
      v_user_id,
      'plan_fee_debit',
      2.50,
      v_wallet.balance - 2.50,
      'Annual Protection Fee (Standard fallback)',
      'std_fallback_' || p_order_id::text
    );

    INSERT INTO public.plan_payments (
      user_id, sim_line_id, capture_id, order_id, kind, gross_usd, net_usd,
      paypal_fee_usd, metadata, created_at
    ) VALUES (
      v_user_id,
      p_sim_line_id,
      'std_fallback_' || p_order_id::text,
      p_order_id::text,
      'plan',
      2.50,
      2.50,
      0.00,
      jsonb_build_object('billing_model', 'pay_per_refill', 'plan', 'standard', 'fallback_from_order', p_order_id),
      now()
    );

    -- Update line to Standard
    UPDATE public.sim_lines
    SET plan_type = 'standard',
        protection_tier = 'standard',
        plan_expires_at = now() + interval '365 days',
        carrier_status = 'pending',
        verification_status = 'unverified',
        updated_at = now()
    WHERE id = p_sim_line_id;

    -- Cancel any active refill executions or schedules
    UPDATE public.topup_executions
    SET status = 'cancelled', failure_reason = 'fallback_to_standard'
    WHERE sim_line_id = p_sim_line_id AND status = 'pending';

    UPDATE public.scheduled_topups
    SET is_active = false, status = 'paused'
    WHERE sim_line_id = p_sim_line_id AND schedule_type <> 'notify';

    RETURN jsonb_build_object(
      'success', true,
      'plan', 'standard',
      'expires_at', now() + interval '365 days'
    );
  ELSE
    RAISE EXCEPTION 'Invalid fallback plan: %', p_fallback_plan;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.fallback_sim_setup_to_reminders(UUID, UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fallback_sim_setup_to_reminders(UUID, UUID, TEXT) TO authenticated, service_role;

-- 10. UNIFIED SERVER QUOTE RPC: quote_sim_setup
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
  v_annual_fee    NUMERIC := 0.00;
  v_first_refill  NUMERIC := 0.00;
  v_total         NUMERIC := 0.00;
  v_interval_days INTEGER := 30;
  v_free_eligible BOOLEAN := true;
  v_premium_quote JSONB;
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
    SELECT COALESCE(config_value::numeric, 2.50) INTO v_annual_fee
    FROM public.system_configs WHERE config_key = 'BASE_SERVICE_FEE_USD';
    v_annual_fee := round(COALESCE(v_annual_fee, 2.50), 2);
    v_first_refill := 0.00;
    v_total := v_annual_fee;
  ELSIF p_plan = 'premium' THEN
    v_premium_quote := public.quote_premium_breakdown(p_carrier_rule_id, p_sim_line_id);
    v_annual_fee := (v_premium_quote->>'annual_fee_usd')::numeric;
    v_first_refill := (v_premium_quote->>'first_refill_cost_usd')::numeric;
    v_total := (v_premium_quote->>'total_charge_usd')::numeric;
    v_interval_days := (v_premium_quote->>'refill_interval_days')::integer;
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
    'free_eligible', v_free_eligible
  );
END;
$$;

REVOKE ALL ON FUNCTION public.quote_sim_setup(TEXT, TEXT, UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quote_sim_setup(TEXT, TEXT, UUID, UUID) TO authenticated, service_role;

-- 11. DISPATCH SIM SETUP VERIFICATION (Server-managed execution pipeline)
CREATE OR REPLACE FUNCTION public.dispatch_sim_setup_verification(
  p_order_id    UUID,
  p_sim_line_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id       UUID := auth.uid();
  v_order         RECORD;
  v_line          RECORD;
  v_rule          RECORD;
  v_execution_id  UUID;
  v_offer_id      TEXT;
  v_offer_value   BIGINT;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;

  SELECT * INTO v_order
  FROM public.sim_setup_orders
  WHERE id = p_order_id AND user_id = v_user_id FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'Order not found'; END IF;

  IF v_order.status NOT IN ('reserved', 'dispatching') THEN
    RAISE EXCEPTION 'Order must be reserved to dispatch verification, currently: %', v_order.status;
  END IF;

  SELECT * INTO v_line
  FROM public.sim_lines
  WHERE id = p_sim_line_id AND user_id = v_user_id;

  IF NOT FOUND THEN RAISE EXCEPTION 'SIM line not found'; END IF;

  -- Link line to order
  UPDATE public.sim_setup_orders
  SET sim_line_id = p_sim_line_id,
      status = 'dispatching',
      updated_at = now()
  WHERE id = p_order_id;

  -- If an execution already exists for this order, return it
  SELECT id INTO v_execution_id
  FROM public.topup_executions
  WHERE wallet_hold_id = v_order.first_refill_hold_id
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_execution_id IS NOT NULL THEN
    RETURN jsonb_build_object('success', true, 'execution_id', v_execution_id, 'status', 'dispatching');
  END IF;

  -- Resolve carrier rule & offer
  IF v_order.carrier_rule_id IS NOT NULL THEN
    SELECT * INTO v_rule FROM public.carrier_rules WHERE id = v_order.carrier_rule_id;
    IF FOUND THEN
      v_offer_id := v_rule.offer_id;
      v_offer_value := v_rule.offer_value;
    END IF;
  END IF;

  INSERT INTO public.topup_executions (
    sim_line_id,
    user_id,
    amount,
    currency,
    execution_type,
    status,
    wallet_hold_id,
    funding_kind,
    offer_id,
    offer_value,
    fulfillment_gateway,
    created_at
  ) VALUES (
    p_sim_line_id,
    v_user_id,
    v_order.first_refill_cost_usd,
    'USD',
    'refill_instant',
    'routing',
    v_order.first_refill_hold_id,
    'setup_hold',
    v_offer_id,
    v_offer_value,
    'API',
    now()
  ) RETURNING id INTO v_execution_id;

  RETURN jsonb_build_object(
    'success', true,
    'execution_id', v_execution_id,
    'status', 'dispatching'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.dispatch_sim_setup_verification(UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dispatch_sim_setup_verification(UUID, UUID) TO authenticated, service_role;

-- 12. FINALIZE SIM SETUP ORDER
CREATE OR REPLACE FUNCTION public.finalize_sim_setup_order(
  p_order_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id      UUID := auth.uid();
  v_order        RECORD;
  v_execution    RECORD;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;

  SELECT * INTO v_order
  FROM public.sim_setup_orders
  WHERE id = p_order_id AND user_id = v_user_id FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'Order not found'; END IF;

  IF v_order.status = 'active' THEN
    RETURN jsonb_build_object('success', true, 'status', 'active', 'plan', v_order.plan);
  END IF;

  IF v_order.status = 'failed' THEN
    RETURN jsonb_build_object('success', false, 'status', 'failed', 'reason', v_order.failure_reason);
  END IF;

  -- For Standard: can capture immediately if holds are reserved
  IF v_order.plan = 'standard' THEN
    RETURN public.capture_sim_setup_holds(p_order_id);
  END IF;

  -- For Premium: check execution outcome
  SELECT * INTO v_execution
  FROM public.topup_executions
  WHERE wallet_hold_id = v_order.first_refill_hold_id
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'status', 'dispatching', 'pending', true);
  END IF;

  IF v_execution.status = 'success' THEN
    RETURN public.capture_sim_setup_holds(p_order_id, v_execution.reloadly_transaction_id);
  ELSIF v_execution.status IN ('failed', 'cancelled') THEN
    RETURN public.release_sim_setup_holds(p_order_id, COALESCE(v_execution.failure_reason, 'Initial recharge failed'));
  ELSE
    -- Still routing / processing
    RETURN jsonb_build_object('success', false, 'status', 'dispatching', 'pending', true);
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.finalize_sim_setup_order(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.finalize_sim_setup_order(UUID) TO authenticated, service_role;

