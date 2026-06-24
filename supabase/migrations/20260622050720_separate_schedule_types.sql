-- Migrate schedule_type
ALTER TABLE public.scheduled_topups DROP CONSTRAINT IF EXISTS scheduled_topups_schedule_type_check;

UPDATE public.scheduled_topups 
SET schedule_type = 'refill mini' 
WHERE schedule_type = 'refill' AND amount = 0;

UPDATE public.scheduled_topups 
SET schedule_type = 'refill custom' 
WHERE schedule_type = 'refill' AND amount > 0;

ALTER TABLE public.scheduled_topups ADD CONSTRAINT scheduled_topups_schedule_type_check CHECK (schedule_type = ANY (ARRAY['notify'::text, 'refill mini'::text, 'refill custom'::text]));

-- Revert is_premium_auto_refill_active from sim_lines
ALTER TABLE public.sim_lines DROP COLUMN IF EXISTS is_premium_auto_refill_active;
