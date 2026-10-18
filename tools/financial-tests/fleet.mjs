import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {bootstrap} from './bootstrap.mjs';
import migrationSource from '../migration-source.cjs';
import {runSQLCases} from './sql-cases.mjs';
const read=p=>fs.readFileSync(new URL('../../'+p,import.meta.url),'utf8');
const manifest=JSON.parse(fs.readFileSync(new URL('../../../backend-sync-wt/worker-fleet.json',import.meta.url),'utf8'));
const results=[];let db,server,owner,directory;
const scalar=async(sql,args=[])=>(await db.query(sql,args)).rows[0].v;
const snapshot=()=>scalar('SELECT public.worker_fleet_snapshot() v');
const component=async key=>(await snapshot()).components.find(c=>c.key===key);
const uuid=()=>crypto.randomUUID();
async function scenario(name,run){await db.exec('BEGIN');try{await run();results.push({name,status:'passed'});console.log('PASS '+name);}catch(e){results.push({name,status:'failed',code:e.code,message:e.message});console.error('FAIL '+name+': '+e.message+' '+(e.where||''));}finally{await db.exec('ROLLBACK');}}
async function denied(sql,code='42501'){await db.exec('SAVEPOINT denial');await assert.rejects(db.query(sql),e=>e.code===code);await db.exec('ROLLBACK TO SAVEPOINT denial');}
const version='a'.repeat(64);
const payload=p=>Object.fromEntries(Object.keys(p.lanes).map(k=>[k,{phase:'idle',completed:1,failed:0,running_seconds:0}]));
const report=(p,lanes=payload(p),sequence=1,instance=uuid(),started=new Date(Date.now()-60000).toISOString())=>scalar('SELECT public.report_worker_health($1,$2,$3,$4,$5,$6) v',[p.name,instance,started,sequence,version,lanes]);
const seed=`INSERT INTO auth.users(id,email) VALUES('10000000-0000-4000-8000-000000000001','fixture@example.invalid');
INSERT INTO public.profiles(id,email) VALUES('10000000-0000-4000-8000-000000000001','fixture@example.invalid');
INSERT INTO public.countries(id,name,iso_code,dialing_code,currency_code) VALUES('30000000-0000-4000-8000-000000000001','Fixture','ZZ','000','USD');
INSERT INTO public.carriers(id,name,country_id) VALUES('40000000-0000-4000-8000-000000000001','Fixture','30000000-0000-4000-8000-000000000001');
INSERT INTO public.sim_lines(id,user_id,phone_number,carrier_id) VALUES('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','+15550000001','40000000-0000-4000-8000-000000000001');`;
try{
 if(process.env.FLEET_NATIVE==='1'){
  const {default:EmbeddedPostgres}=await import(process.env.EMBEDDED_POSTGRES_MODULE_PATH?pathToFileURL(process.env.EMBEDDED_POSTGRES_MODULE_PATH).href:'embedded-postgres');
  directory=fs.mkdtempSync(path.join(os.tmpdir(),'keepsims-fleet-'));
  server=new EmbeddedPostgres({databaseDir:directory,user:'postgres',password:'isolated',port:Number(process.env.FLEET_TEST_PORT||56560),persistent:false,initdbFlags:['--locale=C'],postgresFlags:['-h','127.0.0.1','-k',directory],onLog:()=>{},onError:()=>{}});
  await server.initialise();await server.start();owner=server.getPgClient();await owner.connect();db={exec:s=>owner.query(s),query:(s,p)=>owner.query(s,p)};
 }else{const {PGlite}=await import(process.env.PGLITE_MODULE_PATH?pathToFileURL(process.env.PGLITE_MODULE_PATH).href:'@electric-sql/pglite');db=new PGlite();}
 await bootstrap(db);
 await db.exec(read('supabase/tests/fixtures/pricing_contract_baseline.sql'));
 await db.exec(read('supabase/tests/fixtures/offline_voucher_baseline.sql'));
 await db.exec(read('supabase/tests/fixtures/worker_fleet_baseline.sql'));
 const legacy=migrationSource('20260921020000_virtual_did_numbers.sql');await db.exec(legacy.slice(0,legacy.indexOf('-- 2. Security-Definer')));
 const did=read('supabase/migrations/20261017024520_second_number_inbox_and_lifecycle.sql');await db.exec(did.slice(0,did.indexOf('CREATE FUNCTION public.admin_set_second_number_policy'))+'COMMIT;');
 await db.exec(`CREATE SCHEMA cron; CREATE TABLE cron.job(jobid bigint PRIMARY KEY,jobname text UNIQUE,active boolean);
 CREATE TABLE cron.job_run_details(runid bigint GENERATED ALWAYS AS IDENTITY,jobid bigint,status text,start_time timestamptz,end_time timestamptz);`);
 await db.exec(read('supabase/migrations/20261018090000_worker_fleet_monitoring.sql'));
 await db.exec(seed);
 await db.exec("INSERT INTO public.service_providers(code,name) VALUES('ding','Fixture')");
 await db.exec("SELECT set_config('request.jwt.claims','{\"role\":\"service_role\"}',false)");
 await db.exec(`INSERT INTO cron.job SELECT row_number() OVER(),name,true FROM public.worker_fleet_cron;
 INSERT INTO cron.job_run_details(jobid,status,start_time,end_time) SELECT jobid,'succeeded',now()-interval '1 minute',now() FROM cron.job;`);
 await scenario('versioned manifest exactly matches all required SQL process and lane thresholds',async()=>{
  const rows=(await db.query('SELECT worker,stale_seconds,lanes FROM public.worker_fleet_requirements ORDER BY worker')).rows;
  assert.equal(rows.length,manifest.processes.length);
  for(const p of manifest.processes){const row=rows.find(r=>r.worker===p.name);assert.ok(row);assert.deepEqual(row.lanes,p.lanes);assert.equal(row.stale_seconds,p.stale_seconds);}
  assert.ok(!rows.some(r=>r.worker==='worker_voucher_stock'));assert.ok(rows.some(r=>r.worker==='supplier-reconciliation'));
 });
 await scenario('a green legacy eSIM heartbeat never conceals the rest of the missing fleet',async()=>{
  await db.exec("INSERT INTO public.system_configs(config_key,config_value,updated_at) VALUES('WORKER_ESIM_FULFILLMENT_HEARTBEAT','ok',now())");
  const s=await snapshot();assert.equal(s.status,'degraded');assert.equal(s.components.filter(c=>c.kind==='worker'&&c.state==='missing').length,9);
 });
 for(const p of manifest.processes)await report(p);
 await db.exec("INSERT INTO public.worker_fleet_observation(singleton,payload) SELECT true,public.worker_fleet_snapshot()");
 await scenario('all fresh successful workers, empty probes and successful cron runs yield healthy',async()=>{
  const s=await snapshot();assert.equal(s.status,'healthy',JSON.stringify(s.components.filter(c=>c.state!=='healthy')));
  await db.exec('SET ROLE service_role');assert.equal((await scalar('SELECT public.get_worker_fleet_health() v')).status,'healthy');
 });
 for(const p of manifest.processes)await scenario('stopping '+p.name+' is detected independently',async()=>{
  await db.query("UPDATE public.worker_fleet_runtime SET last_seen_at=now()-interval '181 seconds' WHERE worker=$1",[p.name]);
  assert.equal((await component('worker:'+p.name)).state,'stale');assert.equal((await snapshot()).status,'degraded');
 });
 for(const p of manifest.processes)await scenario('stalling '+p.name+' is detected despite fresh heartbeats',async()=>{
  const data=payload(p),key=Object.keys(data)[0];data[key]={...data[key],phase:'running',running_seconds:p.lanes[key].max_run_seconds+1};
  await report(p,data,2,(await db.query('SELECT instance FROM public.worker_fleet_runtime WHERE worker=$1',[p.name])).rows[0].instance);
  assert.equal((await component('worker:'+p.name)).state,'stalled');
 });
 await scenario('a stalled usage lane cannot be hidden by fulfillment progress',async()=>{
  const p=manifest.processes.find(p=>p.name==='worker-esim-fulfillment');const data=payload(p);data.usage.phase='error';
  const id=await scalar('SELECT instance v FROM public.worker_fleet_runtime WHERE worker=$1',[p.name]);await report(p,data,2,id);
  assert.equal((await component('worker:'+p.name)).lanes.fulfillment,'healthy');assert.equal((await component('worker:'+p.name)).lanes.usage,'degraded');
 });
 await scenario('actual Node reporter and PostgreSQL RPC agree on successful progress and failed cycles',async()=>{
  const {createMonitor}=await import(new URL('../../../backend-sync-wt/worker_health.js',import.meta.url));
  const monitor=createMonitor('worker_instant_refill',new URL('../../../backend-sync-wt/worker_instant_refill.js',import.meta.url).pathname,{
   autoStart:false,env:{SUPABASE_URL:'https://isolated.invalid',SUPABASE_SERVICE_ROLE_KEY:'synthetic'},log:()=>{},
   fetch:async(url,init)=>{assert.ok(url.endsWith('/rpc/report_worker_health'));const b=JSON.parse(init.body);
    const result=await scalar('SELECT public.report_worker_health($1,$2,$3,$4,$5,$6) v',[b.p_worker,b.p_instance,b.p_started_at,b.p_sequence,b.p_version,b.p_lanes]);
    return Response.json(result);}
  });
  monitor.begin('queue');monitor.success('queue');assert.equal(await monitor.flush(),true);
  assert.equal((await component('worker:worker_instant_refill')).state,'healthy');
  monitor.fail('queue');assert.equal(await monitor.flush(),true);assert.equal((await component('worker:worker_instant_refill')).state,'stalled');
 });
 await scenario('real client roles cannot report health or read private state, even if an RPC grant regresses',async()=>{
  await db.exec("SELECT set_config('request.jwt.claims','{\"role\":\"authenticated\",\"sub\":\"10000000-0000-4000-8000-000000000001\"}',false); SET ROLE authenticated");
  for(const sql of ['SELECT public.get_worker_fleet_health()','SELECT * FROM public.worker_fleet_runtime','SELECT * FROM public.worker_fleet_probes','SELECT public.check_worker_fleet_health()'])await denied(sql);
  await db.exec('RESET ROLE; GRANT EXECUTE ON FUNCTION public.report_worker_health(text,uuid,timestamptz,bigint,text,jsonb) TO authenticated; SET ROLE authenticated');
  await denied(`SELECT public.report_worker_health('worker_instant_refill',gen_random_uuid(),now(),1,'${version}','{}')`);
 });
 await scenario('JWT power users can read detailed fleet state through the guarded admin API',async()=>{
  await db.exec("SELECT set_config('request.jwt.claims','{\"role\":\"authenticated\",\"sub\":\"10000000-0000-4000-8000-000000000001\",\"app_metadata\":{\"is_power_user\":true}}',false); SET ROLE authenticated");
  const value=await scalar('SELECT public.admin_worker_fleet_health() v');assert.equal(value.status,'healthy');assert.ok(value.components.some(c=>c.version===version));
 });
 await scenario('initial running cycles without a successful observation never report healthy',async()=>{
  const p=manifest.processes[0],data=Object.fromEntries(Object.keys(p.lanes).map(k=>[k,{phase:'running',completed:0,failed:0,running_seconds:0}]));
  await report(p,data,1,uuid(),new Date(Date.now()).toISOString());
  assert.equal((await component('worker:'+p.name)).state,'stalled');
 });
 await scenario('fresh heartbeats without a new successful cycle eventually become stalled',async()=>{
  await db.exec("UPDATE public.worker_fleet_runtime SET lanes=jsonb_set(lanes,'{queue,last_success_at}',to_jsonb(now()-interval '1 hour')) WHERE worker='worker_instant_refill'");
  assert.equal((await component('worker:worker_instant_refill')).state,'stalled');
 });
 await scenario('reordered heartbeats and superseded process instances cannot resurrect old success',async()=>{
  const p=manifest.processes[0],id=uuid(),started=new Date(Date.now()+1000).toISOString();assert.equal(await report(p,payload(p),1,id,started),true);
  assert.equal(await report(p,payload(p),1,id,started),false);
  assert.equal(await report(p,payload(p),9,uuid(),new Date(Date.now()-120000).toISOString()),false);
 });
 await scenario('arbitrary payload fields, secret-bearing versions and unknown workers are rejected',async()=>{
  const p=manifest.processes[0],data=payload(p),key=Object.keys(data)[0];data[key].provider_payload='private';
  await db.exec('SAVEPOINT invalid');await assert.rejects(report(p,data),e=>e.code==='22023');await db.exec('ROLLBACK TO SAVEPOINT invalid');
  await denied(`SELECT public.report_worker_health('unknown',gen_random_uuid(),now(),1,'${version}','{}')`,'22023');
 });
 await scenario('public/API polls use cached queue measurements, live worker state and fail closed on stale measurements',async()=>{
  await db.exec("UPDATE public.worker_fleet_probes SET query_sql='SELECT * FROM missing_table' WHERE key='refill_instant'");
  assert.equal((await scalar('SELECT public.get_worker_fleet_health() v')).status,'healthy');
  await db.exec("UPDATE public.worker_fleet_runtime SET last_seen_at=now()-interval '1 hour' WHERE worker='worker_instant_refill'");
  assert.equal((await scalar('SELECT public.get_worker_fleet_health() v')).status,'degraded');
  await db.exec("UPDATE public.worker_fleet_runtime SET last_seen_at=now(); UPDATE public.worker_fleet_observation SET observed_at=now()-interval '16 minutes'");
  assert.ok((await scalar('SELECT public.get_worker_fleet_health() v')).components.some(c=>c.key==='probe:observation'&&c.state==='unknown'));
 });
 await scenario('probe failures and missing cron metadata fail closed independently',async()=>{
  await db.exec("UPDATE public.worker_fleet_probes SET query_sql='SELECT * FROM public.missing_table' WHERE key='refill_instant'");
  assert.equal((await component('probe:refill_instant')).state,'unknown');assert.equal((await component('probe:refill_mini')).state,'healthy');
  await db.exec('DROP SCHEMA cron CASCADE');assert.ok((await snapshot()).components.filter(c=>c.kind==='cron').every(c=>c.state==='unknown'));
 });
 await scenario('overdue queues, stale refill claims and future work have distinct behavior',async()=>{
  await db.exec("INSERT INTO public.topup_executions(sim_line_id,user_id,amount,execution_type,execution_time) VALUES('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001',2,'refill_instant',now()+interval '1 day')");
  assert.equal((await component('probe:refill_instant')).state,'healthy');
  await db.exec("UPDATE public.topup_executions SET execution_time=now()-interval '6 minutes'");assert.equal((await component('probe:refill_instant')).state,'backlog');
  await db.exec("UPDATE public.topup_executions SET status='processing',processing_since=now()-interval '16 minutes'");assert.equal((await component('probe:refill_instant')).issues,1);
 });
 await scenario('operator supplier reconciliation and expired leases remain visible with fresh reconciler',async()=>{
  await db.exec("INSERT INTO public.wallets(id,user_id,balance) VALUES('60000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001',0)");
  await db.exec("INSERT INTO public.wallet_holds(id,wallet_id,user_id,order_type,order_reference_id,amount,expires_at) VALUES('70000000-0000-4000-8000-000000000001','60000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','refill_instant','fixture',2,now()-interval '1 hour')");
  const id=uuid();await db.query("INSERT INTO public.topup_executions(id,sim_line_id,user_id,amount,execution_type) VALUES($1,'20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001',2,'refill_instant')",[id]);
  await db.query("INSERT INTO public.refill_supplier_submissions(execution_id,hold_id,provider,external_reference,binding,outcome) VALUES($1,'70000000-0000-4000-8000-000000000001','dtone','fixture','{}','operator')",[id]);
  assert.equal((await component('probe:supplier_reconciliation')).issues,1);assert.equal((await component('probe:unresolved_holds')).state,'backlog');
  await db.exec("UPDATE public.refill_supplier_submissions SET outcome='pending',lease_until=now()-interval '1 minute'");assert.equal((await component('probe:supplier_reconciliation')).issues,1);
 });
 await scenario('overdue voucher requests and failed manual-stock jobs are visible without starting purchases',async()=>{
  await db.exec("INSERT INTO public.offline_voucher_requests(user_id,sim_line_id,carrier_id,due_at) VALUES('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000001',now()-interval '2 minutes')");
  assert.equal((await component('probe:voucher_requests')).state,'backlog');
  await db.exec("INSERT INTO public.offline_voucher_purchase_jobs(carrier_id,quantity,max_unit_cost_usd,status) VALUES('40000000-0000-4000-8000-000000000001',1,1,'failed')");assert.equal((await component('probe:voucher_purchase_jobs')).issues,1);
 });
 await scenario('failed billing email and ambiguous WhatsApp sends degrade fleet without exposing payloads',async()=>{
  await db.exec("INSERT INTO public.admin_emails(from_address,to_addresses,subject,body_text,status) VALUES('test@example.invalid',ARRAY['private@example.invalid'],'private-subject','private-body','failed')");
  await db.exec("INSERT INTO public.whatsapp_message_attempts(purpose,recipient_phone,route_mode,idempotency_key,state) VALUES('admin_test','private-phone','baileys','private-key','unknown')");
  assert.equal((await component('probe:admin_email')).issues,1);assert.equal((await component('probe:whatsapp_attempts')).issues,1);
  assert.doesNotMatch(JSON.stringify(await snapshot()),/private-|provider_payload|balance|capture_id/);
 });
 await scenario('failed or paused required cron jobs degrade health and recovery is immediate',async()=>{
  await db.exec("UPDATE cron.job SET active=false WHERE jobname='reap-stuck-executions'");assert.equal((await component('cron:reap-stuck-executions')).state,'missing');
  await db.exec("UPDATE cron.job SET active=true; UPDATE cron.job_run_details SET status='failed' WHERE jobid=(SELECT jobid FROM cron.job WHERE jobname='reap-stuck-executions')");assert.equal((await component('cron:reap-stuck-executions')).state,'failed');
  await db.exec("UPDATE cron.job_run_details SET status='succeeded'");assert.equal((await component('cron:reap-stuck-executions')).state,'healthy');
 });
 await scenario('alerts are bounded per component across repeated sweeps and flapping recovery',async()=>{
  await db.exec("UPDATE public.worker_fleet_runtime SET last_seen_at=now()-interval '1 hour' WHERE worker='worker_instant_refill'; SELECT public.check_worker_heartbeat_health(); SELECT public.check_worker_heartbeat_health();");
  assert.equal(Number(await scalar("SELECT count(*) v FROM public.system_alerts WHERE kind='worker_fleet_degraded'")),1);
  await db.exec("UPDATE public.worker_fleet_runtime SET last_seen_at=now(); SELECT public.check_worker_fleet_health(); UPDATE public.worker_fleet_runtime SET last_seen_at=now()-interval '1 hour'; SELECT public.check_worker_fleet_health();");
  // Eight newly stale processes join the original one; the original does not spam.
  assert.equal(Number(await scalar("SELECT count(*) v FROM public.system_alerts WHERE details->>'component'='worker:worker_instant_refill'")),1);
 });
 await scenario('catalogue freshness checks only explicitly active suppliers and routes',async()=>{
  await db.exec("INSERT INTO public.service_providers(code,name,supports_esim) VALUES('fixture','Fixture',true); INSERT INTO public.esim_suppliers(code,name,is_active) VALUES('fixture','Fixture',false)");
  assert.equal((await component('probe:active_esim_catalogue')).state,'healthy');
  await db.exec("UPDATE public.esim_suppliers SET is_active=true");assert.equal((await component('probe:active_esim_catalogue')).issues,1);
  await db.exec("UPDATE public.esim_suppliers SET last_sync_at=now(),last_sync_status='ok'");assert.equal((await component('probe:active_esim_catalogue')).state,'healthy');
  await db.exec("INSERT INTO public.supplier_policy(provider,is_globally_enabled) VALUES('ding',true); UPDATE public.carriers SET is_supported=true; INSERT INTO public.carrier_provider_map(carrier_id,provider,provider_country_code,provider_carrier_code,provider_country_label,provider_carrier_label,is_enabled) VALUES('40000000-0000-4000-8000-000000000001','ding','ZZ','fixture','Fixture','Fixture',true)");
  assert.equal((await component('probe:active_offer_catalogue')).issues,1);
  await db.exec("INSERT INTO public.provider_offers_cache(api_provider,offer_id,country_code,carrier_code,price_type,price_fixed_usd) VALUES('ding','fixture','ZZ','fixture','FIXED',1)");assert.equal((await component('probe:active_offer_catalogue')).state,'healthy');
 });
 await scenario('failed approval pricing work cannot be hidden by later idle polling',async()=>{
  const id=uuid();await db.query("INSERT INTO public.topup_executions(id,sim_line_id,user_id,amount,execution_type) VALUES($1,'20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001',2,'refill_mini')",[id]);
  await db.query("INSERT INTO public.refill_approval_quotes(execution_id,requested_by,execution_snapshot,status) VALUES($1,'10000000-0000-4000-8000-000000000001','{}','failed')",[id]);
  assert.equal((await component('probe:approval_quotes')).issues,1);
 });
 await scenario('failed notification targets and expired dispatcher claims remain visible',async()=>{
  const n=uuid();await db.query("INSERT INTO public.notifications(id,user_id,category,title,body) VALUES($1,'10000000-0000-4000-8000-000000000001','system','Fixture','Fixture')",[n]);
  await db.query("INSERT INTO public.notification_dispatch_jobs(notification_id,user_id,payload,state,lease_until) VALUES($1,'10000000-0000-4000-8000-000000000001','{}','leased',now()-interval '1 minute')",[n]);
  await db.query("INSERT INTO public.notification_channel_targets(notification_id,user_id,channel,target_key,state) VALUES($1,'10000000-0000-4000-8000-000000000001','email','fixture','unknown')",[n]);
  assert.equal((await component('probe:notification_dispatch')).issues,1);assert.equal((await component('probe:notification_targets')).issues,1);
 });
 await scenario('stale eSIM fulfillment and failed purge jobs are distinct visible backlogs',async()=>{
  await db.exec("INSERT INTO public.esim_orders(user_id,bundle_name,wholesale_price_usd,retail_price_usd,markup_percent,status,created_at,updated_at) VALUES('10000000-0000-4000-8000-000000000001','fixture',1,2,100,'processing',now()-interval '1 hour',now()-interval '1 hour')");
  assert.equal((await component('probe:esim_orders')).issues,1);
  await db.exec("INSERT INTO public.account_deletions(id,user_id,email_hash,scheduled_purge_at) VALUES('80000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','fixture',now()); INSERT INTO public.account_purge_jobs(deletion_id,target_user_id,actor_email,state) VALUES('80000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','fixture@example.invalid','failed')");
  assert.equal((await component('probe:account_purge')).issues,1);
 });
 await scenario('failed payout and reconciliation-required payout records stay visible',async()=>{
  const user='10000000-0000-4000-8000-000000000001';
  await db.query("SELECT public.credit_wallet_for_deposit($1,5,'fixture','paypal_fleet','{\"paypal_capture_id\":\"fleet\"}')",[user]);
  const w=await scalar('SELECT id v FROM public.wallets WHERE user_id=$1',[user]);
  const lot=await scalar('SELECT id v FROM public.wallet_funding_lots WHERE wallet_id=$1',[w]);const r=uuid();
  await db.query("INSERT INTO public.wallet_refund_requests(id,user_id,wallet_id,requested_amount,status) VALUES($1,$2,$3,1,'processing')",[r,user,w]);
  await db.query("INSERT INTO public.wallet_refund_items(refund_request_id,lot_id,capture_id,amount,idempotency_key,status) VALUES($1,$2,'fleet',1,'fleet','reconciliation_required')",[r,lot]);
  assert.equal((await component('probe:payout_reconciliation')).issues,1);
  await db.exec("UPDATE public.wallet_refund_items SET status='completed'");assert.equal((await component('probe:payout_reconciliation')).state,'healthy');
 });
 await scenario('DID purchase ambiguity is reported without a provider lookup or purchase',async()=>{
  await db.exec("INSERT INTO public.second_number_orders(user_id,phone_number,country_code,country_name,number_type,wholesale_monthly_usd,monthly_fee_usd,service_fee_usd,setup_fee_usd,terms,state) VALUES('10000000-0000-4000-8000-000000000001','+15550009999','ZZ','Fixture','mobile',1,2,1,0,'{}','reconciliation')");
  assert.equal((await component('probe:second_number_purchases')).issues,1);
 });
 await scenario('ledger drift is observable without publishing balances',async()=>{
  await db.exec("INSERT INTO public.wallets(user_id,balance) VALUES('10000000-0000-4000-8000-000000000001',5)");
  assert.equal((await component('probe:wallet_reconciliation')).issues,1);
  assert.doesNotMatch(JSON.stringify(await snapshot()),/balance|ledger_sum|5\.00/);
 });
 await scenario('cron run failures, missing runs and hung jobs never count as healthy',async()=>{
  await db.exec("UPDATE cron.job_run_details SET status='running',start_time=now()-interval '16 minutes',end_time=NULL WHERE jobid=(SELECT jobid FROM cron.job WHERE jobname='process-alert-outbox-every-minute')");
  assert.equal((await component('cron:process-alert-outbox-every-minute')).state,'stale');
  await db.exec("DELETE FROM cron.job_run_details WHERE jobid=(SELECT jobid FROM cron.job WHERE jobname='process-alert-outbox-every-minute')");assert.equal((await component('cron:process-alert-outbox-every-minute')).state,'unknown');
 });
 await scenario('alert cooldown survives state changes and permits a bounded later reminder',async()=>{
  await db.exec("UPDATE public.worker_fleet_runtime SET last_seen_at=now()-interval '1 hour' WHERE worker='worker_instant_refill'; SELECT public.check_worker_fleet_health();");
  await db.exec("UPDATE public.worker_fleet_incidents SET last_alert_at=now()-interval '7 hours' WHERE key='worker:worker_instant_refill'; SELECT public.check_worker_fleet_health();");
  assert.equal(Number(await scalar("SELECT count(*) v FROM public.system_alerts WHERE details->>'component'='worker:worker_instant_refill'")),2);
 });
 await scenario('failed alert storage cannot suppress a later healthy storage retry',async()=>{
  await db.exec("UPDATE public.worker_fleet_runtime SET last_seen_at=now()-interval '1 hour' WHERE worker='worker_instant_refill'");
  await db.exec("CREATE FUNCTION public.fleet_test_fail_alert() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'private-payload';END$$; CREATE TRIGGER fleet_test_alert BEFORE INSERT ON public.system_alerts FOR EACH ROW EXECUTE FUNCTION public.fleet_test_fail_alert(); SELECT public.check_worker_fleet_health();");
  assert.equal(await scalar("SELECT count(*)::int v FROM public.worker_fleet_incidents WHERE key='worker:worker_instant_refill'"),0);
  await db.exec("DROP TRIGGER fleet_test_alert ON public.system_alerts; SELECT public.check_worker_fleet_health()");
  assert.equal(await scalar("SELECT count(*)::int v FROM public.worker_fleet_incidents WHERE key='worker:worker_instant_refill'"),1);
 });
 if(server)await scenario('independent sweeps serialize and insert one incident alert',async()=>{
  // Main transaction is rolled back by scenario(); seed and commit outside it for concurrency.
  await db.exec('COMMIT');await db.exec("UPDATE public.worker_fleet_runtime SET last_seen_at=now()-interval '1 hour' WHERE worker='worker_instant_refill'");
  const clients=[server.getPgClient(),server.getPgClient()];
  try{for(const c of clients)await c.connect();await Promise.all(clients.map(c=>c.query('SELECT public.check_worker_fleet_health()')));
   assert.equal(Number(await scalar("SELECT count(*) v FROM public.system_alerts WHERE details->>'component'='worker:worker_instant_refill'")),1);
  }finally{for(const c of clients)await c.end();await db.exec("DELETE FROM public.system_alerts WHERE kind='worker_fleet_degraded'; DELETE FROM public.worker_fleet_incidents; UPDATE public.worker_fleet_runtime SET last_seen_at=now()");await db.exec('BEGIN');}
 });
 results.push(...await runSQLCases(db,read('supabase/tests/worker_fleet_contract_tests.sql'),'fleet security'));
 if(process.env.FLEET_NATIVE==='1')assert.ok(results.some(r=>r.name==='independent sweeps serialize and insert one incident alert'&&r.status==='passed'),'Required independent-session fleet race did not pass');
 if(process.env.FLEET_TEST_REPORT)fs.writeFileSync(process.env.FLEET_TEST_REPORT,JSON.stringify({environment:server?'isolated native PostgreSQL':'isolated PGlite',passed:results.filter(r=>r.status==='passed').length,failed:results.filter(r=>r.status==='failed').length,results},null,2)+'\n');
 console.log(`${results.filter(r=>r.status==='passed').length} passed; ${results.filter(r=>r.status==='failed').length} failed`);if(results.some(r=>r.status==='failed'))process.exitCode=1;
}finally{if(server){await owner?.end();await server.stop();fs.rmSync(directory,{recursive:true,force:true});}else await db?.close();}
