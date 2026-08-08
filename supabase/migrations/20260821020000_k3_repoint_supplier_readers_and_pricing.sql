-- =============================================================================
-- K3 Â· Retire the per-supplier columns on `carriers`, and stop pricing refills
--      from a hand-typed number
-- =============================================================================
-- This migration does two things that have to happen together:
--
--   (a) Every reader of `carriers.zen_carrier / dt_carrier / ding_carrier /
--       reloadly_operator_id / api_provider` is repointed at
--       `carrier_provider_map` (through the K1 `carrier_supplier_routing` view),
--       and the columns are dropped.
--
--   (b) The premium refill path stops reading
--       `carrier_rules.minimum_topup_amount` as if it were the price of
--       `carrier_rules.offer_id`, and asks the catalogue instead.
--
-- (b) is not scope creep. Half the readers being rewritten in (a) are the same
-- functions that carry the price bug, and both defects have one cause: a fact
-- about a supplier stored in a second place, by hand, with nothing reconciling
-- the copies.
--
-- THE PRICE BUG, MEASURED
--   Of 36 carrier rules naming an offer, 23 name one whose real catalogue price
--   differs from the queued amount and 3 name an offer no enabled catalogue
--   contains. `worker_auto_mini_refill.js` â†’ `resolveVerifiedOffer` refuses the
--   mismatch, so those premium refills fail permanently:
--     "Offer price mismatch: STC_SA_001_USD costs 7.1 USD but 6.25 USD was charged."
--   Zain KSA is the only premium line that ever succeeded, and only because its
--   rule has `offer_id IS NULL` so the worker matched by value against a RANGE.
--
-- PRICING STANCE, AND WHY IT IS A FLOOR RATHER THAN A REPLACEMENT
--   `carrier_rules.inapp_pricing` is a deliberate retail figure and an operator
--   may want it above cost. So it still wins â€” but only upwards. The new price
--   is GREATEST(inapp_pricing, cost + fees + margin), so a stale retail number
--   can no longer sell a plan below what fulfilling it costs. Measured today
--   `inapp_pricing` is BELOW cost on most carriers; Turkcell bills $7.58 per
--   refill against a $10.00 cost.
--
--   Two plans move a lot, and both because the old number priced an offer that
--   does not exist: Jio $20.91 â†’ $95.92 (its only real offer is $17.00, the
--   rule claimed $3.11) and Airtel IN $29.93 â†’ $52.72. Everything else moves
--   under $4, and Zain KSA â€” the one live premium line â€” does not move at all.
--
--   Where NO offer resolves, the functions RAISE instead of guessing. J8
--   established that a plausible wrong price gets charged unnoticed; a refusal
--   at the point of sale is recoverable, a year of failing refills is not.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. plan_price_net â€” the quote, floored at what fulfilment actually costs
-- -----------------------------------------------------------------------------
-- Signature unchanged: CREATE OR REPLACE, never DROP+CREATE with a new argument
-- list. Two signatures differing by a defaulted parameter is the PGRST203 trap
-- that broke both money paths for eight days (D5b â†’ F2b).
CREATE OR REPLACE FUNCTION public.plan_price_net(
  p_plan text,
  p_sim_line_id uuid DEFAULT NULL::uuid,
  p_carrier_rule_id uuid DEFAULT NULL::uuid
)
RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_base_fee    numeric;
  v_app_fee_pct numeric;
  v_margin_pct  numeric;
  v_margin_flat numeric;
  v_rule        RECORD;
  v_step        integer;
  v_refills     integer;
  v_per_refill  numeric;
  v_qualifying  numeric;
  v_offer       RECORD;
  v_from_cost   numeric;
BEGIN
  SELECT config_value::numeric INTO v_base_fee
  FROM public.system_configs WHERE config_key = 'BASE_SERVICE_FEE_USD';
  IF v_base_fee IS NULL OR v_base_fee <= 0 THEN v_base_fee := 2.50; END IF;

  IF lower(coalesce(p_plan, '')) = 'standard' THEN
    RETURN v_base_fee;
  END IF;

  IF lower(coalesce(p_plan, '')) <> 'premium' THEN
    RAISE EXCEPTION 'Invalid plan: %', p_plan USING ERRCODE = '22023';
  END IF;

  SELECT cr.carrier_id, cr.minimum_topup_amount, cr.inactivity_limit_days,
         cr.refill_interval_days_override, cr.inapp_pricing,
         cr.activity_requirement, cr.validity_qualifying_topup_amount
  INTO v_rule
  FROM public.carrier_rules cr
  WHERE cr.id = COALESCE(
          p_carrier_rule_id,
          (SELECT sl.carrier_rule_id FROM public.sim_lines sl WHERE sl.id = p_sim_line_id),
          (SELECT cr2.id
             FROM public.carrier_rules cr2
             JOIN public.sim_lines sl2 ON sl2.carrier_id = cr2.carrier_id
            WHERE sl2.id = p_sim_line_id
            ORDER BY cr2.created_at DESC
            LIMIT 1));

  IF NOT FOUND OR v_rule.minimum_topup_amount IS NULL OR v_rule.minimum_topup_amount <= 0 THEN
    RAISE EXCEPTION 'No carrier rule with a top-up price exists for this plan'
      USING ERRCODE = '22023';
  END IF;

  -- i7's refusals stay in the pricing function, because pricing is the one thing
  -- every purchase surface must pass through.
  IF v_rule.activity_requirement = 'usage_required' THEN
    RAISE EXCEPTION
      'This carrier only resets its inactivity clock on an outgoing call, SMS or data session, so automated refills cannot keep the line active.'
      USING ERRCODE = 'KS422';
  END IF;

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
    RAISE EXCEPTION 'Carrier rule has no usable deactivation window'
      USING ERRCODE = '22023';
  END IF;

  v_refills := ceil(365.0 / v_step);

  SELECT COALESCE(config_value::numeric, 3.0) INTO v_app_fee_pct
  FROM public.system_configs WHERE config_key = 'APP_FEE_PERCENT';
  SELECT COALESCE(config_value::numeric, 5.0) INTO v_margin_pct
  FROM public.system_configs WHERE config_key = 'PREMIUM_MARGIN_PERCENT';
  SELECT COALESCE(config_value::numeric, 0.324) INTO v_margin_flat
  FROM public.system_configs WHERE config_key = 'PREMIUM_MARGIN_PER_REFILL_USD';
  v_app_fee_pct := COALESCE(v_app_fee_pct, 3.0);
  v_margin_pct  := COALESCE(v_margin_pct, 5.0);
  v_margin_flat := COALESCE(v_margin_flat, 0.324);

  -- The amount that has to reach the carrier for the top-up to count.
  v_qualifying := COALESCE(v_rule.validity_qualifying_topup_amount,
                           v_rule.minimum_topup_amount);

  -- What a supplier will actually charge for a refill that qualifies. This is
  -- the number that used to be assumed equal to minimum_topup_amount.
  SELECT * INTO v_offer
  FROM public.carrier_refill_offer(v_rule.carrier_id, v_qualifying);

  IF v_offer.offer_code IS NULL THEN
    RAISE EXCEPTION
      'No supplier currently sells a top-up for this carrier that reaches the % USD its validity rules require, so a premium year cannot be fulfilled.',
      to_char(v_qualifying, 'FM999990.00')
      USING ERRCODE = 'KS422';
  END IF;

  v_from_cost := v_offer.price_usd * (1.0 + ((v_app_fee_pct + v_margin_pct) / 100.0))
                 + v_margin_flat;

  -- inapp_pricing is a retail decision and may sit ABOVE cost. It may never sit
  -- below it: that is how premium came to be sold at a loss on most carriers.
  v_per_refill := GREATEST(COALESCE(v_rule.inapp_pricing, 0), v_from_cost);

  -- Deliberately UNROUNDED (J8): rounding the net before the caller grosses it
  -- up moves the final figure a cent off the button, and rounding each refill
  -- before summing drifts across a year. Callers round exactly once.
  RETURN v_base_fee + (v_per_refill * v_refills);
END;
$function$;

-- -----------------------------------------------------------------------------
-- 2. queue_premium_refill_executions â€” queue an offer that can be bought
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.queue_premium_refill_executions(
  p_sim_line_id uuid,
  p_scheduled_topup_id uuid,
  p_plan_expires_at timestamptz DEFAULT NULL::timestamptz,
  p_start_at timestamptz DEFAULT now()
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_line       RECORD;
  v_rule       RECORD;
  v_offer      RECORD;
  v_qualifying numeric;
  v_expires    timestamptz;
  v_t          timestamptz;
  v_count      integer := 0;
  v_role       text;
  v_step       integer;
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

  BEGIN
    v_role := current_setting('request.jwt.claims', true)::json ->> 'role';
  EXCEPTION WHEN OTHERS THEN
    v_role := NULL;
  END;

  -- I2: guard the SPEND, not the label.
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
         cr.minimum_topup_amount, cr.activity_requirement,
         cr.validity_qualifying_topup_amount
  INTO v_rule
  FROM public.carrier_rules cr
  WHERE cr.id = COALESCE(v_line.carrier_rule_id,
                         (SELECT cr2.id FROM public.carrier_rules cr2
                          WHERE cr2.carrier_id = v_line.carrier_id
                          ORDER BY cr2.created_at DESC LIMIT 1));

  IF NOT FOUND OR v_rule.minimum_topup_amount IS NULL OR v_rule.minimum_topup_amount <= 0 THEN
    RAISE EXCEPTION 'No carrier rule with a top-up price exists for this SIM line';
  END IF;

  IF v_rule.activity_requirement = 'usage_required' THEN
    RAISE EXCEPTION
      'This carrier only resets its inactivity clock on an outgoing call, SMS or data session, so automated refills cannot keep the line active.'
      USING ERRCODE = 'KS422';
  END IF;

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

  v_qualifying := COALESCE(v_rule.validity_qualifying_topup_amount,
                           v_rule.minimum_topup_amount);

  -- THE FIX. The amount and the offer id now come from one place, so they
  -- cannot disagree. Previously the amount was carrier_rules.minimum_topup_amount
  -- and the offer id was carrier_rules.offer_id, typed in separately, and the
  -- worker refused every pair that had drifted apart.
  SELECT * INTO v_offer
  FROM public.carrier_refill_offer(v_line.carrier_id, v_qualifying);

  IF v_offer.offer_code IS NULL THEN
    RAISE EXCEPTION
      'No supplier currently sells a top-up for this carrier that reaches the % USD its validity rules require.',
      to_char(v_qualifying, 'FM999990.00')
      USING ERRCODE = 'KS422';
  END IF;

  v_expires := COALESCE(v_line.plan_expires_at, p_start_at + interval '365 days');
  IF p_plan_expires_at IS NOT NULL AND p_plan_expires_at < v_expires THEN
    v_expires := p_plan_expires_at;
  END IF;
  -- I2: the horizon may only ever narrow.
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
      payment_gateway_code, scheduled_topup_id, api_provider
    ) VALUES (
      p_sim_line_id, v_line.user_id, v_offer.price_usd,
      v_offer.price_usd, 'USD', 'pending',
      'refill_mini', v_t, v_offer.offer_code,
      CASE WHEN v_offer.offer_value IS NULL THEN NULL ELSE v_offer.offer_value::bigint END,
      NULL,
      p_scheduled_topup_id,
      -- I1: stamp the winning supplier, or route_topup_execution falls back to
      -- the carrier default and a DTOne purchase gets dispatched to Zendit.
      v_offer.provider_code
    );
    v_count := v_count + 1;
    v_t := v_t + (v_step || ' days')::interval;
  END LOOP;

  RETURN v_count;
END;
$function$;

-- -----------------------------------------------------------------------------
-- 3. route_topup_execution â€” the default supplier is a mapping, not a column
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.route_topup_execution()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $function$
DECLARE
  v_gateway VARCHAR;
  v_api_provider text;
BEGIN
  IF NEW.status IN ('pending', 'pending_payment', 'routing') AND NEW.fulfillment_gateway IS NULL THEN

    SELECT ca.fulfillment_gateway, m.provider
    INTO v_gateway, v_api_provider
    FROM public.sim_lines sl
    JOIN public.carriers ca ON sl.carrier_id = ca.id
    LEFT JOIN public.carrier_provider_map m
      ON m.carrier_id = ca.id AND m.is_primary
    WHERE sl.id = NEW.sim_line_id;

    IF v_gateway IS NULL THEN
      SELECT config_value INTO v_gateway
      FROM public.system_configs WHERE config_key = 'ACTIVE_FULFILLMENT_METHOD' LIMIT 1;
      IF v_gateway IS NULL THEN
        v_gateway := 'MANUAL';
      END IF;
    END IF;

    IF v_gateway = 'TASKER_SCRIPT' AND NEW.execution_type = 'refill_instant' THEN
      v_gateway := 'API';
    END IF;

    IF v_gateway = 'TASKER_SCRIPT' AND NOT EXISTS (
      SELECT 1
      FROM public.sim_lines sl
      JOIN public.refill_scripts rs ON rs.carrier_id = sl.carrier_id
      WHERE sl.id = NEW.sim_line_id
        AND rs.is_enabled
        AND NEW.execution_type = ANY (rs.allowed_execution_types)
    ) THEN
      v_gateway := 'API';
    END IF;

    NEW.fulfillment_gateway := v_gateway;
    -- I1: never CLOBBER an explicitly chosen supplier.
    NEW.api_provider := COALESCE(NEW.api_provider, v_api_provider);

    IF NEW.execution_type = 'refill_instant' AND NEW.status = 'pending' THEN
      NEW.status := 'routing';
    END IF;

  END IF;

  RETURN NEW;
END;
$function$;

-- -----------------------------------------------------------------------------
-- 4. supplier_candidates â€” the incumbent is the primary mapping
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.supplier_candidates(
  p_sim_line_id uuid, p_offer_id text, p_exclude text[] DEFAULT NULL::text[]
)
RETURNS TABLE (provider text, base numeric, eff numeric, incumbent boolean, prio integer)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT poc.api_provider,
         COALESCE(poc.price_fixed_usd, poc.price_min_usd),
         public.supplier_effective_cost(poc.api_provider,
           COALESCE(poc.price_fixed_usd, poc.price_min_usd)),
         m.is_primary,
         m.priority
  FROM public.sim_lines sl
  JOIN public.carrier_provider_map m
    ON m.carrier_id = sl.carrier_id AND m.is_enabled
  JOIN public.supplier_policy sp
    ON sp.provider = m.provider AND sp.is_globally_enabled
  JOIN public.provider_offers_cache poc
    ON poc.api_provider = m.provider
   AND poc.country_code = m.provider_country_code
   AND poc.carrier_code = m.provider_carrier_code
   AND poc.offer_id     = p_offer_id
  WHERE sl.id = p_sim_line_id
    AND poc.refreshed_at >= now() - interval '24 hours'
    AND (p_exclude IS NULL OR NOT (poc.api_provider = ANY (p_exclude)));
$function$;

-- -----------------------------------------------------------------------------
-- 5. sync_auto_price_watches â€” one supplier per carrier was never the truth
-- -----------------------------------------------------------------------------
-- Watches every ENABLED mapping, not just the default one. A line whose carrier
-- has two suppliers is now watched on both, which is the whole point of price
-- watching.
CREATE OR REPLACE FUNCTION public.sync_auto_price_watches()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_added   integer;
  v_removed integer;
BEGIN
  WITH live AS (
    SELECT DISTINCT sl.user_id, m.provider_country_code AS country_code,
           m.provider_carrier_code AS carrier_code
    FROM public.sim_lines sl
    JOIN public.carrier_provider_map m ON m.carrier_id = sl.carrier_id AND m.is_enabled
    WHERE sl.status = 'active'
  )
  INSERT INTO public.offer_price_watches (user_id, source, country_code, carrier_code, origin)
  SELECT l.user_id, 'topup', l.country_code, l.carrier_code, 'auto'
  FROM live l
  WHERE l.carrier_code IS NOT NULL AND l.country_code IS NOT NULL
  ON CONFLICT DO NOTHING;

  GET DIAGNOSTICS v_added = ROW_COUNT;

  WITH live AS (
    SELECT DISTINCT sl.user_id, m.provider_country_code AS country_code,
           m.provider_carrier_code AS carrier_code
    FROM public.sim_lines sl
    JOIN public.carrier_provider_map m ON m.carrier_id = sl.carrier_id AND m.is_enabled
    WHERE sl.status = 'active'
  )
  DELETE FROM public.offer_price_watches w
  WHERE w.origin = 'auto'
    AND NOT EXISTS (
      SELECT 1 FROM live l
      WHERE l.user_id = w.user_id
        AND l.country_code = w.country_code
        AND l.carrier_code = w.carrier_code
    );

  GET DIAGNOSTICS v_removed = ROW_COUNT;

  RETURN v_added + v_removed;
END;
$function$;

-- -----------------------------------------------------------------------------
-- 6. ingest_offline_refill â€” was Zendit-only, on every carrier
-- -----------------------------------------------------------------------------
-- This function read `ca.zen_carrier` and looked the offer up in
-- `zendit_offers_cache` (a view over provider_offers_cache WHERE
-- api_provider='zendit'). A DTOne carrier therefore ALWAYS rejected with
-- 'no_offer' â€” the identical defect I1 fixed for instant refill and never
-- propagated here. Zain KSA is DTOne and holds the only live SIM line, so
-- offline refill has never once been able to work for it.
CREATE OR REPLACE FUNCTION public.ingest_offline_refill(
  p_provider text, p_provider_msg_id text, p_sender_phone text, p_channel text,
  p_amount_usd numeric DEFAULT NULL::numeric, p_raw jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_event_id     uuid;
  v_user_id      uuid;
  v_line_id      uuid;
  v_line_ids     uuid[];
  v_carrier_id   uuid;
  v_offer        RECORD;
  v_base         numeric;
  v_value        numeric;
  v_amount_req   numeric;
  v_default_amt  numeric;
  v_enabled      boolean;
  v_execution_id uuid;
  v_existing     RECORD;
BEGIN
  IF p_channel NOT IN ('whatsapp','sms','missed_call') THEN
    RAISE EXCEPTION 'Unknown offline channel %', p_channel;
  END IF;

  SELECT * INTO v_existing
  FROM public.offline_refill_events
  WHERE provider = p_provider AND provider_msg_id = p_provider_msg_id;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'status', 'duplicate', 'event_id', v_existing.id,
      'execution_id', v_existing.execution_id, 'original_status', v_existing.status);
  END IF;

  INSERT INTO public.offline_refill_events
    (provider, provider_msg_id, channel, sender_phone, raw)
  VALUES
    (p_provider, p_provider_msg_id, p_channel, p_sender_phone, COALESCE(p_raw, '{}'::jsonb))
  RETURNING id INTO v_event_id;

  IF regexp_replace(COALESCE(p_sender_phone,''), '\D', '', 'g') = '' THEN
    UPDATE public.offline_refill_events
      SET status='rejected', reject_reason='no_sender' WHERE id = v_event_id;
    RETURN jsonb_build_object('status','rejected','reason','no_sender','event_id',v_event_id);
  END IF;

  v_user_id := public.resolve_sender_user(p_sender_phone);

  IF v_user_id IS NULL THEN
    UPDATE public.offline_refill_events
      SET status='rejected', reject_reason='unknown_sender' WHERE id = v_event_id;
    RETURN jsonb_build_object('status','rejected','reason','unknown_sender','event_id',v_event_id);
  END IF;

  UPDATE public.offline_refill_events SET user_id = v_user_id WHERE id = v_event_id;

  SELECT COALESCE(s.is_enabled,false), s.target_sim_line_id, COALESCE(s.default_refill_amount,10.00)
  INTO v_enabled, v_line_id, v_default_amt
  FROM public.offline_refill_settings s
  WHERE s.user_id = v_user_id;

  IF v_enabled IS DISTINCT FROM true THEN
    UPDATE public.offline_refill_events
      SET status='rejected', reject_reason='disabled' WHERE id = v_event_id;
    RETURN jsonb_build_object('status','rejected','reason','disabled','event_id',v_event_id);
  END IF;

  IF v_line_id IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM public.sim_lines sl
                     WHERE sl.id = v_line_id AND sl.user_id = v_user_id) THEN
    v_line_id := NULL;
  END IF;

  IF v_line_id IS NULL THEN
    SELECT array_agg(sl.id) INTO v_line_ids
    FROM public.sim_lines sl
    WHERE sl.user_id = v_user_id AND COALESCE(sl.status,'active') = 'active';
    IF v_line_ids IS NOT NULL AND array_length(v_line_ids,1) = 1 THEN
      v_line_id := v_line_ids[1];
    END IF;
  END IF;

  IF v_line_id IS NULL THEN
    UPDATE public.offline_refill_events
      SET status='rejected', reject_reason='no_target' WHERE id = v_event_id;
    RETURN jsonb_build_object('status','rejected','reason','no_target','event_id',v_event_id);
  END IF;

  SELECT sl.carrier_id INTO v_carrier_id
  FROM public.sim_lines sl WHERE sl.id = v_line_id;

  v_amount_req := COALESCE(p_amount_usd, v_default_amt);

  -- Provider-agnostic, and priced from the catalogue rather than from a rule
  -- column. Asks for the cheapest offer that reaches the requested amount.
  SELECT * INTO v_offer
  FROM public.carrier_refill_offer(v_carrier_id, v_amount_req);

  IF v_offer.offer_code IS NULL THEN
    UPDATE public.offline_refill_events
      SET status='rejected', reject_reason='no_offer', sim_line_id=v_line_id WHERE id = v_event_id;
    RETURN jsonb_build_object('status','rejected','reason','no_offer','event_id',v_event_id);
  END IF;

  IF v_offer.is_stale THEN
    UPDATE public.offline_refill_events
      SET status='rejected', reject_reason='pricing_stale', sim_line_id=v_line_id WHERE id = v_event_id;
    RETURN jsonb_build_object('status','rejected','reason','pricing_stale','event_id',v_event_id);
  END IF;

  v_base  := v_offer.price_usd;
  v_value := v_offer.offer_value;

  IF v_base IS NULL OR v_base <= 0 THEN
    UPDATE public.offline_refill_events
      SET status='rejected', reject_reason='no_price', sim_line_id=v_line_id WHERE id = v_event_id;
    RETURN jsonb_build_object('status','rejected','reason','no_price','event_id',v_event_id);
  END IF;

  BEGIN
    INSERT INTO public.topup_executions (
      sim_line_id, user_id, amount, base_cost_usd, payment_gateway_code,
      currency, status, execution_type, execution_time, offer_id, offer_value,
      refill_channel, api_provider
    ) VALUES (
      v_line_id, v_user_id, v_base, v_base, 'wallet',
      'USD', 'pending', 'refill_instant', now(), v_offer.offer_code,
      CASE WHEN v_value IS NULL THEN NULL ELSE v_value::bigint END, p_channel,
      v_offer.provider_code
    )
    RETURNING id INTO v_execution_id;
  EXCEPTION WHEN others THEN
    UPDATE public.offline_refill_events
      SET status='rejected', reject_reason = left('insert_failed: '||sqlerrm, 200), sim_line_id=v_line_id
      WHERE id = v_event_id;
    RETURN jsonb_build_object('status','rejected','reason','insert_failed','detail',sqlerrm,'event_id',v_event_id);
  END;

  UPDATE public.offline_refill_events
    SET status='queued', sim_line_id=v_line_id, execution_id=v_execution_id
    WHERE id = v_event_id;

  RETURN jsonb_build_object(
    'status','queued','event_id',v_event_id,'execution_id',v_execution_id,
    'sim_line_id',v_line_id,'base_cost_usd',v_base,'channel',p_channel);
END $function$;

-- -----------------------------------------------------------------------------
-- 7. run_auto_rescue Ã¢â‚¬â€ same Zendit-only defect, same fix
-- -----------------------------------------------------------------------------
-- Read `ca.zen_carrier` and `zendit_offers_cache`, so a DTOne line reported
-- 'no top-up offer known for this line' and was never rescued. SIM Shield has
-- therefore never been able to protect Zain KSA, the only carrier with a live
-- line. The forecast's suggested amount is now the FLOOR an offer has to reach,
-- not an offer id we hope still exists.
CREATE OR REPLACE FUNCTION public.run_auto_rescue(p_dry_run boolean DEFAULT false)
RETURNS TABLE(sim_line_id uuid, line_label text, action text, reason text,
              amount_usd numeric, execution_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_claims text; v_role text; v_enabled boolean;
  v_grace_hours numeric; v_cooldown_days numeric; v_max_per_run integer;
  v_spent integer := 0; r RECORD; v_offer RECORD;
  v_base numeric; v_value bigint; v_exec_id uuid; v_charged numeric; v_label text;
BEGIN
  v_claims := current_setting('request.jwt.claims', true);
  IF v_claims IS NOT NULL AND v_claims <> '' THEN
    v_role := (v_claims::jsonb) ->> 'role';
    IF v_role IS DISTINCT FROM 'service_role' THEN
      RAISE EXCEPTION 'run_auto_rescue is not callable by role %', COALESCE(v_role, '<none>')
        USING ERRCODE = 'KS403';
    END IF;
  END IF;

  SELECT COALESCE(NULLIF(config_value, ''), 'true')::boolean INTO v_enabled
    FROM public.system_configs WHERE config_key = 'RESCUE_ENABLED';
  v_enabled := COALESCE(v_enabled, true);
  IF NOT v_enabled THEN
    RETURN QUERY SELECT NULL::uuid, NULL::text, 'skipped'::text,
                        'RESCUE_ENABLED is false'::text, NULL::numeric, NULL::uuid;
    RETURN;
  END IF;

  SELECT COALESCE((SELECT NULLIF(config_value,'')::numeric FROM public.system_configs WHERE config_key='RESCUE_GRACE_HOURS'), 24) INTO v_grace_hours;
  SELECT COALESCE((SELECT NULLIF(config_value,'')::numeric FROM public.system_configs WHERE config_key='RESCUE_COOLDOWN_DAYS'), 20) INTO v_cooldown_days;
  SELECT COALESCE((SELECT NULLIF(config_value,'')::int FROM public.system_configs WHERE config_key='RESCUE_MAX_PER_RUN'), 25) INTO v_max_per_run;

  FOR r IN
    SELECT p.sim_line_id, p.user_id, p.max_usd, p.lead_days, p.warn_lead_days,
           p.last_warned_at, p.last_rescue_at, sl.nickname, sl.phone_number,
           sl.carrier_id,
           f.days_remaining, f.predicted_depletion_at, f.suggested_amount_usd,
           COALESCE(w.balance, 0) AS balance
    FROM public.sim_line_rescue_policy p
    JOIN public.sim_lines sl ON sl.id = p.sim_line_id
    JOIN public.profiles pr  ON pr.id = p.user_id
    LEFT JOIN public.sim_line_usage_forecast f ON f.sim_line_id = p.sim_line_id AND f.subject_kind = 'sim_line'
    LEFT JOIN public.wallets   w  ON w.user_id = p.user_id
    WHERE p.max_usd > 0 AND sl.status = 'active' AND sl.protection_paused = false
      AND COALESCE(pr.is_suspended, false) = false
    ORDER BY f.days_remaining NULLS LAST
  LOOP
    v_label := COALESCE(NULLIF(r.nickname, ''), r.phone_number, r.sim_line_id::text);

    IF r.days_remaining IS NULL THEN
      RETURN QUERY SELECT r.sim_line_id, v_label, 'skipped'::text, 'no forecast for this line'::text, NULL::numeric, NULL::uuid;
      CONTINUE;
    END IF;

    IF r.days_remaining > r.lead_days + r.warn_lead_days THEN
      IF r.last_warned_at IS NOT NULL THEN
        IF NOT p_dry_run THEN
          UPDATE public.sim_line_rescue_policy SET last_warned_at = NULL
           WHERE sim_line_rescue_policy.sim_line_id = r.sim_line_id;
        END IF;
        RETURN QUERY SELECT r.sim_line_id, v_label, 'reset'::text,
                            format('%s days left; warning cleared', r.days_remaining), NULL::numeric, NULL::uuid;
      END IF;
      CONTINUE;
    END IF;

    IF r.last_warned_at IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.topup_executions te
      WHERE te.sim_line_id = r.sim_line_id AND te.status = 'success' AND te.created_at > r.last_warned_at
    ) THEN
      IF NOT p_dry_run THEN
        UPDATE public.sim_line_rescue_policy SET last_warned_at = NULL
         WHERE sim_line_rescue_policy.sim_line_id = r.sim_line_id;
      END IF;
      RETURN QUERY SELECT r.sim_line_id, v_label, 'reset'::text,
                          'user topped up after the warning'::text, NULL::numeric, NULL::uuid;
      CONTINUE;
    END IF;

    IF r.last_rescue_at IS NOT NULL
       AND r.last_rescue_at > now() - make_interval(days => v_cooldown_days::int) THEN
      RETURN QUERY SELECT r.sim_line_id, v_label, 'skipped'::text,
                          format('rescued already within %s days', v_cooldown_days::int), NULL::numeric, NULL::uuid;
      CONTINUE;
    END IF;

    IF r.last_warned_at IS NULL THEN
      IF NOT p_dry_run THEN
        INSERT INTO public.notifications (user_id, category, title, body, action_url, sim_line_id)
        VALUES (r.user_id, 'line_critical', format('%s needs a top-up', v_label),
          format('About %s day(s) of validity left. SIM Shield will top it up automatically in %s hour(s) if you do not - up to $%s.',
                 GREATEST(r.days_remaining, 0), v_grace_hours::int, to_char(r.max_usd, 'FM999990.00')),
          '/sim-lines/' || r.sim_line_id::text, r.sim_line_id);
        UPDATE public.sim_line_rescue_policy SET last_warned_at = now()
         WHERE sim_line_rescue_policy.sim_line_id = r.sim_line_id;
      END IF;
      RETURN QUERY SELECT r.sim_line_id, v_label, 'warned'::text,
                          format('%s days left; grace starts now', r.days_remaining), NULL::numeric, NULL::uuid;
      CONTINUE;
    END IF;

    IF r.days_remaining > r.lead_days THEN
      RETURN QUERY SELECT r.sim_line_id, v_label, 'skipped'::text,
                          format('warned; %s days left, rescue at %s', r.days_remaining, r.lead_days), NULL::numeric, NULL::uuid;
      CONTINUE;
    END IF;

    IF now() - r.last_warned_at < make_interval(hours => v_grace_hours::int) THEN
      RETURN QUERY SELECT r.sim_line_id, v_label, 'skipped'::text,
                          format('inside the %s-hour grace window', v_grace_hours::int), NULL::numeric, NULL::uuid;
      CONTINUE;
    END IF;

    IF EXISTS (
      SELECT 1 FROM public.topup_executions te
      WHERE te.sim_line_id = r.sim_line_id
        AND te.status IN ('pending', 'pending_payment', 'routing', 'processing')
    ) THEN
      RETURN QUERY SELECT r.sim_line_id, v_label, 'skipped'::text,
                          'a refill is already in flight'::text, NULL::numeric, NULL::uuid;
      CONTINUE;
    END IF;

    IF v_spent >= v_max_per_run THEN
      RETURN QUERY SELECT r.sim_line_id, v_label, 'skipped'::text,
                          format('run capped at %s rescues', v_max_per_run), NULL::numeric, NULL::uuid;
      CONTINUE;
    END IF;

    SELECT * INTO v_offer
    FROM public.carrier_refill_offer(r.carrier_id, r.suggested_amount_usd);

    IF v_offer.offer_code IS NULL THEN
      RETURN QUERY SELECT r.sim_line_id, v_label, 'skipped'::text,
                          'no top-up offer known for this line'::text, NULL::numeric, NULL::uuid;
      CONTINUE;
    END IF;

    IF v_offer.is_stale THEN
      RETURN QUERY SELECT r.sim_line_id, v_label, 'skipped'::text,
                          format('offer %s pricing is over 24h old', v_offer.offer_code), NULL::numeric, NULL::uuid;
      CONTINUE;
    END IF;

    v_base  := v_offer.price_usd;
    v_value := CASE WHEN v_offer.offer_value IS NULL THEN NULL ELSE v_offer.offer_value::bigint END;

    IF v_base IS NULL OR v_base <= 0 THEN
      RETURN QUERY SELECT r.sim_line_id, v_label, 'skipped'::text, 'offer has no usable price'::text, NULL::numeric, NULL::uuid;
      CONTINUE;
    END IF;

    IF v_base > r.max_usd THEN
      RETURN QUERY SELECT r.sim_line_id, v_label, 'skipped'::text,
                          format('cheapest top-up $%s is over the $%s limit',
                                 to_char(v_base, 'FM999990.00'), to_char(r.max_usd, 'FM999990.00')), v_base, NULL::uuid;
      CONTINUE;
    END IF;

    IF r.balance < v_base THEN
      RETURN QUERY SELECT r.sim_line_id, v_label, 'skipped'::text,
                          format('wallet has $%s, needs $%s',
                                 to_char(r.balance, 'FM999990.00'), to_char(v_base, 'FM999990.00')), v_base, NULL::uuid;
      CONTINUE;
    END IF;

    IF p_dry_run THEN
      RETURN QUERY SELECT r.sim_line_id, v_label, 'rescued'::text,
                          format('DRY RUN: would buy %s for $%s', v_offer.offer_code, to_char(v_base, 'FM999990.00')),
                          v_base, NULL::uuid;
      v_spent := v_spent + 1;
      CONTINUE;
    END IF;

    BEGIN
      INSERT INTO public.topup_executions (
        sim_line_id, user_id, amount, base_cost_usd, payment_gateway_code,
        currency, status, execution_type, execution_time, offer_id, offer_value, api_provider
      ) VALUES (
        r.sim_line_id, r.user_id, v_base, v_base, 'wallet',
        'USD', 'pending', 'refill_instant', now(), v_offer.offer_code, v_value, v_offer.provider_code
      ) RETURNING id, amount INTO v_exec_id, v_charged;

      IF v_charged > r.max_usd THEN
        RAISE EXCEPTION 'RESCUE_OVER_CAP:%:%', v_charged, r.max_usd USING ERRCODE = 'KS402';
      END IF;
      IF v_charged > r.balance THEN
        RAISE EXCEPTION 'RESCUE_NO_FUNDS:%:%', v_charged, r.balance USING ERRCODE = 'KS402';
      END IF;

      INSERT INTO public.line_activity_log (sim_line_id, user_id, event_type, description, metadata)
      VALUES (r.sim_line_id, r.user_id, 'rescue_topup_triggered',
        format('SIM Shield auto-topped up $%s to keep this line alive', to_char(v_charged, 'FM999990.00')),
        jsonb_build_object('execution_id', v_exec_id, 'offer_id', v_offer.offer_code,
          'provider', v_offer.provider_code,
          'base_cost_usd', v_base, 'charged_usd', v_charged, 'max_usd', r.max_usd,
          'days_remaining', r.days_remaining, 'warned_at', r.last_warned_at, 'grace_hours', v_grace_hours));

      INSERT INTO public.notifications (user_id, category, title, body, action_url, sim_line_id)
      VALUES (r.user_id, 'system', format('SIM Shield rescued %s', v_label),
        format('You had about %s day(s) left and had not topped up, so we spent $%s from your wallet to keep the line alive. Switch this off any time in the line settings.',
               GREATEST(r.days_remaining, 0), to_char(v_charged, 'FM999990.00')),
        '/sim-lines/' || r.sim_line_id::text, r.sim_line_id);

      UPDATE public.sim_line_rescue_policy
         SET last_rescue_at = now(), last_rescue_execution_id = v_exec_id,
             rescue_count = rescue_count + 1, last_warned_at = NULL
       WHERE sim_line_rescue_policy.sim_line_id = r.sim_line_id;

      v_spent := v_spent + 1;
      RETURN QUERY SELECT r.sim_line_id, v_label, 'rescued'::text,
                          format('bought %s, charged $%s of a $%s limit', v_offer.offer_code,
                                 to_char(v_charged, 'FM999990.00'), to_char(r.max_usd, 'FM999990.00')),
                          v_charged, v_exec_id;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN QUERY SELECT r.sim_line_id, v_label, 'skipped'::text,
                            format('%s %s', SQLSTATE, left(SQLERRM, 120)), v_base, NULL::uuid;
    END;
  END LOOP;
  RETURN;
END $function$;

-- -----------------------------------------------------------------------------
-- 8. The columns themselves are dropped in K4, not here
-- -----------------------------------------------------------------------------
-- admin_list_carriers, admin_update_carrier and admin_overview still read them
-- at this point. plpgsql bodies are NOT validated when a column is dropped, so
-- dropping here would succeed silently and leave those three raising 42703 the
-- next time an operator opened the admin app - a failure that reads as "the
-- admin app broke", not as "a migration removed a column". K4 rewrites them
-- first, then drops.
