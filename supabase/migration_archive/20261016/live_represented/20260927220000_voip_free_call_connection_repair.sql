-- 20260927220000_voip_free_call_connection_repair.sql
-- Fix VoIP Free Call connection reliability, atomic answer claims, and truthful duration

-- Drop previous VOID-returning versions
DROP FUNCTION IF EXISTS public.save_voip_offer(UUID, TEXT);
DROP FUNCTION IF EXISTS public.answer_voip_session(UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.terminate_voip_session(UUID, TEXT, TEXT);

-- 1. Redefine save_voip_offer with typed JSONB return
CREATE OR REPLACE FUNCTION public.save_voip_offer(
  p_call_id UUID,
  p_offer_sdp TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_session RECORD;
BEGIN
  SELECT id, caller_id, status INTO v_session
  FROM public.voip_call_sessions
  WHERE id = p_call_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'status', 'not_found', 'error', 'Call session not found');
  END IF;

  IF auth.uid() IS NOT NULL AND auth.uid() <> v_session.caller_id THEN
    RETURN jsonb_build_object('ok', false, 'status', 'forbidden', 'error', 'Only caller can save offer');
  END IF;

  IF v_session.status NOT IN ('initiating', 'ringing') THEN
    RETURN jsonb_build_object('ok', false, 'status', 'invalid_state', 'error', 'Session is no longer initiating');
  END IF;

  UPDATE public.voip_call_sessions
  SET offer_sdp = p_offer_sdp,
      updated_at = NOW()
  WHERE id = p_call_id;

  RETURN jsonb_build_object('ok', true, 'status', 'saved');
END;
$$;

-- 2. Redefine answer_voip_session with atomic claim, typed JSONB return, and NO premature connected_at
CREATE OR REPLACE FUNCTION public.answer_voip_session(
  p_call_id UUID,
  p_answer_sdp TEXT,
  p_device_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_session RECORD;
BEGIN
  SELECT id, caller_id, callee_id, status INTO v_session
  FROM public.voip_call_sessions
  WHERE id = p_call_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'status', 'not_found', 'error', 'Call session not found');
  END IF;

  IF auth.uid() IS NOT NULL AND auth.uid() <> v_session.callee_id THEN
    RETURN jsonb_build_object('ok', false, 'status', 'forbidden', 'error', 'Only callee can answer call');
  END IF;

  -- If already accepted or connected
  IF v_session.status = 'accepted' THEN
    -- If already answered by this device or updating SDP
    UPDATE public.voip_call_sessions
    SET answer_sdp = COALESCE(p_answer_sdp, answer_sdp),
        callee_device_id = COALESCE(p_device_id, callee_device_id),
        updated_at = NOW()
    WHERE id = p_call_id;
    RETURN jsonb_build_object('ok', true, 'status', 'already_answered');
  END IF;

  IF v_session.status IN ('completed', 'declined', 'busy', 'missed', 'failed', 'timeout') THEN
    RETURN jsonb_build_object('ok', false, 'status', 'expired', 'error', 'Call has already ended');
  END IF;

  IF v_session.status NOT IN ('initiating', 'ringing') THEN
    RETURN jsonb_build_object('ok', false, 'status', 'invalid_state', 'error', 'Call cannot be answered from current state');
  END IF;

  -- Transition to 'accepted' while keeping connected_at NULL until media connects
  UPDATE public.voip_call_sessions
  SET status = 'accepted',
      answer_sdp = p_answer_sdp,
      callee_device_id = COALESCE(p_device_id, callee_device_id),
      updated_at = NOW()
  WHERE id = p_call_id;

  RETURN jsonb_build_object('ok', true, 'status', 'accepted');
END;
$$;

-- 3. New atomic RPC: mark_voip_session_connected (invoked only when WebRTC media connects)
CREATE OR REPLACE FUNCTION public.mark_voip_session_connected(
  p_call_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_session RECORD;
  v_now TIMESTAMPTZ := NOW();
BEGIN
  SELECT id, caller_id, callee_id, status, connected_at INTO v_session
  FROM public.voip_call_sessions
  WHERE id = p_call_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'status', 'not_found', 'error', 'Call session not found');
  END IF;

  IF auth.uid() IS NOT NULL AND auth.uid() <> v_session.caller_id AND auth.uid() <> v_session.callee_id THEN
    RETURN jsonb_build_object('ok', false, 'status', 'forbidden', 'error', 'Not a participant of this call');
  END IF;

  -- Idempotency: if already connected
  IF v_session.connected_at IS NOT NULL OR v_session.status = 'connected' THEN
    RETURN jsonb_build_object('ok', true, 'status', 'connected', 'already_connected', true, 'connected_at', v_session.connected_at);
  END IF;

  -- Terminal check
  IF v_session.status IN ('completed', 'declined', 'busy', 'missed', 'failed', 'timeout') THEN
    RETURN jsonb_build_object('ok', false, 'status', v_session.status, 'error', 'Cannot connect an ended call');
  END IF;

  -- Atomic transition to connected
  UPDATE public.voip_call_sessions
  SET status = 'connected',
      connected_at = v_now,
      updated_at = v_now
  WHERE id = p_call_id;

  RETURN jsonb_build_object('ok', true, 'status', 'connected', 'connected_at', v_now);
END;
$$;

-- 4. Redefine terminate_voip_session: zero duration for never-connected calls & truthful status
CREATE OR REPLACE FUNCTION public.terminate_voip_session(
  p_call_id UUID,
  p_status TEXT,
  p_end_reason TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_session RECORD;
  v_duration INTEGER := 0;
  v_final_status TEXT := p_status;
BEGIN
  SELECT id, caller_id, callee_id, status, connected_at INTO v_session
  FROM public.voip_call_sessions
  WHERE id = p_call_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'status', 'not_found', 'error', 'Call session not found');
  END IF;

  IF auth.uid() IS NOT NULL AND auth.uid() <> v_session.caller_id AND auth.uid() <> v_session.callee_id THEN
    RETURN jsonb_build_object('ok', false, 'status', 'forbidden', 'error', 'Not authorized to terminate this call session');
  END IF;

  -- Terminal state idempotency
  IF v_session.status IN ('completed', 'declined', 'busy', 'missed', 'failed', 'timeout') THEN
    RETURN jsonb_build_object('ok', true, 'status', v_session.status, 'already_terminated', true);
  END IF;

  -- Calculate duration ONLY if media was actually connected
  IF v_session.connected_at IS NOT NULL THEN
    v_duration := GREATEST(0, EXTRACT(EPOCH FROM (NOW() - v_session.connected_at))::INTEGER);
    IF v_final_status = 'completed' AND v_duration = 0 THEN
      -- Bounded minimum 1s if connected at least momentarily
      v_duration := 1;
    END IF;
  ELSE
    -- Never connected: duration is strictly zero
    v_duration := 0;
    -- If caller hung up before connection, status cannot be 'completed'
    IF v_final_status = 'completed' THEN
      IF auth.uid() = v_session.caller_id THEN
        IF v_session.status IN ('initiating', 'ringing') THEN
          v_final_status := 'missed';
        ELSE
          v_final_status := 'failed';
        END IF;
      ELSE
        v_final_status := 'declined';
      END IF;
    END IF;
  END IF;

  UPDATE public.voip_call_sessions
  SET status = v_final_status,
      end_reason = p_end_reason,
      ended_at = NOW(),
      duration_seconds = v_duration,
      updated_at = NOW()
  WHERE id = p_call_id;

  RETURN jsonb_build_object('ok', true, 'status', v_final_status, 'duration_seconds', v_duration);
END;
$$;

-- 5. Revoke public/anon and grant authenticated roles
REVOKE EXECUTE ON FUNCTION public.save_voip_offer(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_voip_offer(UUID, TEXT) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.answer_voip_session(UUID, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.answer_voip_session(UUID, TEXT, TEXT) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.mark_voip_session_connected(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_voip_session_connected(UUID) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.terminate_voip_session(UUID, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.terminate_voip_session(UUID, TEXT, TEXT) TO authenticated, service_role;
