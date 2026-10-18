-- Read-only contract checks; behavior scenarios live in tools/financial-tests/vouchers.mjs.
-- CASE: status API has explicit signed-in grants and a safe definer boundary
DO $test$
BEGIN
 IF has_function_privilege('anon','public.offline_voucher_state()','EXECUTE')
    OR NOT has_function_privilege('authenticated','public.offline_voucher_state()','EXECUTE')
    OR NOT has_function_privilege('service_role','public.offline_voucher_state()','EXECUTE') THEN
  RAISE EXCEPTION 'Unexpected voucher state execution grants';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid='public.offline_voucher_state()'::regprocedure
   AND prosecdef AND provolatile='s' AND proconfig @> ARRAY['search_path=""']) THEN
  RAISE EXCEPTION 'Voucher state definer boundary differs';
 END IF;
END;
$test$;
