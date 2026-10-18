// Isolated Task 3 authorization tests. No network, provider or production writes.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';
const { PGlite } = await import(process.env.PGLITE_MODULE_PATH
  ? pathToFileURL(process.env.PGLITE_MODULE_PATH).href : '@electric-sql/pglite');
const root = new URL('../../', import.meta.url);
const read = p => fs.readFileSync(new URL(p, root), 'utf8');
const manifest = JSON.parse(read('docs/reviews/privileged-database-access-20261017/allowlist.json'));
const migration = read('supabase/migrations/20261016210736_privileged_database_access.sql');
const catalogTest = read('supabase/tests/privileged_database_access_tests.sql');
const db = new PGlite();
const uid = '10000000-0000-4000-8000-000000000001';
const foreign = '10000000-0000-4000-8000-000000000002';
const line = '20000000-0000-4000-8000-000000000001';
const otherLine = '20000000-0000-4000-8000-000000000002';
let count = 0;
async function test(name, run) { await run(); console.log('PASS '+name); count++; }
async function role(name, claims, run) {
  await db.exec('BEGIN');
  try {
    await db.exec('SET LOCAL ROLE '+name);
    await db.query("SELECT set_config('request.jwt.claims',$1,true)", [JSON.stringify(claims)]);
    return await run();
  } finally { await db.exec('ROLLBACK'); }
}
const user = (run, sub=uid, extra={}) => role('authenticated', {role:'authenticated',sub,app_metadata:{},...extra},run);
const admin = run => user(run,uid,{app_metadata:{is_power_user:true}});
const service = run => role('service_role',{role:'service_role'},run);
const anon = run => role('anon',{role:'anon'},run);
async function denied(run, code='42501') { await assert.rejects(run, e => e.code===code); }
const value = async (sql, args=[]) => (await db.query(sql,args)).rows[0].value;
try {
  await db.exec(`
    CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role BYPASSRLS;
    CREATE ROLE supabase_admin SUPERUSER;
    CREATE SCHEMA auth; CREATE SCHEMA extensions; CREATE SCHEMA cron;
    GRANT USAGE ON SCHEMA public,auth TO anon,authenticated,service_role;
    GRANT CREATE ON SCHEMA public TO PUBLIC;
    CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
      SELECT (nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'sub')::uuid;
    $$;
    CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS $$
      SELECT coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb,'{}'::jsonb);
    $$;
    CREATE TABLE cron.job_run_details(jobid bigint,status text,start_time timestamptz);
    SET check_function_bodies = false;
  `);
  await db.exec(read('supabase/tests/fixtures/privileged_database_access_tables.sql'));
  // ACL-only stand-ins for unrelated bodies. Preserve every live signature,
  // return type, definer flag, owner and effective API grant; no blanket fake admin gate.
  for (const f of manifest.functions) {
    await db.exec(`CREATE FUNCTION public.${f.signature} RETURNS ${f.returns}
      LANGUAGE plpgsql ${f.prosecdef?'SECURITY DEFINER':''}
      AS $$ BEGIN RAISE EXCEPTION 'Unrepresented fixture body' USING ERRCODE='P0002'; END; $$;`);
    if (f.proconfig) for (const config of f.proconfig) {
      const path=config.slice('search_path='.length);
      await db.exec(`ALTER FUNCTION public.${f.signature} SET search_path = ${!path||path==='""'?"''":path}`);
    }
    await db.exec(`REVOKE ALL ON FUNCTION public.${f.signature} FROM PUBLIC`);
    if (!f.proacl || /(?:^|[,{])=X/.test(f.proacl)) await db.exec(`GRANT EXECUTE ON FUNCTION public.${f.signature} TO PUBLIC`);
    for (const r of ['anon','authenticated','service_role']) if(f[r]) await db.exec(`GRANT EXECUTE ON FUNCTION public.${f.signature} TO ${r}`);
  }
  await db.exec(read('supabase/tests/fixtures/privileged_database_access_functions.sql'));
  await db.exec(`
    CREATE FUNCTION public.current_user_email() RETURNS text LANGUAGE sql AS $$ SELECT 'fixture@example.invalid'::text $$;
    CREATE FUNCTION public.fixture_unqualified_count() RETURNS bigint LANGUAGE sql SECURITY DEFINER
      SET search_path=public AS $$ SELECT count(*) FROM return_trips $$;
    GRANT REFERENCES(id) ON public.sim_lines TO authenticated;
    CREATE SEQUENCE public.fixture_sequence;
  `);
  const tablePrivileges={r:'SELECT',a:'INSERT',w:'UPDATE',d:'DELETE',D:'TRUNCATE',x:'REFERENCES',t:'TRIGGER',m:'MAINTAIN'};
  for(const t of manifest.relations.filter(t=>['r','p','v','m'].includes(t.kind))) {
    if(!await value('SELECT to_regclass($1) IS NOT NULL value',['public.'+t.name])) continue;
    for(const entry of t.acl||[]) {
      const [grantee,rest]=entry.split('=');
      if(!['','anon','authenticated','service_role'].includes(grantee)) continue;
      const privs=[...rest.split('/')[0]].filter(c=>c!=='*').map(c=>tablePrivileges[c]).filter(Boolean);
      if(privs.length) await db.exec(`GRANT ${privs.join(',')} ON TABLE public.${t.name} TO ${grantee||'PUBLIC'}`);
    }
  }
  await db.exec(`ALTER TABLE public.admin_audit_log ALTER COLUMN id SET DEFAULT gen_random_uuid(),
    ALTER COLUMN id SET NOT NULL, ALTER COLUMN created_at SET DEFAULT now(), ALTER COLUMN created_at SET NOT NULL,
    ALTER COLUMN action SET NOT NULL, ALTER COLUMN target_type SET NOT NULL`);
  for(const owner of ['postgres','supabase_admin']) for(const scope of ['', 'IN SCHEMA public']) {
    for(const kind of ['FUNCTIONS','TABLES','SEQUENCES']) {
      await db.exec(`ALTER DEFAULT PRIVILEGES FOR ROLE ${owner} ${scope} GRANT ALL ON ${kind} TO PUBLIC,anon,authenticated,service_role`);
    }
  }
  const rowDmlBefore=await value(`SELECT jsonb_agg(jsonb_build_array(c.relname,r.role,v.p,has_table_privilege(r.role,c.oid,v.p)) ORDER BY c.relname,r.role,v.p) value
    FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    CROSS JOIN (VALUES ('anon'),('authenticated'),('service_role')) r(role)
    CROSS JOIN (VALUES ('SELECT'),('INSERT'),('UPDATE'),('DELETE')) v(p)
    WHERE n.nspname='public' AND c.relkind='r'`);
  await test('baseline detects real broad function/table/default grants',async()=>assert((await db.query(catalogTest)).rows.length>50));
  await db.exec(migration);
  await test('complete live-signature grant matrix is closed',async()=>assert.deepEqual((await db.query(catalogTest)).rows,[]));
  await test('existing row DML and service grants preserved',async()=>{
    const after=await value(`SELECT jsonb_agg(jsonb_build_array(c.relname,r.role,v.p,has_table_privilege(r.role,c.oid,v.p)) ORDER BY c.relname,r.role,v.p) value
      FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
      CROSS JOIN (VALUES ('anon'),('authenticated'),('service_role')) r(role)
      CROSS JOIN (VALUES ('SELECT'),('INSERT'),('UPDATE'),('DELETE')) v(p)
      WHERE n.nspname='public' AND c.relkind='r'`);
    assert.deepEqual(after,rowDmlBefore);
    for(const f of manifest.functions.filter(f=>f.service_role&&!manifest.owner_only.includes(f.signature)))
      assert.equal(await value('SELECT has_function_privilege($1,$2,\'EXECUTE\') value',['service_role','public.'+f.signature]),true,f.signature);
  });
  await test('idempotent migration',async()=>{await db.exec(migration);assert.deepEqual((await db.query(catalogTest)).rows,[]);});
  await db.exec(`
    INSERT INTO public.sim_lines(id,user_id) VALUES ('${line}','${uid}'),('${otherLine}','${foreign}');
    INSERT INTO public.return_trips(id,user_id,sim_line_id,status,arrival_date) VALUES
      (gen_random_uuid(),'${uid}','${line}','planning',current_date),
      (gen_random_uuid(),'${foreign}','${otherLine}','planning',current_date);
    INSERT INTO public.countries(id,name) VALUES ('40000000-0000-4000-8000-000000000001','Fixture country');
    UPDATE public.sim_lines SET country_id='40000000-0000-4000-8000-000000000001',plan_type='free';
    INSERT INTO public.return_trip_packages(id,country_id,is_active,supplier_cost_usd,retail_price_usd)
      VALUES (gen_random_uuid(),'40000000-0000-4000-8000-000000000001',true,1,2);
    INSERT INTO public.call_rates(id,country_code,country_name,phone_prefix,rate_per_minute_usd,cost_per_minute_usd,is_active)
      VALUES(gen_random_uuid(),'FX','Fixture country','+1',0.2,0.1,true);
    INSERT INTO public.system_alerts(id,kind,created_at) VALUES (gen_random_uuid(),'fixture-old',now()-interval '200 days');
    INSERT INTO cron.job_run_details VALUES (1,'succeeded',now()-interval '200 days');
  `);
  const unsafeCalls=[
    "SELECT public.finalize_sim_setup_order(null::uuid,null::text)",
    "SELECT public.confirm_line_verification(null::uuid,'sms',null)",
    'SELECT public.check_scheduled_jobs_health()',
    'SELECT public.prune_database_logs(14,90)',
    'SELECT public.reap_stuck_executions(10,3)',
    'SELECT public.resolve_line_entitlement(null::uuid)',
    "SELECT public.resolve_app_fee('refills','premium',1)",
    "SELECT public.settle_line_verification_attempt(null::uuid,'succeeded',null,null)",
  ];
  for(const [label,actor] of [['anonymous',anon],['ordinary',user],['admin',admin]]) {
    await test(label+' denied internal, maintenance and self-confirmation RPCs',async()=>{
      for(const call of unsafeCalls) await denied(()=>actor(()=>db.query(call)));
    });
  }
  await test('service cannot call retired finalizer, self-confirmation or postgres-only maintenance',async()=>{
    for(const call of unsafeCalls.slice(0,4)) await denied(()=>service(()=>db.query(call)));
  });
  for(const actor of [anon,user]) await test('server admin guard rejects missing/ordinary admin identity',async()=>{
    for(const f of manifest.functions.filter(f=>f.anon&&f.signature.startsWith('admin_'))) {
      const params=f.signature.slice(f.signature.indexOf('(')+1,-1).split(',').filter(Boolean).map(t=>'NULL::'+t).join(',');
      const call=`SELECT public.${f.signature.split('(')[0]}(${params})`;
      await denied(()=>actor(()=>db.query(call)),actor===anon?'42501':'KS460');
    }
  });
  await test('user_metadata cannot elevate administration; suspended admin denied',async()=>{
    await denied(()=>user(()=>db.query('SELECT public.admin_list_app_fee_rules()'),uid,{user_metadata:{is_power_user:true}}),'KS460');
    await denied(()=>user(()=>db.query('SELECT public.admin_list_app_fee_rules()'),uid,{app_metadata:{is_power_user:true,is_suspended:true}}),'KS460');
  });
  await test('admin list and audited pruning work through server guard',async()=>{
    await admin(()=>db.query('SELECT * FROM public.admin_list_app_fee_rules()'));
    await admin(async()=>{
      const result=(await db.query('SELECT public.admin_prune_database_logs(14,90) value')).rows[0].value;
      assert.equal(result.alerts_pruned,1); assert.equal(result.cron_runs_pruned,1);
      // Inspect as the fixture owner; admins cannot read this table directly.
      await db.exec('RESET ROLE');
      assert.equal(await value('SELECT count(*)::int value FROM public.admin_audit_log'),1);
    });
    assert.equal(await value('SELECT count(*)::int value FROM public.system_alerts'),1,'pruning test rolls back');
  });
  await test('postgres cron health/pruning and service reaper execute real bodies',async()=>{
    await db.exec('BEGIN');
    try {
      await db.query('SELECT public.check_scheduled_jobs_health()');
      const p=(await db.query('SELECT public.prune_database_logs(14,90) value')).rows[0].value;
      assert.equal(p.cron_runs_pruned,1);assert.equal(p.alerts_pruned,1);
    } finally {await db.exec('ROLLBACK');}
    await service(()=>db.query('SELECT * FROM public.reap_stuck_executions(10,3)'));
  });
  await test('admin pruning validation and audit failure roll back deletion',async()=>{
    await denied(()=>admin(()=>db.query('SELECT public.admin_prune_database_logs(1,90)')),'P0001');
    await db.exec("ALTER TABLE public.admin_audit_log ADD CONSTRAINT fixture_audit_failure CHECK (action <> 'prune_database_logs')");
    try {
      await denied(()=>admin(()=>db.query('SELECT public.admin_prune_database_logs(14,90)')),'23514');
      assert.equal(await value('SELECT count(*)::int value FROM public.system_alerts'),1);
      assert.equal(await value('SELECT count(*)::int value FROM cron.job_run_details'),1);
    } finally {await db.exec('ALTER TABLE public.admin_audit_log DROP CONSTRAINT fixture_audit_failure');}
  });
  await test('verification quote denies anonymous identity substitution and foreign line',async()=>{
    await denied(()=>anon(()=>db.query('SELECT public.quote_line_verification($1,$2)',[line,uid])));
    await denied(()=>user(()=>db.query('SELECT public.quote_line_verification($1,$2)',[otherLine,foreign])),'KS403');
    await user(async()=>assert.equal((await db.query('SELECT public.quote_line_verification($1,null) value',[line])).rows[0].value.sim_line_id,line));
    await service(async()=>assert.equal((await db.query('SELECT public.quote_line_verification($1,$2) value',[line,uid])).rows[0].value.sim_line_id,line));
  });
  await test('provider-backed verification settlement works only through service',async()=>{
    const attempt='30000000-0000-4000-8000-000000000001';
    await db.query(`INSERT INTO public.line_verification_attempts(id,sim_line_id,user_id,status,funding_kind,method)
      VALUES ($1,$2,$3,'pending','no_charge','sms')`,[attempt,line,uid]);
    await service(async()=>{
      await db.query("SELECT public.settle_line_verification_attempt($1,'succeeded',null,null)",[attempt]);
      assert.equal(await value('SELECT outcome value FROM public.line_verification_attempts WHERE id=$1',[attempt]),'succeeded');
      assert.equal(await value('SELECT verification_status value FROM public.sim_lines WHERE id=$1',[line]),'verified');
      await db.query("SELECT public.settle_line_verification_attempt($1,'succeeded',null,null)",[attempt]);
      assert.equal(await value('SELECT count(*)::int value FROM public.line_activity_log'),1);
    });
  });
  for(const fn of ['get_active_return_trip_for_line','get_return_trip_history_for_line','get_return_trip_packages_for_line']) {
    await test(fn+' enforces own identity and line before reads',async()=>{
      await denied(()=>anon(()=>db.query(`SELECT * FROM public.${fn}($1,$2)`,[line,uid])));
      await denied(()=>user(()=>db.query(`SELECT * FROM public.${fn}($1,$2)`,[otherLine,foreign])));
      await denied(()=>user(()=>db.query(`SELECT * FROM public.${fn}($1,$2)`,[otherLine,uid])));
      if(fn!=='get_return_trip_packages_for_line') {
        const own=await user(()=>db.query(`SELECT * FROM public.${fn}($1)`,[line]));assert.equal(own.rows.length,1);
        const other=await service(()=>db.query(`SELECT * FROM public.${fn}($1,$2)`,[otherLine,foreign]));assert.equal(other.rows.length,1);
      } else {
        assert.equal((await user(()=>db.query(`SELECT * FROM public.${fn}($1)`,[line]))).rows.length,1);
        assert.equal((await service(()=>db.query(`SELECT * FROM public.${fn}($1,$2)`,[otherLine,foreign]))).rows.length,1);
      }
    });
  }
  for(const [fn,args] of [['get_user_calling_rates',[foreign]],['get_call_rate_for_number',['+15555555555',foreign]]]) {
    await test(fn+' denies alternate account and missing identity',async()=>{
      const sql=`SELECT * FROM public.${fn}(${args.map((_,i)=>'$'+(i+1)).join(',')})`;
      await denied(()=>user(()=>db.query(sql,args)));
      await denied(()=>anon(()=>db.query(sql,args)));
      await denied(()=>role('authenticated',{role:'authenticated'},()=>db.query(sql,args)));
      const own=args.map(arg=>arg===foreign?uid:arg);
      assert.equal((await user(()=>db.query(sql,own))).rows.length,1);
      assert.equal((await service(()=>db.query(sql,args))).rows.length,1);
    });
  }
  await test('temporary relations cannot shadow privileged public relations',async()=>{
    await db.exec('BEGIN');
    try {
      await db.exec('CREATE TEMP TABLE return_trips(id integer); INSERT INTO pg_temp.return_trips VALUES (1),(2),(3)');
      assert.equal(Number(await value('SELECT public.fixture_unqualified_count() value')),2);
    } finally {await db.exec('ROLLBACK');}
    await denied(()=>user(()=>db.exec('CREATE TABLE public.client_shadow(id integer)')));
  });
  await test('revoked trigger EXECUTE preserves client inserts and anonymous RLS predicates',async()=>{
    await db.exec('CREATE TRIGGER fixture_tier_defaults BEFORE INSERT ON public.sim_lines FOR EACH ROW EXECUTE FUNCTION public.format_sim_line_tier_defaults()');
    await user(async()=>{
      const row=(await db.query("INSERT INTO public.sim_lines(id,user_id,plan_type,protection_tier) VALUES (gen_random_uuid(),$1,'free','premium') RETURNING protection_tier",[uid])).rows[0];
      assert.equal(row.protection_tier,'basic');
    });
    await anon(async()=>{
      assert.equal(await value('SELECT public.is_power_user(null::uuid) value'),false);
      assert.equal(await value('SELECT public.is_user_suspended() value'),false);
    });
  });
  await test('future objects deny client access for both owners and both default scopes',async()=>{
    for(const owner of ['postgres','supabase_admin']) {
      await db.exec(`SET ROLE ${owner}; CREATE TABLE public.future_${owner}(id bigint); CREATE SEQUENCE public.future_${owner}_seq;
        CREATE FUNCTION public.future_${owner}() RETURNS int LANGUAGE sql AS $$ SELECT 1 $$; RESET ROLE;`);
      for(const r of ['anon','authenticated']) {
        assert.equal(await value(`SELECT has_table_privilege('${r}','public.future_${owner}','SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') value`),false);
        assert.equal(await value(`SELECT has_sequence_privilege('${r}','public.future_${owner}_seq','USAGE,SELECT,UPDATE') value`),false);
        assert.equal(await value(`SELECT has_function_privilege('${r}','public.future_${owner}()','EXECUTE') value`),false);
      }
    }
  });
  await test('body preflight refuses a different newer implementation before changes',async()=>{
    const source=read('supabase/tests/fixtures/privileged_database_access_functions.sql');
    const start=source.indexOf('CREATE OR REPLACE FUNCTION public.admin_prune_database_logs(');
    const end=source.indexOf('$function$;',source.indexOf('AS $function$',start))+12;
    await db.exec(source.slice(start,end).replace("'prune_database_logs',","'fixture-newer-version',"));
    await denied(()=>db.exec(migration),'55000');
    await db.exec('ROLLBACK');
  });
  console.log(`${count} privilege/security tests passed`);
} catch(error) {
  console.error('FAIL',error.message,error.code||'',error.where||'');
  process.exitCode=1;
} finally { await db.close(); }
