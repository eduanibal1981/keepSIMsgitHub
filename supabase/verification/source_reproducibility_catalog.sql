-- Read-only, data-free comparison. No function bodies, role credentials, config
-- values, cron command text, Vault contents or application rows are exported.
SELECT jsonb_build_object(
  'server_version', current_setting('server_version'),
  'functions', (SELECT jsonb_agg(jsonb_build_object(
    'name',p.proname,'types',oidvectortypes(p.proargtypes),
    'identity',pg_get_function_identity_arguments(p.oid),
    'source_sha256',encode(sha256(convert_to(p.prosrc,'UTF8')),'hex'),
    'definition_sha256',encode(sha256(convert_to(pg_get_functiondef(p.oid),'UTF8')),'hex'),
    'security_definer',p.prosecdef,'settings',p.proconfig,
    'acl',p.proacl::text) ORDER BY p.proname,oidvectortypes(p.proargtypes))
    FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.prokind='f'),
  'extensions',(SELECT jsonb_agg(jsonb_build_object('name',e.extname,
    'version',e.extversion,'schema',n.nspname) ORDER BY e.extname)
    FROM pg_extension e JOIN pg_namespace n ON n.oid=e.extnamespace),
  'history',(SELECT jsonb_agg(jsonb_build_object('version',version,'name',name)
    ORDER BY version) FROM supabase_migrations.schema_migrations),
  'cron',(SELECT jsonb_agg(jsonb_build_object('name',jobname,'schedule',schedule,
    'active',active,'command_sha256',encode(sha256(convert_to(command,'UTF8')),'hex'))
    ORDER BY jobname) FROM cron.job),
  'constraints',(SELECT jsonb_agg(jsonb_build_object('table',r.relname,
    'name',c.conname,'type',c.contype,'definition_sha256',
    encode(sha256(convert_to(pg_get_constraintdef(c.oid,true),'UTF8')),'hex'))
    ORDER BY r.relname,c.conname) FROM pg_constraint c
    JOIN pg_class r ON r.oid=c.conrelid JOIN pg_namespace n ON n.oid=r.relnamespace
    WHERE n.nspname='public'),
  'relations',(SELECT jsonb_agg(jsonb_build_object('name',c.relname,
    'kind',c.relkind,'rls',c.relrowsecurity,'force_rls',c.relforcerowsecurity,
    'options',c.reloptions,'acl',c.relacl::text) ORDER BY c.relname)
    FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relkind IN ('r','v','m','S','p')),
  'columns',(SELECT jsonb_agg(jsonb_build_object('table',c.relname,'name',a.attname,
    'type',format_type(a.atttypid,a.atttypmod),'not_null',a.attnotnull,
    'generated',a.attgenerated,'identity',a.attidentity,'acl',a.attacl::text,
    'default_sha256',encode(sha256(convert_to(coalesce(pg_get_expr(d.adbin,d.adrelid),''),'UTF8')),'hex'))
    ORDER BY c.relname,a.attnum) FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid
    JOIN pg_namespace n ON n.oid=c.relnamespace LEFT JOIN pg_attrdef d ON d.adrelid=c.oid AND d.adnum=a.attnum
    WHERE n.nspname='public' AND c.relkind IN ('r','p') AND a.attnum>0 AND NOT a.attisdropped),
  'triggers',(SELECT jsonb_agg(jsonb_build_object('schema',n.nspname,'table',c.relname,
    'name',t.tgname,'enabled',t.tgenabled,'definition_sha256',
    encode(sha256(convert_to(pg_get_triggerdef(t.oid,true),'UTF8')),'hex'))
    ORDER BY n.nspname,c.relname,t.tgname) FROM pg_trigger t
    JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace
    JOIN pg_proc p ON p.oid=t.tgfoid JOIN pg_namespace pn ON pn.oid=p.pronamespace
    WHERE NOT t.tgisinternal AND (n.nspname='public' OR pn.nspname='public')),
  'views',(SELECT jsonb_agg(jsonb_build_object('name',c.relname,'definition_sha256',
    encode(sha256(convert_to(pg_get_viewdef(c.oid,true),'UTF8')),'hex')) ORDER BY c.relname)
    FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relkind IN ('v','m')),
  'non_public_dependencies',(SELECT jsonb_agg(DISTINCT
    jsonb_build_object('public_object',pg_describe_object(d.classid,d.objid,d.objsubid),
    'dependency',pg_describe_object(d.refclassid,d.refobjid,d.refobjsubid)))
    FROM pg_depend d JOIN pg_namespace ns ON ns.oid=d.refobjid
    WHERE d.refclassid='pg_namespace'::regclass AND ns.nspname NOT IN ('public','pg_catalog','information_schema')
      AND d.objid IN (SELECT p.oid FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public')),
  'policies',(SELECT jsonb_agg(jsonb_build_object('table',tablename,'name',policyname,
    'roles',roles,'command',cmd,'permissive',permissive,
    'using_sha256',encode(sha256(convert_to(coalesce(qual,''),'UTF8')),'hex'),
    'check_sha256',encode(sha256(convert_to(coalesce(with_check,''),'UTF8')),'hex'))
    ORDER BY tablename,policyname) FROM pg_policies WHERE schemaname='public'),
  'defaults',(SELECT jsonb_agg(jsonb_build_object('schema',n.nspname,
    'type',d.defaclobjtype,'acl',d.defaclacl::text)
    ORDER BY d.defaclnamespace,d.defaclobjtype,d.defaclrole)
    FROM pg_default_acl d LEFT JOIN pg_namespace n ON n.oid=d.defaclnamespace),
  'effective_table_grants',(SELECT jsonb_agg(jsonb_build_object('table',c.relname,
    'role',r.role,'privilege',v.privilege,'allowed',has_table_privilege(r.role,c.oid,v.privilege))
    ORDER BY c.relname,r.role,v.privilege)
    FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    CROSS JOIN (VALUES('anon'),('authenticated'),('service_role')) r(role)
    CROSS JOIN (VALUES('SELECT'),('INSERT'),('UPDATE'),('DELETE'),('TRUNCATE'),('REFERENCES'),('TRIGGER'),('MAINTAIN')) v(privilege)
    WHERE n.nspname='public' AND c.relkind IN ('r','p'))
) AS catalog;
