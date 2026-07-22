-- C8 Travel & Geolocation Migration
-- 1. Add last_country column to profiles
-- 2. Add system_configs entry for GEO_FLAP_GUARD_HOURS

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS last_country text NULL;

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_last_country_check;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_last_country_check
  CHECK (last_country IS NULL OR char_length(last_country) = 2);

-- Seed flap-guard key in system_configs (default 1 hour)
INSERT INTO public.system_configs (config_key, config_value)
VALUES ('GEO_FLAP_GUARD_HOURS', '1')
ON CONFLICT (config_key) DO UPDATE SET config_value = EXCLUDED.config_value;
