-- Read-only post-release catalog check. Zero rows means the expected access
-- contracts are present; this does not certify real SMS/carrier delivery.
WITH trusted(name,args) AS(VALUES
  ('authorize_second_number_purchase','uuid,uuid,boolean,numeric,numeric'),
  ('settle_second_number_renewal','uuid,timestamp with time zone,text'),
  ('begin_second_number_purchase','uuid,uuid,boolean'),
  ('capture_second_number_hold','uuid,text'),
  ('finish_second_number_purchase','uuid,text,text'),
  ('fail_second_number_purchase','uuid'),
  ('route_second_number_sms','text,text,text,text,text,timestamp with time zone'),
  ('process_second_number_renewals','integer'),
  ('claim_second_number_releases','integer'),
  ('finish_second_number_release','uuid,uuid,boolean')),
resolved AS(SELECT name,to_regprocedure('public.'||name||'('||args||')') oid FROM trusted)
SELECT name,'missing or unsafe trusted function' AS violation FROM resolved r
LEFT JOIN pg_proc p ON p.oid=r.oid
WHERE r.oid IS NULL OR NOT p.prosecdef OR p.proconfig IS DISTINCT FROM ARRAY['search_path=""']
  OR has_function_privilege('anon',r.oid,'EXECUTE') OR has_function_privilege('authenticated',r.oid,'EXECUTE')
  OR NOT has_function_privilege('service_role',r.oid,'EXECUTE')
UNION ALL
SELECT 'virtual_did_messages','client write access' WHERE
  has_table_privilege('authenticated','public.virtual_did_messages','INSERT,UPDATE,DELETE')
  OR has_table_privilege('anon','public.virtual_did_messages','SELECT,INSERT,UPDATE,DELETE')
UNION ALL
SELECT 'second_number_orders','client raw order access' WHERE
  has_table_privilege('authenticated','public.second_number_orders','SELECT,INSERT,UPDATE,DELETE')
UNION ALL
SELECT 'second_number_renewals','client financial access' WHERE
  has_table_privilege('authenticated','public.second_number_renewals','SELECT,INSERT,UPDATE,DELETE,TRUNCATE')
  OR has_table_privilege('anon','public.second_number_renewals','SELECT,INSERT,UPDATE,DELETE,TRUNCATE')
UNION ALL
SELECT 'second_number_purchase_gate','client gate access' WHERE
  has_table_privilege('authenticated','public.second_number_purchase_gate','SELECT,INSERT,UPDATE,DELETE,TRUNCATE')
  OR has_table_privilege('anon','public.second_number_purchase_gate','SELECT,INSERT,UPDATE,DELETE,TRUNCATE')
UNION ALL
SELECT 'virtual_did_numbers','client financial writes' WHERE
  has_table_privilege('authenticated','public.virtual_did_numbers','INSERT,UPDATE,DELETE,TRUNCATE');
