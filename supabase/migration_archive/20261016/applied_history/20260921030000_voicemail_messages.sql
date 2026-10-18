-- ============================================================================
-- Migration: 20260921030000_voicemail_messages.sql
-- Feature: AI Voicemail Bilingual Transcription & Visual Voicemail Inbox (Phase D)
-- ============================================================================

-- 1. Voicemail Messages Table
CREATE TABLE IF NOT EXISTS public.voicemail_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  did_id UUID REFERENCES public.virtual_did_numbers(id) ON DELETE SET NULL,
  caller_number TEXT NOT NULL,
  caller_name TEXT,
  audio_url TEXT NOT NULL,
  duration_seconds INTEGER NOT NULL DEFAULT 0,
  transcript TEXT,
  language TEXT NOT NULL DEFAULT 'en',
  status TEXT NOT NULL DEFAULT 'transcribed' CHECK (status IN ('recording', 'transcribing', 'transcribed', 'failed')),
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_voicemail_user_date ON public.voicemail_messages(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_voicemail_unread ON public.voicemail_messages(user_id) WHERE is_read = FALSE;

ALTER TABLE public.voicemail_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own voicemails" ON public.voip_call_sessions;
DROP POLICY IF EXISTS "Users can view own voicemails" ON public.voicemail_messages;
CREATE POLICY "Users can view own voicemails" ON public.voicemail_messages
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own voicemail read status" ON public.voicemail_messages;
CREATE POLICY "Users can update own voicemail read status" ON public.voicemail_messages
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Service role manages all voicemails" ON public.voicemail_messages;
CREATE POLICY "Service role manages all voicemails" ON public.voicemail_messages
  FOR ALL TO service_role
  USING (TRUE)
  WITH CHECK (TRUE);

-- 2. Security-Definer RPC: Get User Voicemails
CREATE OR REPLACE FUNCTION public.get_user_voicemails(p_limit INTEGER DEFAULT 50)
RETURNS TABLE (
  id UUID,
  caller_number TEXT,
  caller_name TEXT,
  audio_url TEXT,
  duration_seconds INTEGER,
  transcript TEXT,
  language TEXT,
  status TEXT,
  is_read BOOLEAN,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    v.id,
    v.caller_number,
    v.caller_name,
    v.audio_url,
    v.duration_seconds,
    v.transcript,
    v.language,
    v.status,
    v.is_read,
    v.created_at
  FROM public.voicemail_messages v
  WHERE v.user_id = auth.uid()
  ORDER BY v.created_at DESC
  LIMIT p_limit;
END;
$$;

REVOKE ALL ON FUNCTION public.get_user_voicemails(INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_user_voicemails(INTEGER) TO authenticated, service_role;

-- 3. Security-Definer RPC: Mark Voicemail Read
CREATE OR REPLACE FUNCTION public.mark_voicemail_read(p_voicemail_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.voicemail_messages
  SET is_read = TRUE,
      updated_at = NOW()
  WHERE id = p_voicemail_id
    AND user_id = auth.uid();
END;
$$;

REVOKE ALL ON FUNCTION public.mark_voicemail_read(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_voicemail_read(UUID) TO authenticated, service_role;
