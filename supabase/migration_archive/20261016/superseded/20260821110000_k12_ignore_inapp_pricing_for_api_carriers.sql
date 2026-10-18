-- =============================================================================
-- Migration K12: Ignore inapp_pricing for API-fulfilled carriers
-- =============================================================================
-- `inapp_pricing` is an override for MANUAL and TASKER_SCRIPT carriers.
-- For API-fulfilled carriers, pricing must always be derived dynamically from
-- actual live supplier catalog offers (v_from_cost).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.plan_price_net(
  p_plan            text DEFAULT 'standard'::text,
  p_sim_line_id     uuid DEFAULT NULL::uuid,
  p_carrier_rule_id uuid DEFAULT NULL::uuid
) RETURNS numeric
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_rule                 record;
  v_offer                record;
  v_base_fee             numeric;
  v_app_fee_pct          numeric;
  v_margin_pct           numeric;
  v_margin_flat          numeric;
  v_step                 integer;
  v_refills              integer;
  v_qualifying           numeric;
  v_from_cost            numeric;
  v_per_refill           numeric;
  v_fulfillment_gateway  text;
BEGIN
  IF p_plan IS NULL OR p_plan = 'standard' THEN
    SELECT COALESCE(config_value::numeric, 2.50) INTO v_base_fee
    FROM public.system_configs WHERE config_key = 'BASE_SERVICE_FEE_USD';
    RETURN COALESCE(v_base_fee, 2.50);
  END IF;

  IF p_plan <> 'premium' THEN
    RAISE EXCEPTION 'Unknown plan type: %', p_plan USING ERRCODE = '22023';
  END IF;

  SELECT COALESCE(config_value::numeric, 2.50) INTO v_base_fee
  FROM public.system_configs WHERE config_key = 'BASE_SERVICE_FEE_USD';
  v_base_fee := COALESCE(v_base_fee, 2.50);

  -- Resolve carrier rule
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

  v_qualifying := COALESCE(v_rule.validity_qualifying_topup_amount,
                           v_rule.minimum_topup_amount);

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

  -- Fetch fulfillment gateway for the carrier
  SELECT COALESCE(c.fulfillment_gateway, 'API') INTO v_fulfillment_gateway
  FROM public.carriers c
  WHERE c.id = v_rule.carrier_id;

  -- `inapp_pricing` is ONLY used for non-API carriers (MANUAL / TASKER_SCRIPT).
  -- For API carriers, pricing MUST be derived from actual live supplier catalog offers.
  IF v_fulfillment_gateway = 'API' THEN
    v_per_refill := v_from_cost;
  ELSE
    v_per_refill := GREATEST(COALESCE(v_rule.inapp_pricing, 0), v_from_cost);
  END IF;

  RETURN v_base_fee + (v_per_refill * v_refills);
END;
$function$;
