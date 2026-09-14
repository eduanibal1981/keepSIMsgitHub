-- =============================================================================
-- Test: firsty_recovery_schema_tests.sql
-- Purpose: Verify recovery_esim_profiles, recovery_allowance_grants, RLS, and constraints
-- =============================================================================

BEGIN;

-- Test 1: Verify tables exist
DO $$
BEGIN
    ASSERT (SELECT to_regclass('public.recovery_esim_profiles') IS NOT NULL),
        'Table public.recovery_esim_profiles does not exist';
    ASSERT (SELECT to_regclass('public.recovery_allowance_grants') IS NOT NULL),
        'Table public.recovery_allowance_grants does not exist';
END $$;

-- Test 2: Verify system configurations are seeded
DO $$
DECLARE
    v_kill_switch TEXT;
    v_monthly_limit TEXT;
    v_max_mb TEXT;
BEGIN
    SELECT config_value INTO v_kill_switch FROM public.system_configs WHERE config_key = 'FIRSTY_EMERGENCY_KILL_SWITCH';
    SELECT config_value INTO v_monthly_limit FROM public.system_configs WHERE config_key = 'FIRSTY_EMERGENCY_MONTHLY_LIMIT_USD';
    SELECT config_value INTO v_max_mb FROM public.system_configs WHERE config_key = 'FIRSTY_ALLOWANCE_MAX_MB_PER_USER';

    ASSERT v_kill_switch = 'false', 'FIRSTY_EMERGENCY_KILL_SWITCH must be false';
    ASSERT v_monthly_limit = '100.00', 'FIRSTY_EMERGENCY_MONTHLY_LIMIT_USD must be 100.00';
    ASSERT v_max_mb = '1024', 'FIRSTY_ALLOWANCE_MAX_MB_PER_USER must be 1024';
END $$;

-- Test 3: Verify RLS is enabled on both tables
DO $$
DECLARE
    v_rls_profiles BOOLEAN;
    v_rls_grants BOOLEAN;
BEGIN
    SELECT relrowsecurity INTO v_rls_profiles FROM pg_class WHERE oid = 'public.recovery_esim_profiles'::regclass;
    SELECT relrowsecurity INTO v_rls_grants FROM pg_class WHERE oid = 'public.recovery_allowance_grants'::regclass;

    ASSERT v_rls_profiles = TRUE, 'RLS must be enabled on recovery_esim_profiles';
    ASSERT v_rls_grants = TRUE, 'RLS must be enabled on recovery_allowance_grants';
END $$;

-- Test 4: Verify unique constraint on user_id, provider, environment
DO $$
DECLARE
    v_constraint_count INTEGER;
BEGIN
    SELECT count(*) INTO v_constraint_count
    FROM pg_constraint
    WHERE conrelid = 'public.recovery_esim_profiles'::regclass
      AND conname = 'uq_user_recovery_profile';

    ASSERT v_constraint_count = 1, 'Unique constraint uq_user_recovery_profile must exist';
END $$;

ROLLBACK;
