-- ==============================================================================
-- Migration: 20260915080000_remediation_security_and_concurrency.sql
-- Description: Security hardening, concurrency serialization, and trigger fixes
--              addressing review findings R1, R3, R9, R10.
-- ==============================================================================

-- 1. Secure approve_refill_execution (R1)
--    - Enforce authentication and ownership/household manager authorization
--    - Validate finite positive authorization limit
--    - Revoke PUBLIC and anon permissions
CREATE OR REPLACE FUNCTION public.approve_refill_execution(
  p_execution_id UUID,
  p_new_max_authorized_usd NUMERIC DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_exec RECORD;
  v_new_cap NUMERIC;
BEGIN
  -- 1. Authentication check
  IF auth.uid() IS NULL AND current_user <> 'service_role' AND session_user <> 'postgres' THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT * INTO v_exec
  FROM public.topup_executions
  WHERE id = p_execution_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Execution % not found', p_execution_id;
  END IF;

  -- 2. Authorization check: must be execution owner, SIM line owner, or accepted household manager
  IF auth.uid() IS NOT NULL AND auth.uid() <> v_exec.user_id THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.sim_lines sl
      WHERE sl.id = v_exec.sim_line_id
        AND (sl.user_id = auth.uid()
             OR EXISTS (SELECT 1 FROM public.household_members hm
                        WHERE hm.owner_id = sl.user_id
                          AND hm.member_id = auth.uid()
                          AND hm.invite_status = 'accepted'
                          AND hm.role = 'manager'))
    ) THEN
      RAISE EXCEPTION 'Not authorized to approve execution %', p_execution_id;
    END IF;
  END IF;

  -- 3. Status transition check
  IF v_exec.status <> 'awaiting_approval' THEN
    RAISE EXCEPTION 'Execution % is in status %, expected awaiting_approval', p_execution_id, v_exec.status;
  END IF;

  -- Determine new cap: defaults to quoted amount on execution if not specified
  v_new_cap := COALESCE(p_new_max_authorized_usd, v_exec.amount);

  -- 4. Limit validation: must be positive and within safety bounds
  IF v_new_cap IS NULL OR v_new_cap <= 0 OR v_new_cap > 1000 THEN
    RAISE EXCEPTION 'Invalid authorization limit: % (must be between 0.01 and 1000.00 USD)', v_new_cap;
  END IF;

  -- Transition execution back to pending with updated cap
  UPDATE public.topup_executions
  SET max_authorized_usd = v_new_cap,
      status = 'pending',
      failure_reason = NULL,
      execution_time = NOW(),
      updated_at = NOW()
  WHERE id = p_execution_id;

  -- If tied to a scheduled topup, update schedule's max_authorized_usd as well
  IF v_exec.scheduled_topup_id IS NOT NULL THEN
    UPDATE public.scheduled_topups
    SET max_authorized_usd = v_new_cap,
        updated_at = NOW()
    WHERE id = v_exec.scheduled_topup_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'execution_id', p_execution_id,
    'new_max_authorized_usd', v_new_cap,
    'status', 'pending'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.approve_refill_execution(UUID, NUMERIC) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.approve_refill_execution(UUID, NUMERIC) FROM anon;
GRANT EXECUTE ON FUNCTION public.approve_refill_execution(UUID, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_refill_execution(UUID, NUMERIC) TO service_role;

-- 2. Secure resume_awaiting_funds_executions (R1)
--    - Enforce authentication and ownership/household manager authorization
--    - Revoke PUBLIC and anon permissions
CREATE OR REPLACE FUNCTION public.resume_awaiting_funds_executions(p_user_id UUID)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_resumed integer := 0;
BEGIN
  -- Authentication check
  IF auth.uid() IS NULL AND current_user <> 'service_role' AND session_user <> 'postgres' THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  -- Authorization check
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_id THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.household_members hm
      WHERE hm.owner_id = p_user_id
        AND hm.member_id = auth.uid()
        AND hm.invite_status = 'accepted'
        AND hm.role = 'manager'
    ) THEN
      RAISE EXCEPTION 'Not authorized to resume executions for user %', p_user_id;
    END IF;
  END IF;

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

REVOKE ALL ON FUNCTION public.resume_awaiting_funds_executions(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.resume_awaiting_funds_executions(UUID) FROM anon;
GRANT EXECUTE ON FUNCTION public.resume_awaiting_funds_executions(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.resume_awaiting_funds_executions(UUID) TO service_role;

-- 3. Fix route_topup_execution trigger (R3)
--    - Initialize attempted_providers as empty array ARRAY[]::text[], NOT pre-populated with api_provider
CREATE OR REPLACE FUNCTION public.route_topup_execution()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE 
  v_gateway VARCHAR; 
  v_api_provider text;
BEGIN
  IF NEW.status IN ('pending', 'pending_payment', 'routing') THEN
    -- Priority 1: If offer_id is set and api_provider is not set, resolve from offer catalog cache
    IF NEW.api_provider IS NULL AND NEW.offer_id IS NOT NULL THEN
      SELECT api_provider INTO v_api_provider
      FROM public.provider_offers_cache
      WHERE offer_id = NEW.offer_id
      LIMIT 1;

      IF v_api_provider IS NULL THEN
        SELECT provider_code INTO v_api_provider
        FROM public.provider_offers
        WHERE offer_code = NEW.offer_id
        LIMIT 1;
      END IF;
    END IF;

    -- Priority 2: Carrier's primary provider from carrier_provider_map
    IF v_api_provider IS NULL THEN
      SELECT m.provider INTO v_api_provider
      FROM public.sim_lines sl
      JOIN public.carriers ca ON sl.carrier_id = ca.id
      LEFT JOIN public.carrier_provider_map m ON m.carrier_id = ca.id AND m.is_primary
      WHERE sl.id = NEW.sim_line_id;
    END IF;

    -- Resolve fulfillment gateway
    SELECT ca.fulfillment_gateway INTO v_gateway
    FROM public.sim_lines sl
    JOIN public.carriers ca ON sl.carrier_id = ca.id
    WHERE sl.id = NEW.sim_line_id;

    IF NEW.fulfillment_gateway IS NULL THEN
      IF v_gateway IS NULL THEN
        SELECT config_value INTO v_gateway FROM public.system_configs
         WHERE config_key = 'ACTIVE_FULFILLMENT_METHOD' LIMIT 1;
        IF v_gateway IS NULL THEN v_gateway := 'MANUAL'; END IF;
      END IF;

      IF v_gateway = 'TASKER_SCRIPT' AND NEW.execution_type = 'refill_instant' THEN 
        v_gateway := 'API'; 
      END IF;

      IF v_gateway = 'TASKER_SCRIPT' AND NOT EXISTS (
        SELECT 1 FROM public.sim_lines sl2
        JOIN public.refill_scripts rs ON rs.carrier_id = sl2.carrier_id
        WHERE sl2.id = NEW.sim_line_id AND rs.is_enabled
          AND NEW.execution_type = ANY (rs.allowed_execution_types)) THEN
        v_gateway := 'API';
      END IF;

      NEW.fulfillment_gateway := v_gateway;
    END IF;

    -- Always populate api_provider if not already set
    NEW.api_provider := COALESCE(NEW.api_provider, v_api_provider);

    -- Initialize attempted_providers as empty array if null
    IF NEW.attempted_providers IS NULL THEN
      NEW.attempted_providers := ARRAY[]::text[];
    END IF;

    IF NEW.execution_type = 'refill_instant' AND NEW.status = 'pending' THEN 
      NEW.status := 'routing'; 
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

-- 4. Harden claim_due_executions with Strict Concurrency Serialization (R9)
--    - Uses pg_try_advisory_xact_lock to serialize claims on the same SIM line across workers
--    - Uses DISTINCT ON (sim_line_id) so one batch never claims multiple rows for the same line
--    - Guarantees no two workers or batches can process for the same SIM line simultaneously
CREATE OR REPLACE FUNCTION public.claim_due_executions(p_execution_type character varying, p_limit integer)
RETURNS SETOF topup_executions
LANGUAGE plpgsql
SET search_path TO ''
AS $$
BEGIN
  RETURN QUERY
  WITH candidates AS (
    SELECT DISTINCT ON (t.sim_line_id) t.id
    FROM public.topup_executions t
    WHERE t.status = 'pending'
      AND t.execution_type = p_execution_type
      AND t.execution_time <= NOW()
      AND (t.scheduled_topup_id IS NULL OR EXISTS (
        SELECT 1 FROM public.scheduled_topups st
        WHERE st.id = t.scheduled_topup_id
          AND st.is_active))
      AND NOT EXISTS (
        SELECT 1 FROM public.topup_executions p
        WHERE p.sim_line_id = t.sim_line_id
          AND p.status = 'processing'
      )
      AND pg_try_advisory_xact_lock(hashtext('sim_line_' || t.sim_line_id::text))
    ORDER BY t.sim_line_id, t.execution_time ASC
    LIMIT p_limit
  )
  UPDATE public.topup_executions te
  SET status = 'processing',
      processing_since = NOW(),
      pre_processing_status = 'pending'
  FROM candidates c
  WHERE te.id = c.id
  RETURNING te.*;
END;
$$;

-- 5. Fix trg_fn_sync_custom_refill_queue Cap Desync & Scope (R10)
--    - Include max_authorized_usd, api_provider, engine_version, intent_kind in IF EXISTS
--    - Cancel unsubmitted executions in awaiting_approval and awaiting_funds on schedule change/pause
CREATE OR REPLACE FUNCTION public.trg_fn_sync_custom_refill_queue()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
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
      engine_version, intent_kind, attempted_providers
    ) VALUES (
      NEW.sim_line_id, NEW.user_id, NEW.amount, COALESCE(NEW.base_cost_usd, NEW.amount), NEW.app_fee_usd,
      COALESCE(NEW.currency, 'USD'), 'pending',
      NEW.schedule_type, NEW.next_execution_at, NEW.offer_id, NEW.offer_value,
      'wallet', NEW.id, NEW.preferred_provider,
      NEW.target_local_value, NEW.target_local_currency, COALESCE(NEW.max_authorized_usd, NEW.amount),
      COALESCE(NEW.engine_version, 2), COALESCE(NEW.intent_kind, 'exact_airtime'),
      ARRAY[]::text[]
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

-- 6. Clean up existing pending executions in the database
--    Reset attempted_providers from ['dtone'] to empty array if unsubmitted
UPDATE public.topup_executions
SET attempted_providers = ARRAY[]::text[]
WHERE status IN ('pending', 'awaiting_approval', 'awaiting_funds')
  AND (attempted_providers = ARRAY['dtone'] OR attempted_providers IS NULL);

-- 7. Harden retry_topup_execution against Double-Spending (R5)
--    - Forbid retrying if carrier_in_flight is true or active wallet hold exists
--    - Preserve max_authorized_usd, engine_version, and intent fields on retry
CREATE OR REPLACE FUNCTION public.retry_topup_execution(p_execution_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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

  -- Safety Guard R5: Forbid retrying if submission was in-flight or hold is still active/unreconciled
  IF COALESCE(v_exec.carrier_in_flight, false) THEN
    RAISE EXCEPTION 'This execution has an in-flight submission with the carrier network. It is under investigation and cannot be retried until reconciled.';
  END IF;

  IF v_exec.wallet_hold_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.wallet_holds wh
    WHERE wh.id = v_exec.wallet_hold_id
      AND wh.status = 'active'
  ) THEN
    RAISE EXCEPTION 'This execution has an active wallet balance hold under verification. It cannot be retried until the transaction is confirmed.';
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
    offer_id, offer_value, scheduled_topup_id, retry_of,
    max_authorized_usd, engine_version, intent_kind,
    target_local_value, target_local_currency
  ) VALUES (
    v_exec.sim_line_id, v_exec.user_id,
    COALESCE(v_exec.base_cost_usd, v_exec.amount),
    COALESCE(v_exec.base_cost_usd, v_exec.amount),
    v_exec.payment_gateway_code,
    v_exec.currency, 'pending', v_exec.execution_type, now(),
    v_exec.offer_id, v_exec.offer_value, v_exec.scheduled_topup_id,
    p_execution_id,
    v_exec.max_authorized_usd, COALESCE(v_exec.engine_version, 2), v_exec.intent_kind,
    v_exec.target_local_value, v_exec.target_local_currency
  )
  RETURNING id INTO v_new_id;

  RETURN v_new_id;
END;
$function$;
