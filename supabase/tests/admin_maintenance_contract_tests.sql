-- Read-only post-release checks. Zero rows means no catalog violations.
WITH expected(name,definer,customer,service) AS (VALUES
 ('admin_prune_database_logs',true,true,true),('prune_database_logs',true,false,true),
 ('prune_database_logs_internal',false,false,false),('check_rate_limit_health',true,false,true),
 ('admin_purge_user_account',true,true,false),('purge_deleted_accounts',true,false,true),
 ('claim_account_purge_job',true,false,true),('finish_account_purge_job',true,false,true),
 ('dispatch_account_purge_job',false,false,false),('log_account_purge_job',false,false,false),
 ('delete_auth_user_by_id',true,false,false),('claim_admin_email',true,false,true),
 ('finish_admin_email',true,false,true),('kick_admin_email',false,false,true)
), functions AS (
 SELECT e.*,p.oid,p.prosecdef,p.proconfig FROM expected e
 LEFT JOIN pg_proc p ON p.proname=e.name AND p.pronamespace='public'::regnamespace
)
SELECT name AS violation FROM functions WHERE oid IS NULL OR prosecdef IS DISTINCT FROM definer
 OR proconfig IS DISTINCT FROM ARRAY['search_path=""']
 OR has_function_privilege('anon',oid,'EXECUTE')
 OR has_function_privilege('authenticated',oid,'EXECUTE') IS DISTINCT FROM customer
 OR has_function_privilege('service_role',oid,'EXECUTE') IS DISTINCT FROM service
UNION ALL
SELECT 'direct purge job access: '||r.role FROM (VALUES('anon'),('authenticated'),('service_role')) r(role)
WHERE has_table_privilege(r.role,'public.account_purge_jobs','SELECT,INSERT,UPDATE,DELETE,TRUNCATE')
UNION ALL
SELECT 'client mutation: '||r.role||'.'||r.tbl FROM
 (VALUES('anon','account_deletions'),('authenticated','account_deletions'),
        ('anon','admin_emails'),('authenticated','admin_emails')) r(role,tbl)
WHERE has_table_privilege(r.role,'public.'||r.tbl,'INSERT,UPDATE,DELETE,TRUNCATE');
