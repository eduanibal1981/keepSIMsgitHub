import assert from 'node:assert/strict';
import fs from 'node:fs';
import {PGlite} from '@electric-sql/pglite';
const read=p=>fs.readFileSync(new URL('../../'+p,import.meta.url),'utf8');
const db=new PGlite();const dump=read('supabase/baselines/development-20261019/public.sql');
const q=async(sql,params=[]) => (await db.query(sql,params)).rows;
const scalar=async(sql,params=[]) => (await q(sql,params))[0]?.v;
const rpc=(name,params=[])=>scalar('select public.'+name+'('+params.map((_,i)=>'$'+(i+1)).join(',')+') v',params);
const owner='10000000-0000-4000-8000-000000000001',other='10000000-0000-4000-8000-000000000002';
const profile={supplier_profile_ref:'FIXTURE_PROFILE_A',provider_order_ref:'FIXTURE_ORDER_A',issuance_proven:true,
 iccid:'8900000000000000001',lpa_string:'LPA:1$fixture.invalid$fixture-matching',smdp_address:'fixture.invalid',matching_id:'fixture-matching',profile_state:'issued',installation_state:'released',bundle_state:'not_started',provider_state:{esimStatus:'GOT_RESOURCE',smdpStatus:'RELEASED'},activation_trigger:'first_network_connection'};
let passed=0;
const test=async(name,fn)=>{await db.exec('BEGIN');try{await fn();console.log('PASS '+name);passed++;}catch(error){console.error('FAIL '+name);throw error;}finally{await db.exec('ROLLBACK');}};
const reject=async(fn,pattern)=>{await db.exec('SAVEPOINT negative');try{await assert.rejects(fn,pattern);}finally{await db.exec('ROLLBACK TO SAVEPOINT negative; RELEASE SAVEPOINT negative');}};
const order=async(user=owner,quantity=1)=>{
 await db.exec("UPDATE esim_private.accounts SET new_sales_enabled=true WHERE account_key='primary'");
 return scalar("insert into public.esim_orders(user_id,provider,bundle_name,quantity,wholesale_price_usd,retail_price_usd,markup_percent,status) values($1,'esimaccess','FIXTURE', $2,1,1.4,40,'pending') returning id v",[user,quantity]);
};
const claim=()=>rpc('service_esim_claim_order');
const bind=async(job,ref='FIXTURE_ORDER_A')=>{
 await rpc('service_esim_mark_submitted',[job.order_id,job.lease]);
 await rpc('service_esim_order_checkpoint',[job.order_id,job.lease,ref,null]);
 await q("update esim_private.order_runs set next_check_at=now()-interval '1 second' where order_id=$1",[job.order_id]);
 return claim();
};
try{
 await db.exec(`CREATE ROLE anon;CREATE ROLE authenticated;CREATE ROLE service_role BYPASSRLS;
 CREATE SCHEMA auth;GRANT USAGE ON SCHEMA auth,public TO anon,authenticated,service_role;
 CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
 CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS $$select coalesce(nullif(current_setting('request.jwt.claim.role',true),''),nullif(current_setting('role',true),'none'))$$;
 CREATE TABLE public.fixture_admin_audit(action text,target text);
 CREATE FUNCTION public.admin_log(text,text,text,jsonb,jsonb,text) RETURNS void LANGUAGE sql AS $$INSERT INTO public.fixture_admin_audit VALUES($1,$3)$$;
 CREATE FUNCTION public.assert_admin() RETURNS void LANGUAGE plpgsql AS $$BEGIN
 IF coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb#>>'{app_metadata,is_power_user}' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Admin access required' USING ERRCODE='KS460';END IF;END$$;
 `);
 for(const table of ['esim_orders','user_esims','system_configs']){
  const at=dump.indexOf('CREATE TABLE public.'+table+' (');assert.notEqual(at,-1);
  await db.exec(dump.slice(at,dump.indexOf('\n);',at)+4));
 }
 await db.exec(`ALTER TABLE public.esim_orders ADD PRIMARY KEY(id);ALTER TABLE public.esim_orders ADD COLUMN catalogue_snapshot jsonb;
 ALTER TABLE public.user_esims ADD PRIMARY KEY(id);ALTER TABLE public.user_esims ADD UNIQUE(iccid);
 ALTER TABLE public.system_configs ADD PRIMARY KEY(config_key);
 ALTER TABLE public.user_esims ENABLE ROW LEVEL SECURITY;ALTER TABLE public.esim_orders ENABLE ROW LEVEL SECURITY;
 CREATE POLICY owner_read ON public.user_esims FOR SELECT TO authenticated USING(user_id=auth.uid());
 CREATE POLICY owner_read ON public.esim_orders FOR SELECT TO authenticated USING(user_id=auth.uid());
 GRANT SELECT ON public.esim_orders,public.user_esims TO anon,authenticated;
 SELECT set_config('request.jwt.claim.role','service_role',false);`);
 await db.exec(read('supabase/migrations/20261027235408_esim_profile_identity_lifecycle.sql'));
 await db.exec(read('supabase/migrations/20261027235409_esim_event_inbox_reconciliation.sql'));
 console.log('PASS both forward migrations compile over the deployed table shapes');passed++;
 const makeProfile=async(user=owner)=>{await order(user);const job=await bind(await claim());await rpc('service_esim_save_issuance',[job.order_id,job.lease,'FIXTURE_ORDER_A',[profile],null]);return scalar('select id v from public.user_esims limit 1');};
 const dueProfile=async()=>{await db.exec("update esim_private.profile_work set next_check_at=now()-interval '1 second'");return rpc('service_esim_claim_profile');};
 const observation={...profile,profile_state:'active',bundle_state:'active',installation_state:'enabled',data_total_bytes:1073741824,data_used_bytes:268435456,data_remaining_bytes:805306368,usage_observed_at:'2026-01-02T00:00:00Z'};
 await test('sales gate refuses inserts before any financial work',async()=>{
  await reject(async()=>q("insert into public.esim_orders(user_id,provider,bundle_name,quantity,wholesale_price_usd,retail_price_usd,markup_percent,status) values($1,'esimaccess','FIXTURE',1,1,1.4,40,'pending')",[owner]),/temporarily unavailable/);
  assert.equal(await scalar('select count(*)::int v from public.esim_orders'),0);
 });
 await test('submission marker is durable and never authorizes a second POST',async()=>{
  await order();const job=await claim();assert.equal(job.state,'prepared');
  assert.equal(await rpc('service_esim_mark_submitted',[job.order_id,job.lease]),true);
  assert.equal(await rpc('service_esim_mark_submitted',[job.order_id,job.lease]),false);
  await db.exec("update esim_private.order_runs set lease_until=now()-interval '1 second'");
  const recovered=await claim();assert.equal(recovered.state,'submitted');assert.notEqual(recovered.lease,job.lease);
 });
 await test('null lease tokens cannot authorize submission, issuance or observations',async()=>{
  await order();const job=await claim();
  assert.equal(await rpc('service_esim_mark_submitted',[job.order_id,null]),false);
  await reject(async()=>rpc('service_esim_save_issuance',[job.order_id,null,'FIXTURE_ORDER_A',[profile],job.submission_ref]),/Expired order lease/);
 });
 await test('missing/partial issuance cannot complete or manufacture a profile',async()=>{
  await order(owner,2);let job=await bind(await claim());
  let result=await rpc('service_esim_save_issuance',[job.order_id,job.lease,'FIXTURE_ORDER_A',[],null]);assert.equal(result.completed,false);
  assert.equal(await scalar('select count(*)::int v from public.user_esims'),0);
  await db.exec("update esim_private.order_runs set next_check_at=now()-interval '1 second'");job=await claim();
  result=await rpc('service_esim_save_issuance',[job.order_id,job.lease,'FIXTURE_ORDER_A',[profile],null]);assert.equal(result.profiles,1);assert.equal(result.completed,false);
  assert.equal(await scalar('select status v from public.esim_orders'),'processing');
  await db.exec("update esim_private.order_runs set next_check_at=now()-interval '1 second'");job=await claim();
  result=await rpc('service_esim_save_issuance',[job.order_id,job.lease,'FIXTURE_ORDER_A',[profile,{...profile,supplier_profile_ref:'FIXTURE_B',iccid:'8900000000000000002'}],null]);assert.equal(result.completed,true);
 });
 await test('stable supplier reference and ICCID collisions cannot cross ownership',async()=>{
  await makeProfile();await order(other);let job=await bind(await claim(),'FIXTURE_ORDER_B');
  const conflict=await rpc('service_esim_save_issuance',[job.order_id,job.lease,'FIXTURE_ORDER_B',[{...profile,provider_order_ref:'FIXTURE_ORDER_B'}],null]);
  assert.equal(conflict.conflict,true);assert.equal(await scalar('select user_id v from public.user_esims'),owner);
  await order(other);job=await bind(await claim(),'FIXTURE_ORDER_C');
  const iccidConflict=await rpc('service_esim_save_issuance',[job.order_id,job.lease,'FIXTURE_ORDER_C',[{...profile,supplier_profile_ref:'DIFFERENT_REF',provider_order_ref:'FIXTURE_ORDER_C'}],null]);assert.equal(iccidConflict.conflict,true);
  assert.equal(await scalar('select count(*)::int v from public.user_esims'),1);
 });
 await test('unknown outcome stays protected without guessed binding or expiry release',async()=>{
  await order();const job=await claim();await rpc('service_esim_mark_submitted',[job.order_id,job.lease]);
  await rpc('service_esim_order_checkpoint',[job.order_id,job.lease,null,'ESIM_PROVIDER_UNCERTAIN']);
  const run=(await q('select state,next_check_at from esim_private.order_runs'))[0];assert.equal(run.state,'support_required');assert.equal(run.next_check_at,null);
  assert.equal(await scalar('select status v from public.esim_orders'),'processing');assert.equal(await scalar('select count(*)::int v from public.user_esims'),0);
 });
 await test('unproven callback order cannot be adopted without exact transaction binding',async()=>{
  await order();const job=await claim();await rpc('service_esim_mark_submitted',[job.order_id,job.lease]);
  await reject(async()=>rpc('service_esim_save_issuance',[job.order_id,job.lease,'UNTRUSTED_ORDER',[{...profile,provider_order_ref:'UNTRUSTED_ORDER'}],'WRONG_TRANSACTION']),/Unproven/);
 });
 await test('both byte totals and usage update while purchase is never labelled installed',async()=>{
  const id=await makeProfile();assert.equal(await scalar('select profile_state v from public.user_esims'),'issued');
  assert.equal(await scalar('select confirmed_expires_at v from public.user_esims'),null);
  let job=await dueProfile();assert.equal(await rpc('service_esim_apply_observation',[id,job.lease,observation,null]),true);
  job=await dueProfile();const next={...observation,data_total_bytes:2147483648,data_used_bytes:0,data_remaining_bytes:2147483648,usage_observed_at:'2026-01-03T00:00:00Z'};
  await rpc('service_esim_apply_observation',[id,job.lease,next,null]);
  const row=(await q('select data_total_bytes,data_used_bytes,data_remaining_bytes,data_total_mb from public.user_esims'))[0];
  assert.equal(Number(row.data_total_bytes),2147483648);assert.equal(Number(row.data_used_bytes),0);assert.equal(Number(row.data_total_mb),2048);
 });
 await test('stale observations and expired leases cannot regress state',async()=>{
  const id=await makeProfile();let job=await dueProfile();await rpc('service_esim_apply_observation',[id,job.lease,observation,null]);
  job=await dueProfile();assert.equal(await rpc('service_esim_apply_observation',[id,job.lease,{...observation,profile_state:'issued',data_remaining_bytes:0,usage_observed_at:'2026-01-01T00:00:00Z'},null]),false);
  assert.equal(await scalar('select profile_state v from public.user_esims'),'active');assert.equal(Number(await scalar('select data_remaining_bytes v from public.user_esims')),805306368);
  job=await dueProfile();await db.exec("update esim_private.profile_work set lease_until=now()-interval '1 second'");const newJob=await dueProfile();assert.notEqual(newJob.lease,job.lease);
  assert.equal(await rpc('service_esim_apply_observation',[id,job.lease,observation,null]),false);
 });
 await test('a matching profile ID cannot accept a response bound to another order',async()=>{
  const id=await makeProfile();const job=await dueProfile();
  await reject(async()=>rpc('service_esim_apply_observation',[id,job.lease,{...observation,provider_order_ref:'OTHER_ORDER'},null]),/binding mismatch/);
  assert.equal(await scalar('select profile_state v from public.user_esims'),'issued');
  assert.equal(await rpc('service_esim_apply_observation',[id,null,observation,null]),false);
 });
 await test('failed refresh retains last-known data with an error instead of zero depletion',async()=>{
  const id=await makeProfile();let job=await dueProfile();await rpc('service_esim_apply_observation',[id,job.lease,observation,null]);job=await dueProfile();
  await rpc('service_esim_apply_observation',[id,job.lease,null,'PROVIDER_UNAVAILABLE']);
  assert.equal(Number(await scalar('select data_remaining_bytes v from public.user_esims')),805306368);assert.equal(await scalar('select usage_error_code v from public.user_esims'),'PROVIDER_UNAVAILABLE');
 });
 await test('issued/depleted/suspended profiles remain eligible; terminal checks are bounded',async()=>{
  const id=await makeProfile();let job=await dueProfile();await rpc('service_esim_apply_observation',[id,job.lease,{...observation,bundle_state:'depleted',data_remaining_bytes:0},null]);assert.ok(await dueProfile());
  await db.exec('update esim_private.profile_work set lease=null,lease_until=null');
  for(let i=0;i<3;i++){job=await dueProfile();await rpc('service_esim_apply_observation',[id,job.lease,{...observation,profile_state:'expired',bundle_state:'expired'},null]);}
  assert.equal(await dueProfile(),null);
 });
 await test('owner projection and batched refresh deny cross-owner reads and throttle requests',async()=>{
  await makeProfile();await db.exec(`SELECT set_config('request.jwt.claim.role','authenticated',true);SELECT set_config('request.jwt.claim.sub','${owner}',true);SET LOCAL ROLE authenticated;`);
  assert.equal((await q('select * from public.customer_esim_profiles')).length,1);
  assert.equal((await rpc('request_esim_profile_refresh')).queued,1);assert.equal((await rpc('request_esim_profile_refresh')).queued,0);
  await reject(async()=>q('select * from esim_private.order_runs'),/permission denied/);
  await db.exec(`RESET ROLE;SELECT set_config('request.jwt.claim.sub','${other}',true);SET LOCAL ROLE authenticated;`);
  assert.equal((await q('select * from public.customer_esim_profiles')).length,0);assert.equal((await rpc('request_esim_profile_refresh')).queued,0);
  await reject(async()=>q('select wholesale_price_usd from public.esim_orders'),/permission denied/);
 });
 await test('shared supplier limiter coordinates callers in one account',async()=>{
  assert.equal((await rpc('service_esim_acquire_slot')).granted,true);assert.equal((await rpc('service_esim_acquire_slot')).granted,false);
 });
 await test('duplicate events persist once and callback hints do not settle a profile or order',async()=>{
  const id=await order();const job=await claim();await rpc('service_esim_mark_submitted',[id,job.lease]);
  const event={kind:'ORDER_STATUS',order_ref:'HINT_ONLY',submission_ref:job.submission_ref,state_hint:'GOT_RESOURCE'};
  assert.equal((await rpc('service_esim_accept_event',['primary','a'.repeat(64),event])).duplicate,false);
  assert.equal((await rpc('service_esim_accept_event',['primary','a'.repeat(64),event])).duplicate,true);
  const claimEvent=await rpc('service_esim_claim_event');await rpc('service_esim_process_event',[claimEvent.id,claimEvent.lease]);
  const run=(await q('select * from esim_private.order_runs'))[0];assert.equal(run.provider_order_ref,null);assert.equal(run.hinted_order_ref,'HINT_ONLY');assert.equal(run.state,'submitted');assert.equal(await scalar('select count(*)::int v from public.user_esims'),0);
 });
 await test('event leases recover after restart and unmatched events reach a dead letter',async()=>{
  await rpc('service_esim_accept_event',['primary','b'.repeat(64),{kind:'ESIM_STATUS',profile_ref:'UNKNOWN_REF'}]);
  const old=await rpc('service_esim_claim_event');await db.exec("update esim_private.events set lease_until=now()-interval '1 second'");const next=await rpc('service_esim_claim_event');assert.notEqual(old.lease,next.lease);
  assert.equal((await rpc('service_esim_process_event',[old.id,old.lease])).processed,false);
  await rpc('service_esim_process_event',[next.id,next.lease]);assert.equal(await scalar('select status v from esim_private.events'),'retry');
  await db.exec("update esim_private.events set attempts=7,next_attempt_at=now()-interval '1 second'");const last=await rpc('service_esim_claim_event');await rpc('service_esim_process_event',[last.id,last.lease]);assert.equal(await scalar('select status v from esim_private.events'),'dead_letter');
 });
 await test('Admin reconciliation is audited, read-only and available while new sales are gated',async()=>{
  const id=await order();await db.exec("update esim_private.accounts set new_sales_enabled=false");
  await db.exec(`SELECT set_config('request.jwt.claims','{"app_metadata":{"is_power_user":true}}',true);SET LOCAL ROLE authenticated;`);
  const result=await rpc('admin_request_esim_reconciliation',[id]);assert.equal(result.read_only,true);assert.equal(result.queued,true);
  assert.equal((await rpc('admin_esim_runtime_status')).new_sales_enabled,false);
  await db.exec('RESET ROLE');assert.equal(await scalar('select count(*)::int v from public.fixture_admin_audit'),1);
  assert.equal(await scalar('select status v from public.esim_orders'),'pending');
 });
 await test('service-only ingress and persistence RPCs cannot be invoked by clients',async()=>{
  await db.exec("SELECT set_config('request.jwt.claim.role','authenticated',true);SET LOCAL ROLE authenticated;");
  await reject(async()=>rpc('service_esim_claim_order'),/permission denied/);await reject(async()=>rpc('service_esim_acquire_slot'),/permission denied/);
  await reject(async()=>rpc('service_esim_accept_event',['primary','c'.repeat(64),{kind:'ORDER_STATUS',order_ref:'NO'}]),/permission denied/);
  await reject(async()=>rpc('admin_esim_runtime_status'),/Admin access required/);
 });
 console.log(JSON.stringify({passed,failed:0,provider_calls:0,wallet_mutations:0}));
}catch(error){console.error(JSON.stringify({code:error.code,message:error.message,where:error.where}));process.exitCode=1;}finally{await db.close();}
