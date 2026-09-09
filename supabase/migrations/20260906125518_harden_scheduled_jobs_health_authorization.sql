-- P0 issue 3: check_scheduled_jobs_health() is invoked by pg_cron as postgres.
-- Keep the live function body, owner, SECURITY DEFINER mode, and hardened empty
-- search_path intact; local and live bodies currently differ, so replacing the
-- function here would risk reverting deployed health/alert behavior.

REVOKE EXECUTE ON FUNCTION public.check_scheduled_jobs_health() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.check_scheduled_jobs_health() FROM anon;
REVOKE EXECUTE ON FUNCTION public.check_scheduled_jobs_health() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.check_scheduled_jobs_health() FROM service_role;

-- The active pg_cron entry executes SELECT public.check_scheduled_jobs_health()
-- with username=postgres. No client or service-role caller is required.
GRANT EXECUTE ON FUNCTION public.check_scheduled_jobs_health() TO postgres;
