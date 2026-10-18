-- Restrict the already-deployed alert-clock RPCs and replace the legacy
-- Telegram UUID binding path with a one-use token.  The prior migration was
-- applied to production directly and is deliberately not rewritten here.

REVOKE ALL ON FUNCTION public.calculate_sim_line_alert_clock(uuid, timestamptz)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.calculate_sim_line_alert_clock(uuid, timestamptz)
  TO service_role;

REVOKE ALL ON FUNCTION public.sync_all_sim_line_alert_clocks(timestamptz)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.sync_all_sim_line_alert_clocks(timestamptz)
  TO service_role;

REVOKE ALL ON FUNCTION public.emit_urgent_deactivation_alerts(boolean, timestamptz)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.emit_urgent_deactivation_alerts(boolean, timestamptz)
  TO service_role;

REVOKE ALL ON FUNCTION public.create_telegram_bind_token()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_telegram_bind_token()
  TO authenticated;

DROP POLICY IF EXISTS "Users can create and view their own bind tokens"
  ON public.telegram_bind_tokens;
REVOKE ALL ON public.telegram_bind_tokens FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.bind_telegram_bot_token(
  p_token_or_uid text,
  p_chat_id text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  IF p_token_or_uid IS NULL OR p_token_or_uid !~ '^[0-9a-f]{32}$' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid bind token');
  END IF;
  IF p_chat_id IS NULL OR p_chat_id !~ '^-?[0-9]+$' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid Telegram chat');
  END IF;

  -- UPDATE is the claim: exactly one concurrent call can consume this token.
  UPDATE public.telegram_bind_tokens
  SET used_at = now()
  WHERE token = p_token_or_uid
    AND used_at IS NULL
    AND expires_at > now()
  RETURNING user_id INTO v_user_id;

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Expired or used bind token');
  END IF;

  INSERT INTO public.notification_channels (user_id, channel_type, is_enabled, config)
  VALUES (v_user_id, 'telegram', true, jsonb_build_object('chat_id', p_chat_id))
  ON CONFLICT (user_id, channel_type) DO UPDATE SET
    is_enabled = true,
    config = jsonb_set(
      COALESCE(public.notification_channels.config, '{}'::jsonb),
      '{chat_id}', to_jsonb(p_chat_id)
    );

  RETURN jsonb_build_object('success', true, 'user_id', v_user_id);
END;
$$;

REVOKE ALL ON FUNCTION public.bind_telegram_bot_token(text, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.bind_telegram_bot_token(text, text)
  TO service_role;

-- The app may refresh only a line it owns or an accepted household line.
CREATE OR REPLACE FUNCTION public.refresh_own_sim_line_alert_clock(
  p_sim_line_id uuid
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE
  v_owner_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'KS401';
  END IF;
  SELECT user_id INTO v_owner_id
  FROM public.sim_lines WHERE id = p_sim_line_id;
  IF v_owner_id IS NULL OR NOT (
    v_owner_id = auth.uid() OR EXISTS (
      SELECT 1 FROM public.household_members hm
      WHERE hm.owner_id = v_owner_id
        AND hm.member_id = auth.uid()
        AND hm.invite_status = 'accepted'
    )
  ) THEN
    RAISE EXCEPTION 'Line not found' USING ERRCODE = 'KS404';
  END IF;
  RETURN public.calculate_sim_line_alert_clock(p_sim_line_id);
END;
$$;
REVOKE ALL ON FUNCTION public.refresh_own_sim_line_alert_clock(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.refresh_own_sim_line_alert_clock(uuid)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_sync_alert_clocks()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
BEGIN
  PERFORM public.assert_admin();
  RETURN public.sync_all_sim_line_alert_clocks();
END;
$$;
REVOKE ALL ON FUNCTION public.admin_sync_alert_clocks()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_sync_alert_clocks()
  TO authenticated, service_role;

CREATE UNIQUE INDEX IF NOT EXISTS idx_notifications_line_deactivation_event_key
  ON public.notifications(source_event_key)
  WHERE event_type = 'line_deactivation_imminent'
    AND source_event_key IS NOT NULL;

-- Keep emission paused until the rest of the delivery and accuracy fixes land.
UPDATE public.system_configs
SET config_value = 'false'
WHERE config_key = 'ALERT_CLOCK_SCHEDULER_ENABLED';
