-- ============================================================================
-- Migration: 20260921020000_virtual_did_numbers.sql
-- Feature: Virtual DID Numbers & Inbound Roaming Call Forwarding (Phase C)
-- ============================================================================

-- 1. Virtual DID Numbers Table
CREATE TABLE IF NOT EXISTS public.virtual_did_numbers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  phone_number TEXT NOT NULL UNIQUE,
  country_code TEXT NOT NULL,
  country_name TEXT NOT NULL,
  provider TEXT NOT NULL DEFAULT 'telnyx',
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'released')),
  monthly_fee_usd NUMERIC NOT NULL DEFAULT 1.50,
  forward_mode TEXT NOT NULL DEFAULT 'app' CHECK (forward_mode IN ('app', 'pstn', 'voicemail', 'sim_roaming')),
  forward_destination TEXT,
  auto_renew BOOLEAN NOT NULL DEFAULT TRUE,
  renews_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '30 days'),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_virtual_dids_user ON public.virtual_did_numbers(user_id, status);
CREATE INDEX IF NOT EXISTS idx_virtual_dids_phone ON public.virtual_did_numbers(phone_number);

ALTER TABLE public.virtual_did_numbers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own virtual dids" ON public.virtual_did_numbers;
CREATE POLICY "Users can view own virtual dids" ON public.virtual_did_numbers
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Service role manages virtual dids" ON public.virtual_did_numbers;
CREATE POLICY "Service role manages virtual dids" ON public.virtual_did_numbers
  FOR ALL TO service_role
  USING (TRUE)
  WITH CHECK (TRUE);

-- 2. Security-Definer RPC: Update DID Forwarding Mode
CREATE OR REPLACE FUNCTION public.update_did_forwarding(
  p_did_id UUID,
  p_forward_mode TEXT,
  p_forward_destination TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_forward_mode NOT IN ('app', 'pstn', 'voicemail', 'sim_roaming') THEN
    RAISE EXCEPTION 'Invalid forwarding mode: %', p_forward_mode;
  END IF;

  UPDATE public.virtual_did_numbers
  SET forward_mode = p_forward_mode,
      forward_destination = CASE 
        WHEN p_forward_mode IN ('pstn', 'sim_roaming') THEN p_forward_destination 
        ELSE NULL 
      END,
      updated_at = NOW()
  WHERE id = p_did_id
    AND user_id = auth.uid()
    AND status = 'active';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'DID number not found or not owned by user';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.update_did_forwarding(UUID, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_did_forwarding(UUID, TEXT, TEXT) TO authenticated, service_role;

-- 3. Security-Definer RPC: Get User DIDs
CREATE OR REPLACE FUNCTION public.get_user_dids()
RETURNS TABLE (
  id UUID,
  phone_number TEXT,
  country_code TEXT,
  country_name TEXT,
  status TEXT,
  monthly_fee_usd NUMERIC,
  forward_mode TEXT,
  forward_destination TEXT,
  renews_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    d.id,
    d.phone_number,
    d.country_code,
    d.country_name,
    d.status,
    d.monthly_fee_usd,
    d.forward_mode,
    d.forward_destination,
    d.renews_at,
    d.created_at
  FROM public.virtual_did_numbers d
  WHERE d.user_id = auth.uid()
    AND d.status = 'active'
  ORDER BY d.created_at ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.get_user_dids() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_user_dids() TO authenticated, service_role;
