BEGIN;

-- Explicit server-approved promotion/grandfather proof; never derived from a
-- client plan label. No historical balances or receipts are invented/backfilled.
CREATE TABLE public.line_plan_grants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sim_line_id uuid NOT NULL REFERENCES public.sim_lines(id),
  user_id uuid NOT NULL REFERENCES auth.users(id),
  plan text NOT NULL CHECK(plan IN ('standard','premium')),
  source text NOT NULL CHECK(source IN ('promotion','grandfather')),
  source_key text NOT NULL UNIQUE,
  credit_usd numeric(10,2) NOT NULL CHECK(credit_usd>=0 AND credit_usd::text NOT IN ('NaN','Infinity','-Infinity')),
  starts_at timestamptz NOT NULL DEFAULT now(), expires_at timestamptz NOT NULL,
  reason text NOT NULL CHECK(length(reason)>=10), revoked_at timestamptz,
  CHECK(expires_at>starts_at), CHECK(source<>'promotion' OR credit_usd=0)
);
ALTER TABLE public.line_plan_grants ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.line_plan_grants FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.line_plan_grants TO service_role;
REVOKE INSERT,UPDATE,DELETE,TRUNCATE ON public.plan_payments,public.premium_entitlement_grandfather FROM PUBLIC,anon,authenticated;
REVOKE INSERT,UPDATE,DELETE,TRUNCATE ON public.sim_setup_orders FROM PUBLIC,anon,authenticated;
ALTER TABLE public.sim_setup_orders ADD COLUMN pricing_snapshot jsonb,
  ADD COLUMN quote_expires_at timestamptz;

-- One evidence contract for both entitlement and upgrade credit. Legacy wallet
-- receipts remain valid without fabricating new funding lots or plan_payments.
CREATE FUNCTION public.line_paid_plan_evidence(p_sim_line_id uuid,p_plan text)
RETURNS TABLE(source_key text,paid_usd numeric,paid_at timestamptz,valid_until timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
  WITH line AS (
    SELECT * FROM public.sim_lines WHERE id=p_sim_line_id AND status='active'
      AND plan_expires_at>now() AND p_plan IN ('standard','premium')
  ), evidence AS (
    SELECT 'wallet:'||t.id AS source_key,t.amount AS paid_usd,t.created_at AS paid_at,
      least(l.plan_expires_at,t.created_at+interval '365 days') AS valid_until
    FROM line l JOIN public.wallet_transactions t ON t.user_id=l.user_id
      JOIN public.wallets w ON w.id=t.wallet_id AND w.user_id=l.user_id AND w.currency='USD'
    WHERE t.type='plan_fee_debit' AND t.status='completed' AND t.amount>0
      AND t.amount::text NOT IN ('NaN','Infinity','-Infinity') AND t.balance_before-t.balance_after=t.amount
      AND (t.sim_line_id=l.id OR t.metadata->>'sim_line_id'=l.id::text OR EXISTS(
        SELECT 1 FROM public.sim_setup_orders o WHERE o.id::text=t.metadata->>'setup_order_id'
          AND o.sim_line_id=l.id AND o.user_id=l.user_id AND o.status='active'))
      AND (lower(t.metadata->>'plan')=p_plan OR (t.metadata->>'plan' IS NULL
        AND lower(t.description) IN ('annual plan fee debit ('||p_plan||')','annual protection fee ('||p_plan||')')))
      AND NOT EXISTS(SELECT 1 FROM public.wallet_transaction_funding f WHERE f.transaction_id=t.id AND f.reversed_amount>0)
      AND NOT EXISTS(SELECT 1 FROM public.wallet_transactions r WHERE r.user_id=l.user_id AND r.status='completed'
        AND r.type='refund' AND (r.metadata->>'reversal_of'=t.id::text OR r.reference_id='refund_'||t.reference_id))
    UNION ALL
    SELECT 'receipt:'||p.id,p.net_usd,p.created_at,least(l.plan_expires_at,p.created_at+interval '365 days')
    FROM line l JOIN public.plan_payments p ON p.sim_line_id=l.id AND p.user_id=l.user_id
    WHERE p.kind='plan' AND lower(p.metadata->>'plan')=p_plan AND p.net_usd>0 AND p.net_usd<=p.gross_usd
      AND (p.metadata->>'currency' IS NULL OR p.metadata->>'currency'='USD') AND p.net_usd::text NOT IN ('NaN','Infinity','-Infinity') AND nullif(p.capture_id,'') IS NOT NULL
      -- Setup receipts are mirrors of the captured wallet ledger above. Do not
      -- let their duplicate record restore refunded or uncollected entitlement.
      AND p.metadata->>'setup_order_id' IS NULL
      AND NOT EXISTS(SELECT 1 FROM public.sim_setup_orders o WHERE o.id::text=p.order_id)
      AND NOT EXISTS(SELECT 1 FROM public.wallet_holds h WHERE h.id::text=p.capture_id)
      AND NOT EXISTS(SELECT 1 FROM public.paypal_orders o WHERE o.order_id=p.order_id
        AND (o.user_id IS DISTINCT FROM p.user_id OR o.kind<>'plan' OR o.plan IS DISTINCT FROM p_plan
          OR o.sim_line_id IS DISTINCT FROM l.id OR o.status<>'captured' OR o.amount_usd<>p.gross_usd))
    UNION ALL
    SELECT 'grant:'||g.id,g.credit_usd,g.starts_at,least(l.plan_expires_at,g.expires_at)
    FROM line l JOIN public.line_plan_grants g ON g.sim_line_id=l.id AND g.user_id=l.user_id AND g.plan=p_plan
    WHERE g.revoked_at IS NULL
    UNION ALL
    SELECT 'legacy-grandfather:'||l.id,0,g.created_at,l.plan_expires_at
    FROM line l JOIN public.premium_entitlement_grandfather g ON g.sim_line_id=l.id
    WHERE p_plan='premium'
  ) SELECT * FROM evidence WHERE paid_at<=now() AND valid_until>now();
$$;
CREATE OR REPLACE FUNCTION public.membership_fee_usd(p_plan text)
RETURNS numeric LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE v_fee numeric;
BEGIN
  IF p_plan NOT IN ('standard','premium') OR p_plan IS NULL THEN RAISE EXCEPTION 'Invalid paid plan'; END IF;
  SELECT config_value::numeric INTO v_fee FROM public.system_configs WHERE config_key=CASE p_plan
    WHEN 'standard' THEN 'MEMBERSHIP_FEE_STANDARD_USD' ELSE 'MEMBERSHIP_FEE_PREMIUM_USD' END;
  IF v_fee IS NULL AND p_plan='standard' THEN
    SELECT config_value::numeric INTO v_fee FROM public.system_configs WHERE config_key='BASE_SERVICE_FEE_USD';
  END IF;
  IF v_fee IS NULL THEN RAISE EXCEPTION 'Membership pricing is not configured'; END IF;
  IF v_fee<0 OR v_fee::text IN ('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'Invalid membership fee'; END IF;
  RETURN round(v_fee,2);
END;
$$;

CREATE OR REPLACE FUNCTION public.resolve_app_fee(p_item text,p_tier text,p_base_amount numeric)
RETURNS numeric LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.app_fee_rules; v_pct numeric; v_min numeric;
BEGIN
  IF p_base_amount IS NULL OR p_base_amount<0 OR p_base_amount::text IN ('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'Invalid fee basis'; END IF;
  SELECT * INTO r FROM public.app_fee_rules WHERE appfees_item=p_item AND status='published'
    AND (effective_from IS NULL OR effective_from<=now()) AND (effective_to IS NULL OR effective_to>now())
    ORDER BY version DESC LIMIT 1;
  IF NOT FOUND THEN RAISE EXCEPTION 'Published fee rule unavailable for %',p_item; END IF;
  IF r.currency<>'USD' OR r.fee_basis<>'base_amount_usd' THEN RAISE EXCEPTION 'Unsupported fee currency or basis'; END IF;
  v_pct:=CASE lower(p_tier) WHEN 'premium' THEN r.prem_percentage WHEN 'standard' THEN r.stand_percentage ELSE r.free_percentage END;
  v_min:=CASE lower(p_tier) WHEN 'premium' THEN r.prem_minimum WHEN 'standard' THEN r.stand_minimum ELSE r.free_minimum END;
  IF v_pct IS NULL OR v_min IS NULL OR v_pct<0 OR v_min<0 OR v_pct::text IN ('NaN','Infinity','-Infinity') OR v_min::text IN ('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'Invalid published fee'; END IF;
  IF p_item='intelcallfee' THEN RETURN round(p_base_amount*coalesce(v_pct,0)/100,4); END IF;
  RETURN round(greatest(p_base_amount*coalesce(v_pct,0)/100,coalesce(v_min,0)),2);
END;
$$;


CREATE OR REPLACE FUNCTION public.resolve_line_entitlement(p_sim_line_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE l public.sim_lines; e record; tier text:='free';
BEGIN
  SELECT * INTO l FROM public.sim_lines WHERE id=p_sim_line_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('found',false,'effective_tier','free','is_paid',false,'is_premium',false,'automation_eligible',false); END IF;
  SELECT * INTO e FROM public.line_paid_plan_evidence(l.id,lower(trim(l.plan_type))) ORDER BY paid_at DESC,source_key LIMIT 1;
  IF FOUND THEN tier:=lower(trim(l.plan_type)); END IF;
  RETURN jsonb_build_object('found',true,'sim_line_id',l.id,'user_id',l.user_id,'plan_type',l.plan_type,
    'protection_tier',l.protection_tier,'effective_tier',tier,'is_paid',tier IN ('standard','premium'),
    'is_premium',tier='premium','is_expired',tier='free','expires_at',e.valid_until,'automation_eligible',tier='premium');
END $$;
CREATE OR REPLACE FUNCTION public.standard_upgrade_credit_usd(p_sim_line_id uuid)
RETURNS numeric LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE paid numeric; last_paid_at timestamptz;
BEGIN
  IF public.resolve_line_entitlement(p_sim_line_id)->>'effective_tier'<>'standard' THEN RETURN 0; END IF;
  SELECT e.paid_usd,e.paid_at INTO paid,last_paid_at FROM public.line_paid_plan_evidence(p_sim_line_id,'standard') e
    ORDER BY e.paid_at DESC,e.source_key LIMIT 1;
  IF EXISTS(SELECT 1 FROM public.line_paid_plan_evidence(p_sim_line_id,'premium') e WHERE e.paid_at>=last_paid_at) THEN RETURN 0; END IF;
  RETURN least(coalesce(paid,0),public.membership_fee_usd('standard'),public.membership_fee_usd('premium'));
END $$;


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
         cr.refill_interval_days_override, cr.inapp_pricing,cr.inapp_pricing_currency,
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

  IF p_sim_line_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.sim_lines WHERE id=p_sim_line_id AND carrier_id=v_rule.carrier_id) THEN RAISE EXCEPTION 'Carrier rule does not match the owned line'; END IF;

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

  -- Published fee rules include explicit zero-fee promotions.
  v_app_fee := public.resolve_app_fee('refills','premium',v_offer.price_usd);

  SELECT COALESCE(c.fulfillment_gateway, 'API') INTO v_fulfillment_gateway
  FROM public.carriers c
  WHERE c.id = v_rule.carrier_id;

  IF v_fulfillment_gateway<>'API' AND coalesce(v_rule.inapp_pricing,0)>0 AND v_rule.inapp_pricing_currency IS DISTINCT FROM 'USD' THEN RAISE EXCEPTION 'Manual retail override must be denominated in USD'; END IF;
  IF v_fulfillment_gateway = 'API' THEN
    v_first_refill := round(v_offer.price_usd + v_app_fee, 2);
  ELSE
    v_first_refill := round(GREATEST(COALESCE(v_rule.inapp_pricing, 0), v_offer.price_usd + v_app_fee), 2);
  END IF;

  v_total := round(v_base_fee + v_first_refill, 2);

  RETURN jsonb_build_object(
    'success', true,'currency','USD',
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
SET search_path TO ''
AS $$
DECLARE
  v_annual_fee       NUMERIC := 0.00;
  v_first_refill     NUMERIC := 0.00;
  v_total            NUMERIC := 0.00;
  v_interval_days    INTEGER := 30;
  v_free_eligible    BOOLEAN := true;
  v_premium_quote    JSONB;
  v_standard_fee     NUMERIC;
  v_is_upgrade       BOOLEAN := false;
  v_upgrade_credit   NUMERIC := 0.00;
  v_full_annual_fee  NUMERIC;
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
    v_full_annual_fee := (v_premium_quote->>'full_annual_fee_usd')::numeric;
  ELSE
    RAISE EXCEPTION 'Invalid plan: %', p_plan;
  END IF;

  RETURN jsonb_build_object(
    'success', true,'currency','USD',
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
  v_snapshot jsonb;
  v_base numeric;
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

  v_snapshot:=v_breakdown;
  IF p_plan='premium' THEN
    SELECT r.price_usd INTO v_base FROM public.carrier_rules cr
      CROSS JOIN LATERAL public.carrier_refill_offer(cr.carrier_id,coalesce(cr.validity_qualifying_topup_amount,cr.minimum_topup_amount)) r
      WHERE cr.id=coalesce(p_carrier_rule_id,(SELECT carrier_rule_id FROM public.sim_lines WHERE id=p_sim_line_id));
    IF v_base IS NULL OR v_base<=0 OR v_first_refill<v_base THEN RAISE EXCEPTION 'Supplier quote unavailable'; END IF;
    v_snapshot:=v_snapshot||jsonb_build_object('base_cost_usd',v_base,'first_refill_fee_usd',round(v_first_refill-v_base,2));
  END IF;
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
        pricing_snapshot=v_snapshot,quote_expires_at=now()+interval '15 minutes',
        updated_at = now()
    WHERE id = v_existing.id
    RETURNING id INTO v_order_id;
  ELSE
    INSERT INTO public.sim_setup_orders (
      user_id, sim_line_id, carrier_rule_id, plan, phone_number,
      country_code, carrier_code, annual_fee_usd, first_refill_cost_usd,
      total_charge_usd, status, created_at, updated_at,pricing_snapshot,quote_expires_at
    ) VALUES (
      v_user_id, p_sim_line_id, p_carrier_rule_id, p_plan, p_phone_number,
      p_country_code, p_carrier_code, v_annual_fee, v_first_refill,
      v_total, 'draft', now(), now(),v_snapshot,now()+interval '15 minutes'
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

CREATE OR REPLACE FUNCTION public.reserve_sim_setup_holds(p_order_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_user_id             UUID;
  v_order               RECORD;
  v_wallet              RECORD;
  v_held_amount         NUMERIC := 0.00;
  v_available           NUMERIC := 0.00;
  v_fee_hold_id         UUID;
  v_refill_hold_id      UUID;
  v_current_quote jsonb;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT * INTO v_order
  FROM public.sim_setup_orders
  WHERE id = p_order_id FOR UPDATE;

  IF v_order.id IS NULL THEN
    RAISE EXCEPTION 'Setup order not found: %', p_order_id;
  END IF;

  IF v_order.user_id <> v_user_id THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  IF v_order.status IN ('reserved','dispatching') THEN
    PERFORM public.assert_setup_hold_bindings(v_order.id);
    RETURN jsonb_build_object('success', true, 'status', 'reserved', 'order_id', p_order_id);
  END IF;

  IF v_order.status NOT IN ('draft', 'awaiting_funds') THEN
    RAISE EXCEPTION 'Cannot reserve holds for order in status: %', v_order.status;
  END IF;

  IF v_order.pricing_snapshot IS NULL OR v_order.quote_expires_at<=now() OR v_order.quote_expires_at IS NULL THEN
    RAISE EXCEPTION 'Setup quote expired; refresh the server quote'; END IF;
  PERFORM 1 FROM public.sim_lines WHERE id=v_order.sim_line_id AND user_id=v_user_id FOR UPDATE;
  v_current_quote:=public.quote_sim_setup(v_order.phone_number,v_order.plan,v_order.carrier_rule_id,v_order.sim_line_id);
  IF (v_current_quote->>'total_charge_usd')::numeric IS DISTINCT FROM v_order.total_charge_usd
    OR (v_current_quote->>'annual_fee_usd')::numeric IS DISTINCT FROM v_order.annual_fee_usd
    OR (v_current_quote->>'first_refill_cost_usd')::numeric IS DISTINCT FROM v_order.first_refill_cost_usd THEN
    RAISE EXCEPTION 'Setup price changed; review the current quote'; END IF;
  IF v_order.total_charge_usd=0 THEN
    UPDATE public.sim_setup_orders SET status='reserved',updated_at=now() WHERE id=v_order.id;
    RETURN jsonb_build_object('success',true,'status','reserved','order_id',v_order.id,'total_charge_usd',0);
  END IF;

  IF EXISTS(SELECT 1 FROM public.sim_setup_orders WHERE sim_line_id=v_order.sim_line_id AND id<>v_order.id AND status IN ('reserved','dispatching')) THEN RAISE EXCEPTION 'Another plan purchase is already reserved'; END IF;

  -- Lock wallet
  SELECT * INTO v_wallet
  FROM public.wallets
  WHERE user_id = v_user_id FOR UPDATE;

  IF v_wallet.id IS NULL THEN
    RAISE EXCEPTION 'Wallet not found for user';
  END IF;

  SELECT COALESCE(SUM(amount), 0.00) INTO v_held_amount
  FROM public.wallet_holds
  WHERE user_id = v_user_id AND status = 'active';

  v_available := v_wallet.balance - v_held_amount;

  IF v_available < v_order.total_charge_usd THEN
    UPDATE public.sim_setup_orders
    SET status = 'awaiting_funds', updated_at = now()
    WHERE id = p_order_id;

    RETURN jsonb_build_object(
      'success', false,
      'code', 'insufficient_funds',
      'error', 'insufficient_balance',
      'message', 'Your wallet balance cannot cover this plan. Please add funds to continue.',
      'available_balance', v_available,
      'current_balance', v_available,
      'required_balance', v_order.total_charge_usd,
      'shortfall', round(v_order.total_charge_usd - v_available, 2)
    );
  END IF;

  -- 1. Hold annual fee if > 0
  IF v_order.annual_fee_usd > 0 THEN
    v_fee_hold_id := public.reserve_wallet_funds(
      v_user_id,
      v_order.annual_fee_usd,
      'plan_fee',
      'setup_fee_' || p_order_id::text,
      'Annual KeepSIMs Protection Fee Hold',
      240
    );
  END IF;

  -- 2. Hold first refill as 'setup_refill' if > 0
  IF v_order.first_refill_cost_usd > 0 THEN
    v_refill_hold_id := public.reserve_wallet_funds(
      v_user_id,
      v_order.first_refill_cost_usd,
      'setup_refill',
      'setup_refill_' || p_order_id::text,
      'Initial SIM Setup Refill Hold',
      240
    );
  END IF;

  UPDATE public.sim_setup_orders
  SET annual_fee_hold_id = v_fee_hold_id,
      first_refill_hold_id = v_refill_hold_id,
      status = 'reserved',
      updated_at = now()
  WHERE id = p_order_id;

  RETURN jsonb_build_object(
    'success', true,
    'status', 'reserved',
    'annual_fee_hold_id', v_fee_hold_id,
    'first_refill_hold_id', v_refill_hold_id,
    'total_charge_usd', v_order.total_charge_usd
  );
END;
$function$;


CREATE OR REPLACE FUNCTION public.capture_sim_setup_holds(
  p_order_id UUID,
  p_provider_tx_id TEXT DEFAULT NULL::TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_order            RECORD;
  v_line_id          UUID;
  v_interval_days    INTEGER := 30;
  v_rule             RECORD;
  v_notify_amount    NUMERIC := 1.00;
  v_execution        RECORD;
  v_base_cost        NUMERIC := NULL;
  v_app_fee          NUMERIC := NULL;
  v_refill_amount    NUMERIC := NULL;
  v_offer_id         TEXT := NULL;
  v_offer_value      BIGINT := NULL;
  v_provider         TEXT := NULL;
  v_intent_kind      TEXT := 'exact_airtime';
  v_target_local_val NUMERIC := NULL;
  v_target_local_cur TEXT := NULL;
  v_fee_rule_ver     INTEGER := NULL;
BEGIN
  SELECT * INTO v_order
  FROM public.sim_setup_orders
  WHERE id = p_order_id FOR UPDATE;

  IF v_order.id IS NULL THEN
    RAISE EXCEPTION 'Setup order not found: %', p_order_id;
  END IF;

  PERFORM 1 FROM public.sim_lines WHERE id=v_order.sim_line_id AND user_id=v_order.user_id
    AND phone_number=v_order.phone_number FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Owned matching line required'; END IF;
  PERFORM public.assert_setup_hold_bindings(v_order.id);
  IF v_order.plan='standard' AND (v_order.first_refill_hold_id IS NOT NULL OR v_order.first_refill_cost_usd<>0) THEN
    RAISE EXCEPTION 'Standard setup must not include a refill reservation'; END IF;
  IF v_order.status = 'active' THEN
    RETURN jsonb_build_object('success', true, 'status', 'active', 'already_captured', true);
  END IF;

  IF v_order.status NOT IN ('reserved','dispatching') OR v_order.plan NOT IN ('standard','premium') THEN
    RAISE EXCEPTION 'Invalid setup capture state';
  END IF;
  PERFORM 1 FROM public.sim_lines WHERE id=v_order.sim_line_id
    AND user_id=v_order.user_id AND phone_number=v_order.phone_number FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Owned matching line required'; END IF;
  IF v_order.annual_fee_usd>0 AND NOT EXISTS (
    SELECT 1 FROM public.wallet_holds WHERE id=v_order.annual_fee_hold_id
      AND user_id=v_order.user_id AND amount=v_order.annual_fee_usd
      AND status IN ('active','captured') AND order_type='plan_fee'
      AND order_reference_id IN ('setup_fee_'||v_order.id::text,'std_fallback_'||v_order.id::text)
      AND currency='USD' AND wallet_id=(SELECT id FROM public.wallets WHERE user_id=v_order.user_id AND currency='USD')
  ) THEN RAISE EXCEPTION 'Annual fee reservation required'; END IF;
  IF v_order.plan='premium' THEN
    SELECT * INTO v_execution FROM public.topup_executions
      WHERE wallet_hold_id=v_order.first_refill_hold_id AND user_id=v_order.user_id
        AND sim_line_id=v_order.sim_line_id AND status='success'
        AND reloadly_transaction_id IS NOT NULL ORDER BY created_at DESC LIMIT 1;
    IF v_execution.id IS NULL THEN RAISE EXCEPTION 'Confirmed initial delivery required'; END IF;
    PERFORM public.assert_instant_refill_reservation(v_execution.id,v_order.first_refill_hold_id);
    IF NOT EXISTS(SELECT 1 FROM public.wallet_holds h JOIN public.wallet_transactions t
      ON t.reference_id='hold_'||h.id::text WHERE h.id=v_order.first_refill_hold_id AND h.status='captured'
      AND t.type='topup_debit' AND t.status='completed' AND t.amount=v_order.first_refill_cost_usd
      AND t.wallet_id=h.wallet_id AND t.user_id=v_order.user_id
      AND t.metadata->>'execution_id'=v_execution.id::text
      AND t.metadata->>'provider_tx_id'=v_execution.reloadly_transaction_id) THEN
      RAISE EXCEPTION 'Settled initial delivery receipt required'; END IF;
    p_provider_tx_id:=v_execution.reloadly_transaction_id;
    IF NOT EXISTS (SELECT 1 FROM public.wallet_holds WHERE id=v_order.first_refill_hold_id
      AND user_id=v_order.user_id AND amount=v_order.first_refill_cost_usd
      AND status IN ('active','captured')) THEN RAISE EXCEPTION 'Refill reservation required'; END IF;
  END IF;

  -- 1. Capture annual fee hold
  IF v_order.annual_fee_hold_id IS NOT NULL THEN
    PERFORM public.capture_wallet_hold(
      v_order.annual_fee_hold_id,
      'plan_fee_debit',
      'Annual Protection Fee (' || v_order.plan || ')',
      jsonb_build_object('setup_order_id', p_order_id, 'sim_line_id',v_order.sim_line_id, 'plan', v_order.plan, 'order_type', 'plan_fee')
    );
  END IF;

  -- 2. Capture initial refill hold
  IF v_order.first_refill_hold_id IS NOT NULL THEN
    PERFORM public.capture_wallet_hold(
      v_order.first_refill_hold_id,
      'topup_debit',
      'Initial SIM Recharge (' || v_order.phone_number || ')',
      jsonb_build_object('setup_order_id', p_order_id, 'provider_tx_id', p_provider_tx_id, 'order_type', 'setup_refill')
    );
  END IF;

  v_line_id := v_order.sim_line_id;
  IF v_line_id IS NULL THEN
    -- Resilient fallback: link matching SIM line if user already created it
    SELECT id INTO v_line_id
    FROM public.sim_lines
    WHERE user_id = v_order.user_id AND phone_number = v_order.phone_number
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_line_id IS NOT NULL THEN
      UPDATE public.sim_setup_orders
      SET sim_line_id = v_line_id, updated_at = now()
      WHERE id = p_order_id;
    ELSE
      RAISE EXCEPTION 'Cannot activate setup order without an associated sim_line_id: %', p_order_id;
    END IF;
  END IF;

  IF v_order.plan='standard' THEN
    UPDATE public.scheduled_topups SET is_active=false,status='paused',updated_at=now()
      WHERE sim_line_id=v_line_id AND schedule_type<>'notify';
  END IF;
  -- 3. Activate SIM Line with valid carrier_status ('active')
  UPDATE public.sim_lines
  SET status = 'active',
      plan_type = v_order.plan,
      protection_tier = CASE WHEN v_order.plan = 'free' THEN 'basic' ELSE v_order.plan END,
      plan_expires_at = now() + INTERVAL '365 days',
      last_topup_at = CASE WHEN v_order.plan = 'premium' THEN now() ELSE last_topup_at END,
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

  IF v_order.plan IN ('standard','premium') AND v_order.annual_fee_usd=0 THEN
    IF v_order.pricing_snapshot IS NULL OR (v_order.pricing_snapshot->>'annual_fee_usd')::numeric IS DISTINCT FROM 0 THEN
      RAISE EXCEPTION 'Zero fee requires an accepted server price'; END IF;
    INSERT INTO public.line_plan_grants(sim_line_id,user_id,plan,source,source_key,credit_usd,expires_at,reason)
      VALUES(v_line_id,v_order.user_id,v_order.plan,'promotion','setup:'||v_order.id,0,
        now()+interval '365 days','Accepted server-priced zero membership fee') ON CONFLICT(source_key) DO NOTHING;
  END IF;

  -- 5. Calculate cadence and schedule next occurrences
  IF v_order.carrier_rule_id IS NOT NULL THEN
    SELECT * INTO v_rule FROM public.carrier_rules WHERE id = v_order.carrier_rule_id;
  ELSE
    SELECT cr.* INTO v_rule
    FROM public.sim_lines sl
    JOIN public.carrier_rules cr ON cr.id = sl.carrier_rule_id OR cr.carrier_id = sl.carrier_id
    WHERE sl.id = v_line_id
    LIMIT 1;
  END IF;

  IF v_rule.id IS NOT NULL THEN
    v_interval_days := public.refill_interval_days(v_rule.inactivity_limit_days, v_rule.refill_interval_days_override);
    IF v_interval_days IS NULL OR v_interval_days < 1 THEN
      v_interval_days := 30;
    END IF;

    -- Resolve valid positive notify amount
    v_notify_amount := COALESCE(
      NULLIF(v_order.first_refill_cost_usd, 0),
      NULLIF(v_rule.minimum_topup_amount, 0),
      NULLIF(v_rule.recommended_topup_amount, 0),
      1.00
    );

    -- 5a. Always create 'notify' schedule for user alert reminders
    INSERT INTO public.scheduled_topups (
      user_id, sim_line_id, amount, currency, frequency_days,
      next_execution_at, is_active, status, schedule_type
    ) VALUES (
      v_order.user_id,
      v_line_id,
      v_notify_amount,
      'USD',
      v_interval_days,
      now() + (v_interval_days || ' days')::interval,
      true,
      'active',
      'notify'
    )
    ON CONFLICT (sim_line_id, schedule_type)
    DO UPDATE SET
      amount = EXCLUDED.amount,
      frequency_days = EXCLUDED.frequency_days,
      next_execution_at = EXCLUDED.next_execution_at,
      is_active = true,
      status = 'active',
      updated_at = now();

    -- 5b. For Premium lines, look up execution snapshot to establish a coherent pricing contract
    IF v_order.plan = 'premium' THEN
      SELECT * INTO v_execution
      FROM public.topup_executions
      WHERE wallet_hold_id = v_order.first_refill_hold_id
      ORDER BY created_at DESC
      LIMIT 1;

      IF v_execution.id IS NOT NULL THEN
        v_offer_id := v_execution.offer_id;
        v_offer_value := v_execution.offer_value;
        v_provider := v_execution.api_provider;
        v_base_cost := v_execution.base_cost_usd;
        v_app_fee := COALESCE(
          v_execution.app_fee_usd,
          round(v_order.first_refill_cost_usd - COALESCE(v_execution.base_cost_usd, 0), 2)
        );
        v_refill_amount := v_order.first_refill_cost_usd;
        v_intent_kind := COALESCE(v_execution.intent_kind, 'exact_airtime');
        v_target_local_val := v_execution.target_local_value;
        v_target_local_cur := v_execution.target_local_currency;
      ELSE
        v_offer_id := v_rule.offer_id;
        v_offer_value := v_rule.offer_value;
        v_refill_amount := COALESCE(NULLIF(v_order.first_refill_cost_usd, 0), v_rule.minimum_topup_amount, 1.00);
      END IF;

      -- Resolve active fee rule version
      SELECT version INTO v_fee_rule_ver
      FROM public.app_fee_rules
      WHERE appfees_item = 'refills'
      ORDER BY (status = 'published') DESC, version DESC
      LIMIT 1;

      -- Fallback lookup for target local currency and value if missing
      IF (v_target_local_val IS NULL OR v_target_local_cur IS NULL) AND v_offer_id IS NOT NULL THEN
        SELECT source_amount_native, source_send_currency
        INTO v_target_local_val, v_target_local_cur
        FROM public.provider_offers
        WHERE offer_code = v_offer_id
          AND (v_rule.carrier_id IS NULL OR carrier_id = v_rule.carrier_id)
        ORDER BY is_active DESC, updated_at DESC
        LIMIT 1;
      END IF;

      INSERT INTO public.scheduled_topups (
        user_id, sim_line_id, amount, base_cost_usd, app_fee_usd, max_authorized_usd,
        currency, frequency_days, next_execution_at, is_active, status, schedule_type,
        offer_id, offer_value, preferred_provider, pricing_tier, intent_kind,
        target_local_value, target_local_currency, engine_version, fee_rule_version
      ) VALUES (
        v_order.user_id,
        v_line_id,
        v_refill_amount,
        v_base_cost,
        v_app_fee,
        v_refill_amount,
        'USD',
        v_interval_days,
        now() + (v_interval_days || ' days')::interval,
        true,
        'active',
        'refill_mini',
        v_offer_id,
        v_offer_value,
        v_provider,
        'premium',
        v_intent_kind,
        v_target_local_val,
        v_target_local_cur,
        2,
        COALESCE(v_fee_rule_ver, 1)
      )
      ON CONFLICT (sim_line_id, schedule_type)
      DO UPDATE SET
        amount = EXCLUDED.amount,
        base_cost_usd = EXCLUDED.base_cost_usd,
        app_fee_usd = EXCLUDED.app_fee_usd,
        max_authorized_usd = EXCLUDED.max_authorized_usd,
        currency = EXCLUDED.currency,
        frequency_days = EXCLUDED.frequency_days,
        next_execution_at = EXCLUDED.next_execution_at,
        is_active = true,
        status = 'active',
        offer_id = EXCLUDED.offer_id,
        offer_value = EXCLUDED.offer_value,
        preferred_provider = EXCLUDED.preferred_provider,
        pricing_tier = EXCLUDED.pricing_tier,
        intent_kind = EXCLUDED.intent_kind,
        target_local_value = EXCLUDED.target_local_value,
        target_local_currency = EXCLUDED.target_local_currency,
        engine_version = EXCLUDED.engine_version,
        fee_rule_version = EXCLUDED.fee_rule_version,
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

CREATE OR REPLACE FUNCTION public.fallback_sim_setup_to_reminders(p_order_id uuid,p_sim_line_id uuid,p_fallback_plan text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE o public.sim_setup_orders; v_fee numeric; v_hold uuid; v_available numeric; v_days integer;
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
  PERFORM public.assert_setup_hold_bindings(o.id);
  PERFORM 1 FROM public.topup_executions WHERE wallet_hold_id=o.first_refill_hold_id FOR UPDATE;
  PERFORM 1 FROM public.wallets WHERE user_id=o.user_id FOR UPDATE;
  IF EXISTS(SELECT 1 FROM public.wallet_holds WHERE id IN (o.annual_fee_hold_id,o.first_refill_hold_id)
    AND status='active' AND recovery_contract_version<1) THEN
    RAISE EXCEPTION 'Legacy setup requires reconciliation'; END IF;
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
        annual_fee_usd=v_fee,first_refill_cost_usd=0,total_charge_usd=v_fee,
        pricing_snapshot=jsonb_build_object('annual_fee_usd',v_fee,'total_charge_usd',v_fee,'currency','USD'),quote_expires_at=now()+interval '15 minutes',annual_fee_hold_id=NULL,first_refill_hold_id=NULL,updated_at=now() WHERE id=o.id;
      RETURN jsonb_build_object('success',false,'code','insufficient_funds','available_balance',coalesce(v_available,0),'required',v_fee);
    END IF;
    IF v_fee>0 THEN v_hold:=public.reserve_wallet_funds(o.user_id,v_fee,'plan_fee','std_fallback_'||o.id); END IF;
    UPDATE public.sim_setup_orders SET plan='standard',status='reserved',sim_line_id=p_sim_line_id,
      annual_fee_usd=v_fee,first_refill_cost_usd=0,total_charge_usd=v_fee,
        pricing_snapshot=jsonb_build_object('annual_fee_usd',v_fee,'total_charge_usd',v_fee,'currency','USD'),quote_expires_at=now()+interval '15 minutes',
      annual_fee_hold_id=v_hold,first_refill_hold_id=NULL,updated_at=now() WHERE id=o.id;
    RETURN public.capture_sim_setup_holds(o.id);
  END IF;
  SELECT public.refill_interval_days(inactivity_limit_days,refill_interval_days_override)
    INTO v_days FROM public.carrier_rules WHERE id=o.carrier_rule_id;
  INSERT INTO public.scheduled_topups(user_id,sim_line_id,amount,currency,frequency_days,
    next_execution_at,is_active,status,schedule_type)
    VALUES(o.user_id,p_sim_line_id,coalesce(nullif(o.first_refill_cost_usd,0),1),'USD',
      coalesce(v_days,30),now()+make_interval(days=>coalesce(v_days,30)),true,'active','notify')
    ON CONFLICT(sim_line_id,schedule_type) DO UPDATE SET is_active=true,status='active',updated_at=now();
  UPDATE public.sim_lines SET plan_type='free',protection_tier='basic',plan_expires_at=NULL,updated_at=now() WHERE id=p_sim_line_id;
  UPDATE public.scheduled_topups SET is_active=false,status='paused',updated_at=now()
    WHERE sim_line_id=p_sim_line_id AND schedule_type<>'notify';
  UPDATE public.sim_setup_orders SET plan='free',status='active',sim_line_id=p_sim_line_id,annual_fee_usd=0,
    first_refill_cost_usd=0,total_charge_usd=0,annual_fee_hold_id=NULL,first_refill_hold_id=NULL,updated_at=now() WHERE id=o.id;
  RETURN jsonb_build_object('success',true,'plan','free','expires_at',NULL);
END;
$$;

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
  PERFORM 1 FROM public.sim_lines WHERE id=p_sim_line_id AND user_id=v_user_id FOR UPDATE;
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

  IF EXISTS(SELECT 1 FROM public.line_plan_grants WHERE source_key='wallet:'||p_reference_id) THEN
    IF NOT EXISTS(SELECT 1 FROM public.line_plan_grants WHERE source_key='wallet:'||p_reference_id AND user_id=v_user_id AND sim_line_id=p_sim_line_id AND plan=v_plan) THEN
      RAISE EXCEPTION 'Plan payment reference mismatch'; END IF;
    RETURN jsonb_build_object('success',true,'already_paid',true,'amount',0,'plan',v_plan,'reference_id',p_reference_id);
  END IF;
  IF EXISTS(SELECT 1 FROM public.sim_setup_orders WHERE sim_line_id=p_sim_line_id AND status IN ('reserved','dispatching')) THEN RAISE EXCEPTION 'Another plan purchase is already reserved'; END IF;
  -- Priced server-side with upgrade credit if applicable
  v_fee := round(public.plan_price_net(v_plan, p_sim_line_id, p_carrier_rule_id), 2);

  IF v_fee IS NULL OR v_fee < 0 THEN
    RAISE EXCEPTION 'Plan % has no usable price', v_plan USING ERRCODE = '22023';
  END IF;

  IF v_fee=0 THEN
    IF p_sim_line_id IS NULL THEN RAISE EXCEPTION 'A zero-price membership requires an owned line'; END IF;
    INSERT INTO public.line_plan_grants(sim_line_id,user_id,plan,source,source_key,credit_usd,expires_at,reason)
      VALUES(p_sim_line_id,v_user_id,v_plan,'promotion','wallet:'||p_reference_id,0,now()+interval '365 days','Published zero membership price');
    UPDATE public.sim_lines SET plan_type=v_plan,protection_tier=v_plan,plan_expires_at=now()+interval '365 days',updated_at=now() WHERE id=p_sim_line_id;
    RETURN jsonb_build_object('success',true,'amount',0,'plan',v_plan,'reference_id',p_reference_id);
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


REVOKE ALL ON FUNCTION public.line_paid_plan_evidence(uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.line_paid_plan_evidence(uuid,text) TO service_role;
-- Only retail fee policy is public; effectiveness and validation stay on server.
CREATE FUNCTION public.get_current_refill_fee_rules() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.app_fee_rules;
BEGIN
  IF auth.uid() IS NULL AND coalesce(auth.role(),'')<>'service_role' THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  PERFORM public.resolve_app_fee('refills','free',0);
  PERFORM public.resolve_app_fee('refills','standard',0);
  PERFORM public.resolve_app_fee('refills','premium',0);
  SELECT * INTO r FROM public.app_fee_rules WHERE appfees_item='refills' AND status='published'
    AND (effective_from IS NULL OR effective_from<=now()) AND (effective_to IS NULL OR effective_to>now()) ORDER BY version DESC LIMIT 1;
  RETURN jsonb_build_object('free',jsonb_build_object('percentage',r.free_percentage,'minimum',r.free_minimum),
    'standard',jsonb_build_object('percentage',r.stand_percentage,'minimum',r.stand_minimum),
    'premium',jsonb_build_object('percentage',r.prem_percentage,'minimum',r.prem_minimum),'version',r.version,'currency','USD');
END $$;
REVOKE ALL ON FUNCTION public.get_current_refill_fee_rules() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_current_refill_fee_rules() TO authenticated,service_role;

-- Bind confirmation to a server quote. Stable retries adopt the original charge
-- before reading changed configuration, and do not charge a second gateway fee.
CREATE FUNCTION public.pay_quoted_plan_fee_from_wallet(p_reference_id text,p_sim_line_id uuid,p_device_id text,
  p_plan text,p_carrier_rule_id uuid,p_expected_amount numeric) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE original numeric;
BEGIN
  PERFORM public.assert_pricing_line_owner(p_sim_line_id);
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  PERFORM 1 FROM public.sim_lines WHERE id=p_sim_line_id FOR UPDATE;
  PERFORM 1 FROM public.wallets WHERE user_id=auth.uid() FOR UPDATE;
  SELECT amount INTO original FROM public.wallet_transactions WHERE user_id=auth.uid()
    AND reference_id=p_reference_id AND type='plan_fee_debit' AND status='completed';
  IF EXISTS(SELECT 1 FROM public.wallet_transactions t JOIN public.wallet_transaction_funding f ON f.transaction_id=t.id WHERE t.user_id=auth.uid() AND t.reference_id=p_reference_id AND f.reversed_amount>0) THEN RAISE EXCEPTION 'Plan payment was reversed'; END IF;
  IF FOUND OR EXISTS(SELECT 1 FROM public.line_plan_grants WHERE source_key='wallet:'||p_reference_id AND user_id=auth.uid()) THEN
    RETURN public.pay_plan_fee_from_wallet(p_reference_id,p_sim_line_id,p_device_id,p_plan,p_carrier_rule_id);
  END IF;
  IF p_expected_amount IS NULL OR p_expected_amount::text IN ('NaN','Infinity','-Infinity') OR
    p_expected_amount IS DISTINCT FROM public.plan_price_net(p_plan,p_sim_line_id,p_carrier_rule_id) THEN
    RAISE EXCEPTION 'Plan price changed; review the current quote'; END IF;
  RETURN public.pay_plan_fee_from_wallet(p_reference_id,p_sim_line_id,p_device_id,p_plan,p_carrier_rule_id);
END $$;
REVOKE ALL ON FUNCTION public.pay_quoted_plan_fee_from_wallet(text,uuid,text,text,uuid,numeric) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.pay_quoted_plan_fee_from_wallet(text,uuid,text,text,uuid,numeric) TO authenticated,service_role;
REVOKE EXECUTE ON FUNCTION public.pay_plan_fee_from_wallet(text,uuid,text,text,uuid) FROM authenticated;

-- A reserved setup buys its quoted first refill at the Premium purchase price,
-- even while the line is still unpaid. This does not grant general Premium
-- entitlement to the draft line or reprice a funded order after reservation.
CREATE OR REPLACE FUNCTION public.calculate_topup_fees() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE o public.sim_setup_orders; tier text; fee numeric; msg numeric:=0; key text;
BEGIN
  IF NEW.funding_kind='setup_hold' THEN
    SELECT * INTO o FROM public.sim_setup_orders WHERE first_refill_hold_id=NEW.wallet_hold_id
      AND user_id=NEW.user_id AND sim_line_id=NEW.sim_line_id AND plan='premium'
      AND status IN ('reserved','dispatching');
    IF NOT FOUND OR o.pricing_snapshot IS NULL OR
      NEW.base_cost_usd IS DISTINCT FROM (o.pricing_snapshot->>'base_cost_usd')::numeric OR
      NEW.amount IS DISTINCT FROM o.first_refill_cost_usd OR
      NOT EXISTS(SELECT 1 FROM public.wallet_holds WHERE id=o.first_refill_hold_id AND user_id=o.user_id
        AND amount=o.first_refill_cost_usd AND status='active' AND order_type='setup_refill') THEN
      RAISE EXCEPTION 'Setup pricing snapshot mismatch'; END IF;
    NEW.app_fee_usd:=(o.pricing_snapshot->>'first_refill_fee_usd')::numeric;
    NEW.amount:=o.first_refill_cost_usd;
    NEW.max_authorized_usd:=coalesce(NEW.max_authorized_usd,NEW.amount);
    RETURN NEW;
  END IF;
  IF NEW.payment_gateway_code IS NOT NULL AND NEW.base_cost_usd IS NOT NULL THEN
    IF NOT EXISTS(SELECT 1 FROM public.payment_gateways WHERE code=NEW.payment_gateway_code AND is_active) THEN
      RAISE EXCEPTION 'Payment rail unavailable'; END IF;
    tier:=coalesce(public.resolve_line_entitlement(NEW.sim_line_id)->>'effective_tier','free');
    fee:=public.resolve_app_fee('refills',tier,NEW.base_cost_usd);
    key:=CASE NEW.refill_channel WHEN 'whatsapp' THEN 'OFFLINE_WHATSAPP_MESSAGE_FEE_USD'
      WHEN 'sms' THEN 'OFFLINE_SMS_MESSAGE_FEE_USD' WHEN 'missed_call' THEN 'OFFLINE_MISSED_CALL_FEE_USD' END;
    IF key IS NOT NULL THEN
      SELECT config_value::numeric INTO msg FROM public.system_configs WHERE config_key=key;
      IF msg IS NULL OR msg<0 OR msg::text IN ('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'Messaging price unavailable'; END IF;
    END IF;
    NEW.app_fee_usd:=fee;NEW.amount:=round(NEW.base_cost_usd+fee+msg,2);
    NEW.max_authorized_usd:=coalesce(NEW.max_authorized_usd,NEW.amount);
  END IF;
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION public.get_authoritative_refill_quote(p_sim_line_id uuid,p_target_value numeric,
  p_target_currency text,p_offer_id text DEFAULT NULL,p_preferred_provider text DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE l public.sim_lines; o public.provider_offers_cache; cost numeric; fee numeric; tier text; ver integer;
BEGIN
  PERFORM public.assert_pricing_line_owner(p_sim_line_id);
  SELECT * INTO l FROM public.sim_lines WHERE id=p_sim_line_id;
  IF NOT FOUND OR p_target_value IS NULL OR p_target_value<=0 OR p_target_value::text IN ('NaN','Infinity','-Infinity')
    OR nullif(p_target_currency,'') IS NULL THEN RAISE EXCEPTION 'Valid owned refill target required'; END IF;
  SELECT c.* INTO o FROM public.provider_offers_cache c JOIN public.carrier_provider_map m
    ON m.carrier_id=l.carrier_id AND m.provider=c.api_provider AND m.is_enabled
      AND m.provider_country_code=c.country_code AND m.provider_carrier_code=c.carrier_code
    WHERE (p_offer_id IS NULL OR c.offer_id=p_offer_id) AND (p_preferred_provider IS NULL OR c.api_provider=p_preferred_provider)
      AND c.service_type='airtime' AND upper(c.send_currency)=upper(p_target_currency)
      AND ((c.price_type='RANGE' AND p_target_value BETWEEN c.send_min AND c.send_max)
        OR (c.price_type='FIXED' AND c.source_amount_native=p_target_value))
    ORDER BY m.is_primary DESC,m.priority,c.price_fixed_usd,c.offer_id LIMIT 1;
  IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','No eligible provider offer'); END IF;
  IF o.price_type='RANGE' THEN
    IF o.send_max<=o.send_min OR o.price_max_usd<o.price_min_usd THEN RAISE EXCEPTION 'Invalid supplier range'; END IF;
    -- Values retain the cache's provider-native send units/divisor. Interpolate
    -- the cached USD cost for that exact dispatch value, never the lower bound.
    cost:=o.price_min_usd+(p_target_value-o.send_min)*(o.price_max_usd-o.price_min_usd)/(o.send_max-o.send_min);
  ELSE cost:=o.price_fixed_usd; END IF;
  IF cost IS NULL OR cost<=0 OR cost::text IN ('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'Supplier cost unavailable'; END IF;
  cost:=round(cost,2);
  tier:=public.resolve_line_entitlement(l.id)->>'effective_tier';
  fee:=public.resolve_app_fee('refills',tier,cost);
  SELECT version INTO ver FROM public.app_fee_rules WHERE appfees_item='refills' AND status='published'
    AND (effective_from IS NULL OR effective_from<=now()) AND (effective_to IS NULL OR effective_to>now()) ORDER BY version DESC LIMIT 1;
  RETURN jsonb_build_object('success',true,'provider',o.api_provider,'offer_id',o.offer_id,'offer_name',o.offer_name,
    'price_type',o.price_type,'target_local_value',p_target_value,'target_local_currency',upper(p_target_currency),
    'send_currency_divisor',o.send_currency_divisor,'wholesale_cost_usd',cost,'pricing_tier',tier,
    'fee_rule_version',ver,'customer_fee_usd',fee,'total_charge_usd',round(cost+fee,2),
    'max_authorized_usd',round(cost+fee,2),'expected_margin_usd',fee,'is_profitable',true,'quote_created_at',now());
END $$;
-- Internal supplier projection is deliberately service-only. Task 19 owns the
-- separately sanitized customer refill-read surface.
REVOKE ALL ON FUNCTION public.get_authoritative_refill_quote(uuid,numeric,text,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.get_authoritative_refill_quote(uuid,numeric,text,text,text) TO service_role;

CREATE FUNCTION public.get_owned_plan_payment_receipt(p_reference_id text) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE r record;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  SELECT t.id,t.amount,t.sim_line_id,coalesce(t.metadata->>'plan',
    CASE lower(t.description) WHEN 'annual plan fee debit (standard)' THEN 'standard' WHEN 'annual plan fee debit (premium)' THEN 'premium' END) plan
    INTO r FROM public.wallet_transactions t WHERE t.user_id=auth.uid() AND t.reference_id=p_reference_id
      AND t.type='plan_fee_debit' AND t.status='completed' AND t.balance_before-t.balance_after=t.amount;
  IF FOUND THEN
    IF EXISTS(SELECT 1 FROM public.wallet_transaction_funding WHERE transaction_id=r.id AND reversed_amount>0) THEN RAISE EXCEPTION 'Plan payment was reversed'; END IF;
    RETURN jsonb_build_object('amount',r.amount,'sim_line_id',r.sim_line_id,'plan',r.plan);
  END IF;
  SELECT g.credit_usd amount,g.sim_line_id,g.plan INTO r FROM public.line_plan_grants g
    WHERE g.source_key='wallet:'||p_reference_id AND g.user_id=auth.uid() AND g.revoked_at IS NULL;
  IF FOUND THEN RETURN jsonb_build_object('amount',r.amount,'sim_line_id',r.sim_line_id,'plan',r.plan); END IF;
  RETURN NULL;
END $$;
REVOKE ALL ON FUNCTION public.get_owned_plan_payment_receipt(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_owned_plan_payment_receipt(text) TO authenticated,service_role;

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
  IF v_gw_pct>=100 OR v_gw_pct<0 OR v_gw_fixed<0 OR v_gw_pct::text IN ('NaN','Infinity','-Infinity') OR v_gw_fixed::text IN ('NaN','Infinity','-Infinity') THEN
    RAISE EXCEPTION 'Invalid gateway fee policy' USING ERRCODE='22023';
  END IF;

  IF v_net=0 THEN RETURN 0; END IF;
  RETURN round((v_net + v_gw_fixed) / (1.0 - (v_gw_pct / 100.0)), 2);
END;
$function$;
NOTIFY pgrst,'reload schema';
COMMIT;
