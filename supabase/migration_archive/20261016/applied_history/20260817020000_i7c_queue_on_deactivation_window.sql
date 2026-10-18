-- i7c: queue the plan year against the deactivation window, not the bundle cycle
--
-- `queue_premium_refill_executions` stepped `v_t` by `topup_validity_days`,
-- which i7 established is a bundle/validity cycle rather than the window after
-- which a carrier terminates the line. On STC Saudi Arabia that column held 30
-- against a real 180-day cliff, so the loop inserted 13 topup_executions where
-- 3 would hold the number — and the subscriber had already been charged for all
-- 13 up front by RefillPricing.
--
-- The step now comes from public.refill_interval_days(), the same function the
-- Dart quote uses. Nothing else in the function changes: the entitlement guard,
-- the plan_expires_at clamp and the 400-row ceiling from I2b are carried over
-- verbatim.
--
-- One new refusal. A carrier flagged 'usage_required' resets its inactivity
-- clock only when a human makes a call, sends an SMS or uses data — pushing
-- credit at it does nothing. Queueing a year of refills for such a line would
-- spend the subscriber's money on a guarantee we cannot keep, so the queue
-- refuses and the purchase screens are expected to have said so first.

BEGIN;

CREATE OR REPLACE FUNCTION public.queue_premium_refill_executions(
  p_sim_line_id       uuid,
  p_scheduled_topup_id uuid,
  p_plan_expires_at   timestamptz DEFAULT NULL::timestamptz,
  p_start_at          timestamptz DEFAULT now()
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_line RECORD;
  v_rule RECORD;
  v_expires timestamptz;
  v_t timestamptz;
  v_count integer := 0;
  v_role text;
  v_step integer;
BEGIN
  SELECT sl.user_id, sl.carrier_id, sl.carrier_rule_id, sl.plan_expires_at
  INTO v_line
  FROM public.sim_lines sl
  WHERE sl.id = p_sim_line_id
    AND (auth.uid() IS NULL
         OR sl.user_id = auth.uid()
         OR EXISTS (SELECT 1 FROM public.household_members hm
                    WHERE hm.owner_id = sl.user_id
                      AND hm.member_id = auth.uid()
                      AND hm.invite_status = 'accepted'
                      AND hm.role = 'manager'));

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Not authorized to schedule refills for this SIM line';
  END IF;

  -- I2b GUARD. `current_user` is useless here (SECURITY DEFINER makes it the
  -- owner — D5c/F-6a/F4b, four occurrences), so the discriminator is the JWT
  -- role, read fail-closed: a malformed claims blob yields NULL, which is not
  -- 'service_role', so the guard still runs.
  BEGIN
    v_role := current_setting('request.jwt.claims', true)::json ->> 'role';
  EXCEPTION WHEN OTHERS THEN
    v_role := NULL;
  END;

  IF v_role IS DISTINCT FROM 'service_role' THEN
    IF NOT public.has_paid_premium_entitlement(p_sim_line_id) THEN
      RAISE EXCEPTION
        'This line has no paid, unexpired premium plan, so pre-paid refills cannot be queued.'
        USING ERRCODE = 'KS403';
    END IF;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.scheduled_topups st
    WHERE st.id = p_scheduled_topup_id
      AND st.sim_line_id = p_sim_line_id
      AND st.schedule_type = 'refill_mini'
  ) THEN
    RAISE EXCEPTION 'Schedule does not belong to this SIM line';
  END IF;

  SELECT cr.inactivity_limit_days, cr.refill_interval_days_override,
         cr.minimum_topup_amount, cr.offer_id, cr.offer_value,
         cr.activity_requirement, cr.validity_qualifying_topup_amount
  INTO v_rule
  FROM public.carrier_rules cr
  WHERE cr.id = COALESCE(v_line.carrier_rule_id,
                         (SELECT cr2.id FROM public.carrier_rules cr2
                          WHERE cr2.carrier_id = v_line.carrier_id
                          ORDER BY cr2.created_at DESC LIMIT 1));

  IF NOT FOUND OR v_rule.minimum_topup_amount IS NULL OR v_rule.minimum_topup_amount <= 0 THEN
    RAISE EXCEPTION 'No carrier rule with a top-up price exists for this SIM line';
  END IF;

  -- i7: no cadence saves a line whose carrier wants human usage. Refuse rather
  -- than bill for refills that cannot deliver what the plan promises.
  IF v_rule.activity_requirement = 'usage_required' THEN
    RAISE EXCEPTION
      'This carrier only resets its inactivity clock on an outgoing call, SMS or data session, so automated refills cannot keep the line active.'
      USING ERRCODE = 'KS422';
  END IF;

  -- i7: on a voucher-tier carrier a refill below the qualifying denomination
  -- buys credit and no line validity. Queueing it would look like protection
  -- and deliver none.
  IF v_rule.activity_requirement = 'min_denomination'
     AND v_rule.validity_qualifying_topup_amount IS NOT NULL
     AND v_rule.minimum_topup_amount < v_rule.validity_qualifying_topup_amount THEN
    RAISE EXCEPTION
      'Carrier rule refills % but this carrier only grants line validity from %',
      v_rule.minimum_topup_amount, v_rule.validity_qualifying_topup_amount
      USING ERRCODE = 'KS422';
  END IF;

  v_step := public.refill_interval_days(
    v_rule.inactivity_limit_days, v_rule.refill_interval_days_override);

  IF v_step IS NULL OR v_step < 1 THEN
    RAISE EXCEPTION 'Carrier rule has no usable deactivation window';
  END IF;

  -- I2b: the horizon is the LINE's paid-for expiry. `p_plan_expires_at` may
  -- only pull it in (a shorter queue is always safe), never push it out — it
  -- used to be trusted outright, which was worth ~$1,000 of airtime per line.
  v_expires := COALESCE(v_line.plan_expires_at, p_start_at + interval '365 days');
  IF p_plan_expires_at IS NOT NULL AND p_plan_expires_at < v_expires THEN
    v_expires := p_plan_expires_at;
  END IF;
  IF v_expires > p_start_at + interval '370 days' THEN
    v_expires := p_start_at + interval '370 days';
  END IF;

  UPDATE public.topup_executions
  SET status = 'cancelled', completed_at = now()
  WHERE scheduled_topup_id = p_scheduled_topup_id
    AND status IN ('pending', 'pending_payment');

  v_t := p_start_at;
  WHILE v_t < v_expires AND v_count < 400 LOOP
    INSERT INTO public.topup_executions (
      sim_line_id, user_id, amount, base_cost_usd, currency, status,
      execution_type, execution_time, offer_id, offer_value,
      payment_gateway_code, scheduled_topup_id
    ) VALUES (
      p_sim_line_id, v_line.user_id, v_rule.minimum_topup_amount,
      v_rule.minimum_topup_amount, 'USD', 'pending',
      'refill_mini', v_t, v_rule.offer_id, v_rule.offer_value,
      NULL,
      p_scheduled_topup_id
    );
    v_count := v_count + 1;
    v_t := v_t + (v_step || ' days')::interval;
  END LOOP;

  RETURN v_count;
END;
$function$;

COMMIT;
