-- ============================================================================
-- Migration: 20260921000000_calling_phase_a_baseline.sql
-- Feature: VoIP Calling Baseline Security, RLS Lockdown & Transition RPCs (F05)
-- ============================================================================

-- 1. Restrict voip_call_sessions RLS to SELECT only for participants
DROP POLICY IF EXISTS "Participants can view and update call sessions" ON public.voip_call_sessions;
DROP POLICY IF EXISTS "Participants can view call sessions" ON public.voip_call_sessions;

CREATE POLICY "Participants can view call sessions" ON public.voip_call_sessions
  FOR SELECT TO authenticated
  USING (auth.uid() = caller_id OR auth.uid() = callee_id);

DROP POLICY IF EXISTS "Service role manages all voip sessions" ON public.voip_call_sessions;
CREATE POLICY "Service role manages all voip sessions" ON public.voip_call_sessions
  FOR ALL TO service_role
  USING (TRUE)
  WITH CHECK (TRUE);

-- 2. Security-Definer RPC: Save caller SDP offer
CREATE OR REPLACE FUNCTION public.save_voip_offer(
  p_call_id UUID,
  p_offer_sdp TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.voip_call_sessions
  SET offer_sdp = p_offer_sdp,
      updated_at = NOW()
  WHERE id = p_call_id
    AND caller_id = auth.uid()
    AND status = 'initiating';
END;
$$;

REVOKE ALL ON FUNCTION public.save_voip_offer(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_voip_offer(UUID, TEXT) TO authenticated, service_role;

-- 3. Security-Definer RPC: Callee answers VoIP call session
CREATE OR REPLACE FUNCTION public.answer_voip_session(
  p_call_id UUID,
  p_answer_sdp TEXT,
  p_device_id TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.voip_call_sessions
  SET status = 'accepted',
      answer_sdp = p_answer_sdp,
      connected_at = COALESCE(connected_at, NOW()),
      callee_device_id = COALESCE(p_device_id, callee_device_id),
      updated_at = NOW()
  WHERE id = p_call_id
    AND callee_id = auth.uid()
    AND status IN ('initiating', 'ringing');
END;
$$;

REVOKE ALL ON FUNCTION public.answer_voip_session(UUID, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.answer_voip_session(UUID, TEXT, TEXT) TO authenticated, service_role;

-- 4. Security-Definer RPC: Terminate / decline / timeout VoIP call session
CREATE OR REPLACE FUNCTION public.terminate_voip_session(
  p_call_id UUID,
  p_status TEXT,
  p_end_reason TEXT DEFAULT 'normal_hangup'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_session RECORD;
  v_duration INTEGER := 0;
BEGIN
  SELECT * INTO v_session
  FROM public.voip_call_sessions
  WHERE id = p_call_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- Caller, callee, or service_role can terminate
  IF auth.uid() IS NOT NULL AND auth.uid() <> v_session.caller_id AND auth.uid() <> v_session.callee_id THEN
    RAISE EXCEPTION 'Not authorized to terminate this call session';
  END IF;

  -- Terminal state idempotency
  IF v_session.status IN ('completed', 'declined', 'busy', 'missed', 'failed', 'timeout') THEN
    RETURN;
  END IF;

  IF v_session.connected_at IS NOT NULL AND p_status = 'completed' THEN
    v_duration := GREATEST(0, EXTRACT(EPOCH FROM (NOW() - v_session.connected_at))::INTEGER);
  END IF;

  UPDATE public.voip_call_sessions
  SET status = p_status,
      end_reason = p_end_reason,
      ended_at = NOW(),
      duration_seconds = v_duration,
      updated_at = NOW()
  WHERE id = p_call_id;
END;
$$;

REVOKE ALL ON FUNCTION public.terminate_voip_session(UUID, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.terminate_voip_session(UUID, TEXT, TEXT) TO authenticated, service_role;
