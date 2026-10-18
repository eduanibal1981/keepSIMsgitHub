// Isolated read-only state projection against captured production contracts.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {bootstrapProductionBaseline} from './bootstrap.mjs';
import {runSQLCases} from './sql-cases.mjs';
const {PGlite}=await import(process.env.PGLITE_MODULE_PATH?pathToFileURL(process.env.PGLITE_MODULE_PATH).href:'@electric-sql/pglite');
const db=new PGlite();
const read=p=>fs.readFileSync(new URL('../../'+p,import.meta.url),'utf8');
const results=[],payloads={};
const u='10000000-0000-4000-8000-000000000001',other='10000000-0000-4000-8000-000000000002';
const line='20000000-0000-4000-8000-000000000001',foreign='20000000-0000-4000-8000-000000000002';
const country='30000000-0000-4000-8000-000000000001',carrier='40000000-0000-4000-8000-000000000001';
const stock='50000000-0000-4000-8000-000000000001';
const grant='60000000-0000-4000-8000-000000000001';
const scalar=async(sql,args=[])=>(await db.query(sql,args)).rows[0].v;
const state=()=>scalar('SELECT public.offline_voucher_state() v');
async function claims(user=u,admin=false){await db.query("SELECT set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub:user,role:'authenticated',app_metadata:{is_power_user:admin}})]);}
async function scenario(name,run){await db.exec('BEGIN');try{await run();results.push({name,status:'passed'});console.log('PASS '+name);}catch(e){results.push({name,status:'failed',message:e.message,code:e.code});console.error('FAIL '+name+': '+e.message);}finally{await db.exec('ROLLBACK');}}
async function denied(sql,code='42501'){await db.exec('SAVEPOINT denied');await assert.rejects(db.query(sql),e=>e.code===code);await db.exec('ROLLBACK TO SAVEPOINT denied');}
async function request(status='open',owner=u,target=line){await db.query('INSERT INTO public.offline_voucher_requests(user_id,sim_line_id,carrier_id,status,due_at) VALUES($1,$2,$3,$4,$5)',[owner,target,carrier,status,'2026-11-01T12:00:00Z']);}
try{
 await db.exec("SET TIME ZONE 'UTC'");
 await bootstrapProductionBaseline(db);
 await db.exec(read('supabase/tests/fixtures/offline_voucher_baseline.sql'));
 await db.query('INSERT INTO auth.users(id) VALUES($1),($2)',[u,other]);
 await db.query("INSERT INTO public.profiles(id,email) VALUES($1,'owner@example.invalid'),($2,'other@example.invalid')",[u,other]);
 await db.query("INSERT INTO public.countries(id,name,iso_code,dialing_code,currency_code) VALUES($1,'Fixture','ZZ','000','USD')",[country]);
 await db.query("INSERT INTO public.carriers(id,country_id,name) VALUES($1,$2,'Fixture')",[carrier,country]);
 await db.query("INSERT INTO public.sim_lines(id,user_id,phone_number,carrier_id,plan_type) VALUES($1,$2,'+000000001',$5,'standard'),($3,$4,'+000000002',$5,'standard')",[line,u,foreign,other,carrier]);
 await db.exec("INSERT INTO public.system_configs(config_key,config_value) VALUES('OFFLINE_VOUCHER_ENABLED','true')");
 await claims();
 await scenario('original production query hides a real open request',async()=>{await request();assert.equal((await state()).lines[0].request,null);});
 await db.exec(read('supabase/migrations/20261018080000_offline_voucher_request_state.sql'));
 for(const status of ['open','fulfilled','cancelled','none'])await scenario(status+' request projects the active promise correctly',async()=>{
  if(status!=='none')await request(status);
  await db.exec('SET ROLE authenticated');const payload=await state();
  assert.equal(payload.success,true);assert.equal(payload.lines.length,1);
  if(status==='open'){assert.equal(payload.lines[0].request.reason,'no_stock');assert.equal(new Date(payload.lines[0].request.due_at).toISOString(),'2026-11-01T12:00:00.000Z');}
  else assert.equal(payload.lines[0].request,null);
  payloads[status]=payload;
 });
 await scenario('only actual lifecycle values are accepted and no-supplier reason is preserved',async()=>{
  for(const status of ['pending','processing'])await denied(`INSERT INTO public.offline_voucher_requests(user_id,sim_line_id,carrier_id,status,due_at) VALUES('${u}','${line}','${carrier}','${status}',now())`,'23514');
  await request();await db.exec("UPDATE public.offline_voucher_requests SET reason='no_automatic_source'");
  assert.equal((await state()).lines[0].request.reason,'no_automatic_source');
 });
 await scenario('closed history cannot duplicate or replace the one active request',async()=>{
  await request('fulfilled');await request('cancelled');await request('open');
  assert.equal((await state()).lines.length,1);assert.ok((await state()).lines[0].request);
  await denied(`INSERT INTO public.offline_voucher_requests(user_id,sim_line_id,carrier_id,due_at) VALUES('${u}','${line}','${carrier}',now())`,'23505');
 });
 await scenario('open request transitions to fulfilled and cancelled clear its deadline',async()=>{
  await request();assert.ok((await state()).lines[0].request);
  for(const terminal of ['fulfilled','cancelled']){await db.query('UPDATE public.offline_voucher_requests SET status=$1',[terminal]);assert.equal((await state()).lines[0].request,null);}
 });
 await scenario('another owner and malformed foreign request are not exposed',async()=>{
  await request('open',other,line);await request('open',other,foreign);
  await db.exec('SET ROLE authenticated');const s=await state();assert.equal(s.lines.length,1);assert.equal(s.lines[0].sim_line_id,line);assert.equal(s.lines[0].request,null);
 });
 await scenario('current user with no lines receives an empty list',async()=>{
  await claims('10000000-0000-4000-8000-000000000003');await db.exec('SET ROLE authenticated');assert.deepEqual((await state()).lines,[]);
 });
 await scenario('grant metadata remains visible without bearer secrets or private request notes',async()=>{
  await db.query("INSERT INTO public.offline_voucher_stock(id,carrier_id,source,pin_encrypted,pin_fingerprint,serial,face_value_usd,status) VALUES($1,$2,'manual','\\x1234','secret-fingerprint','secret-serial',5,'issued')",[stock,carrier]);
  await db.query("INSERT INTO public.offline_voucher_grants(id,user_id,sim_line_id,stock_id,status,amount_due_usd,provisioned_at) VALUES($1,$2,$3,$4,'revealed',5,'2026-10-18T00:00:00Z')",[grant,u,line,stock]);
  await request();await db.exec("UPDATE public.offline_voucher_requests SET note='private-admin-note'");
  await db.exec('SET ROLE authenticated');const s=await state();assert.equal(s.lines[0].grant.status,'revealed');assert.equal(s.lines[0].grant.face_value_usd,5);
  assert.deepEqual(Object.keys(s.lines[0].request).sort(),['due_at','reason']);
  assert.deepEqual(Object.keys(s.lines[0].grant).sort(),['amount_due_usd','expires_at','face_value_usd','id','provisioned_at','revealed_at','status']);
  assert.doesNotMatch(JSON.stringify(s),/secret-|private-admin|pin_encrypted|pin_fingerprint/);
  payloads.revealed=s;
 });
 await scenario('foreign grant on owned line is excluded',async()=>{
  await db.query("INSERT INTO public.offline_voucher_stock(id,carrier_id,source,pin_encrypted,pin_fingerprint,face_value_usd,status) VALUES($1,$2,'manual','\\x1234','foreign-secret',5,'issued')",[stock,carrier]);
  await db.query('INSERT INTO public.offline_voucher_grants(user_id,sim_line_id,stock_id) VALUES($1,$2,$3)',[other,line,stock]);
  await db.exec('SET ROLE authenticated');assert.equal((await state()).lines[0].grant,null);
 });
 await scenario('feature flag remains off or absent without changing request lifecycle',async()=>{
  await request();await db.exec("UPDATE public.system_configs SET config_value='false' WHERE config_key='OFFLINE_VOUCHER_ENABLED'");assert.equal((await state()).enabled,false);
  await db.exec("DELETE FROM public.system_configs WHERE config_key='OFFLINE_VOUCHER_ENABLED'");assert.equal((await state()).enabled,false);
  assert.equal(await scalar("SELECT status v FROM public.offline_voucher_requests"),'open');
 });
 await scenario('anonymous execution denied and missing identity fails closed',async()=>{
  await db.exec('SET ROLE anon');await denied('SELECT public.offline_voucher_state()');await db.exec('RESET ROLE');
  await db.exec("SELECT set_config('request.jwt.claims','{}',false); SET ROLE authenticated");assert.deepEqual(await state(),{success:false,code:'UNAUTHORIZED'});
 });
 await scenario('raw voucher tables remain inaccessible to customer and anonymous roles',async()=>{
  for(const role of ['authenticated','anon']){await db.exec('SET ROLE '+role);for(const table of ['offline_voucher_requests','offline_voucher_grants','offline_voucher_stock'])await denied('SELECT * FROM public.'+table);await db.exec('RESET ROLE');}
 });
 await scenario('admin queue defaults to open, terminal filters and all-history remain accurate',async()=>{
  for(const status of ['open','fulfilled','cancelled'])await request(status);
  await claims(u,true);await db.exec('SET ROLE authenticated');
  const q=async(status)=>(await db.query('SELECT status FROM public.admin_list_voucher_requests($1)',[status])).rows.map(r=>r.status);
  assert.deepEqual((await db.query('SELECT status FROM public.admin_list_voucher_requests()')).rows.map(r=>r.status),['open']);
  assert.deepEqual(await q('fulfilled'),['fulfilled']);assert.deepEqual(await q('cancelled'),['cancelled']);assert.equal((await q(null)).length,3);
 });
 await scenario('ordinary customer cannot use admin request queue',async()=>{await db.exec('SET ROLE authenticated');await denied('SELECT * FROM public.admin_list_voucher_requests()','KS460');});
 results.push(...await runSQLCases(db,read('supabase/tests/offline_voucher_state_contract_tests.sql'),'voucher state ACL'));
 if(results.some(r=>r.status==='failed'))process.exitCode=1;
 else {
  const fixture=new URL('../../test/fixtures/offline_voucher_state_payloads.json',import.meta.url);
  if(process.argv.includes('--regenerate-fixture'))fs.writeFileSync(fixture,JSON.stringify(payloads,null,2)+'\n');
  else assert.deepEqual(payloads,JSON.parse(fs.readFileSync(fixture,'utf8')),
    'Supported voucher projection changed; review before explicitly regenerating the Dart fixture');
 }
 if(process.env.FINANCIAL_TEST_REPORT)fs.writeFileSync(process.env.FINANCIAL_TEST_REPORT,JSON.stringify({environment:'isolated PGlite PostgreSQL; captured production baseline and voucher extension; no live actions',passed:results.filter(r=>r.status==='passed').length,failed:results.filter(r=>r.status==='failed').length,results},null,2)+'\n');
 console.log(`${results.filter(r=>r.status==='passed').length} passed; ${results.filter(r=>r.status==='failed').length} failed`);
}finally{await db.close();}
