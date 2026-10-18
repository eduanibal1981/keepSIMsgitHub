// Task 15: production-shaped native PostgreSQL, with the actual cron SQL and
// customer/manual-recharge entry point. No external database/provider access.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
const {default:EmbeddedPostgres}=await import(process.env.EMBEDDED_POSTGRES_MODULE_PATH
  ? pathToFileURL(process.env.EMBEDDED_POSTGRES_MODULE_PATH).href:'embedded-postgres');
const directory=await fs.mkdtemp(path.join(os.tmpdir(),'keepsims-forecasts-'));
const server=new EmbeddedPostgres({databaseDir:directory,user:'postgres',password:'isolated-test',
  port:Number(process.env.FORECAST_TEST_PORT||56550),persistent:false,initdbFlags:['--locale=C'],
  postgresFlags:['-h','127.0.0.1',...(process.platform==='win32'?[]:['-k',directory])],onLog:()=>{},onError:()=>{}});
const read=p=>fs.readFile(new URL('../../'+p,import.meta.url),'utf8');
const clients=[],notices=[];
let db,passed=0;
async function connect(){const c=server.getPgClient();await c.connect();clients.push(c);c.on('notice',n=>notices.push(n.message));return c;}
const query=(sql,p)=>db.query(sql,p);
const value=async(sql,p)=>(await query(sql,p)).rows[0].value;
const user='10000000-0000-4000-8000-000000000001',other='10000000-0000-4000-8000-000000000002';
const line='20000000-0000-4000-8000-000000000001';
const compute=()=>value('SELECT public.compute_usage_forecasts() AS value');
const refresh=()=>value('SELECT public.refresh_usage_forecasts() AS value');
const forecast=async(id=line)=>(await query('SELECT * FROM public.sim_line_usage_forecast WHERE sim_line_id=$1 OR esim_id=$1',[id])).rows[0];
async function scenario(name,run){await query('BEGIN');try{await run();passed++;console.log('PASS '+name);}finally{await query('ROLLBACK');}}
async function rejected(sql,code,p){await query('SAVEPOINT rejection');await assert.rejects(query(sql,p),e=>e.code===code);await query('ROLLBACK TO SAVEPOINT rejection');}
async function role(name,uid=user){await query('SET LOCAL ROLE '+name);await query("SELECT set_config('request.jwt.claims',$1,true)",[JSON.stringify({role:name,sub:uid})]);}
async function esim({remaining=500,total=1000,expiry="now()+interval '10 days'",checked='now()',catalogue=true,owner=user}={}){
  const order=await value(`INSERT INTO public.esim_orders(user_id,bundle_name,quantity,wholesale_price_usd,retail_price_usd,markup_percent,status,offer_id,total_amount_usd)
    VALUES($1,'fixture',3,0.2,4.5,10,'completed','fixture-offer',13.5) RETURNING id AS value`,[owner]);
  const id=await value(`INSERT INTO public.user_esims(user_id,order_id,iccid,smdp_address,matching_id,lpa_string,bundle_name,
    purchased_at,expires_at,data_total_mb,data_remaining_mb,last_usage_check)
    VALUES($1,$2,gen_random_uuid()::text,'example.invalid','synthetic','synthetic','fixture',now()-interval '20 days',${expiry},$3,$4,${checked}) RETURNING id AS value`,[owner,order,total,remaining]);
  if(catalogue)await query(`INSERT INTO public.esim_offers_cache(provider,bundle_name,data_amount_mb,duration_days)
    VALUES('esim_go','fixture',1000,30) ON CONFLICT DO NOTHING`);
  return {id,order};
}
async function samples(id,readings){for(const [days,remaining,total=1000] of readings)await query(`INSERT INTO public.esim_usage_samples(esim_id,sampled_on,data_remaining_mb,data_total_mb)
  VALUES($1,(now() AT TIME ZONE 'UTC')::date+$2::int,$3,$4) ON CONFLICT(esim_id,sampled_on) DO UPDATE SET data_remaining_mb=excluded.data_remaining_mb,data_total_mb=excluded.data_total_mb`,[id,days,remaining,total]);}
const seed=`
INSERT INTO auth.users(id) VALUES('${user}'),('${other}');
INSERT INTO public.profiles(id,email) VALUES('${user}','user@example.invalid'),('${other}','other@example.invalid');
INSERT INTO public.notification_channel_catalog(channel_key,label) VALUES('push','Push');
INSERT INTO public.system_configs(config_key,config_value) VALUES('FORECAST_ALERT_LEAD_DAYS','7'),('FORECAST_MIN_CYCLE_DAYS','3'),('FORECAST_DEFAULT_VALIDITY_DAYS','90');
INSERT INTO public.countries(id,name,iso_code,dialing_code,currency_code) VALUES('30000000-0000-4000-8000-000000000001','Fixture','ZZ','000','USD');
INSERT INTO public.carriers(id,country_id,name) VALUES('40000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','Fixture');
INSERT INTO public.carrier_rules(id,carrier_id,rule_type,inactivity_limit_days,minimum_topup_amount,topup_validity_days,grace_period_days)
 VALUES('50000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000001','prepaid',90,2,1,30);
INSERT INTO public.sim_lines(id,user_id,phone_number,created_at,carrier_id,carrier_rule_id)
 VALUES('${line}','${user}','+0000000001',now()-interval '20 days','40000000-0000-4000-8000-000000000001','50000000-0000-4000-8000-000000000001');
`;
try{
  await server.initialise();await server.start();db=await connect();
  await query(await read('supabase/tests/fixtures/notification_scheduler_baseline.sql'));
  await query(await read('supabase/tests/fixtures/usage_forecast_baseline.sql'));
  await query(await read('supabase/migrations/20261018010000_notification_scheduler_contract.sql'));
  await query(seed);
  await scenario('original production computation and cron refresh reproduce missing esims and roll back physical output',async()=>{
    for(const fn of ['compute_usage_forecasts','refresh_usage_forecasts'])await rejected('SELECT public.'+fn+'()','42P01');
    assert.equal(await value('SELECT count(*)::int AS value FROM public.sim_line_usage_forecast'),0);
  });
  await scenario('retained null-anchor migration reproduces its rejected none method with real constraints',async()=>{
    const old=await read('supabase/migrations/20260916080000_fix_forecast_anchor_null_recharge.sql');
    await query(old.slice(old.indexOf('CREATE OR REPLACE FUNCTION'),old.indexOf('$function$;')+'$function$;'.length));
    await rejected('SELECT public.compute_usage_forecasts()','23514');
  });
  await query(await read('supabase/migrations/20261018020000_usage_forecast_schema_contract.sql'));
  await scenario('recorded postgres cron SQL refreshes an empty database without fabricated rows',async()=>{
    const catalog=JSON.parse(await read('docs/reviews/migration-cleanup-20261016/live-catalog.json'));
    const cron=catalog.cron.find(c=>c.name==='refresh-usage-forecasts');
    assert.equal(cron.username,'postgres');assert.equal(cron.command_sha256,createHash('sha256').update('SELECT public.refresh_usage_forecasts();').digest('hex'));
    await query('DELETE FROM public.sim_lines');
    const result=await refresh();assert.equal(result.esim_samples,0);assert.equal(result.forecasts,0);assert.equal(result.alerts,0);
  });
  await scenario('null physical recharge anchor retains an allowed method and unknown depletion',async()=>{
    assert.equal(await compute(),1);const f=await forecast();
    assert.equal(f.predicted_depletion_at,null);assert.equal(f.days_remaining,null);assert.equal(f.confidence,'low');
    assert.equal(f.method,'carrier_rule');assert.equal(f.suggested_frequency_days,76);
  });
  await scenario('physical history, sparse gaps and retry floor preserve a defensible carrier-capped forecast',async()=>{
    await query(`UPDATE public.sim_lines SET last_topup_at=now()-interval '10 days'`);
    for(const days of [100,70,40,10,9.9])await query(`INSERT INTO public.topup_executions(sim_line_id,user_id,amount,status,completed_at)
      VALUES($1,$2,5,'success',now()-$3::numeric*interval '1 day')`,[line,user,days]);
    await compute();const f=await forecast();assert.equal(f.method,'topup_history');assert.equal(f.confidence,'high');
    assert.equal(Number(f.observed_interval_days),30);assert.equal(f.days_remaining,20);assert.equal(f.suggested_frequency_days,76);
    assert.equal(Number(f.suggested_amount_usd),5);
  });
  await scenario('physical predictions do not extend the inactivity deadline into grace',async()=>{
    await query("UPDATE public.sim_lines SET last_topup_at=now(); UPDATE public.carrier_rules SET refill_interval_days_override=120");
    await compute();assert.equal((await forecast()).days_remaining,90);
  });
  await scenario('no rule/default configuration remains a labeled physical estimate and inactive forecasts are removed',async()=>{
    await query("UPDATE public.sim_lines SET carrier_rule_id=NULL,carrier_id=NULL,last_topup_at=now(); DELETE FROM public.system_configs");
    await compute();assert.equal((await forecast()).method,'default');assert.equal((await forecast()).days_remaining,90);
    await query("UPDATE public.sim_lines SET status='paused'");await compute();assert.equal(await forecast(),undefined);
  });
  await scenario('mixed physical/eSIM refresh fits actual samples and uses composite catalogue and retail unit purchase data',async()=>{
    const e=await esim();await samples(e.id,[[-4,900],[-2,700]]);
    await query("INSERT INTO public.esim_offers_cache(provider,bundle_name,data_amount_mb,duration_days) VALUES('other','fixture',1000,999)");
    const result=await refresh();assert.equal(result.forecasts,2);assert.equal(result.esim_samples,1);
    const f=await forecast(e.id);assert.equal(f.method,'esim_usage');assert.equal(f.confidence,'medium');
    assert.equal(Number(f.mb_per_day),100);assert.equal(f.days_remaining,5);assert.equal(f.effective_validity_days,30);
    assert.equal(f.suggested_frequency_days,30);assert.equal(Number(f.suggested_amount_usd),4.5);assert.equal(f.suggested_offer_id,'fixture-offer');
    assert.equal((await forecast()).predicted_depletion_at,null);
  });
  await scenario('expiry caps the fitted burn date without being inferred from purchase date or duration',async()=>{
    const e=await esim({expiry:"now()+interval '2 days'"});await samples(e.id,[[-4,900],[-2,700]]);await refresh();
    assert.equal((await forecast(e.id)).days_remaining,2);
  });
  await scenario('missing catalogue and unobserved usage remain explicit unknowns without blocking physical rows',async()=>{
    const e=await esim({catalogue:false,expiry:'NULL',checked:'NULL'});await refresh();const f=await forecast(e.id);
    assert.equal(f.predicted_depletion_at,null);assert.equal(f.days_remaining,null);assert.equal(f.effective_validity_days,null);
    assert.equal(f.suggested_frequency_days,null);assert.equal(f.mb_per_day,null);assert.equal(f.method,'default');assert.equal(f.confidence,'low');
    assert.ok(await forecast());
  });
  await scenario('a measured eSIM fit needs no catalogue; stale current readings project from their observation time',async()=>{
    const e=await esim({catalogue:false,checked:"now()-interval '2 days'",expiry:'NULL'});
    await samples(e.id,[[-6,900],[-4,700]]);await refresh();const f=await forecast(e.id);
    assert.equal(f.method,'esim_usage');assert.equal(Number(f.mb_per_day),100);assert.equal(f.days_remaining,3);
    assert.equal(f.effective_validity_days,null);assert.equal(f.suggested_frequency_days,null);
    await query('UPDATE public.user_esims SET data_remaining_mb=950 WHERE id=$1',[e.id]);await compute();
    assert.equal((await forecast(e.id)).predicted_depletion_at,null);
  });
  await scenario('unrepresentable burn rates and horizons become unknown without rolling back physical work',async()=>{
    const e=await esim({total:'9223372036854775807',remaining:'8000000000000000000',expiry:'NULL'});
    await samples(e.id,[[-2,'9223372036854775807','9223372036854775807']]);await refresh();
    assert.equal((await forecast(e.id)).mb_per_day,null);assert.equal((await forecast(e.id)).predicted_depletion_at,null);assert.ok(await forecast());
    await query('DELETE FROM public.esim_usage_samples');
    await query('UPDATE public.user_esims SET data_remaining_mb=999999 WHERE id=$1',[e.id]);
    await samples(e.id,[[-2,1000000,'9223372036854775807']]);await refresh();
    assert.equal((await forecast(e.id)).predicted_depletion_at,null);
  });
  await scenario('missing purchase evidence never borrows another owner price or wholesale metadata',async()=>{
    const e=await esim();await query('UPDATE public.esim_orders SET user_id=$1 WHERE id=$2',[other,e.order]);
    await refresh();assert.equal((await forecast(e.id)).suggested_amount_usd,null);assert.equal((await forecast(e.id)).suggested_offer_id,null);
  });
  for(const [name,sql] of [
    ['failed purchase',"UPDATE public.esim_orders SET status='failed'"],
    ['invalid historical price',"UPDATE public.esim_orders SET retail_price_usd='NaN'"],
    ['oversized historical offer identity',"UPDATE public.esim_orders SET offer_id=repeat('x',121)"],
  ])await scenario(name+' cannot break mixed-subject forecasting',async()=>{
    const e=await esim();await query(sql);await refresh();assert.ok(await forecast());assert.ok(await forecast(e.id));
    if(name==='oversized historical offer identity')assert.equal((await forecast(e.id)).suggested_offer_id,null);
    else assert.equal((await forecast(e.id)).suggested_amount_usd,null);
  });
  await scenario('one sample and flat usage retain expiry-only forecasts with low confidence',async()=>{
    const e=await esim();await refresh();let f=await forecast(e.id);assert.equal(f.samples_count,1);assert.equal(f.mb_per_day,null);assert.equal(f.confidence,'low');
    await samples(e.id,[[-4,500],[-2,500]]);await refresh();f=await forecast(e.id);
    assert.equal(f.method,'default');assert.equal(f.confidence,'low');assert.equal(f.days_remaining,10);
  });
  await scenario('sparse samples fit their real day span and data increases reset the fit',async()=>{
    const e=await esim();await samples(e.id,[[-10,1000],[-5,900],[-2,600]]);await refresh();
    assert.equal(Number((await forecast(e.id)).mb_per_day),50);
    await query('UPDATE public.user_esims SET data_remaining_mb=950 WHERE id=$1',[e.id]);await refresh();
    assert.equal((await forecast(e.id)).mb_per_day,null);assert.equal((await forecast(e.id)).samples_count,1);
  });
  await scenario('future, invalid, mismatched-total and pre-purchase samples do not poison a current fit',async()=>{
    const e=await esim();await samples(e.id,[[-25,1000],[-5,-1],[-4,900],[-3,1500],[-2,700],[1,1]]);
    await refresh();assert.equal(Number((await forecast(e.id)).mb_per_day),100);
    await query('UPDATE public.user_esims SET data_total_mb=2000 WHERE id=$1',[e.id]);await refresh();
    assert.equal((await forecast(e.id)).mb_per_day,null);
  });
  await scenario('unlimited/zero baselines and stale provider checks never manufacture daily usage samples',async()=>{
    const e=await esim({total:0,remaining:0,expiry:'NULL'});await refresh();assert.equal((await forecast(e.id)).predicted_depletion_at,null);
    assert.equal(await value('SELECT count(*)::int AS value FROM public.esim_usage_samples'),0);
    await query("UPDATE public.user_esims SET data_total_mb=1000,data_remaining_mb=500; UPDATE public.esim_offers_cache SET is_unlimited=true");
    await refresh();assert.equal(await value('SELECT count(*)::int AS value FROM public.esim_usage_samples'),0);
    await query("UPDATE public.esim_offers_cache SET is_unlimited=false; UPDATE public.user_esims SET last_usage_check=now()-interval '2 days'");
    await refresh();await refresh();assert.equal(await value('SELECT count(*)::int AS value FROM public.esim_usage_samples'),1);
    assert.equal(await value("SELECT bool_and(sampled_on=(now() AT TIME ZONE 'UTC')::date-2) AS value FROM public.esim_usage_samples"),true);
  });
  for(const change of ["status='expired'","status='depleted'","expires_at=now()-interval '1 second'","user_id=NULL"])
    await scenario(change+' removes the old eSIM forecast while preserving physical work',async()=>{
      const e=await esim();await refresh();assert.ok(await forecast(e.id));await query('UPDATE public.user_esims SET '+change+' WHERE id=$1',[e.id]);
      await refresh();assert.equal(await forecast(e.id),undefined);assert.ok(await forecast());
    });
  await scenario('manual owner recharge recomputes immediately through the protected invoker core',async()=>{
    await role('authenticated');const result=await value('SELECT public.record_manual_external_recharge($1,now(),5,NULL) AS value',[line]);
    assert.equal(result.success,true);await query('RESET ROLE');assert.equal((await forecast()).days_remaining,76);
  });
  await scenario('manual household manager works while unrelated/viewer callers remain denied',async()=>{
    await role('authenticated',other);await rejected('SELECT public.record_manual_external_recharge($1)','KS404',[line]);await query('RESET ROLE');
    await query("INSERT INTO public.household_members(owner_id,member_email,member_id,role,invite_status) VALUES($1,'other@example.invalid',$2,'viewer','accepted')",[user,other]);
    await role('authenticated',other);await rejected('SELECT public.record_manual_external_recharge($1)','KS404',[line]);await query('RESET ROLE');
    await query("UPDATE public.household_members SET role='manager'");await role('authenticated',other);
    await query('SELECT public.record_manual_external_recharge($1)',[line]);await query('RESET ROLE');assert.equal((await forecast()).days_remaining,76);
  });
  await scenario('unexpected eSIM errors invalidate stale predictions, preserve physical work and report a sanitized diagnostic',async()=>{
    const e=await esim();await refresh();
    await query(`CREATE FUNCTION public.fixture_esim_failure() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
      IF NEW.subject_kind='esim' THEN RAISE EXCEPTION 'private supplier payload' USING ERRCODE='23514'; END IF; RETURN NEW; END $$;
      CREATE TRIGGER fixture_fail BEFORE INSERT ON public.sim_line_usage_forecast FOR EACH ROW EXECUTE FUNCTION public.fixture_esim_failure()`);
    const start=notices.length;await refresh();assert.ok(await forecast());assert.equal((await forecast(e.id)).predicted_depletion_at,null);
    assert.deepEqual(await value('SELECT details AS value FROM public.system_alerts'),{stage:'esim_compute',sqlstate:'23514'});
    assert.ok(notices.slice(start).some(n=>n.includes('eSIM stage failed')));assert.ok(notices.slice(start).every(n=>!n.includes('private')));
  });
  await scenario('snapshot failures and alert outbox failures cannot roll back valid forecasts',async()=>{
    await esim();await query("UPDATE public.sim_lines SET last_topup_at=now()-interval '75 days'");
    await query(`CREATE FUNCTION public.fixture_failure() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'private failure' USING ERRCODE='23514'; END $$;
      CREATE TRIGGER fixture_sample BEFORE INSERT ON public.esim_usage_samples FOR EACH ROW EXECUTE FUNCTION public.fixture_failure();
      CREATE TRIGGER fixture_job BEFORE INSERT ON public.notification_dispatch_jobs FOR EACH ROW EXECUTE FUNCTION public.fixture_failure()`);
    const start=notices.length;const result=await refresh();assert.equal(result.forecasts,2);assert.equal(result.esim_samples,0);assert.equal(result.alerts,0);
    assert.equal((await forecast()).days_remaining,1);assert.equal((await forecast()).last_alert_at,null);
    assert.ok(notices.slice(start).some(n=>n.includes('snapshot failed')));assert.ok(notices.slice(start).some(n=>n.includes('alerts failed')));
  });
  await scenario('successful forecast alerts use the durable outbox with honest delivery and repeat-sweep suppression',async()=>{
    await query("UPDATE public.sim_lines SET last_topup_at=now()-interval '75 days'");
    assert.equal((await refresh()).alerts,1);assert.equal((await refresh()).alerts,0);
    assert.equal(await value('SELECT count(*)::int AS value FROM public.notification_dispatch_jobs'),1);
    assert.equal(await value('SELECT cardinality(delivered_via) AS value FROM public.notifications'),0);
  });
  await scenario('bulk entry points reject clients and forged service claims but permit the actual service identity',async()=>{
    for(const name of ['anon','authenticated']){
      await role(name);
      for(const fn of ['compute_usage_forecasts','compute_usage_forecasts_internal','refresh_usage_forecasts','snapshot_esim_usage','emit_forecast_depletion_alerts'])await rejected('SELECT public.'+fn+'()','42501');
      await query('RESET ROLE');
    }
    await query('GRANT EXECUTE ON FUNCTION public.compute_usage_forecasts(),public.compute_usage_forecasts_internal() TO authenticated');
    await role('authenticated');await query("SELECT set_config('request.jwt.claims','{\"role\":\"service_role\"}',true)");
    await rejected('SELECT public.compute_usage_forecasts()','42501');await rejected('SELECT public.compute_usage_forecasts_internal()','42501');await query('RESET ROLE');
    await role('service_role');assert.equal((await refresh()).forecasts,1);await query('RESET ROLE');
  });
  await scenario('catalog checks preserve exact API/core execution grants and safe search paths',async()=>{
    assert.deepEqual((await query(await read('supabase/tests/usage_forecast_contract_tests.sql'))).rows,[]);
  });
  const a=await connect(),b=await connect();await a.query('BEGIN');await a.query('SELECT public.refresh_usage_forecasts()');
  const overlap=b.query('SELECT public.refresh_usage_forecasts()');
  let blocked=false;
  for(let i=0;i<100;i++){
    if(await value('SELECT $1::int=ANY(pg_blocking_pids($2::int)) AS value',[a.processID,b.processID])){blocked=true;break;}
    await new Promise(resolve=>setTimeout(resolve,10));
  }
  assert.equal(blocked,true);await a.query('COMMIT');await overlap;
  assert.equal(await value('SELECT count(*)::int AS value FROM public.sim_line_usage_forecast'),1);
  passed++;console.log('PASS overlapping native postgres refresh sessions serialize and upsert one physical row');
  console.log(`${passed} usage forecast scenarios passed`);
}finally{await Promise.allSettled(clients.map(c=>c.end()));await server.stop();await fs.rm(directory,{recursive:true,force:true});}
