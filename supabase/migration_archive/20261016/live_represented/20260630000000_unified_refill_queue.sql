-- Migration: 20260630000000_unified_refill_queue.sql

-- 1. Helper function to check if a user is a power user
CREATE OR REPLACE FUNCTION public.is_power_user(user_id uuid)
RETURNS boolean AS $$
DECLARE
  is_power boolean;
BEGIN
  SELECT COALESCE(profiles.is_power_user, false) INTO is_power 
  FROM public.profiles 
  WHERE profiles.id = user_id;
  
  RETURN is_power;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Create system_configs table
CREATE TABLE IF NOT EXISTS public.system_configs (
    config_key VARCHAR PRIMARY KEY,
    config_value VARCHAR NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert the default configuration for fulfillment
INSERT INTO public.system_configs (config_key, config_value) 
VALUES ('ACTIVE_FULFILLMENT_METHOD', 'MANUAL')
ON CONFLICT (config_key) DO NOTHING;

-- Enable RLS on system_configs
ALTER TABLE public.system_configs ENABLE ROW LEVEL SECURITY;

-- Global config reading is open to authenticated users (so the dashboard can read it)
CREATE POLICY "Allow authenticated users to read config" 
ON public.system_configs 
FOR SELECT 
TO authenticated 
USING (true);

-- Updating is restricted to power users
CREATE POLICY "Allow power users to update config" 
ON public.system_configs 
FOR UPDATE 
TO authenticated 
USING (public.is_power_user(auth.uid())) 
WITH CHECK (public.is_power_user(auth.uid()));

-- Insert is restricted to power users
CREATE POLICY "Allow power users to insert config" 
ON public.system_configs 
FOR INSERT 
TO authenticated 
WITH CHECK (public.is_power_user(auth.uid()));

-- 3. Create refill_requests table
CREATE TABLE IF NOT EXISTS public.refill_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    corporate_line_id UUID NOT NULL REFERENCES public.sim_lines(id) ON DELETE CASCADE,
    source VARCHAR NOT NULL CHECK (source IN ('whatsapp_offline', 'app_auto', 'app_manual')),
    amount NUMERIC NOT NULL CHECK (amount > 0),
    status VARCHAR NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'routing', 'processing', 'completed', 'failed', 'pending_manual_action')),
    fulfillment_method_used VARCHAR,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on refill_requests
ALTER TABLE public.refill_requests ENABLE ROW LEVEL SECURITY;

-- Allow power users to read all refill requests
CREATE POLICY "Allow power users to select refill_requests" 
ON public.refill_requests 
FOR SELECT 
TO authenticated 
USING (public.is_power_user(auth.uid()));

-- Allow regular users to read their own requests
CREATE POLICY "Allow users to read their own refill_requests" 
ON public.refill_requests 
FOR SELECT 
TO authenticated 
USING (EXISTS (
    SELECT 1 FROM public.sim_lines 
    WHERE public.sim_lines.id = refill_requests.corporate_line_id 
    AND public.sim_lines.user_id = auth.uid()
));

-- Allow users to insert requests for their own SIM lines, or power users
CREATE POLICY "Allow users to insert their own refill requests or power users"
ON public.refill_requests
FOR INSERT
TO authenticated
WITH CHECK (
  public.is_power_user(auth.uid()) OR 
  EXISTS (
    SELECT 1 FROM public.sim_lines 
    WHERE public.sim_lines.id = corporate_line_id 
    AND public.sim_lines.user_id = auth.uid()
  )
);

-- Allow power users to update refill requests
CREATE POLICY "Allow power users to update refill_requests" 
ON public.refill_requests 
FOR UPDATE 
TO authenticated 
USING (public.is_power_user(auth.uid())) 
WITH CHECK (public.is_power_user(auth.uid()));

-- 4. Enable Supabase Realtime replication on both tables
BEGIN;
  -- Remove tables from publication if they exist to avoid errors
  ALTER PUBLICATION supabase_realtime DROP TABLE IF EXISTS public.system_configs;
  ALTER PUBLICATION supabase_realtime DROP TABLE IF EXISTS public.refill_requests;
  
  -- Add them back
  ALTER PUBLICATION supabase_realtime ADD TABLE public.system_configs;
  ALTER PUBLICATION supabase_realtime ADD TABLE public.refill_requests;
COMMIT;
