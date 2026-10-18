// Task 16: isolated native PostgreSQL, no production deletion or email.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {createRequire} from 'node:module';
const {loadEdge}=createRequire(import.meta.url)('../../test/edge_module_loader.cjs');
const {default:EmbeddedPostgres}=await import(process.env.EMBEDDED_POSTGRES_MODULE_PATH
  ? pathToFileURL(process.env.EMBEDDED_POSTGRES_MODULE_PATH).href:'embedded-postgres');
const dir=await fs.mkdtemp(path.join(os.tmpdir(),'keepsims-maintenance-'));
const server=new EmbeddedPostgres({databaseDir:dir,user:'postgres',password:'isolated-test',
  port:Number(process.env.MAINTENANCE_TEST_PORT||56551),persistent:false,initdbFlags:['--locale=C'],
  postgresFlags:['-h','127.0.0.1',...(process.platform==='win32'?[]:['-k',dir])],onLog:()=>{},onError:()=>{}});
const read=p=>fs.readFile(new URL('../../'+p,import.meta.url),'utf8');
const admin='10000000-0000-4000-8000-000000000001',target='10000000-0000-4000-8000-000000000002';
const clients=[];let db,passed=0;
const query=(s,p)=>db.query(s,p),value=async(s,p)=>(await query(s,p)).rows[0].value;
async function connect(){const c=server.getPgClient();await c.connect();clients.push(c);return c;}
async function role(name,power=false,uid=admin){await query('SET LOCAL ROLE '+name);await query("SELECT set_config('request.jwt.claims',$1,true)",[JSON.stringify({role:name,sub:uid,app_metadata:{is_power_user:power}})]);}
async function scenario(name,run){await query('BEGIN');try{await run();passed++;console.log('PASS '+name);}finally{await query('ROLLBACK');}}
async function reject(sql,code,args){await query('SAVEPOINT rejected');await assert.rejects(query(sql,args),e=>e.code===code);await query('ROLLBACK TO SAVEPOINT rejected');}
async function request(){await role('authenticated',true);const r=await value('SELECT public.admin_purge_user_account($1::uuid,$1::text,$2) AS value',[target,'Synthetic deletion test']);await query('RESET ROLE');return r;}
const claim=id=>value('SELECT public.claim_account_purge_job($1) AS value',[id]);
const finish=(id,token,success,note=null)=>value('SELECT public.finish_account_purge_job($1,$2,$3,$4) AS value',[id,token,success,note]);
function integratedPurge(kind='purge'){
  const client={async rpc(name,args){
    assert.ok(['get_internal_secret','claim_account_purge_job','finish_account_purge_job','claim_admin_email','finish_admin_email'].includes(name));
    assert.ok(Object.keys(args).every(k=>/^[a-z_]+$/.test(k)));
    await query('SAVEPOINT edge_rpc');
    try{
      await role('service_role');
      const data=await value('SELECT public.'+name+'('+Object.keys(args).map((k,i)=>k+' => $'+(i+1)).join(',')+') AS value',Object.values(args));
      await query('RESET ROLE');await query('RELEASE SAVEPOINT edge_rpc');return {data,error:null};
    }catch(error){await query('ROLLBACK TO SAVEPOINT edge_rpc');await query('RELEASE SAVEPOINT edge_rpc');return {data:null,error:{code:error.code}};}
  },storage:{from(){return {async list(){return {data:[],error:null};},async remove(){throw Error('No files in this fixture');}};}},
  auth:{admin:{async deleteUser(id){assert.equal(id,target);await query('DELETE FROM auth.users WHERE id=$1',[id]);return {error:null};}}}};
  const mod=loadEdge('supabase/functions/'+(kind==='email'?'send-admin-email':'purge-accounts')+'/index.ts',{serve:()=>{},createClient:()=>client,
    env:{SUPABASE_URL:'https://project.invalid',SUPABASE_SERVICE_ROLE_KEY:'synthetic-service',RESEND_API_KEY:'synthetic-provider'},
    fetch:(url)=>{assert.equal(kind,'email');assert.equal(url,'https://api.resend.com/emails');return Response.json({id:'synthetic-provider-acceptance'});}});
  return kind==='email'?mod.handleAdminEmail:mod.handlePurgeRequest;
}
const seed=`INSERT INTO auth.users(id,email) VALUES('${admin}','admin@example.invalid'),('${target}','target@example.invalid');
INSERT INTO public.profiles(id,email) VALUES('${admin}','admin@example.invalid'),('${target}','target@example.invalid');
INSERT INTO vault.decrypted_secrets(name,decrypted_secret) VALUES('dispatch_shared_secret','synthetic-purge-secret'),('admin_email_secret','synthetic-mail-secret');`;
try{
  await server.initialise();await server.start();db=await connect();
  await query(await read('supabase/tests/fixtures/notification_scheduler_baseline.sql'));
  await query(`ALTER TABLE auth.users ADD COLUMN email text;
    CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS $$ SELECT coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb,'{}') $$;
    CREATE SCHEMA vault;CREATE TABLE vault.decrypted_secrets(name text,decrypted_secret text);
    CREATE SCHEMA cron;CREATE TABLE cron.job_run_details(runid bigint GENERATED ALWAYS AS IDENTITY,start_time timestamptz);
    CREATE SCHEMA net;CREATE TABLE net.requests(id bigint GENERATED ALWAYS AS IDENTITY,body jsonb);
    CREATE FUNCTION net.http_post(url text,body jsonb DEFAULT '{}',params jsonb DEFAULT '{}',headers jsonb DEFAULT '{}',timeout_milliseconds integer DEFAULT 1000)
      RETURNS bigint LANGUAGE sql AS $$ INSERT INTO net.requests(body) VALUES(body) RETURNING id $$;
    CREATE FUNCTION public.enforce_rate_limit(text,text) RETURNS void LANGUAGE sql AS $$ SELECT $$;`);
  await query(await read('supabase/tests/fixtures/admin_maintenance_baseline.sql'));
  await query(seed);
  await scenario('original admin pruning reproduces its missing helper',async()=>{
    await role('authenticated',true);await reject('SELECT public.admin_prune_database_logs()','42883');
  });
  await scenario('original admin purge reproduces unsupported deletion columns',async()=>{
    await role('authenticated',true);await reject('SELECT public.admin_purge_user_account($1::uuid,$1::text)','42703',[target]);
  });
  await scenario('original rate-limit threshold reproduces unsupported system-alert columns',async()=>{
    await query("INSERT INTO public.security_logs(event_type) SELECT 'rate_limited' FROM generate_series(1,20)");
    await reject('SELECT public.check_rate_limit_health()','42703');
  });
  await query('ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon,authenticated,service_role; ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO anon,authenticated,service_role');
  await query(await read('supabase/migrations/20261018030000_admin_maintenance_deletion_contract.sql'));
  await scenario('non-admin and anonymous maintenance calls fail',async()=>{
    for(const r of ['anon','authenticated']){await role(r);await reject('SELECT public.admin_prune_database_logs()',r==='anon'?'42501':'KS460');await query('RESET ROLE');}
  });
  await scenario('admin retention prunes only eligible log rows and records actor/after_value atomically',async()=>{
    await query("INSERT INTO cron.job_run_details(start_time) VALUES(now()-interval '20 days'),(now()-interval '1 day'); INSERT INTO public.system_alerts(kind,message,created_at) VALUES('test','old',now()-interval '100 days'),('test','recent',now()-interval '1 day')");
    await role('authenticated',true);const r=await value('SELECT public.admin_prune_database_logs() AS value');await query('RESET ROLE');
    assert.equal(r.cron_runs_pruned,1);assert.equal(r.alerts_pruned,1);
    const a=(await query('SELECT * FROM public.admin_audit_log')).rows[0];assert.equal(a.actor_id,admin);assert.equal(a.actor_email,'admin@example.invalid');assert.equal(a.after_value.cron_runs_pruned,1);
  });
  await scenario('retention rejects null/unsafe bounds and auditing failure rolls back pruning',async()=>{
    await role('authenticated',true);for(const sql of ['SELECT public.admin_prune_database_logs(2,90)','SELECT public.admin_prune_database_logs(14,6)','SELECT public.admin_prune_database_logs(NULL,90)'])await reject(sql,'22023');await query('RESET ROLE');
    await query("INSERT INTO cron.job_run_details(start_time) VALUES(now()-interval '100 days')");
    await query(`CREATE FUNCTION public.fixture_audit_failure() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'Synthetic failure' USING ERRCODE='23514'; END $$;
      CREATE TRIGGER fixture_audit BEFORE INSERT ON public.admin_audit_log FOR EACH ROW EXECUTE FUNCTION public.fixture_audit_failure()`);
    await role('authenticated',true);await reject('SELECT public.admin_prune_database_logs()','23514');await query('RESET ROLE');
    assert.equal(await value('SELECT count(*)::int AS value FROM cron.job_run_details'),1);
  });
  await scenario('postgres rate-health threshold, rolling hour and six-hour deduplication use real alert columns',async()=>{
    await query("INSERT INTO public.security_logs(event_type) SELECT 'rate_limited' FROM generate_series(1,19)");
    await query('SELECT public.check_rate_limit_health()');assert.equal(await value('SELECT count(*)::int AS value FROM public.system_alerts'),0);
    await query("INSERT INTO public.security_logs(event_type) VALUES('rate_limited')");await query('SELECT public.check_rate_limit_health()');await query('SELECT public.check_rate_limit_health()');
    assert.equal(await value('SELECT count(*)::int AS value FROM public.system_alerts'),1);
    await query("UPDATE public.system_alerts SET created_at=now()-interval '6 hours 1 second'");await query('SELECT public.check_rate_limit_health()');assert.equal(await value('SELECT count(*)::int AS value FROM public.system_alerts'),2);
  });
  await scenario('admin request supplies required fields and returns queued without claiming deletion',async()=>{
    const r=await request();assert.equal(r.status,'queued');assert.equal(await value('SELECT count(*)::int AS value FROM auth.users'),2);
    const d=(await query('SELECT * FROM public.account_deletions')).rows[0];assert.equal(d.status,'frozen');assert.equal(d.actor_id,admin);assert.ok(d.email_hash);assert.ok(d.scheduled_purge_at);assert.equal(d.purged_at,null);assert.equal(d.auth_deleted_at,null);
    assert.equal((await request()).job_id,r.job_id);assert.equal(await value('SELECT count(*)::int AS value FROM public.account_purge_jobs'),1);
  });
  await scenario('admin challenge rejects mismatched ID, unrelated callers and self deletion',async()=>{
    await role('authenticated');await reject('SELECT public.admin_purge_user_account($1::uuid,$1::text)','KS460',[target]);
    await role('authenticated',true);await reject("SELECT public.admin_purge_user_account($1,'incorrect')",'KS400',[target]);await reject('SELECT public.admin_purge_user_account($1::uuid,$1::text)','KS400',[admin]);
  });
  await scenario('dispatch errors persist failed requests/audit and never mark purged',async()=>{
    await query("DELETE FROM vault.decrypted_secrets WHERE name='dispatch_shared_secret'");const r=await request();assert.equal(r.success,false);assert.equal(r.status,'failed');
    assert.equal(await value("SELECT count(*)::int AS value FROM public.admin_audit_log WHERE action='user.purge_failed'"),1);
    assert.equal(await value('SELECT purged_at AS value FROM public.account_deletions'),null);
  });
  await scenario('claim requires a persisted due request and serializes active processors',async()=>{
    const r=await request();const c=await claim(r.job_id);assert.equal(c.claimed,true);assert.equal((await claim(r.job_id)).state,'busy');
    await reject('SELECT public.finish_account_purge_job($1,$2,true)','55000',[r.job_id,c.claim_token]);
    assert.equal(await value('SELECT status AS value FROM public.account_deletions'),'drained');
    assert.equal(await value("SELECT count(*)::int AS value FROM public.admin_audit_log WHERE action='user.purge_completed'"),0);
  });
  await scenario('completion follows Auth absence and preserves authorized actor; duplicate completion audits once',async()=>{
    const r=await request();const c=await claim(r.job_id);await query('DELETE FROM auth.users WHERE id=$1',[target]);
    assert.equal(await finish(r.job_id,c.claim_token,true),true);assert.equal(await finish(r.job_id,c.claim_token,true),true);
    assert.equal(await value('SELECT status AS value FROM public.account_deletions'),'auth_deleted');
    const a=(await query("SELECT * FROM public.admin_audit_log WHERE action='user.purge_completed'")).rows;assert.equal(a.length,1);assert.equal(a[0].actor_id,admin);assert.equal(a[0].after_value.authorized_actor_id,admin);
  });
  await scenario('failed deletion persists failure with no completion and permits fenced idempotent retry',async()=>{
    const r=await request();const c=await claim(r.job_id);await finish(r.job_id,c.claim_token,false,'storage_failed');
    assert.equal(await value('SELECT state AS value FROM public.account_purge_jobs'),'failed');assert.equal(await value('SELECT purged_at AS value FROM public.account_deletions'),null);
    const retry=await claim(r.job_id);assert.notEqual(retry.claim_token,c.claim_token);assert.equal(await finish(r.job_id,c.claim_token,true),false);
  });
  await scenario('completed deletion and success audit roll back together on audit failure',async()=>{
    const r=await request();const c=await claim(r.job_id);await query('DELETE FROM auth.users WHERE id=$1',[target]);
    await query(`CREATE FUNCTION public.fixture_audit_failure() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'failure' USING ERRCODE='23514'; END $$;
      CREATE TRIGGER fixture_audit BEFORE INSERT ON public.admin_audit_log FOR EACH ROW EXECUTE FUNCTION public.fixture_audit_failure()`);
    await reject('SELECT public.finish_account_purge_job($1,$2,true)','23514',[r.job_id,c.claim_token]);assert.equal(await value('SELECT state AS value FROM public.account_purge_jobs'),'processing');
  });
  await scenario('nonzero funds and retained financial evidence stop before irreversible work',async()=>{
    await query('INSERT INTO public.wallets(user_id,balance) VALUES($1,5)',[target]);const r=await request();assert.equal((await claim(r.job_id)).state,'review_required');
    assert.equal(await value('SELECT count(*)::int AS value FROM auth.users WHERE id=$1',[target]),1);
    assert.equal(await value('SELECT balance::int AS value FROM public.wallets WHERE user_id=$1',[target]),5);
  });
  await scenario('zero-balance funding history and provider numbers still require retention/reconciliation review',async()=>{
    const wallet=await value('INSERT INTO public.wallets(user_id,balance) VALUES($1,0) RETURNING id AS value',[target]);
    await query("INSERT INTO public.wallet_funding_lots(wallet_id,user_id,origin_type,funded_amount,remaining_amount) VALUES($1,$2,'paypal_deposit',5,0)",[wallet,target]);
    const r=await request();assert.equal((await claim(r.job_id)).state,'review_required');
    await query('DELETE FROM public.wallet_funding_lots');
    await query("INSERT INTO public.virtual_did_numbers(user_id,phone_number,country_code,country_name) VALUES($1,'+0000000000','ZZ','Synthetic')",[target]);
    assert.equal((await claim(r.job_id)).state,'review_required');assert.equal(await value('SELECT count(*)::int AS value FROM public.virtual_did_numbers'),1);
  });
  await scenario('scheduled purge respects grace and queues work without claiming completion',async()=>{
    await query("INSERT INTO public.account_deletions(user_id,email_hash,scheduled_purge_at,actor_id) VALUES($1,'synthetic',now()+interval '1 day',$1)",[target]);
    assert.equal((await value('SELECT public.purge_deleted_accounts() AS value')).queued_count,0);
    await query("UPDATE public.account_deletions SET scheduled_purge_at=now()-interval '1 second'");const result=await value('SELECT public.purge_deleted_accounts() AS value');assert.equal(result.queued_count,1);assert.equal(result.purged_count,0);
  });
  await scenario('cancelled requests cannot be claimed and customer cancellation is serialized before due time',async()=>{
    await query("INSERT INTO public.account_deletions(user_id,email_hash,scheduled_purge_at,actor_id) VALUES($1,'synthetic',now()+interval '1 day',$1)",[target]);
    await role('authenticated',false,target);assert.equal((await value('SELECT public.cancel_account_deletion() AS value')).success,true);await query('RESET ROLE');
    assert.equal((await value('SELECT public.purge_deleted_accounts() AS value')).queued_count,0);
    const r=await request();await query("UPDATE public.account_deletions SET status='cancelled'");assert.equal((await claim(r.job_id)).state,'not_eligible');
  });
  await scenario('expired worker leases can be reclaimed after a crash and reject stale completion tokens',async()=>{
    const r=await request(),first=await claim(r.job_id);
    await query("UPDATE public.account_purge_jobs SET lease_until=now()-interval '1 second',dispatched_at=now()-interval '2 hours'");
    assert.equal((await value('SELECT public.purge_deleted_accounts() AS value')).queued_count,1);
    const retry=await claim(r.job_id);assert.equal(retry.claimed,true);assert.notEqual(first.claim_token,retry.claim_token);
    assert.equal(await finish(r.job_id,first.claim_token,true),false);
    await reject('SELECT public.finish_account_purge_job($1,$2,NULL)','22023',[r.job_id,retry.claim_token]);
    await reject('SELECT public.finish_account_purge_job($1,$2,false,NULL)','22023',[r.job_id,retry.claim_token]);
  });
  await scenario('scheduled self-deletion retains the authorized actor snapshot after the actor Auth row is gone',async()=>{
    await query("INSERT INTO public.account_deletions(user_id,email_hash,scheduled_purge_at,actor_id) VALUES($1,'synthetic',now()-interval '1 day',$1)",[target]);
    await query('SELECT public.purge_deleted_accounts()');const id=await value('SELECT id AS value FROM public.account_purge_jobs'),c=await claim(id);
    await query('DELETE FROM auth.users WHERE id=$1',[target]);await finish(id,c.claim_token,true);
    const a=(await query("SELECT * FROM public.admin_audit_log WHERE action='user.purge_completed'")).rows[0];
    assert.equal(a.actor_id,null);assert.equal(a.actor_email,'target@example.invalid');assert.equal(a.after_value.authorized_actor_id,target);
  });
  await scenario('clients cannot forge job/table state, invoke purge workers, or use the retired SQL Auth fallback',async()=>{
    for(const r of ['anon','authenticated','service_role']){
      await role(r);
      await reject('SELECT * FROM public.account_purge_jobs','42501');
      await reject('SELECT public.delete_auth_user_by_id($1)','42501',[target]);
      if(r!=='service_role'){
        await reject('SELECT public.claim_account_purge_job($1)','42501',[target]);
        await reject("UPDATE public.account_deletions SET status='auth_deleted'",'42501');
      }
      await query('RESET ROLE');
    }
  });
  await scenario('actual service role claims/finishes jobs while customer forged service claims are rejected',async()=>{
    const r=await request();await role('service_role');assert.equal((await claim(r.job_id)).claimed,true);await query('RESET ROLE');
    await query('GRANT EXECUTE ON FUNCTION public.claim_account_purge_job(uuid) TO authenticated');await role('authenticated');
    await query("SELECT set_config('request.jwt.claims','{\"role\":\"service_role\"}',true)");await reject('SELECT public.claim_account_purge_job($1)','42501',[r.job_id]);
  });
  await scenario('email dispatch preserves admin request validation and sends only the persisted email ID to pg_net',async()=>{
    await query("INSERT INTO public.system_configs(config_key,config_value) VALUES('ADMIN_EMAIL_ENABLED','true'),('ADMIN_EMAIL_FROM','admin@example.invalid'),('ADMIN_EMAIL_FROM_OPTIONS','admin@example.invalid')");
    await role('authenticated',true);const r=await value("SELECT public.admin_send_email(ARRAY['recipient@example.invalid'],'Synthetic','Body') AS value");await query('RESET ROLE');assert.equal(r.status,'queued');
    assert.deepEqual(await value('SELECT body AS value FROM net.requests ORDER BY id DESC LIMIT 1'),{email_id:r.email_id});
  });
  await scenario('email claim/outcome are fenced and ambiguous failure is never automatically resent',async()=>{
    const id=await value("INSERT INTO public.admin_emails(from_address,to_addresses,subject,body_text) VALUES('from@example.invalid',ARRAY['to@example.invalid'],'Synthetic','Body') RETURNING id AS value");
    await role('service_role');const c=await value('SELECT public.claim_admin_email($1) AS value',[id]);assert.equal(c.claimed,true);
    assert.equal((await value('SELECT public.claim_admin_email($1) AS value',[id])).claimed,false);
    assert.equal(await value("SELECT public.finish_admin_email($1,$2,false,NULL,'provider_outcome_unknown') AS value",[id,c.claim_token]),true);
    assert.equal((await value('SELECT public.claim_admin_email($1) AS value',[id])).claimed,false);
  });
  await scenario('read-only catalog assertions confirm private jobs and exact function/column grants',async()=>{
    assert.deepEqual((await query(await read('supabase/tests/admin_maintenance_contract_tests.sql'))).rows,[]);
  });
  await scenario('actual Edge handler uses exact named SQL RPCs and completes only after isolated Auth removal/audit',async()=>{
    const r=await request(),handle=integratedPurge();
    const response=await handle(new Request('https://project.invalid/purge',{method:'POST',headers:{'x-keep-sims-secret':'synthetic-purge-secret'},body:JSON.stringify({job_id:r.job_id})}));
    assert.equal(response.status,200);assert.equal((await response.json()).status,'completed');
    assert.equal(await value('SELECT count(*)::int AS value FROM auth.users WHERE id=$1',[target]),0);
    assert.equal(await value("SELECT count(*)::int AS value FROM public.admin_audit_log WHERE action='user.purge_completed' AND actor_id=$1",[admin]),1);
  });
  await scenario('actual Edge/SQL completion audit failure returns error with recoverable processing state after Auth is gone',async()=>{
    const r=await request();
    await query(`CREATE FUNCTION public.fixture_completion_audit_failure() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
      IF NEW.action IN ('user.purge_completed','user.purge_failed') THEN RAISE EXCEPTION 'Synthetic audit outage' USING ERRCODE='23514'; END IF; RETURN NEW; END $$;
      CREATE TRIGGER fixture_audit BEFORE INSERT ON public.admin_audit_log FOR EACH ROW EXECUTE FUNCTION public.fixture_completion_audit_failure()`);
    const response=await integratedPurge()(new Request('https://project.invalid/purge',{method:'POST',headers:{'x-keep-sims-secret':'synthetic-purge-secret'},body:JSON.stringify({job_id:r.job_id})}));
    assert.equal(response.status,503);assert.equal(await value('SELECT state AS value FROM public.account_purge_jobs'),'processing');
    assert.equal(await value('SELECT count(*)::int AS value FROM auth.users WHERE id=$1',[target]),0);
    assert.equal(await value("SELECT count(*)::int AS value FROM public.admin_audit_log WHERE action='user.purge_completed'"),0);
  });
  await scenario('actual replacement email handler claims and records a synthetic provider acceptance through exact named SQL RPCs',async()=>{
    const id=await value("INSERT INTO public.admin_emails(created_by,from_address,to_addresses,subject,body_text) VALUES($1,'from@example.invalid',ARRAY['to@example.invalid'],'Synthetic','Body') RETURNING id AS value",[admin]);
    const response=await integratedPurge('email')(new Request('https://project.invalid/email',{method:'POST',headers:{'x-sync-secret':'synthetic-mail-secret'},body:JSON.stringify({email_id:id})}));
    assert.equal(response.status,200);assert.equal((await response.json()).status,'accepted_by_provider');
    assert.equal(await value('SELECT provider_message_id AS value FROM public.admin_emails'),'synthetic-provider-acceptance');
  });
  await db.query('BEGIN');await request();await db.query('COMMIT');
  const job=await value('SELECT id AS value FROM public.account_purge_jobs');const a=await connect(),b=await connect();
  const claims=await Promise.all([a.query('SELECT public.claim_account_purge_job($1) AS value',[job]),b.query('SELECT public.claim_account_purge_job($1) AS value',[job])]);
  assert.deepEqual(claims.map(r=>r.rows[0].value.claimed).sort(),[false,true]);passed++;console.log('PASS independent concurrent sessions admit one purge processor');
  console.log(`${passed} admin maintenance/deletion SQL scenarios passed`);
}finally{await Promise.allSettled(clients.map(c=>c.end()));await server.stop();await fs.rm(dir,{recursive:true,force:true});}
