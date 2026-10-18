import assert from 'node:assert/strict';
import fs from 'node:fs';
import migrationSource from '../migration-source.cjs';
import { pathToFileURL } from 'node:url';
import { bootstrap } from './bootstrap.mjs';
const {PGlite}=await import(process.env.PGLITE_MODULE_PATH?pathToFileURL(process.env.PGLITE_MODULE_PATH).href:'@electric-sql/pglite');
let db, server, directory;
if(process.env.SECOND_NUMBER_NATIVE==='1') {
  const {default:EmbeddedPostgres}=await import(process.env.EMBEDDED_POSTGRES_MODULE_PATH ? pathToFileURL(process.env.EMBEDDED_POSTGRES_MODULE_PATH).href : 'embedded-postgres');
  const os=await import('node:os');const path=await import('node:path');
  directory=fs.mkdtempSync(path.join(os.tmpdir(),'second-number-postgres-'));
  server=new EmbeddedPostgres({databaseDir:directory,user:'postgres',password:'isolated-test',port:56549,persistent:false,
    initdbFlags:['--locale=C'],postgresFlags:['-h','127.0.0.1','-k','/tmp'],onLog:()=>{},onError:()=>{}});
  await server.initialise();await server.start();
  const client=server.getPgClient();await client.connect();
  db={exec:sql=>client.query(sql),query:(sql,args)=>client.query(sql,args),close:async()=>{await client.end();await server.stop();fs.rmSync(directory,{recursive:true,force:true});}};
} else db=new PGlite();
const read=p=>fs.readFileSync(new URL('../../'+p,import.meta.url),'utf8');
let count=0, failed=false;
const test=async(name,run)=>{await run();console.log('PASS '+name);count++;};
try {
  await bootstrap(db);
  // Actual legacy DID table, alongside the captured production wallet contracts.
  const legacy=migrationSource('20260921020000_virtual_did_numbers.sql');
  await db.exec(legacy.slice(0,legacy.indexOf('-- 2. Security-Definer')));
  // Captured export grants ALL to both client roles on this table.
  await db.exec('GRANT ALL ON public.virtual_did_numbers TO anon,authenticated,service_role');
  await db.exec(`CREATE TABLE public.offline_refill_endpoints(phone_number text,channel text,is_active boolean);
    CREATE OR REPLACE FUNCTION public.is_user_suspended() RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT coalesce((auth.jwt()->'app_metadata'->>'is_suspended')::boolean,false) $$;
    CREATE PUBLICATION supabase_realtime;`);
  const migration=fs.readdirSync(new URL('../../supabase/migrations',import.meta.url)).find(f=>f.endsWith('_second_number_inbox_and_lifecycle.sql'));
  await db.exec(read('supabase/migrations/'+migration));
  await db.exec(read('supabase/migrations/20261018040000_second_number_financial_safety.sql'));
  const user='10000000-0000-4000-8000-000000000001';
  const other='10000000-0000-4000-8000-000000000002';
  await db.exec(`insert into auth.users(id,email) values('${user}','second@test.invalid'),('${other}','other@test.invalid');
    insert into public.profiles(id,email) values('${user}','second@test.invalid'),('${other}','other@test.invalid');
    select set_config('request.jwt.claims','{"role":"service_role"}',false);
    select public.credit_wallet_for_deposit('${user}',20,'fixture','paypal_second', '{"paypal_capture_id":"second"}');
    insert into public.second_number_policies values('GB','mobile','United Kingdom',true,5,'Incoming SMS included in the approved pilot subscription.','pilot','not_required',now());`);
  const quote=async(number='+447700900123')=>(await db.query(`insert into public.second_number_orders(user_id,phone_number,country_code,country_name,number_type,wholesale_monthly_usd,monthly_fee_usd,service_fee_usd,setup_fee_usd,terms,wholesale_setup_usd,quote_contract_version)
    values($1,$2,'GB','United Kingdom','mobile',4,5,1,0,'{"version":"pilot","kyc_status":"not_required"}',0,1) returning id`,[user,number])).rows[0].id;
  const begin=async(id)=>(await db.query('select public.authorize_second_number_purchase($1,$2,true,4,0) value',[user,id])).rows[0].value;
  const id=await quote();
  await test('disabled purchase gate and changed supplier quote cannot reserve or submit',async()=>{
    await assert.rejects(begin(id),/disabled/);
    await db.query('update public.second_number_purchase_gate set enabled=true,pilot_user_ids=ARRAY[$1]::uuid[]',[user]);
    await assert.rejects(db.query('select public.authorize_second_number_purchase($1,$2,true,9,0)',[user,id]),/price changed/);
    assert.equal((await db.query('select count(*)::int n from public.wallet_holds')).rows[0].n,0);
  });
  await test('purchase reservation is stable and a second request never resubmits',async()=>{
    assert.equal((await begin(id)).submit,true);assert.equal((await begin(id)).submit,false);
    assert.equal((await db.query('select count(*)::int n from public.wallet_holds')).rows[0].n,1);
    assert.equal(Number((await db.query('select balance from public.wallets where user_id=$1',[user])).rows[0].balance),20);
  });
  if(server) await test('independent sessions allow exactly one submission for a shared purchase',async()=>{
    const race=await quote('+447700900789');const clients=[server.getPgClient(),server.getPgClient()];
    try {
      for(const client of clients){await client.connect();await client.query('SET ROLE service_role');await client.query("select set_config('request.jwt.claims','{\"role\":\"service_role\"}',false)");}
      const attempts=await Promise.all(clients.map(c=>c.query('select public.authorize_second_number_purchase($1,$2,true,4,0) value',[user,race])));
      assert.deepEqual(attempts.map(r=>r.rows[0].value.submit).sort(),[false,true]);
      await db.query('select public.fail_second_number_purchase($1)',[race]);
    } finally {for(const client of clients)await client.end();}
  });
  await test('expired quotes and other reservations prevent a new supplier submission',async()=>{
    const blocked=await quote('+447700902222');
    await db.exec('BEGIN');
    try {
      await db.query("update public.second_number_orders set expires_at=now()-interval '1 second' where id=$1",[blocked]);
      await assert.rejects(begin(blocked),/Quote expired/);
    } finally {await db.exec('ROLLBACK');}
    await db.exec('BEGIN');
    try {
      await db.query("select public.reserve_wallet_funds($1,15,'second_number','other-budget','fixture',120)",[user]);
      await assert.rejects(begin(blocked),/Insufficient available balance/);
    } finally {await db.exec('ROLLBACK');}
    assert.equal((await db.query('select state from public.second_number_orders where id=$1',[blocked])).rows[0].state,'quoted');
    await assert.rejects(db.query('select public.authorize_second_number_purchase($1,$2,true,4,0)',[other,blocked]),/Quote unavailable/);
  });
  await test('capture rejects an amount changed after reservation without activating service',async()=>{
    await db.exec('BEGIN');
    try {
      await db.query('update public.second_number_orders set monthly_fee_usd=6 where id=$1',[id]);
      await assert.rejects(db.query("select public.finish_second_number_purchase($1,'provider-order','provider-number')",[id]),/Reservation mismatch/);
    } finally {await db.exec('ROLLBACK');}
    assert.equal((await db.query('select count(*)::int n from public.virtual_did_numbers')).rows[0].n,0);
  });
  await test('ledger failure rolls back capture and never creates active service',async()=>{
    await db.exec('BEGIN');
    try {
      await db.exec("CREATE FUNCTION pg_temp.reject_did_ledger() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'injected capture failure'; END $$; CREATE TRIGGER reject_did_ledger BEFORE INSERT ON public.wallet_transactions FOR EACH ROW EXECUTE FUNCTION pg_temp.reject_did_ledger();");
      await assert.rejects(db.query("select public.finish_second_number_purchase($1,'provider-order','provider-number')",[id]),/injected capture failure/);
    } finally {await db.exec('ROLLBACK');}
    assert.equal((await db.query('select count(*)::int n from public.virtual_did_numbers')).rows[0].n,0);
    assert.equal((await db.query('select h.status from public.wallet_holds h join public.second_number_orders o on o.hold_id=h.id where o.id=$1',[id])).rows[0].status,'active');
    assert.equal(Number((await db.query('select balance from public.wallets where user_id=$1',[user])).rows[0].balance),20);
  });
  let did;
  await test('activation captures wallet and funding once and retries preserve identity',async()=>{
    did=(await db.query("select public.finish_second_number_purchase($1,'provider-order','provider-number') id",[id])).rows[0].id;
    assert.equal((await db.query("select public.finish_second_number_purchase($1,'provider-order','provider-number') id",[id])).rows[0].id,did);
    assert.equal(Number((await db.query('select balance from public.wallets where user_id=$1',[user])).rows[0].balance),15);
    assert.equal(Number((await db.query('select sum(remaining_amount) n from public.wallet_funding_lots where user_id=$1',[user])).rows[0].n),15);
    await assert.rejects(db.query("select public.finish_second_number_purchase($1,'wrong-order','provider-number')",[id]));
  });
  const sms=async(message='sms-1',text='Your code is 482-910',to='+447700900123',time=new Date(Date.now()+1000).toISOString())=>(await db.query("select public.route_second_number_sms('telnyx',$1,$2,'Example',$3,$4) value",[message,to,text,time])).rows[0].value;
  await test('message deduplication creates one private notification and code candidate',async()=>{
    assert.equal((await sms()).stored,true);assert.equal((await sms()).stored,false);
    const rows=(await db.query('select * from public.virtual_did_messages')).rows;assert.equal(rows.length,1);assert.equal(rows[0].extracted_otp,'482910');
    const notices=(await db.query("select title,body,template_data from public.notifications where source_event_key='did_sms:telnyx:sms-1'")).rows;
    assert.equal(notices.length,1);assert.ok(!JSON.stringify(notices).includes('482'));
    await assert.rejects(sms('sms-1','Altered content'));
  });
  await test('ambiguous numeric content has no suggested code',async()=>{
    await sms('sms-2','Code 123456, account 987654');
    assert.equal((await db.query("select extracted_otp from public.virtual_did_messages where provider_msg_id='sms-2'")).rows[0].extracted_otp,null);
  });
  await test('unknown recipients are ignored and only registered refill destinations route to commands',async()=>{
    assert.equal((await sms('unknown','REFILL 10','+19999999999')).route,'ignore');
    await db.exec("insert into public.offline_refill_endpoints values('+19999999999','sms',true)");
    assert.equal((await sms('registered','REFILL 10','+19999999999')).route,'refill');
    assert.equal((await sms('stale','old code','+447700900123','2000-01-01T00:00:00Z')).stored,false);
  });
  await test('client message writes and trusted financial calls are denied',async()=>{
    await db.exec('begin; set local role authenticated');
    await db.query("select set_config('request.jwt.claims',$1,true)",[JSON.stringify({sub:other,role:'authenticated'})]);
    assert.equal((await db.query('select * from public.virtual_did_messages')).rows.length,0);
    await assert.rejects(db.query('select public.request_second_number_release($1)',[did]),/Number unavailable/);
    await db.exec('rollback');
    await db.exec('begin; set local role authenticated');
    await assert.rejects(db.query('update public.virtual_did_messages set body=\'changed\''),e=>e.code==='42501');await db.exec('rollback');
    await db.exec('begin; set local role authenticated');
    await assert.rejects(db.query('select public.begin_second_number_purchase($1,$2,true)',[user,id]),e=>e.code==='42501');await db.exec('rollback');
  });
  await test('renewal debits once per original billing anchor',async()=>{
    await db.query("update public.virtual_did_numbers set renews_at=now()-interval '1 hour' where id=$1",[did]);
    const period=(await db.query('select renews_at::text as renews_at from public.virtual_did_numbers where id=$1',[did])).rows[0].renews_at;
    await db.exec('select public.process_second_number_renewals(50)');
    await db.query("select public.settle_second_number_renewal($1,$2,'provider-number')",[did,period]);
    await db.query("select public.settle_second_number_renewal($1,$2,'provider-number')",[did,period]);
    assert.equal(Number((await db.query('select balance from public.wallets where user_id=$1',[user])).rows[0].balance),10);
  });
  await test('low balance enters grace and top-up recovers without duplicate debit',async()=>{
    await db.query("update public.virtual_did_numbers set monthly_fee_usd=11,renews_at=now()-interval '1 hour' where id=$1",[did]);
    await db.exec('select public.process_second_number_renewals(50)');
    assert.equal((await db.query('select status from public.virtual_did_numbers where id=$1',[did])).rows[0].status,'suspended');
    const insufficientPeriod=(await db.query('select renews_at::text as renews_at from public.virtual_did_numbers where id=$1',[did])).rows[0].renews_at;
    assert.equal((await db.query("select public.settle_second_number_renewal($1,$2,'provider-number') ok",[did,insufficientPeriod])).rows[0].ok,false);
    await db.query("select public.credit_wallet_for_deposit($1,5,'fixture','paypal_recover','{\"paypal_capture_id\":\"recover\"}')",[user]);
    const period=(await db.query('select renews_at::text as renews_at from public.virtual_did_numbers where id=$1',[did])).rows[0].renews_at;
    await db.exec('select public.process_second_number_renewals(50)');
    await db.query("select public.settle_second_number_renewal($1,$2,'provider-number')",[did,period]);
    await db.query("select public.settle_second_number_renewal($1,$2,'provider-number')",[did,period]);
    assert.equal((await db.query('select status from public.virtual_did_numbers where id=$1',[did])).rows[0].status,'active');
    assert.equal(Number((await db.query('select balance from public.wallets where user_id=$1',[user])).rows[0].balance),4);
  });
  if(server) await test('concurrent renewals capture one period once with independent sessions',async()=>{
    await db.query("select public.credit_wallet_for_deposit($1,20,'fixture','paypal_race','{\"paypal_capture_id\":\"race\"}')",[user]);
    await db.query("update public.virtual_did_numbers set renews_at=now()-interval '1 minute',monthly_fee_usd=5 where id=$1",[did]);
    const period=(await db.query('select renews_at::text as renews_at from public.virtual_did_numbers where id=$1',[did])).rows[0].renews_at;
    const clients=[server.getPgClient(),server.getPgClient()];
    try {
      for(const c of clients){await c.connect();await c.query('SET ROLE service_role');await c.query("select set_config('request.jwt.claims','{\"role\":\"service_role\"}',false)");}
      await Promise.all(clients.map(c=>c.query("select public.settle_second_number_renewal($1,$2,'provider-number')",[did,period])));
      assert.equal(Number((await db.query('select count(*) n from public.second_number_renewals where did_id=$1 and period_start=$2',[did,period])).rows[0].n),1);
    } finally {for(const c of clients)await c.end();}
  });
  await test('cancellation and expired grace prevent charging and move toward provider release',async()=>{
    await db.exec('BEGIN');
    try {
      await db.query("update public.virtual_did_numbers set auto_renew=false,renews_at=now()-interval '1 hour' where id=$1",[did]);
      const period=(await db.query('select renews_at::text as renews_at from public.virtual_did_numbers where id=$1',[did])).rows[0].renews_at;
      assert.equal((await db.query("select public.settle_second_number_renewal($1,$2,'provider-number') ok",[did,period])).rows[0].ok,false);
      await db.exec('select public.process_second_number_renewals(50)');
      assert.equal((await db.query('select status from public.virtual_did_numbers where id=$1',[did])).rows[0].status,'release_pending');
      await db.query("update public.virtual_did_numbers set auto_renew=true,status='suspended',renews_at=now()-interval '4 days',grace_expires_at=now()-interval '1 day' where id=$1",[did]);
      await db.exec('select public.process_second_number_renewals(50)');
      assert.equal((await db.query('select status from public.virtual_did_numbers where id=$1',[did])).rows[0].status,'release_pending');
    } finally {await db.exec('ROLLBACK');}
  });
  await test('release needs the claim token and upstream confirmation; identifiers remain auditable',async()=>{
    await db.query("update public.virtual_did_numbers set status='release_pending',release_retry_at=now() where id=$1",[did]);
    const claim=(await db.query('select * from public.claim_second_number_releases(10)')).rows[0];
    await assert.rejects(db.query('select public.finish_second_number_release($1,$2,true)',[did,user]));
    await db.query('select public.finish_second_number_release($1,$2,true)',[did,claim.release_claim]);
    assert.equal((await db.query('select provider_sid from public.virtual_did_numbers where id=$1',[did])).rows[0].provider_sid,'provider-number');
    assert.equal((await sms('after-release','123456')).stored,false);
  });
  await test('confirmed failure releases the original hold, while an ambiguous order retains it',async()=>{
    await db.query("select public.credit_wallet_for_deposit($1,5,'fixture','paypal_failure','{\"paypal_capture_id\":\"failure\"}')",[user]);
    const failed=await quote('+447700900456');await begin(failed);
    await db.query('select public.fail_second_number_purchase($1)',[failed]);await db.query('select public.fail_second_number_purchase($1)',[failed]);
    assert.equal((await db.query('select state from public.second_number_orders where id=$1',[failed])).rows[0].state,'failed');
    const ambiguous=await quote('+447700900999');await begin(ambiguous);
    const held=(await db.query('select h.status,h.carrier_in_flight from public.wallet_holds h join public.second_number_orders o on o.hold_id=h.id where o.id=$1',[ambiguous])).rows[0];
    assert.equal(held.status,'active');assert.equal(held.carrier_in_flight,true);
    await db.query("update public.wallet_holds set expires_at=now()-interval '1 hour' where id=(select hold_id from public.second_number_orders where id=$1)",[ambiguous]);
    await db.exec('select public.recover_expired_wallet_holds(100)');
    assert.equal((await db.query('select h.status from public.wallet_holds h join public.second_number_orders o on o.hold_id=h.id where o.id=$1',[ambiguous])).rows[0].status,'active');
  });
  await test('legacy numbers are not silently enrolled and cannot be sold to a different rental',async()=>{
    const legacy='+447700901111';
    await db.query("insert into public.virtual_did_numbers(user_id,phone_number,country_code,country_name,provider_sid,renews_at) values($1,$2,'GB','United Kingdom','legacy-sid',now()-interval '1 hour')",[user,legacy]);
    const balance=(await db.query('select balance from public.wallets where user_id=$1',[user])).rows[0].balance;
    await db.exec('select public.process_second_number_renewals(50)');
    assert.equal((await db.query('select balance from public.wallets where user_id=$1',[user])).rows[0].balance,balance);
    const alreadyOwned=await quote(legacy);await assert.rejects(begin(alreadyOwned),/no longer available/);
  });
  await test('catalog contracts retain private tables and exact trusted RPC grants',async()=>{
    assert.deepEqual((await db.query(read('supabase/tests/second_number_contract_tests.sql'))).rows,[]);
  });
  console.log(`${count} Second Number SQL scenarios passed`);
} catch(error) {console.error('Second Number SQL failure:',error.message,error.code,error.where||'');failed=true;} finally {await db.close();if(failed)process.exitCode=1;}
