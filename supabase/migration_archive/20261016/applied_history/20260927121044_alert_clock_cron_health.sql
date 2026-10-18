CREATE OR REPLACE FUNCTION public.admin_alert_clock_scheduler_status()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE v_enabled boolean; v_run record;
BEGIN
  PERFORM public.assert_admin();
  SELECT config_value='true' INTO v_enabled FROM public.system_configs
  WHERE config_key='ALERT_CLOCK_SCHEDULER_ENABLED';
  SELECT d.status, d.start_time, left(coalesce(d.return_message,''),500) AS message
  INTO v_run
  FROM cron.job j
  JOIN cron.job_run_details d ON d.jobid=j.jobid
  WHERE j.jobname='emit-urgent-deactivation-alerts'
  ORDER BY d.start_time DESC LIMIT 1;
  RETURN jsonb_build_object(
    'enabled',coalesce(v_enabled,false),
    'dry_run',public.emit_urgent_deactivation_alerts(true),
    'last_run_status',v_run.status,
    'last_run_at',v_run.start_time,
    'last_run_message',v_run.message
  );
END;
$$;
REVOKE ALL ON FUNCTION public.admin_alert_clock_scheduler_status()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_alert_clock_scheduler_status()
  TO authenticated, service_role;
