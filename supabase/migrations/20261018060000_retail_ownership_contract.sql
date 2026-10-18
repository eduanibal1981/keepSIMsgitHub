BEGIN;

CREATE OR REPLACE FUNCTION public.get_return_trip_history_for_line(
  p_sim_line_id UUID,
  p_user_id UUID DEFAULT auth.uid()
)
RETURNS TABLE (
  trip_id UUID,
  sim_line_id UUID,
  destination_country_id UUID,
  arrival_date DATE,
  status TEXT,
  package_id UUID,
  package_type TEXT,
  package_title TEXT,
  carrier_name TEXT,
  data_allowance_mb INT,
  duration_days INT,
  is_unlimited BOOLEAN,
  effective_price_usd NUMERIC,
  ussd_recharge_code TEXT,
  activation_instructions TEXT,
  badge_label TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  PERFORM public.assert_return_trip_owner(p_sim_line_id,p_user_id);
  RETURN QUERY
  SELECT 
    t.id AS trip_id,
    t.sim_line_id,
    t.destination_country_id,
    t.arrival_date,
    t.status,
    p.id AS package_id,
    coalesce(p.package_type, t.chosen_package_type) AS package_type,
    coalesce(p.title, 'Curated Return Pack') AS package_title,
    c.name AS carrier_name,
    coalesce(p.data_allowance_mb, 0) AS data_allowance_mb,
    coalesce(p.duration_days, 1) AS duration_days,
    coalesce(p.is_unlimited, false) AS is_unlimited,
    t.accepted_price_usd AS effective_price_usd,
    p.ussd_recharge_code,
    p.activation_instructions,
    p.badge_label,
    t.notes,
    t.created_at
  FROM public.return_trips t
  LEFT JOIN public.return_trip_packages p ON p.id = t.chosen_package_id
  LEFT JOIN public.carriers c ON c.id = p.carrier_id
  WHERE t.sim_line_id = p_sim_line_id
    AND t.user_id = p_user_id
  ORDER BY t.arrival_date DESC, t.created_at DESC;
END;
$$;



-- Reassert retail return shapes after the independently released Task 3
-- containment, which deliberately retained the captured wholesale shapes.
-- RESTRICT makes any unreviewed dependent object a release blocker.

DROP FUNCTION public.get_return_trip_packages_for_line(uuid,uuid);
CREATE OR REPLACE FUNCTION public.get_return_trip_packages_for_line(
  p_sim_line_id UUID,
  p_user_id     UUID DEFAULT auth.uid()
)
RETURNS TABLE (
  id UUID,
  country_id UUID,
  carrier_id UUID,
  carrier_name TEXT,
  package_type TEXT,
  title TEXT,
  description TEXT,
  data_allowance_mb INT,
  duration_days INT,
  is_unlimited BOOLEAN,
  retail_price_usd NUMERIC,
  effective_price_usd NUMERIC,
  discount_usd NUMERIC,
  ussd_recharge_code TEXT,
  activation_instructions TEXT,
  badge_label TEXT,
  account_tier TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_line_country_id UUID;
  v_line_carrier_id UUID;
  v_tier            TEXT := 'free';
  v_discount_rate   NUMERIC := 0.00;
BEGIN
  PERFORM public.assert_return_trip_owner(p_sim_line_id,p_user_id);
  -- Resolve line country and carrier
  SELECT sl.country_id, sl.carrier_id INTO v_line_country_id, v_line_carrier_id
  FROM public.sim_lines sl
  WHERE sl.id = p_sim_line_id;

  IF v_line_country_id IS NULL THEN
    RETURN;
  END IF;

  -- Resolve account commerce tier
  v_tier := public.resolve_account_commerce_benefit(p_user_id);
  IF v_tier IS NULL THEN
    v_tier := 'free';
  END IF;

  -- App Fee Discount per Tier:
  -- Premium: 100% app fee discount ($0 fee)
  -- Standard: 50% app fee discount
  -- Free: 0% app fee discount
  IF v_tier = 'premium' THEN
    v_discount_rate := 1.00;
  ELSIF v_tier = 'standard' THEN
    v_discount_rate := 0.50;
  ELSE
    v_discount_rate := 0.00;
  END IF;

  RETURN QUERY
  SELECT 
    pkg.id,
    pkg.country_id,
    pkg.carrier_id,
    c.name AS carrier_name,
    pkg.package_type,
    pkg.title,
    pkg.description,
    pkg.data_allowance_mb,
    pkg.duration_days,
    pkg.is_unlimited,
    pkg.retail_price_usd,
    public.return_trip_retail_price(pkg.id,p_user_id) AS effective_price_usd,
    pkg.retail_price_usd-public.return_trip_retail_price(pkg.id,p_user_id) AS discount_usd,
    pkg.ussd_recharge_code,
    pkg.activation_instructions,
    pkg.badge_label,
    v_tier AS account_tier
  FROM public.return_trip_packages pkg
  LEFT JOIN public.carriers c ON c.id = pkg.carrier_id
  WHERE pkg.country_id = v_line_country_id
    AND pkg.is_active = true
  ORDER BY 
    CASE 
      WHEN pkg.package_type = 'esim' THEN 0
      WHEN v_line_carrier_id IS NOT NULL AND pkg.carrier_id = v_line_carrier_id THEN 1
      ELSE 2
    END,
    effective_price_usd ASC;
END;
$$;



REVOKE ALL ON FUNCTION public.get_return_trip_packages_for_line(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.get_return_trip_packages_for_line(uuid,uuid) TO authenticated,service_role;

DROP FUNCTION public.get_user_calling_rates(uuid);
CREATE OR REPLACE FUNCTION public.get_user_calling_rates(p_user_id uuid DEFAULT auth.uid())
 RETURNS TABLE(id uuid, country_code text, country_name text, phone_prefix text, destination_type text, base_rate_per_minute_usd numeric, effective_rate_per_minute_usd numeric, connection_fee_usd numeric, billing_increment_seconds integer, account_tier text, is_active boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_tier TEXT;
BEGIN
  PERFORM public.assert_wallet_access(p_user_id);
  v_tier := public.resolve_account_commerce_benefit(p_user_id);
  
  RETURN QUERY
  SELECT 
    r.id,
    r.country_code,
    r.country_name,
    r.phone_prefix,
    r.destination_type,
    r.rate_per_minute_usd AS base_rate_per_minute_usd,
    round(
      CASE 
        WHEN r.cost_per_minute_usd IS NOT NULL AND r.cost_per_minute_usd > 0 THEN
          r.cost_per_minute_usd + COALESCE(
            public.resolve_app_fee('intelcallfee', v_tier, r.cost_per_minute_usd),
            CASE v_tier
              WHEN 'premium'  THEN round(r.cost_per_minute_usd * 0.05, 4)
              WHEN 'standard' THEN round(r.cost_per_minute_usd * 0.10, 4)
              ELSE round(r.cost_per_minute_usd * 0.15, 4)
            END
          )
        ELSE r.rate_per_minute_usd
      END,
      4
    ) AS effective_rate_per_minute_usd,
    0.00::NUMERIC AS connection_fee_usd, -- Strictly $0 connection fee per C12
    r.billing_increment_seconds,
    v_tier AS account_tier,
    r.is_active
  FROM public.call_rates r
  WHERE r.is_active = true
  ORDER BY r.country_name;
END;
$function$;



REVOKE ALL ON FUNCTION public.get_user_calling_rates(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_calling_rates(uuid) TO authenticated,service_role;

DROP FUNCTION public.get_call_rate_for_number(text,uuid);
CREATE OR REPLACE FUNCTION public.get_call_rate_for_number(p_phone_number text, p_user_id uuid DEFAULT auth.uid())
 RETURNS TABLE(id uuid, country_code text, country_name text, phone_prefix text, rate_per_minute_usd numeric, connection_fee_usd numeric, billing_increment_seconds integer, account_tier text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_clean_number TEXT;
  v_tier         TEXT;
  v_rate         RECORD;
  v_effective    NUMERIC;
  v_fee          NUMERIC;
BEGIN
  PERFORM public.assert_wallet_access(p_user_id);
  -- 1. Resolve Halo tier for this account
  v_tier := public.resolve_account_commerce_benefit(p_user_id);

  -- 2. Normalize number format
  v_clean_number := regexp_replace(p_phone_number, '[^0-9+]', '', 'g');
  IF NOT (v_clean_number LIKE '+%') THEN
    v_clean_number := '+' || v_clean_number;
  END IF;

  SELECT
    cr.id,
    cr.country_code,
    cr.country_name,
    cr.phone_prefix,
    cr.rate_per_minute_usd,
    cr.cost_per_minute_usd,
    0.00::NUMERIC AS connection_fee_usd, -- Strictly $0 connection fee per C12
    cr.billing_increment_seconds
  INTO v_rate
  FROM public.call_rates cr
  WHERE cr.is_active = TRUE
    AND v_clean_number LIKE (cr.phone_prefix || '%')
  ORDER BY length(cr.phone_prefix) DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- 3. Calculate effective rate per minute with intelcallfee app fee rule
  IF v_rate.cost_per_minute_usd IS NOT NULL AND v_rate.cost_per_minute_usd > 0 THEN
    v_fee := public.resolve_app_fee('intelcallfee', v_tier, v_rate.cost_per_minute_usd);
    IF v_fee IS NULL THEN
      -- Fallback to default draft percentages if no rule in table
      v_fee := CASE v_tier
        WHEN 'premium'  THEN round(v_rate.cost_per_minute_usd * 0.05, 4)
        WHEN 'standard' THEN round(v_rate.cost_per_minute_usd * 0.10, 4)
        ELSE round(v_rate.cost_per_minute_usd * 0.15, 4)
      END;
    END IF;
    v_effective := round(v_rate.cost_per_minute_usd + v_fee, 4);
  ELSE
    v_effective := v_rate.rate_per_minute_usd;
  END IF;

  RETURN QUERY
  SELECT
    v_rate.id,
    v_rate.country_code,
    v_rate.country_name,
    v_rate.phone_prefix,
    v_effective AS rate_per_minute_usd,
    0.00::NUMERIC AS connection_fee_usd,
    v_rate.billing_increment_seconds,
    v_tier AS account_tier;
END;
$function$;



REVOKE ALL ON FUNCTION public.get_call_rate_for_number(text,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.get_call_rate_for_number(text,uuid) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION "public"."list_refill_offers"("p_sim_line_id" "uuid") RETURNS TABLE("provider" "text", "offer_id" "text", "offer_name" "text", "price_type" "text", "price_fixed_usd" numeric, "price_min_usd" numeric, "price_max_usd" numeric, "send_min" numeric, "send_max" numeric, "send_currency" "text", "send_currency_divisor" numeric, "refreshed_at" timestamp with time zone, "is_stale" boolean, "delivery_type" "text", "service_type" "text", "benefit_summary" "text", "data_mb" bigint, "duration_days" integer)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.sim_lines sl
    WHERE sl.id = p_sim_line_id
      AND (sl.user_id = auth.uid()
           OR EXISTS (SELECT 1 FROM public.household_members hm
                      WHERE hm.owner_id = sl.user_id
                        AND hm.member_id = auth.uid()
                        AND hm.invite_status = 'accepted'
                        AND hm.role = 'manager'))
  ) THEN
    RAISE EXCEPTION 'SIM ownership required' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT
    poc.api_provider,
    poc.offer_id,
    poc.offer_name,
    poc.price_type,
    CASE WHEN poc.price_fixed_usd IS NOT NULL THEN round(poc.price_fixed_usd+public.resolve_app_fee('refills',public.resolve_line_entitlement(p_sim_line_id)->>'effective_tier',poc.price_fixed_usd),2) END AS retail_fixed,
    CASE WHEN poc.price_min_usd IS NOT NULL THEN round(poc.price_min_usd+public.resolve_app_fee('refills',public.resolve_line_entitlement(p_sim_line_id)->>'effective_tier',poc.price_min_usd),2) END AS retail_min,
    CASE WHEN poc.price_max_usd IS NOT NULL THEN round(poc.price_max_usd+public.resolve_app_fee('refills',public.resolve_line_entitlement(p_sim_line_id)->>'effective_tier',poc.price_max_usd),2) END,
    poc.send_min,
    poc.send_max,
    poc.send_currency,
    poc.send_currency_divisor,
    poc.refreshed_at,
    (poc.refreshed_at < now() - interval '24 hours') AS is_stale,
    COALESCE(poc.delivery_type, 'direct') AS delivery_type,
    COALESCE(poc.service_type, 'airtime') AS service_type,
    COALESCE(poc.benefit_summary, poc.offer_name) AS benefit_summary,
    poc.data_mb,
    poc.duration_days
  FROM public.sim_lines sl
  JOIN public.carrier_provider_map m
    ON m.carrier_id = sl.carrier_id
   AND m.is_enabled = true
  JOIN public.provider_offers_cache poc
    ON poc.api_provider  = m.provider
   AND poc.country_code  = m.provider_country_code
   AND poc.carrier_code  = m.provider_carrier_code
  WHERE sl.id = p_sim_line_id
  ORDER BY
    coalesce(CASE WHEN poc.price_fixed_usd IS NOT NULL THEN round(poc.price_fixed_usd+public.resolve_app_fee('refills',public.resolve_line_entitlement(p_sim_line_id)->>'effective_tier',poc.price_fixed_usd),2) END, CASE WHEN poc.price_min_usd IS NOT NULL THEN round(poc.price_min_usd+public.resolve_app_fee('refills',public.resolve_line_entitlement(p_sim_line_id)->>'effective_tier',poc.price_min_usd),2) END) ASC NULLS LAST,
    m.priority ASC,
    poc.offer_id ASC;
END;
$$;

CREATE OR REPLACE FUNCTION "public"."list_carrier_offers"("p_carrier_id" "uuid") RETURNS TABLE("provider" "text", "offer_id" "text", "offer_name" "text", "price_type" "text", "price_usd" numeric, "price_min_usd" numeric, "price_max_usd" numeric, "send_min" numeric, "send_max" numeric, "send_currency" "text", "send_currency_divisor" numeric, "refreshed_at" timestamp with time zone, "is_stale" boolean)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT o.provider_code, o.offer_code, o.effective_name, o.source_price_type,
         (CASE WHEN o.effective_price_usd IS NOT NULL THEN round(o.effective_price_usd+public.resolve_app_fee('refills',public.resolve_account_commerce_benefit(auth.uid()),o.effective_price_usd),2) END), (CASE WHEN o.source_price_min_usd IS NOT NULL THEN round(o.source_price_min_usd+public.resolve_app_fee('refills',public.resolve_account_commerce_benefit(auth.uid()),o.source_price_min_usd),2) END), (CASE WHEN o.source_price_max_usd IS NOT NULL THEN round(o.source_price_max_usd+public.resolve_app_fee('refills',public.resolve_account_commerce_benefit(auth.uid()),o.source_price_max_usd),2) END),
         o.source_send_min, o.source_send_max, o.source_send_currency,
         COALESCE(o.source_send_divisor, 100),
         o.source_refreshed_at,
         (o.source_refreshed_at < now() - interval '24 hours')
  FROM public.provider_offers o
  JOIN public.carrier_supplier_routing r
    ON r.carrier_id = o.carrier_id AND r.provider_code = o.provider_code
  WHERE o.carrier_id = p_carrier_id
    AND o.offer_kind = 'topup'
    AND o.is_active
    -- Only offers that can actually be routed and bought. Listing anything else
    -- is how a tap turns into "offer is not available for this SIM line".
    AND r.is_routable
  ORDER BY (CASE WHEN o.effective_price_usd IS NOT NULL THEN round(o.effective_price_usd+public.resolve_app_fee('refills',public.resolve_account_commerce_benefit(auth.uid()),o.effective_price_usd),2) END) ASC NULLS LAST, r.priority ASC, o.offer_code ASC;
END;
$$;

-- Raw catalogues and diagnostic views are backend-only. Clear column ACLs too:
-- a table REVOKE alone does not remove historical column grants.
DO $$
DECLARE rel text; cols text;
BEGIN
  FOREACH rel IN ARRAY ARRAY['provider_offers','provider_offers_cache','provider_offers_effective',
    'zendit_offers_cache','esim_offers_cache','esim_suppliers','return_trip_packages','call_rates','esim_orders'] LOOP
    EXECUTE format('REVOKE ALL ON TABLE public.%I FROM PUBLIC,anon,authenticated',rel);
    SELECT string_agg(quote_ident(attname),',') INTO cols FROM pg_attribute
      WHERE attrelid=format('public.%I',rel)::regclass AND attnum>0 AND NOT attisdropped;
    EXECUTE format('REVOKE ALL (%s) ON TABLE public.%I FROM PUBLIC,anon,authenticated',cols,rel);
    GRANT USAGE ON SCHEMA public TO service_role;
    EXECUTE format('GRANT SELECT ON TABLE public.%I TO service_role',rel);
  END LOOP;
END $$;
-- A legitimate legacy calling fallback has only published retail columns.
GRANT SELECT(id,country_code,country_name,phone_prefix,destination_type,rate_per_minute_usd,
  connection_fee_usd,billing_increment_seconds,is_active) ON public.call_rates TO authenticated;

-- The receipt uses the caller's RLS and narrow base-column privileges. Provider
-- references, raw errors, cost and markup are excluded even for an owned order.
ALTER TABLE public.esim_orders ENABLE ROW LEVEL SECURITY;
DO $$ DECLARE p record; BEGIN
  FOR p IN SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename='esim_orders' LOOP
    EXECUTE format('DROP POLICY %I ON public.esim_orders',p.policyname);
  END LOOP;
END $$;
CREATE POLICY esim_order_owner_read ON public.esim_orders FOR SELECT TO authenticated
  USING(user_id=(SELECT auth.uid()));
GRANT SELECT(id,user_id,provider,bundle_name,quantity,retail_price_usd,status,created_at,updated_at,total_amount_usd)
  ON public.esim_orders TO authenticated;
CREATE VIEW public.customer_esim_orders WITH (security_invoker=true,security_barrier=true) AS
SELECT id,user_id,provider,bundle_name,quantity,retail_price_usd,status,created_at,updated_at,total_amount_usd
 ,CASE WHEN status='failed' THEN 'eSIM order could not be completed.' END AS error_message FROM public.esim_orders;
REVOKE ALL ON public.customer_esim_orders FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.customer_esim_orders TO authenticated,service_role;

-- Entitlement and fee-basis helpers are internal APIs, including all overloads
-- captured by Task 3. Customer prices are computed for the verified caller.
REVOKE ALL ON FUNCTION public.resolve_line_entitlement(uuid),public.resolve_account_commerce_benefit(uuid),
  public.has_paid_premium_entitlement(uuid),public.line_paid_plan_evidence(uuid,text),
  public.resolve_esim_offer_price(numeric,uuid),public.return_trip_retail_price(uuid,uuid),
  public.standard_upgrade_credit_usd(uuid),public.get_authoritative_refill_quote(uuid,numeric,text,text,text),
  public.pick_best_refill_offer(uuid,numeric) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_line_entitlement(uuid),public.resolve_account_commerce_benefit(uuid),
  public.has_paid_premium_entitlement(uuid),public.line_paid_plan_evidence(uuid,text),
  public.resolve_esim_offer_price(numeric,uuid),public.return_trip_retail_price(uuid,uuid),
  public.standard_upgrade_credit_usd(uuid),public.get_authoritative_refill_quote(uuid,numeric,text,text,text),
  public.pick_best_refill_offer(uuid,numeric) TO service_role;

-- A view's caller needs EXECUTE on functions in its target list. Use a catalogue-key
-- definer wrapper with caller identity; do not grant the arbitrary cost/user API.
CREATE FUNCTION public.customer_esim_price(p_provider text,p_bundle_name text) RETURNS numeric
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE price numeric;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  SELECT public.resolve_esim_offer_price(c.wholesale_price_usd,auth.uid()) INTO price
    FROM public.esim_offers_cache c WHERE c.provider=p_provider AND c.bundle_name=p_bundle_name AND c.is_active;
  RETURN price;
END $$;
REVOKE ALL ON FUNCTION public.customer_esim_price(text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.customer_esim_price(text,text) TO authenticated,service_role;
CREATE OR REPLACE VIEW public.esim_offers WITH (security_barrier=true,security_invoker=false) AS
SELECT c.provider||'_'||c.bundle_name AS id,c.provider,c.bundle_name,c.description,c.countries,
  c.roaming_enabled,c.data_amount_mb,c.duration_days,
  public.customer_esim_price(c.provider,c.bundle_name)::numeric(10,2) AS retail_price_usd,
  c.image_url,c.is_active,c.updated_at,c.is_unlimited,c.bundle_group,c.speed_tier,c.region,c.country_count,
  CASE WHEN c.is_unlimited OR c.data_amount_mb<=0 THEN NULL::numeric
    ELSE round(public.customer_esim_price(c.provider,c.bundle_name)/(c.data_amount_mb::numeric/1024),2)
  END::numeric(10,2) AS price_per_gb_usd
FROM public.esim_offers_cache c WHERE c.is_active AND auth.uid() IS NOT NULL;
REVOKE ALL ON public.esim_offers FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.esim_offers TO authenticated,service_role;

-- Exact selected-offer pricing. The helper's supplier projection is never
-- customer executable. It supports airtime/data/PIN offers without guessing FX.
CREATE FUNCTION public.selected_refill_quote_internal(p_sim_line_id uuid,p_offer_id text,p_offer_value numeric DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE o public.provider_offers_cache; tier text; base numeric; total numeric;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.sim_lines l WHERE l.id=p_sim_line_id AND (l.user_id=auth.uid()
    OR EXISTS(SELECT 1 FROM public.household_members m WHERE m.owner_id=l.user_id AND m.member_id=auth.uid()
      AND m.invite_status='accepted' AND m.role='manager'))) THEN
    RAISE EXCEPTION 'SIM ownership required' USING ERRCODE='42501'; END IF;
  SELECT c.* INTO o FROM public.choose_supplier_for_offer(p_sim_line_id,p_offer_id,NULL) pick
    JOIN public.provider_offers_cache c ON c.api_provider=pick.provider AND c.offer_id=p_offer_id
    JOIN public.sim_lines l ON l.id=p_sim_line_id
    JOIN public.carrier_provider_map m ON m.carrier_id=l.carrier_id AND m.provider=c.api_provider
      AND m.provider_country_code=c.country_code AND m.provider_carrier_code=c.carrier_code AND m.is_enabled
    LIMIT 1;
  IF o.offer_id IS NULL OR o.refreshed_at<now()-interval '24 hours' THEN
    RAISE EXCEPTION 'Offer pricing unavailable'; END IF;
  -- Match the existing fixed-offer charge: preserve supplier precision until
  -- the retail total is rounded. RANGE dispatch uses its cent-rounded USD basis.
  IF o.price_type='FIXED' THEN base:=o.price_fixed_usd;
  ELSE
    IF p_offer_value IS NULL OR p_offer_value::text IN ('NaN','Infinity','-Infinity')
      OR p_offer_value<o.send_min OR p_offer_value>o.send_max OR o.send_max<=o.send_min THEN
      RAISE EXCEPTION 'Invalid refill value'; END IF;
    base:=round(o.price_min_usd+(p_offer_value-o.send_min)*(o.price_max_usd-o.price_min_usd)/(o.send_max-o.send_min),2);
  END IF;
  IF base IS NULL OR base<=0 OR base::text IN ('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'Offer pricing unavailable'; END IF;
  tier:=public.resolve_line_entitlement(p_sim_line_id)->>'effective_tier';
  total:=round(base+public.resolve_app_fee('refills',tier,base),2);
  RETURN jsonb_build_object('offer_id',o.offer_id,'offer_value',p_offer_value,'provider',o.api_provider,
    'wholesale_cost_usd',base,'total_charge_usd',total,'currency','USD','pricing_tier',tier,'quote_created_at',now());
END $$;
REVOKE ALL ON FUNCTION public.selected_refill_quote_internal(uuid,text,numeric) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.selected_refill_quote_internal(uuid,text,numeric) TO service_role;
CREATE FUNCTION public.get_customer_refill_quote(p_sim_line_id uuid,p_offer_id text,p_offer_value numeric DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE q jsonb;
BEGIN
  q:=public.selected_refill_quote_internal(p_sim_line_id,p_offer_id,p_offer_value);
  RETURN jsonb_build_object('offer_id',q->'offer_id','offer_value',q->'offer_value','total_charge_usd',q->'total_charge_usd',
    'currency','USD','pricing_tier',q->'pricing_tier','quote_created_at',q->'quote_created_at');
END $$;
REVOKE ALL ON FUNCTION public.get_customer_refill_quote(uuid,text,numeric) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.get_customer_refill_quote(uuid,text,numeric) TO authenticated;

-- Keep legacy internal submission logic and its risk/household checks, but do
-- not ask a customer to know supplier cost. The retail ceiling is checked both
-- before and after creation; any price drift rolls the whole request back.
CREATE FUNCTION public.request_retail_instant_refill(p_sim_line_id uuid,p_offer_id text,p_max_authorized_usd numeric,
  p_offer_value numeric DEFAULT NULL,p_device_id text DEFAULT NULL) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE q jsonb; eid uuid; charged numeric;
BEGIN
  q:=public.selected_refill_quote_internal(p_sim_line_id,p_offer_id,p_offer_value);
  IF p_max_authorized_usd IS NULL OR p_max_authorized_usd<=0 OR p_max_authorized_usd::text IN ('NaN','Infinity','-Infinity')
    OR (q->>'total_charge_usd')::numeric>p_max_authorized_usd THEN RAISE EXCEPTION 'Price changed; review the current quote'; END IF;
  eid:=public.request_instant_refill(p_sim_line_id,p_offer_id,'wallet',(q->>'wholesale_cost_usd')::numeric,p_device_id);
  SELECT amount INTO charged FROM public.topup_executions WHERE id=eid;
  IF charged IS DISTINCT FROM (q->>'total_charge_usd')::numeric OR charged>p_max_authorized_usd THEN
    RAISE EXCEPTION 'Price changed; review the current quote'; END IF;
  -- Persist the exact customer-selected dispatch value; inversion of rounded USD
  -- can otherwise drift by one provider unit on a RANGE offer.
  UPDATE public.topup_executions SET offer_value=p_offer_value WHERE id=eid AND p_offer_value IS NOT NULL;
  RETURN eid;
EXCEPTION WHEN SQLSTATE 'KS451' THEN
  RAISE EXCEPTION 'DEVICE_BLOCKED' USING ERRCODE='KS451';
WHEN SQLSTATE '42501' THEN
  RAISE EXCEPTION 'SIM ownership required' USING ERRCODE='42501';
WHEN OTHERS THEN
  RAISE EXCEPTION 'Refill pricing or authorization changed. Review a fresh quote.' USING ERRCODE='22023';
END $$;
REVOKE ALL ON FUNCTION public.request_retail_instant_refill(uuid,text,numeric,numeric,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.request_retail_instant_refill(uuid,text,numeric,numeric,text) TO authenticated;
REVOKE ALL ON FUNCTION public.request_instant_refill(uuid,text,text,numeric,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.request_instant_refill(uuid,text,text,numeric,text) TO service_role;
REVOKE ALL ON FUNCTION public.list_refill_offers(uuid),public.list_carrier_offers(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.list_refill_offers(uuid),public.list_carrier_offers(uuid) TO authenticated,service_role;

-- Replace all permissive legacy trip policies: owner AND referenced line owner
-- must agree for reads, deletes and both sides of updates.
ALTER TABLE public.return_trips ENABLE ROW LEVEL SECURITY;
DO $$ DECLARE p record; BEGIN
  FOR p IN SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename='return_trips' LOOP
    EXECUTE format('DROP POLICY %I ON public.return_trips',p.policyname);
  END LOOP;
END $$;
CREATE POLICY return_trip_owner ON public.return_trips FOR ALL TO authenticated
  USING(user_id=(SELECT auth.uid()) AND EXISTS(SELECT 1 FROM public.sim_lines l WHERE l.id=sim_line_id AND l.user_id=(SELECT auth.uid())))
  WITH CHECK(user_id=(SELECT auth.uid()) AND EXISTS(SELECT 1 FROM public.sim_lines l WHERE l.id=sim_line_id AND l.user_id=(SELECT auth.uid())));
REVOKE ALL ON public.return_trips FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.return_trips TO authenticated;
CREATE OR REPLACE FUNCTION public.guard_return_trip_contract()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE l public.sim_lines; p public.return_trip_packages; v_quote numeric;
BEGIN
  SELECT * INTO l FROM public.sim_lines WHERE id=NEW.sim_line_id AND user_id=NEW.user_id;
  IF NOT FOUND OR l.country_id IS DISTINCT FROM NEW.destination_country_id THEN
    RAISE EXCEPTION 'Owned destination SIM required' USING ERRCODE='42501';
  END IF;
  IF TG_OP='UPDATE' AND (NEW.user_id<>OLD.user_id OR NEW.sim_line_id<>OLD.sim_line_id) THEN
    RAISE EXCEPTION 'Trip ownership cannot change' USING ERRCODE='42501';
  END IF;
  IF TG_OP='UPDATE' AND OLD.status<>'planning' AND NEW.status='planning' THEN
    RAISE EXCEPTION 'Accepted trip cannot return to planning' USING ERRCODE='42501';
  END IF;
  IF TG_OP='UPDATE' AND OLD.status<>'planning' AND (NEW.chosen_package_id IS DISTINCT FROM OLD.chosen_package_id
    OR NEW.chosen_package_type IS DISTINCT FROM OLD.chosen_package_type) THEN
    RAISE EXCEPTION 'Accepted package cannot change' USING ERRCODE='42501';
  END IF;
  IF NEW.chosen_package_id IS NOT NULL THEN
    SELECT * INTO p FROM public.return_trip_packages WHERE id=NEW.chosen_package_id;
    IF NOT FOUND OR p.country_id<>NEW.destination_country_id OR p.package_type IS DISTINCT FROM NEW.chosen_package_type THEN
      RAISE EXCEPTION 'Package does not match this trip';
    END IF;
  END IF;
  IF TG_OP='INSERT' OR NEW.chosen_package_id IS DISTINCT FROM OLD.chosen_package_id THEN
    v_quote:=public.return_trip_retail_price(NEW.chosen_package_id,NEW.user_id);
    IF NEW.accepted_price_usd IS NOT NULL AND NEW.accepted_price_usd IS DISTINCT FROM v_quote THEN
      RAISE EXCEPTION 'Package price changed; review the current quote';
    END IF;
    NEW.accepted_price_usd:=v_quote;
    IF NEW.chosen_package_id IS NOT NULL AND NEW.accepted_price_usd IS NULL THEN RAISE EXCEPTION 'Package unavailable'; END IF;
    NEW.price_accepted_at:=CASE WHEN NEW.accepted_price_usd IS NOT NULL THEN now() END;
  ELSE
    NEW.accepted_price_usd:=OLD.accepted_price_usd;
    NEW.price_accepted_at:=OLD.price_accepted_at;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_active_return_trip_for_line(
  p_sim_line_id UUID,
  p_user_id     UUID DEFAULT auth.uid()
)
RETURNS TABLE (
  trip_id UUID,
  sim_line_id UUID,
  destination_country_id UUID,
  arrival_date DATE,
  status TEXT,
  package_id UUID,
  package_type TEXT,
  package_title TEXT,
  carrier_name TEXT,
  data_allowance_mb INT,
  duration_days INT,
  is_unlimited BOOLEAN,
  effective_price_usd NUMERIC,
  ussd_recharge_code TEXT,
  activation_instructions TEXT,
  badge_label TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  PERFORM public.assert_return_trip_owner(p_sim_line_id,p_user_id);
  RETURN QUERY
  SELECT 
    t.id AS trip_id,
    t.sim_line_id,
    t.destination_country_id,
    t.arrival_date,
    t.status,
    p.id AS package_id,
    coalesce(p.package_type, t.chosen_package_type) AS package_type,
    coalesce(p.title, 'Curated Return Pack') AS package_title,
    c.name AS carrier_name,
    coalesce(p.data_allowance_mb, 0) AS data_allowance_mb,
    coalesce(p.duration_days, 1) AS duration_days,
    coalesce(p.is_unlimited, false) AS is_unlimited,
    t.accepted_price_usd AS effective_price_usd,
    p.ussd_recharge_code,
    p.activation_instructions,
    p.badge_label,
    t.notes,
    t.created_at
  FROM public.return_trips t
  LEFT JOIN public.return_trip_packages p ON p.id = t.chosen_package_id
  LEFT JOIN public.carriers c ON c.id = p.carrier_id
  WHERE t.sim_line_id = p_sim_line_id
    AND t.user_id = p_user_id
    AND t.status IN ('planning', 'data_ready', 'arrived')
  ORDER BY t.created_at DESC
  LIMIT 1;
END;
$$;


-- Receipt/history projections also exclude embedded supplier payloads.

REVOKE SELECT ON public.topup_executions FROM PUBLIC,anon,authenticated;
DO $$ DECLARE names text; BEGIN
  SELECT string_agg(quote_ident(attname),',') INTO names FROM pg_attribute
    WHERE attrelid='public.topup_executions'::regclass AND attnum>0 AND NOT attisdropped;
  EXECUTE format('REVOKE SELECT (%s) ON public.topup_executions FROM PUBLIC,anon,authenticated',names);
END $$;
GRANT SELECT(id,scheduled_topup_id,sim_line_id,user_id,amount,currency,status,retry_of,validity_days_added,executed_at,completed_at,created_at,fulfillment_gateway,api_provider,execution_type,execution_time,offer_id,offer_value,payment_gateway_code,refill_channel,message_fee_usd,acting_user_id,pin_code,pin_serial,redeem_instructions,updated_at,funding_kind,target_local_value,target_local_currency,max_authorized_usd,engine_version,intent_kind) ON public.topup_executions TO authenticated;
CREATE VIEW public.customer_topup_executions WITH (security_invoker=true,security_barrier=true) AS
  SELECT id,scheduled_topup_id,sim_line_id,user_id,amount,currency,status,retry_of,validity_days_added,executed_at,completed_at,created_at,fulfillment_gateway,api_provider,execution_type,execution_time,offer_id,offer_value,payment_gateway_code,refill_channel,message_fee_usd,acting_user_id,pin_code,pin_serial,redeem_instructions,updated_at,funding_kind,target_local_value,target_local_currency,max_authorized_usd,engine_version,intent_kind,CASE WHEN status='failed' THEN 'Refill could not be completed.' END AS failure_reason FROM public.topup_executions;
REVOKE ALL ON public.customer_topup_executions FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.customer_topup_executions TO authenticated,service_role;

REVOKE SELECT ON public.scheduled_topups FROM PUBLIC,anon,authenticated;
DO $$ DECLARE names text; BEGIN
  SELECT string_agg(quote_ident(attname),',') INTO names FROM pg_attribute
    WHERE attrelid='public.scheduled_topups'::regclass AND attnum>0 AND NOT attisdropped;
  EXECUTE format('REVOKE SELECT (%s) ON public.scheduled_topups FROM PUBLIC,anon,authenticated',names);
END $$;
GRANT SELECT(id,sim_line_id,user_id,amount,currency,frequency_days,next_execution_at,last_execution_at,is_active,retry_count,max_retries,status,created_at,updated_at,whatsapp_sent_this_cycle,schedule_type,offer_id,offer_value,pricing_tier,fee_rule_version,target_local_value,target_local_currency,max_authorized_usd,preferred_provider,engine_version,intent_kind) ON public.scheduled_topups TO authenticated;
CREATE VIEW public.customer_scheduled_topups WITH (security_invoker=true,security_barrier=true) AS
  SELECT id,sim_line_id,user_id,amount,currency,frequency_days,next_execution_at,last_execution_at,is_active,retry_count,max_retries,status,created_at,updated_at,whatsapp_sent_this_cycle,schedule_type,offer_id,offer_value,pricing_tier,fee_rule_version,target_local_value,target_local_currency,max_authorized_usd,preferred_provider,engine_version,intent_kind FROM public.scheduled_topups;
REVOKE ALL ON public.customer_scheduled_topups FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.customer_scheduled_topups TO authenticated,service_role;

REVOKE SELECT ON public.call_records FROM PUBLIC,anon,authenticated;
DO $$ DECLARE names text; BEGIN
  SELECT string_agg(quote_ident(attname),',') INTO names FROM pg_attribute
    WHERE attrelid='public.call_records'::regclass AND attnum>0 AND NOT attisdropped;
  EXECUTE format('REVOKE SELECT (%s) ON public.call_records FROM PUBLIC,anon,authenticated',names);
END $$;
GRANT SELECT(id,user_id,sim_line_id,call_type,caller_number,destination_number,destination_country_code,destination_country_name,status,started_at,answered_at,ended_at,duration_seconds,billed_duration_seconds,rate_per_minute_usd,total_cost_usd,wallet_txn_id,created_at,updated_at,requested_caller_id,effective_caller_id,caller_id_type,policy_reason,policy_version,sip_hangup_cause,telnyx_hangup_cause,hangup_source,cancellation_requested_at,idempotency_key,billing_increment_seconds) ON public.call_records TO authenticated;
CREATE VIEW public.customer_call_records WITH (security_invoker=true,security_barrier=true) AS
  SELECT id,user_id,sim_line_id,call_type,caller_number,destination_number,destination_country_code,destination_country_name,status,started_at,answered_at,ended_at,duration_seconds,billed_duration_seconds,rate_per_minute_usd,total_cost_usd,wallet_txn_id,created_at,updated_at,requested_caller_id,effective_caller_id,caller_id_type,policy_reason,policy_version,sip_hangup_cause,telnyx_hangup_cause,hangup_source,cancellation_requested_at,idempotency_key,billing_increment_seconds,CASE WHEN status='failed' THEN 'Call could not be completed.' END AS error_message FROM public.call_records;
REVOKE ALL ON public.customer_call_records FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.customer_call_records TO authenticated,service_role;
-- Administrative supplier inspection stays behind a server-checked boundary.
CREATE FUNCTION public.authorize_admin_catalogue_read() RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
  PERFORM public.assert_admin();
  RETURN true;
END $$;
REVOKE ALL ON FUNCTION public.authorize_admin_catalogue_read() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.authorize_admin_catalogue_read() TO authenticated;
CREATE VIEW public.admin_internal_provider_offers WITH (security_barrier=true,security_invoker=false) AS
 SELECT t.* FROM public.provider_offers t WHERE (SELECT public.authorize_admin_catalogue_read());
REVOKE ALL ON public.admin_internal_provider_offers FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.admin_internal_provider_offers TO authenticated;
CREATE VIEW public.admin_internal_provider_offers_cache WITH (security_barrier=true,security_invoker=false) AS
 SELECT t.* FROM public.provider_offers_cache t WHERE (SELECT public.authorize_admin_catalogue_read());
REVOKE ALL ON public.admin_internal_provider_offers_cache FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.admin_internal_provider_offers_cache TO authenticated;
CREATE VIEW public.admin_internal_topup_executions WITH (security_barrier=true,security_invoker=false) AS
 SELECT t.* FROM public.topup_executions t WHERE (SELECT public.authorize_admin_catalogue_read());
REVOKE ALL ON public.admin_internal_topup_executions FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.admin_internal_topup_executions TO authenticated;

-- Worker-produced price approval snapshots contain supplier routes. Expose only
-- the requested customer's retail total, with current line authorization.
REVOKE ALL ON public.refill_approval_quotes FROM PUBLIC,anon,authenticated;
DO $$ DECLARE names text; BEGIN
  SELECT string_agg(quote_ident(attname),',') INTO names FROM pg_attribute
    WHERE attrelid='public.refill_approval_quotes'::regclass AND attnum>0 AND NOT attisdropped;
  EXECUTE format('REVOKE ALL (%s) ON public.refill_approval_quotes FROM PUBLIC,anon,authenticated',names);
END $$;
CREATE VIEW public.customer_refill_approval_quotes WITH (security_barrier=true,security_invoker=false) AS
SELECT q.id,q.status,q.expires_at,
  jsonb_build_object('totalChargeUsd',q.route->'totalChargeUsd','targetLocalValue',q.route->'targetLocalValue',
    'targetLocalCurrency',q.route->'targetLocalCurrency') AS route,
  CASE WHEN q.status='failed' THEN 'Pricing unavailable. Please try again.' END AS error_message
FROM public.refill_approval_quotes q JOIN public.topup_executions e ON e.id=q.execution_id
JOIN public.sim_lines l ON l.id=e.sim_line_id
WHERE q.requested_by=auth.uid() AND (e.user_id=auth.uid() OR l.user_id=auth.uid()
  OR EXISTS(SELECT 1 FROM public.household_members m WHERE m.owner_id=l.user_id AND m.member_id=auth.uid()
    AND m.role='manager' AND m.invite_status='accepted'));
REVOKE ALL ON public.customer_refill_approval_quotes FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.customer_refill_approval_quotes TO authenticated;
REVOKE SELECT ON public.sim_setup_orders FROM PUBLIC,anon,authenticated;
DO $$ DECLARE names text; BEGIN
  SELECT string_agg(quote_ident(attname),',') INTO names FROM pg_attribute
    WHERE attrelid='public.sim_setup_orders'::regclass AND attnum>0 AND NOT attisdropped;
  EXECUTE format('REVOKE SELECT (%s) ON public.sim_setup_orders FROM PUBLIC,anon,authenticated',names);
END $$;
GRANT SELECT(id,user_id,sim_line_id,status,annual_fee_usd,first_refill_cost_usd,total_charge_usd,created_at,updated_at)
 ON public.sim_setup_orders TO authenticated;

REVOKE ALL ON FUNCTION public.get_active_return_trip_for_line(uuid,uuid),
 public.get_return_trip_history_for_line(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.get_active_return_trip_for_line(uuid,uuid),
 public.get_return_trip_history_for_line(uuid,uuid) TO authenticated,service_role;
REVOKE ALL ON FUNCTION public.choose_supplier_for_offer(uuid,text,text[]),
 public.supplier_candidates(uuid,text,text[]),public.supplier_effective_cost(text,numeric),
 public.carrier_refill_offer(uuid,numeric),public.resolve_app_fee(text,text,numeric)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.choose_supplier_for_offer(uuid,text,text[]),
 public.supplier_candidates(uuid,text,text[]),public.supplier_effective_cost(text,numeric),
 public.carrier_refill_offer(uuid,numeric),public.resolve_app_fee(text,text,numeric) TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;
