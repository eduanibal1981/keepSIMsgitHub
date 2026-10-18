-- =============================================================================
-- Migration: 20260914030000_tier_aware_scheduled_refill_pricing.sql
-- Description:
--   1. Add base_cost_usd, app_fee_usd, pricing_tier, fee_rule_version to scheduled_topups
--   2. Purge legacy test schedules (frequency_days = 0) and enforce positive frequency
--   3. Update trg_fn_sync_custom_refill_queue to preserve separate base_cost_usd and app_fee_usd
--   4. Backfill existing custom refill schedules
-- =============================================================================

-- 1. ADD PRICING COLUMNS TO scheduled_topups
ALTER TABLE public.scheduled_topups
  ADD COLUMN IF NOT EXISTS base_cost_usd NUMERIC(18,6),
  ADD COLUMN IF NOT EXISTS app_fee_usd NUMERIC(18,6),
  ADD COLUMN IF NOT EXISTS pricing_tier TEXT,
  ADD COLUMN IF NOT EXISTS fee_rule_version INT;

-- 2. HARD DELETE LEGACY 0-FREQUENCY TEST SCHEDULES AND CANCEL PENDING EXECUTIONS
UPDATE public.topup_executions
SET status = 'cancelled', completed_at = now()
WHERE scheduled_topup_id IN (
  SELECT id FROM public.scheduled_topups WHERE frequency_days = 0
) AND status IN ('pending', 'pending_payment');

DELETE FROM public.scheduled_topups WHERE frequency_days = 0;

-- Enforce valid production frequency constraint
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'ck_scheduled_topups_frequency'
  ) THEN
    ALTER TABLE public.scheduled_topups
      ADD CONSTRAINT ck_scheduled_topups_frequency
      CHECK (frequency_days BETWEEN 1 AND 365);
  END IF;
END $$;

-- 3. UPDATE trg_fn_sync_custom_refill_queue TO PRESERVE SEPARATE BASE COST & APP FEE
CREATE OR REPLACE FUNCTION public.trg_fn_sync_custom_refill_queue()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  -- Handle both user-defined custom refills and system keep-alive mini refills
  IF NEW.schedule_type NOT IN ('refill_custom', 'refill_mini') THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE'
     AND NEW.amount IS NOT DISTINCT FROM OLD.amount
     AND NEW.currency IS NOT DISTINCT FROM OLD.currency
     AND NEW.next_execution_at IS NOT DISTINCT FROM OLD.next_execution_at
     AND NEW.is_active IS NOT DISTINCT FROM OLD.is_active
     AND NEW.offer_id IS NOT DISTINCT FROM OLD.offer_id
     AND NEW.offer_value IS NOT DISTINCT FROM OLD.offer_value
     AND NEW.base_cost_usd IS NOT DISTINCT FROM OLD.base_cost_usd
     AND NEW.app_fee_usd IS NOT DISTINCT FROM OLD.app_fee_usd THEN
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
        AND t.offer_value IS NOT DISTINCT FROM NEW.offer_value
        AND t.base_cost_usd IS NOT DISTINCT FROM COALESCE(NEW.base_cost_usd, NEW.amount)
    ) THEN
      RETURN NEW;
    END IF;

    UPDATE public.topup_executions
    SET status = 'cancelled', completed_at = now()
    WHERE scheduled_topup_id = NEW.id
      AND status IN ('pending', 'pending_payment');

    INSERT INTO public.topup_executions (
      sim_line_id, user_id, amount, base_cost_usd, app_fee_usd, currency, status,
      execution_type, execution_time, offer_id, offer_value,
      payment_gateway_code, scheduled_topup_id
    ) VALUES (
      NEW.sim_line_id, NEW.user_id, NEW.amount, COALESCE(NEW.base_cost_usd, NEW.amount), NEW.app_fee_usd,
      COALESCE(NEW.currency, 'USD'), 'pending',
      NEW.schedule_type, NEW.next_execution_at, NEW.offer_id, NEW.offer_value,
      'wallet', NEW.id
    );
  ELSE
    UPDATE public.topup_executions
    SET status = 'cancelled', completed_at = now()
    WHERE scheduled_topup_id = NEW.id
      AND status IN ('pending', 'pending_payment');
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.trg_fn_sync_custom_refill_queue() FROM PUBLIC, anon, authenticated;

-- 4. BACKFILL EXISTING SCHEDULES
UPDATE public.scheduled_topups s
SET
  base_cost_usd = COALESCE(s.base_cost_usd, s.amount),
  app_fee_usd = COALESCE(s.app_fee_usd, 0.00),
  pricing_tier = COALESCE(s.pricing_tier, 'free')
WHERE s.schedule_type IN ('refill_custom', 'refill_mini')
  AND (s.base_cost_usd IS NULL OR s.app_fee_usd IS NULL);
