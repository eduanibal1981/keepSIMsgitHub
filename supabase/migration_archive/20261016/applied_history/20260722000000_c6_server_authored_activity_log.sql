-- Migration: 20260722000000_c6_server_authored_activity_log.sql
-- C6 Activity Log — Server-authored money trail, Option A deletion policy, retention cap

-- 0. Update event_type CHECK constraint and created_at default on line_activity_log
ALTER TABLE public.line_activity_log ALTER COLUMN created_at SET DEFAULT clock_timestamp();

ALTER TABLE public.line_activity_log DROP CONSTRAINT IF EXISTS line_activity_log_event_type_check;

ALTER TABLE public.line_activity_log ADD CONSTRAINT line_activity_log_event_type_check CHECK (
  event_type = ANY (ARRAY[
    'topup_requested'::text,
    'topup_success'::text,
    'topup_failed'::text,
    'topup_refunded'::text,
    'topup_cancelled'::text,
    'topup_retry_queued'::text,
    'reminder_sent'::text,
    'status_change'::text,
    'health_update'::text,
    'tier_change'::text,
    'paused'::text,
    'resumed'::text,
    'created'::text,
    'grace_period_entered'::text,
    'rescue_topup_triggered'::text,
    'validity_extended'::text
  ])
);

-- 1. Trigger function to automatically log topup_executions events to line_activity_log
CREATE OR REPLACE FUNCTION public.trg_fn_log_topup_activity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_event_type TEXT;
  v_metadata JSONB;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_event_type := CASE 
      WHEN NEW.retry_of IS NOT NULL THEN 'topup_retry_queued'
      ELSE 'topup_requested'
    END;

    v_metadata := jsonb_build_object(
      'amount', NEW.amount,
      'base_cost_usd', NEW.base_cost_usd,
      'execution_id', NEW.id,
      'execution_type', NEW.execution_type,
      'provider', COALESCE(NEW.api_provider, 'zendit'),
      'offer_id', NEW.offer_id,
      'refill_channel', NEW.refill_channel
    );

    INSERT INTO public.line_activity_log (
      sim_line_id, user_id, event_type, description, metadata, created_at
    ) VALUES (
      NEW.sim_line_id, NEW.user_id, v_event_type, NULL, v_metadata, clock_timestamp()
    );

  ELSIF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    IF NEW.status = 'success' THEN
      v_event_type := 'topup_success';
      v_metadata := jsonb_build_object(
        'amount', NEW.amount,
        'execution_id', NEW.id,
        'execution_type', NEW.execution_type,
        'provider', COALESCE(NEW.api_provider, 'zendit'),
        'transaction_id', NEW.reloadly_transaction_id,
        'refill_channel', NEW.refill_channel
      );
    ELSIF NEW.status = 'failed' THEN
      v_event_type := 'topup_failed';
      v_metadata := jsonb_build_object(
        'amount', NEW.amount,
        'execution_id', NEW.id,
        'execution_type', NEW.execution_type,
        'provider', COALESCE(NEW.api_provider, 'zendit'),
        'failure_reason', COALESCE(NEW.failure_reason, 'Execution failed'),
        'refill_channel', NEW.refill_channel
      );
    ELSIF NEW.status = 'refunded' THEN
      v_event_type := 'topup_refunded';
      v_metadata := jsonb_build_object(
        'amount', NEW.amount,
        'execution_id', NEW.id,
        'execution_type', NEW.execution_type,
        'refund_reason', COALESCE(NEW.failure_reason, 'Wallet refunded')
      );
    ELSIF NEW.status = 'cancelled' THEN
      v_event_type := 'topup_cancelled';
      v_metadata := jsonb_build_object(
        'amount', NEW.amount,
        'execution_id', NEW.id,
        'execution_type', NEW.execution_type
      );
    ELSE
      RETURN NEW;
    END IF;

    INSERT INTO public.line_activity_log (
      sim_line_id, user_id, event_type, description, metadata, created_at
    ) VALUES (
      NEW.sim_line_id, NEW.user_id, v_event_type, NULL, v_metadata, clock_timestamp()
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_topup_executions_activity ON public.topup_executions;
CREATE TRIGGER trg_topup_executions_activity
  AFTER INSERT OR UPDATE OF status ON public.topup_executions
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_log_topup_activity();

-- 2. Update process_due_notifications() to log 'reminder_sent' instead of 'topup_success'
CREATE OR REPLACE FUNCTION public.process_due_notifications()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  r RECORD;
  v_phone_number TEXT;
  v_next_due TIMESTAMPTZ;
BEGIN
  FOR r IN 
    SELECT s.id, s.sim_line_id, s.user_id, s.amount, s.currency, s.frequency_days
    FROM public.scheduled_topups s
    WHERE s.is_active = true 
      AND s.status = 'active'
      AND s.schedule_type = 'notify'
      AND s.next_execution_at <= NOW()
  LOOP
    SELECT phone_number INTO v_phone_number
    FROM public.sim_lines
    WHERE id = r.sim_line_id;

    INSERT INTO public.notifications (
      user_id, category, title, body, action_url, sim_line_id, delivered_via, is_read, created_at
    ) VALUES (
      r.user_id, 'line_critical', 'Notify Renewal', 
      'Your Phone Number (' || COALESCE(v_phone_number, '') || ') is due for recharge. Please top up at least $' || to_char(r.amount, 'FM99999990.00') || ' to keep it active.',
      '/sim_lines/' || r.sim_line_id, r.sim_line_id, ARRAY['push'::text], false, NOW()
    );

    INSERT INTO public.line_activity_log (
      sim_line_id, user_id, event_type, description, metadata, created_at
    ) VALUES (
      r.sim_line_id, r.user_id, 'reminder_sent', 
      NULL,
      jsonb_build_object('amount', r.amount, 'schedule_type', 'notify'),
      clock_timestamp()
    );

    v_next_due := NOW() + (CASE WHEN r.frequency_days = 0 THEN INTERVAL '1 hour' ELSE r.frequency_days * INTERVAL '1 day' END);

    UPDATE public.scheduled_topups
    SET last_execution_at = NOW(),
        next_execution_at = v_next_due,
        retry_count = 0,
        whatsapp_sent_this_cycle = false,
        status = 'active',
        updated_at = NOW()
    WHERE id = r.id;
  END LOOP;
END;
$$;

-- 3. Retention Cap: Prune line_activity_log to newest 50 per sim_line_id
CREATE OR REPLACE FUNCTION public.trg_fn_prune_line_activity_log()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM public.line_activity_log
  WHERE sim_line_id = NEW.sim_line_id
    AND id NOT IN (
      SELECT id FROM public.line_activity_log
      WHERE sim_line_id = NEW.sim_line_id
      ORDER BY created_at DESC, id DESC
      LIMIT 50
    );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_line_activity_log_prune ON public.line_activity_log;
CREATE TRIGGER trg_line_activity_log_prune
  AFTER INSERT ON public.line_activity_log
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_prune_line_activity_log();

-- 4. Option A Deletion Policy & RLS Lockdown on line_activity_log
ALTER FUNCTION public.trg_fn_log_topup_activity() SET search_path = '';
ALTER FUNCTION public.trg_fn_prune_line_activity_log() SET search_path = '';
REVOKE EXECUTE ON FUNCTION public.trg_fn_log_topup_activity() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_fn_prune_line_activity_log() FROM PUBLIC, anon, authenticated;

DROP POLICY IF EXISTS "Users can insert own line activity" ON public.line_activity_log;
DROP POLICY IF EXISTS "Users can delete own line activity logs" ON public.line_activity_log;
DROP POLICY IF EXISTS "Users can insert non-financial line activity" ON public.line_activity_log;
DROP POLICY IF EXISTS "Users can delete non-financial line activity" ON public.line_activity_log;

CREATE POLICY "Users can insert non-financial line activity" ON public.line_activity_log
  FOR INSERT WITH CHECK (
    auth.uid() = user_id 
    AND NOT is_user_suspended()
    AND event_type NOT IN ('topup_requested', 'topup_success', 'topup_failed', 'topup_refunded', 'topup_cancelled', 'topup_retry_queued')
  );

CREATE POLICY "Users can delete non-financial line activity" ON public.line_activity_log
  FOR DELETE USING (
    auth.uid() = user_id 
    AND NOT is_user_suspended()
    AND event_type NOT IN ('topup_requested', 'topup_success', 'topup_failed', 'topup_refunded', 'topup_cancelled', 'topup_retry_queued')
  );
