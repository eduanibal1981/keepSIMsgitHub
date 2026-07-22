-- ============================================================================
-- SIM Shield — Phase C9a: eSIM Catalog Cache, Retail Markup & Canon Extension
-- ============================================================================

-- 1. Create esim_offers_cache table (wholesale stored, private from clients)
CREATE TABLE IF NOT EXISTS public.esim_offers_cache (
  provider TEXT NOT NULL DEFAULT 'esim_go',
  bundle_name TEXT NOT NULL,
  description TEXT,
  countries TEXT[] NOT NULL DEFAULT '{}',
  roaming_enabled TEXT[] NOT NULL DEFAULT '{}',
  data_amount_mb BIGINT NOT NULL DEFAULT 0,
  duration_days INT NOT NULL DEFAULT 0,
  wholesale_price_usd NUMERIC(10, 4) NOT NULL DEFAULT 0.0000,
  image_url TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (provider, bundle_name)
);

CREATE INDEX IF NOT EXISTS idx_esim_offers_cache_provider ON public.esim_offers_cache(provider);
CREATE INDEX IF NOT EXISTS idx_esim_offers_cache_active ON public.esim_offers_cache(is_active);

-- Enable RLS on esim_offers_cache
ALTER TABLE public.esim_offers_cache ENABLE ROW LEVEL SECURITY;

-- Note: No SELECT or write policy for authenticated or anon roles.
-- Wholesale costs remain private to service_role.

-- 2. Ensure system_configs.ESIM_MARKUP_PERCENT is seeded (default 30%)
INSERT INTO public.system_configs (config_key, config_value)
VALUES ('ESIM_MARKUP_PERCENT', '30')
ON CONFLICT (config_key) DO NOTHING;

-- 3. Create view esim_offers exposing calculated retail_price_usd
CREATE OR REPLACE VIEW public.esim_offers WITH (security_invoker = false) AS
SELECT
  c.provider || '_' || c.bundle_name AS id,
  c.provider,
  c.bundle_name,
  c.description,
  c.countries,
  c.roaming_enabled,
  c.data_amount_mb,
  c.duration_days,
  ROUND(
    c.wholesale_price_usd * (1.0 + (
      COALESCE(
        (SELECT NULLIF(config_value, '')::numeric FROM public.system_configs WHERE config_key = 'ESIM_MARKUP_PERCENT'),
        30.0
      ) / 100.0
    )),
    2
  )::NUMERIC(10, 2) AS retail_price_usd,
  c.image_url,
  c.is_active,
  c.updated_at
FROM public.esim_offers_cache c
WHERE c.is_active = true;

GRANT SELECT ON public.esim_offers TO authenticated, anon;

-- 4. Extend Notification Categories Canon to include 'esim_low_data'
ALTER TABLE public.alert_settings DROP CONSTRAINT IF EXISTS alert_settings_category_check;
ALTER TABLE public.alert_settings ADD CONSTRAINT alert_settings_category_check
  CHECK (category = ANY (ARRAY[
    'top_up_success','top_up_failed','wallet_low','wallet_depleted','line_critical',
    'line_entering_grace','geo_fence_triggered','welcome_home_ready','referral_reward',
    'system','wallet_credit','promo','support','esim_low_data'
  ]));

ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_category_check;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_category_check
  CHECK (category = ANY (ARRAY[
    'top_up_success','top_up_failed','wallet_low','wallet_depleted','line_critical',
    'line_entering_grace','geo_fence_triggered','welcome_home_ready','referral_reward',
    'system','wallet_credit','promo','support','esim_low_data'
  ]));

-- Update seed_default_alert_settings trigger function
CREATE OR REPLACE FUNCTION public.seed_default_alert_settings()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  INSERT INTO public.alert_settings (user_id, category, is_enabled, channels)
  SELECT NEW.id,
         c.category,
         c.category <> 'promo',
         ARRAY['push','email','telegram','whatsapp']::text[]
  FROM unnest(ARRAY[
    'top_up_success','top_up_failed','wallet_low','wallet_depleted','line_critical',
    'line_entering_grace','geo_fence_triggered','welcome_home_ready','referral_reward',
    'system','wallet_credit','promo','support','esim_low_data'
  ]) AS c(category)
  ON CONFLICT (user_id, category) DO NOTHING;
  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.seed_default_alert_settings() FROM public, anon, authenticated;

-- Backfill esim_low_data for existing profiles
INSERT INTO public.alert_settings (user_id, category, is_enabled, channels)
SELECT p.id,
       'esim_low_data',
       true,
       ARRAY['push','email','telegram','whatsapp']::text[]
FROM public.profiles p
ON CONFLICT (user_id, category) DO NOTHING;
