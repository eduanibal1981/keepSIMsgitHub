-- Migration: Fix foreign key violation when deleting sim_line
-- When a sim_line is deleted, PostgreSQL cascades deletion to scheduled_topups.
-- The trigger trg_cancel_executions_on_schedule_delete previously executed an UPDATE on topup_executions,
-- which in turn fired trg_topup_executions_activity -> trg_fn_log_topup_activity().
-- Because the parent sim_line was already deleted in the transaction, inserting into line_activity_log
-- violated line_activity_log_sim_line_id_fkey.

-- 1. Guard trg_fn_cancel_executions_on_schedule_delete so it does not cancel topup_executions
-- if the parent sim_line is already being deleted (topup_executions will cascade-delete anyway).
CREATE OR REPLACE FUNCTION public.trg_fn_cancel_executions_on_schedule_delete()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  -- If the parent sim_line is already deleted or being deleted, topup_executions
  -- will be cascade-deleted automatically; do not trigger cancellation cascades.
  IF OLD.sim_line_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.sim_lines WHERE id = OLD.sim_line_id
  ) THEN
    RETURN OLD;
  END IF;

  UPDATE public.topup_executions
  SET status = 'cancelled',
      completed_at = now()
  WHERE scheduled_topup_id = OLD.id
    AND status IN ('pending', 'pending_payment');
  RETURN OLD;
END;
$function$;

-- 2. Guard trg_fn_log_topup_activity so it does not attempt to insert into line_activity_log
-- if the sim_line does not exist (e.g. being deleted in the current transaction).
CREATE OR REPLACE FUNCTION public.trg_fn_log_topup_activity()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_event_type TEXT;
  v_metadata JSONB;
BEGIN
  -- Guard: If sim_line does not exist (e.g. being deleted in the current transaction),
  -- skip inserting into line_activity_log to avoid FK constraint violation.
  IF NEW.sim_line_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.sim_lines WHERE id = NEW.sim_line_id
  ) THEN
    RETURN NEW;
  END IF;

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
      'funding_kind', NEW.funding_kind,
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
        'funding_kind', NEW.funding_kind,
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
        'funding_kind', NEW.funding_kind,
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
        'funding_kind', NEW.funding_kind,
        'refund_reason', COALESCE(NEW.failure_reason, 'Wallet refunded')
      );
    ELSIF NEW.status = 'cancelled' THEN
      v_event_type := 'topup_cancelled';
      v_metadata := jsonb_build_object(
        'amount', NEW.amount,
        'execution_id', NEW.id,
        'execution_type', NEW.execution_type,
        'funding_kind', NEW.funding_kind
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
$function$;
