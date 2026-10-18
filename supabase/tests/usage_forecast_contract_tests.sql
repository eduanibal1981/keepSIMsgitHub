-- Read-only post-release catalog check. Zero rows means no violations.
WITH expected(name,definer,customer,service) AS (VALUES
  ('compute_usage_forecasts',true,false,true),
  ('compute_usage_forecasts_internal',false,false,false),
  ('refresh_usage_forecasts',true,false,true),
  ('snapshot_esim_usage',true,false,true),
  ('emit_forecast_depletion_alerts',true,false,true),
  ('record_manual_external_recharge',true,true,true)
), actual AS (
  SELECT e.*,p.oid,p.prosecdef,p.proconfig FROM expected e
  LEFT JOIN pg_proc p ON p.proname=e.name AND p.pronamespace='public'::regnamespace
)
SELECT name AS violation FROM actual WHERE oid IS NULL OR prosecdef IS DISTINCT FROM definer
  OR proconfig IS DISTINCT FROM ARRAY['search_path=""']
  OR has_function_privilege('anon',oid,'EXECUTE')
  OR has_function_privilege('authenticated',oid,'EXECUTE') IS DISTINCT FROM customer
  OR has_function_privilege('service_role',oid,'EXECUTE') IS DISTINCT FROM service
  OR NOT has_function_privilege('postgres',oid,'EXECUTE');
