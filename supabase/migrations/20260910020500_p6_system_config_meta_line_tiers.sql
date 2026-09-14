-- =============================================================================
-- Migration: 20260910020500_p6_system_config_meta_line_tiers.sql
-- Description:
--   Registers metadata for Standard/Premium membership fees and alert allowance pools
--   so they appear grouped and editable in keep_sims_admin Settings.
-- =============================================================================

INSERT INTO public.system_config_meta (
  config_key, label, group_name, value_type, min_value, max_value, unit, description, is_sensitive, is_readonly, sort_order
) VALUES 
  ('MEMBERSHIP_FEE_STANDARD_USD', 'Standard annual membership', 'Fees & pricing', 'decimal', 0, 100, 'USD', 'Annual line membership fee for Standard plan ($2.50).', false, false, 22),
  ('MEMBERSHIP_FEE_PREMIUM_USD', 'Premium annual membership', 'Fees & pricing', 'decimal', 0, 100, 'USD', 'Annual line membership fee for Premium plan ($5.00).', false, false, 24),
  ('NOTIFICATION_ALLOWANCE_POOL_STANDARD_USD', 'Standard alert allowance pool', 'Notifications', 'decimal', 0, 50, 'USD', 'Annual USD allowance pool for SMS/WhatsApp offline alerts on Standard lines ($0.50).', false, false, 26),
  ('NOTIFICATION_ALLOWANCE_POOL_PREMIUM_USD', 'Premium alert allowance pool', 'Notifications', 'decimal', 0, 50, 'USD', 'Annual USD allowance pool for SMS/WhatsApp offline alerts on Premium lines ($1.00).', false, false, 28)
ON CONFLICT (config_key) DO UPDATE SET
  label = EXCLUDED.label,
  group_name = EXCLUDED.group_name,
  value_type = EXCLUDED.value_type,
  min_value = EXCLUDED.min_value,
  max_value = EXCLUDED.max_value,
  unit = EXCLUDED.unit,
  description = EXCLUDED.description,
  sort_order = EXCLUDED.sort_order;
