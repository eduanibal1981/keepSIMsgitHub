-- ============================================================================
-- Operationalize Scheduled Jobs
-- Creates registry, ownership, freshness thresholds, and automated health checks
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.scheduled_job_registry (
  job_name                    text PRIMARY KEY,
  job_id                      integer,
  owner                       text NOT NULL,
  category                    text NOT NULL,
  expected_schedule           text NOT NULL,
  freshness_threshold_minutes integer NOT NULL,
  max_consecutive_failures    integer NOT NULL DEFAULT 3,
  is_critical                 boolean NOT NULL DEFAULT false,
  description                 text NOT NULL,
  created_at                  timestamptz DEFAULT now(),
  updated_at                  timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.scheduled_job_registry ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow read scheduled_job_registry to authenticated and service_role"
  ON public.scheduled_job_registry
  FOR SELECT
  TO authenticated, service_role
  USING (true);

-- Seed metadata for all 17 scheduled pg_cron jobs
INSERT INTO public.scheduled_job_registry 
  (job_name, job_id, owner, category, expected_schedule, freshness_threshold_minutes, is_critical, description)
VALUES
  ('reap-stuck-executions', 8, 'billing_ops', 'refill_pipeline', '*/5 * * * *', 15, true, 'Recovers stuck in-flight topup executions back to pending or marks timeout.'),
  ('check-worker-heartbeat', 19, 'core_infra', 'core_infra', '*/10 * * * *', 25, true, 'Checks background daemon processes are checking in with active heartbeats.'),
  ('refill-pipeline-health', 9, 'billing_ops', 'refill_pipeline', '30 * * * *', 90, true, 'Verifies queue throughput and flags stuck execution backlogs.'),
  ('process-hourly-notifications', 7, 'customer_care', 'notifications', '0 * * * *', 90, true, 'Processes due and delayed user push, WhatsApp, and email alerts.'),
  ('run-auto-rescue', 22, 'billing_ops', 'refill_pipeline', '50 * * * *', 90, true, 'Executes automated rescue topups for SIM lines in critical grace windows.'),
  ('purge-deleted-accounts-hourly', 10, 'core_infra', 'account_lifecycle', '0 * * * *', 90, false, 'Processes expired account deletion requests and invokes purge-accounts.'),
  ('reap-stale-esim-orders-hourly', 13, 'catalog_sync', 'refill_pipeline', '0 * * * *', 90, true, 'Cleans up abandoned or unfulfilled eSIM purchase sessions.'),
  ('check-rate-limit-health', 11, 'core_infra', 'rate_limiting', '30 * * * *', 90, false, 'Monitors rate limit bucket capacities and detects anomalous spikes.'),
  ('prune-rate-limit-data', 12, 'core_infra', 'rate_limiting', '0 3 * * *', 1500, false, 'Nightly cleanup of expired client rate limit counters.'),
  ('refresh-usage-forecasts', 20, 'billing_ops', 'refill_pipeline', '20 2 * * *', 1500, false, 'Recomputes projected balance depletion curves for active SIM lines.'),
  ('refresh-offer-price-watch', 21, 'catalog_sync', 'pricing_catalog', '40 2 * * *', 1500, false, 'Detects carrier package price changes and prunes history older than 90 days.'),
  ('refresh-fx-rates', 23, 'pricing_catalog', 'pricing_catalog', '10 3 * * *', 1500, true, 'Fetches latest global currency exchange rates and updates local FX multipliers.'),
  ('emit-carrier-self-service-advice', 24, 'customer_care', 'notifications', '55 2 * * *', 1500, false, 'Dispatches USSD and portal self-service instructions for managed carriers.'),
  ('sync-esim-catalogue', 25, 'catalog_sync', 'pricing_catalog', '40 3 * * *', 1500, false, 'Nightly synchronization of eSIM Go and Zendit bundle catalogues.'),
  ('sync-affiliate-network', 26, 'growth_marketing', 'pricing_catalog', '10 4 * * *', 1500, false, 'Pulls affiliate conversion records from external marketing networks.'),
  ('refresh-provider-offers', 27, 'catalog_sync', 'pricing_catalog', '30 4 * * *', 1500, true, 'Materializes latest supplier cache bundles into active provider_offers catalogue.'),
  ('sweep-offline-vouchers', 28, 'billing_ops', 'refill_pipeline', '20 3 * * *', 1500, false, 'Sweeps expired or pending manual offline voucher requests.')
ON CONFLICT (job_name) DO UPDATE SET
  job_id = EXCLUDED.job_id,
  owner = EXCLUDED.owner,
  category = EXCLUDED.category,
  expected_schedule = EXCLUDED.expected_schedule,
  freshness_threshold_minutes = EXCLUDED.freshness_threshold_minutes,
  is_critical = EXCLUDED.is_critical,
  description = EXCLUDED.description,
  updated_at = now();

-- Health and Freshness Checker Function
CREATE OR REPLACE FUNCTION public.check_scheduled_jobs_health()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  r RECORD;
  v_last_run RECORD;
  v_stale_count integer := 0;
  v_failing_count integer := 0;
  v_healthy_count integer := 0;
  v_minutes_since_run integer;
  v_recent_failures integer;
  v_status text;
BEGIN
  FOR r IN SELECT * FROM public.scheduled_job_registry ORDER BY is_critical DESC, job_name ASC LOOP
    -- Fetch latest run for this job
    SELECT status, start_time, end_time, return_message
      INTO v_last_run
      FROM cron.job_run_details
     WHERE jobid = r.job_id
     ORDER BY start_time DESC
     LIMIT 1;

    IF v_last_run.start_time IS NULL THEN
      IF r.created_at > pg_catalog.now() - (r.freshness_threshold_minutes || ' minutes')::interval THEN
        v_minutes_since_run := 0;
        v_status := 'pending_first_run';
      ELSE
        v_minutes_since_run := 999999;
        v_status := 'never_run';
      END IF;
    ELSE
      v_minutes_since_run := FLOOR(EXTRACT(EPOCH FROM (pg_catalog.now() - v_last_run.start_time)) / 60)::integer;
      v_status := v_last_run.status;
    END IF;

    -- Count consecutive recent failures
    SELECT count(*)::integer
      INTO v_recent_failures
      FROM (
        SELECT status
          FROM cron.job_run_details
         WHERE jobid = r.job_id
         ORDER BY start_time DESC
         LIMIT r.max_consecutive_failures
      ) sub
     WHERE sub.status != 'succeeded';

    -- Check freshness
    IF v_minutes_since_run > r.freshness_threshold_minutes THEN
      v_stale_count := v_stale_count + 1;

      -- Emit system alert if critical or not previously logged recently
      INSERT INTO public.system_alerts (kind, message, details)
      VALUES (
        'scheduled_job_stale',
        'Scheduled job ' || r.job_name || ' is stale. Last run was ' || v_minutes_since_run || ' minutes ago (threshold: ' || r.freshness_threshold_minutes || 'm).',
        pg_catalog.jsonb_build_object(
          'job_name', r.job_name,
          'job_id', r.job_id,
          'owner', r.owner,
          'minutes_since_run', v_minutes_since_run,
          'threshold_minutes', r.freshness_threshold_minutes,
          'is_critical', r.is_critical
        )
      );
    ELSIF v_recent_failures >= r.max_consecutive_failures THEN
      v_failing_count := v_failing_count + 1;

      INSERT INTO public.system_alerts (kind, message, details)
      VALUES (
        'scheduled_job_failing',
        'Scheduled job ' || r.job_name || ' failed ' || v_recent_failures || ' consecutive times.',
        pg_catalog.jsonb_build_object(
          'job_name', r.job_name,
          'job_id', r.job_id,
          'owner', r.owner,
          'consecutive_failures', v_recent_failures,
          'last_error', v_last_run.return_message,
          'is_critical', r.is_critical
        )
      );
    ELSE
      v_healthy_count := v_healthy_count + 1;
    END IF;
  END LOOP;

  RETURN pg_catalog.jsonb_build_object(
    'healthy', v_healthy_count,
    'stale', v_stale_count,
    'failing', v_failing_count,
    'total_registered', (SELECT count(*) FROM public.scheduled_job_registry),
    'checked_at', pg_catalog.now()
  );
END;
$$;

-- Overview RPC for Admin Portal
CREATE OR REPLACE FUNCTION public.admin_get_scheduled_jobs_overview()
RETURNS TABLE (
  job_name                    text,
  job_id                      integer,
  owner                       text,
  category                    text,
  expected_schedule           text,
  freshness_threshold_minutes integer,
  is_critical                 boolean,
  last_run_at                 timestamptz,
  last_status                 text,
  minutes_since_last_run      integer,
  consecutive_failures        integer,
  health_state                text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  PERFORM public.assert_admin();

  RETURN QUERY
  SELECT 
    reg.job_name,
    reg.job_id,
    reg.owner,
    reg.category,
    reg.expected_schedule,
    reg.freshness_threshold_minutes,
    reg.is_critical,
    latest.start_time AS last_run_at,
    COALESCE(latest.status, 'pending_first_run') AS last_status,
    COALESCE(FLOOR(EXTRACT(EPOCH FROM (pg_catalog.now() - latest.start_time)) / 60)::integer, 0) AS minutes_since_last_run,
    COALESCE(fail_count.failures, 0) AS consecutive_failures,
    CASE 
      WHEN latest.start_time IS NULL THEN
        CASE 
          WHEN reg.created_at > pg_catalog.now() - (reg.freshness_threshold_minutes || ' minutes')::interval THEN 'healthy'
          ELSE 'stale'
        END
      WHEN FLOOR(EXTRACT(EPOCH FROM (pg_catalog.now() - latest.start_time)) / 60)::integer > reg.freshness_threshold_minutes THEN 'stale'
      WHEN COALESCE(fail_count.failures, 0) >= reg.max_consecutive_failures THEN 'failing'
      ELSE 'healthy'
    END AS health_state
  FROM public.scheduled_job_registry reg
  LEFT JOIN LATERAL (
    SELECT status, start_time
      FROM cron.job_run_details d
     WHERE d.jobid = reg.job_id
     ORDER BY d.start_time DESC
     LIMIT 1
  ) latest ON true
  LEFT JOIN LATERAL (
    SELECT count(*)::integer AS failures
      FROM (
        SELECT status
          FROM cron.job_run_details d2
         WHERE d2.jobid = reg.job_id
         ORDER BY d2.start_time DESC
         LIMIT reg.max_consecutive_failures
      ) sub
     WHERE sub.status != 'succeeded'
  ) fail_count ON true
  ORDER BY reg.is_critical DESC, reg.category ASC, reg.job_name ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_get_scheduled_jobs_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_get_scheduled_jobs_overview() TO authenticated, service_role;
