-- ============================================================================
-- Migration: 20260920000000_voip_internet_calling.sql
-- Feature: Internet Voice Calling (WhatsApp-like VoIP) & PushKit / FCM Tokens
-- ============================================================================

-- 1. VoIP Push Tokens (Stores iOS PushKit VoIP tokens & Android High-Priority FCM tokens)
CREATE TABLE IF NOT EXISTS public.voip_push_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  device_id TEXT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
  voip_token TEXT,          -- Apple PushKit Hex token
  fcm_token TEXT,           -- Android high-priority FCM token
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_user_device_voip UNIQUE (user_id, device_id)
);

CREATE INDEX IF NOT EXISTS idx_voip_push_tokens_user ON public.voip_push_tokens(user_id) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_voip_push_tokens_device ON public.voip_push_tokens(device_id);

ALTER TABLE public.voip_push_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own voip push tokens" ON public.voip_push_tokens;
CREATE POLICY "Users can manage own voip push tokens" ON public.voip_push_tokens
  FOR ALL TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Service role manages voip push tokens" ON public.voip_push_tokens;
CREATE POLICY "Service role manages voip push tokens" ON public.voip_push_tokens
  FOR ALL TO service_role
  USING (TRUE)
  WITH CHECK (TRUE);

-- 2. VoIP Call Sessions Table
CREATE TABLE IF NOT EXISTS public.voip_call_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  caller_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  callee_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  call_type TEXT NOT NULL DEFAULT 'voice' CHECK (call_type IN ('voice', 'video')),
  status TEXT NOT NULL DEFAULT 'initiating' 
    CHECK (status IN ('initiating', 'ringing', 'accepted', 'declined', 'busy', 'missed', 'completed', 'failed', 'timeout')),
  offer_sdp TEXT,
  answer_sdp TEXT,
  end_reason TEXT,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ringing_at TIMESTAMPTZ,
  connected_at TIMESTAMPTZ,
  ended_at TIMESTAMPTZ,
  duration_seconds INTEGER NOT NULL DEFAULT 0,
  caller_device_id TEXT,
  callee_device_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_voip_sessions_caller ON public.voip_call_sessions(caller_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_voip_sessions_callee ON public.voip_call_sessions(callee_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_voip_sessions_status ON public.voip_call_sessions(status);

ALTER TABLE public.voip_call_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Participants can view and update call sessions" ON public.voip_call_sessions;
CREATE POLICY "Participants can view and update call sessions" ON public.voip_call_sessions
  FOR ALL TO authenticated
  USING (auth.uid() = caller_id OR auth.uid() = callee_id)
  WITH CHECK (auth.uid() = caller_id OR auth.uid() = callee_id);

DROP POLICY IF EXISTS "Service role manages all voip sessions" ON public.voip_call_sessions;
CREATE POLICY "Service role manages all voip sessions" ON public.voip_call_sessions
  FOR ALL TO service_role
  USING (TRUE)
  WITH CHECK (TRUE);

-- Enable Realtime publication for voip_call_sessions
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'voip_call_sessions'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.voip_call_sessions;
  END IF;
END $$;

-- 3. Contact Phone Lookup RPC (Allows discovering if a phone number is a KeepSIMs user)
CREATE OR REPLACE FUNCTION public.lookup_voip_contact_by_phone(p_phone TEXT)
RETURNS TABLE (
  user_id UUID,
  full_name TEXT,
  avatar_url TEXT,
  phone TEXT,
  is_online BOOLEAN
) 
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_clean_phone TEXT;
BEGIN
  v_clean_phone := REGEXP_REPLACE(p_phone, '[^0-9]', '', 'g');
  
  RETURN QUERY
  SELECT 
    p.id AS user_id,
    p.full_name,
    p.avatar_url,
    p.phone,
    EXISTS (
      SELECT 1 FROM public.voip_push_tokens t 
      WHERE t.user_id = p.id AND t.is_active = TRUE
    ) AS is_online
  FROM public.profiles p
  WHERE REGEXP_REPLACE(COALESCE(p.phone, ''), '[^0-9]', '', 'g') = v_clean_phone
    AND p.id <> auth.uid()
  LIMIT 1;
END;
$$;

GRANT EXECUTE ON FUNCTION public.lookup_voip_contact_by_phone(TEXT) TO authenticated;

-- 4. User VoIP Call History View RPC
CREATE OR REPLACE FUNCTION public.get_voip_call_history(p_limit INTEGER DEFAULT 50)
RETURNS TABLE (
  id UUID,
  caller_id UUID,
  callee_id UUID,
  peer_user_id UUID,
  peer_name TEXT,
  peer_avatar_url TEXT,
  peer_phone TEXT,
  is_outgoing BOOLEAN,
  status TEXT,
  started_at TIMESTAMPTZ,
  connected_at TIMESTAMPTZ,
  ended_at TIMESTAMPTZ,
  duration_seconds INTEGER
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN QUERY
  SELECT 
    s.id,
    s.caller_id,
    s.callee_id,
    CASE WHEN s.caller_id = auth.uid() THEN s.callee_id ELSE s.caller_id END AS peer_user_id,
    p.full_name AS peer_name,
    p.avatar_url AS peer_avatar_url,
    p.phone AS peer_phone,
    (s.caller_id = auth.uid()) AS is_outgoing,
    s.status,
    s.started_at,
    s.connected_at,
    s.ended_at,
    s.duration_seconds
  FROM public.voip_call_sessions s
  LEFT JOIN public.profiles p ON p.id = (CASE WHEN s.caller_id = auth.uid() THEN s.callee_id ELSE s.caller_id END)
  WHERE s.caller_id = auth.uid() OR s.callee_id = auth.uid()
  ORDER BY s.started_at DESC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_voip_call_history(INTEGER) TO authenticated;
