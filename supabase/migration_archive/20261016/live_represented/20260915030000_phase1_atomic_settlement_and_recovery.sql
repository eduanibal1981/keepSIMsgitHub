-- Phase 1 Migration: Settlement, Holds, and Recovery Foundation
-- Addresses F03, F04, F06, F08, F09, F17

-- 1. Harden reserve_wallet_funds (F09)
--    - Verify matching user_id and amount upon idempotency adoption
--    - Subtract active hold allocations when allocating from funding lots to prevent concurrent over-allocation
--    - Assert v_needed = 0 after lot allocation
CREATE OR REPLACE FUNCTION public.reserve_wallet_funds(
  p_user_id uuid,
  p_amount numeric,
  p_order_type text,
  p_order_reference_id text,
  p_reason text DEFAULT NULL::text,
  p_ttl_minutes integer DEFAULT 120
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_wallet_id UUID;
  v_balance NUMERIC;
  v_held_amount NUMERIC := 0.00;
  v_available NUMERIC := 0.00;
  v_hold_id UUID;
  v_existing_hold RECORD;
  v_needed NUMERIC;
  v_lot RECORD;
  v_alloc_amount NUMERIC;
  v_active_lot_alloc NUMERIC;
  v_available_in_lot NUMERIC;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Hold amount must be positive, got %', p_amount;
  END IF;

  IF p_order_type IS NULL OR p_order_reference_id IS NULL THEN
    RAISE EXCEPTION 'order_type and order_reference_id are required';
  END IF;

  -- Idempotency check: if active hold exists for this reference, adopt it
  SELECT * INTO v_existing_hold
  FROM public.wallet_holds
  WHERE order_type = p_order_type AND order_reference_id = p_order_reference_id;

  IF v_existing_hold.id IS NOT NULL THEN
    IF v_existing_hold.status = 'active' THEN
      -- F09: Verify user_id and amount match
      IF v_existing_hold.user_id != p_user_id THEN
        RAISE EXCEPTION 'Existing hold % belongs to user %, but requested for user %', v_existing_hold.id, v_existing_hold.user_id, p_user_id;
      END IF;
      IF v_existing_hold.amount != p_amount THEN
        RAISE EXCEPTION 'Existing hold % has amount %, but requested amount is %', v_existing_hold.id, v_existing_hold.amount, p_amount;
      END IF;
      RETURN v_existing_hold.id;
    ELSE
      RAISE EXCEPTION 'Hold for % % is already in status %', p_order_type, p_order_reference_id, v_existing_hold.status;
    END IF;
  END IF;

  -- Lock wallet
  SELECT id, balance INTO v_wallet_id, v_balance
  FROM public.wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    RAISE EXCEPTION 'Wallet not found for user %', p_user_id;
  END IF;

  -- Calculate current active holds
  SELECT COALESCE(SUM(amount), 0.00) INTO v_held_amount
  FROM public.wallet_holds
  WHERE user_id = p_user_id AND status = 'active';

  v_available := v_balance - v_held_amount;

  IF v_available < p_amount THEN
    RAISE EXCEPTION 'Insufficient available balance. Available: %, Needed: %', v_available, p_amount;
  END IF;

  -- Create hold
  INSERT INTO public.wallet_holds (
    wallet_id, user_id, order_type, order_reference_id, amount, currency,
    status, reason, expires_at, created_at
  ) VALUES (
    v_wallet_id, p_user_id, p_order_type, p_order_reference_id, p_amount, 'USD',
    'active', p_reason, now() + (p_ttl_minutes || ' minutes')::interval, now()
  ) RETURNING id INTO v_hold_id;

  -- Allocate lots: Spend non-refundable/promotional first, then gifts, then paid deposits oldest first
  v_needed := p_amount;

  FOR v_lot IN
    SELECT * FROM public.wallet_funding_lots
    WHERE user_id = p_user_id AND status = 'active' AND remaining_amount > 0
    ORDER BY
      CASE
        WHEN origin_type IN ('promotional', 'unverified_legacy') THEN 1
        WHEN origin_type = 'gift_received' THEN 2
        ELSE 3
      END ASC,
      created_at ASC
    FOR UPDATE
  LOOP
    EXIT WHEN v_needed <= 0;

    -- Subtract any already-allocated amounts from active holds on this lot
    SELECT COALESCE(SUM(a.amount), 0.00) INTO v_active_lot_alloc
    FROM public.wallet_hold_allocations a
    JOIN public.wallet_holds h ON h.id = a.hold_id
    WHERE a.lot_id = v_lot.id AND h.status = 'active' AND h.id != v_hold_id;

    v_available_in_lot := v_lot.remaining_amount - v_active_lot_alloc;

    IF v_available_in_lot > 0 THEN
      v_alloc_amount := LEAST(v_available_in_lot, v_needed);

      INSERT INTO public.wallet_hold_allocations (hold_id, lot_id, amount, created_at)
      VALUES (v_hold_id, v_lot.id, v_alloc_amount, now());

      v_needed := v_needed - v_alloc_amount;
    END IF;
  END LOOP;

  -- Invariant check: Assert that the entire requested amount was successfully allocated
  IF v_needed > 0 THEN
    RAISE EXCEPTION 'Invariant violation: unable to allocate full amount from active lots. Short by %', v_needed;
  END IF;

  RETURN v_hold_id;
END;
$function$;

-- 2. Create Atomic Settlement RPC settle_successful_execution (F04, F17)
CREATE OR REPLACE FUNCTION public.settle_successful_execution(
  p_execution_id uuid,
  p_provider_tx_id text,
  p_hold_id uuid DEFAULT NULL,
  p_pin_code text DEFAULT NULL,
  p_pin_serial text DEFAULT NULL,
  p_redeem_instructions text DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_exec RECORD;
  v_hold_id UUID := p_hold_id;
  v_txn_id UUID := NULL;
  v_hold RECORD;
BEGIN
  -- 1. Lock execution row
  SELECT * INTO v_exec
  FROM public.topup_executions
  WHERE id = p_execution_id
  FOR UPDATE;

  IF v_exec.id IS NULL THEN
    RAISE EXCEPTION 'Execution not found: %', p_execution_id;
  END IF;

  -- If execution is already success, return idempotently
  IF v_exec.status = 'success' THEN
    SELECT id INTO v_txn_id
    FROM public.wallet_transactions
    WHERE reference_id = 'hold_' || COALESCE(v_exec.wallet_hold_id, p_hold_id)::text;

    RETURN jsonb_build_object(
      'success', true,
      'idempotent', true,
      'execution_id', v_exec.id,
      'status', 'success',
      'txn_id', v_txn_id
    );
  END IF;

  -- Determine hold_id
  IF v_hold_id IS NULL THEN
    v_hold_id := v_exec.wallet_hold_id;
  END IF;

  -- 2. If hold_id is present, capture the hold
  IF v_hold_id IS NOT NULL THEN
    SELECT * INTO v_hold
    FROM public.wallet_holds
    WHERE id = v_hold_id;

    IF v_hold.id IS NOT NULL THEN
      IF v_hold.status = 'active' THEN
        v_txn_id := public.capture_wallet_hold(
          p_hold_id => v_hold_id,
          p_txn_type => 'topup_debit',
          p_description => 'Auto-Refill: ' || COALESCE(v_exec.execution_type, 'refill'),
          p_metadata => jsonb_build_object(
            'execution_id', v_exec.id,
            'sim_line_id', v_exec.sim_line_id,
            'provider_tx_id', p_provider_tx_id
          ) || COALESCE(p_metadata, '{}'::jsonb)
        );
      ELSIF v_hold.status = 'captured' THEN
        SELECT id INTO v_txn_id
        FROM public.wallet_transactions
        WHERE reference_id = 'hold_' || v_hold_id::text;
      ELSE
        RAISE EXCEPTION 'Hold % is in invalid status for capture: %', v_hold_id, v_hold.status;
      END IF;
    END IF;
  END IF;

  -- 3. Update execution status atomically
  UPDATE public.topup_executions
  SET status = 'success',
      reloadly_transaction_id = p_provider_tx_id,
      wallet_hold_id = COALESCE(v_hold_id, wallet_hold_id),
      pin_code = COALESCE(p_pin_code, pin_code),
      pin_serial = COALESCE(p_pin_serial, pin_serial),
      redeem_instructions = COALESCE(p_redeem_instructions, redeem_instructions),
      executed_at = COALESCE(executed_at, now()),
      completed_at = now(),
      failure_reason = NULL,
      updated_at = now()
  WHERE id = p_execution_id;

  RETURN jsonb_build_object(
    'success', true,
    'execution_id', p_execution_id,
    'provider_tx_id', p_provider_tx_id,
    'hold_id', v_hold_id,
    'wallet_txn_id', v_txn_id
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.settle_successful_execution FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.settle_successful_execution TO service_role;

-- 3. Update route_topup_execution (F03)
--    - Resolve api_provider from offer catalogs when offer_id is present and api_provider is null
--    - Initialize attempted_providers with the primary provider
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

    -- Initialize attempted_providers with the primary provider if null or empty
    IF (NEW.attempted_providers IS NULL OR array_length(NEW.attempted_providers, 1) IS NULL) AND NEW.api_provider IS NOT NULL THEN
      NEW.attempted_providers := ARRAY[NEW.api_provider];
    END IF;

    IF NEW.execution_type = 'refill_instant' AND NEW.status = 'pending' THEN 
      NEW.status := 'routing'; 
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

-- 4. Harden reap_stuck_executions (F06)
--    - Only requeue to pending if the execution was pre-submission (no external tx id, not in flight)
--    - If carrier_in_flight or provider tx id exists, dead-letter with alert rather than creating duplicate purchase
CREATE OR REPLACE FUNCTION public.reap_stuck_executions(p_stuck_after_minutes integer DEFAULT 15, p_max_retries integer DEFAULT 3)
 RETURNS TABLE(requeued integer, dead_lettered integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
           COALESCE(h.carrier_in_flight, false) AS carrier_in_flight
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
$function$;
