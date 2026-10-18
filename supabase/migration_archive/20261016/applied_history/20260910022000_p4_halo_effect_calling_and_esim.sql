-- =============================================================================
-- Migration: 20260910022000_p4_halo_effect_calling_and_esim.sql
-- Description:
--   Implements Account Commerce Benefit (Halo Effect) for Calling & eSIM (P4):
--   1. get_call_rate_for_number(phone, user_id): applies intelcallfee discount
--      based on resolve_account_commerce_benefit(user_id) with strictly $0 connection fee
--   2. get_user_calling_rates(user_id): list destination rates with account tier pricing
--   3. resolve_esim_offer_price(wholesale_price, user_id): applies esimofferfee
-- =============================================================================

-- 1. get_call_rate_for_number with Halo Effect
CREATE OR REPLACE FUNCTION public.get_call_rate_for_number(
  p_phone_number TEXT,
  p_user_id      UUID DEFAULT auth.uid()
)
RETURNS TABLE(
  id UUID,
  country_code TEXT,
  country_name TEXT,
  phone_prefix TEXT,
  rate_per_minute_usd NUMERIC,
  cost_per_minute_usd NUMERIC,
  connection_fee_usd NUMERIC,
  billing_increment_seconds INT,
  account_tier TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
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
    IF v_fee IS NULL OR v_fee = 0 THEN
      -- Fallback to default draft percentages if not yet published
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
$$;

GRANT EXECUTE ON FUNCTION public.get_call_rate_for_number(TEXT, UUID) TO authenticated, anon, service_role;


-- 2. get_user_calling_rates
CREATE OR REPLACE FUNCTION public.get_user_calling_rates(p_user_id UUID DEFAULT auth.uid())
RETURNS TABLE (
  id UUID,
  country_code TEXT,
  country_name TEXT,
  phone_prefix TEXT,
  destination_type TEXT,
  cost_per_minute_usd NUMERIC,
  base_rate_per_minute_usd NUMERIC,
  effective_rate_per_minute_usd NUMERIC,
  connection_fee_usd NUMERIC,
  billing_increment_seconds INT,
  account_tier TEXT,
  is_active BOOLEAN
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_tier TEXT;
  v_fee  NUMERIC;
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
            NULLIF(public.resolve_app_fee('intelcallfee', v_tier, r.cost_per_minute_usd), 0),
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
$$;

GRANT EXECUTE ON FUNCTION public.get_user_calling_rates(UUID) TO authenticated, anon, service_role;


-- 3. resolve_esim_offer_price
CREATE OR REPLACE FUNCTION public.resolve_esim_offer_price(
  p_wholesale_price NUMERIC,
  p_user_id         UUID DEFAULT auth.uid()
)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_tier TEXT;
  v_fee  NUMERIC;
BEGIN
  IF p_wholesale_price IS NULL OR p_wholesale_price <= 0 THEN
    RETURN 0.00;
  END IF;

  v_tier := public.resolve_account_commerce_benefit(p_user_id);
  v_fee := public.resolve_app_fee('esimofferfee', v_tier, p_wholesale_price);
  
  IF v_fee IS NULL OR v_fee = 0 THEN
    v_fee := CASE v_tier
      WHEN 'premium'  THEN round(p_wholesale_price * 0.05, 2)
      WHEN 'standard' THEN round(p_wholesale_price * 0.07, 2)
      ELSE round(p_wholesale_price * 0.10, 2)
    END;
  END IF;
  
  RETURN round(p_wholesale_price + v_fee, 2);
END;
$$;

GRANT EXECUTE ON FUNCTION public.resolve_esim_offer_price(NUMERIC, UUID) TO authenticated, anon, service_role;
