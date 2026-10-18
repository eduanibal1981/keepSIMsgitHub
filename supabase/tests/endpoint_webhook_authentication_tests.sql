-- Read-only release check. Zero rows is PASS. Safe before and after deployment.
WITH wanted(signature) AS (VALUES
  ('public.claim_verified_webhook(text,text,text,text)'),
  ('public.finish_verified_webhook(text,text,uuid,boolean)')
), functions AS (
  SELECT signature,to_regprocedure(signature)::oid AS oid FROM wanted
), violations AS (
  SELECT 'missing_function:'||signature AS violation FROM functions WHERE oid IS NULL
  UNION ALL
  SELECT 'unsafe_function:'||signature FROM functions f JOIN pg_proc p ON p.oid=f.oid
  WHERE NOT p.prosecdef OR p.proconfig IS DISTINCT FROM ARRAY['search_path=""']::text[]
    OR has_function_privilege('anon',p.oid,'EXECUTE')
    OR has_function_privilege('authenticated',p.oid,'EXECUTE')
    OR NOT has_function_privilege('service_role',p.oid,'EXECUTE')
  UNION ALL
  SELECT 'missing_receipt_table' WHERE to_regclass('public.verified_webhook_events') IS NULL
  UNION ALL
  SELECT 'unsafe_receipt_table' FROM pg_class c WHERE c.oid=to_regclass('public.verified_webhook_events') AND (
    NOT c.relrowsecurity OR EXISTS (
      SELECT 1 FROM (VALUES ('anon'),('authenticated'),('service_role')) AS r(role_name)
      WHERE has_table_privilege(r.role_name,c.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
    ))
  UNION ALL
  SELECT 'missing_recording_identity' WHERE NOT EXISTS (
    SELECT 1 FROM pg_attribute WHERE attrelid=to_regclass('public.voicemail_messages') AND attname='source_recording_id' AND NOT attisdropped)
  UNION ALL
  SELECT 'missing_unique_recording_identity' WHERE NOT EXISTS (
    SELECT 1 FROM pg_index i WHERE i.indexrelid=to_regclass('public.voicemail_source_recording_id') AND i.indisunique AND i.indisvalid)
)
SELECT violation FROM violations ORDER BY violation;
