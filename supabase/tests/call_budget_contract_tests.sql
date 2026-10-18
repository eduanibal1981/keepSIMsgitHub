-- Read-only catalog guard. Empty rows mean success; does not dial or mutate money.
WITH contracts(signature,expected_definer) AS (VALUES
 ('public.prepare_budgeted_media_call(uuid,jsonb,uuid)',true),
 ('public.begin_media_call_leg(uuid,text)',true),
 ('public.assert_media_call_reservation(uuid,boolean)',true),
 ('public.request_media_call_termination(uuid)',true),
 ('public.record_media_call_evidence(uuid,text,text,timestamp with time zone,jsonb)',true),
 ('public.finish_media_call(uuid,timestamp with time zone,text,text,jsonb)',false)
), failures AS (
 SELECT signature AS failure FROM contracts c LEFT JOIN pg_proc p ON p.oid=to_regprocedure(c.signature)
 WHERE p.oid IS NULL OR p.prosecdef<>c.expected_definer
   OR NOT (coalesce(p.proconfig,ARRAY[]::text[]) @> ARRAY['search_path=""'])
   OR has_function_privilege('anon',p.oid,'EXECUTE')
   OR has_function_privilege('authenticated',p.oid,'EXECUTE')
   OR NOT has_function_privilege('service_role',p.oid,'EXECUTE')
 UNION ALL
 SELECT 'call budget CHECK missing' WHERE NOT EXISTS(SELECT 1 FROM pg_constraint
   WHERE conrelid='public.call_records'::regclass AND conname='call_budget_snapshot_check' AND convalidated)
 UNION ALL
 SELECT 'call budget reservation uniqueness missing' WHERE NOT EXISTS(SELECT 1 FROM pg_indexes
   WHERE schemaname='public' AND indexname='call_budget_hold_unique' AND indexdef LIKE 'CREATE UNIQUE INDEX%')
)
SELECT * FROM failures;
