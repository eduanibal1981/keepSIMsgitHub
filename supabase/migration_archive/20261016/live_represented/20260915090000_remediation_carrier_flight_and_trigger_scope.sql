-- ==============================================================================
-- Migration: 20260915090000_remediation_carrier_flight_and_trigger_scope.sql
-- Description: Adds carrier_in_flight column to topup_executions (S1),
--              restores schedule_type guard in trg_fn_sync_custom_refill_queue (S3),
--              and hardens reap_stuck_executions for in-flight tracking (S4).
-- ==============================================================================

-- 1. Add carrier_in_flight column to topup_executions (S1)
ALTER TABLE public.topup_executions
  ADD COLUMN IF NOT EXISTS carrier_in_flight BOOLEAN NOT NULL DEFAULT FALSE;

-- 2. Restore schedule_type guard to trg_fn_sync_custom_refill_queue (S3)
CREATE OR REPLACE FUNCTION public.trg_fn_sync_custom_refill_queue()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  -- Only process custom and mini automated refills; ignore reminders (notify)
  IF NEW.schedule_type NOT IN ('refill_custom', 'refill_mini') THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE'
     AND NEW.amount IS NOT DISTINCT FROM OLD.amount
     AND NEW.next_execution_at IS NOT DISTINCT FROM OLD.next_execution_at
     AND NEW.is_active IS NOT DISTINCT FROM OLD.is_active
     AND NEW.offer_id IS NOT DISTINCT FROM OLD.offer_id
     AND NEW.offer_value IS NOT DISTINCT FROM OLD.offer_value
     AND NEW.base_cost_usd IS NOT DISTINCT FROM OLD.base_cost_usd
     AND NEW.app_fee_usd IS NOT DISTINCT FROM OLD.app_fee_usd
     AND NEW.target_local_value IS NOT DISTINCT FROM OLD.target_local_value
     AND NEW.target_local_currency IS NOT DISTINCT FROM OLD.target_local_currency
     AND NEW.max_authorized_usd IS NOT DISTINCT FROM OLD.max_authorized_usd
     AND NEW.engine_version IS NOT DISTINCT FROM OLD.engine_version
     AND NEW.intent_kind IS NOT DISTINCT FROM OLD.intent_kind
     AND NEW.preferred_provider IS NOT DISTINCT FROM OLD.preferred_provider THEN
    RETURN NEW;
  END IF;

  IF COALESCE(NEW.is_active, false) THEN
    -- Check if identical pending execution already exists with matching cap and intent
    IF EXISTS (
      SELECT 1 FROM public.topup_executions t
      WHERE t.scheduled_topup_id = NEW.id
        AND t.status = 'pending'
        AND t.execution_time = NEW.next_execution_at
        AND t.amount = NEW.amount
        AND t.offer_id IS NOT DISTINCT FROM NEW.offer_id
        AND t.offer_value IS NOT DISTINCT FROM NEW.offer_value
        AND t.base_cost_usd IS NOT DISTINCT FROM COALESCE(NEW.base_cost_usd, NEW.amount)
        AND t.target_local_value IS NOT DISTINCT FROM NEW.target_local_value
        AND t.target_local_currency IS NOT DISTINCT FROM NEW.target_local_currency
        AND t.max_authorized_usd IS NOT DISTINCT FROM COALESCE(NEW.max_authorized_usd, NEW.amount)
        AND t.api_provider IS NOT DISTINCT FROM NEW.preferred_provider
        AND t.engine_version IS NOT DISTINCT FROM COALESCE(NEW.engine_version, 2)
        AND t.intent_kind IS NOT DISTINCT FROM COALESCE(NEW.intent_kind, 'exact_airtime')
    ) THEN
      RETURN NEW;
    END IF;

    -- Cancel existing unsubmitted executions across all waiting states
    UPDATE public.topup_executions
    SET status = 'cancelled', completed_at = now()
    WHERE scheduled_topup_id = NEW.id
      AND status IN ('pending', 'pending_payment', 'awaiting_approval', 'awaiting_funds');

    INSERT INTO public.topup_executions (
      sim_line_id, user_id, amount, base_cost_usd, app_fee_usd, currency, status,
      execution_type, execution_time, offer_id, offer_value,
      payment_gateway_code, scheduled_topup_id, api_provider,
      target_local_value, target_local_currency, max_authorized_usd,
      engine_version, intent_kind, attempted_providers, carrier_in_flight
    ) VALUES (
      NEW.sim_line_id, NEW.user_id, NEW.amount, COALESCE(NEW.base_cost_usd, NEW.amount), NEW.app_fee_usd,
      COALESCE(NEW.currency, 'USD'), 'pending',
      NEW.schedule_type, NEW.next_execution_at, NEW.offer_id, NEW.offer_value,
      'wallet', NEW.id, NEW.preferred_provider,
      NEW.target_local_value, NEW.target_local_currency, COALESCE(NEW.max_authorized_usd, NEW.amount),
      COALESCE(NEW.engine_version, 2), COALESCE(NEW.intent_kind, 'exact_airtime'),
      ARRAY[]::text[], FALSE
    );
  ELSE
    -- Schedule paused or deactivated: cancel unsubmitted executions across all waiting states
    UPDATE public.topup_executions
    SET status = 'cancelled', completed_at = now()
    WHERE scheduled_topup_id = NEW.id
      AND status IN ('pending', 'pending_payment', 'awaiting_approval', 'awaiting_funds');
  END IF;

  RETURN NEW;
END;
$function$;

-- 3. Harden reap_stuck_executions for unified in-flight detection (S4)
DROP FUNCTION IF EXISTS public.reap_stuck_executions(integer, integer);

CREATE OR REPLACE FUNCTION public.reap_stuck_executions(
  p_stuck_after_minutes integer DEFAULT 10,
  p_max_retries integer DEFAULT 3
)
RETURNS TABLE(requeued integer, dead_lettered integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_requeued integer := 0;
  v_dead integer := 0;
  v_in_flight_count integer := 0;
BEGIN
  -- 1. Identify stuck processing executions
  -- Distinguish between safe-to-requeue (pre-submission) and in-flight/ambiguous (post-submission)
  WITH stuck_all AS (
    SELECT t.id, t.reaper_retries, COALESCE(t.pre_processing_status, 'pending') AS back_to,
           t.reloadly_transaction_id,
           (COALESCE(h.carrier_in_flight, false) OR COALESCE(t.carrier_in_flight, false)) AS carrier_in_flight
    FROM public.topup_executions t
    LEFT JOIN public.wallet_holds h ON h.id = t.wallet_hold_id
    WHERE t.status = 'processing'
      AND COALESCE(t.processing_since, t.created_at) < now() - make_interval(mins => p_stuck_after_minutes)
    FOR UPDATE OF t SKIP LOCKED
  ),
  -- In-flight / ambiguous submissions: MUST NOT be requeued to pending (F06 double-purchase prevention)
  in_flight_flagged AS (
    UPDATE public.topup_executions t
    SET status = 'failed',
        carrier_in_flight = true,
        failure_reason = 'Stuck in processing with in-flight carrier submission. Dead-lettered for manual reconciliation to prevent duplicate purchase.',
        completed_at = now()
    FROM stuck_all s
    WHERE t.id = s.id
      AND (s.reloadly_transaction_id IS NOT NULL OR s.carrier_in_flight)
    RETURNING t.id
  ),
  -- Dead-letter pre-submission executions that have exhausted retries
  dead AS (
    UPDATE public.topup_executions t
    SET status = 'failed',
        failure_reason = 'Dead-lettered by reaper: repeatedly stuck in processing before provider submission (worker crash?)',
        completed_at = now()
    FROM stuck_all s
    WHERE t.id = s.id
      AND s.reloadly_transaction_id IS NULL
      AND NOT s.carrier_in_flight
      AND s.reaper_retries >= p_max_retries
    RETURNING t.id
  ),
  -- Safe to requeue: pre-submission executions with retries remaining
  requeue AS (
    UPDATE public.topup_executions t
    SET status = s.back_to,
        reaper_retries = t.reaper_retries + 1,
        processing_since = NULL
    FROM stuck_all s
    WHERE t.id = s.id
      AND s.reloadly_transaction_id IS NULL
      AND NOT s.carrier_in_flight
      AND s.reaper_retries < p_max_retries
    RETURNING t.id
  )
  SELECT 
    (SELECT count(*) FROM requeue),
    (SELECT count(*) FROM dead) + (SELECT count(*) FROM in_flight_flagged),
    (SELECT count(*) FROM in_flight_flagged)
  INTO v_requeued, v_dead, v_in_flight_count;

  IF v_in_flight_count > 0 THEN
    INSERT INTO public.system_alerts (kind, message, details)
    VALUES (
      'in_flight_execution_stuck',
      v_in_flight_count || ' execution(s) were stuck in processing with in-flight submissions and dead-lettered to prevent duplicate purchases.',
      jsonb_build_object('in_flight_count', v_in_flight_count, 'stuck_after_minutes', p_stuck_after_minutes)
    );
  END IF;

  IF (v_dead - v_in_flight_count) > 0 THEN
    INSERT INTO public.system_alerts (kind, message, details)
    VALUES (
      'execution_dead_lettered',
      (v_dead - v_in_flight_count) || ' execution(s) dead-lettered after repeatedly getting stuck in processing.',
      jsonb_build_object('dead_lettered', v_dead - v_in_flight_count, 'requeued', v_requeued)
    );
  END IF;

  RETURN QUERY SELECT v_requeued, v_dead;
END;
$$;
