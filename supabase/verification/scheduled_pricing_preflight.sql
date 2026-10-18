-- Read-only Task 20 release inspection: metadata only, no customer rows.
SELECT now() AS captured_at, c.relname,c.relrowsecurity,c.reloptions,
 has_table_privilege('anon',c.oid,'INSERT,UPDATE,DELETE') AS anon_mutation,
 has_table_privilege('authenticated',c.oid,'INSERT,UPDATE,DELETE') AS customer_mutation,
 has_any_column_privilege('authenticated',c.oid,'INSERT,UPDATE') AS customer_column_mutation
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relname IN ('scheduled_topups','customer_scheduled_topups','admin_internal_scheduled_topups');
SELECT p.oid::regprocedure AS signature,pg_get_function_result(p.oid) AS result,p.prosecdef,p.proconfig,
 has_function_privilege('anon',p.oid,'EXECUTE') AS anon_execute,
 has_function_privilege('authenticated',p.oid,'EXECUTE') AS customer_execute,
 has_function_privilege('service_role',p.oid,'EXECUTE') AS backend_execute,md5(p.prosrc) AS body_md5
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN
 ('save_customer_schedule','set_customer_schedule_active','delete_customer_schedule','initialize_line_schedules',
 'assert_schedule_access','sync_next_schedule_occurrence','guard_schedule_identity',
 'queue_premium_refill_executions','approve_refill_execution','approve_refill_execution_quote',
 'claim_due_executions','reschedule_mini_refill','reset_mini_refill_to_default','update_mini_refill_dates',
 'trg_fn_sync_custom_refill_queue','update_sim_line_last_topup_at','capture_sim_setup_holds')
ORDER BY p.oid::regprocedure::text;
SELECT policyname,cmd,roles,qual,with_check FROM pg_policies
WHERE schemaname='public' AND tablename='scheduled_topups';
SELECT tgname,pg_get_triggerdef(oid) FROM pg_trigger WHERE NOT tgisinternal
AND tgrelid IN ('public.scheduled_topups'::regclass,'public.topup_executions'::regclass) ORDER BY tgname;
SELECT tablename,indexname,indexdef FROM pg_indexes WHERE schemaname='public'
AND indexname='one_validated_waiting_schedule_occurrence';
SELECT table_name,column_name,column_default,is_nullable FROM information_schema.columns
WHERE table_schema='public' AND table_name IN ('scheduled_topups','topup_executions') AND column_name='schedule_contract_version';
SELECT version,name FROM supabase_migrations.schema_migrations WHERE version='20261018070000';
