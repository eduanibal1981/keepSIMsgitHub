-- =============================================================================
-- Migration: 20260911040000_firsty_recovery_schema.sql
-- Description: Schema and policies for Firsty Emergency Recovery Sandbox
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.recovery_esim_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    provider TEXT NOT NULL DEFAULT 'firsty_sandbox',
    environment TEXT NOT NULL DEFAULT 'sandbox',
    profile_reference TEXT,
    esim_reference TEXT,
    iccid TEXT,
    activation_code TEXT,
    smdp_address TEXT,
    matching_id TEXT,
    status TEXT NOT NULL DEFAULT 'prepared' CHECK (status IN ('prepared', 'installed_reported', 'verified', 'failed')),
    lifecycle_status TEXT NOT NULL DEFAULT 'active' CHECK (lifecycle_status IN ('active', 'suspended', 'terminated')),
    is_mock BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_user_recovery_profile UNIQUE (user_id, provider, environment)
);

CREATE TABLE IF NOT EXISTS public.recovery_allowance_grants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    profile_id UUID NOT NULL REFERENCES public.recovery_esim_profiles(id) ON DELETE CASCADE,
    package_reference TEXT,
    plan_reference TEXT NOT NULL DEFAULT 'CL1DBCXC5VDGLN',
    capacity_mb INTEGER NOT NULL DEFAULT 1024,
    remaining_mb INTEGER NOT NULL DEFAULT 1024,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'exhausted', 'expired', 'revoked')),
    idempotency_key TEXT UNIQUE,
    granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '30 days'),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indices for performance and foreign key lookups
CREATE INDEX IF NOT EXISTS idx_recovery_profiles_user_id ON public.recovery_esim_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_recovery_grants_user_id ON public.recovery_allowance_grants(user_id);
CREATE INDEX IF NOT EXISTS idx_recovery_grants_profile_id ON public.recovery_allowance_grants(profile_id);
CREATE INDEX IF NOT EXISTS idx_recovery_grants_idempotency ON public.recovery_allowance_grants(idempotency_key);

-- Enable RLS
ALTER TABLE public.recovery_esim_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recovery_allowance_grants ENABLE ROW LEVEL SECURITY;

-- Select policies: Users can only read their own recovery records
DROP POLICY IF EXISTS "Users can read own recovery profiles" ON public.recovery_esim_profiles;
CREATE POLICY "Users can read own recovery profiles"
    ON public.recovery_esim_profiles
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can read own recovery grants" ON public.recovery_allowance_grants;
CREATE POLICY "Users can read own recovery grants"
    ON public.recovery_allowance_grants
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- Revoke direct client write access (Only service_role / Edge Functions can insert/update/delete)
REVOKE INSERT, UPDATE, DELETE ON public.recovery_esim_profiles FROM authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON public.recovery_allowance_grants FROM authenticated, anon;

-- System configurations for emergency recovery controls
INSERT INTO public.system_configs (config_key, config_value, description)
VALUES 
    ('FIRSTY_EMERGENCY_KILL_SWITCH', 'false', 'Emergency kill switch for partner-sponsored Firsty recovery grants'),
    ('FIRSTY_EMERGENCY_MONTHLY_LIMIT_USD', '100.00', 'Maximum monthly spend budget for Firsty emergency grants in USD'),
    ('FIRSTY_ALLOWANCE_MAX_MB_PER_USER', '1024', 'Maximum emergency recovery data MB granted per user per 30-day window'),
    ('FIRSTY_SANDBOX_MODE', 'true', 'Restricts Firsty connectivity provider to staging/sandbox mode')
ON CONFLICT (config_key) DO UPDATE
SET config_value = EXCLUDED.config_value,
    description = EXCLUDED.description;
