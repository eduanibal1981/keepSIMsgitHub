-- ==============================================================================
-- Migration: 20260915050000_approve_refill_execution_rpc.sql
-- Description: Adds approve_refill_execution RPC allowing users/admin to approve
--              price-drifted refills in 'awaiting_approval' status.
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.approve_refill_execution(
  p_execution_id UUID,
  p_new_max_authorized_usd NUMERIC DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_exec RECORD;
  v_new_cap NUMERIC;
BEGIN
  SELECT * INTO v_exec
  FROM public.topup_executions
  WHERE id = p_execution_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Execution % not found', p_execution_id;
  END IF;

  IF v_exec.status <> 'awaiting_approval' THEN
    RAISE EXCEPTION 'Execution % is in status %, expected awaiting_approval', p_execution_id, v_exec.status;
  END IF;

  -- Determine new cap: defaults to current quoted amount on execution if not specified
  v_new_cap := COALESCE(p_new_max_authorized_usd, v_exec.amount);

  -- Transition execution back to pending with updated cap
  UPDATE public.topup_executions
  SET max_authorized_usd = v_new_cap,
      status = 'pending',
      failure_reason = NULL,
      execution_time = NOW(),
      updated_at = NOW()
  WHERE id = p_execution_id;

  -- If tied to a scheduled topup, update schedule's max_authorized_usd as well
  IF v_exec.scheduled_topup_id IS NOT NULL THEN
    UPDATE public.scheduled_topups
    SET max_authorized_usd = v_new_cap,
        updated_at = NOW()
    WHERE id = v_exec.scheduled_topup_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'execution_id', p_execution_id,
    'new_max_authorized_usd', v_new_cap,
    'status', 'pending'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.approve_refill_execution(UUID, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_refill_execution(UUID, NUMERIC) TO service_role;
