-- Migration: 20260713000000_merge_telecom_routes_into_carriers.sql

-- 1. Add columns to carriers
ALTER TABLE public.carriers
ADD COLUMN fulfillment_gateway VARCHAR NOT NULL DEFAULT 'API' CHECK (fulfillment_gateway IN ('API', 'MANUAL', 'TASKER_SCRIPT')),
ADD COLUMN api_provider VARCHAR DEFAULT 'zendit';

-- 2. Migrate existing data (if any exists)
-- Since telecom_fulfillment_routes uses country_id and carrier_id, we can map it
UPDATE public.carriers c
SET 
  fulfillment_gateway = r.gateway,
  api_provider = r.api_provider
FROM public.telecom_fulfillment_routes r
WHERE c.country_id = r.country_id AND c.id = r.carrier_id;

-- 3. Drop the now-redundant table
DROP TABLE IF EXISTS public.telecom_fulfillment_routes;
