-- Migration: 20260915140000_fix_draft_health_and_universal_sync.sql
-- Description:
--   1. Set sim_lines.health_score DEFAULT 0 so new unverified draft SIM lines start with 0
--      instead of misleading 100 before verification/refills/schedules exist.
--   2. Universally synchronize health_score and next_topup_due across all existing active SIM lines
--      with active schedules.

-- 1. Align default health_score on sim_lines
ALTER TABLE public.sim_lines ALTER COLUMN health_score SET DEFAULT 0;

-- 2. Universal sync for all active lines with active schedules
UPDATE public.sim_lines sl
SET next_topup_due = sub.next_due,
    health_score = public.calculate_health_score(sl.id, sl.status, sl.last_topup_at),
    updated_at = now()
FROM (
  SELECT sim_line_id, MIN(next_execution_at) AS next_due
  FROM public.scheduled_topups
  WHERE is_active = true
    AND status = 'active'
    AND schedule_type IN ('refill_mini', 'refill_custom')
  GROUP BY sim_line_id
) sub
WHERE sl.id = sub.sim_line_id
  AND (sl.next_topup_due IS DISTINCT FROM sub.next_due 
       OR sl.health_score IS DISTINCT FROM public.calculate_health_score(sl.id, sl.status, sl.last_topup_at));
