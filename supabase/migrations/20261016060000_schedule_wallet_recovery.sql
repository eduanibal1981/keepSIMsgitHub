-- Register recovery where pg_cron is installed. No provider/payout API is
-- invoked: only proven pre-submission terminal holds are released automatically.
BEGIN;
DO $$
DECLARE v_job bigint;
BEGIN
  IF EXISTS(SELECT 1 FROM pg_extension WHERE extname='pg_cron') THEN
    v_job:=cron.schedule('recover-expired-wallet-holds','*/5 * * * *',
      'SELECT public.recover_expired_wallet_holds(100);');
    INSERT INTO public.scheduled_job_registry(job_name,job_id,owner,category,expected_schedule,
      freshness_threshold_minutes,max_consecutive_failures,is_critical,description)
    VALUES('recover-expired-wallet-holds',v_job,'billing_ops','refill_pipeline','*/5 * * * *',15,3,true,
      'Release expired proven pre-submission terminal reservations and flag ambiguous operations for reconciliation.')
    ON CONFLICT(job_name) DO UPDATE SET job_id=EXCLUDED.job_id,expected_schedule=EXCLUDED.expected_schedule,
      freshness_threshold_minutes=EXCLUDED.freshness_threshold_minutes,description=EXCLUDED.description,updated_at=now();
  END IF;
END;
$$;
COMMIT;
