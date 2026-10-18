-- Read-only release inspection. Compare with the captured fixture/review before
-- applying the targeted migration; this file does not grant access or seed data.
SELECT p.oid::regprocedure AS signature, md5(p.prosrc) AS body_md5,
       p.prosecdef, p.provolatile, p.proconfig, p.proacl
FROM pg_proc p
WHERE p.oid IN (to_regprocedure('public.offline_voucher_state()'),
               to_regprocedure('public.admin_list_voucher_requests(text,integer)'));
SELECT conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint WHERE conrelid='public.offline_voucher_requests'::regclass;
SELECT indexname,indexdef FROM pg_indexes
WHERE schemaname='public' AND tablename='offline_voucher_requests';
SELECT c.relname,c.relrowsecurity,c.relacl FROM pg_class c
JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relname IN
 ('offline_voucher_requests','offline_voucher_grants','offline_voucher_stock');
SELECT config_key,config_value FROM public.system_configs
WHERE config_key='OFFLINE_VOUCHER_ENABLED';
