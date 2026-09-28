-- ==============================================================================
-- Migration: 20260915060000_phase3_scheduling_and_cross_flow_coordination.sql
-- Description: Phase 3 - Single occurrence creation, cross-flow mini/custom
--              coordination, concurrency serialization in claim_due_executions,
--              and wallet credit auto-resume for awaiting_funds executions.
-- ==============================================================================

-- 1. Refactor update_sim_line_last_topup_at
-- Removes raw INSERT into topup_executions (eliminating duplicate queue entries and stale cycle chaining).
-- Advances scheduled_topups dates so trg_fn_sync_custom_refill_queue acts as single authoritative creator.
-- Performs cross-flow coordination: pushes linked refill_mini due date forward when custom/manual recharge succeeds.
CREATE OR REPLACE FUNCTION public.update_sim_line_last_topup_at()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_freq INTEGER;
    v_mini_freq INTEGER;
BEGIN
    IF NEW.status = 'success' AND (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'success') THEN
        -- 1. Update sim_lines last_topup_at
        UPDATE public.sim_lines
        SET last_topup_at = COALESCE(NEW.completed_at, now()),
            updated_at = now()
        WHERE id = NEW.sim_line_id;
        
        -- 2. Advance parent schedule (trg_fn_sync_custom_refill_queue creates the next clean pending occurrence)
        IF NEW.execution_type IN ('refill_custom', 'refill_mini') AND NEW.scheduled_topup_id IS NOT NULL THEN
            SELECT frequency_days INTO v_freq 
            FROM public.scheduled_topups 
            WHERE id = NEW.scheduled_topup_id 
            AND is_active = true;
            
            IF v_freq IS NOT NULL AND v_freq > 0 THEN
                UPDATE public.scheduled_topups
                SET next_execution_at = COALESCE(NEW.completed_at, now()) + (v_freq || ' days')::interval,
                    last_execution_at = COALESCE(NEW.completed_at, now()),
                    updated_at = now()
                WHERE id = NEW.scheduled_topup_id;
            END IF;
        END IF;

        -- 3. Cross-Flow Protection Coordination:
        -- If this recharge was a custom refill, instant refill, or manual topup,
        -- it successfully extended line validity. If this line has an active refill_mini
        -- schedule, push its next_execution_at out by its frequency window so the customer
        -- is not prematurely billed for an unneeded mini keep-alive refill.
        IF NEW.execution_type IN ('refill_custom', 'refill_instant', 'manual') OR NEW.execution_type IS NULL THEN
            SELECT frequency_days INTO v_mini_freq
            FROM public.scheduled_topups
            WHERE sim_line_id = NEW.sim_line_id
              AND schedule_type = 'refill_mini'
              AND is_active = true
            LIMIT 1;

            IF v_mini_freq IS NOT NULL AND v_mini_freq > 0 THEN
                UPDATE public.scheduled_topups
                SET next_execution_at = COALESCE(NEW.completed_at, now()) + (v_mini_freq || ' days')::interval,
                    updated_at = now()
                WHERE sim_line_id = NEW.sim_line_id
                  AND schedule_type = 'refill_mini'
                  AND is_active = true;
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$function$;

-- 2. Harden claim_due_executions with Concurrency Serialization
-- Ensures that no execution for a SIM line is claimed if another execution for that line is currently 'processing'.
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
      -- Concurrency serialization: do not claim if another execution for this SIM line is currently processing
      AND NOT EXISTS (
        SELECT 1 FROM public.topup_executions p
        WHERE p.sim_line_id = t.sim_line_id
          AND p.id <> t.id
          AND p.status = 'processing'
      )
    ORDER BY t.execution_time ASC
    LIMIT p_limit
    FOR UPDATE SKIP LOCKED
  )
  RETURNING *;
END;
$$;

-- 3. Wallet Credit Auto-Recovery for awaiting_funds Executions
CREATE OR REPLACE FUNCTION public.trg_fn_resume_awaiting_funds()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF NEW.type IN ('credit', 'deposit', 'refund', 'gift_received', 'referral_credit', 'manual_credit') AND NEW.amount > 0 THEN
    UPDATE public.topup_executions
    SET status = 'pending',
        execution_time = NOW(),
        failure_reason = NULL,
        updated_at = NOW()
    WHERE user_id = NEW.user_id
      AND status = 'awaiting_funds';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_resume_awaiting_funds ON public.wallet_transactions;
CREATE TRIGGER trg_resume_awaiting_funds
AFTER INSERT ON public.wallet_transactions
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_resume_awaiting_funds();

CREATE OR REPLACE FUNCTION public.resume_awaiting_funds_executions(p_user_id UUID)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_resumed integer := 0;
BEGIN
  WITH updated AS (
    UPDATE public.topup_executions
    SET status = 'pending',
        execution_time = NOW(),
        failure_reason = NULL,
        updated_at = NOW()
    WHERE user_id = p_user_id
      AND status = 'awaiting_funds'
    RETURNING id
  )
  SELECT count(*) INTO v_resumed FROM updated;

  RETURN v_resumed;
END;
$$;

GRANT EXECUTE ON FUNCTION public.resume_awaiting_funds_executions(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.resume_awaiting_funds_executions(UUID) TO service_role;

-- 4. Update queue_premium_refill_executions to stamp intent fields
CREATE OR REPLACE FUNCTION public.queue_premium_refill_executions(
  p_sim_line_id uuid,
  p_scheduled_topup_id uuid,
  p_plan_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone,
  p_start_at timestamp with time zone DEFAULT now()
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_line RECORD; v_rule RECORD; v_offer RECORD; v_qualifying numeric;
  v_expires timestamptz; v_t timestamptz; v_count integer := 0; v_role text; v_step integer;
BEGIN
  SELECT sl.user_id, sl.carrier_id, sl.carrier_rule_id, sl.plan_expires_at INTO v_line
  FROM public.sim_lines sl
  WHERE sl.id = p_sim_line_id
    AND (auth.uid() IS NULL OR sl.user_id = auth.uid()
         OR EXISTS (SELECT 1 FROM public.household_members hm
                    WHERE hm.owner_id = sl.user_id AND hm.member_id = auth.uid()
                      AND hm.invite_status = 'accepted' AND hm.role = 'manager'));
  IF NOT FOUND THEN RAISE EXCEPTION 'Not authorized to schedule refills for this SIM line'; END IF;

  BEGIN v_role := current_setting('request.jwt.claims', true)::json ->> 'role';
  EXCEPTION WHEN OTHERS THEN v_role := NULL; END;

  IF v_role IS DISTINCT FROM 'service_role' THEN
    IF NOT public.has_paid_premium_entitlement(p_sim_line_id) THEN
      RAISE EXCEPTION 'This line has no paid, unexpired premium plan, so pre-paid refills cannot be queued.'
        USING ERRCODE = 'KS403';
    END IF;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.scheduled_topups st
                  WHERE st.id = p_scheduled_topup_id AND st.sim_line_id = p_sim_line_id
                    AND st.schedule_type = 'refill_mini') THEN
    RAISE EXCEPTION 'Schedule does not belong to this SIM line';
  END IF;

  SELECT cr.inactivity_limit_days, cr.refill_interval_days_override,
         cr.minimum_topup_amount, cr.activity_requirement, cr.validity_qualifying_topup_amount
  INTO v_rule FROM public.carrier_rules cr
  WHERE cr.id = COALESCE(v_line.carrier_rule_id,
                 (SELECT cr2.id FROM public.carrier_rules cr2
                   WHERE cr2.carrier_id = v_line.carrier_id ORDER BY cr2.created_at DESC LIMIT 1));

  IF NOT FOUND OR v_rule.minimum_topup_amount IS NULL OR v_rule.minimum_topup_amount <= 0 THEN
    RAISE EXCEPTION 'No carrier rule with a top-up price exists for this SIM line';
  END IF;

  IF v_rule.activity_requirement = 'usage_required' THEN
    RAISE EXCEPTION 'This carrier only resets its inactivity clock on an outgoing call, SMS or data session, so automated refills cannot keep the line active.'
      USING ERRCODE = 'KS422';
  END IF;

  IF v_rule.activity_requirement = 'min_denomination'
     AND v_rule.validity_qualifying_topup_amount IS NOT NULL
     AND v_rule.minimum_topup_amount < v_rule.validity_qualifying_topup_amount THEN
    RAISE EXCEPTION 'Carrier rule refills % but this carrier only grants line validity from %',
      v_rule.minimum_topup_amount, v_rule.validity_qualifying_topup_amount USING ERRCODE = 'KS422';
  END IF;

  v_step := public.refill_interval_days(v_rule.inactivity_limit_days, v_rule.refill_interval_days_override);
  IF v_step IS NULL OR v_step < 1 THEN RAISE EXCEPTION 'Carrier rule has no usable deactivation window'; END IF;

  v_qualifying := COALESCE(v_rule.validity_qualifying_topup_amount, v_rule.minimum_topup_amount);

  SELECT * INTO v_offer FROM public.carrier_refill_offer(v_line.carrier_id, v_qualifying);
  IF v_offer.offer_code IS NULL THEN
    RAISE EXCEPTION 'No supplier currently sells a top-up for this carrier that reaches the % USD its validity rules require.',
      to_char(v_qualifying, 'FM999990.00') USING ERRCODE = 'KS422';
  END IF;

  v_expires := COALESCE(v_line.plan_expires_at, p_start_at + interval '365 days');
  IF p_plan_expires_at IS NOT NULL AND p_plan_expires_at < v_expires THEN v_expires := p_plan_expires_at; END IF;
  IF v_expires > p_start_at + interval '370 days' THEN v_expires := p_start_at + interval '370 days'; END IF;

  UPDATE public.topup_executions SET status = 'cancelled', completed_at = now()
   WHERE scheduled_topup_id = p_scheduled_topup_id AND status IN ('pending', 'pending_payment');

  v_t := p_start_at;
  WHILE v_t < v_expires AND v_count < 400 LOOP
    INSERT INTO public.topup_executions (
      sim_line_id, user_id, amount, base_cost_usd, currency, status,
      execution_type, execution_time, offer_id, offer_value,
      payment_gateway_code, scheduled_topup_id, api_provider,
      max_authorized_usd, engine_version, intent_kind
    ) VALUES (
      p_sim_line_id, v_line.user_id, v_offer.price_usd, v_offer.price_usd, 'USD', 'pending',
      'refill_mini', v_t, v_offer.offer_code,
      CASE WHEN v_offer.offer_value IS NULL THEN NULL ELSE v_offer.offer_value::bigint END,
      NULL, p_scheduled_topup_id, v_offer.provider_code,
      v_offer.price_usd, 2, 'exact_airtime'
    );
    v_count := v_count + 1;
    v_t := v_t + (v_step || ' days')::interval;
  END LOOP;

  RETURN v_count;
END;
$function$;

-- 5. Keep trg_fn_sync_custom_refill_queue in sync with engine_version and intent_kind
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
     AND NEW.max_authorized_usd IS NOT DISTINCT FROM OLD.max_authorized_usd
     AND NEW.engine_version IS NOT DISTINCT FROM OLD.engine_version
     AND NEW.intent_kind IS NOT DISTINCT FROM OLD.intent_kind
     AND NEW.preferred_provider IS NOT DISTINCT FROM OLD.preferred_provider THEN
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
      target_local_value, target_local_currency, max_authorized_usd,
      engine_version, intent_kind
    ) VALUES (
      NEW.sim_line_id, NEW.user_id, NEW.amount, COALESCE(NEW.base_cost_usd, NEW.amount), NEW.app_fee_usd,
      COALESCE(NEW.currency, 'USD'), 'pending',
      NEW.schedule_type, NEW.next_execution_at, NEW.offer_id, NEW.offer_value,
      'wallet', NEW.id, NEW.preferred_provider,
      NEW.target_local_value, NEW.target_local_currency, COALESCE(NEW.max_authorized_usd, NEW.amount),
      COALESCE(NEW.engine_version, 2), COALESCE(NEW.intent_kind, 'exact_airtime')
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

