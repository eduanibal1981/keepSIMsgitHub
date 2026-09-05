-- Migration: 20260904060000_automated_log_retention.sql
-- Automated database log retention and maintenance routine.
-- Prunes cron.job_run_details older than 14 days and system_alerts older than 90 days.
-- Scheduled via pg_cron to run daily at 02:30 UTC.

-- 1. Core maintenance routine (SECURITY DEFINER, postgres)
CREATE OR REPLACE FUNCTION public.prune_database_logs(
  p_cron_retention_days integer DEFAULT 14,
  p_alerts_retention_days integer DEFAULT 90
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $func$
DECLARE
  v_cron_deleted integer := 0;
  v_alerts_deleted integer := 0;
  v_cutoff_cron timestamptz;
  v_cutoff_alerts timestamptz;
BEGIN
  -- Validate sane bounds to prevent accidental total wipe
  IF p_cron_retention_days < 3 THEN
    RAISE EXCEPTION 'p_cron_retention_days must be at least 3 days';
  END IF;
  IF p_alerts_retention_days < 7 THEN
    RAISE EXCEPTION 'p_alerts_retention_days must be at least 7 days';
  END IF;

  v_cutoff_cron := pg_catalog.now() - (p_cron_retention_days || ' days')::interval;
  v_cutoff_alerts := pg_catalog.now() - (p_alerts_retention_days || ' days')::interval;

  -- Prune cron.job_run_details
  WITH deleted_cron AS (
    DELETE FROM cron.job_run_details
    WHERE start_time < v_cutoff_cron
    RETURNING 1
  )
  SELECT count(*)::integer INTO v_cron_deleted FROM deleted_cron;

  -- Prune public.system_alerts
  WITH deleted_alerts AS (
    DELETE FROM public.system_alerts
    WHERE created_at < v_cutoff_alerts
    RETURNING 1
  )
  SELECT count(*)::integer INTO v_alerts_deleted FROM deleted_alerts;

  RETURN pg_catalog.jsonb_build_object(
    'status', 'success',
    'cron_runs_pruned', v_cron_deleted,
    'cron_retention_days', p_cron_retention_days,
    'cron_cutoff', v_cutoff_cron,
    'alerts_pruned', v_alerts_deleted,
    'alerts_retention_days', p_alerts_retention_days,
    'alerts_cutoff', v_cutoff_alerts,
    'executed_at', pg_catalog.now()
  );
END;
$func$;

REVOKE ALL ON FUNCTION public.prune_database_logs(integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.prune_database_logs(integer, integer) TO postgres, service_role;

-- 2. Admin endpoint for on-demand manual invocation
CREATE OR REPLACE FUNCTION public.admin_prune_database_logs(
  p_cron_retention_days integer DEFAULT 14,
  p_alerts_retention_days integer DEFAULT 90
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $func$
DECLARE
  v_actor_id uuid;
  v_actor_email text;
  v_result jsonb;
BEGIN
  PERFORM public.assert_admin();

  v_actor_id := auth.uid();
  v_actor_email := public.current_user_email();

  v_result := public.prune_database_logs(p_cron_retention_days, p_alerts_retention_days);

  INSERT INTO public.admin_audit_log (
    actor_id,
    actor_email,
    action,
    target_type,
    target_id,
    details
  ) VALUES (
    v_actor_id,
    v_actor_email,
    'prune_database_logs',
    'maintenance',
    'database_logs',
    v_result
  );

  RETURN v_result;
END;
$func$;

REVOKE ALL ON FUNCTION public.admin_prune_database_logs(integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_prune_database_logs(integer, integer) TO authenticated, service_role;

-- 3. Schedule daily pg_cron maintenance job at 02:30 UTC
DO $cron_block$
DECLARE
  v_jobid integer;
BEGIN
  -- Unschedule existing job if already present
  PERFORM cron.unschedule('prune-database-logs-daily')
  WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'prune-database-logs-daily'
  );

  -- Schedule daily job at 02:30 UTC
  v_jobid := cron.schedule(
    'prune-database-logs-daily',
    '30 2 * * *',
    'SELECT public.prune_database_logs(14, 90);'
  );

  -- 4. Register in scheduled_job_registry
  INSERT INTO public.scheduled_job_registry (
    job_name,
    job_id,
    owner,
    category,
    expected_schedule,
    freshness_threshold_minutes,
    max_consecutive_failures,
    is_critical,
    description
  ) VALUES (
    'prune-database-logs-daily',
    v_jobid,
    'core_infra',
    'core_infra',
    '30 2 * * *',
    1500, -- max 25 hours freshness SLA
    2,
    false,
    'Daily maintenance pruning cron.job_run_details older than 14 days and aged system alerts.'
  )
  ON CONFLICT (job_name) DO UPDATE SET
    job_id = EXCLUDED.job_id,
    expected_schedule = EXCLUDED.expected_schedule,
    freshness_threshold_minutes = EXCLUDED.freshness_threshold_minutes,
    updated_at = pg_catalog.now();
END;
$cron_block$;