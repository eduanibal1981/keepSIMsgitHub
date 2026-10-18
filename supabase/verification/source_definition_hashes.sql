-- Read-only canonical (non-pretty) deparse hashes for historical comparison.
SELECT jsonb_build_object(
 'constraints',(SELECT jsonb_agg(jsonb_build_object('table',r.relname,'name',c.conname,
   'sha256',encode(sha256(convert_to(pg_get_constraintdef(c.oid,false),'UTF8')),'hex'))
   ORDER BY r.relname,c.conname)
   FROM pg_constraint c JOIN pg_class r ON r.oid=c.conrelid JOIN pg_namespace n ON n.oid=r.relnamespace
   WHERE n.nspname='public'),
 'triggers',(SELECT jsonb_agg(jsonb_build_object('table',r.relname,'name',t.tgname,
   'sha256',encode(sha256(convert_to(pg_get_triggerdef(t.oid,false),'UTF8')),'hex'))
   ORDER BY r.relname,t.tgname)
   FROM pg_trigger t JOIN pg_class r ON r.oid=t.tgrelid JOIN pg_namespace n ON n.oid=r.relnamespace
   WHERE n.nspname='public' AND NOT t.tgisinternal)
) AS comparison;
