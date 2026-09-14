-- ============================================================================
-- line_tiers_and_app_fee_rules_tests.sql
-- Unit and regression tests for Line Tiers and Account Benefits Redesign (P1/P2).
--
-- Asserts:
--   1. app_fee_rules formula round(max(B * p / 100, m), 2) across USD 1, 5, 10, 100
--   2. Invariant constraints: hierarchy (Free >= Std >= Prem) and intelcallfee zero-minima
--   3. Permanent Free: multiple lines succeed with plan_expires_at = NULL and no KS403
--   4. Canonical resolve_line_entitlement: tier, term, and automation flags
--   5. Canonical resolve_account_commerce_benefit: Halo effect for Calling & eSIM
--   6. quote_sim_setup: $0 Free, $2.50 Standard, $5.00 Premium membership prices
--
-- HOW TO RUN: Run as a single transaction (BEGIN ... ROLLBACK).
-- ============================================================================

BEGIN;

CREATE TEMP TABLE tier_test_results(test_name TEXT, status TEXT, detail TEXT) ON COMMIT DROP;

DO $$
DECLARE
  v_user_id UUID := gen_random_uuid();
  v_other_id UUID := gen_random_uuid();
  v_line_free1 UUID := gen_random_uuid();
  v_line_free2 UUID := gen_random_uuid();
  v_line_std UUID := gen_random_uuid();
  v_line_prem UUID := gen_random_uuid();
  v_line_exp UUID := gen_random_uuid();
  
  v_fee NUMERIC;
  v_ent JSONB;
  v_acct_benefit TEXT;
  v_setup_quote JSONB;
  v_err_caught BOOLEAN := false;
BEGIN

  -- --------------------------------------------------------------------------
  -- TEST 1: Refills Fee Calculations (Section 6.1 Matrix)
  -- --------------------------------------------------------------------------
  -- USD 1.00 base
  v_fee := public.resolve_app_fee('refills', 'free', 1.00);
  IF v_fee = 0.50 THEN
    INSERT INTO tier_test_results VALUES ('refill_1usd_free', 'PASS', 'Fee is $0.50 (floor)');
  ELSE
    INSERT INTO tier_test_results VALUES ('refill_1usd_free', 'FAIL', 'Expected 0.50, got ' || coalesce(v_fee::text, 'null'));
  END IF;

  v_fee := public.resolve_app_fee('refills', 'standard', 1.00);
  IF v_fee = 0.30 THEN
    INSERT INTO tier_test_results VALUES ('refill_1usd_standard', 'PASS', 'Fee is $0.30 (floor)');
  ELSE
    INSERT INTO tier_test_results VALUES ('refill_1usd_standard', 'FAIL', 'Expected 0.30, got ' || coalesce(v_fee::text, 'null'));
  END IF;

  v_fee := public.resolve_app_fee('refills', 'premium', 1.00);
  IF v_fee = 0.10 THEN
    INSERT INTO tier_test_results VALUES ('refill_1usd_premium', 'PASS', 'Fee is $0.10 (floor)');
  ELSE
    INSERT INTO tier_test_results VALUES ('refill_1usd_premium', 'FAIL', 'Expected 0.10, got ' || coalesce(v_fee::text, 'null'));
  END IF;

  -- USD 5.00 base
  v_fee := public.resolve_app_fee('refills', 'free', 5.00);
  IF v_fee = 0.50 THEN
    INSERT INTO tier_test_results VALUES ('refill_5usd_free', 'PASS', 'Fee is $0.50 (floor)');
  ELSE
    INSERT INTO tier_test_results VALUES ('refill_5usd_free', 'FAIL', 'Expected 0.50, got ' || coalesce(v_fee::text, 'null'));
  END IF;

  v_fee := public.resolve_app_fee('refills', 'standard', 5.00);
  IF v_fee = 0.30 THEN
    INSERT INTO tier_test_results VALUES ('refill_5usd_standard', 'PASS', 'Fee is $0.30 (floor)');
  ELSE
    INSERT INTO tier_test_results VALUES ('refill_5usd_standard', 'FAIL', 'Expected 0.30, got ' || coalesce(v_fee::text, 'null'));
  END IF;

  v_fee := public.resolve_app_fee('refills', 'premium', 5.00);
  IF v_fee = 0.15 THEN
    INSERT INTO tier_test_results VALUES ('refill_5usd_premium', 'PASS', 'Fee is $0.15 (3% of $5.00)');
  ELSE
    INSERT INTO tier_test_results VALUES ('refill_5usd_premium', 'FAIL', 'Expected 0.15, got ' || coalesce(v_fee::text, 'null'));
  END IF;

  -- USD 10.00 base
  v_fee := public.resolve_app_fee('refills', 'free', 10.00);
  IF v_fee = 0.70 THEN
    INSERT INTO tier_test_results VALUES ('refill_10usd_free', 'PASS', 'Fee is $0.70 (7% of $10.00)');
  ELSE
    INSERT INTO tier_test_results VALUES ('refill_10usd_free', 'FAIL', 'Expected 0.70, got ' || coalesce(v_fee::text, 'null'));
  END IF;

  v_fee := public.resolve_app_fee('refills', 'standard', 10.00);
  IF v_fee = 0.50 THEN
    INSERT INTO tier_test_results VALUES ('refill_10usd_standard', 'PASS', 'Fee is $0.50 (5% of $10.00)');
  ELSE
    INSERT INTO tier_test_results VALUES ('refill_10usd_standard', 'FAIL', 'Expected 0.50, got ' || coalesce(v_fee::text, 'null'));
  END IF;

  v_fee := public.resolve_app_fee('refills', 'premium', 10.00);
  IF v_fee = 0.30 THEN
    INSERT INTO tier_test_results VALUES ('refill_10usd_premium', 'PASS', 'Fee is $0.30 (3% of $10.00)');
  ELSE
    INSERT INTO tier_test_results VALUES ('refill_10usd_premium', 'FAIL', 'Expected 0.30, got ' || coalesce(v_fee::text, 'null'));
  END IF;

  -- USD 100.00 base
  v_fee := public.resolve_app_fee('refills', 'free', 100.00);
  IF v_fee = 7.00 THEN
    INSERT INTO tier_test_results VALUES ('refill_100usd_free', 'PASS', 'Fee is $7.00');
  ELSE
    INSERT INTO tier_test_results VALUES ('refill_100usd_free', 'FAIL', 'Expected 7.00, got ' || coalesce(v_fee::text, 'null'));
  END IF;

  v_fee := public.resolve_app_fee('refills', 'standard', 100.00);
  IF v_fee = 5.00 THEN
    INSERT INTO tier_test_results VALUES ('refill_100usd_standard', 'PASS', 'Fee is $5.00');
  ELSE
    INSERT INTO tier_test_results VALUES ('refill_100usd_standard', 'FAIL', 'Expected 5.00, got ' || coalesce(v_fee::text, 'null'));
  END IF;

  v_fee := public.resolve_app_fee('refills', 'premium', 100.00);
  IF v_fee = 3.00 THEN
    INSERT INTO tier_test_results VALUES ('refill_100usd_premium', 'PASS', 'Fee is $3.00');
  ELSE
    INSERT INTO tier_test_results VALUES ('refill_100usd_premium', 'FAIL', 'Expected 3.00, got ' || coalesce(v_fee::text, 'null'));
  END IF;


  -- --------------------------------------------------------------------------
  -- TEST 2: Invariant Check on Calling Minima (C12: intelcallfee minima = 0)
  -- --------------------------------------------------------------------------
  v_err_caught := false;
  BEGIN
    INSERT INTO public.app_fee_rules (
      appfees_item, version,
      free_percentage, free_minimum,
      stand_percentage, stand_minimum,
      prem_percentage, prem_minimum,
      status
    ) VALUES (
      'intelcallfee', 99,
      15.0, 0.10,  -- Nonzero minimum must fail constraint
      10.0, 0.05,
      5.0, 0.00,
      'draft'
    );
  EXCEPTION WHEN check_violation THEN
    v_err_caught := true;
  END;

  IF v_err_caught THEN
    INSERT INTO tier_test_results VALUES ('intelcallfee_zero_minima_constraint', 'PASS', 'Nonzero calling minimum correctly rejected');
  ELSE
    INSERT INTO tier_test_results VALUES ('intelcallfee_zero_minima_constraint', 'FAIL', 'Allowed illegal nonzero minimum on intelcallfee');
  END IF;


  -- --------------------------------------------------------------------------
  -- TEST 3: Invariant Check on Tier Hierarchy (Free >= Std >= Prem)
  -- --------------------------------------------------------------------------
  v_err_caught := false;
  BEGIN
    INSERT INTO public.app_fee_rules (
      appfees_item, version,
      free_percentage, free_minimum,
      stand_percentage, stand_minimum,
      prem_percentage, prem_minimum,
      status
    ) VALUES (
      'refills', 98,
      2.0, 0.10,  -- Inverted: Free (2%) < Standard (5%)
      5.0, 0.30,
      3.0, 0.10,
      'draft'
    );
  EXCEPTION WHEN check_violation THEN
    v_err_caught := true;
  END;

  IF v_err_caught THEN
    INSERT INTO tier_test_results VALUES ('tier_hierarchy_constraint', 'PASS', 'Inverted tier hierarchy correctly rejected');
  ELSE
    INSERT INTO tier_test_results VALUES ('tier_hierarchy_constraint', 'FAIL', 'Allowed illegal inverted tier hierarchy');
  END IF;


  -- --------------------------------------------------------------------------
  -- TEST 4: Permanent Free Cutover (Unlimited Free lines, no KS403)
  -- --------------------------------------------------------------------------
  -- Insert dummy user
  INSERT INTO auth.users (id, email)
  VALUES (v_user_id, 'tier_test_user@keepsims.internal')
  ON CONFLICT DO NOTHING;

  INSERT INTO public.sim_lines (
    id, user_id, phone_number, plan_type, protection_tier, status
  ) VALUES (
    v_line_free1, v_user_id, '+15551110001', 'free', 'basic', 'active'
  );

  -- Insert second Free line for same user (formerly blocked by 1-line or 6-mo grant limit)
  INSERT INTO public.sim_lines (
    id, user_id, phone_number, plan_type, protection_tier, status
  ) VALUES (
    v_line_free2, v_user_id, '+15551110002', 'free', 'basic', 'active'
  );

  IF (SELECT plan_expires_at FROM public.sim_lines WHERE id = v_line_free1) IS NULL AND
     (SELECT plan_expires_at FROM public.sim_lines WHERE id = v_line_free2) IS NULL THEN
    INSERT INTO tier_test_results VALUES ('permanent_free_unlimited_lines', 'PASS', 'Multiple Free lines created with NULL expiration');
  ELSE
    INSERT INTO tier_test_results VALUES ('permanent_free_unlimited_lines', 'FAIL', 'Free lines received non-null expiration');
  END IF;


  -- --------------------------------------------------------------------------
  -- TEST 5: Canonical resolve_line_entitlement
  -- --------------------------------------------------------------------------
  -- Insert Standard line
  INSERT INTO public.sim_lines (
    id, user_id, phone_number, plan_type, protection_tier, plan_expires_at, status
  ) VALUES (
    v_line_std, v_user_id, '+15551110003', 'standard', 'standard', now() + interval '365 days', 'active'
  );

  -- Insert Premium line
  INSERT INTO public.sim_lines (
    id, user_id, phone_number, plan_type, protection_tier, plan_expires_at, status
  ) VALUES (
    v_line_prem, v_user_id, '+15551110004', 'premium', 'premium', now() + interval '365 days', 'active'
  );

  -- Insert Expired Premium line
  INSERT INTO public.sim_lines (
    id, user_id, phone_number, plan_type, protection_tier, plan_expires_at, status
  ) VALUES (
    v_line_exp, v_user_id, '+15551110005', 'premium', 'premium', now() - interval '2 days', 'active'
  );

  v_ent := public.resolve_line_entitlement(v_line_free1);
  IF v_ent->>'effective_tier' = 'free' AND (v_ent->>'is_paid')::boolean = false AND (v_ent->>'automation_eligible')::boolean = false THEN
    INSERT INTO tier_test_results VALUES ('resolve_line_entitlement_free', 'PASS', 'Free line entitlement verified');
  ELSE
    INSERT INTO tier_test_results VALUES ('resolve_line_entitlement_free', 'FAIL', 'Got ' || v_ent::text);
  END IF;

  v_ent := public.resolve_line_entitlement(v_line_std);
  IF v_ent->>'effective_tier' = 'standard' AND (v_ent->>'is_paid')::boolean = true AND (v_ent->>'automation_eligible')::boolean = false THEN
    INSERT INTO tier_test_results VALUES ('resolve_line_entitlement_standard', 'PASS', 'Standard line entitlement verified');
  ELSE
    INSERT INTO tier_test_results VALUES ('resolve_line_entitlement_standard', 'FAIL', 'Got ' || v_ent::text);
  END IF;

  v_ent := public.resolve_line_entitlement(v_line_prem);
  IF v_ent->>'effective_tier' = 'premium' AND (v_ent->>'is_paid')::boolean = true AND (v_ent->>'automation_eligible')::boolean = true THEN
    INSERT INTO tier_test_results VALUES ('resolve_line_entitlement_premium', 'PASS', 'Premium line entitlement verified');
  ELSE
    INSERT INTO tier_test_results VALUES ('resolve_line_entitlement_premium', 'FAIL', 'Got ' || v_ent::text);
  END IF;

  v_ent := public.resolve_line_entitlement(v_line_exp);
  IF v_ent->>'effective_tier' = 'free' AND (v_ent->>'is_expired')::boolean = true AND (v_ent->>'automation_eligible')::boolean = false THEN
    INSERT INTO tier_test_results VALUES ('resolve_line_entitlement_expired', 'PASS', 'Expired Premium dropped to Free entitlement');
  ELSE
    INSERT INTO tier_test_results VALUES ('resolve_line_entitlement_expired', 'FAIL', 'Got ' || v_ent::text);
  END IF;


  -- --------------------------------------------------------------------------
  -- TEST 6: Canonical resolve_account_commerce_benefit (Halo Effect)
  -- --------------------------------------------------------------------------
  -- User with Premium line active -> returns 'premium'
  v_acct_benefit := public.resolve_account_commerce_benefit(v_user_id);
  IF v_acct_benefit = 'premium' THEN
    INSERT INTO tier_test_results VALUES ('account_benefit_premium', 'PASS', 'Account inherits Premium from 1 active Premium line');
  ELSE
    INSERT INTO tier_test_results VALUES ('account_benefit_premium', 'FAIL', 'Expected premium, got ' || coalesce(v_acct_benefit, 'null'));
  END IF;

  -- Remove Premium line -> user has Standard active -> returns 'standard'
  DELETE FROM public.sim_lines WHERE id = v_line_prem;
  v_acct_benefit := public.resolve_account_commerce_benefit(v_user_id);
  IF v_acct_benefit = 'standard' THEN
    INSERT INTO tier_test_results VALUES ('account_benefit_standard', 'PASS', 'Account inherits Standard after Premium removed');
  ELSE
    INSERT INTO tier_test_results VALUES ('account_benefit_standard', 'FAIL', 'Expected standard, got ' || coalesce(v_acct_benefit, 'null'));
  END IF;

  -- Remove Standard line -> user has only Free lines active -> returns 'free'
  DELETE FROM public.sim_lines WHERE id = v_line_std;
  v_acct_benefit := public.resolve_account_commerce_benefit(v_user_id);
  IF v_acct_benefit = 'free' THEN
    INSERT INTO tier_test_results VALUES ('account_benefit_free', 'PASS', 'Account with only Free lines derives Free');
  ELSE
    INSERT INTO tier_test_results VALUES ('account_benefit_free', 'FAIL', 'Expected free, got ' || coalesce(v_acct_benefit, 'null'));
  END IF;


  -- --------------------------------------------------------------------------
  -- TEST 7: quote_sim_setup Membership Pricing Quotes
  -- --------------------------------------------------------------------------
  v_setup_quote := public.quote_sim_setup('+15559990001', 'free');
  IF (v_setup_quote->>'annual_fee_usd')::numeric = 0.00 AND (v_setup_quote->>'free_eligible')::boolean = true THEN
    INSERT INTO tier_test_results VALUES ('quote_setup_free', 'PASS', 'Free setup quoted $0.00 and free_eligible=true');
  ELSE
    INSERT INTO tier_test_results VALUES ('quote_setup_free', 'FAIL', 'Got ' || v_setup_quote::text);
  END IF;

  v_setup_quote := public.quote_sim_setup('+15559990002', 'standard');
  IF (v_setup_quote->>'annual_fee_usd')::numeric = 2.50 THEN
    INSERT INTO tier_test_results VALUES ('quote_setup_standard', 'PASS', 'Standard setup quoted $2.50 annual fee');
  ELSE
    INSERT INTO tier_test_results VALUES ('quote_setup_standard', 'FAIL', 'Got ' || v_setup_quote::text);
  END IF;

  v_setup_quote := public.quote_sim_setup('+15559990003', 'premium');
  IF (v_setup_quote->>'annual_fee_usd')::numeric = 5.00 THEN
    INSERT INTO tier_test_results VALUES ('quote_setup_premium', 'PASS', 'Premium setup quoted $5.00 annual fee');
  ELSE
    INSERT INTO tier_test_results VALUES ('quote_setup_premium', 'FAIL', 'Got ' || v_setup_quote::text);
  END IF;

END $$;

SELECT test_name, status, detail FROM tier_test_results ORDER BY test_name;

ROLLBACK;
