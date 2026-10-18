-- ============================================================================
-- Migration: 20260908210000_refill_mini_queue_and_wallet_reminders.sql
-- Description:
-- 1. Fix capture_sim_setup_holds to insert schedule_type = 'refill_mini' (not 'refill_custom')
-- 2. Update trg_fn_sync_custom_refill_queue to synchronize both refill_custom AND refill_mini
-- 3. Update update_sim_line_last_topup_at to chain both refill_custom AND refill_mini
-- 4. Add emit_upcoming_refill_low_balance_reminders() and integrate into process_due_notifications()
-- 5. Data fix: migrate line 4328fee7-6a20-449c-b0ef-341541043cc0 from refill_custom to refill_mini
-- ============================================================================

-- 1. FIX capture_sim_setup_holds: Create 'refill_mini' schedule for Premium lines
CREATE OR REPLACE FUNCTION public.capture_sim_setup_holds(
  p_order_id UUID,
  p_provider_tx_id TEXT DEFAULT NULL::TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_order         RECORD;
  v_line_id       UUID;
  v_interval_days INTEGER := 30;
  v_rule          RECORD;
BEGIN
  SELECT * INTO v_order
  FROM public.sim_setup_orders
  WHERE id = p_order_id FOR UPDATE;

  IF v_order.id IS NULL THEN
    RAISE EXCEPTION 'Setup order not found: %', p_order_id;
  END IF;

  IF v_order.status = 'active' THEN
    RETURN jsonb_build_object('success', true, 'status', 'active', 'already_captured', true);
  END IF;

  -- 1. Capture annual fee hold
  IF v_order.annual_fee_hold_id IS NOT NULL THEN
    PERFORM public.capture_wallet_hold(
      v_order.annual_fee_hold_id,
      'plan_fee_debit',
      'Annual Protection Fee (' || v_order.plan || ')',
      jsonb_build_object('setup_order_id', p_order_id, 'plan', v_order.plan)
    );
  END IF;

  -- 2. Capture initial refill hold
  IF v_order.first_refill_hold_id IS NOT NULL THEN
    PERFORM public.capture_wallet_hold(
      v_order.first_refill_hold_id,
      'topup_debit',
      'Initial SIM Recharge (' || v_order.phone_number || ')',
      jsonb_build_object('setup_order_id', p_order_id, 'provider_tx_id', p_provider_tx_id)
    );
  END IF;

  v_line_id := v_order.sim_line_id;
  IF v_line_id IS NULL THEN
    RAISE EXCEPTION 'Cannot activate setup order without an associated sim_line_id: %', p_order_id;
  END IF;

  -- 3. Activate SIM Line with valid carrier_status ('active')
  UPDATE public.sim_lines
  SET status = 'active',
      plan_type = v_order.plan,
      protection_tier = CASE WHEN v_order.plan = 'free' THEN 'basic' ELSE v_order.plan END,
      plan_expires_at = now() + INTERVAL '365 days',
      last_topup_at = CASE WHEN v_order.plan = 'premium' THEN now() ELSE last_topup_at END,
      carrier_verified_at = now(),
      is_carrier_verified = true,
      carrier_status = 'active',
      verification_status = 'verified',
      updated_at = now()
  WHERE id = v_line_id;

  -- 4. Record plan payment with EXACT column names
  IF v_order.annual_fee_usd > 0 THEN
    INSERT INTO public.plan_payments (
      user_id, sim_line_id, capture_id, order_id, kind, gross_usd, net_usd,
      paypal_fee_usd, metadata, created_at
    ) VALUES (
      v_order.user_id,
      v_line_id,
      COALESCE(v_order.annual_fee_hold_id::text, 'setup_' || p_order_id::text),
      p_order_id::text,
      'plan',
      v_order.annual_fee_usd,
      v_order.annual_fee_usd,
      0.00,
      jsonb_build_object('billing_model', 'pay_per_refill', 'plan', v_order.plan, 'setup_order_id', p_order_id),
      now()
    );
  END IF;

  -- 5. Calculate cadence and schedule single next occurrence for Premium keep-alive
  IF v_order.plan = 'premium' AND v_order.carrier_rule_id IS NOT NULL THEN
    SELECT * INTO v_rule FROM public.carrier_rules WHERE id = v_order.carrier_rule_id;
    IF FOUND THEN
      v_interval_days := public.refill_interval_days(v_rule.inactivity_limit_days, v_rule.refill_interval_days_override);
      IF v_interval_days IS NULL OR v_interval_days < 1 THEN
        v_interval_days := 30;
      END IF;

      INSERT INTO public.scheduled_topups (
        user_id, sim_line_id, amount, currency, frequency_days,
        next_execution_at, is_active, status, schedule_type, offer_id, offer_value
      ) VALUES (
        v_order.user_id,
        v_line_id,
        v_order.first_refill_cost_usd,
        'USD',
        v_interval_days,
        now() + (v_interval_days || ' days')::interval,
        true,
        'active',
        'refill_mini',
        v_rule.offer_id,
        v_rule.offer_value
      )
      ON CONFLICT (sim_line_id, schedule_type)
      DO UPDATE SET
        amount = EXCLUDED.amount,
        currency = EXCLUDED.currency,
        frequency_days = EXCLUDED.frequency_days,
        next_execution_at = EXCLUDED.next_execution_at,
        is_active = true,
        status = 'active',
        offer_id = EXCLUDED.offer_id,
        offer_value = EXCLUDED.offer_value,
        updated_at = now();
    END IF;
  END IF;

  UPDATE public.sim_setup_orders
  SET status = 'active',
      provider_tx_id = COALESCE(p_provider_tx_id, provider_tx_id),
      updated_at = now()
  WHERE id = p_order_id;

  RETURN jsonb_build_object(
    'success', true,
    'status', 'active',
    'sim_line_id', v_line_id,
    'plan', v_order.plan
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.capture_sim_setup_holds(UUID, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.capture_sim_setup_holds(UUID, TEXT) TO service_role;


-- 2. UPDATE trg_fn_sync_custom_refill_queue to handle both refill_custom AND refill_mini
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
     AND NEW.offer_value IS NOT DISTINCT FROM OLD.offer_value THEN
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
    ) THEN
      RETURN NEW;
    END IF;

    UPDATE public.topup_executions
    SET status = 'cancelled', completed_at = now()
    WHERE scheduled_topup_id = NEW.id
      AND status IN ('pending', 'pending_payment');

    INSERT INTO public.topup_executions (
      sim_line_id, user_id, amount, base_cost_usd, currency, status,
      execution_type, execution_time, offer_id, offer_value,
      payment_gateway_code, scheduled_topup_id
    ) VALUES (
      NEW.sim_line_id, NEW.user_id, NEW.amount, NEW.amount,
      COALESCE(NEW.currency, 'USD'), 'pending',
      NEW.schedule_type, NEW.next_execution_at, NEW.offer_id, NEW.offer_value,
      NULL, NEW.id
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


-- 3. UPDATE update_sim_line_last_topup_at to chain both refill_custom AND refill_mini
CREATE OR REPLACE FUNCTION public.update_sim_line_last_topup_at()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_freq INTEGER;
BEGIN
    IF NEW.status = 'success' AND (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'success') THEN
        -- 1. Update sim_lines last_topup_at
        UPDATE public.sim_lines
        SET last_topup_at = COALESCE(NEW.completed_at, now()),
            updated_at = now()
        WHERE id = NEW.sim_line_id;
        
        -- 2. Handle next execution for refill_custom and refill_mini (Pay-Per-Refill model)
        IF NEW.execution_type IN ('refill_custom', 'refill_mini') AND NEW.scheduled_topup_id IS NOT NULL THEN
            SELECT frequency_days INTO v_freq 
            FROM public.scheduled_topups 
            WHERE id = NEW.scheduled_topup_id 
            AND is_active = true;
            
            IF v_freq IS NOT NULL AND v_freq > 0 THEN
                -- Insert next execution row
                INSERT INTO public.topup_executions (
                    scheduled_topup_id, 
                    sim_line_id, 
                    user_id, 
                    amount, 
                    currency, 
                    status, 
                    execution_time, 
                    execution_type, 
                    base_cost_usd, 
                    payment_gateway_code,
                    offer_id,
                    offer_value
                ) VALUES (
                    NEW.scheduled_topup_id, 
                    NEW.sim_line_id, 
                    NEW.user_id, 
                    NEW.amount, 
                    NEW.currency, 
                    'pending', 
                    COALESCE(NEW.completed_at, now()) + (v_freq || ' days')::interval, 
                    NEW.execution_type, 
                    NEW.base_cost_usd, 
                    NEW.payment_gateway_code,
                    NEW.offer_id,
                    NEW.offer_value
                );
                
                -- Update scheduled_topups dates
                UPDATE public.scheduled_topups
                SET next_execution_at = COALESCE(NEW.completed_at, now()) + (v_freq || ' days')::interval,
                    last_execution_at = COALESCE(NEW.completed_at, now()),
                    updated_at = now()
                WHERE id = NEW.scheduled_topup_id;
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.update_sim_line_last_topup_at() FROM PUBLIC, anon, authenticated;


-- 4. FUNCTION emit_upcoming_refill_low_balance_reminders
CREATE OR REPLACE FUNCTION public.emit_upcoming_refill_low_balance_reminders()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  r RECORD;
  v_count INTEGER := 0;
  v_available NUMERIC;
  v_phone TEXT;
BEGIN
  FOR r IN
    SELECT te.id AS execution_id,
           te.sim_line_id,
           te.user_id,
           te.amount,
           te.execution_time,
           te.execution_type,
           sl.phone_number,
           sl.nickname
    FROM public.topup_executions te
    JOIN public.sim_lines sl ON sl.id = te.sim_line_id
    WHERE te.status = 'pending'
      AND te.execution_type IN ('refill_mini', 'refill_custom')
      AND te.execution_time > now()
      AND te.execution_time <= now() + INTERVAL '7 days'
      AND sl.status = 'active'
      AND COALESCE(sl.protection_paused, false) = false
  LOOP
    -- Calculate user's available wallet balance
    SELECT (w.balance - COALESCE(
      (SELECT SUM(h.amount) FROM public.wallet_holds h WHERE h.user_id = r.user_id AND h.status = 'active'),
      0.00
    )) INTO v_available
    FROM public.wallets w
    WHERE w.user_id = r.user_id;

    IF v_available IS NOT NULL AND v_available < r.amount THEN
      -- Deduplication: Ensure we don't spam. Only 1 notification per SIM line per 24 hours.
      IF NOT EXISTS (
        SELECT 1 FROM public.notifications n
        WHERE n.user_id = r.user_id
          AND n.sim_line_id = r.sim_line_id
          AND n.category = 'wallet'
          AND n.created_at >= now() - INTERVAL '24 hours'
          AND n.title = 'Low Wallet Balance for Upcoming Auto-Refill'
      ) THEN
        v_phone := COALESCE(NULLIF(r.nickname, ''), r.phone_number, 'Your SIM line');

        INSERT INTO public.notifications (
          user_id, category, title, body, action_url, sim_line_id, delivered_via, is_read, created_at
        ) VALUES (
          r.user_id,
          'wallet',
          'Low Wallet Balance for Upcoming Auto-Refill',
          'Your scheduled recharge of $' || to_char(r.amount, 'FM999990.00') || ' for ' || v_phone || ' is due on ' || to_char(r.execution_time, 'Mon DD') || '. Your available wallet balance ($' || to_char(GREATEST(v_available, 0.00), 'FM999990.00') || ') is low. Please top up your wallet to ensure continuous protection.',
          '/wallet',
          r.sim_line_id,
          ARRAY['push'::text],
          false,
          now()
        );

        INSERT INTO public.line_activity_log (
          sim_line_id, user_id, event_type, description, metadata, created_at
        ) VALUES (
          r.sim_line_id,
          r.user_id,
          'reminder_sent',
          'Low wallet balance reminder sent for upcoming auto-refill',
          jsonb_build_object(
            'execution_id', r.execution_id,
            'execution_time', r.execution_time,
            'refill_amount', r.amount,
            'available_balance', v_available
          ),
          clock_timestamp()
        );

        v_count := v_count + 1;
      END IF;
    END IF;
  END LOOP;

  RETURN v_count;
END;
$function$;

REVOKE ALL ON FUNCTION public.emit_upcoming_refill_low_balance_reminders() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.emit_upcoming_refill_low_balance_reminders() TO service_role;


-- 5. UPDATE process_due_notifications to also call emit_upcoming_refill_low_balance_reminders()
CREATE OR REPLACE FUNCTION public.process_due_notifications()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  r RECORD;
  v_phone_number TEXT;
  v_next_due TIMESTAMPTZ;
BEGIN
  -- A. Process standard notification schedules
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

  -- B. Emit advance low-balance reminders for upcoming auto-refills
  PERFORM public.emit_upcoming_refill_low_balance_reminders();
END;
$function$;

REVOKE ALL ON FUNCTION public.process_due_notifications() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_due_notifications() TO service_role;


-- 6. DATA FIX for SIM Line 4328fee7-6a20-449c-b0ef-341541043cc0
-- Convert schedule from 'refill_custom' to 'refill_mini'
UPDATE public.scheduled_topups
SET schedule_type = 'refill_mini',
    updated_at = now()
WHERE id = '14c7b650-f877-42a3-82db-f3ac9583be09';

-- Convert pending execution from 'refill_custom' to 'refill_mini'
UPDATE public.topup_executions
SET execution_type = 'refill_mini',
    updated_at = now()
WHERE id = 'e1169db7-955d-42d4-abe8-89b06eeefd8c';
