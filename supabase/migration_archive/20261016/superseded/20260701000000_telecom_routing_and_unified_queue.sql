-- Migration: 20260701000000_telecom_routing_and_unified_queue.sql

-- 1. Create the Telecom Routing Table
CREATE TABLE IF NOT EXISTS public.telecom_fulfillment_routes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    country_id VARCHAR NOT NULL,
    carrier_id VARCHAR NOT NULL,
    gateway VARCHAR NOT NULL CHECK (gateway IN ('API', 'MANUAL', 'TASKER_SCRIPT')),
    api_provider VARCHAR,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(country_id, carrier_id)
);

-- Enable RLS
ALTER TABLE public.telecom_fulfillment_routes ENABLE ROW LEVEL SECURITY;

-- Only Power Users can access and modify routing rules
CREATE POLICY "Allow power users full access to telecom_fulfillment_routes" 
ON public.telecom_fulfillment_routes 
FOR ALL TO authenticated 
USING (public.is_power_user(auth.uid())) 
WITH CHECK (public.is_power_user(auth.uid()));

-- 2. Modify topup_executions to handle fulfillment tracking
ALTER TABLE public.topup_executions
ADD COLUMN IF NOT EXISTS fulfillment_gateway VARCHAR,
ADD COLUMN IF NOT EXISTS api_provider VARCHAR;

-- 3. Add topup_executions to realtime so the Node Daemon can listen to it
BEGIN;
  ALTER PUBLICATION supabase_realtime DROP TABLE IF EXISTS public.topup_executions;
  ALTER PUBLICATION supabase_realtime ADD TABLE public.topup_executions;
COMMIT;
