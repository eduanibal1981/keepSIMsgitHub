-- ============================================================================
-- Migration: 20260910031500_p4_calling_rate_precision_and_draft_fallback.sql
-- Description: Update resolve_app_fee to support 4-decimal precision for
--              calling fees (intelcallfee) and draft fallback when no published
--              rule exists. Also updates get_user_calling_rates and
--              get_call_rate_for_number to respect exact calculated fees.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.resolve_app_fee(p_item text, p_tier text, p_base_amount numeric)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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

  -- 1. Look for active published rule
  SELECT * INTO v_rule
  FROM public.app_fee_rules
  WHERE appfees_item = p_item
    AND status = 'published'
    AND (effective_from IS NULL OR effective_from <= now())
    AND (effective_to IS NULL OR effective_to > now())
  ORDER BY version DESC
  LIMIT 1;

  -- 2. Fallback to latest draft rule if no published rule exists
  IF NOT FOUND THEN
    SELECT * INTO v_rule
    FROM public.app_fee_rules
    WHERE appfees_item = p_item
    ORDER BY version DESC
    LIMIT 1;
  END IF;

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

  -- Calling fees are percentage-only and require 4 decimal places of precision ($0.0001/min)
  IF p_item = 'intelcallfee' THEN
    v_fee := round((p_base_amount * v_pct) / 100.0, 4);
  ELSE
    v_fee := round(greatest((p_base_amount * v_pct) / 100.0, v_min), 2);
  END IF;

  RETURN v_fee;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_user_calling_rates(p_user_id uuid DEFAULT auth.uid())
 RETURNS TABLE(id uuid, country_code text, country_name text, phone_prefix text, destination_type text, cost_per_minute_usd numeric, base_rate_per_minute_usd numeric, effective_rate_per_minute_usd numeric, connection_fee_usd numeric, billing_increment_seconds integer, account_tier text, is_active boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_tier TEXT;
BEGIN
  v_tier := public.resolve_account_commerce_benefit(p_user_id);
  
  RETURN QUERY
  SELECT 
    r.id,
    r.country_code,
    r.country_name,
    r.phone_prefix,
    r.destination_type,
    r.cost_per_minute_usd,
    r.rate_per_minute_usd AS base_rate_per_minute_usd,
    round(
      CASE 
        WHEN r.cost_per_minute_usd IS NOT NULL AND r.cost_per_minute_usd > 0 THEN
          r.cost_per_minute_usd + COALESCE(
            public.resolve_app_fee('intelcallfee', v_tier, r.cost_per_minute_usd),
            CASE v_tier
              WHEN 'premium'  THEN round(r.cost_per_minute_usd * 0.05, 4)
              WHEN 'standard' THEN round(r.cost_per_minute_usd * 0.10, 4)
              ELSE round(r.cost_per_minute_usd * 0.15, 4)
            END
          )
        ELSE r.rate_per_minute_usd
      END,
      4
    ) AS effective_rate_per_minute_usd,
    0.00::NUMERIC AS connection_fee_usd, -- Strictly $0 connection fee per C12
    r.billing_increment_seconds,
    v_tier AS account_tier,
    r.is_active
  FROM public.call_rates r
  WHERE r.is_active = true
  ORDER BY r.country_name;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_call_rate_for_number(p_phone_number text, p_user_id uuid DEFAULT auth.uid())
 RETURNS TABLE(id uuid, country_code text, country_name text, phone_prefix text, rate_per_minute_usd numeric, cost_per_minute_usd numeric, connection_fee_usd numeric, billing_increment_seconds integer, account_tier text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_clean_number TEXT;
  v_tier         TEXT;
  v_rate         RECORD;
  v_effective    NUMERIC;
  v_fee          NUMERIC;
BEGIN
  -- 1. Resolve Halo tier for this account
  v_tier := public.resolve_account_commerce_benefit(p_user_id);

  -- 2. Normalize number format
  v_clean_number := regexp_replace(p_phone_number, '[^0-9+]', '', 'g');
  IF NOT (v_clean_number LIKE '+%') THEN
    v_clean_number := '+' || v_clean_number;
  END IF;

  SELECT
    cr.id,
    cr.country_code,
    cr.country_name,
    cr.phone_prefix,
    cr.rate_per_minute_usd,
    cr.cost_per_minute_usd,
    0.00::NUMERIC AS connection_fee_usd, -- Strictly $0 connection fee per C12
    cr.billing_increment_seconds
  INTO v_rate
  FROM public.call_rates cr
  WHERE cr.is_active = TRUE
    AND v_clean_number LIKE (cr.phone_prefix || '%')
  ORDER BY length(cr.phone_prefix) DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- 3. Calculate effective rate per minute with intelcallfee app fee rule
  IF v_rate.cost_per_minute_usd IS NOT NULL AND v_rate.cost_per_minute_usd > 0 THEN
    v_fee := public.resolve_app_fee('intelcallfee', v_tier, v_rate.cost_per_minute_usd);
    IF v_fee IS NULL THEN
      -- Fallback to default draft percentages if no rule in table
      v_fee := CASE v_tier
        WHEN 'premium'  THEN round(v_rate.cost_per_minute_usd * 0.05, 4)
        WHEN 'standard' THEN round(v_rate.cost_per_minute_usd * 0.10, 4)
        ELSE round(v_rate.cost_per_minute_usd * 0.15, 4)
      END;
    END IF;
    v_effective := round(v_rate.cost_per_minute_usd + v_fee, 4);
  ELSE
    v_effective := v_rate.rate_per_minute_usd;
  END IF;

  RETURN QUERY
  SELECT
    v_rate.id,
    v_rate.country_code,
    v_rate.country_name,
    v_rate.phone_prefix,
    v_effective AS rate_per_minute_usd,
    v_rate.cost_per_minute_usd,
    0.00::NUMERIC AS connection_fee_usd,
    v_rate.billing_increment_seconds,
    v_tier AS account_tier;
END;
$function$;
