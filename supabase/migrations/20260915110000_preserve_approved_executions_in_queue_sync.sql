-- Migration: 20260915110000_preserve_approved_executions_in_queue_sync.sql
-- Description: Updates trg_fn_sync_custom_refill_queue so that cap-only updates (from approve_refill_execution)
-- do not cancel and reschedule executions, and currently due executions (execution_time <= now()) are preserved.

CREATE OR REPLACE FUNCTION public.trg_fn_sync_custom_refill_queue()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  -- Only process custom and mini automated refills; ignore reminders (notify)
  IF NEW.schedule_type NOT IN ('refill_custom', 'refill_mini') THEN
    RETURN NEW;
  END IF;

  -- 1. No-op check: if nothing changed at all, exit immediately
  IF TG_OP = 'UPDATE'
     AND NEW.amount IS NOT DISTINCT FROM OLD.amount
     AND NEW.currency IS NOT DISTINCT FROM OLD.currency
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

  -- 2. Cap-only update: if ONLY max_authorized_usd changed (e.g. from approve_refill_execution),
  -- update pending executions in-place without cancelling or rescheduling them.
  IF TG_OP = 'UPDATE'
     AND NEW.amount IS NOT DISTINCT FROM OLD.amount
     AND NEW.currency IS NOT DISTINCT FROM OLD.currency
     AND NEW.next_execution_at IS NOT DISTINCT FROM OLD.next_execution_at
     AND NEW.is_active IS NOT DISTINCT FROM OLD.is_active
     AND NEW.offer_id IS NOT DISTINCT FROM OLD.offer_id
     AND NEW.offer_value IS NOT DISTINCT FROM OLD.offer_value
     AND NEW.base_cost_usd IS NOT DISTINCT FROM OLD.base_cost_usd
     AND NEW.app_fee_usd IS NOT DISTINCT FROM OLD.app_fee_usd
     AND NEW.target_local_value IS NOT DISTINCT FROM OLD.target_local_value
     AND NEW.target_local_currency IS NOT DISTINCT FROM OLD.target_local_currency
     AND NEW.engine_version IS NOT DISTINCT FROM OLD.engine_version
     AND NEW.intent_kind IS NOT DISTINCT FROM OLD.intent_kind
     AND NEW.preferred_provider IS NOT DISTINCT FROM OLD.preferred_provider
     AND NEW.max_authorized_usd IS DISTINCT FROM OLD.max_authorized_usd THEN
    UPDATE public.topup_executions
    SET max_authorized_usd = NEW.max_authorized_usd,
        updated_at = now()
    WHERE scheduled_topup_id = NEW.id
      AND status IN ('pending', 'pending_payment', 'awaiting_approval', 'awaiting_funds');
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

    -- Cancel existing future unsubmitted executions (preserve any execution currently due or approved for now)
    UPDATE public.topup_executions
    SET status = 'cancelled', completed_at = now()
    WHERE scheduled_topup_id = NEW.id
      AND status IN ('pending', 'pending_payment', 'awaiting_approval', 'awaiting_funds')
      AND execution_time > now();

    -- Only insert a new execution if one for next_execution_at does not already exist
    IF NOT EXISTS (
      SELECT 1 FROM public.topup_executions t
      WHERE t.scheduled_topup_id = NEW.id
        AND t.status = 'pending'
        AND t.execution_time = NEW.next_execution_at
    ) THEN
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
    END IF;
  ELSE
    -- Schedule paused or deactivated: cancel unsubmitted executions across all waiting states
    UPDATE public.topup_executions
    SET status = 'cancelled', completed_at = now()
    WHERE scheduled_topup_id = NEW.id
      AND status IN ('pending', 'pending_payment', 'awaiting_approval', 'awaiting_funds');
  END IF;

  RETURN NEW;
END;
$$;
