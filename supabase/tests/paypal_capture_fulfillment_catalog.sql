-- Read-only release verification. Zero rows is PASS, including before deploy.
WITH target AS (
 SELECT to_regprocedure('public.fulfill_paypal_capture(text,jsonb)')::oid AS oid
), violations AS (
 SELECT 'missing_fulfillment_rpc' AS violation FROM target WHERE oid IS NULL
 UNION ALL
 SELECT 'unsafe_fulfillment_rpc' FROM target t JOIN pg_proc p ON p.oid=t.oid
 WHERE NOT p.prosecdef OR p.proconfig IS DISTINCT FROM ARRAY['search_path=""']::text[]
 OR has_function_privilege('anon',p.oid,'EXECUTE') OR has_function_privilege('authenticated',p.oid,'EXECUTE')
 OR NOT has_function_privilege('service_role',p.oid,'EXECUTE')
 UNION ALL
 SELECT 'missing_capture_receipts' WHERE to_regclass('public.paypal_capture_receipts') IS NULL
 UNION ALL
 SELECT 'unsafe_capture_receipts' FROM pg_class c WHERE c.oid=to_regclass('public.paypal_capture_receipts') AND
 (NOT c.relrowsecurity OR EXISTS(SELECT 1 FROM (VALUES('anon'),('authenticated'),('service_role')) AS r(name)
 WHERE has_table_privilege(r.name,c.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')))
 UNION ALL
 SELECT 'missing_receipt_capture_uniqueness' WHERE NOT EXISTS(SELECT 1 FROM pg_constraint
 WHERE conrelid=to_regclass('public.paypal_capture_receipts') AND contype='p' AND pg_get_constraintdef(oid)='PRIMARY KEY (capture_id)')
 UNION ALL
 SELECT 'missing_receipt_order_uniqueness' WHERE NOT EXISTS(SELECT 1 FROM pg_constraint
 WHERE conrelid=to_regclass('public.paypal_capture_receipts') AND contype='u' AND pg_get_constraintdef(oid)='UNIQUE (order_id)')
 UNION ALL
 SELECT 'missing_order_merchant' WHERE NOT EXISTS(SELECT 1 FROM information_schema.columns
 WHERE table_schema='public' AND table_name='paypal_orders' AND column_name='merchant_id')
)
SELECT violation FROM violations ORDER BY violation;
