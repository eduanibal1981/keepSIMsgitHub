-- Release the 48-hour crossing scheduler after source checks, outbox delivery,
-- and a dry run with zero current candidates. The hourly notification cron
-- already calls emit_urgent_deactivation_alerts(false).
UPDATE public.system_configs
SET config_value = 'true'
WHERE config_key = 'ALERT_CLOCK_SCHEDULER_ENABLED';
