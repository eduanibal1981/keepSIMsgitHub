-- Phase 2 Migration: Intent-Based Scheduling, Pricing, and Customer Authorization
-- Addresses F01, F02, F10, F11, F12, F13, F15, F18

-- 1. Extend scheduled_topups schema
ALTER TABLE public.scheduled_topups
  ADD COLUMN IF NOT EXISTS target_local_value NUMERIC,
  ADD COLUMN IF NOT EXISTS target_local_currency TEXT,
  ADD COLUMN IF NOT EXISTS max_authorized_usd NUMERIC,
  ADD COLUMN IF NOT EXISTS preferred_provider TEXT,
  ADD COLUMN IF NOT EXISTS engine_version INTEGER DEFAULT 2,
  ADD COLUMN IF NOT EXISTS intent_kind TEXT DEFAULT 'exact_airtime';

-- 2. Extend topup_executions schema
ALTER TABLE public.topup_executions
  ADD COLUMN IF NOT EXISTS target_local_value NUMERIC,
  ADD COLUMN IF NOT EXISTS target_local_currency TEXT,
  ADD COLUMN IF NOT EXISTS max_authorized_usd NUMERIC,
  ADD COLUMN IF NOT EXISTS quoted_cost_usd NUMERIC,
  ADD COLUMN IF NOT EXISTS quoted_fee_usd NUMERIC,
  ADD COLUMN IF NOT EXISTS quote_id UUID;

-- Update topup_executions status constraint to include awaiting_approval
ALTER TABLE public.topup_executions 
  DROP CONSTRAINT IF EXISTS topup_executions_status_check,
  ADD CONSTRAINT topup_executions_status_check 
    CHECK (status = ANY (ARRAY[
      'pending'::text, 
      'pending_payment'::text, 
      'awaiting_funds'::text, 
      'awaiting_approval'::text, 
      'processing'::text, 
      'routing'::text, 
      'success'::text, 
      'failed'::text, 
      'refunded'::text, 
      'cancelled'::text
    ]));

-- 3. Backfill existing custom schedule and execution for Omantel (F01/F02 intent baseline)
UPDATE public.scheduled_topups
SET target_local_value = 1.0,
    target_local_currency = 'OMR',
    preferred_provider = 'dtone',
    max_authorized_usd = amount,
    engine_version = 2,
    intent_kind = 'exact_airtime'
WHERE schedule_type = 'refill_custom' AND target_local_value IS NULL;

UPDATE public.topup_executions
SET target_local_value = 1.0,
    target_local_currency = 'OMR',
    max_authorized_usd = amount,
    quoted_cost_usd = base_cost_usd,
    quoted_fee_usd = app_fee_usd
WHERE execution_type = 'refill_custom' AND target_local_value IS NULL;

-- 4. Update trg_fn_sync_custom_refill_queue to forward intent and cap fields
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
     AND NEW.app_fee_usd IS NOT DISTINCT FROM OLD.app_fee_usd
     AND NEW.target_local_value IS NOT DISTINCT FROM OLD.target_local_value
     AND NEW.target_local_currency IS NOT DISTINCT FROM OLD.target_local_currency
     AND NEW.max_authorized_usd IS NOT DISTINCT FROM OLD.max_authorized_usd THEN
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
        AND t.target_local_value IS NOT DISTINCT FROM NEW.target_local_value
        AND t.target_local_currency IS NOT DISTINCT FROM NEW.target_local_currency
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
      payment_gateway_code, scheduled_topup_id, api_provider,
      target_local_value, target_local_currency, max_authorized_usd
    ) VALUES (
      NEW.sim_line_id, NEW.user_id, NEW.amount, COALESCE(NEW.base_cost_usd, NEW.amount), NEW.app_fee_usd,
      COALESCE(NEW.currency, 'USD'), 'pending',
      NEW.schedule_type, NEW.next_execution_at, NEW.offer_id, NEW.offer_value,
      'wallet', NEW.id, NEW.preferred_provider,
      NEW.target_local_value, NEW.target_local_currency, COALESCE(NEW.max_authorized_usd, NEW.amount)
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

-- 5. Create Authoritative Quoting RPC get_authoritative_refill_quote
CREATE OR REPLACE FUNCTION public.get_authoritative_refill_quote(
  p_sim_line_id uuid,
  p_target_value numeric,
  p_target_currency text,
  p_offer_id text DEFAULT NULL,
  p_preferred_provider text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_sim RECORD;
  v_offer RECORD;
  v_line_tier TEXT := 'free';
  v_entitlement JSONB;
  v_app_fee NUMERIC;
  v_total_usd NUMERIC;
  v_cost_usd NUMERIC;
  v_provider TEXT := p_preferred_provider;
BEGIN
  -- 1. Validate SIM line
  SELECT * INTO v_sim FROM public.sim_lines WHERE id = p_sim_line_id;
  IF v_sim.id IS NULL THEN
    RAISE EXCEPTION 'SIM line not found: %', p_sim_line_id;
  END IF;

  -- 2. Resolve entitlement & tier
  v_entitlement := public.resolve_line_entitlement(p_sim_line_id);
  v_line_tier := COALESCE(v_entitlement->>'effective_tier', 'free');

  -- 3. Match offer
  -- Case A: Explicit offer_id provided
  IF p_offer_id IS NOT NULL THEN
    SELECT * INTO v_offer
    FROM public.provider_offers_cache
    WHERE offer_id = p_offer_id
      AND (v_provider IS NULL OR api_provider = v_provider)
    LIMIT 1;

    IF v_offer.offer_id IS NULL THEN
      SELECT * INTO v_offer
      FROM public.provider_offers_cache
      WHERE offer_id = p_offer_id
      LIMIT 1;
    END IF;
  END IF;

  -- Case B: Match by destination benefit (airtime value & currency)
  IF v_offer.offer_id IS NULL THEN
    SELECT poc.* INTO v_offer
    FROM public.provider_offers_cache poc
    JOIN public.carrier_provider_map cpm 
      ON cpm.carrier_id = v_sim.carrier_id 
     AND cpm.provider = poc.api_provider 
     AND cpm.is_enabled = true
    WHERE poc.service_type = 'airtime'
      AND upper(poc.send_currency) = upper(p_target_currency)
      AND (
        (poc.price_type = 'FIXED' AND (poc.send_min = p_target_value OR poc.source_amount_native = p_target_value))
        OR (poc.price_type = 'RANGE' AND p_target_value BETWEEN poc.send_min AND poc.send_max)
      )
      AND (v_provider IS NULL OR poc.api_provider = v_provider)
    ORDER BY 
      CASE WHEN v_provider IS NOT NULL AND poc.api_provider = v_provider THEN 0 ELSE 1 END,
      cpm.is_primary DESC,
      cpm.priority ASC,
      poc.price_fixed_usd ASC
    LIMIT 1;
  END IF;

  IF v_offer.offer_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'No eligible provider offer found for ' || p_target_value || ' ' || p_target_currency
    );
  END IF;

  v_provider := v_offer.api_provider;
  v_cost_usd := COALESCE(v_offer.price_fixed_usd, v_offer.price_min_usd, 0.0);

  -- 4. Calculate fee using published tier rules
  v_app_fee := public.resolve_app_fee('refills', v_line_tier, v_cost_usd);
  IF v_app_fee IS NULL OR v_app_fee = 0 THEN
    v_app_fee := round(greatest(v_cost_usd * 0.03, 0.03), 2);
  END IF;

  v_total_usd := round(v_cost_usd + v_app_fee, 2);

  RETURN jsonb_build_object(
    'success', true,
    'provider', v_provider,
    'offer_id', v_offer.offer_id,
    'offer_name', v_offer.offer_name,
    'price_type', v_offer.price_type,
    'target_local_value', p_target_value,
    'target_local_currency', upper(p_target_currency),
    'wholesale_cost_usd', v_cost_usd,
    'pricing_tier', v_line_tier,
    'fee_rule_version', 1,
    'customer_fee_usd', v_app_fee,
    'total_charge_usd', v_total_usd,
    'max_authorized_usd', v_total_usd,
    'expected_margin_usd', v_app_fee,
    'is_profitable', (v_total_usd >= v_cost_usd),
    'quote_created_at', now()
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.get_authoritative_refill_quote FROM public, anon;
GRANT EXECUTE ON FUNCTION public.get_authoritative_refill_quote TO authenticated, service_role;
