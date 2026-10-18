-- Read-only post-release checks. Zero rows means expected catalog contracts.
WITH trusted(signature) AS (VALUES
 ('line_paid_plan_evidence(uuid,text)'),('resolve_line_entitlement(uuid)'),
 ('standard_upgrade_credit_usd(uuid)'),('membership_fee_usd(text)'),
 ('resolve_app_fee(text,text,numeric)'),('pay_plan_fee_from_wallet(text,uuid,text,text,uuid)'),
 ('get_authoritative_refill_quote(uuid,numeric,text,text,text)')),
resolved AS(SELECT signature,to_regprocedure('public.'||signature) oid FROM trusted)
SELECT signature,'unsafe or missing trusted pricing function' violation FROM resolved
LEFT JOIN pg_proc ON pg_proc.oid=resolved.oid
WHERE resolved.oid IS NULL OR NOT prosecdef OR proconfig IS DISTINCT FROM ARRAY['search_path=""']
 OR has_function_privilege('authenticated',resolved.oid,'EXECUTE')
 OR has_function_privilege('anon',resolved.oid,'EXECUTE')
 OR NOT has_function_privilege('service_role',resolved.oid,'EXECUTE')
UNION ALL
SELECT 'line_plan_grants','client evidence write access' WHERE
 has_table_privilege('authenticated','public.line_plan_grants','SELECT,INSERT,UPDATE,DELETE,TRUNCATE')
 OR has_table_privilege('anon','public.line_plan_grants','SELECT,INSERT,UPDATE,DELETE,TRUNCATE')
UNION ALL
SELECT 'plan_payments','client receipt write access' WHERE
 has_table_privilege('authenticated','public.plan_payments','INSERT,UPDATE,DELETE,TRUNCATE')
UNION ALL
SELECT 'sim_setup_orders','client price snapshot write access' WHERE
 has_table_privilege('authenticated','public.sim_setup_orders','INSERT,UPDATE,DELETE,TRUNCATE');
