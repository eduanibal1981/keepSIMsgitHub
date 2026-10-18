-- Migration: Fix record_manual_external_recharge RPC
-- Description:
-- Previously, record_manual_external_recharge attempted to insert into topup_executions
-- referencing non-existent columns (notes, error_message) and invalid enum values (status = 'completed', gateway = 'EXTERNAL').
-- topup_executions is the billing/supplier dispatch queue, whereas manual external recharges belong in line_activity_log.
-- This migration updates record_manual_external_recharge to record in line_activity_log (event_type: validity_extended),
-- update sim_lines.last_topup_at, clear auto-rescue warning clocks, and recompute usage forecasts.

CREATE OR REPLACE FUNCTION public.record_manual_external_recharge(
  p_sim_line_id     uuid,
  p_recharge_date   timestamptz DEFAULT now(),
  p_amount          numeric     DEFAULT NULL,
  p_note            text        DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_line RECORD;
  v_user_id uuid;
  v_log_id uuid;
  v_description text;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = 'KS401';
  END IF;

  SELECT * INTO v_line
  FROM public.sim_lines
  WHERE id = p_sim_line_id
    AND (user_id = v_user_id
         OR EXISTS (
           SELECT 1 FROM public.household_members hm
           WHERE hm.owner_id = sim_lines.user_id
             AND hm.member_id = v_user_id
             AND hm.invite_status = 'accepted'
             AND hm.role = 'manager'
         ));

  IF NOT FOUND THEN
    RAISE EXCEPTION 'SIM line not found or unauthorized' USING ERRCODE = 'KS404';
  END IF;

  v_description := COALESCE(NULLIF(btrim(p_note), ''), 'Manual external recharge logged');

  -- 1. Insert activity log entry for audit and UI trail
  INSERT INTO public.line_activity_log (
    sim_line_id,
    user_id,
    event_type,
    description,
    metadata,
    created_at
  ) VALUES (
    p_sim_line_id,
    v_user_id,
    'validity_extended',
    v_description,
    jsonb_build_object(
      'recharge_date', p_recharge_date,
      'amount', p_amount,
      'note', p_note,
      'source', 'external'
    ),
    now()
  )
  RETURNING id INTO v_log_id;

  -- 2. Explicitly update sim_lines last_topup_at (will also trigger trg_update_line_health)
  UPDATE public.sim_lines
  SET last_topup_at = p_recharge_date,
      updated_at = now()
  WHERE id = p_sim_line_id;

  -- 3. Clear any pending auto-rescue warning clock
  UPDATE public.sim_line_rescue_policy
  SET last_warned_at = NULL
  WHERE sim_line_id = p_sim_line_id;

  -- 4. Recompute usage forecast asynchronously / best-effort
  BEGIN
    PERFORM public.compute_usage_forecasts();
  EXCEPTION WHEN OTHERS THEN
    -- Best effort, do not block
  END;

  RETURN jsonb_build_object(
    'success', true,
    'activity_id', v_log_id,
    'sim_line_id', p_sim_line_id,
    'last_topup_at', p_recharge_date
  );
END;
$$;

REVOKE ALL ON FUNCTION public.record_manual_external_recharge(uuid, timestamptz, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_manual_external_recharge(uuid, timestamptz, numeric, text) TO authenticated, service_role;
