import assert from 'node:assert/strict';
import fs from 'node:fs';
import {PGlite} from '@electric-sql/pglite';
const root=new URL('../../',import.meta.url), read=p=>fs.readFileSync(new URL(p,root),'utf8');
const db=new PGlite(), dump=read('supabase/baselines/development-20261019/public.sql');
const q=async(s,p=[]) => (await db.query(s,p)).rows;
const one=async(s,p=[]) => (await q(s,p))[0]?.v;
const owner='10000000-0000-4000-8000-000000000001',other='10000000-0000-4000-8000-000000000002';
let passed=0;
const test=async(name,fn)=>{await db.exec('BEGIN');try{await fn();passed++;console.log('PASS '+name);}finally{await db.exec('ROLLBACK');}};
const deny=async(s)=>{await db.exec('SAVEPOINT denied');try{await assert.rejects(()=>db.exec(s),/permission denied|Service role required/);}finally{await db.exec('ROLLBACK TO denied');}};
const sweep=()=>one('select public.service_esim_emit_alerts() v');
const count=()=>one('select count(*)::int v from public.notifications');
let profile,order;
const active=async(extra='')=>{await q(`update public.user_esims set profile_state='active',bundle_state='active',installation_state='enabled',
 data_total_bytes=1000,data_remaining_bytes=150,data_used_bytes=850,last_usage_check=now(),usage_observed_at=now(),last_observation_at=now(),usage_error_code=null where id=$1`,[profile]);if(extra)await q('update user_esims set '+extra.slice(1)+' where id=$1',[profile]);};
try {
 await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role BYPASSRLS;
 CREATE SCHEMA auth; GRANT USAGE ON SCHEMA auth,public TO anon,authenticated,service_role;
 CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
 CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS $$select current_setting('request.jwt.claim.role',true)$$;
 CREATE TABLE profiles(id uuid PRIMARY KEY); CREATE TABLE sim_lines(id uuid,user_id uuid);
 CREATE FUNCTION public.assert_admin() RETURNS void LANGUAGE sql AS $$select$$;
 CREATE FUNCTION public.admin_log(text,text,text,jsonb,jsonb,text) RETURNS void LANGUAGE sql AS $$select$$;`);
 for(const table of ['esim_orders','user_esims','system_configs','notifications','alert_settings','notification_dispatch_jobs','user_preferences','notification_channels','notification_channel_catalog']) {
  const start=dump.indexOf('CREATE TABLE public.'+table+' (');assert(start>=0,table);
  await db.exec(dump.slice(start,dump.indexOf('\n);',start)+4));
 }
 await db.exec(`ALTER TABLE esim_orders ADD PRIMARY KEY(id); ALTER TABLE esim_orders ADD COLUMN catalogue_snapshot jsonb;
 ALTER TABLE user_esims ADD PRIMARY KEY(id); ALTER TABLE user_esims ADD UNIQUE(iccid);
 ALTER TABLE system_configs ADD PRIMARY KEY(config_key);
 ALTER TABLE notifications ADD PRIMARY KEY(id);
 ALTER TABLE alert_settings ADD UNIQUE(user_id,category);
 ALTER TABLE notification_dispatch_jobs ADD UNIQUE(notification_id);
 CREATE FUNCTION public.notification_channel_eligible(uuid,uuid,text,text) RETURNS boolean LANGUAGE sql AS $$select true$$;
 SELECT set_config('request.jwt.claim.role','service_role',false);
 `);
 await db.exec(read('docs/reviews/esimaccess-alerts-20261028/evidence/notification-trigger-before.sql'));
 await db.exec('CREATE TRIGGER trg_on_notification_created AFTER INSERT ON notifications FOR EACH ROW EXECUTE FUNCTION trg_fn_dispatch_notification()');
 await db.exec(read('supabase/migrations/20261027235408_esim_profile_identity_lifecycle.sql'));
 await db.exec(read('supabase/migrations/20261027235409_esim_event_inbox_reconciliation.sql'));
 await db.exec(read('supabase/migrations/20261028013756_esim_actionable_alerts.sql'));
 console.log('PASS ESIM-03/04/05 compile against captured table shapes');passed++;
 await db.exec(`insert into profiles values('${owner}'),('${other}');
 insert into notification_channel_catalog(channel_key,label,is_globally_enabled,min_tier,sort_order)
 values('push','Push',true,'basic',1),('telegram','Telegram',true,'basic',2);
 insert into notification_channels(user_id,channel_type,is_enabled) values('${owner}','push',true),('${owner}','telegram',true);
 update esim_private.accounts set new_sales_enabled=true;`);
 order=await one("insert into esim_orders(user_id,provider,bundle_name,quantity,wholesale_price_usd,retail_price_usd,markup_percent,status) values($1,'esimaccess','FIXTURE',1,1,1.4,40,'pending') returning id v",[owner]);
 profile=await one(`insert into user_esims(user_id,order_id,provider,bundle_name,iccid,smdp_address,matching_id,lpa_string,status,data_total_mb,data_remaining_mb,
 supplier_account_id,supplier_profile_ref,profile_state,installation_state,bundle_state,last_observation_at)
 select $1,$2,'esimaccess','FIXTURE','8900000000000000001','fixture.invalid','private','LPA:1$fixture.invalid$private','active',0,0,
 id,'FIXTURE_PROFILE','issued','released','not_started',now() from esim_private.accounts returning user_esims.id v`,[owner,order]);
 await test('ready alert is durable, minimal, owner-bound and push-only',async()=>{
  assert.equal((await sweep()).created,1);assert.equal((await sweep()).created,0);
  const [n]=await q('select * from notifications'); assert.equal(n.user_id,owner);assert.equal(n.target.id,profile);
  assert.equal(n.target.route,'/esim/profiles/:id');assert.deepEqual(n.delivered_via,[]);
  assert(!JSON.stringify(n).includes('private'));assert(!JSON.stringify(n).includes('8900000'));
  const [j]=await q('select * from notification_dispatch_jobs'); assert.deepEqual(j.payload.channels,['push']);assert.equal(j.state,'pending');
 });
 await test('event hints and repeated polling share one saved-state alert policy',async()=>{
  await active();await sweep();const n=await count();await sweep();await sweep();assert.equal(await count(),n);
  assert.equal(await one("select count(*)::int v from notifications where event_type='esim_low_data'"),1);
 });
 await test('20 percent then 10 percent alerts happen once each',async()=>{
  await active();await sweep();await q('update user_esims set data_remaining_bytes=90 where id=$1',[profile]);await sweep();await sweep();
  assert.equal(await one("select count(*)::int v from notifications where event_type='esim_low_data'"),2);
 });
 await test('first observation below critical suppresses the weaker threshold',async()=>{
  await active(',data_remaining_bytes=50');await sweep();await q('update user_esims set data_remaining_bytes=150 where id=$1',[profile]);await sweep();
  assert.equal(await one("select count(*)::int v from notifications where event_type='esim_low_data'"),1);
 });
 await test('unknown zero-total stale failed and inconsistent usage cannot trigger low-data',async()=>{
  for(const extra of [',data_total_bytes=0',',data_remaining_bytes=null',",usage_error_code='FAILED'",",last_usage_check=now()-interval '8 hours'",",usage_observed_at=now()-interval '8 hours'",',data_remaining_bytes=2000']) {
   await active(extra);await sweep();
  }
  assert.equal(await one("select count(*)::int v from notifications where event_type='esim_low_data'"),0);
 });
 await test('genuine zero remaining is alertable, stale lifecycle is not',async()=>{
  await active(",data_remaining_bytes=0,last_observation_at=now()-interval '8 hours'");await sweep();assert.equal(await count(),0);
  await active(',data_remaining_bytes=0');await sweep();assert.equal(await one("select count(*)::int v from notifications where event_type='esim_low_data'"),1);
 });
 await test('opt-outs survive seeding and suppress alerts and dispatch',async()=>{
  await db.exec("update alert_settings set is_enabled=false where category in ('esim_updates','esim_low_data')");
  await active();await sweep();assert.equal(await count(),0);assert.equal(await one('select count(*)::int v from notification_dispatch_jobs'),0);
 });
 await test('expiry uses provider truth; purchase date never makes an expired event',async()=>{
  await active(",confirmed_expires_at=now()+interval '36 hours'");await sweep();
  assert.equal(await one("select count(*)::int v from notifications where event_type='esim_near_expiry'"),1);
  await q("update user_esims set confirmed_expires_at=now()-interval '1 second' where id=$1",[profile]);await sweep();
  assert.equal(await one("select count(*)::int v from notifications where event_type='esim_expired'"),0);
  await q("update user_esims set bundle_state='expired',profile_state='expired' where id=$1",[profile]);await sweep();
  assert.equal(await one("select count(*)::int v from notifications where event_type='esim_expired'"),1);
 });
 await test('delayed push rechecks ownership, freshness and current entitlement cycle',async()=>{
  await active();await sweep();const n=await one("select id v from notifications where event_type='esim_low_data'");
  assert.equal(await one('select service_esim_alert_is_current($1) v',[n]),true);
  await q('update user_esims set user_id=$1 where id=$2',[other,profile]);assert.equal(await one('select service_esim_alert_is_current($1) v',[n]),false);
  await q('update user_esims set user_id=$1,usage_error_code=\'FAILED\' where id=$2',[owner,profile]);assert.equal(await one('select service_esim_alert_is_current($1) v',[n]),false);
 });
 await test('a verified new entitlement resets thresholds once; replay and usage corrections do not',async()=>{
  await active();await sweep();const first=await one('select cycle_id v from esim_private.alert_profile_state');
  await q('update user_esims set data_total_bytes=2000,data_remaining_bytes=1500 where id=$1',[profile]);await sweep();
  await active();await sweep();assert.equal(await one("select count(*)::int v from notifications where event_type='esim_low_data'"),1);
  const next=await one("select esim_private.open_alert_cycle($1,'verified-recharge:fixture') v",[profile]);assert.notEqual(next,first);
  await sweep();await one("select esim_private.open_alert_cycle($1,'verified-recharge:fixture') v",[profile]);await sweep();
  await one("select esim_private.open_alert_cycle($1,$2) v",[profile,'issuance:'+order]);
  assert.equal(await one('select cycle_id v from esim_private.alert_profile_state'),next);
  assert.equal(await one("select count(*)::int v from notifications where event_type='esim_low_data'"),2);
  assert.equal(await one("select count(*)::int v from notifications where event_type='esim_activated'"),1);
 });
 await test('order results deduplicate without suggesting financial settlement',async()=>{
  await q("update esim_private.order_runs set state='support_required' where order_id=$1",[order]);await sweep();await sweep();
  const [n]=await q("select * from notifications where event_type='esim_order_support_required'");
  assert.equal(n.target.id,order);assert.equal(n.target.route,'/esim/orders/:id');assert.match(n.body,/does not confirm a refund/);
 });
 await test('notification deletion does not permit a repeat send',async()=>{
  await sweep();await db.exec('delete from notification_dispatch_jobs;delete from notifications');await sweep();assert.equal(await count(),0);
 });
 await test('disabled policy stops generation and delayed delivery',async()=>{
  await sweep();const n=await one('select id v from notifications limit 1');await db.exec('update esim_private.alert_policy set enabled=false');
  assert.equal((await sweep()).enabled,false);assert.equal(await one('select service_esim_alert_is_current($1) v',[n]),false);
 });
 await test('clients cannot call service APIs or reset cycles',async()=>{
  for(const role of ['anon','authenticated']) {
   await db.exec(`set local role ${role};select set_config('request.jwt.claim.role','${role}',true)`);
   await deny('select public.service_esim_emit_alerts()');await deny(`select public.service_esim_alert_is_current(gen_random_uuid())`);
   await deny('select * from esim_private.alert_events');await db.exec('reset role');
  }
 });
 console.log(`${passed} ESIM-05 SQL scenario groups passed; no external calls`);
} catch(error) {console.error(error.message);process.exitCode=1;} finally {await db.close();}
