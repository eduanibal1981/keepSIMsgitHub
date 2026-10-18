-- C3b-2 (1/4): cancellation is a real state, deleting a schedule stops its
-- queued work, and the auto workers refuse orphaned or paused work.
--
-- Client DELETE on topup_executions has always been a silent no-op (no DELETE
-- policy), and scheduled_topup_id is ON DELETE SET NULL, so deleting a schedule
-- orphaned its pending executions while claim_due_executions picked them up
-- with no parent check: a cancelled schedule's refills would still fire and
-- debit. 'cancelled' + the trigger + the claim guard close all three holes.

-- 1) 'cancelled' joins the status vocabulary.
ALTER TABLE public.topup_executions DROP CONSTRAINT topup_executions_status_check;
ALTER TABLE public.topup_executions ADD CONSTRAINT topup_executions_status_check
  CHECK (status = ANY (ARRAY['pending'::text, 'pending_payment'::text, 'processing'::text,
                             'routing'::text, 'success'::text, 'failed'::text,
                             'refunded'::text, 'cancelled'::text]));

-- 2) The client's way to stop queued work. Only queued rows can be cancelled:
-- anything the workers may already be spending on ('processing'/'routing') is
-- immutable from the client, which is the entire point of C3b-2.
CREATE OR REPLACE FUNCTION public.cancel_topup_execution(p_execution_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_user_id uuid;
  v_sim_line_id uuid;
  v_status text;
BEGIN
  SELECT t.user_id, t.sim_line_id, t.status
  INTO v_user_id, v_sim_line_id, v_status
  FROM public.topup_executions t
  WHERE t.id = p_execution_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Execution not found';
  END IF;

  -- Same authorization shape as reschedule_mini_refill: the payer, the line
  -- owner, or an accepted household manager. auth.uid() IS NULL means a
  -- service-role caller, which is trusted.
  IF auth.uid() IS NOT NULL AND NOT (
       v_user_id = auth.uid()
       OR EXISTS (SELECT 1 FROM public.sim_lines sl
                  WHERE sl.id = v_sim_line_id AND sl.user_id = auth.uid())
       OR EXISTS (SELECT 1 FROM public.sim_lines sl
                  JOIN public.household_members hm ON hm.owner_id = sl.user_id
                  WHERE sl.id = v_sim_line_id
                    AND hm.member_id = auth.uid()
                    AND hm.invite_status = 'accepted'
                    AND hm.role = 'manager')) THEN
    RAISE EXCEPTION 'Not authorized to cancel this execution';
  END IF;

  IF v_status NOT IN ('pending', 'pending_payment') THEN
    RETURN false;
  END IF;

  UPDATE public.topup_executions
  SET status = 'cancelled',
      completed_at = now()
  WHERE id = p_execution_id;

  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.cancel_topup_execution(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_topup_execution(uuid) TO authenticated;

-- 3) Deleting a schedule cancels its queued executions BEFORE the FK sets
-- their scheduled_topup_id to NULL, so no orphan is ever claimable. Fires for
-- every deletion path (app, admin app, SQL), unlike the old client-side delete.
CREATE OR REPLACE FUNCTION public.trg_fn_cancel_executions_on_schedule_delete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  UPDATE public.topup_executions
  SET status = 'cancelled',
      completed_at = now()
  WHERE scheduled_topup_id = OLD.id
    AND status IN ('pending', 'pending_payment');
  RETURN OLD;
END;
$$;

REVOKE ALL ON FUNCTION public.trg_fn_cancel_executions_on_schedule_delete() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_cancel_executions_on_schedule_delete ON public.scheduled_topups;
CREATE TRIGGER trg_cancel_executions_on_schedule_delete
  BEFORE DELETE ON public.scheduled_topups
  FOR EACH ROW EXECUTE FUNCTION public.trg_fn_cancel_executions_on_schedule_delete();

-- 4) The auto workers only claim work whose parent schedule still exists and
-- is active. A NULL parent stays claimable: pre-existing rows and any future
-- parentless scheduled work would otherwise silently starve. Pausing a
-- schedule now actually pauses it (rows stay 'pending', just unclaimable);
-- resuming lets any past-due rows fire on the next poll.
CREATE OR REPLACE FUNCTION public.claim_due_executions(p_execution_type character varying, p_limit integer)
RETURNS SETOF topup_executions
LANGUAGE plpgsql
SET search_path TO ''
AS $$
BEGIN
  RETURN QUERY
  UPDATE public.topup_executions
  SET status = 'processing',
      processing_since = NOW(),
      pre_processing_status = 'pending'
  WHERE id IN (
    SELECT t.id FROM public.topup_executions t
    WHERE t.status = 'pending'
      AND t.execution_type = p_execution_type
      AND t.execution_time <= NOW()
      AND (t.scheduled_topup_id IS NULL OR EXISTS (
        SELECT 1 FROM public.scheduled_topups st
        WHERE st.id = t.scheduled_topup_id
          AND st.is_active))
    ORDER BY t.execution_time ASC
    LIMIT p_limit
    FOR UPDATE SKIP LOCKED
  )
  RETURNING *;
END;
$$;