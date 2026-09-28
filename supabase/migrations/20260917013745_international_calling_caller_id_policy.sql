-- ============================================================================
-- Migration: 20260917000000_international_calling_policy_and_caller_id.sql
-- Feature: International Calling Caller-ID Policy, Lifecycle & Diagnostic CDR
-- ============================================================================

-- 1. Extend call_records with caller ID resolution, diagnostics, and route policy
ALTER TABLE public.call_records
  ADD COLUMN IF NOT EXISTS requested_caller_id TEXT,
  ADD COLUMN IF NOT EXISTS effective_caller_id TEXT,
  ADD COLUMN IF NOT EXISTS caller_id_type TEXT DEFAULT 'gateway' CHECK (caller_id_type IN ('gateway', 'verified_number')),
  ADD COLUMN IF NOT EXISTS policy_reason TEXT,
  ADD COLUMN IF NOT EXISTS policy_version TEXT DEFAULT '2026-09-17',
  ADD COLUMN IF NOT EXISTS sip_hangup_cause INTEGER,
  ADD COLUMN IF NOT EXISTS telnyx_hangup_cause TEXT,
  ADD COLUMN IF NOT EXISTS hangup_source TEXT,
  ADD COLUMN IF NOT EXISTS cancellation_requested_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS idempotency_key TEXT;

CREATE INDEX IF NOT EXISTS idx_call_records_idempotency_key
  ON public.call_records(idempotency_key)
  WHERE idempotency_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_call_records_sip_cause
  ON public.call_records(sip_hangup_cause);

CREATE INDEX IF NOT EXISTS idx_call_records_effective_caller
  ON public.call_records(effective_caller_id);

-- 2. Enforce at most one default verified number per user
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_caller_ids_unique_default
  ON public.user_caller_ids(user_id)
  WHERE is_default = TRUE;

-- 3. Create user_caller_id_preferences table to track explicit Gateway selection
CREATE TABLE IF NOT EXISTS public.user_caller_id_preferences (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  selected_mode TEXT NOT NULL DEFAULT 'gateway' CHECK (selected_mode IN ('gateway', 'verified_number')),
  selected_caller_id_id UUID REFERENCES public.user_caller_ids(id) ON DELETE SET NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.user_caller_id_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own caller ID preference" ON public.user_caller_id_preferences;
CREATE POLICY "Users can read own caller ID preference" ON public.user_caller_id_preferences
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

-- Preferences are changed only through the authenticated Edge Function, which
-- verifies the selected caller-ID belongs to the requesting user.  Do not let
-- clients write this foreign key directly.
DROP POLICY IF EXISTS "Users can update own caller ID preference" ON public.user_caller_id_preferences;

DROP POLICY IF EXISTS "Service role manages caller ID preference" ON public.user_caller_id_preferences;
CREATE POLICY "Service role manages caller ID preference" ON public.user_caller_id_preferences
  FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);

-- 4. Atomic RPC to set user default caller ID or switch to Gateway
CREATE OR REPLACE FUNCTION public.set_user_caller_id_preference(
  p_user_id UUID,
  p_caller_id_id UUID,
  p_use_gateway BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_phone_number TEXT;
  v_is_verified BOOLEAN;
BEGIN
  IF p_use_gateway THEN
    -- Clear all default flags on verified numbers for this user
    UPDATE public.user_caller_ids
    SET is_default = FALSE
    WHERE user_id = p_user_id;

    -- Upsert preference as gateway
    INSERT INTO public.user_caller_id_preferences (user_id, selected_mode, selected_caller_id_id, updated_at)
    VALUES (p_user_id, 'gateway', NULL, NOW())
    ON CONFLICT (user_id) DO UPDATE SET
      selected_mode = 'gateway',
      selected_caller_id_id = NULL,
      updated_at = NOW();

    RETURN jsonb_build_object('success', true, 'mode', 'gateway');
  ELSE
    IF p_caller_id_id IS NULL THEN
      RAISE EXCEPTION 'caller_id_id is required when p_use_gateway is false';
    END IF;

    -- Verify caller ID exists, is owned by user, and is verified
    SELECT phone_number, is_verified INTO v_phone_number, v_is_verified
    FROM public.user_caller_ids
    WHERE id = p_caller_id_id AND user_id = p_user_id
    FOR UPDATE;

    IF v_phone_number IS NULL THEN
      RAISE EXCEPTION 'Caller ID not found or not owned by user';
    END IF;

    IF v_is_verified IS NOT TRUE THEN
      RAISE EXCEPTION 'Caller ID % is not verified', v_phone_number;
    END IF;

    -- Clear all defaults first
    UPDATE public.user_caller_ids
    SET is_default = FALSE
    WHERE user_id = p_user_id;

    -- Set this record as default
    UPDATE public.user_caller_ids
    SET is_default = TRUE
    WHERE id = p_caller_id_id AND user_id = p_user_id;

    -- Upsert preference as verified_number
    INSERT INTO public.user_caller_id_preferences (user_id, selected_mode, selected_caller_id_id, updated_at)
    VALUES (p_user_id, 'verified_number', p_caller_id_id, NOW())
    ON CONFLICT (user_id) DO UPDATE SET
      selected_mode = 'verified_number',
      selected_caller_id_id = p_caller_id_id,
      updated_at = NOW();

    RETURN jsonb_build_object(
      'success', true,
      'mode', 'verified_number',
      'caller_id_id', p_caller_id_id,
      'phone_number', v_phone_number
    );
  END IF;
END;
$function$;

REVOKE ALL ON FUNCTION public.set_user_caller_id_preference(UUID, UUID, BOOLEAN) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.set_user_caller_id_preference(UUID, UUID, BOOLEAN) TO service_role;


