-- Migration: 20260731000000_d4b_paypal_orders_and_quoting.sql
-- Description: Creates paypal_orders table with RLS, quote_plan_price function, deposit limit configs, and Realtime publication membership.

-- 1. Create paypal_orders table
CREATE TABLE IF NOT EXISTS public.paypal_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id TEXT NOT NULL UNIQUE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kind TEXT NOT NULL DEFAULT 'deposit' CHECK (kind IN ('deposit', 'plan')),
  plan TEXT CHECK (plan IN ('standard', 'premium')),
  sim_line_id UUID REFERENCES public.sim_lines(id) ON DELETE SET NULL,
  amount_usd NUMERIC(10, 2) NOT NULL CHECK (amount_usd > 0),
  status TEXT NOT NULL DEFAULT 'created' CHECK (status IN ('created', 'approved', 'captured', 'failed', 'refunded')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  captured_at TIMESTAMPTZ,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb
);

-- Enable RLS
ALTER TABLE public.paypal_orders ENABLE ROW LEVEL SECURITY;

-- Grants & Policies
REVOKE ALL ON public.paypal_orders FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.paypal_orders TO authenticated;
GRANT ALL ON public.paypal_orders TO service_role;

DROP POLICY IF EXISTS select_own_paypal_orders ON public.paypal_orders;
CREATE POLICY select_own_paypal_orders ON public.paypal_orders
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- Index for user lookup
CREATE INDEX IF NOT EXISTS idx_paypal_orders_user_id ON public.paypal_orders(user_id);
CREATE INDEX IF NOT EXISTS idx_paypal_orders_status ON public.paypal_orders(status);

-- Realtime Publication Membership
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'paypal_orders'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.paypal_orders;
  END IF;
END $$;

-- 2. Seed Min/Max Deposit Configs
INSERT INTO public.system_configs (config_key, config_value)
VALUES 
  ('PAYPAL_MIN_DEPOSIT_USD', '1.00'),
  ('PAYPAL_MAX_DEPOSIT_USD', '500.00')
ON CONFLICT (config_key) DO UPDATE SET config_value = EXCLUDED.config_value;

-- 3. quote_plan_price RPC
CREATE OR REPLACE FUNCTION public.quote_plan_price(
  p_sim_line_id uuid DEFAULT NULL::uuid,
  p_plan text DEFAULT 'standard'::text,
  p_gateway text DEFAULT 'paypal'::text
)
 RETURNS numeric
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_base_fee numeric;
  v_app_fee_pct numeric;
  v_margin_pct numeric;
  v_margin_flat numeric;
  v_gw_pct numeric;
  v_gw_fixed numeric;
  
  v_carrier_id uuid;
  v_min_topup numeric;
  v_validity_days int;
  v_inapp_override numeric;
  
  v_per_refill numeric;
  v_refills_count int;
  v_net numeric;
  v_total numeric;
BEGIN
  -- Validate caller has access if sim_line_id is provided
  IF p_sim_line_id IS NOT NULL AND auth.uid() IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.sim_lines
      WHERE id = p_sim_line_id AND user_id = auth.uid()
    ) THEN
      RAISE EXCEPTION 'FORBIDDEN: SIM line does not belong to caller' USING ERRCODE = '42501';
    END IF;
  END IF;

  -- Read gateway fees (Doctrine: payment_gateways IS source of truth)
  SELECT fee_percentage, fee_fixed
  INTO v_gw_pct, v_gw_fixed
  FROM public.payment_gateways
  WHERE code = p_gateway AND is_active = true;

  IF NOT FOUND OR v_gw_pct IS NULL OR v_gw_fixed IS NULL THEN
    RAISE EXCEPTION 'Gateway % is not active or missing rates in payment_gateways', p_gateway USING ERRCODE = '22023';
  END IF;

  -- Read system configs
  SELECT COALESCE(config_value::numeric, 2.50) INTO v_base_fee
  FROM public.system_configs WHERE config_key = 'BASE_SERVICE_FEE_USD';
  
  IF LOWER(p_plan) = 'standard' THEN
    IF v_gw_pct >= 100 THEN
      RETURN ROUND(v_base_fee, 2);
    END IF;
    RETURN ROUND((v_base_fee + v_gw_fixed) / (1.0 - (v_gw_pct / 100.0)), 2);
  ELSIF LOWER(p_plan) = 'premium' THEN
    SELECT COALESCE(config_value::numeric, 3.0) INTO v_app_fee_pct
    FROM public.system_configs WHERE config_key = 'APP_FEE_PERCENT';

    SELECT COALESCE(config_value::numeric, 5.0) INTO v_margin_pct
    FROM public.system_configs WHERE config_key = 'PREMIUM_MARGIN_PERCENT';

    SELECT COALESCE(config_value::numeric, 0.324) INTO v_margin_flat
    FROM public.system_configs WHERE config_key = 'PREMIUM_MARGIN_PER_REFILL_USD';

    -- Look up line carrier_rules
    IF p_sim_line_id IS NOT NULL THEN
      SELECT sl.carrier_id INTO v_carrier_id
      FROM public.sim_lines sl
      WHERE sl.id = p_sim_line_id;
    END IF;

    IF v_carrier_id IS NOT NULL THEN
      SELECT minimum_topup_amount, topup_validity_days, inapp_pricing
      INTO v_min_topup, v_validity_days, v_inapp_override
      FROM public.carrier_rules
      WHERE carrier_id = v_carrier_id
      LIMIT 1;
    END IF;

    v_min_topup := COALESCE(v_min_topup, 10.0);
    v_validity_days := COALESCE(v_validity_days, 30);

    IF v_inapp_override IS NOT NULL AND v_inapp_override > 0 THEN
      v_per_refill := v_inapp_override;
    ELSE
      v_per_refill := (v_min_topup * (1.0 + ((v_app_fee_pct + v_margin_pct) / 100.0))) + v_margin_flat;
    END IF;

    IF v_validity_days <= 0 THEN
      v_refills_count := 0;
    ELSE
      v_refills_count := CEIL(365.0 / v_validity_days);
    END IF;

    v_net := v_base_fee + (v_per_refill * v_refills_count);

    IF v_gw_pct >= 100 THEN
      RETURN ROUND(v_net, 2);
    END IF;

    RETURN ROUND((v_net + v_gw_fixed) / (1.0 - (v_gw_pct / 100.0)), 2);
  ELSE
    RAISE EXCEPTION 'Invalid plan: %', p_plan USING ERRCODE = '22023';
  END IF;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.quote_plan_price(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quote_plan_price(uuid, text, text) TO authenticated, service_role;
