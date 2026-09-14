-- =============================================================================
-- Migration: 20260914040000_update_health_score_four_pillars.sql
-- Description:
--   Update calculate_health_score to 4 pillars of 25 points each (max 100):
--   1. Any refill schedule is 25 point (status = 'active', schedule_type in ('refill_custom', 'refill_mini'))
--   2. Any verification is 25 point (status = 'active', is_carrier_verified = true, etc.)
--   3. Any notification setted = 25 point (status = 'active', schedule_type = 'notify')
--   4. Last refill date < carrier rule expiration days (default 90) = 25 point
-- =============================================================================

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
  -- 1. Any refill schedule is 25 point
  SELECT EXISTS(
    SELECT 1 FROM public.scheduled_topups
    WHERE sim_line_id = p_sim_line_id
      AND status = 'active'
      AND schedule_type IN ('refill_custom', 'refill_mini')
  ) INTO v_has_refill_schedule;

  IF v_has_refill_schedule THEN
    v_score := v_score + 25;
  END IF;

  -- 2. Any verification is 25 point
  SELECT (
    p_status = 'active'
    OR COALESCE(is_carrier_verified, false) = true
    OR carrier_verified_at IS NOT NULL
    OR verification_status = 'verified'
  ) INTO v_is_verified
  FROM public.sim_lines
  WHERE id = p_sim_line_id;

  IF COALESCE(v_is_verified, p_status = 'active') THEN
    v_score := v_score + 25;
  END IF;

  -- 3. Any notification setted = 25 point
  SELECT EXISTS(
    SELECT 1 FROM public.scheduled_topups
    WHERE sim_line_id = p_sim_line_id
      AND status = 'active'
      AND schedule_type = 'notify'
  ) INTO v_has_notify_schedule;

  IF v_has_notify_schedule THEN
    v_score := v_score + 25;
  END IF;

  -- 4. Last refill date < carrier rule expiration days (default 90) = 25 point
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

-- Recalculate health_score for all existing sim_lines
UPDATE public.sim_lines
SET health_score = public.calculate_health_score(id, status, last_topup_at),
    updated_at = NOW();
