-- No synthetic profiles, wallet changes, provider jobs or persisted mutations.
BEGIN;
DO $$
DECLARE f text; t text; result jsonb; profile_id uuid:=gen_random_uuid(); owner_id uuid:=gen_random_uuid();
BEGIN
 FOREACH t IN ARRAY ARRAY['recharge_policy','topup_cache','recharge_quotes'] LOOP
  IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid=('esim_private.'||t)::regclass) THEN RAISE EXCEPTION 'Private RLS missing'; END IF;
  IF has_table_privilege('anon','esim_private.'||t,'SELECT') OR has_table_privilege('authenticated','esim_private.'||t,'SELECT') THEN RAISE EXCEPTION 'Private table exposed'; END IF;
 END LOOP;
 IF has_schema_privilege('authenticated','esim_private','USAGE') THEN RAISE EXCEPTION 'Private schema exposed'; END IF;
 FOREACH f IN ARRAY ARRAY['public.request_esim_topups(uuid)','public.quote_esim_topup(uuid,text,uuid,numeric)','public.check_esim_topup_quote(uuid)'] LOOP
  IF has_function_privilege('anon',f,'EXECUTE') OR NOT has_function_privilege('authenticated',f,'EXECUTE') THEN RAISE EXCEPTION 'Customer ACL incorrect'; END IF;
 END LOOP;
 FOREACH f IN ARRAY ARRAY['public.service_esim_claim_topups(text)','public.service_esim_save_topups(uuid,uuid,jsonb,text)','public.prune_esim_topup_discovery()'] LOOP
  IF has_function_privilege('anon',f,'EXECUTE') OR has_function_privilege('authenticated',f,'EXECUTE') OR NOT has_function_privilege('service_role',f,'EXECUTE') THEN RAISE EXCEPTION 'Service ACL incorrect'; END IF;
 END LOOP;
 PERFORM set_config('request.jwt.claim.sub',owner_id::text,true);
 PERFORM set_config('request.jwt.claim.role','authenticated',true);
 EXECUTE 'SET LOCAL ROLE authenticated';
 result:=public.request_esim_topups(profile_id);
 IF result->>'status'<>'PROFILE_UNAVAILABLE' THEN RAISE EXCEPTION 'Unrelated profile readable'; END IF;
 result:=public.quote_esim_topup(profile_id,'NOT_COMPATIBLE',gen_random_uuid(),0.01);
 IF result->>'status'<>'PROFILE_UNAVAILABLE' THEN RAISE EXCEPTION 'Unrelated quote allowed'; END IF;
 result:=public.check_esim_topup_quote(gen_random_uuid());
 IF result->>'status'<>'QUOTE_UNAVAILABLE' THEN RAISE EXCEPTION 'Unrelated quote readable'; END IF;
 BEGIN PERFORM public.service_esim_claim_topups();RAISE EXCEPTION 'Client service access allowed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 EXECUTE 'RESET ROLE';
 EXECUTE 'SET LOCAL ROLE anon';
 BEGIN PERFORM public.request_esim_topups(profile_id);RAISE EXCEPTION 'Anonymous discovery allowed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 EXECUTE 'RESET ROLE';
 IF md5(pg_get_functiondef('public.request_esim_purchase(text,integer,text)'::regprocedure))<>'524b7d1f6f79eadaf422fb0ff3f1c315' THEN RAISE EXCEPTION 'Purchase source changed'; END IF;
 IF EXISTS(SELECT 1 FROM esim_private.accounts WHERE new_sales_enabled) THEN RAISE EXCEPTION 'Money gate changed'; END IF;
END $$;
ROLLBACK;
SELECT 'PASS private RLS/ACLs, owner isolation, anon/service denials and unchanged purchase gate' AS verification;
