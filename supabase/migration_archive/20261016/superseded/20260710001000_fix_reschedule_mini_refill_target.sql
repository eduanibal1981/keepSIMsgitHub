-- 1. Redefine reschedule function to target future executions (> 1 hour from now)
CREATE OR REPLACE FUNCTION public.reschedule_mini_refill(
  p_sim_line_id uuid, 
  p_new_date timestamp with time zone
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Update scheduled_topups next_execution_at
  UPDATE public.scheduled_topups
  SET next_execution_at = p_new_date,
      updated_at = NOW()
  WHERE sim_line_id = p_sim_line_id AND schedule_type = 'refill_mini';

  -- Update earliest pending topup_execution in the future
  UPDATE public.topup_executions
  SET execution_time = p_new_date
  WHERE id = (
    SELECT id FROM public.topup_executions
    WHERE sim_line_id = p_sim_line_id 
      AND execution_type = 'refill_mini' 
      AND status = 'pending'
      AND execution_time > NOW() + INTERVAL '1 hour'
    ORDER BY execution_time ASC
    LIMIT 1
  );
END;
$$;

-- 2. Redefine reset to default function to target future executions (> 1 hour from now)
CREATE OR REPLACE FUNCTION public.reset_mini_refill_to_default(
  p_sim_line_id uuid
)
RETURNS timestamp with time zone
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_next_topup_due timestamp with time zone;
  v_frequency_days integer;
  v_buffer_days integer;
  v_default_date timestamp with time zone;
BEGIN
  -- Get next_topup_due from sim_lines
  SELECT next_topup_due INTO v_next_topup_due
  FROM public.sim_lines
  WHERE id = p_sim_line_id;

  -- Get frequency_days from scheduled_topups
  SELECT frequency_days INTO v_frequency_days
  FROM public.scheduled_topups
  WHERE sim_line_id = p_sim_line_id AND schedule_type = 'refill_mini';

  IF v_next_topup_due IS NULL OR v_frequency_days IS NULL THEN
    -- Fallback to today + 85 days
    v_default_date := NOW() + INTERVAL '85 days';
  ELSE
    -- Compute buffer
    IF v_frequency_days >= 85 THEN
      v_buffer_days := 5;
    ELSIF v_frequency_days = 30 THEN
      v_buffer_days := 2;
    ELSIF v_frequency_days = 14 THEN
      v_buffer_days := 1;
    ELSE
      v_buffer_days := 0;
    END IF;

    v_default_date := v_next_topup_due - (v_buffer_days * INTERVAL '1 day');
  END IF;

  -- Ensure it's not in the past
  IF v_default_date < NOW() THEN
    v_default_date := NOW();
  END IF;

  -- Update scheduled_topups
  UPDATE public.scheduled_topups
  SET next_execution_at = v_default_date,
      updated_at = NOW()
  WHERE sim_line_id = p_sim_line_id AND schedule_type = 'refill_mini';

  -- Update earliest pending topup_execution in the future
  UPDATE public.topup_executions
  SET execution_time = v_default_date
  WHERE id = (
    SELECT id FROM public.topup_executions
    WHERE sim_line_id = p_sim_line_id 
      AND execution_type = 'refill_mini' 
      AND status = 'pending'
      AND execution_time > NOW() + INTERVAL '1 hour'
    ORDER BY execution_time ASC
    LIMIT 1
  );

  RETURN v_default_date;
END;
$$;

-- 3. Fix the user's specific duplicate record back to today (due immediately)
UPDATE public.topup_executions
SET execution_time = NOW()
WHERE id = 'b0721ad3-795b-4c47-aad8-eec4faac2a91'
  AND status = 'pending';
