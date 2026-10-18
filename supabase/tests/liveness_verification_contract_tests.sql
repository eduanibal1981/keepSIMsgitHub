-- Read-only catalog checks: zero rows after Task 12. Safe against deployed DB.
SELECT 'customer executable: '||p.proname AS violation
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname IN ('confirm_line_verification','settle_line_verification_attempt',
 'begin_line_verification','bind_line_verification_resource','settle_line_verification_event')
 AND (has_function_privilege('anon',p.oid,'EXECUTE') OR has_function_privilege('authenticated',p.oid,'EXECUTE'))
UNION ALL
SELECT 'customer mutation: '||t||'/'||v
FROM unnest(ARRAY['line_verification_attempts','line_verification_allowances']) t
CROSS JOIN unnest(ARRAY['INSERT','UPDATE','DELETE','TRUNCATE']) v
WHERE has_table_privilege('anon','public.'||t,v) OR has_table_privilege('authenticated','public.'||t,v)
UNION ALL
SELECT 'missing trusted evidence version'
WHERE NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public'
 AND table_name='line_verification_attempts' AND column_name='evidence_version')
UNION ALL
SELECT 'missing verification field guard'
WHERE NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.sim_lines'::regclass
 AND tgname='z_guard_line_verification_fields' AND tgenabled='O');
