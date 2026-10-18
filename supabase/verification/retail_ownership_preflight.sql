-- Read-only Task 19 release verification. No customer rows or provider calls.
SELECT c.relname,c.relkind,c.relrowsecurity,c.reloptions,
 has_table_privilege('anon',c.oid,'SELECT') AS anon_table_read,
 has_table_privilege('authenticated',c.oid,'SELECT') AS customer_table_read,
 has_any_column_privilege('authenticated',c.oid,'SELECT') AS customer_column_read,
 has_table_privilege('service_role',c.oid,'SELECT') AS backend_read
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relname IN
 ('provider_offers','provider_offers_cache','provider_offers_effective','zendit_offers_cache',
  'esim_offers_cache','esim_suppliers','esim_offers','esim_orders','return_trip_packages',
  'return_trips','call_rates','refill_approval_quotes','sim_setup_orders','topup_executions',
  'scheduled_topups','call_records','customer_esim_orders','customer_topup_executions',
  'customer_scheduled_topups','customer_call_records','customer_refill_approval_quotes',
  'admin_internal_provider_offers','admin_internal_provider_offers_cache','admin_internal_topup_executions')
ORDER BY c.relname;

SELECT p.oid::regprocedure AS signature,pg_get_function_result(p.oid) AS return_shape,
 has_function_privilege('anon',p.oid,'EXECUTE') AS anon_execute,
 has_function_privilege('authenticated',p.oid,'EXECUTE') AS customer_execute,
 has_function_privilege('service_role',p.oid,'EXECUTE') AS backend_execute,
 p.proconfig,md5(p.prosrc) AS body_md5
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'
AND p.proname IN ('get_authoritative_refill_quote','selected_refill_quote_internal',
 'get_customer_refill_quote','request_retail_instant_refill','request_instant_refill',
 'get_return_trip_packages_for_line','get_active_return_trip_for_line','get_return_trip_history_for_line',
 'get_user_calling_rates','get_call_rate_for_number','resolve_account_commerce_benefit','resolve_line_entitlement',
 'line_paid_plan_evidence','has_paid_premium_entitlement','resolve_esim_offer_price','customer_esim_price',
 'list_refill_offers','list_carrier_offers','choose_supplier_for_offer','supplier_candidates','carrier_refill_offer')
ORDER BY p.proname,p.oid::regprocedure::text;

SELECT table_name,column_name,grantee,privilege_type FROM information_schema.column_privileges
WHERE table_schema='public' AND grantee IN ('anon','authenticated','PUBLIC')
AND table_name IN ('provider_offers','provider_offers_cache','esim_offers_cache','esim_orders',
 'call_rates','return_trip_packages','refill_approval_quotes','sim_setup_orders','topup_executions',
 'scheduled_topups','call_records') ORDER BY table_name,grantee,column_name,privilege_type;
