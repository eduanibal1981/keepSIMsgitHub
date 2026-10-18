-- ISOLATED ONLY: Task 20 real scheduling functions and triggers; after retail fixture.
SET check_function_bodies=false;
DROP FUNCTION public.carrier_refill_offer(uuid,numeric);

CREATE OR REPLACE FUNCTION "public"."carrier_qualifying_topup_amount"("p_carrier_id" "uuid") RETURNS numeric
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  SELECT COALESCE(cr.validity_qualifying_topup_amount, cr.minimum_topup_amount)
  FROM public.carrier_rules cr
  WHERE cr.carrier_id = p_carrier_id
  ORDER BY cr.updated_at DESC NULLS LAST
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION "public"."carrier_refill_offer"("p_carrier_id" "uuid", "p_min_usd" numeric DEFAULT NULL::numeric) RETURNS TABLE("provider_code" "text", "offer_code" "text", "price_type" "text", "price_usd" numeric, "supplier_cost_usd" numeric, "offer_value" numeric, "is_overridden" boolean, "is_stale" boolean, "delivery_type" "text", "redeem_instructions" "text")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  WITH floored AS (
    SELECT NULLIF(GREATEST(COALESCE(p_min_usd, 0),
                           COALESCE(public.carrier_qualifying_topup_amount(p_carrier_id), 0)), 0) AS min_usd
  )
  SELECT
    o.provider_code,
    o.offer_code,
    o.source_price_type,
    CASE WHEN o.source_price_type = 'RANGE'
         THEN GREATEST(o.source_price_min_usd,
                       LEAST(o.source_price_max_usd, COALESCE(f.min_usd, o.source_price_min_usd)))
         ELSE o.effective_price_usd END,
    o.source_price_usd,
    CASE WHEN o.source_price_type = 'RANGE' AND o.source_price_max_usd > o.source_price_min_usd
         THEN round(o.source_send_min
                    + (GREATEST(o.source_price_min_usd,
                        LEAST(o.source_price_max_usd, COALESCE(f.min_usd, o.source_price_min_usd)))
                       - o.source_price_min_usd)
                      * (o.source_send_max - o.source_send_min)
                      / (o.source_price_max_usd - o.source_price_min_usd))
         ELSE NULL END,
    (o.override_price_usd IS NOT NULL),
    (o.source_refreshed_at < now() - interval '24 hours'),
    COALESCE(o.delivery_type, 'direct'),
    o.redeem_instructions
  FROM public.provider_offers o
  CROSS JOIN floored f
  JOIN public.carrier_supplier_routing r
    ON r.carrier_id = o.carrier_id AND r.provider_code = o.provider_code
  WHERE o.offer_kind = 'topup' AND o.carrier_id = p_carrier_id AND o.is_active
    AND r.is_routable
    AND (f.min_usd IS NULL
         OR (o.source_price_type = 'RANGE' AND o.source_price_max_usd >= f.min_usd)
         OR (o.source_price_type = 'FIXED' AND o.effective_price_usd  >= f.min_usd))
  ORDER BY
    -- 1. Primary provider first
    CASE WHEN r.is_primary THEN 0 ELSE 1 END ASC,
    -- 2. Prefer direct airtime recharge over PIN voucher
    CASE WHEN COALESCE(o.delivery_type, 'direct') = 'direct' THEN 0 ELSE 1 END ASC,
    -- 3. Lowest price (cheapest within primary if primary exists, else cheapest overall)
    CASE WHEN o.source_price_type = 'RANGE'
         THEN GREATEST(o.source_price_min_usd,
                       LEAST(o.source_price_max_usd, COALESCE(f.min_usd, o.source_price_min_usd)))
         ELSE o.effective_price_usd END ASC,
    -- 4. Priority tie-breaker
    r.priority ASC,
    -- 5. Offer code tie-breaker
    o.offer_code ASC
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION "public"."refill_interval_days"("p_inactivity_limit_days" integer, "p_override" integer DEFAULT NULL::integer) RETURNS integer
    LANGUAGE "sql" IMMUTABLE
    SET "search_path" TO ''
    AS $$
  SELECT CASE
    WHEN p_override IS NOT NULL AND p_override > 0 THEN LEAST(365, p_override)
    WHEN p_inactivity_limit_days IS NULL OR p_inactivity_limit_days < 1 THEN NULL
    ELSE GREATEST(1, LEAST(365,
      p_inactivity_limit_days - GREATEST(7, ceil(p_inactivity_limit_days * 0.15)::integer)))
  END;
$$;

CREATE OR REPLACE FUNCTION "public"."queue_premium_refill_executions"("p_sim_line_id" "uuid", "p_scheduled_topup_id" "uuid", "p_plan_expires_at" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_start_at" timestamp with time zone DEFAULT "now"()) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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
$$;

CREATE OR REPLACE FUNCTION "public"."trg_fn_sync_custom_refill_queue"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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
    -- Check if identical pending execution already exists with matching cap, pricing, and intent
    IF EXISTS (
      SELECT 1 FROM public.topup_executions t
      WHERE t.scheduled_topup_id = NEW.id
        AND t.status = 'pending'
        AND t.execution_time = NEW.next_execution_at
        AND t.amount = NEW.amount
        AND t.offer_id IS NOT DISTINCT FROM NEW.offer_id
        AND t.offer_value IS NOT DISTINCT FROM NEW.offer_value
        AND t.base_cost_usd IS NOT DISTINCT FROM NEW.base_cost_usd
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
        NEW.sim_line_id, NEW.user_id, NEW.amount, NEW.base_cost_usd, NEW.app_fee_usd,
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

CREATE OR REPLACE FUNCTION "public"."update_sim_line_last_topup_at"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;

CREATE OR REPLACE FUNCTION "public"."reschedule_mini_refill"("p_sim_line_id" "uuid", "p_new_date" timestamp with time zone) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.sim_lines sl
    WHERE sl.id = p_sim_line_id
      AND (sl.user_id = auth.uid()
           OR EXISTS (SELECT 1 FROM public.household_members hm
                      WHERE hm.owner_id = sl.user_id
                        AND hm.member_id = auth.uid()
                        AND hm.invite_status = 'accepted'
                        AND hm.role = 'manager'))
  ) THEN
    RAISE EXCEPTION 'Not authorized to modify this SIM line schedule';
  END IF;

  UPDATE public.scheduled_topups
  SET next_execution_at = p_new_date,
      updated_at = NOW()
  WHERE sim_line_id = p_sim_line_id AND schedule_type = 'refill_mini';

  UPDATE public.topup_executions
  SET execution_time = p_new_date
  WHERE id = (
    SELECT id FROM public.topup_executions
    WHERE sim_line_id = p_sim_line_id
      AND execution_type = 'refill_mini'
      AND status = 'pending'
      AND execution_time > NOW() + INTERVAL '1 hour'
    ORDER BY execution_time ASC
    LIMIT 1
  );
END;
$$;

CREATE OR REPLACE FUNCTION "public"."reset_mini_refill_to_default"("p_sim_line_id" "uuid") RETURNS timestamp with time zone
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_next_topup_due timestamp with time zone;
  v_frequency_days integer;
  v_buffer_days integer;
  v_default_date timestamp with time zone;
BEGIN
  IF auth.uid() IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.sim_lines sl
    WHERE sl.id = p_sim_line_id
      AND (sl.user_id = auth.uid()
           OR EXISTS (SELECT 1 FROM public.household_members hm
                      WHERE hm.owner_id = sl.user_id
                        AND hm.member_id = auth.uid()
                        AND hm.invite_status = 'accepted'
                        AND hm.role = 'manager'))
  ) THEN
    RAISE EXCEPTION 'Not authorized to modify this SIM line schedule';
  END IF;

  SELECT next_topup_due INTO v_next_topup_due
  FROM public.sim_lines
  WHERE id = p_sim_line_id;

  SELECT frequency_days INTO v_frequency_days
  FROM public.scheduled_topups
  WHERE sim_line_id = p_sim_line_id AND schedule_type = 'refill_mini';

  IF v_next_topup_due IS NULL OR v_frequency_days IS NULL THEN
    v_default_date := NOW() + INTERVAL '85 days';
  ELSE
    IF v_frequency_days >= 85 THEN
      v_buffer_days := 5;
    ELSIF v_frequency_days = 30 THEN
      v_buffer_days := 2;
    ELSIF v_frequency_days = 14 THEN
      v_buffer_days := 1;
    ELSE
      v_buffer_days := 0;
    END IF;

    v_default_date := v_next_topup_due - (v_buffer_days * INTERVAL '1 day');
  END IF;

  IF v_default_date < NOW() THEN
    v_default_date := NOW();
  END IF;

  UPDATE public.scheduled_topups
  SET next_execution_at = v_default_date,
      updated_at = NOW()
  WHERE sim_line_id = p_sim_line_id AND schedule_type = 'refill_mini';

  UPDATE public.topup_executions
  SET execution_time = v_default_date
  WHERE id = (
    SELECT id FROM public.topup_executions
    WHERE sim_line_id = p_sim_line_id
      AND execution_type = 'refill_mini'
      AND status = 'pending'
      AND execution_time > NOW() + INTERVAL '1 hour'
    ORDER BY execution_time ASC
    LIMIT 1
  );

  RETURN v_default_date;
END;
$$;

CREATE OR REPLACE FUNCTION "public"."update_mini_refill_dates"("p_sim_line_id" "uuid", "p_updates" "jsonb") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  r RECORD;
  v_moved integer := 0;
  v_earliest timestamptz;
BEGIN
  IF auth.uid() IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.sim_lines sl
    WHERE sl.id = p_sim_line_id
      AND (sl.user_id = auth.uid()
           OR EXISTS (SELECT 1 FROM public.household_members hm
                      WHERE hm.owner_id = sl.user_id
                        AND hm.member_id = auth.uid()
                        AND hm.invite_status = 'accepted'
                        AND hm.role = 'manager'))
  ) THEN
    RAISE EXCEPTION 'Not authorized to modify this SIM line schedule';
  END IF;

  -- Only this line's own queued mini refills can move; ids belonging to other
  -- lines/users or already-claimed rows are silently skipped, exactly like the
  -- old RLS-scoped client update.
  FOR r IN SELECT key AS execution_id, value AS new_time FROM jsonb_each_text(p_updates)
  LOOP
    UPDATE public.topup_executions
    SET execution_time = r.new_time::timestamptz
    WHERE id = r.execution_id::uuid
      AND sim_line_id = p_sim_line_id
      AND execution_type = 'refill_mini'
      AND status = 'pending';
    IF FOUND THEN
      v_moved := v_moved + 1;
    END IF;
  END LOOP;

  -- Keep the schedule's next_execution_at in step with the earliest queued row.
  SELECT min(execution_time) INTO v_earliest
  FROM public.topup_executions
  WHERE sim_line_id = p_sim_line_id
    AND execution_type = 'refill_mini'
    AND status = 'pending';

  IF v_earliest IS NOT NULL THEN
    UPDATE public.scheduled_topups
    SET next_execution_at = v_earliest,
        updated_at = now()
    WHERE sim_line_id = p_sim_line_id
      AND schedule_type = 'refill_mini';
  END IF;

  RETURN v_moved;
END;
$$;

CREATE OR REPLACE FUNCTION "public"."approve_refill_execution"("p_execution_id" "uuid", "p_new_max_authorized_usd" numeric DEFAULT NULL::numeric) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
BEGIN
  RAISE EXCEPTION 'Please update or reload KeepSIMs, then review the current refill price before approving.';
END;
$$;

CREATE OR REPLACE TRIGGER "trg_sync_custom_refill_queue" AFTER INSERT OR UPDATE ON "public"."scheduled_topups" FOR EACH ROW EXECUTE FUNCTION "public"."trg_fn_sync_custom_refill_queue"();

CREATE OR REPLACE TRIGGER "trigger_update_sim_line_last_topup" AFTER INSERT OR UPDATE OF "status" ON "public"."topup_executions" FOR EACH ROW EXECUTE FUNCTION "public"."update_sim_line_last_topup_at"();

SET check_function_bodies=true;
