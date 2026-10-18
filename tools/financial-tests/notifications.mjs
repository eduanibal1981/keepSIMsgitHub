// Isolated native PostgreSQL: actual recorded postgres cron entry point,
// production constraints and catalog-verified emitter/outbox/clock functions.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
const { default: EmbeddedPostgres } = await import(process.env.EMBEDDED_POSTGRES_MODULE_PATH
  ? pathToFileURL(process.env.EMBEDDED_POSTGRES_MODULE_PATH).href : 'embedded-postgres');
const directory = await fs.mkdtemp(path.join(os.tmpdir(),'keepsims-notifications-'));
const server = new EmbeddedPostgres({databaseDir:directory,user:'postgres',password:'isolated-test',
  port:Number(process.env.NOTIFICATION_TEST_PORT || 56549),persistent:false,initdbFlags:['--locale=C'],
  postgresFlags:['-h','127.0.0.1',...(process.platform==='win32'?[]:['-k',directory])],onLog:()=>{},onError:()=>{}});
const clients=[];
const notices=[];
const read=p=>fs.readFile(new URL('../../'+p,import.meta.url),'utf8');
const user='10000000-0000-4000-8000-000000000001';
const line='20000000-0000-4000-8000-000000000001';
const admin='10000000-0000-4000-8000-000000000002';
let db,passed=0;
async function connect(){const c=server.getPgClient();await c.connect();clients.push(c);c.on('notice',n=>notices.push(n.message));return c;}
const query=(sql,params)=>db.query(sql,params);
const value=async(sql,params)=>(await query(sql,params)).rows[0].value;
const sweep=()=>query('SELECT public.process_due_notifications()');
const emit=()=>value('SELECT public.emit_upcoming_refill_low_balance_reminders() AS value');
const count=(where)=>value('SELECT count(*)::int AS value FROM public.notifications WHERE '+where);
async function blockedBy(client,blocker){
  for(let attempt=0;attempt<100;attempt++){
    if(await value('SELECT $1::int=ANY(pg_blocking_pids($2::int)) AS value',[blocker.processID,client.processID]))return;
    await new Promise(resolve=>setTimeout(resolve,10));
  }
  assert.fail('Expected an overlapping session to wait on the scheduler transaction lock');
}
async function scenario(name,run){
  await query('BEGIN');
  try{await run();passed++;console.log('PASS '+name);}
  finally{await query('ROLLBACK');}
}
async function rejected(sql,code){
  await query('SAVEPOINT denied');
  await assert.rejects(query(sql),e=>e.code===code);
  await query('ROLLBACK TO SAVEPOINT denied');
}
const seed=`
INSERT INTO auth.users(id) VALUES('${user}'),('${admin}');
INSERT INTO public.profiles(id,email,is_power_user) VALUES('${user}','user@example.invalid',false),('${admin}','admin@example.invalid',true);
INSERT INTO public.notification_channel_catalog(channel_key,label,min_tier,sort_order)
  VALUES('push','Push','basic',1),('telegram','Telegram','basic',2),('email','Email','standard',3),('whatsapp','WhatsApp','standard',4);
INSERT INTO public.system_configs(config_key,config_value) VALUES('ALERT_CLOCK_SCHEDULER_ENABLED','true'),('ALERT_CLOCK_STALE_RULE_DAYS','180');
INSERT INTO public.countries(id,name,iso_code,dialing_code,currency_code) VALUES('30000000-0000-4000-8000-000000000001','Fixture','ZZ','000','USD');
INSERT INTO public.carriers(id,country_id,name) VALUES('40000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','Fixture');
INSERT INTO public.carrier_rules(id,carrier_id,rule_type,inactivity_limit_days,minimum_topup_amount,topup_validity_days,last_verified_at,rule_source_url)
  VALUES('50000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000001','prepaid',30,1,30,now(),'https://example.invalid/rule');
INSERT INTO public.sim_lines(id,user_id,phone_number,plan_type,notification_entitlement_verified,created_at,last_topup_at,carrier_id,carrier_rule_id)
  VALUES('${line}','${user}','+0000000001','standard',true,now()-interval '20 days',now(),'40000000-0000-4000-8000-000000000001','50000000-0000-4000-8000-000000000001'),
  ('20000000-0000-4000-8000-000000000002','${user}','+0000000002','basic',false,now()-interval '20 days',NULL,'40000000-0000-4000-8000-000000000001','50000000-0000-4000-8000-000000000001'),
  ('20000000-0000-4000-8000-000000000003','${user}','+0000000003','basic',false,now()-interval '40 days',now()-interval '29 days','40000000-0000-4000-8000-000000000001','50000000-0000-4000-8000-000000000001');
INSERT INTO public.wallets(id,user_id,balance) VALUES('60000000-0000-4000-8000-000000000001','${user}',10);
INSERT INTO public.wallet_holds(wallet_id,user_id,order_type,order_reference_id,amount)
  VALUES('60000000-0000-4000-8000-000000000001','${user}','call_budget','fixture',8);
INSERT INTO public.topup_executions(sim_line_id,user_id,amount,execution_type,execution_time)
  VALUES('${line}','${user}',5,'refill_mini',now()+interval '2 days');
INSERT INTO public.scheduled_topups(sim_line_id,user_id,amount,frequency_days,next_execution_at)
  VALUES('${line}','${user}',5,30,now()-interval '1 hour');
`;
try{
  await server.initialise();await server.start();db=await connect();
  await query(await read('supabase/tests/fixtures/notification_scheduler_baseline.sql'));
  await query(seed);
  await scenario('production low-available-balance branch reproduces 23514 and rolls back the original scheduler',async()=>{
    assert.equal(await value('SELECT current_user AS value'),'postgres');
    await rejected('SELECT public.process_due_notifications()','23514');
    assert.equal(await count('true'),0);
  });
  await query(await read('supabase/migrations/20261018010000_notification_scheduler_contract.sql'));
  await scenario('postgres cron entry point queues all four real emitters and repeat sweeps deduplicate',async()=>{
    await sweep();await sweep();
    assert.deepEqual((await query('SELECT event_type FROM public.notifications ORDER BY event_type')).rows.map(r=>r.event_type),
      ['line_deactivation_imminent','recharge_date_missing','recharge_due_today','wallet_low']);
    assert.equal(await value('SELECT count(*)::int AS value FROM public.notification_dispatch_jobs'),4);
    assert.equal(await value('SELECT count(*)::int AS value FROM public.system_alerts'),0);
    assert.equal(await value('SELECT bool_and(next_execution_at>now()) AS value FROM public.scheduled_topups'),true);
    assert.equal(await value('SELECT bool_and(cardinality(delivered_via)=0) AS value FROM public.notifications'),true);
    assert.equal(await emit(),0);
    const {rows:[job]}=await query("SELECT j.payload,j.state,j.attempt_count,n.* FROM public.notification_dispatch_jobs j JOIN public.notifications n ON n.id=j.notification_id WHERE n.event_type='wallet_low'");
    assert.equal(job.category,'wallet_low');assert.equal(job.schema_version,2);assert.equal(job.template_version,1);
    assert.equal(job.state,'pending');assert.equal(job.attempt_count,0);assert.deepEqual(job.payload.channels,['push']);
    assert.deepEqual(job.payload.template_data,job.template_data);assert.equal(job.template_data.available_balance,2);
    assert.equal(job.payload.source_event_key,job.source_event_key);assert.deepEqual(job.target,{route:'/wallet'});
    assert.equal(await value("SELECT bool_and(metadata->>'state'='queued') AS value FROM public.line_activity_log"),true);
  });
  await scenario('same-line mini/custom executions choose the nearest refill and enforce a rolling 24-hour limit',async()=>{
    await query(`INSERT INTO public.topup_executions(sim_line_id,user_id,amount,execution_type,execution_time) VALUES($1,$2,6,'refill_custom',now()+interval '1 day')`,[line,user]);
    assert.equal(await emit(),1);assert.equal(await emit(),0);
    assert.equal(await value("SELECT (template_data->>'refill_amount')::numeric::int AS value FROM public.notifications"),6);
    await query("UPDATE public.notifications SET created_at=now()-interval '23 hours 59 minutes',source_event_key='upcoming-refill-low-balance:previous-day'");
    assert.equal(await emit(),0);
    await query("UPDATE public.notifications SET created_at=now()-interval '24 hours 1 minute'");
    assert.equal(await emit(),1);assert.equal(await count("category='wallet_low'"),2);
  });
  await scenario('supported legacy wallet_low reminder participates in deduplication',async()=>{
    await query("INSERT INTO public.notifications(user_id,sim_line_id,category,title,body) VALUES($1,$2,'wallet_low','Low Wallet Balance for Upcoming Auto-Refill','Legacy')",[user,line]);
    assert.equal(await emit(),0);
  });
  await scenario('inclusive seven-day boundary and legacy null currency retain a valid durable reminder',async()=>{
    await query("UPDATE public.topup_executions SET execution_time=now()+interval '7 days',currency=NULL");
    assert.equal(await emit(),1);
    assert.equal(await value("SELECT template_data->>'currency' AS value FROM public.notifications"),'USD');
  });
  for(const [name,sql] of [
    ['sufficient available funds',"UPDATE public.wallet_holds SET status='released'"],
    ['exact available funds',"UPDATE public.wallet_holds SET amount=5"],
    ['missing wallet',"DELETE FROM public.wallet_holds; DELETE FROM public.wallets"],
    ['paused protection',"UPDATE public.sim_lines SET protection_paused=true"],
    ['inactive line',"UPDATE public.sim_lines SET status='paused'"],
    ['past execution',"UPDATE public.topup_executions SET execution_time=now()-interval '1 minute'"],
    ['outside seven-day window',"UPDATE public.topup_executions SET execution_time=now()+interval '7 days 1 minute'"],
    ['nonpending execution',"UPDATE public.topup_executions SET status='success'"],
    ['foreign execution owner',`UPDATE public.topup_executions SET user_id='${admin}'`],
  ])await scenario(name+' creates no low-balance reminder',async()=>{await query(sql);assert.equal(await emit(),0);});
  await scenario('category/channel preferences and verified paid eligibility control the existing outbox trigger',async()=>{
    await query("INSERT INTO public.notification_channels(user_id,channel_type,is_enabled) VALUES($1,'email',true),($1,'telegram',true),($1,'whatsapp',true)",[user]);
    assert.equal(await emit(),1);
    assert.deepEqual(await value("SELECT payload->'channels' AS value FROM public.notification_dispatch_jobs"),['push','telegram','email','whatsapp']);
    await query('DELETE FROM public.notifications');
    await query('UPDATE public.sim_lines SET notification_entitlement_verified=false');
    assert.equal(await emit(),1);
    assert.deepEqual(await value("SELECT payload->'channels' AS value FROM public.notification_dispatch_jobs"),['push','telegram']);
    await query('DELETE FROM public.notifications');
    await query("INSERT INTO public.alert_settings(user_id,category,is_enabled) VALUES($1,'wallet_low',false)",[user]);
    assert.equal(await emit(),1);
    assert.equal(await value('SELECT count(*)::int AS value FROM public.notification_dispatch_jobs'),0);
    assert.equal(await value('SELECT cardinality(delivered_via) AS value FROM public.notifications'),0);
  });
  await scenario('failed low-balance outbox insertion rolls back its event, records diagnostics, and preserves later real emitters',async()=>{
    await query(`CREATE FUNCTION public.fixture_fail_low_job() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
      IF NEW.payload->>'event_type'='wallet_low' THEN RAISE EXCEPTION 'fixture secret must not be logged' USING ERRCODE='23514'; END IF; RETURN NEW; END $$;
      CREATE TRIGGER fixture_fail BEFORE INSERT ON public.notification_dispatch_jobs FOR EACH ROW EXECUTE FUNCTION public.fixture_fail_low_job()`);
    await sweep();
    assert.equal(await count("event_type='wallet_low'"),0);
    for(const event of ['recharge_due_today','recharge_date_missing','line_deactivation_imminent','system_alert'])assert.equal(await count("event_type='"+event+"'"),1);
    const details=await value('SELECT details AS value FROM public.system_alerts');
    assert.deepEqual(details,{job_name:'process-hourly-notifications',stage:'upcoming_refill',sqlstate:'23514'});
    assert.ok(!JSON.stringify((await query('SELECT * FROM public.system_alerts')).rows).includes('fixture secret'));
    assert.equal(await value('SELECT bool_and(cardinality(delivered_via)=0) AS value FROM public.notifications'),true);
    await query('DROP TRIGGER fixture_fail ON public.notification_dispatch_jobs');await sweep();
    assert.equal(await count("event_type='wallet_low'"),1);
  });
  await scenario('failed earlier stages and diagnostic storage leave later emitters running with sanitized warnings',async()=>{
    await query(`CREATE FUNCTION public.fixture_fail_event() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
      IF NEW.event_type IN ('recharge_due_today','wallet_low') THEN RAISE EXCEPTION 'private raw payload' USING ERRCODE='23514'; END IF; RETURN NEW; END $$;
      CREATE TRIGGER fixture_fail BEFORE INSERT ON public.notifications FOR EACH ROW EXECUTE FUNCTION public.fixture_fail_event();
      CREATE FUNCTION public.fixture_fail_diagnostic() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'private diagnostic' USING ERRCODE='23514'; END $$;
      CREATE TRIGGER fixture_fail BEFORE INSERT ON public.system_alerts FOR EACH ROW EXECUTE FUNCTION public.fixture_fail_diagnostic()`);
    const start=notices.length;await sweep();
    assert.equal(await count("event_type='recharge_date_missing'"),1);
    assert.equal(await count("event_type='line_deactivation_imminent'"),1);
    assert.equal(notices.slice(start).filter(n=>n.includes('SQLSTATE 23514')).length,4);
    assert.ok(notices.slice(start).every(n=>!n.includes('private')));
    assert.equal(await value('SELECT bool_and(next_execution_at<=now()) AS value FROM public.scheduled_topups'),true);
  });
  await scenario('a missing-date emitter failure cannot suppress urgent deactivation alerts',async()=>{
    await query(`CREATE FUNCTION public.fixture_fail_missing_date() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
      IF NEW.payload->>'event_type'='recharge_date_missing' THEN RAISE EXCEPTION 'fixture failure' USING ERRCODE='23514'; END IF; RETURN NEW; END $$;
      CREATE TRIGGER fixture_fail BEFORE INSERT ON public.notification_dispatch_jobs FOR EACH ROW EXECUTE FUNCTION public.fixture_fail_missing_date()`);
    await sweep();
    assert.equal(await count("event_type='recharge_date_missing'"),0);
    assert.equal(await count("event_type='line_deactivation_imminent'"),1);
    assert.equal(await value("SELECT details->>'stage' AS value FROM public.system_alerts"),'missing_recharge_date');
  });
  await scenario('a complete outbox outage attempts every stage and exposes failed diagnostics through warnings',async()=>{
    await query(`CREATE FUNCTION public.fixture_outbox_outage() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
      RAISE EXCEPTION 'private provider data' USING ERRCODE='23514'; END $$;
      CREATE TRIGGER fixture_fail BEFORE INSERT ON public.notification_dispatch_jobs FOR EACH ROW EXECUTE FUNCTION public.fixture_outbox_outage()`);
    const start=notices.length;await sweep();
    assert.equal(await count('true'),0);
    assert.equal(await value('SELECT count(*)::int AS value FROM public.system_alerts'),0);
    assert.equal(notices.slice(start).filter(n=>n.includes('SQLSTATE 23514')).length,8);
    for(const stage of ['due_schedules','upcoming_refill','missing_recharge_date','urgent_deactivation'])
      assert.ok(notices.slice(start).some(n=>n.includes('stage '+stage+' failed')));
    assert.ok(notices.slice(start).every(n=>!n.includes('private')));
    await query('DROP TRIGGER fixture_fail ON public.notification_dispatch_jobs');await sweep();
    assert.equal(await count('true'),4);
  });
  await scenario('delivery targets stay absent until claiming; provider acceptance remains distinct from delivery',async()=>{
    await emit();
    assert.equal(await value('SELECT count(*)::int AS value FROM public.notification_channel_targets'),0);
    const n=await value('SELECT id AS value FROM public.notifications');
    await query('SET LOCAL ROLE service_role');await query("SELECT set_config('request.jwt.claims','{\"role\":\"service_role\"}',true)");
    const jobs=(await query('SELECT * FROM public.claim_notification_dispatch_jobs(20)')).rows;assert.equal(jobs.length,1);
    const target=await value("SELECT public.claim_notification_channel_target($1,'push','fixture-device','{}') AS value",[n]);
    await query("SELECT public.finish_notification_channel_target($1,'push','fixture-device',$2,'accepted_by_provider',false,'Fixture provider acceptance')",[n,target.claim_token]);
    await query("SELECT public.finish_notification_dispatch_job($1,'complete')",[jobs[0].id]);await query('RESET ROLE');
    assert.equal(await value('SELECT state AS value FROM public.notification_channel_targets'),'accepted_by_provider');
    assert.equal(await value('SELECT cardinality(delivered_via) AS value FROM public.notifications'),0);
  });
  await scenario('anon/customer calls fail; scheduler/service calls work; body guards survive accidental grants',async()=>{
    for(const role of ['anon','authenticated']){
      await query('SET LOCAL ROLE '+role);
      await rejected('SELECT public.process_due_notifications()','42501');
      await rejected('SELECT public.emit_upcoming_refill_low_balance_reminders()','42501');await query('RESET ROLE');
    }
    await query('GRANT EXECUTE ON FUNCTION public.process_due_notifications(),public.emit_upcoming_refill_low_balance_reminders() TO authenticated');
    await query('SET LOCAL ROLE authenticated');
    await query("SELECT set_config('request.jwt.claims','{\"role\":\"service_role\"}',true)");
    await rejected('SELECT public.process_due_notifications()','42501');await rejected('SELECT public.emit_upcoming_refill_low_balance_reminders()','42501');
    await query('RESET ROLE');await query('SET LOCAL ROLE service_role');
    await query("SELECT set_config('request.jwt.claims','{}',true)");await rejected('SELECT public.process_due_notifications()','42501');
    await query("SELECT set_config('request.jwt.claims','{\"role\":\"service_role\"}',true)");await sweep();await query('RESET ROLE');
    assert.equal(await count("event_type='wallet_low'"),1);
  });
  await scenario('catalog checks preserve safe paths and exact execution grants',async()=>{
    assert.deepEqual((await query(await read('supabase/tests/notification_scheduler_contract_tests.sql'))).rows,[]);
  });
  // Independent committed sessions prove the transaction advisory lock, rather
  // than Promise scheduling in a single database connection, prevents duplicates.
  const a=await connect(),b=await connect();
  await a.query('BEGIN');await a.query('SELECT public.emit_upcoming_refill_low_balance_reminders()');
  const second=b.query('SELECT public.emit_upcoming_refill_low_balance_reminders() AS value');
  await blockedBy(b,a);
  await a.query('COMMIT');assert.equal((await second).rows[0].value,0);
  assert.equal(await count("event_type='wallet_low'"),1);
  assert.equal(await value("SELECT count(*)::int AS value FROM public.notification_dispatch_jobs j JOIN public.notifications n ON n.id=j.notification_id WHERE n.event_type='wallet_low'"),1);
  passed++;console.log('PASS overlapping direct sweeps in independent postgres sessions create one event and one outbox job');
  await a.query('BEGIN');await a.query('SELECT public.process_due_notifications()');
  const secondSweep=b.query('SELECT public.process_due_notifications()');
  await blockedBy(b,a);await a.query('COMMIT');await secondSweep;
  assert.equal(await count('true'),4);
  assert.equal(await value('SELECT count(*)::int AS value FROM public.notification_dispatch_jobs'),4);
  passed++;console.log('PASS overlapping scheduler calls preserve one due reminder and one event from each emitter');
  console.log(`${passed} notification SQL/scheduler scenarios passed`);
}finally{
  await Promise.allSettled(clients.map(c=>c.end()));await server.stop();await fs.rm(directory,{recursive:true,force:true});
}
