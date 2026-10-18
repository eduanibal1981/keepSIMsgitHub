BEGIN;

REVOKE SELECT ON public.return_trip_packages,public.call_rates FROM PUBLIC,anon,authenticated;
REVOKE SELECT(supplier_cost_usd) ON public.return_trip_packages FROM PUBLIC,anon,authenticated;
REVOKE SELECT(cost_per_minute_usd) ON public.call_rates FROM PUBLIC,anon,authenticated;
-- Safe legacy fallback reads remain available, with explicit column grants.
GRANT SELECT(id,country_code,country_name,phone_prefix,destination_type,rate_per_minute_usd,
  connection_fee_usd,billing_increment_seconds,is_active) ON public.call_rates TO authenticated;

CREATE FUNCTION public.assert_return_trip_owner(p_sim_line_id uuid,p_user_id uuid)
RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
  PERFORM public.assert_wallet_access(p_user_id);
  IF NOT EXISTS(SELECT 1 FROM public.sim_lines WHERE id=p_sim_line_id AND user_id=p_user_id) THEN
    RAISE EXCEPTION 'SIM ownership required' USING ERRCODE='42501';
  END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.assert_return_trip_owner(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.assert_return_trip_owner(uuid,uuid) TO service_role;

CREATE FUNCTION public.return_trip_retail_price(p_package_id uuid,p_user_id uuid)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
  SELECT round(p.retail_price_usd-greatest(0,p.retail_price_usd-p.supplier_cost_usd)*
    CASE public.resolve_account_commerce_benefit(p_user_id) WHEN 'premium' THEN 1 WHEN 'standard' THEN 0.5 ELSE 0 END,2)
  FROM public.return_trip_packages p WHERE p.id=p_package_id AND p.is_active;
$$;
REVOKE ALL ON FUNCTION public.return_trip_retail_price(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.return_trip_retail_price(uuid,uuid) TO service_role;

ALTER TABLE public.return_trips ADD COLUMN accepted_price_usd numeric CHECK(accepted_price_usd>=0),
  ADD COLUMN price_accepted_at timestamptz;

-- All write paths, including direct REST, validate the referenced line/package
-- and persist a server-derived accepted quote. Legacy history remains unknown.
CREATE FUNCTION public.guard_return_trip_contract()
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
REVOKE ALL ON FUNCTION public.guard_return_trip_contract() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.guard_return_trip_contract() TO service_role;
CREATE TRIGGER guard_return_trip_contract BEFORE INSERT OR UPDATE ON public.return_trips
  FOR EACH ROW EXECUTE FUNCTION public.guard_return_trip_contract();

DROP POLICY IF EXISTS "Users can insert their own return trips" ON public.return_trips;
CREATE POLICY "Users can insert their own return trips" ON public.return_trips FOR INSERT TO authenticated
  WITH CHECK(user_id=(SELECT auth.uid()) AND EXISTS(SELECT 1 FROM public.sim_lines l WHERE l.id=sim_line_id AND l.user_id=(SELECT auth.uid())));
DROP POLICY IF EXISTS "Users can update their own return trips" ON public.return_trips;
CREATE POLICY "Users can update their own return trips" ON public.return_trips FOR UPDATE TO authenticated
  USING(user_id=(SELECT auth.uid()))
  WITH CHECK(user_id=(SELECT auth.uid()) AND EXISTS(SELECT 1 FROM public.sim_lines l WHERE l.id=sim_line_id AND l.user_id=(SELECT auth.uid())));

DROP FUNCTION public.get_return_trip_packages_for_line(uuid,uuid);
DROP FUNCTION IF EXISTS public.get_call_rate_for_number(text);
DROP FUNCTION public.get_call_rate_for_number(text,uuid);
DROP FUNCTION public.get_user_calling_rates(uuid);
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
SET search_path TO 'public'
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

REVOKE ALL ON FUNCTION public.get_return_trip_packages_for_line(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.get_return_trip_packages_for_line(uuid,uuid) TO authenticated,service_role;
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
SET search_path TO 'public'
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
    CASE WHEN t.status='planning' THEN public.return_trip_retail_price(t.chosen_package_id,t.user_id) ELSE t.accepted_price_usd END AS effective_price_usd,
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

REVOKE ALL ON FUNCTION public.get_active_return_trip_for_line(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.get_active_return_trip_for_line(uuid,uuid) TO authenticated,service_role;
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
SET search_path TO 'public'
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

REVOKE ALL ON FUNCTION public.get_return_trip_history_for_line(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.get_return_trip_history_for_line(uuid,uuid) TO authenticated,service_role;
CREATE OR REPLACE FUNCTION public.get_user_calling_rates(p_user_id uuid DEFAULT auth.uid())
 RETURNS TABLE(id uuid, country_code text, country_name text, phone_prefix text, destination_type text, base_rate_per_minute_usd numeric, effective_rate_per_minute_usd numeric, connection_fee_usd numeric, billing_increment_seconds integer, account_tier text, is_active boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
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

REVOKE ALL ON FUNCTION public.get_user_calling_rates(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.get_user_calling_rates(uuid) TO authenticated,service_role;
CREATE OR REPLACE FUNCTION public.get_call_rate_for_number(p_phone_number text, p_user_id uuid DEFAULT auth.uid())
 RETURNS TABLE(id uuid, country_code text, country_name text, phone_prefix text, rate_per_minute_usd numeric, connection_fee_usd numeric, billing_increment_seconds integer, account_tier text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
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

REVOKE ALL ON FUNCTION public.get_call_rate_for_number(text,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.get_call_rate_for_number(text,uuid) TO authenticated,service_role;

NOTIFY pgrst, 'reload schema';
COMMIT;
