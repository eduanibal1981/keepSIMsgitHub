-- Migration: 20260914020000_return_trip_history.sql
-- Description: RPC to retrieve return trip preparation history for a SIM line

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
  ORDER BY t.arrival_date DESC, t.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_return_trip_history_for_line(UUID, UUID) TO authenticated, anon, service_role;
