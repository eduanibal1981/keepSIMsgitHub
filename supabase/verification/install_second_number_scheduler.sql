-- OPERATIONAL RELEASE STEP: run only after the coordinated financial migration,
-- Second Number migration and matching Edge Functions have been deployed and
-- verified. Requires pg_cron/pg_net and the existing service credential stored
-- by an operator in Vault as second_number_lifecycle_service_key. Never put the
-- credential in this file, SQL arguments, system_configs, or a client response.
BEGIN;
DO $$ BEGIN
  IF NOT EXISTS(SELECT 1 FROM vault.decrypted_secrets WHERE name='second_number_lifecycle_service_key' AND length(decrypted_secret)>0) THEN
    RAISE EXCEPTION 'Configure the lifecycle scheduler credential in Vault first';
  END IF;
END $$;
CREATE OR REPLACE FUNCTION public.invoke_second_number_lifecycle() RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE request_id bigint; token text;
BEGIN
  SELECT decrypted_secret INTO STRICT token FROM vault.decrypted_secrets WHERE name='second_number_lifecycle_service_key';
  SELECT net.http_post(
    url:='https://zwxswagokhgbuzrrbnhr.supabase.co/functions/v1/second-number-lifecycle',
    headers:=jsonb_build_object('Authorization','Bearer '||token,'Content-Type','application/json'),
    body:='{}'::jsonb,timeout_milliseconds:=120000) INTO request_id;
  RETURN request_id;
END $$;
REVOKE ALL ON FUNCTION public.invoke_second_number_lifecycle() FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.invoke_second_number_lifecycle() TO postgres;
SELECT cron.schedule('second-number-lifecycle','*/5 * * * *','SELECT public.invoke_second_number_lifecycle();');
INSERT INTO public.scheduled_job_registry(job_name,job_id,owner,category,expected_schedule,freshness_threshold_minutes,is_critical,description)
  SELECT 'second-number-lifecycle',jobid,'billing','calling','*/5 * * * *',15,true,
    'Reconciles Second Number orders, renewals, grace recovery and confirmed releases'
  FROM cron.job WHERE jobname='second-number-lifecycle'
ON CONFLICT(job_name) DO UPDATE SET job_id=excluded.job_id,expected_schedule=excluded.expected_schedule,
  freshness_threshold_minutes=excluded.freshness_threshold_minutes,is_critical=true,updated_at=now();
COMMIT;
