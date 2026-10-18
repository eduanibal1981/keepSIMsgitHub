-- Supersedes the October 4 definitions on both fresh replay and upgrades.
-- The historical migration is retained unchanged for applied environments.
BEGIN;

CREATE OR REPLACE FUNCTION public.resolve_line_entitlement(p_sim_line_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE l public.sim_lines; v_tier text:='free'; v_paid boolean:=false; v_expired boolean;
BEGIN
  SELECT * INTO l FROM public.sim_lines WHERE id=p_sim_line_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('found',false,'effective_tier','free','is_paid',false,'is_premium',false,'automation_eligible',false); END IF;
  v_expired:=l.plan_expires_at IS NULL OR l.plan_expires_at<=now();
  IF l.status='active' AND lower(l.plan_type) IN ('standard','premium') AND NOT v_expired THEN
    v_paid:=EXISTS(SELECT 1 FROM public.plan_payments p WHERE p.sim_line_id=l.id AND p.user_id=l.user_id
      AND p.kind='plan' AND p.net_usd>0 AND lower(p.metadata->>'plan')=lower(l.plan_type)
      AND p.created_at>=greatest(now()-interval '365 days',l.plan_expires_at-interval '366 days') AND p.created_at<=now())
      OR EXISTS(SELECT 1 FROM public.wallet_transactions t WHERE t.user_id=l.user_id
        AND (t.sim_line_id=l.id OR t.metadata->>'sim_line_id'=l.id::text
          OR EXISTS(SELECT 1 FROM public.sim_setup_orders o WHERE o.id::text=t.metadata->>'setup_order_id'
            AND o.sim_line_id=l.id AND o.user_id=l.user_id AND o.status='active'))
        AND t.type='plan_fee_debit' AND t.status='completed' AND t.amount>0
        AND t.balance_before-t.balance_after=t.amount
        AND (lower(t.metadata->>'plan')=lower(l.plan_type)
          OR (t.metadata->>'plan' IS NULL AND lower(t.description) LIKE '%'||lower(l.plan_type)||'%'))
        AND t.created_at>=greatest(now()-interval '365 days',l.plan_expires_at-interval '366 days') AND t.created_at<=now());
    -- Retain the explicit server-maintained legacy Premium promotion policy.
    v_paid:=v_paid OR (lower(l.plan_type)='premium' AND EXISTS(
      SELECT 1 FROM public.premium_entitlement_grandfather g WHERE g.sim_line_id=l.id));
    IF v_paid THEN v_tier:=lower(l.plan_type); END IF;
  END IF;
  RETURN jsonb_build_object('found',true,'sim_line_id',l.id,'user_id',l.user_id,'plan_type',l.plan_type,
    'protection_tier',l.protection_tier,'effective_tier',v_tier,'is_paid',v_paid,
    'is_premium',v_tier='premium','is_expired',v_expired,'expires_at',l.plan_expires_at,
    'automation_eligible',v_tier='premium');
END;
$$;
REVOKE ALL ON FUNCTION public.resolve_line_entitlement(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_line_entitlement(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.has_paid_premium_entitlement(p_sim_line_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
  SELECT coalesce((public.resolve_line_entitlement(p_sim_line_id)->>'is_premium')::boolean,false);
$$;
REVOKE ALL ON FUNCTION public.has_paid_premium_entitlement(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.has_paid_premium_entitlement(uuid) TO service_role;

CREATE FUNCTION public.assert_pricing_line_owner(p_sim_line_id uuid)
RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF auth.uid() IS NULL AND coalesce(auth.role(),'')<>'service_role' THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501';
  END IF;
  IF p_sim_line_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.sim_lines WHERE id=p_sim_line_id
    AND (user_id=auth.uid() OR coalesce(auth.role(),'')='service_role')) THEN
    RAISE EXCEPTION 'SIM ownership required' USING ERRCODE='42501';
  END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.assert_pricing_line_owner(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.assert_pricing_line_owner(uuid) TO service_role;

-- A missing rule is NULL; a published zero is a valid fee. Draft/retired/future
-- rules cannot silently become customer pricing.
CREATE OR REPLACE FUNCTION public.resolve_app_fee(p_item text,p_tier text,p_base_amount numeric)
RETURNS numeric LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.app_fee_rules; v_pct numeric; v_min numeric;
BEGIN
  IF p_base_amount IS NULL OR p_base_amount<0 THEN RAISE EXCEPTION 'Invalid fee basis'; END IF;
  SELECT * INTO r FROM public.app_fee_rules WHERE appfees_item=p_item AND status='published'
    AND (effective_from IS NULL OR effective_from<=now()) AND (effective_to IS NULL OR effective_to>now())
    ORDER BY version DESC LIMIT 1;
  IF NOT FOUND THEN RETURN NULL; END IF;
  v_pct:=CASE lower(p_tier) WHEN 'premium' THEN r.prem_percentage WHEN 'standard' THEN r.stand_percentage ELSE r.free_percentage END;
  v_min:=CASE lower(p_tier) WHEN 'premium' THEN r.prem_minimum WHEN 'standard' THEN r.stand_minimum ELSE r.free_minimum END;
  IF p_item='intelcallfee' THEN RETURN round(p_base_amount*coalesce(v_pct,0)/100,4); END IF;
  RETURN round(greatest(p_base_amount*coalesce(v_pct,0)/100,coalesce(v_min,0)),2);
END;
$$;
REVOKE ALL ON FUNCTION public.resolve_app_fee(text,text,numeric) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_app_fee(text,text,numeric) TO service_role;

CREATE FUNCTION public.membership_fee_usd(p_plan text)
RETURNS numeric LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE v_fee numeric;
BEGIN
  IF p_plan NOT IN ('standard','premium') OR p_plan IS NULL THEN RAISE EXCEPTION 'Invalid paid plan'; END IF;
  SELECT config_value::numeric INTO v_fee FROM public.system_configs WHERE config_key=CASE p_plan
    WHEN 'standard' THEN 'MEMBERSHIP_FEE_STANDARD_USD' ELSE 'MEMBERSHIP_FEE_PREMIUM_USD' END;
  IF v_fee IS NULL AND p_plan='standard' THEN
    SELECT config_value::numeric INTO v_fee FROM public.system_configs WHERE config_key='BASE_SERVICE_FEE_USD';
  END IF;
  v_fee:=coalesce(v_fee,CASE p_plan WHEN 'standard' THEN 2.50 ELSE 5.00 END);
  IF v_fee<0 THEN RAISE EXCEPTION 'Invalid membership fee'; END IF;
  RETURN round(v_fee,2);
END;
$$;
REVOKE ALL ON FUNCTION public.membership_fee_usd(text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.membership_fee_usd(text) TO service_role;
-- Bound upgrade credit by the settled Standard amount, so a paid discounted
-- membership cannot claim today's larger configurable fee as prior payment.
CREATE FUNCTION public.standard_upgrade_credit_usd(p_sim_line_id uuid)
RETURNS numeric LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE l public.sim_lines; v_paid numeric;
BEGIN
  IF public.resolve_line_entitlement(p_sim_line_id)->>'effective_tier'<>'standard' THEN RETURN 0; END IF;
  SELECT * INTO l FROM public.sim_lines WHERE id=p_sim_line_id;
  SELECT max(amount) INTO v_paid FROM (
    SELECT p.net_usd AS amount FROM public.plan_payments p WHERE p.sim_line_id=l.id AND p.user_id=l.user_id
      AND p.kind='plan' AND lower(p.metadata->>'plan')='standard' AND p.net_usd>0
      AND p.created_at>=greatest(now()-interval '365 days',l.plan_expires_at-interval '366 days') AND p.created_at<=now()
    UNION ALL
    SELECT t.amount FROM public.wallet_transactions t WHERE t.user_id=l.user_id
      AND (t.sim_line_id=l.id OR t.metadata->>'sim_line_id'=l.id::text
        OR EXISTS(SELECT 1 FROM public.sim_setup_orders o WHERE o.id::text=t.metadata->>'setup_order_id'
          AND o.sim_line_id=l.id AND o.user_id=l.user_id AND o.status='active'))
      AND t.type='plan_fee_debit' AND t.status='completed' AND t.balance_before-t.balance_after=t.amount
      AND (lower(t.metadata->>'plan')='standard' OR (t.metadata->>'plan' IS NULL AND lower(t.description) LIKE '%standard%'))
      AND t.created_at>=greatest(now()-interval '365 days',l.plan_expires_at-interval '366 days') AND t.created_at<=now()
  ) receipts;
  RETURN least(coalesce(v_paid,0),public.membership_fee_usd('standard'),public.membership_fee_usd('premium'));
END;
$$;
REVOKE ALL ON FUNCTION public.standard_upgrade_credit_usd(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.standard_upgrade_credit_usd(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.quote_premium_breakdown(
  p_carrier_rule_id UUID DEFAULT NULL,
  p_sim_line_id     UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_rule                 record;
  v_offer                record;
  v_base_fee             numeric;
  v_credit numeric:=0;
  v_full_fee numeric;
  v_app_fee              numeric;
  v_step                 integer;
  v_qualifying           numeric;
  v_first_refill         numeric;
  v_total                numeric;
  v_fulfillment_gateway  text;
BEGIN
  PERFORM public.assert_pricing_line_owner(p_sim_line_id);
  v_full_fee:=public.membership_fee_usd('premium');
  IF (public.resolve_line_entitlement(p_sim_line_id)->>'effective_tier')='standard' THEN
    v_credit:=public.standard_upgrade_credit_usd(p_sim_line_id);
  END IF;
  v_base_fee:=v_full_fee-v_credit;

  SELECT cr.id, cr.carrier_id, cr.minimum_topup_amount, cr.inactivity_limit_days,
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

  IF v_rule.activity_requirement='usage_required' OR (v_rule.activity_requirement='min_denomination'
    AND v_rule.minimum_topup_amount<v_rule.validity_qualifying_topup_amount) THEN
    RAISE EXCEPTION 'Carrier validity cannot be fulfilled' USING ERRCODE='KS422';
  END IF;
  v_step := public.refill_interval_days(
              v_rule.inactivity_limit_days, v_rule.refill_interval_days_override);

  IF v_step IS NULL OR v_step<1 THEN RAISE EXCEPTION 'Invalid refill cadence'; END IF;
  v_qualifying := COALESCE(v_rule.validity_qualifying_topup_amount,
                           v_rule.minimum_topup_amount);

  SELECT * INTO v_offer
  FROM public.carrier_refill_offer(v_rule.carrier_id, v_qualifying);

  IF v_offer.offer_code IS NULL THEN
    RAISE EXCEPTION
      'No supplier currently sells a top-up for this carrier that reaches the % USD its validity rules require.',
      to_char(v_qualifying, 'FM999990.00')
      USING ERRCODE = 'KS422';
  END IF;

  -- Apply 3% ($0.10 min) fee rule for Premium line refill
  v_app_fee := coalesce(public.resolve_app_fee('refills','premium',v_offer.price_usd),round(greatest(v_offer.price_usd*0.03,0.03),2));

  SELECT COALESCE(c.fulfillment_gateway, 'API') INTO v_fulfillment_gateway
  FROM public.carriers c
  WHERE c.id = v_rule.carrier_id;

  IF v_fulfillment_gateway = 'API' THEN
    v_first_refill := round(v_offer.price_usd + v_app_fee, 2);
  ELSE
    v_first_refill := round(GREATEST(COALESCE(v_rule.inapp_pricing, 0), v_offer.price_usd + v_app_fee), 2);
  END IF;

  v_total := round(v_base_fee + v_first_refill, 2);

  RETURN jsonb_build_object(
    'success', true,
    'is_upgrade',v_credit>0,'upgrade_credit_usd',v_credit,'full_annual_fee_usd',v_full_fee,
    'carrier_rule_id', v_rule.id,
    'annual_fee_usd', round(v_base_fee, 2),
    'first_refill_cost_usd', v_first_refill,
    'total_charge_usd', v_total,
    'refill_interval_days', v_step,
    'provider_code', v_offer.provider_code,
    'offer_code', v_offer.offer_code,
    'delivery_type', v_offer.delivery_type
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.quote_premium_breakdown(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.quote_premium_breakdown(uuid,uuid) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.plan_price_net(p_plan text DEFAULT 'standard',p_sim_line_id uuid DEFAULT NULL,p_carrier_rule_id uuid DEFAULT NULL)
RETURNS numeric LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF lower(coalesce(p_plan,'standard'))='standard' THEN RETURN public.membership_fee_usd('standard'); END IF;
  IF lower(p_plan)<>'premium' THEN RAISE EXCEPTION 'Invalid plan'; END IF;
  RETURN (public.quote_premium_breakdown(p_carrier_rule_id,p_sim_line_id)->>'total_charge_usd')::numeric;
END;
$$;

REVOKE ALL ON FUNCTION public.plan_price_net(text,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.plan_price_net(text,uuid,uuid) TO service_role;
CREATE OR REPLACE FUNCTION public.quote_sim_setup(
  p_phone_number    TEXT,
  p_plan            TEXT,
  p_carrier_rule_id UUID DEFAULT NULL,
  p_sim_line_id     UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_annual_fee       NUMERIC := 0.00;
  v_first_refill     NUMERIC := 0.00;
  v_total            NUMERIC := 0.00;
  v_interval_days    INTEGER := 30;
  v_free_eligible    BOOLEAN := true;
  v_premium_quote    JSONB;
  v_standard_fee     NUMERIC := 2.50;
  v_is_upgrade       BOOLEAN := false;
  v_upgrade_credit   NUMERIC := 0.00;
  v_full_annual_fee  NUMERIC := 5.00;
BEGIN
  PERFORM public.assert_pricing_line_owner(p_sim_line_id);
  -- Check Free eligibility
  SELECT NOT EXISTS (
    SELECT 1 FROM public.free_line_grants
    WHERE phone_e164 = p_phone_number
      AND (p_sim_line_id IS NULL OR sim_line_id <> p_sim_line_id)
  ) INTO v_free_eligible;

  IF p_plan = 'free' THEN
    v_annual_fee := 0.00;
    v_first_refill := 0.00;
    v_total := 0.00;
  ELSIF p_plan = 'standard' THEN
    v_annual_fee:=public.membership_fee_usd('standard');
    v_first_refill := 0.00;
    v_total := v_annual_fee;
  ELSIF p_plan = 'premium' THEN
    v_premium_quote := public.quote_premium_breakdown(p_carrier_rule_id, p_sim_line_id);
    v_annual_fee := (v_premium_quote->>'annual_fee_usd')::numeric;
    v_first_refill := (v_premium_quote->>'first_refill_cost_usd')::numeric;
    v_total := (v_premium_quote->>'total_charge_usd')::numeric;
    v_interval_days := (v_premium_quote->>'refill_interval_days')::integer;
    v_is_upgrade := COALESCE((v_premium_quote->>'is_upgrade')::boolean, false);
    v_upgrade_credit := COALESCE((v_premium_quote->>'upgrade_credit_usd')::numeric, 0.00);
    v_full_annual_fee := COALESCE((v_premium_quote->>'full_annual_fee_usd')::numeric, 5.00);
  ELSE
    RAISE EXCEPTION 'Invalid plan: %', p_plan;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'plan', p_plan,
    'phone_number', p_phone_number,
    'annual_fee_usd', v_annual_fee,
    'first_refill_cost_usd', v_first_refill,
    'total_charge_usd', v_total,
    'refill_interval_days', v_interval_days,
    'free_eligible', v_free_eligible,
    'is_upgrade', v_is_upgrade,
    'upgrade_credit_usd', v_upgrade_credit,
    'full_annual_fee_usd', v_full_annual_fee
  );
END;
$$;

REVOKE ALL ON FUNCTION public.quote_sim_setup(text,text,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.quote_sim_setup(text,text,uuid,uuid) TO authenticated,service_role;
CREATE OR REPLACE FUNCTION public.pay_plan_fee_from_wallet(
  p_reference_id    text,
  p_sim_line_id     uuid DEFAULT NULL::uuid,
  p_device_id       text DEFAULT NULL::text,
  p_plan            text DEFAULT 'standard'::text,
  p_carrier_rule_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id     uuid := auth.uid();
  v_plan        text := lower(coalesce(p_plan, 'standard'));
  v_fee         numeric(10,2);
  v_balance     numeric(10,2);
  v_existing    RECORD;
  v_guard       jsonb;
  v_line        RECORD;
  v_desc        text;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  IF EXISTS (SELECT 1 FROM public.profiles WHERE id = v_user_id AND is_suspended = true) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Account is suspended.');
  END IF;

  IF p_sim_line_id IS NOT NULL AND NOT EXISTS (
       SELECT 1 FROM public.sim_lines WHERE id = p_sim_line_id AND user_id = v_user_id) THEN
    RAISE EXCEPTION 'SIM line % does not belong to user %', p_sim_line_id, v_user_id;
  END IF;

  PERFORM public.enforce_rate_limit('plan_fee', v_user_id::text);

  IF nullif(btrim(p_reference_id),'') IS NULL THEN RAISE EXCEPTION 'Payment reference required'; END IF;
  PERFORM 1 FROM public.wallets WHERE user_id=v_user_id FOR UPDATE;
  -- Idempotency first: a replay is answered from the ledger, never re-priced.
  SELECT id, amount INTO v_existing
  FROM public.wallet_transactions
  WHERE reference_id=p_reference_id AND type='plan_fee_debit' AND user_id=v_user_id;
  IF FOUND AND NOT EXISTS(SELECT 1 FROM public.wallet_transactions WHERE id=v_existing.id
    AND sim_line_id IS NOT DISTINCT FROM p_sim_line_id AND (metadata->>'plan'=v_plan
      OR (metadata->>'plan' IS NULL AND lower(description) LIKE '%'||v_plan||'%'))) THEN
    RAISE EXCEPTION 'Plan payment reference mismatch';
  END IF;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'success', true,
      'already_paid', true,
      'transaction_id', v_existing.id,
      'amount', v_existing.amount,
      'plan', v_plan,
      'reference_id', p_reference_id
    );
  END IF;

  -- Priced server-side with upgrade credit if applicable
  v_fee := round(public.plan_price_net(v_plan, p_sim_line_id, p_carrier_rule_id), 2);

  IF v_fee IS NULL OR v_fee <= 0 THEN
    RAISE EXCEPTION 'Plan % has no usable price', v_plan USING ERRCODE = '22023';
  END IF;

  SELECT COALESCE(balance, 0.00) INTO v_balance
  FROM public.wallets WHERE user_id = v_user_id;

  IF v_balance < v_fee THEN
    RAISE EXCEPTION 'Insufficient wallet balance ($%) for plan fee ($%).', v_balance, v_fee;
  END IF;

  v_guard := public.guard_money_action('plan_fee', v_fee, p_device_id, p_reference_id, v_user_id);
  IF (v_guard ->> 'blocked')::boolean THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'DEVICE_BLOCKED',
      'reason', v_guard ->> 'reason',
      'error', 'This payment was stopped by a security check on this device. Contact support if this is a mistake.'
    );
  END IF;

  v_desc:='Annual Plan Fee Debit ('||v_plan||')';

  v_existing.id:=public.debit_wallet_for_topup(
    v_user_id, p_sim_line_id, v_fee,
    v_desc,
    p_reference_id, 'plan_fee_debit'
  );

  UPDATE public.wallet_transactions SET metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('plan',v_plan,'sim_line_id',p_sim_line_id) WHERE id=v_existing.id;
  -- Atomic update of SIM Line: plan_type, protection_tier, and fresh 365-day reward!
  IF p_sim_line_id IS NOT NULL THEN
    UPDATE public.sim_lines
    SET plan_type = v_plan,
        protection_tier = CASE WHEN v_plan = 'free' THEN 'basic' ELSE v_plan END,
        plan_expires_at = clock_timestamp() + INTERVAL '365 days',
        updated_at = clock_timestamp()
    WHERE id = p_sim_line_id AND user_id = v_user_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'amount', v_fee,
    'plan', v_plan,
    'reference_id', p_reference_id
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.pay_plan_fee_from_wallet(text,uuid,text,text,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.pay_plan_fee_from_wallet(text,uuid,text,text,uuid) TO authenticated,service_role;
CREATE OR REPLACE FUNCTION public.quote_plan_price(
  p_sim_line_id     uuid DEFAULT NULL::uuid,
  p_plan            text DEFAULT 'standard'::text,
  p_gateway         text DEFAULT 'paypal'::text,
  p_carrier_rule_id uuid DEFAULT NULL::uuid
)
RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_gw_pct   numeric;
  v_gw_fixed numeric;
  v_net      numeric;
BEGIN
  PERFORM public.assert_pricing_line_owner(p_sim_line_id);
  IF p_gateway='wallet' THEN RETURN round(public.plan_price_net(p_plan,p_sim_line_id,p_carrier_rule_id),2); END IF;
  IF p_sim_line_id IS NOT NULL AND auth.uid() IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.sim_lines
      WHERE id = p_sim_line_id AND user_id = auth.uid()
    ) THEN
      RAISE EXCEPTION 'FORBIDDEN: SIM line does not belong to caller' USING ERRCODE = '42501';
    END IF;
  END IF;

  -- Doctrine: payment_gateways is the source of truth for what a gateway costs.
  SELECT fee_percentage, fee_fixed
  INTO v_gw_pct, v_gw_fixed
  FROM public.payment_gateways
  WHERE code = p_gateway AND is_active = true;

  IF NOT FOUND OR v_gw_pct IS NULL OR v_gw_fixed IS NULL THEN
    RAISE EXCEPTION 'Gateway % is not active or missing rates in payment_gateways', p_gateway
      USING ERRCODE = '22023';
  END IF;

  v_net := public.plan_price_net(p_plan, p_sim_line_id, p_carrier_rule_id);

  -- Grossed up, not marked up: solving `charged - (charged*pct + fixed) = net`
  -- leaves exactly the net behind after the gateway takes its cut.
  -- A gateway at 100% can never be covered; such a row is a data error, not a
  -- price, so charge the raw net rather than divide by zero.
  IF v_gw_pct>=100 OR v_gw_pct<0 OR v_gw_fixed<0 THEN
    RAISE EXCEPTION 'Invalid gateway fee policy' USING ERRCODE='22023';
  END IF;

  RETURN round((v_net + v_gw_fixed) / (1.0 - (v_gw_pct / 100.0)), 2);
END;
$function$;

REVOKE ALL ON FUNCTION public.quote_plan_price(uuid,text,text,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.quote_plan_price(uuid,text,text,uuid) TO authenticated,service_role;
CREATE OR REPLACE FUNCTION public.calculate_topup_fees()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_line_tier       TEXT := 'free';
  v_entitlement     JSONB;
  v_app_fee         NUMERIC;
  v_msg_fee         NUMERIC := 0.00;
  v_msg_fee_key     TEXT;
  pm                RECORD;
BEGIN
  IF NEW.payment_gateway_code IS NOT NULL AND NEW.base_cost_usd IS NOT NULL THEN
    SELECT * INTO pm FROM public.payment_gateways WHERE code = NEW.payment_gateway_code;

    IF FOUND THEN
      -- Resolve line tier
      IF NEW.sim_line_id IS NOT NULL THEN
        v_entitlement := public.resolve_line_entitlement(NEW.sim_line_id);
        v_line_tier := COALESCE(v_entitlement->>'effective_tier', 'free');
      END IF;

      -- Resolve app fee from app_fee_rules
      v_app_fee := public.resolve_app_fee('refills', v_line_tier, NEW.base_cost_usd);

      -- Fallback if no published rule existed
      IF v_app_fee IS NULL THEN
        v_app_fee := round(greatest(NEW.base_cost_usd * 0.03, 0.03), 2);
      END IF;

      -- Offline messaging fees if applicable
      IF NEW.refill_channel IS NOT NULL THEN
        v_msg_fee_key := CASE NEW.refill_channel
          WHEN 'whatsapp'    THEN 'OFFLINE_WHATSAPP_MESSAGE_FEE_USD'
          WHEN 'sms'         THEN 'OFFLINE_SMS_MESSAGE_FEE_USD'
          WHEN 'missed_call' THEN 'OFFLINE_MISSED_CALL_FEE_USD'
        END;
        BEGIN
          SELECT config_value::numeric INTO v_msg_fee
          FROM public.system_configs
          WHERE config_key = v_msg_fee_key;
        EXCEPTION WHEN others THEN
          v_msg_fee := 0;
        END;
        v_msg_fee := coalesce(v_msg_fee, 0);
      END IF;

      NEW.app_fee_usd := v_app_fee;
      NEW.amount := round(NEW.base_cost_usd + v_app_fee + v_msg_fee, 2);

      -- Fee calculation must preserve an explicit customer spending limit.
      IF NEW.max_authorized_usd IS NULL THEN
        NEW.max_authorized_usd := NEW.amount;
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.calculate_topup_fees() FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.calculate_topup_fees() TO service_role;
CREATE OR REPLACE FUNCTION public.resolve_esim_offer_price(
  p_wholesale_price NUMERIC,
  p_user_id         UUID DEFAULT auth.uid()
)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_tier TEXT;
  v_fee  NUMERIC;
BEGIN
  IF p_wholesale_price IS NULL OR p_wholesale_price <= 0 THEN
    RETURN 0.00;
  END IF;

  v_tier := public.resolve_account_commerce_benefit(p_user_id);
  v_fee := public.resolve_app_fee('esimofferfee', v_tier, p_wholesale_price);
  
  IF v_fee IS NULL THEN
    v_fee := CASE v_tier
      WHEN 'premium'  THEN round(p_wholesale_price * 0.05, 2)
      WHEN 'standard' THEN round(p_wholesale_price * 0.07, 2)
      ELSE round(p_wholesale_price * 0.10, 2)
    END;
  END IF;
  
  RETURN round(p_wholesale_price + v_fee, 2);
END;
$$;

REVOKE ALL ON FUNCTION public.resolve_esim_offer_price(numeric,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.resolve_esim_offer_price(numeric,uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.create_sim_setup_order(
  p_phone_number    TEXT,
  p_plan            TEXT,
  p_carrier_rule_id UUID DEFAULT NULL,
  p_country_code    TEXT DEFAULT NULL,
  p_carrier_code    TEXT DEFAULT NULL,
  p_sim_line_id     UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_user_id             UUID;
  v_breakdown           JSONB;
  v_annual_fee          NUMERIC := 0.00;
  v_first_refill        NUMERIC := 0.00;
  v_total               NUMERIC := 0.00;
  v_order_id            UUID;
  v_existing            RECORD;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF p_plan NOT IN ('free', 'standard', 'premium') THEN
    RAISE EXCEPTION 'Invalid plan: %', p_plan;
  END IF;

  PERFORM public.assert_pricing_line_owner(p_sim_line_id);
  IF p_sim_line_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.sim_lines
    WHERE id=p_sim_line_id AND user_id=v_user_id AND phone_number=p_phone_number) THEN
    RAISE EXCEPTION 'Matching owned SIM required' USING ERRCODE='42501';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('sim-setup:'||v_user_id||':'||p_phone_number||':'||p_plan,0));
  v_breakdown:=public.quote_sim_setup(p_phone_number,p_plan,p_carrier_rule_id,p_sim_line_id);
  v_annual_fee:=(v_breakdown->>'annual_fee_usd')::numeric;
  v_first_refill:=(v_breakdown->>'first_refill_cost_usd')::numeric;
  v_total:=(v_breakdown->>'total_charge_usd')::numeric;

  -- Reuse existing draft order for same phone and plan if active
  SELECT * INTO v_existing
  FROM public.sim_setup_orders
  WHERE user_id = v_user_id 
    AND phone_number = p_phone_number 
    AND plan = p_plan 
    AND status IN ('draft','awaiting_funds','reserved','dispatching')
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_existing.id IS NOT NULL THEN
    IF v_existing.sim_line_id IS NOT NULL AND p_sim_line_id IS NOT NULL AND v_existing.sim_line_id<>p_sim_line_id THEN
      RAISE EXCEPTION 'Setup already bound to another line';
    END IF;
    IF v_existing.status IN ('reserved','dispatching') THEN
      RETURN jsonb_build_object('success',true,'order_id',v_existing.id,'plan',v_existing.plan,
        'annual_fee_usd',v_existing.annual_fee_usd,'first_refill_cost_usd',v_existing.first_refill_cost_usd,
        'total_charge_usd',v_existing.total_charge_usd,'status',v_existing.status);
    END IF;
    UPDATE public.sim_setup_orders
    SET annual_fee_usd = v_annual_fee,
        first_refill_cost_usd = v_first_refill,
        total_charge_usd = v_total,
        carrier_rule_id = COALESCE(p_carrier_rule_id, carrier_rule_id),
        sim_line_id = COALESCE(p_sim_line_id, sim_line_id),
        updated_at = now()
    WHERE id = v_existing.id
    RETURNING id INTO v_order_id;
  ELSE
    INSERT INTO public.sim_setup_orders (
      user_id, sim_line_id, carrier_rule_id, plan, phone_number,
      country_code, carrier_code, annual_fee_usd, first_refill_cost_usd,
      total_charge_usd, status, created_at, updated_at
    ) VALUES (
      v_user_id, p_sim_line_id, p_carrier_rule_id, p_plan, p_phone_number,
      p_country_code, p_carrier_code, v_annual_fee, v_first_refill,
      v_total, 'draft', now(), now()
    ) RETURNING id INTO v_order_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'plan', p_plan,
    'phone_number', p_phone_number,
    'annual_fee_usd', v_annual_fee,
    'first_refill_cost_usd', v_first_refill,
    'total_charge_usd', v_total,
    'status', 'draft'
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.create_sim_setup_order(text,text,uuid,text,text,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.create_sim_setup_order(text,text,uuid,text,text,uuid) TO authenticated,service_role;

-- The reminder fallback was another direct balance/partial-ledger writer.
-- Reuse the setup capture contract instead of maintaining a second money path.
CREATE OR REPLACE FUNCTION public.fallback_sim_setup_to_reminders(p_order_id uuid,p_sim_line_id uuid,p_fallback_plan text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE o public.sim_setup_orders; v_fee numeric; v_hold uuid; v_available numeric;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  SELECT * INTO o FROM public.sim_setup_orders WHERE id=p_order_id AND user_id=auth.uid() FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Setup unavailable' USING ERRCODE='42501'; END IF;
  PERFORM 1 FROM public.sim_lines WHERE id=p_sim_line_id AND user_id=o.user_id AND phone_number=o.phone_number FOR UPDATE;
  IF NOT FOUND OR (o.sim_line_id IS NOT NULL AND o.sim_line_id<>p_sim_line_id) THEN
    RAISE EXCEPTION 'Matching owned SIM required' USING ERRCODE='42501'; END IF;
  IF p_fallback_plan IS NULL OR p_fallback_plan NOT IN ('free','standard') THEN RAISE EXCEPTION 'Invalid fallback plan'; END IF;
  IF o.status='active' THEN
    IF o.plan=p_fallback_plan THEN RETURN jsonb_build_object('success',true,'plan',o.plan,'already_captured',true); END IF;
    RAISE EXCEPTION 'Active setup cannot be replaced';
  END IF;
  IF o.status='dispatching' OR o.provider_tx_id IS NOT NULL OR EXISTS(
    SELECT 1 FROM public.topup_executions WHERE wallet_hold_id=o.first_refill_hold_id
      AND (status IN ('processing','success') OR reloadly_transaction_id IS NOT NULL OR carrier_in_flight)
  ) OR EXISTS(SELECT 1 FROM public.wallet_holds WHERE id IN (o.annual_fee_hold_id,o.first_refill_hold_id)
      AND (carrier_in_flight OR status='captured')) THEN
    RAISE EXCEPTION 'Setup requires delivery reconciliation before fallback';
  END IF;
  -- Lock the wallet before releasing or replacing reservations.
  PERFORM 1 FROM public.wallets WHERE user_id=o.user_id FOR UPDATE;
  PERFORM public.release_wallet_hold(id,'Switching to reminder protection') FROM public.wallet_holds
    WHERE id IN (o.annual_fee_hold_id,o.first_refill_hold_id) AND status='active';
  UPDATE public.topup_executions SET status='cancelled',failure_reason='Reminder protection selected',updated_at=now()
    WHERE wallet_hold_id=o.first_refill_hold_id AND status IN ('pending','routing','awaiting_funds');
  IF p_fallback_plan='standard' THEN
    v_fee:=public.membership_fee_usd('standard');
    SELECT w.balance-coalesce((SELECT sum(amount) FROM public.wallet_holds WHERE wallet_id=w.id AND status='active'),0)
      INTO v_available FROM public.wallets w WHERE w.user_id=o.user_id;
    IF v_available IS NULL OR v_available<v_fee THEN
      UPDATE public.sim_setup_orders SET plan='standard',status='awaiting_funds',sim_line_id=p_sim_line_id,
        annual_fee_usd=v_fee,first_refill_cost_usd=0,total_charge_usd=v_fee,annual_fee_hold_id=NULL,first_refill_hold_id=NULL,updated_at=now() WHERE id=o.id;
      RETURN jsonb_build_object('success',false,'code','insufficient_funds','available_balance',coalesce(v_available,0),'required',v_fee);
    END IF;
    IF v_fee>0 THEN v_hold:=public.reserve_wallet_funds(o.user_id,v_fee,'plan_fee','std_fallback_'||o.id); END IF;
    UPDATE public.sim_setup_orders SET plan='standard',status='reserved',sim_line_id=p_sim_line_id,
      annual_fee_usd=v_fee,first_refill_cost_usd=0,total_charge_usd=v_fee,
      annual_fee_hold_id=v_hold,first_refill_hold_id=NULL,updated_at=now() WHERE id=o.id;
    RETURN public.capture_sim_setup_holds(o.id);
  END IF;
  UPDATE public.sim_lines SET plan_type='free',protection_tier='basic',plan_expires_at=NULL,updated_at=now() WHERE id=p_sim_line_id;
  UPDATE public.scheduled_topups SET is_active=false,status='paused',updated_at=now()
    WHERE sim_line_id=p_sim_line_id AND schedule_type<>'notify';
  UPDATE public.sim_setup_orders SET plan='free',status='active',sim_line_id=p_sim_line_id,annual_fee_usd=0,
    first_refill_cost_usd=0,total_charge_usd=0,annual_fee_hold_id=NULL,first_refill_hold_id=NULL,updated_at=now() WHERE id=o.id;
  RETURN jsonb_build_object('success',true,'plan','free','expires_at',NULL);
END;
$$;
REVOKE ALL ON FUNCTION public.fallback_sim_setup_to_reminders(uuid,uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.fallback_sim_setup_to_reminders(uuid,uuid,text) TO authenticated,service_role;
COMMIT;
