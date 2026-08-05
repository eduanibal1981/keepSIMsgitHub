-- Fix SIM line deletion constraint error:
-- When a SIM line is deleted, cascading delete of scheduled_topups cancels pending topup_executions,
-- which triggers trg_fn_log_topup_activity to insert a row into line_activity_log.
-- Since the sim_line_id is being deleted from sim_lines in the outer statement, inserting into line_activity_log
-- violated line_activity_log_sim_line_id_fkey foreign key constraint.
--
-- This migration adds EXISTS checks against sim_lines before inserting logs or notifications or updating sim_lines.

CREATE OR REPLACE FUNCTION public.trg_fn_log_topup_activity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_event_type TEXT;
  v_metadata JSONB;
BEGIN
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
$function$;

CREATE OR REPLACE FUNCTION public.trg_scheduled_topup_health_sync()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF EXISTS (SELECT 1 FROM public.sim_lines WHERE id = OLD.sim_line_id) THEN
      UPDATE public.sim_lines SET updated_at = NOW() WHERE id = OLD.sim_line_id;
    END IF;
    RETURN OLD;
  ELSE
    IF EXISTS (SELECT 1 FROM public.sim_lines WHERE id = NEW.sim_line_id) THEN
      UPDATE public.sim_lines SET updated_at = NOW() WHERE id = NEW.sim_line_id;
    END IF;
    RETURN NEW;
  END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.trg_fn_notify_topup_result()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_phone  text;
  v_amount text;
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.status IS NOT DISTINCT FROM OLD.status THEN
    RETURN NEW;
  END IF;
  IF NEW.status NOT IN ('success', 'failed') THEN
    RETURN NEW;
  END IF;

  IF NEW.sim_line_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.sim_lines WHERE id = NEW.sim_line_id) THEN
    RETURN NEW;
  END IF;

  SELECT phone_number INTO v_phone FROM public.sim_lines WHERE id = NEW.sim_line_id;
  v_amount := to_char(COALESCE(NEW.amount, 0), 'FM99999990.00');

  IF NEW.status = 'success' THEN
    INSERT INTO public.notifications
      (user_id, category, title, body, action_url, sim_line_id, delivered_via, is_read)
    VALUES
      (NEW.user_id, 'top_up_success', 'Recharge successful',
       'Your recharge of $' || v_amount || ' for ' || COALESCE(v_phone, 'your line') || ' completed.',
       '/sim_lines/' || NEW.sim_line_id, NEW.sim_line_id, ARRAY['push']::text[], false);
  ELSE
    INSERT INTO public.notifications
      (user_id, category, title, body, action_url, sim_line_id, delivered_via, is_read)
    VALUES
      (NEW.user_id, 'top_up_failed', 'Recharge failed',
       'We could not complete your $' || v_amount || ' recharge for ' || COALESCE(v_phone, 'your line') || '. Please review your wallet and line.',
       '/sim_lines/' || NEW.sim_line_id, NEW.sim_line_id, ARRAY['push']::text[], false);
  END IF;

  RETURN NEW;
END;
$function$;
