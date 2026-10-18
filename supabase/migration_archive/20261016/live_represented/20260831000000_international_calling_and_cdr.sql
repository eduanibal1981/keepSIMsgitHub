-- ============================================================================
-- Migration: 20260831000000_international_calling_and_cdr.sql
-- Feature: International App-to-Phone Calling & Telnyx CDR
-- ============================================================================

-- 1. Extend wallet_transactions_type_check to allow 'call_debit' and 'call_refund'
ALTER TABLE public.wallet_transactions DROP CONSTRAINT IF EXISTS wallet_transactions_type_check;

ALTER TABLE public.wallet_transactions ADD CONSTRAINT wallet_transactions_type_check CHECK (
  type = ANY (ARRAY[
    'deposit'::text,
    'topup_debit'::text,
    'refund'::text,
    'referral_credit'::text,
    'referral_withdrawal'::text,
    'plan_fee_debit'::text,
    'home_mode_debit'::text,
    'auto_fund'::text,
    'esim_purchase_debit'::text,
    'esim_purchase_refund'::text,
    'wallet_settlement'::text,
    'wallet_forfeit'::text,
    'gift_sent'::text,
    'gift_received'::text,
    'admin_adjustment'::text,
    'offline_voucher_debit'::text,
    'call_debit'::text,
    'call_refund'::text
  ])
);

-- 2. Call Rates Table
CREATE TABLE IF NOT EXISTS public.call_rates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  country_code TEXT NOT NULL,
  country_name TEXT NOT NULL,
  phone_prefix TEXT NOT NULL,
  destination_type TEXT NOT NULL DEFAULT 'all' CHECK (destination_type IN ('mobile', 'landline', 'all')),
  cost_per_minute_usd NUMERIC(10, 5) NOT NULL,
  rate_per_minute_usd NUMERIC(10, 5) NOT NULL,
  connection_fee_usd NUMERIC(10, 4) NOT NULL DEFAULT 0.0000,
  billing_increment_seconds INTEGER NOT NULL DEFAULT 1,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_call_rates_prefix ON public.call_rates(phone_prefix);
CREATE INDEX IF NOT EXISTS idx_call_rates_country ON public.call_rates(country_code);

-- Enable RLS on call_rates
ALTER TABLE public.call_rates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can view active call rates" ON public.call_rates;
CREATE POLICY "Public can view active call rates" ON public.call_rates
  FOR SELECT TO authenticated, anon USING (is_active = TRUE);

DROP POLICY IF EXISTS "Service role manages call rates" ON public.call_rates;
CREATE POLICY "Service role manages call rates" ON public.call_rates
  FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);

-- 3. Call Records Table (Session & CDR tracking)
CREATE TABLE IF NOT EXISTS public.call_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  sim_line_id UUID REFERENCES public.sim_lines(id) ON DELETE SET NULL,
  call_type TEXT NOT NULL DEFAULT 'two_way_callback' CHECK (call_type IN ('two_way_callback', 'app_to_phone_webrtc', 'outbound_direct')),
  caller_number TEXT NOT NULL,
  destination_number TEXT NOT NULL,
  destination_country_code TEXT,
  destination_country_name TEXT,
  telnyx_call_control_id_leg_a TEXT,
  telnyx_call_control_id_leg_b TEXT,
  telnyx_call_session_id TEXT,
  status TEXT NOT NULL DEFAULT 'initiated' CHECK (status IN ('initiated', 'ringing', 'in_progress', 'completed', 'busy', 'failed', 'no_answer', 'cancelled')),
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  answered_at TIMESTAMPTZ,
  ended_at TIMESTAMPTZ,
  duration_seconds INTEGER NOT NULL DEFAULT 0,
  billed_duration_seconds INTEGER NOT NULL DEFAULT 0,
  rate_per_minute_usd NUMERIC(10, 5) NOT NULL,
  total_cost_usd NUMERIC(10, 4) NOT NULL DEFAULT 0.0000,
  wallet_txn_id UUID REFERENCES public.wallet_transactions(id) ON DELETE SET NULL,
  error_message TEXT,
  raw_cdr JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_call_records_user ON public.call_records(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_call_records_session ON public.call_records(telnyx_call_session_id);
CREATE INDEX IF NOT EXISTS idx_call_records_leg_a ON public.call_records(telnyx_call_control_id_leg_a);
CREATE INDEX IF NOT EXISTS idx_call_records_leg_b ON public.call_records(telnyx_call_control_id_leg_b);

-- Enable RLS on call_records
ALTER TABLE public.call_records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own call records" ON public.call_records;
CREATE POLICY "Users can view own call records" ON public.call_records
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Service role manages call records" ON public.call_records;
CREATE POLICY "Service role manages call records" ON public.call_records
  FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);

-- 4. Security Definer RPC: Debit Wallet for Call
CREATE OR REPLACE FUNCTION public.debit_wallet_for_call(
  p_user_id UUID,
  p_call_id UUID,
  p_amount NUMERIC,
  p_description TEXT DEFAULT 'International Call'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_wallet_id UUID;
  v_balance_before NUMERIC;
  v_balance_after NUMERIC;
  v_txn_id UUID;
  v_ref_id TEXT;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN NULL;
  END IF;

  v_ref_id := 'call_' || p_call_id::text;

  -- Check if already debited for this call (idempotency)
  SELECT id INTO v_txn_id
  FROM public.wallet_transactions
  WHERE reference_id = v_ref_id
  LIMIT 1;

  IF v_txn_id IS NOT NULL THEN
    RETURN v_txn_id;
  END IF;

  -- Lock wallet
  SELECT id, balance INTO v_wallet_id, v_balance_before
  FROM public.wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    RAISE EXCEPTION 'Wallet not found for user %', p_user_id;
  END IF;

  -- Debit allows balance to go to 0 or even small overdraft if call duration exceeded balance
  v_balance_after := GREATEST(0.00, v_balance_before - p_amount);

  UPDATE public.wallets
  SET balance = v_balance_after,
      total_spent = total_spent + p_amount
  WHERE id = v_wallet_id;

  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, amount, balance_before, balance_after,
    description, reference_id, status
  ) VALUES (
    v_wallet_id, p_user_id, 'call_debit', p_amount, v_balance_before, v_balance_after,
    p_description, v_ref_id, 'completed'
  ) RETURNING id INTO v_txn_id;

  -- Link transaction to call record
  UPDATE public.call_records
  SET wallet_txn_id = v_txn_id,
      total_cost_usd = p_amount,
      updated_at = NOW()
  WHERE id = p_call_id;

  RETURN v_txn_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.debit_wallet_for_call(UUID, UUID, NUMERIC, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.debit_wallet_for_call(UUID, UUID, NUMERIC, TEXT) TO service_role;

-- 5. RPC: Get Call Rate For Phone Number (Longest Prefix Match)
CREATE OR REPLACE FUNCTION public.get_call_rate_for_number(p_phone_number TEXT)
RETURNS TABLE (
  rate_id UUID,
  country_code TEXT,
  country_name TEXT,
  phone_prefix TEXT,
  rate_per_minute_usd NUMERIC,
  cost_per_minute_usd NUMERIC,
  connection_fee_usd NUMERIC,
  billing_increment_seconds INTEGER
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_clean_number TEXT;
BEGIN
  -- Normalize number format: remove spaces, hyphens, parentheses
  v_clean_number := regexp_replace(p_phone_number, '[^0-9+]', '', 'g');
  IF NOT (v_clean_number LIKE '+%') THEN
    v_clean_number := '+' || v_clean_number;
  END IF;

  RETURN QUERY
  SELECT
    cr.id,
    cr.country_code,
    cr.country_name,
    cr.phone_prefix,
    cr.rate_per_minute_usd,
    cr.cost_per_minute_usd,
    cr.connection_fee_usd,
    cr.billing_increment_seconds
  FROM public.call_rates cr
  WHERE cr.is_active = TRUE
    AND v_clean_number LIKE (cr.phone_prefix || '%')
  ORDER BY length(cr.phone_prefix) DESC
  LIMIT 1;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_call_rate_for_number(TEXT) TO authenticated, anon, service_role;

-- 6. Seed Initial Global & Regional Call Rates
INSERT INTO public.call_rates (country_code, country_name, phone_prefix, cost_per_minute_usd, rate_per_minute_usd) VALUES
  ('EG', 'Egypt', '+20', 0.05000, 0.08000),
  ('IN', 'India', '+91', 0.01500, 0.02500),
  ('PK', 'Pakistan', '+92', 0.03500, 0.05500),
  ('BD', 'Bangladesh', '+880', 0.02800, 0.04500),
  ('PH', 'Philippines', '+63', 0.08500, 0.12000),
  ('OM', 'Oman', '+968', 0.04500, 0.07000),
  ('AE', 'United Arab Emirates', '+971', 0.07500, 0.11000),
  ('SA', 'Saudi Arabia', '+966', 0.06000, 0.09000),
  ('QA', 'Qatar', '+974', 0.07000, 0.10000),
  ('KW', 'Kuwait', '+965', 0.06500, 0.09500),
  ('BH', 'Bahrain', '+973', 0.06000, 0.09000),
  ('US', 'United States', '+1', 0.00800, 0.01500),
  ('CA', 'Canada', '+1', 0.00800, 0.01500),
  ('GB', 'United Kingdom', '+44', 0.01800, 0.03000),
  ('DE', 'Germany', '+49', 0.02500, 0.04000),
  ('FR', 'France', '+33', 0.02200, 0.03500),
  ('IT', 'Italy', '+39', 0.02500, 0.04000),
  ('ES', 'Spain', '+34', 0.02000, 0.03500),
  ('TR', 'Turkey', '+90', 0.05000, 0.08000),
  ('JO', 'Jordan', '+962', 0.07000, 0.10000),
  ('LB', 'Lebanon', '+961', 0.09500, 0.14000),
  ('MA', 'Morocco', '+212', 0.11000, 0.16000),
  ('TN', 'Tunisia', '+216', 0.14000, 0.20000),
  ('DZ', 'Algeria', '+213', 0.10000, 0.15000),
  ('SD', 'Sudan', '+249', 0.09000, 0.13000),
  ('YE', 'Yemen', '+967', 0.11000, 0.16000),
  ('SY', 'Syria', '+963', 0.12000, 0.17000),
  ('IQ', 'Iraq', '+964', 0.09000, 0.13000),
  ('LK', 'Sri Lanka', '+94', 0.07000, 0.10000),
  ('NP', 'Nepal', '+977', 0.06500, 0.09500),
  ('ID', 'Indonesia', '+62', 0.04000, 0.06500),
  ('MY', 'Malaysia', '+60', 0.02500, 0.04000),
  ('SG', 'Singapore', '+65', 0.01500, 0.02500),
  ('TH', 'Thailand', '+66', 0.02500, 0.04000),
  ('AU', 'Australia', '+61', 0.02000, 0.03500),
  ('NZ', 'New Zealand', '+64', 0.02500, 0.04000),
  ('ZA', 'South Africa', '+27', 0.05000, 0.08000),
  ('NG', 'Nigeria', '+234', 0.08000, 0.12000),
  ('KE', 'Kenya', '+254', 0.07500, 0.11000),
  ('GH', 'Ghana', '+233', 0.09000, 0.13000)
ON CONFLICT DO NOTHING;

-- 7. Register System Configs
INSERT INTO public.system_config_meta (config_key, label, group_name, value_type, is_sensitive, is_readonly, description) VALUES
  ('TELNYX_API_KEY', 'Telnyx API Key', 'telecom', 'text', TRUE, FALSE, 'API Key for Telnyx Call Control and Voice services'),
  ('TELNYX_CALL_CONTROL_APP_ID', 'Telnyx Voice App ID', 'telecom', 'text', FALSE, FALSE, 'Call Control Application ID for voice orchestration'),
  ('TELNYX_OUTBOUND_PROFILE_ID', 'Telnyx Outbound Profile', 'telecom', 'text', FALSE, FALSE, 'Outbound Voice Profile ID for international termination'),
  ('TELNYX_DEFAULT_CALLER_ID', 'Default Caller ID', 'telecom', 'phone', FALSE, FALSE, 'Default outbound caller ID for app callbacks')
ON CONFLICT (config_key) DO UPDATE SET
  group_name = EXCLUDED.group_name,
  value_type = EXCLUDED.value_type,
  label = EXCLUDED.label,
  description = EXCLUDED.description;

INSERT INTO public.system_configs (config_key, config_value) VALUES
  ('TELNYX_API_KEY', 'KEY01A049E00656B79B4314CFFBC7969C10_k9JM7HV9u4sB2MadneUT1M'),
  ('TELNYX_CALL_CONTROL_APP_ID', '3036680705380714233'),
  ('TELNYX_OUTBOUND_PROFILE_ID', '3036680126524819128'),
  ('TELNYX_DEFAULT_CALLER_ID', '+18337746746')
ON CONFLICT (config_key) DO UPDATE SET
  config_value = EXCLUDED.config_value;
