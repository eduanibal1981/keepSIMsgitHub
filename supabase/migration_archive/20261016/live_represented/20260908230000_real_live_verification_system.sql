-- =============================================================================
-- Migration: 20260908230000_real_live_verification_system.sql
-- Description: Real Live Network Verification System
--   1. Country verification pricing columns & versioning
--   2. Extend wallet_holds order_type allowlist for 'line_verification'
--   3. line_verification_allowances (1 free annual check per paid SIM)
--   4. line_verification_attempts (attempt tracking, ledger & settlement)
--   5. Revoke direct column updates on sim_lines(verification_status, health_score)
--   6. quote_line_verification RPC
--   7. settle_line_verification_attempt (service-role only)
--   8. admin_list_country_verification_prices, admin_update_country_verification_prices, admin_list_line_verification_attempts RPCs
-- =============================================================================

-- 1. COUNTRY VERIFICATION PRICING
ALTER TABLE public.countries
  ADD COLUMN IF NOT EXISTS sms_verify_cost NUMERIC(12,2) DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS call_verify_cost NUMERIC(12,2) DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS verification_price_version INT NOT NULL DEFAULT 1;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'ck_countries_sms_verify_cost_non_negative'
  ) THEN
    ALTER TABLE public.countries
      ADD CONSTRAINT ck_countries_sms_verify_cost_non_negative
      CHECK (sms_verify_cost IS NULL OR sms_verify_cost >= 0);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'ck_countries_call_verify_cost_non_negative'
  ) THEN
    ALTER TABLE public.countries
      ADD CONSTRAINT ck_countries_call_verify_cost_non_negative
      CHECK (call_verify_cost IS NULL OR call_verify_cost >= 0);
  END IF;
END $$;

COMMENT ON COLUMN public.countries.sms_verify_cost IS 'Retail customer price in USD for one successful SMS network verification.';
COMMENT ON COLUMN public.countries.call_verify_cost IS 'Retail customer price in USD for one successful missed-call network verification.';
COMMENT ON COLUMN public.countries.verification_price_version IS 'Optimistic locking version for admin country verification pricing edits.';


-- 2. EXTEND WALLET_HOLDS ORDER_TYPE FOR 'line_verification'
ALTER TABLE public.wallet_holds DROP CONSTRAINT IF EXISTS wallet_holds_order_type_check;
ALTER TABLE public.wallet_holds ADD CONSTRAINT wallet_holds_order_type_check
  CHECK (order_type IN (
    'refill_instant',
    'refill_scheduled',
    'plan_fee',
    'esim_purchase',
    'call_budget',
    'offline_voucher',
    'refund_request',
    'line_verification'
  ));


-- 3. LINE VERIFICATION ANNUAL ALLOWANCES
CREATE TABLE IF NOT EXISTS public.line_verification_allowances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sim_line_id UUID NOT NULL REFERENCES public.sim_lines(id) ON DELETE CASCADE,
  period_start TIMESTAMPTZ NOT NULL,
  period_end TIMESTAMPTZ NOT NULL,
  reserved_attempt_id UUID,
  consumed_attempt_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_allowance_period_bounds CHECK (period_end > period_start),
  CONSTRAINT uq_line_verification_allowance_period UNIQUE (sim_line_id, period_start, period_end)
);

CREATE INDEX IF NOT EXISTS idx_line_verification_allowance_sim 
  ON public.line_verification_allowances(sim_line_id);


-- 4. LINE VERIFICATION ATTEMPTS
CREATE TABLE IF NOT EXISTS public.line_verification_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sim_line_id UUID NOT NULL REFERENCES public.sim_lines(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  method TEXT NOT NULL CHECK (method IN ('sms', 'voice')),
  destination_phone TEXT NOT NULL,
  country_id UUID REFERENCES public.countries(id) ON DELETE SET NULL,
  retail_price NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (retail_price >= 0),
  funding_kind TEXT NOT NULL CHECK (funding_kind IN ('annual_allowance', 'wallet', 'country_zero')),
  wallet_hold_id UUID REFERENCES public.wallet_holds(id) ON DELETE SET NULL,
  provider TEXT,
  provider_resource_id TEXT,
  status TEXT NOT NULL DEFAULT 'reserved' CHECK (status IN ('reserved', 'dispatching', 'pending', 'terminal', 'reconciliation_required')),
  outcome TEXT NOT NULL DEFAULT 'pending' CHECK (outcome IN ('pending', 'succeeded', 'failed', 'inconclusive')),
  settlement_status TEXT NOT NULL DEFAULT 'reserved' CHECK (settlement_status IN ('reserved', 'captured', 'consumed', 'released', 'no_charge', 'reconciliation_required')),
  error_message TEXT,
  carrier_name TEXT,
  price_version INT NOT NULL DEFAULT 1,
  idempotency_key TEXT,
  dispatched_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_attempt_user_idempotency UNIQUE (user_id, idempotency_key)
);

CREATE INDEX IF NOT EXISTS idx_line_verification_attempts_sim 
  ON public.line_verification_attempts(sim_line_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_line_verification_attempts_provider_res 
  ON public.line_verification_attempts(provider, provider_resource_id) 
  WHERE provider_resource_id IS NOT NULL;

-- At most one active/in-flight attempt per line
CREATE UNIQUE INDEX IF NOT EXISTS uq_line_verification_in_flight 
  ON public.line_verification_attempts(sim_line_id)
  WHERE status IN ('reserved', 'dispatching', 'pending');


-- 5. REVOKE DIRECT SIM_LINES STATUS UPDATES & ENABLE RLS
REVOKE UPDATE (verification_status, health_score) ON public.sim_lines FROM authenticated, anon;

ALTER TABLE public.line_verification_allowances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.line_verification_attempts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_line_verification_allowances_select ON public.line_verification_allowances;
CREATE POLICY p_line_verification_allowances_select ON public.line_verification_allowances
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.sim_lines sl
      WHERE sl.id = sim_line_id AND sl.user_id = (SELECT auth.uid())
    ) OR public.is_power_user(auth.uid())
  );

DROP POLICY IF EXISTS p_line_verification_attempts_select ON public.line_verification_attempts;
CREATE POLICY p_line_verification_attempts_select ON public.line_verification_attempts
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()) OR public.is_power_user(auth.uid()));


-- 6. RPC: quote_line_verification
DROP FUNCTION IF EXISTS public.quote_line_verification(p_sim_line_id UUID);
CREATE OR REPLACE FUNCTION public.quote_line_verification(
  p_sim_line_id UUID,
  p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_line RECORD;
  v_country RECORD;
  v_is_paid BOOLEAN := false;
  v_has_allowance BOOLEAN := false;
  v_period_start TIMESTAMPTZ;
  v_period_end TIMESTAMPTZ;
  v_allowance RECORD;
  v_wallet_balance NUMERIC(12,2) := 0.00;
  v_wallet_available NUMERIC(12,2) := 0.00;
  v_held_amount NUMERIC(12,2) := 0.00;
  v_in_flight_id UUID := NULL;
  v_effective_sms_cost NUMERIC(12,2) := 0.00;
  v_effective_call_cost NUMERIC(12,2) := 0.00;
BEGIN
  v_user_id := COALESCE(auth.uid(), p_user_id);
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = 'KS401';
  END IF;

  -- 1. Fetch SIM Line
  SELECT sl.id, sl.user_id, sl.phone_number, sl.country_id, sl.plan_type, 
         sl.protection_tier, sl.plan_expires_at, sl.verification_status, sl.carrier_status
  INTO v_line
  FROM public.sim_lines sl
  WHERE sl.id = p_sim_line_id;

  IF v_line.id IS NULL THEN
    RAISE EXCEPTION 'SIM line not found' USING ERRCODE = 'KS404';
  END IF;

  IF v_line.user_id != v_user_id AND NOT public.is_power_user(v_user_id) THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = 'KS403';
  END IF;

  -- Check existing in-flight attempt
  SELECT id INTO v_in_flight_id
  FROM public.line_verification_attempts
  WHERE sim_line_id = p_sim_line_id
    AND status IN ('reserved', 'dispatching', 'pending')
  LIMIT 1;

  -- 2. Fetch Country Pricing
  SELECT id, name, iso_code, COALESCE(sms_verify_cost, 0.00) AS sms_cost,
         COALESCE(call_verify_cost, 0.00) AS call_cost, verification_price_version
  INTO v_country
  FROM public.countries
  WHERE id = v_line.country_id;

  IF v_country.id IS NULL THEN
    -- Fallback: default zero
    v_effective_sms_cost := 0.00;
    v_effective_call_cost := 0.00;
  ELSE
    v_effective_sms_cost := v_country.sms_cost;
    v_effective_call_cost := v_country.call_cost;
  END IF;

  -- 3. Determine Paid Plan Entitlement & Allowance
  IF LOWER(COALESCE(v_line.plan_type, 'free')) IN ('standard', 'premium') 
     OR LOWER(COALESCE(v_line.protection_tier, 'standard')) = 'premium' THEN
    IF v_line.plan_expires_at IS NULL OR v_line.plan_expires_at > now() THEN
      v_is_paid := true;
      v_period_end := COALESCE(v_line.plan_expires_at, now() + interval '365 days');
      v_period_start := v_period_end - interval '365 days';

      -- Ensure allowance row exists for current period
      INSERT INTO public.line_verification_allowances (
        sim_line_id, period_start, period_end
      ) VALUES (
        p_sim_line_id, v_period_start, v_period_end
      )
      ON CONFLICT (sim_line_id, period_start, period_end) DO NOTHING;

      -- Check if available
      SELECT * INTO v_allowance
      FROM public.line_verification_allowances
      WHERE sim_line_id = p_sim_line_id
        AND period_start = v_period_start
        AND period_end = v_period_end;

      IF v_allowance.id IS NOT NULL 
         AND v_allowance.consumed_attempt_id IS NULL 
         AND (v_allowance.reserved_attempt_id IS NULL OR v_allowance.reserved_attempt_id = v_in_flight_id) THEN
        v_has_allowance := true;
      END IF;
    END IF;
  END IF;

  -- 4. Check Wallet Available Funds
  SELECT COALESCE(balance, 0.00) INTO v_wallet_balance
  FROM public.wallets
  WHERE user_id = v_user_id;

  SELECT COALESCE(SUM(amount), 0.00) INTO v_held_amount
  FROM public.wallet_holds
  WHERE user_id = v_user_id AND status = 'active';

  v_wallet_available := GREATEST(0.00, v_wallet_balance - v_held_amount);

  RETURN jsonb_build_object(
    'sim_line_id', v_line.id,
    'phone_number', v_line.phone_number,
    'country_id', v_country.id,
    'country_name', v_country.name,
    'sms_verify_cost_usd', v_effective_sms_cost,
    'call_verify_cost_usd', v_effective_call_cost,
    'is_paid_plan', v_is_paid,
    'has_annual_allowance', v_has_allowance,
    'allowance_period_end', v_period_end,
    'wallet_balance_usd', v_wallet_balance,
    'wallet_available_usd', v_wallet_available,
    'price_version', COALESCE(v_country.verification_price_version, 1),
    'in_flight_attempt_id', v_in_flight_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.quote_line_verification(UUID, UUID) TO authenticated, service_role;


-- 7. RPC: settle_line_verification_attempt (Service Role Only)
CREATE OR REPLACE FUNCTION public.settle_line_verification_attempt(
  p_attempt_id UUID,
  p_outcome TEXT,
  p_carrier_name TEXT DEFAULT NULL,
  p_error_message TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_attempt RECORD;
  v_channel_label TEXT;
  v_desc TEXT;
BEGIN
  SELECT * INTO v_attempt
  FROM public.line_verification_attempts
  WHERE id = p_attempt_id
  FOR UPDATE;

  IF v_attempt.id IS NULL THEN
    RAISE EXCEPTION 'Attempt not found: %', p_attempt_id;
  END IF;

  IF v_attempt.status = 'terminal' THEN
    RETURN jsonb_build_object('success', true, 'status', 'terminal', 'outcome', v_attempt.outcome);
  END IF;

  IF p_outcome = 'succeeded' THEN
    -- 1. Settle Funds or Allowance
    IF v_attempt.funding_kind = 'wallet' AND v_attempt.wallet_hold_id IS NOT NULL THEN
      PERFORM public.capture_wallet_hold(
        v_attempt.wallet_hold_id,
        'verification_debit',
        'Real Live Verification (' || UPPER(v_attempt.method) || ')',
        jsonb_build_object('attempt_id', p_attempt_id, 'sim_line_id', v_attempt.sim_line_id)
      );
    ELSIF v_attempt.funding_kind = 'annual_allowance' THEN
      UPDATE public.line_verification_allowances
      SET consumed_attempt_id = p_attempt_id,
          reserved_attempt_id = NULL,
          updated_at = now()
      WHERE sim_line_id = v_attempt.sim_line_id
        AND (reserved_attempt_id = p_attempt_id OR consumed_attempt_id IS NULL);
    END IF;

    -- 2. Update SIM line verification & health score
    UPDATE public.sim_lines
    SET verification_status = 'verified',
        health_score = 100,
        carrier_verified_at = now(),
        detected_operator_name = COALESCE(p_carrier_name, detected_operator_name),
        updated_at = now()
    WHERE id = v_attempt.sim_line_id;

    -- 3. Log Activity
    v_channel_label := CASE WHEN v_attempt.method = 'sms' THEN 'SMS DLR Handshake' ELSE 'Missed Call Ring' END;
    v_desc := 'SIM line live verified active via ' || v_channel_label;
    IF p_carrier_name IS NOT NULL AND p_carrier_name <> '' THEN
      v_desc := v_desc || ' on ' || p_carrier_name;
    END IF;
    v_desc := v_desc || '. Health optimized to 100.';

    INSERT INTO public.line_activity_log (
      sim_line_id, user_id, event_type, description, created_at
    ) VALUES (
      v_attempt.sim_line_id, v_attempt.user_id, 'health_update', v_desc, now()
    );

    -- 4. Mark attempt terminal succeeded
    UPDATE public.line_verification_attempts
    SET status = 'terminal',
        outcome = 'succeeded',
        settlement_status = CASE 
          WHEN funding_kind = 'wallet' THEN 'captured'
          WHEN funding_kind = 'annual_allowance' THEN 'consumed'
          ELSE 'no_charge'
        END,
        carrier_name = COALESCE(p_carrier_name, carrier_name),
        completed_at = now(),
        updated_at = now()
    WHERE id = p_attempt_id;

  ELSE
    -- FAILED or INCONCLUSIVE: Release hold / allowance
    IF v_attempt.funding_kind = 'wallet' AND v_attempt.wallet_hold_id IS NOT NULL THEN
      PERFORM public.release_wallet_hold(
        v_attempt.wallet_hold_id,
        COALESCE(p_error_message, 'Verification check was unsuccessful')
      );
    ELSIF v_attempt.funding_kind = 'annual_allowance' THEN
      UPDATE public.line_verification_allowances
      SET reserved_attempt_id = NULL,
          updated_at = now()
      WHERE sim_line_id = v_attempt.sim_line_id
        AND reserved_attempt_id = p_attempt_id;
    END IF;

    UPDATE public.line_verification_attempts
    SET status = 'terminal',
        outcome = p_outcome,
        settlement_status = 'released',
        error_message = p_error_message,
        completed_at = now(),
        updated_at = now()
    WHERE id = p_attempt_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'attempt_id', p_attempt_id,
    'outcome', p_outcome,
    'settlement_status', CASE WHEN p_outcome = 'succeeded' THEN 'captured_or_consumed' ELSE 'released' END
  );
END;
$$;

REVOKE ALL ON FUNCTION public.settle_line_verification_attempt(UUID, TEXT, TEXT, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.settle_line_verification_attempt(UUID, TEXT, TEXT, TEXT) TO service_role;


-- 8. ADMIN RPCS: PRICING & LOGS
CREATE OR REPLACE FUNCTION public.admin_list_country_verification_prices(
  p_search TEXT DEFAULT NULL,
  p_only_zero BOOLEAN DEFAULT FALSE,
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total INT;
  v_items JSONB;
BEGIN
  PERFORM public.assert_admin();

  SELECT count(*) INTO v_total
  FROM public.countries c
  WHERE (p_search IS NULL OR c.name ILIKE '%' || p_search || '%' OR c.iso_code ILIKE '%' || p_search || '%')
    AND (NOT p_only_zero OR (COALESCE(c.sms_verify_cost, 0) = 0 AND COALESCE(c.call_verify_cost, 0) = 0));

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', c.id,
    'name', c.name,
    'iso_code', c.iso_code,
    'dialing_code', c.dialing_code,
    'flag_emoji', COALESCE(c.flag_emoji, '🌐'),
    'currency_code', c.currency_code,
    'sms_verify_cost', COALESCE(c.sms_verify_cost, 0.00),
    'call_verify_cost', COALESCE(c.call_verify_cost, 0.00),
    'verification_price_version', c.verification_price_version,
    'is_supported', c.is_supported
  ) ORDER BY c.name ASC), '[]'::jsonb)
  INTO v_items
  FROM (
    SELECT *
    FROM public.countries c
    WHERE (p_search IS NULL OR c.name ILIKE '%' || p_search || '%' OR c.iso_code ILIKE '%' || p_search || '%')
      AND (NOT p_only_zero OR (COALESCE(c.sms_verify_cost, 0) = 0 AND COALESCE(c.call_verify_cost, 0) = 0))
    ORDER BY c.name ASC
    LIMIT p_limit OFFSET p_offset
  ) c;

  RETURN jsonb_build_object(
    'total', v_total,
    'items', v_items
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_list_country_verification_prices(TEXT, BOOLEAN, INT, INT) TO authenticated;


CREATE OR REPLACE FUNCTION public.admin_update_country_verification_prices(
  p_country_id UUID,
  p_sms_verify_cost NUMERIC,
  p_call_verify_cost NUMERIC,
  p_expected_version INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor UUID;
  v_country RECORD;
  v_sms NUMERIC(12,2);
  v_call NUMERIC(12,2);
BEGIN
  v_actor := public.assert_admin();

  IF p_sms_verify_cost IS NULL OR p_sms_verify_cost < 0 THEN
    v_sms := 0.00;
  ELSE
    v_sms := ROUND(p_sms_verify_cost, 2);
  END IF;

  IF p_call_verify_cost IS NULL OR p_call_verify_cost < 0 THEN
    v_call := 0.00;
  ELSE
    v_call := ROUND(p_call_verify_cost, 2);
  END IF;

  SELECT * INTO v_country
  FROM public.countries
  WHERE id = p_country_id
  FOR UPDATE;

  IF v_country.id IS NULL THEN
    RAISE EXCEPTION 'Country not found' USING ERRCODE = 'KS404';
  END IF;

  IF p_expected_version IS NOT NULL AND v_country.verification_price_version != p_expected_version THEN
    RAISE EXCEPTION 'Pricing version conflict. Stale edit detected.' USING ERRCODE = 'KS409';
  END IF;

  UPDATE public.countries
  SET sms_verify_cost = v_sms,
      call_verify_cost = v_call,
      verification_price_version = v_country.verification_price_version + 1
  WHERE id = p_country_id;

  -- Write to admin audit log
  INSERT INTO public.admin_audit_log (
    actor_id, action, target_type, target_id, before_value, after_value, note
  ) VALUES (
    v_actor,
    'update_verification_pricing',
    'country',
    p_country_id,
    jsonb_build_object(
      'sms_verify_cost', v_country.sms_verify_cost,
      'call_verify_cost', v_country.call_verify_cost,
      'version', v_country.verification_price_version
    ),
    jsonb_build_object(
      'sms_verify_cost', v_sms,
      'call_verify_cost', v_call,
      'version', v_country.verification_price_version + 1
    ),
    'Updated real live verification prices for ' || v_country.name
  );

  RETURN jsonb_build_object(
    'success', true,
    'country_id', p_country_id,
    'sms_verify_cost', v_sms,
    'call_verify_cost', v_call,
    'verification_price_version', v_country.verification_price_version + 1
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_update_country_verification_prices(UUID, NUMERIC, NUMERIC, INT) TO authenticated;


CREATE OR REPLACE FUNCTION public.admin_list_line_verification_attempts(
  p_sim_line_id UUID DEFAULT NULL,
  p_status TEXT DEFAULT NULL,
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total INT;
  v_items JSONB;
BEGIN
  PERFORM public.assert_admin();

  SELECT count(*) INTO v_total
  FROM public.line_verification_attempts a
  WHERE (p_sim_line_id IS NULL OR a.sim_line_id = p_sim_line_id)
    AND (p_status IS NULL OR a.status = p_status);

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', a.id,
    'sim_line_id', a.sim_line_id,
    'user_id', a.user_id,
    'method', a.method,
    'destination_phone', a.destination_phone,
    'retail_price', a.retail_price,
    'funding_kind', a.funding_kind,
    'status', a.status,
    'outcome', a.outcome,
    'settlement_status', a.settlement_status,
    'carrier_name', a.carrier_name,
    'error_message', a.error_message,
    'created_at', a.created_at
  ) ORDER BY a.created_at DESC), '[]'::jsonb)
  INTO v_items
  FROM (
    SELECT *
    FROM public.line_verification_attempts a
    WHERE (p_sim_line_id IS NULL OR a.sim_line_id = p_sim_line_id)
      AND (p_status IS NULL OR a.status = p_status)
    ORDER BY a.created_at DESC
    LIMIT p_limit OFFSET p_offset
  ) a;

  RETURN jsonb_build_object(
    'total', v_total,
    'items', v_items
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_list_line_verification_attempts(UUID, TEXT, INT, INT) TO authenticated;
