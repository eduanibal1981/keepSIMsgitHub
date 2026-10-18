-- =============================================================================
-- Migration: 20260914000000_return_trips_and_packages.sql
-- Description:
--   Supports "Back to {Country} Wizard" for returning travellers:
--   1. public.return_trip_packages: Curated eSIM and Physical SIM data packages
--   2. public.return_trips: User trips tracking arrival date, status, and chosen package
--   3. RPC get_return_trip_packages_for_line: Resolves tier pricing & app fee discount
--   4. Seeds initial packages for Egypt and popular destinations
-- =============================================================================

-- 1. RETURN TRIP PACKAGES TABLE
CREATE TABLE IF NOT EXISTS public.return_trip_packages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  country_id UUID NOT NULL REFERENCES public.countries(id) ON DELETE CASCADE,
  carrier_id UUID REFERENCES public.carriers(id) ON DELETE SET NULL,
  package_type TEXT NOT NULL CHECK (package_type IN ('esim', 'carrier_ussd', 'physical_voucher')),
  title TEXT NOT NULL,
  description TEXT,
  data_allowance_mb INT NOT NULL, -- e.g. 1024, 5120, -1 for unlimited
  duration_days INT NOT NULL,
  is_unlimited BOOLEAN NOT NULL DEFAULT false,
  supplier_cost_usd NUMERIC(10,2) NOT NULL DEFAULT 0.00,
  retail_price_usd NUMERIC(10,2) NOT NULL DEFAULT 0.00,
  ussd_recharge_code TEXT,
  activation_instructions TEXT,
  badge_label TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. RETURN TRIPS TABLE
CREATE TABLE IF NOT EXISTS public.return_trips (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  sim_line_id UUID NOT NULL REFERENCES public.sim_lines(id) ON DELETE CASCADE,
  destination_country_id UUID NOT NULL REFERENCES public.countries(id) ON DELETE RESTRICT,
  arrival_date DATE NOT NULL,
  status TEXT NOT NULL DEFAULT 'planning' CHECK (status IN ('planning', 'data_ready', 'arrived', 'completed', 'cancelled')),
  chosen_package_type TEXT CHECK (chosen_package_type IN ('esim', 'carrier_ussd', 'physical_voucher')),
  chosen_package_id UUID REFERENCES public.return_trip_packages(id) ON DELETE SET NULL,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_return_trip_packages_country_active 
  ON public.return_trip_packages(country_id, is_active);

CREATE INDEX IF NOT EXISTS idx_return_trips_user_sim 
  ON public.return_trips(user_id, sim_line_id);

CREATE INDEX IF NOT EXISTS idx_return_trips_status 
  ON public.return_trips(status);

-- Enable RLS
ALTER TABLE public.return_trip_packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.return_trips ENABLE ROW LEVEL SECURITY;

-- Policies: return_trip_packages (readable by all, manageable by service role)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Anyone can view active return trip packages') THEN
    CREATE POLICY "Anyone can view active return trip packages"
      ON public.return_trip_packages
      FOR SELECT
      USING (is_active = true);
  END IF;
END $$;

-- Policies: return_trips (user owns their trips)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can view their own return trips') THEN
    CREATE POLICY "Users can view their own return trips"
      ON public.return_trips
      FOR SELECT
      TO authenticated
      USING (user_id = auth.uid());
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can insert their own return trips') THEN
    CREATE POLICY "Users can insert their own return trips"
      ON public.return_trips
      FOR INSERT
      TO authenticated
      WITH CHECK (user_id = auth.uid());
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can update their own return trips') THEN
    CREATE POLICY "Users can update their own return trips"
      ON public.return_trips
      FOR UPDATE
      TO authenticated
      USING (user_id = auth.uid())
      WITH CHECK (user_id = auth.uid());
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can delete their own return trips') THEN
    CREATE POLICY "Users can delete their own return trips"
      ON public.return_trips
      FOR DELETE
      TO authenticated
      USING (user_id = auth.uid());
  END IF;
END $$;

-- Grants
GRANT SELECT ON public.return_trip_packages TO authenticated, anon;
GRANT ALL ON public.return_trip_packages TO service_role;

GRANT ALL ON public.return_trips TO authenticated;
GRANT ALL ON public.return_trips TO service_role;

-- 3. RPC: get_return_trip_packages_for_line
-- Calculates tier-aware discounts on the app fee (Premium 100%, Standard 50%, Free 0%)
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
  supplier_cost_usd NUMERIC,
  retail_price_usd NUMERIC,
  effective_price_usd NUMERIC,
  app_fee_usd NUMERIC,
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
    pkg.supplier_cost_usd,
    pkg.retail_price_usd,
    round(
      pkg.supplier_cost_usd + ((pkg.retail_price_usd - pkg.supplier_cost_usd) * (1.00 - v_discount_rate)),
      2
    ) AS effective_price_usd,
    round((pkg.retail_price_usd - pkg.supplier_cost_usd) * (1.00 - v_discount_rate), 2) AS app_fee_usd,
    round((pkg.retail_price_usd - pkg.supplier_cost_usd) * v_discount_rate, 2) AS discount_usd,
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

GRANT EXECUTE ON FUNCTION public.get_return_trip_packages_for_line(UUID, UUID) TO authenticated, anon, service_role;

-- 4. SEED INITIAL PACKAGES FOR EGYPT
DO $$
DECLARE
  v_egypt_id UUID;
  v_vodafone_id UUID;
  v_orange_id UUID;
  v_etisalat_id UUID;
  v_we_id UUID;
BEGIN
  SELECT id INTO v_egypt_id FROM public.countries WHERE iso_code = 'EG' LIMIT 1;
  IF v_egypt_id IS NOT NULL THEN
    SELECT id INTO v_vodafone_id FROM public.carriers WHERE country_id = v_egypt_id AND name ILIKE '%Vodafone%' LIMIT 1;
    SELECT id INTO v_orange_id FROM public.carriers WHERE country_id = v_egypt_id AND name ILIKE '%Orange%' LIMIT 1;
    SELECT id INTO v_etisalat_id FROM public.carriers WHERE country_id = v_egypt_id AND name ILIKE '%Etisalat%' LIMIT 1;
    SELECT id INTO v_we_id FROM public.carriers WHERE country_id = v_egypt_id AND name ILIKE '%WE%' LIMIT 1;

    -- 1. eSIM: 1-Day Unlimited Travel eSIM
    INSERT INTO public.return_trip_packages (
      country_id, carrier_id, package_type, title, description,
      data_allowance_mb, duration_days, is_unlimited,
      supplier_cost_usd, retail_price_usd,
      activation_instructions, badge_label, is_active
    ) VALUES (
      v_egypt_id, NULL, 'esim', '1-Day Unlimited Travel eSIM', 'Unlimited high-speed data for 24 hours upon landing in Egypt.',
      -1, 1, true,
      2.50, 3.50,
      'Scan QR code upon landing at Cairo/Hurghada or install before boarding.', 'Cheapest 1-Day Unlimited', true
    ) ON CONFLICT DO NOTHING;

    -- 2. Vodafone Egypt: 5GB Super Pass (USSD Recharge)
    INSERT INTO public.return_trip_packages (
      country_id, carrier_id, package_type, title, description,
      data_allowance_mb, duration_days, is_unlimited,
      supplier_cost_usd, retail_price_usd,
      ussd_recharge_code, activation_instructions, badge_label, is_active
    ) VALUES (
      v_egypt_id, v_vodafone_id, 'carrier_ussd', 'Vodafone 5GB Super Pass', '5GB high-speed local data valid for 7 days.',
      5120, 7, false,
      3.00, 4.50,
      '*858*PIN#', 'Dial *858*PIN# from your Egyptian Vodafone SIM to activate instantly.', 'Popular Local Data', true
    ) ON CONFLICT DO NOTHING;

    -- 3. Orange Egypt: Orange GO 4GB (USSD Recharge)
    INSERT INTO public.return_trip_packages (
      country_id, carrier_id, package_type, title, description,
      data_allowance_mb, duration_days, is_unlimited,
      supplier_cost_usd, retail_price_usd,
      ussd_recharge_code, activation_instructions, badge_label, is_active
    ) VALUES (
      v_egypt_id, v_orange_id, 'carrier_ussd', 'Orange GO 4GB', '4GB high-speed local data valid for 7 days.',
      4096, 7, false,
      2.80, 4.00,
      '*100*1*4*PIN#', 'Dial *100*1*4*PIN# to activate 4GB on your Orange SIM.', 'Fast 4G Internet', true
    ) ON CONFLICT DO NOTHING;

    -- 4. WE Egypt: WE Nitro 10GB
    INSERT INTO public.return_trip_packages (
      country_id, carrier_id, package_type, title, description,
      data_allowance_mb, duration_days, is_unlimited,
      supplier_cost_usd, retail_price_usd,
      ussd_recharge_code, activation_instructions, badge_label, is_active
    ) VALUES (
      v_egypt_id, v_we_id, 'carrier_ussd', 'WE Nitro 10GB', '10GB large package valid for 30 days.',
      10240, 30, false,
      5.00, 7.00,
      '*555*PIN#', 'Dial *555*PIN# on WE network to recharge.', 'Best 30-Day Value', true
    ) ON CONFLICT DO NOTHING;
  END IF;
END $$;

-- 5. RPC: get_active_return_trip_for_line
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
    coalesce(p.retail_price_usd, 0.00) AS effective_price_usd,
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

GRANT EXECUTE ON FUNCTION public.get_active_return_trip_for_line(UUID, UUID) TO authenticated, anon, service_role;
