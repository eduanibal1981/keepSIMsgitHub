-- C3b-2 (3/4): every remaining client write path on topup_executions becomes a
-- server-side one, so part 4 can revoke the table grants outright.
--
--  * update_mini_refill_dates: premium_refill_config_sheet edited pending
--    refill_mini rows' execution_time directly.
--  * queue_premium_refill_executions: onboarding/upgrade looped a YEAR of
--    refill_mini inserts client-side, priced client-side from carrier_rules.
--    Now the server reads the rule itself.
--  * retry_topup_execution: replaces the mock-era client retry that debited a
--    real wallet, fabricated a 'success' row with a fake TX id and marked the
--    original 'refunded'. A retry is now a NEW queued execution
--    (retry_of = original) that goes through the real worker pipeline; a new
--    row is required because the BEFORE INSERT triggers (routing, fees, rate
--    limit) don't fire on UPDATE, the debit reference exec_<id> is unique per
--    execution, and Zendit dedupes on transactionId z_<execution_id>.
--  * trg_sync_custom_refill_queue: refill_custom executions are queued /
--    requeued / cancelled by the schedule row itself instead of by client
--    inserts and (silently no-op) deletes.

-- 1) Premium mini-refill date editing.
CREATE OR REPLACE FUNCTION public.update_mini_refill_dates(
  p_sim_line_id uuid,
  p_updates jsonb  -- { "<execution_id>": "<ISO timestamp>", ... }
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  r RECORD;
  v_moved integer := 0;
  v_earliest timestamptz;
BEGIN
  IF auth.uid() IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.sim_lines sl
    WHERE sl.id = p_sim_line_id
      AND (sl.user_id = auth.uid()
           OR EXISTS (SELECT 1 FROM public.household_members hm
                      WHERE hm.owner_id = sl.user_id
                        AND hm.member_id = auth.uid()
                        AND hm.invite_status = 'accepted'
                        AND hm.role = 'manager'))
  ) THEN
    RAISE EXCEPTION 'Not authorized to modify this SIM line schedule';
  END IF;

  -- Only this line's own queued mini refills can move; ids belonging to other
  -- lines/users or already-claimed rows are silently skipped, exactly like the
  -- old RLS-scoped client update.
  FOR r IN SELECT key AS execution_id, value AS new_time FROM jsonb_each_text(p_updates)
  LOOP
    UPDATE public.topup_executions
    SET execution_time = r.new_time::timestamptz
    WHERE id = r.execution_id::uuid
      AND sim_line_id = p_sim_line_id
      AND execution_type = 'refill_mini'
      AND status = 'pending';
    IF FOUND THEN
      v_moved := v_moved + 1;
    END IF;
  END LOOP;

  -- Keep the schedule's next_execution_at in step with the earliest queued row.
  SELECT min(execution_time) INTO v_earliest
  FROM public.topup_executions
  WHERE sim_line_id = p_sim_line_id
    AND execution_type = 'refill_mini'
    AND status = 'pending';

  IF v_earliest IS NOT NULL THEN
    UPDATE public.scheduled_topups
    SET next_execution_at = v_earliest,
        updated_at = now()
    WHERE sim_line_id = p_sim_line_id
      AND schedule_type = 'refill_mini';
  END IF;

  RETURN v_moved;
END;
$$;

REVOKE ALL ON FUNCTION public.update_mini_refill_dates(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_mini_refill_dates(uuid, jsonb) TO authenticated;

-- 2) Premium plan: queue the plan year's mini refills, priced from
-- carrier_rules on the server. Idempotent: requeuing first cancels the
-- schedule's queued rows, so a re-run (e.g. upgrade retried) can't double-book.
CREATE OR REPLACE FUNCTION public.queue_premium_refill_executions(
  p_sim_line_id uuid,
  p_scheduled_topup_id uuid,
  p_plan_expires_at timestamptz DEFAULT NULL,
  p_start_at timestamptz DEFAULT now()
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_line RECORD;
  v_rule RECORD;
  v_expires timestamptz;
  v_t timestamptz;
  v_count integer := 0;
BEGIN
  SELECT sl.user_id, sl.carrier_id, sl.carrier_rule_id, sl.plan_expires_at
  INTO v_line
  FROM public.sim_lines sl
  WHERE sl.id = p_sim_line_id
    AND (auth.uid() IS NULL
         OR sl.user_id = auth.uid()
         OR EXISTS (SELECT 1 FROM public.household_members hm
                    WHERE hm.owner_id = sl.user_id
                      AND hm.member_id = auth.uid()
                      AND hm.invite_status = 'accepted'
                      AND hm.role = 'manager'));

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Not authorized to schedule refills for this SIM line';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.scheduled_topups st
    WHERE st.id = p_scheduled_topup_id
      AND st.sim_line_id = p_sim_line_id
      AND st.schedule_type = 'refill_mini'
  ) THEN
    RAISE EXCEPTION 'Schedule does not belong to this SIM line';
  END IF;

  -- The rule IS the premium entitlement: its minimum_topup_amount is the real
  -- Zendit cost the plan pre-paid for, its offer_id the pinned offer.
  SELECT cr.topup_validity_days, cr.minimum_topup_amount, cr.offer_id, cr.offer_value
  INTO v_rule
  FROM public.carrier_rules cr
  WHERE cr.id = COALESCE(v_line.carrier_rule_id,
                         (SELECT cr2.id FROM public.carrier_rules cr2
                          WHERE cr2.carrier_id = v_line.carrier_id
                          ORDER BY cr2.created_at DESC LIMIT 1));

  IF NOT FOUND OR v_rule.minimum_topup_amount IS NULL OR v_rule.minimum_topup_amount <= 0 THEN
    RAISE EXCEPTION 'No carrier rule with a top-up price exists for this SIM line';
  END IF;

  IF v_rule.topup_validity_days IS NULL OR v_rule.topup_validity_days < 1 THEN
    RAISE EXCEPTION 'Carrier rule has no usable validity period';
  END IF;

  v_expires := COALESCE(p_plan_expires_at, v_line.plan_expires_at, p_start_at + interval '365 days');

  UPDATE public.topup_executions
  SET status = 'cancelled', completed_at = now()
  WHERE scheduled_topup_id = p_scheduled_topup_id
    AND status IN ('pending', 'pending_payment');

  v_t := p_start_at;
  WHILE v_t < v_expires AND v_count < 400 LOOP
    INSERT INTO public.topup_executions (
      sim_line_id, user_id, amount, base_cost_usd, currency, status,
      execution_type, execution_time, offer_id, offer_value,
      payment_gateway_code, scheduled_topup_id
    ) VALUES (
      p_sim_line_id, v_line.user_id, v_rule.minimum_topup_amount,
      v_rule.minimum_topup_amount, 'USD', 'pending',
      'refill_mini', v_t, v_rule.offer_id, v_rule.offer_value,
      NULL,  -- pre-paid: no gateway, so calculate_topup_fees adds no app fee
      p_scheduled_topup_id
    );
    v_count := v_count + 1;
    v_t := v_t + (v_rule.topup_validity_days || ' days')::interval;
  END LOOP;

  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.queue_premium_refill_executions(uuid, uuid, timestamptz, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.queue_premium_refill_executions(uuid, uuid, timestamptz, timestamptz) TO authenticated;

-- 3) Real retry through the real pipeline.
CREATE OR REPLACE FUNCTION public.retry_topup_execution(p_execution_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_exec RECORD;
  v_new_id uuid;
BEGIN
  SELECT t.* INTO v_exec
  FROM public.topup_executions t
  WHERE t.id = p_execution_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Execution not found';
  END IF;

  IF auth.uid() IS NOT NULL AND NOT (
       v_exec.user_id = auth.uid()
       OR EXISTS (SELECT 1 FROM public.sim_lines sl
                  WHERE sl.id = v_exec.sim_line_id AND sl.user_id = auth.uid())
       OR EXISTS (SELECT 1 FROM public.sim_lines sl
                  JOIN public.household_members hm ON hm.owner_id = sl.user_id
                  WHERE sl.id = v_exec.sim_line_id
                    AND hm.member_id = auth.uid()
                    AND hm.invite_status = 'accepted'
                    AND hm.role = 'manager')) THEN
    RAISE EXCEPTION 'Not authorized to retry this execution';
  END IF;

  IF v_exec.status <> 'failed' THEN
    RAISE EXCEPTION 'Only failed executions can be retried';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.topup_executions r
    WHERE r.retry_of = p_execution_id
      AND r.status NOT IN ('failed', 'cancelled')
  ) THEN
    RAISE EXCEPTION 'This execution already has a retry in progress';
  END IF;

  -- A retried scheduled refill still needs its live, active schedule; a
  -- deleted or paused schedule's work must not be revivable this way.
  IF v_exec.scheduled_topup_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.scheduled_topups st
    WHERE st.id = v_exec.scheduled_topup_id AND st.is_active
  ) THEN
    RAISE EXCEPTION 'The schedule behind this execution is no longer active';
  END IF;

  INSERT INTO public.topup_executions (
    sim_line_id, user_id, amount, base_cost_usd, payment_gateway_code,
    currency, status, execution_type, execution_time,
    offer_id, offer_value, scheduled_topup_id, retry_of
  ) VALUES (
    v_exec.sim_line_id, v_exec.user_id,
    COALESCE(v_exec.base_cost_usd, v_exec.amount),
    COALESCE(v_exec.base_cost_usd, v_exec.amount),
    v_exec.payment_gateway_code,
    v_exec.currency, 'pending', v_exec.execution_type, now(),
    v_exec.offer_id, v_exec.offer_value, v_exec.scheduled_topup_id,
    p_execution_id
  )
  RETURNING id INTO v_new_id;

  RETURN v_new_id;
END;
$$;

REVOKE ALL ON FUNCTION public.retry_topup_execution(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.retry_topup_execution(uuid) TO authenticated;

-- 4) refill_custom executions follow their schedule row. The success path
-- (update_sim_line_last_topup_at) inserts the next execution and THEN bumps
-- next_execution_at, so this trigger treats "a matching pending row already
-- exists" as done; any other change cancels the queue and rebuilds it from
-- the schedule.
CREATE OR REPLACE FUNCTION public.trg_fn_sync_custom_refill_queue()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  IF NEW.schedule_type <> 'refill_custom' THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE'
     AND NEW.amount IS NOT DISTINCT FROM OLD.amount
     AND NEW.currency IS NOT DISTINCT FROM OLD.currency
     AND NEW.next_execution_at IS NOT DISTINCT FROM OLD.next_execution_at
     AND NEW.is_active IS NOT DISTINCT FROM OLD.is_active
     AND NEW.offer_id IS NOT DISTINCT FROM OLD.offer_id
     AND NEW.offer_value IS NOT DISTINCT FROM OLD.offer_value THEN
    RETURN NEW;
  END IF;

  IF COALESCE(NEW.is_active, false) THEN
    IF EXISTS (
      SELECT 1 FROM public.topup_executions t
      WHERE t.scheduled_topup_id = NEW.id
        AND t.status = 'pending'
        AND t.execution_time = NEW.next_execution_at
        AND t.amount = NEW.amount
        AND t.offer_id IS NOT DISTINCT FROM NEW.offer_id
    ) THEN
      RETURN NEW;
    END IF;

    UPDATE public.topup_executions
    SET status = 'cancelled', completed_at = now()
    WHERE scheduled_topup_id = NEW.id
      AND status IN ('pending', 'pending_payment');

    INSERT INTO public.topup_executions (
      sim_line_id, user_id, amount, base_cost_usd, currency, status,
      execution_type, execution_time, offer_id, offer_value,
      payment_gateway_code, scheduled_topup_id
    ) VALUES (
      NEW.sim_line_id, NEW.user_id, NEW.amount, NEW.amount,
      COALESCE(NEW.currency, 'USD'), 'pending',
      'refill_custom', NEW.next_execution_at, NEW.offer_id, NEW.offer_value,
      NULL, NEW.id
    );
  ELSE
    UPDATE public.topup_executions
    SET status = 'cancelled', completed_at = now()
    WHERE scheduled_topup_id = NEW.id
      AND status IN ('pending', 'pending_payment');
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.trg_fn_sync_custom_refill_queue() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_sync_custom_refill_queue ON public.scheduled_topups;
CREATE TRIGGER trg_sync_custom_refill_queue
  AFTER INSERT OR UPDATE ON public.scheduled_topups
  FOR EACH ROW EXECUTE FUNCTION public.trg_fn_sync_custom_refill_queue();