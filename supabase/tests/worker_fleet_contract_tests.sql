-- CASE: fleet tables and raw snapshot stay private; observation APIs have explicit grants
DO $test$
DECLARE role_name text; obj text;
BEGIN
 FOREACH role_name IN ARRAY ARRAY['anon','authenticated'] LOOP
  FOREACH obj IN ARRAY ARRAY['worker_fleet_requirements','worker_fleet_runtime','worker_fleet_probes','worker_fleet_cron','worker_fleet_incidents','worker_fleet_observation'] LOOP
   IF has_table_privilege(role_name,'public.'||obj,'SELECT,INSERT,UPDATE,DELETE') THEN RAISE EXCEPTION 'Unexpected fleet table access'; END IF;
  END LOOP;
  IF has_function_privilege(role_name,'public.report_worker_health(text,uuid,timestamptz,bigint,text,jsonb)','EXECUTE')
   OR has_function_privilege(role_name,'public.get_worker_fleet_health()','EXECUTE')
   OR has_function_privilege(role_name,'public.worker_fleet_snapshot()','EXECUTE')
   OR has_function_privilege(role_name,'public.worker_fleet_cached_snapshot()','EXECUTE')
   OR has_function_privilege(role_name,'public.worker_fleet_runtime_snapshot()','EXECUTE')
   OR has_function_privilege(role_name,'public.check_worker_fleet_health()','EXECUTE') THEN RAISE EXCEPTION 'Unexpected fleet function access'; END IF;
 END LOOP;
 IF NOT has_function_privilege('service_role','public.get_worker_fleet_health()','EXECUTE')
  OR NOT has_function_privilege('authenticated','public.admin_worker_fleet_health()','EXECUTE')
  OR has_function_privilege('anon','public.admin_worker_fleet_health()','EXECUTE') THEN RAISE EXCEPTION 'Unexpected fleet API grants'; END IF;
END;
$test$;

-- CASE: ordinary authenticated users cannot inspect detailed worker health
DO $test$
BEGIN
 PERFORM set_config('request.jwt.claims','{"role":"authenticated","sub":"10000000-0000-4000-8000-000000000001"}',true);
 SET LOCAL ROLE authenticated;
 BEGIN
  PERFORM public.admin_worker_fleet_health();
  RAISE EXCEPTION 'Expected admin denial';
 EXCEPTION WHEN SQLSTATE 'KS460' THEN NULL;
 END;
 RESET ROLE;
END;
$test$;
