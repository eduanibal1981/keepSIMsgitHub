-- Read-only inspection for an authorized targeted release. No job installation,
-- process start, provider requests, seed writes, grants or alert sweeps.
SELECT p.oid::regprocedure AS signature,md5(p.prosrc) AS body_md5,
       p.prosecdef,p.proconfig,p.proacl
FROM pg_proc p WHERE p.oid IN
 (to_regprocedure('public.check_worker_heartbeat_health()'),
  to_regprocedure('public.report_worker_health(text,uuid,timestamptz,bigint,text,jsonb)'),
  to_regprocedure('public.get_worker_fleet_health()'),
  to_regprocedure('public.admin_worker_fleet_health()'));
SELECT jobname,schedule,active FROM cron.job ORDER BY jobname;
SELECT name,default_version,installed_version FROM pg_available_extensions
 WHERE name IN ('pg_cron','pgcrypto');
SELECT relation_name,to_regclass('public.'||relation_name) AS actual_relation FROM unnest(ARRAY[
 'topup_executions','refill_supplier_submissions','wallet_holds','wallet_refund_items',
 'esim_orders','offline_voucher_requests','offline_voucher_purchase_jobs',
 'notification_dispatch_jobs','notification_channel_targets','whatsapp_message_attempts',
 'admin_emails','second_number_orders','virtual_did_numbers','account_purge_jobs',
 'call_records','line_verification_attempts','wallet_reconciliation','refill_approval_quotes',
 'esim_suppliers','carrier_provider_map','supplier_policy','provider_offers_cache'
]) relation_name;
-- After release: use the explicit admin API for component/version/count detail;
-- service callers use get_worker_fleet_health(), never raw monitoring tables.
