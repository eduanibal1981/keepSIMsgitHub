-- The older process_due_notifications integration suppresses errors from its
-- best-effort Alert Clock call. A dedicated run makes failures visible in
-- pg_cron while the unique event key keeps the two hourly paths idempotent.
SELECT cron.schedule(
  'emit-urgent-deactivation-alerts',
  '5 * * * *',
  $$SELECT public.emit_urgent_deactivation_alerts(false);$$
);
