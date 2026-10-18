-- Read-only post-migration catalog assertions; zero rows means no violations.
WITH expected(name,service) AS (VALUES
  ('emit_upcoming_refill_low_balance_reminders',true),
  ('process_due_notifications',true),
  ('trg_fn_notify_system_alert',false)
), actual AS (
  SELECT e.*,p.oid,p.prosecdef,p.proconfig
  FROM expected e LEFT JOIN pg_proc p ON p.proname=e.name
    AND p.pronamespace='public'::regnamespace AND p.pronargs=0
)
SELECT name AS violation FROM actual
WHERE oid IS NULL OR NOT prosecdef OR proconfig IS DISTINCT FROM ARRAY['search_path=""']
  OR has_function_privilege('anon',oid,'EXECUTE')
  OR has_function_privilege('authenticated',oid,'EXECUTE')
  OR has_function_privilege('service_role',oid,'EXECUTE') IS DISTINCT FROM service
  OR NOT has_function_privilege('postgres',oid,'EXECUTE');
