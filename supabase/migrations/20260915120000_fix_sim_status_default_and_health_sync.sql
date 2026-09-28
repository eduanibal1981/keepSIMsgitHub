-- Migration: 20260915120000_fix_sim_status_default_and_health_sync.sql
-- Description:
--   1. Align sim_lines.status default to 'active' (satisfies sim_lines_status_check).
--   2. Drop DEFAULT now() on topup_executions.executed_at so pending executions do not have executed_at set at creation.
--   3. Update calculate_health_score so unverified lines (verification_status = 'unverified') do not receive verification points solely because status = 'active'.
--   4. Add trg_sync_sim_line_health_and_due trigger on scheduled_topups to keep sim_lines.health_score and next_topup_due updated in sync with schedules.

-- 1. Align sim_lines.status default
ALTER TABLE public.sim_lines ALTER COLUMN status SET DEFAULT 'active';

-- 2. Drop DEFAULT now() on topup_executions.executed_at
ALTER TABLE public.topup_executions ALTER COLUMN executed_at DROP DEFAULT;

-- 3. Align calculate_health_score verification pillar
CREATE OR REPLACE FUNCTION public.calculate_health_score(
  p_sim_line_id uuid,
  p_status text,
  p_last_topup_at timestamp with time zone
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_has_refill_schedule BOOLEAN := false;
  v_has_notify_schedule BOOLEAN := false;
  v_is_verified BOOLEAN := false;
  v_expiration_days INTEGER := 90;
  v_rule_days INTEGER;
  v_score INTEGER := 0;
BEGIN
  -- 1. Any refill schedule is 25 points
  SELECT EXISTS(
    SELECT 1 FROM public.scheduled_topups
    WHERE sim_line_id = p_sim_line_id
      AND status = 'active'
      AND is_active = true
      AND schedule_type IN ('refill_custom', 'refill_mini')
  ) INTO v_has_refill_schedule;

  IF v_has_refill_schedule THEN
    v_score := v_score + 25;
  END IF;

  -- 2. Verification pillar is 25 points
  -- Requires confirmed verification; status = 'active' alone on an unverified line does NOT grant points.
  SELECT (
    COALESCE(verification_status, 'unverified') = 'verified'
    OR COALESCE(is_carrier_verified, false) = true
    OR carrier_verified_at IS NOT NULL
  ) INTO v_is_verified
  FROM public.sim_lines
  WHERE id = p_sim_line_id;

  IF COALESCE(v_is_verified, false) THEN
    v_score := v_score + 25;
  END IF;

  -- 3. Any notification schedule is 25 points
  SELECT EXISTS(
    SELECT 1 FROM public.scheduled_topups
    WHERE sim_line_id = p_sim_line_id
      AND status = 'active'
      AND is_active = true
      AND schedule_type = 'notify'
  ) INTO v_has_notify_schedule;

  IF v_has_notify_schedule THEN
    v_score := v_score + 25;
  END IF;

  -- 4. Last refill date < carrier rule expiration days (default 90) = 25 points
  SELECT cr.inactivity_limit_days INTO v_rule_days
  FROM public.sim_lines sl
  LEFT JOIN public.carrier_rules cr ON (cr.id = sl.carrier_rule_id OR cr.carrier_id = sl.carrier_id)
  WHERE sl.id = p_sim_line_id
  LIMIT 1;

  IF v_rule_days IS NOT NULL AND v_rule_days > 0 THEN
    v_expiration_days := v_rule_days;
  END IF;

  IF p_last_topup_at IS NOT NULL AND p_last_topup_at >= NOW() - (v_expiration_days || ' days')::INTERVAL THEN
    v_score := v_score + 25;
  END IF;

  RETURN LEAST(100, GREATEST(0, v_score));
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.calculate_health_score(uuid, text, timestamp with time zone) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.calculate_health_score(uuid, text, timestamp with time zone) TO authenticated, service_role;

-- 4. Trigger to sync sim_lines health_score and next_topup_due from scheduled_topups
CREATE OR REPLACE FUNCTION public.trg_fn_sync_sim_line_health_and_due()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_sim_id UUID;
  v_line RECORD;
  v_next_due TIMESTAMPTZ;
  v_health INT;
BEGIN
  v_sim_id := COALESCE(NEW.sim_line_id, OLD.sim_line_id);
  IF v_sim_id IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  SELECT * INTO v_line
  FROM public.sim_lines
  WHERE id = v_sim_id;

  IF NOT FOUND THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  -- Compute next topup due from active refill schedules
  SELECT MIN(next_execution_at) INTO v_next_due
  FROM public.scheduled_topups
  WHERE sim_line_id = v_sim_id
    AND is_active = true
    AND status = 'active'
    AND schedule_type IN ('refill_mini', 'refill_custom');

  -- Calculate health score
  v_health := public.calculate_health_score(v_sim_id, v_line.status, v_line.last_topup_at);

  -- Update sim_line
  UPDATE public.sim_lines
  SET next_topup_due = v_next_due,
      health_score = v_health,
      updated_at = now()
  WHERE id = v_sim_id
    AND (next_topup_due IS DISTINCT FROM v_next_due OR health_score IS DISTINCT FROM v_health);

  RETURN COALESCE(NEW, OLD);
END;
$function$;

DROP TRIGGER IF EXISTS trg_sync_sim_line_health_and_due ON public.scheduled_topups;
CREATE TRIGGER trg_sync_sim_line_health_and_due
  AFTER INSERT OR UPDATE OF is_active, status, schedule_type, next_execution_at OR DELETE
  ON public.scheduled_topups
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_sync_sim_line_health_and_due();
