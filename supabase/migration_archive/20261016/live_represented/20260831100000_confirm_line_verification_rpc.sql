-- Migration: Add confirm_line_verification RPC and grant column permissions on sim_lines

-- 1. Grant column update permissions to authenticated role for verification
GRANT UPDATE (verification_status, health_score) ON public.sim_lines TO authenticated;

-- 2. Create atomic confirm_line_verification RPC function
CREATE OR REPLACE FUNCTION public.confirm_line_verification(
  p_sim_line_id UUID,
  p_channel TEXT DEFAULT 'telnyx_sms_dlr',
  p_carrier_name TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_channel_label TEXT;
  v_desc TEXT;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Ensure user owns the line or is manager
  IF NOT EXISTS (
    SELECT 1 FROM sim_lines
    WHERE id = p_sim_line_id
      AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'SIM line not found or unauthorized';
  END IF;

  -- Update SIM line
  UPDATE sim_lines
  SET 
    verification_status = 'verified',
    health_score = 100,
    updated_at = NOW()
  WHERE id = p_sim_line_id;

  v_channel_label := CASE 
    WHEN p_channel = 'telnyx_sms_dlr' THEN 'Telnyx Silent SMS (DLR)'
    ELSE 'Missed Call'
  END;

  v_desc := 'SIM line verified active via ' || v_channel_label;
  IF p_carrier_name IS NOT NULL AND p_carrier_name <> '' THEN
    v_desc := v_desc || ' on ' || p_carrier_name;
  END IF;
  v_desc := v_desc || '. Health optimized to 100.';

  -- Insert activity log
  INSERT INTO line_activity_log (
    sim_line_id,
    user_id,
    event_type,
    description,
    metadata
  ) VALUES (
    p_sim_line_id,
    v_user_id,
    'health_update',
    v_desc,
    jsonb_build_object(
      'verified_at', NOW(),
      'channel', p_channel,
      'carrier_name', p_carrier_name
    )
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.confirm_line_verification(UUID, TEXT, TEXT) TO authenticated;
