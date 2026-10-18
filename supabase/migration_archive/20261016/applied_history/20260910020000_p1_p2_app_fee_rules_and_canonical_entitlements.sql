-- =============================================================================
-- Migration: 20260910020000_p1_p2_app_fee_rules_and_canonical_entitlements.sql
-- Description:
--   Phase 1 (Packages P1 & P2) of Line Tiers and Account Benefits Redesign:
--   1. public.app_fee_rules: Single authoritative versioned source of truth for product fees
--   2. Strict check constraints: Free >= Standard >= Premium (rates & floors), intelcallfee zero-minima
--   3. Seed initial published 'refills' row and draft 'intelcallfee', 'esimofferfee' rows
--   4. Seed membership & allowance pool keys in system_configs (Standard $2.50, Premium $5.00)
--   5. Permanent Free Cutover: Drop 6-month KS403 blocking trigger and allow plan_expires_at = NULL
--   6. Canonical entitlement & pricing RPCs:
--      - resolve_line_entitlement(sim_line_id)
--      - resolve_account_commerce_benefit(user_id)
--      - resolve_app_fee(item, tier, base_amount)
--      - admin_publish_app_fee_rule(...)
--   7. Update quote_sim_setup, quote_premium_breakdown, and calculate_topup_fees
-- =============================================================================

-- 1. APP FEE RULES TABLE
CREATE TABLE IF NOT EXISTS public.app_fee_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  appfees_item TEXT NOT NULL,
  version INT NOT NULL DEFAULT 1,
  free_percentage NUMERIC(12,6) NOT NULL,
  free_minimum NUMERIC(18,6) NOT NULL,
  stand_percentage NUMERIC(12,6) NOT NULL,
  stand_minimum NUMERIC(18,6) NOT NULL,
  prem_percentage NUMERIC(12,6) NOT NULL,
  prem_minimum NUMERIC(18,6) NOT NULL,
  currency TEXT NOT NULL DEFAULT 'USD',
  fee_basis TEXT NOT NULL DEFAULT 'base_amount_usd',
  charge_unit TEXT NOT NULL DEFAULT 'purchase',
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'retired')),
  effective_from TIMESTAMPTZ,
  effective_to TIMESTAMPTZ,
  change_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  published_at TIMESTAMPTZ,
  published_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  CONSTRAINT uq_app_fee_rules_item_version UNIQUE (appfees_item, version),
  CONSTRAINT ck_app_fee_hierarchy CHECK (
    free_percentage >= stand_percentage AND stand_percentage >= prem_percentage AND
    free_minimum >= stand_minimum AND stand_minimum >= prem_minimum
  ),
  CONSTRAINT ck_app_fee_nonnegative CHECK (
    free_percentage >= 0 AND stand_percentage >= 0 AND prem_percentage >= 0 AND
    free_minimum >= 0 AND stand_minimum >= 0 AND prem_minimum >= 0
  )
);

-- Constraint for percentage-only calling fees (C12: intelcallfee minima are all zero)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'ck_intelcallfee_zero_minima'
  ) THEN
    ALTER TABLE public.app_fee_rules
      ADD CONSTRAINT ck_intelcallfee_zero_minima
      CHECK (
        appfees_item <> 'intelcallfee' OR (
          free_minimum = 0 AND stand_minimum = 0 AND prem_minimum = 0
        )
      );
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_app_fee_rules_lookup 
  ON public.app_fee_rules(appfees_item, status, effective_from, effective_to);

ALTER TABLE public.app_fee_rules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_app_fee_rules_select ON public.app_fee_rules;
CREATE POLICY p_app_fee_rules_select ON public.app_fee_rules
  FOR SELECT TO authenticated, anon
  USING (status = 'published' OR (SELECT auth.role()) = 'service_role');

REVOKE INSERT, UPDATE, DELETE ON public.app_fee_rules FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.app_fee_rules TO service_role;


-- 2. SEED INITIAL APP FEE RULES
-- 2a. Refills (Published version 1)
INSERT INTO public.app_fee_rules (
  appfees_item, version,
  free_percentage, free_minimum,
  stand_percentage, stand_minimum,
  prem_percentage, prem_minimum,
  currency, fee_basis, charge_unit,
  status, effective_from, change_reason, published_at
) VALUES (
  'refills', 1,
  7.000000, 0.500000,
  5.000000, 0.300000,
  3.000000, 0.100000,
  'USD', 'base_amount_usd', 'purchase',
  'published', now(), 'Initial approved commercial refill rates (C11)', now()
) ON CONFLICT (appfees_item, version) DO UPDATE SET
  free_percentage = EXCLUDED.free_percentage,
  free_minimum = EXCLUDED.free_minimum,
  stand_percentage = EXCLUDED.stand_percentage,
  stand_minimum = EXCLUDED.stand_minimum,
  prem_percentage = EXCLUDED.prem_percentage,
  prem_minimum = EXCLUDED.prem_minimum,
  status = 'published';

-- 2b. International Calling (Draft baseline version 1)
INSERT INTO public.app_fee_rules (
  appfees_item, version,
  free_percentage, free_minimum,
  stand_percentage, stand_minimum,
  prem_percentage, prem_minimum,
  currency, fee_basis, charge_unit,
  status, change_reason
) VALUES (
  'intelcallfee', 1,
  15.000000, 0.000000,
  10.000000, 0.000000,
  5.000000, 0.000000,
  'USD', 'base_amount_usd', 'connected_call',
  'draft', 'Baseline draft rates for international calling (C12)'
) ON CONFLICT (appfees_item, version) DO NOTHING;

-- 2c. Standalone eSIM Offers (Draft baseline version 1)
INSERT INTO public.app_fee_rules (
  appfees_item, version,
  free_percentage, free_minimum,
  stand_percentage, stand_minimum,
  prem_percentage, prem_minimum,
  currency, fee_basis, charge_unit,
  status, change_reason
) VALUES (
  'esimofferfee', 1,
  10.000000, 0.500000,
  7.000000, 0.300000,
  5.000000, 0.100000,
  'USD', 'base_amount_usd', 'purchase',
  'draft', 'Baseline draft rates for standalone eSIM offers'
) ON CONFLICT (appfees_item, version) DO NOTHING;


-- 3. MEMBERSHIP PRICING & ALLOWANCE CONFIGS IN system_configs
INSERT INTO public.system_configs (config_key, config_value)
VALUES 
  ('MEMBERSHIP_FEE_STANDARD_USD', '2.50'),
  ('MEMBERSHIP_FEE_PREMIUM_USD', '5.00'),
  ('NOTIFICATION_ALLOWANCE_POOL_STANDARD_USD', '0.50'),
  ('NOTIFICATION_ALLOWANCE_POOL_PREMIUM_USD', '1.00')
ON CONFLICT (config_key) DO UPDATE SET
  config_value = EXCLUDED.config_value,
  updated_at = now();


-- 4. PERMANENT FREE CUTOVER (C13)
-- Drop legacy 6-month limit trigger and functions
DROP TRIGGER IF EXISTS trg_check_free_grant_eligibility ON public.sim_lines;
DROP TRIGGER IF EXISTS trg_record_free_grant_after_insert ON public.sim_lines;
DROP FUNCTION IF EXISTS public.check_free_grant_eligibility();
DROP FUNCTION IF EXISTS public.record_free_grant_after_insert();

-- Formatting trigger ensuring Free lines have plan_expires_at = NULL and protection_tier = 'basic'
CREATE OR REPLACE FUNCTION public.format_sim_line_tier_defaults()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF NEW.plan_type = 'free' THEN
    NEW.plan_expires_at := NULL;
    NEW.protection_tier := 'basic';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_format_sim_line_tier_defaults ON public.sim_lines;
CREATE TRIGGER trg_format_sim_line_tier_defaults
  BEFORE INSERT OR UPDATE OF plan_type ON public.sim_lines
  FOR EACH ROW
  EXECUTE FUNCTION public.format_sim_line_tier_defaults();


-- 5. CANONICAL ENTITLEMENT & CALCULATION RPCS

-- 5a. resolve_app_fee: Exact mathematical calculation max(B * p / 100, m)
CREATE OR REPLACE FUNCTION public.resolve_app_fee(
  p_item        TEXT,
  p_tier        TEXT,
  p_base_amount NUMERIC
)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_rule RECORD;
  v_pct  NUMERIC;
  v_min  NUMERIC;
  v_fee  NUMERIC;
  v_tier TEXT := lower(coalesce(p_tier, 'free'));
BEGIN
  IF p_base_amount IS NULL OR p_base_amount <= 0 THEN
    RETURN 0.00;
  END IF;

  SELECT * INTO v_rule
  FROM public.app_fee_rules
  WHERE appfees_item = p_item
    AND status = 'published'
    AND (effective_from IS NULL OR effective_from <= now())
    AND (effective_to IS NULL OR effective_to > now())
  ORDER BY version DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN 0.00;
  END IF;

  IF v_tier = 'premium' THEN
    v_pct := v_rule.prem_percentage;
    v_min := v_rule.prem_minimum;
  ELSIF v_tier = 'standard' THEN
    v_pct := v_rule.stand_percentage;
    v_min := v_rule.stand_minimum;
  ELSE
    v_pct := v_rule.free_percentage;
    v_min := v_rule.free_minimum;
  END IF;

  v_pct := coalesce(v_pct, 0.0);
  v_min := coalesce(v_min, 0.0);

  v_fee := round(greatest((p_base_amount * v_pct) / 100.0, v_min), 2);
  RETURN v_fee;
END;
$$;

GRANT EXECUTE ON FUNCTION public.resolve_app_fee(TEXT, TEXT, NUMERIC) TO authenticated, anon, service_role;


-- 5b. resolve_line_entitlement: Per-line authoritative entitlement
CREATE OR REPLACE FUNCTION public.resolve_line_entitlement(p_sim_line_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_line              RECORD;
  v_plan              TEXT;
  v_protection        TEXT;
  v_effective_tier    TEXT := 'free';
  v_is_paid           BOOLEAN := false;
  v_is_premium        BOOLEAN := false;
  v_is_expired        BOOLEAN := false;
  v_auto_eligible     BOOLEAN := false;
BEGIN
  SELECT id, user_id, plan_type, protection_tier, plan_expires_at, status
  INTO v_line
  FROM public.sim_lines
  WHERE id = p_sim_line_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'found', false,
      'effective_tier', 'free',
      'is_paid', false,
      'is_premium', false,
      'automation_eligible', false
    );
  END IF;

  v_plan := lower(coalesce(v_line.plan_type, 'free'));
  v_protection := lower(coalesce(v_line.protection_tier, 'basic'));

  IF v_plan = 'free' OR (v_plan = '' AND v_protection = 'basic') THEN
    v_effective_tier := 'free';
    v_is_paid := false;
    v_is_premium := false;
    v_is_expired := false;
    v_auto_eligible := false;
  ELSE
    IF v_line.plan_expires_at IS NOT NULL AND v_line.plan_expires_at <= now() THEN
      v_effective_tier := 'free';
      v_is_paid := false;
      v_is_premium := false;
      v_is_expired := true;
      v_auto_eligible := false;
    ELSE
      IF v_plan = 'premium' OR v_protection = 'premium' THEN
        v_effective_tier := 'premium';
        v_is_paid := true;
        v_is_premium := true;
        v_auto_eligible := true;
      ELSE
        v_effective_tier := 'standard';
        v_is_paid := true;
        v_is_premium := false;
        v_auto_eligible := false;
      END IF;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'found', true,
    'sim_line_id', v_line.id,
    'user_id', v_line.user_id,
    'plan_type', v_line.plan_type,
    'protection_tier', v_line.protection_tier,
    'effective_tier', v_effective_tier,
    'is_paid', v_is_paid,
    'is_premium', v_is_premium,
    'is_expired', v_is_expired,
    'expires_at', v_line.plan_expires_at,
    'automation_eligible', v_auto_eligible
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.resolve_line_entitlement(UUID) TO authenticated, service_role;


-- 5c. resolve_account_commerce_benefit: Halo effect for International Calling & standalone eSIM
CREATE OR REPLACE FUNCTION public.resolve_account_commerce_benefit(p_user_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_highest_tier   TEXT := 'free';
  v_line           RECORD;
  v_entitlement    JSONB;
  v_tier           TEXT;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN 'free';
  END IF;

  FOR v_line IN
    SELECT id FROM public.sim_lines
    WHERE user_id = p_user_id
      AND status = 'active'
  LOOP
    v_entitlement := public.resolve_line_entitlement(v_line.id);
    v_tier := v_entitlement->>'effective_tier';
    
    IF v_tier = 'premium' THEN
      RETURN 'premium';
    ELSIF v_tier = 'standard' AND v_highest_tier <> 'premium' THEN
      v_highest_tier := 'standard';
    END IF;
  END LOOP;

  RETURN v_highest_tier;
END;
$$;

GRANT EXECUTE ON FUNCTION public.resolve_account_commerce_benefit(UUID) TO authenticated, service_role;


-- 5d. admin_publish_app_fee_rule: Atomic publication of fee versions
CREATE OR REPLACE FUNCTION public.admin_publish_app_fee_rule(
  p_item             TEXT,
  p_free_percentage  NUMERIC,
  p_free_minimum     NUMERIC,
  p_stand_percentage NUMERIC,
  p_stand_minimum    NUMERIC,
  p_prem_percentage  NUMERIC,
  p_prem_minimum     NUMERIC,
  p_charge_unit      TEXT DEFAULT 'purchase',
  p_change_reason    TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_admin_id UUID := auth.uid();
  v_latest_version INT;
  v_new_version INT;
  v_rule_id UUID;
BEGIN
  -- Validate zero minima for calling
  IF p_item = 'intelcallfee' AND (p_free_minimum <> 0 OR p_stand_minimum <> 0 OR p_prem_minimum <> 0) THEN
    RAISE EXCEPTION 'Calling fee minima must be zero ($0.00)' USING ERRCODE = 'KS422';
  END IF;

  -- Validate hierarchy
  IF p_free_percentage < p_stand_percentage OR p_stand_percentage < p_prem_percentage OR
     p_free_minimum < p_stand_minimum OR p_stand_minimum < p_prem_minimum THEN
    RAISE EXCEPTION 'Invalid tier hierarchy: Free must be >= Standard >= Premium' USING ERRCODE = 'KS422';
  END IF;

  SELECT COALESCE(MAX(version), 0) INTO v_latest_version
  FROM public.app_fee_rules
  WHERE appfees_item = p_item;

  v_new_version := v_latest_version + 1;

  -- Retire active rule
  UPDATE public.app_fee_rules
  SET status = 'retired',
      effective_to = now()
  WHERE appfees_item = p_item
    AND status = 'published';

  -- Insert new published rule
  INSERT INTO public.app_fee_rules (
    appfees_item, version,
    free_percentage, free_minimum,
    stand_percentage, stand_minimum,
    prem_percentage, prem_minimum,
    currency, fee_basis, charge_unit,
    status, effective_from,
    change_reason, created_by, published_by, published_at
  ) VALUES (
    p_item, v_new_version,
    p_free_percentage, p_free_minimum,
    p_stand_percentage, p_stand_minimum,
    p_prem_percentage, p_prem_minimum,
    'USD', 'base_amount_usd', coalesce(p_charge_unit, 'purchase'),
    'published', now(),
    p_change_reason, v_admin_id, v_admin_id, now()
  ) RETURNING id INTO v_rule_id;

  RETURN jsonb_build_object(
    'success', true,
    'rule_id', v_rule_id,
    'appfees_item', p_item,
    'version', v_new_version,
    'status', 'published'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_publish_app_fee_rule(TEXT, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC, TEXT, TEXT) TO authenticated, service_role;


-- 6. UPDATE quote_sim_setup FOR $5.00 PREMIUM & $2.50 STANDARD
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
  v_premium_quote JSONB;
BEGIN
  IF p_plan = 'free' THEN
    v_annual_fee := 0.00;
    v_first_refill := 0.00;
    v_total := 0.00;
  ELSIF p_plan = 'standard' THEN
    SELECT COALESCE(config_value::numeric, 2.50) INTO v_annual_fee
    FROM public.system_configs WHERE config_key = 'MEMBERSHIP_FEE_STANDARD_USD';
    v_annual_fee := round(COALESCE(v_annual_fee, 2.50), 2);
    v_first_refill := 0.00;
    v_total := v_annual_fee;
  ELSIF p_plan = 'premium' THEN
    -- Check if carrier rule is provided to calculate optional first refill
    IF p_carrier_rule_id IS NOT NULL OR p_sim_line_id IS NOT NULL THEN
      BEGIN
        v_premium_quote := public.quote_premium_breakdown(p_carrier_rule_id, p_sim_line_id);
        v_annual_fee := (v_premium_quote->>'annual_fee_usd')::numeric;
        v_first_refill := (v_premium_quote->>'first_refill_cost_usd')::numeric;
        v_total := (v_premium_quote->>'total_charge_usd')::numeric;
        v_interval_days := (v_premium_quote->>'refill_interval_days')::integer;
      EXCEPTION WHEN OTHERS THEN
        -- Fallback to standalone membership if carrier breakdown fails
        SELECT COALESCE(config_value::numeric, 5.00) INTO v_annual_fee
        FROM public.system_configs WHERE config_key = 'MEMBERSHIP_FEE_PREMIUM_USD';
        v_annual_fee := round(COALESCE(v_annual_fee, 5.00), 2);
        v_first_refill := 0.00;
        v_total := v_annual_fee;
      END;
    ELSE
      SELECT COALESCE(config_value::numeric, 5.00) INTO v_annual_fee
      FROM public.system_configs WHERE config_key = 'MEMBERSHIP_FEE_PREMIUM_USD';
      v_annual_fee := round(COALESCE(v_annual_fee, 5.00), 2);
      v_first_refill := 0.00;
      v_total := v_annual_fee;
    END IF;
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
    'free_eligible', true
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.quote_sim_setup(TEXT, TEXT, UUID, UUID) TO authenticated, service_role;


-- 7. UPDATE quote_premium_breakdown FOR $5.00 ANNUAL FEE
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
  v_app_fee              numeric;
  v_step                 integer;
  v_qualifying           numeric;
  v_first_refill         numeric;
  v_total                numeric;
  v_fulfillment_gateway  text;
BEGIN
  -- Read $5.00 Premium membership fee
  SELECT COALESCE(config_value::numeric, 5.00) INTO v_base_fee
  FROM public.system_configs WHERE config_key = 'MEMBERSHIP_FEE_PREMIUM_USD';
  v_base_fee := COALESCE(v_base_fee, 5.00);

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

  -- Apply 3% ($0.10 min) fee rule for Premium line refill
  v_app_fee := public.resolve_app_fee('refills', 'premium', v_offer.price_usd);

  SELECT COALESCE(c.fulfillment_gateway, 'API') INTO v_fulfillment_gateway
  FROM public.carriers c
  WHERE c.id = v_rule.carrier_id;

  IF v_fulfillment_gateway = 'API' THEN
    v_first_refill := round(v_offer.price_usd + v_app_fee, 2);
  ELSE
    v_first_refill := round(GREATEST(COALESCE(v_rule.inapp_pricing, 0), v_offer.price_usd + v_app_fee), 2);
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

GRANT EXECUTE ON FUNCTION public.quote_premium_breakdown(UUID, UUID) TO authenticated, service_role;


-- 8. UPDATE calculate_topup_fees TO USE app_fee_rules
CREATE OR REPLACE FUNCTION public.calculate_topup_fees()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_line_tier       TEXT := 'free';
  v_entitlement     JSONB;
  v_app_fee         NUMERIC;
  v_msg_fee         NUMERIC := 0.00;
  v_msg_fee_key     TEXT;
  pm                RECORD;
BEGIN
  IF NEW.payment_gateway_code IS NOT NULL AND NEW.base_cost_usd IS NOT NULL THEN
    SELECT * INTO pm FROM public.payment_gateways WHERE code = NEW.payment_gateway_code;

    IF FOUND THEN
      -- Resolve line tier
      IF NEW.sim_line_id IS NOT NULL THEN
        v_entitlement := public.resolve_line_entitlement(NEW.sim_line_id);
        v_line_tier := COALESCE(v_entitlement->>'effective_tier', 'free');
      END IF;

      -- Resolve app fee from app_fee_rules
      v_app_fee := public.resolve_app_fee('refills', v_line_tier, NEW.base_cost_usd);

      -- Fallback if no published rule existed
      IF v_app_fee IS NULL OR v_app_fee = 0 THEN
        v_app_fee := round(greatest(NEW.base_cost_usd * 0.03, 0.03), 2);
      END IF;

      -- Offline messaging fees if applicable
      IF NEW.refill_channel IS NOT NULL THEN
        v_msg_fee_key := CASE NEW.refill_channel
          WHEN 'whatsapp'    THEN 'OFFLINE_WHATSAPP_MESSAGE_FEE_USD'
          WHEN 'sms'         THEN 'OFFLINE_SMS_MESSAGE_FEE_USD'
          WHEN 'missed_call' THEN 'OFFLINE_MISSED_CALL_FEE_USD'
        END;
        BEGIN
          SELECT config_value::numeric INTO v_msg_fee
          FROM public.system_configs
          WHERE config_key = v_msg_fee_key;
        EXCEPTION WHEN others THEN
          v_msg_fee := 0;
        END;
        v_msg_fee := coalesce(v_msg_fee, 0);
      END IF;

      NEW.app_fee_usd := v_app_fee;
      NEW.amount := round(NEW.base_cost_usd + v_app_fee + v_msg_fee, 2);
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;
