import { runCallsHTTP } from './calls-http.mjs';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { randomUUID,createHmac } from 'node:crypto';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { bootstrap } from './bootstrap.mjs';

// Requires an explicitly provided, pinned PostgREST executable. This runner
// never downloads software, reads application credentials or connects remotely.
if(!process.env.POSTGREST_BINARY)throw Error('Set POSTGREST_BINARY to the verified local PostgREST executable');
const {default:EmbeddedPostgres}=await import(process.env.EMBEDDED_POSTGRES_MODULE_PATH
  ?pathToFileURL(process.env.EMBEDDED_POSTGRES_MODULE_PATH).href:'embedded-postgres');
const directory=await fs.mkdtemp(path.join(os.tmpdir(),'keepsims-scheduled-http-'));
const dbPort=Number(process.env.FINANCIAL_TEST_PORT||56553),httpPort=Number(process.env.FINANCIAL_HTTP_PORT||56554);
const server=new EmbeddedPostgres({databaseDir:directory,user:'postgres',password:'isolated-test',port:dbPort,
  persistent:false,initdbFlags:['--locale=C'],postgresFlags:['-h','127.0.0.1',...(process.platform==='win32'?[]:['-k','/tmp'])],onLog:()=>{},onError:()=>{}});
let client,api,apiError,passed=0,failed=0;const results=[];
// Set the loader path only on PostgREST; injecting it into Node/initdb can
// load incompatible libraries before this runner starts.
const postgrestLibraryPath=process.env.POSTGREST_LIBRARY_PATH||process.env.DYLD_LIBRARY_PATH;
const postgrestEnv={...process.env,...(postgrestLibraryPath?{DYLD_LIBRARY_PATH:postgrestLibraryPath}:{})};
const key='isolated-keepsims-http-signing-key-not-a-production-secret';
function token(role){
  const parts=[{alg:'HS256',typ:'JWT'},{role,exp:Math.floor(Date.now()/1000)+300}].map(x=>Buffer.from(JSON.stringify(x)).toString('base64url'));
  return [...parts,createHmac('sha256',key).update(parts.join('.')).digest('base64url')].join('.');
}
const route={provider:'dtone',offerId:'fixture-pin',offerValue:200,costUsd:2,feeUsd:0,totalChargeUsd:2,targetLocalValue:2,targetLocalCurrency:'USD'};
async function check(name,body){try{await body();passed++;results.push({name,status:'passed'});console.log('PASS '+name);}
  catch(error){failed++;results.push({name,status:'failed',message:error.message});console.error('FAIL '+name+': '+error.message);}}
async function rpc(name,args,role='service_role'){
  const response=await fetch(`http://127.0.0.1:${httpPort}/rpc/${name}`,{method:'POST',
    headers:{'Content-Type':'application/json',...(role?{Authorization:'Bearer '+token(role)}:{})},body:JSON.stringify(args),signal:AbortSignal.timeout(10000)});
  const body=await response.text();return {status:response.status,body:body?JSON.parse(body):null};
}
const scalar=async(sql,args=[])=>Object.values((await client.query(sql,args)).rows[0])[0];
try{
  await server.initialise();
  // A failed startup (for example an occupied port) must fail visibly rather
  // than let an unresolved embedded-postgres promise exit with status zero.
  let startupTimer;
  try { await Promise.race([server.start(),new Promise((_,reject)=>{startupTimer=setTimeout(()=>reject(Error('Local PostgreSQL startup timed out')),15000);})]); }
  finally { clearTimeout(startupTimer); }
  client=server.getPgClient();await client.connect();
  await bootstrap({exec:sql=>client.query(sql),query:(sql,args)=>client.query(sql,args)});
  await client.query("CREATE ROLE fixture_authenticator LOGIN NOINHERIT PASSWORD 'isolated-http'; GRANT anon,authenticated,service_role TO fixture_authenticator");
  const version=await new Promise((resolve,reject)=>{const p=spawn(process.env.POSTGREST_BINARY,['--version'],{env:postgrestEnv});let s='';p.stdout.on('data',x=>s+=x);p.on('error',reject);p.on('close',(code,signal)=>code!==0||!s.trim()?reject(Error('PostgREST version failed: '+(signal||code))):resolve(s.trim()));});
  console.log('HTTP adapter '+version);
  api=spawn(process.env.POSTGREST_BINARY,[],{env:{PATH:process.env.PATH,
    ...(postgrestLibraryPath?{DYLD_LIBRARY_PATH:postgrestLibraryPath}:{}),
    PGRST_DB_URI:`postgres://fixture_authenticator:isolated-http@127.0.0.1:${dbPort}/postgres`,
    PGRST_DB_SCHEMAS:'public',PGRST_DB_ANON_ROLE:'anon',PGRST_JWT_SECRET:key,
    PGRST_DB_POOL:'4',PGRST_SERVER_HOST:'127.0.0.1',PGRST_SERVER_PORT:String(httpPort),PGRST_LOG_LEVEL:'crit'},stdio:['ignore','ignore','pipe']});
  api.on('error',e=>{apiError=e;});let stderr='';api.stderr.on('data',x=>{stderr+=x;});
  let ready=false;
  for(let i=0;i<100;i++){
    if(apiError||api.exitCode!==null)throw Error('PostgREST failed to start: '+(apiError?.message||stderr.slice(-1500)));
    try{const r=await fetch(`http://127.0.0.1:${httpPort}/`,{signal:AbortSignal.timeout(500)});if(r.ok){ready=true;break;}}catch{}
    await new Promise(r=>setTimeout(r,100));
  }
  if(!ready)throw Error('Local PostgREST did not become ready: '+stderr.slice(-1500));
  const u=randomUUID(),l=randomUUID(),e=randomUUID();
  await client.query("INSERT INTO public.payment_gateways(code,name) VALUES('wallet','Fixture wallet')");
  await client.query("INSERT INTO public.app_fee_rules(appfees_item,version,free_percentage,free_minimum,stand_percentage,stand_minimum,prem_percentage,prem_minimum,status) VALUES('refills',9999999,0,0,0,0,0,0,'published')");
  await client.query('INSERT INTO auth.users(id,email) VALUES($1,$2)',[u,u+'@fixture.test']);
  await client.query('INSERT INTO public.profiles(id,email) VALUES($1,$2)',[u,u+'@fixture.test']);
  await client.query("INSERT INTO public.sim_lines(id,user_id,phone_number,plan_type,plan_expires_at) VALUES($1,$2,'+15550001010','premium',now()+interval '1 year')",[l,u]);
  await client.query('SELECT public.ensure_wallet_v2($1)',[u]);
  await client.query("SELECT public.credit_wallet_for_deposit($1::uuid,20,'fixture',$2,jsonb_build_object('paypal_capture_id',$1::text))",[u,'paypal_'+u]);
  await client.query("INSERT INTO public.topup_executions(id,user_id,sim_line_id,execution_type,status,amount,base_cost_usd,app_fee_usd,currency,payment_gateway_code,max_authorized_usd,fulfillment_gateway) VALUES($1,$2,$3,'refill_custom','processing',2,2,0,'USD','wallet',3,'API')",[e,u,l]);
  await check('HTTP anonymous and authenticated callers cannot invoke worker money RPCs',async()=>{
    for(const role of [null,'authenticated'])for(const [name,args] of [
      ['prepare_scheduled_refill',{p_execution_id:e,p_route:route}],
      ['begin_scheduled_refill_submission',{p_execution_id:e,p_hold_id:randomUUID(),p_route:route}],
      ['settle_successful_execution',{p_execution_id:e,p_provider_tx_id:'fixture-proof'}],
      ['stop_scheduled_refill_before_submission',{p_execution_id:e,p_reason:'fixture'}]
    ]){const r=await rpc(name,args,role);assert.ok([401,403,404].includes(r.status),JSON.stringify(r));assert.notEqual(r.body?.code,'PGRST203');}
  });
  await check('HTTP settlement without a funded hold is rejected',async()=>{
    const r=await rpc('settle_successful_execution',{p_execution_id:e,p_provider_tx_id:'fixture-proof'});
    assert.equal(r.status,400);assert.match(r.body.message,/reservation/);
  });
  let prepared;
  await check('HTTP preparation resolves named JSON route and persists a funded hold',async()=>{
    const r=await rpc('prepare_scheduled_refill',{p_execution_id:e,p_route:route});
    assert.equal(r.status,200,JSON.stringify(r));prepared=r.body;assert.ok(prepared.hold_id);
  });
  await check('HTTP submission rejects a wrong-currency reservation',async()=>{
    await client.query("UPDATE public.wallet_holds SET currency='EUR' WHERE id=$1",[prepared.hold_id]);
    const r=await rpc('begin_scheduled_refill_submission',{p_execution_id:e,p_hold_id:prepared.hold_id,p_route:prepared.route});
    assert.equal(r.status,400);assert.match(r.body.message,/reservation/);
    await client.query("UPDATE public.wallet_holds SET currency='USD' WHERE id=$1",[prepared.hold_id]);
  });
  await check('HTTP submission commits the marker with the exact worker arguments',async()=>{
    const r=await rpc('begin_scheduled_refill_submission',{p_execution_id:e,p_hold_id:prepared.hold_id,p_route:prepared.route});
    assert.ok([200,204].includes(r.status),JSON.stringify(r));
    assert.equal(await scalar('SELECT carrier_in_flight FROM public.topup_executions WHERE id=$1',[e]),true);
  });
  await check('HTTP duplicate full settlement payloads capture once and retain PIN details',async()=>{
    const args={p_execution_id:e,p_provider_tx_id:'fixture-proof',p_hold_id:prepared.hold_id,
      p_pin_code:'1234',p_pin_serial:'serial',p_redeem_instructions:'Dial code',p_metadata:{provider:'dtone'}};
    const settled=await Promise.all([rpc('settle_successful_execution',args),rpc('settle_successful_execution',args)]);
    for(const r of settled){assert.equal(r.status,200,JSON.stringify(r));assert.equal(r.body.success,true);}
    assert.equal(Number(await scalar('SELECT balance FROM public.wallets WHERE user_id=$1',[u])),18);
    assert.equal(Number(await scalar("SELECT count(*) FROM public.wallet_transactions WHERE user_id=$1 AND type='topup_debit'",[u])),1);
    assert.equal(await scalar('SELECT pin_code FROM public.topup_executions WHERE id=$1',[e]),'1234');
  });
  await check('HTTP omitted optional settlement fields resolve without PGRST203',async()=>{
    const r=await rpc('settle_successful_execution',{p_execution_id:e,p_provider_tx_id:'fixture-proof'});
    assert.equal(r.status,200,JSON.stringify(r));assert.equal(r.body.idempotent,true);
    const stopped=await rpc('stop_scheduled_refill_before_submission',{p_execution_id:e,p_reason:'stale worker'});
    assert.equal(stopped.status,200,JSON.stringify(stopped));assert.equal(stopped.body.reconciliation_required,true);
  });
  await check('HTTP retired status overloads are unavailable',async()=>{
    for(const args of [{p_id:e,p_status:'success',p_reloadly_transaction_id:'fixture'},
      {p_id:e,p_status:'success',p_reloadly_transaction_id:'fixture',p_pin_code:'code',p_pin_serial:'serial',p_redeem_instructions:'Dial'}]){
      const r=await rpc('update_execution_status',args);assert.equal(r.status,404);assert.equal(r.body.code,'PGRST202');
    }
  });
  await check('HTTP reconciliation claims and full completion payloads adopt ordinary worker delivery',async()=>{
    await client.query("UPDATE public.refill_supplier_submissions SET next_check_at=now()-interval '1 hour' WHERE execution_id=$1",[e]);
    const claimed=await rpc('claim_refill_supplier_reconciliation',{p_limit:1});
    assert.equal(claimed.status,200,JSON.stringify(claimed));assert.equal(claimed.body.length,1);
    assert.equal(claimed.body[0].external_reference,'dt_'+e);
    const args={p_execution_id:e,p_claim_token:claimed.body[0].claim_token,p_outcome:'success',p_provider_tx_id:'fixture-proof',
      p_pin_code:'1234',p_pin_serial:'serial',p_redeem_instructions:'Dial code'};
    for(const result of await Promise.all([rpc('complete_refill_supplier_reconciliation',args),rpc('complete_refill_supplier_reconciliation',args)])){
      assert.equal(result.status,200,JSON.stringify(result));assert.equal(result.body.outcome,'success');
    }
    const conflict=await rpc('complete_refill_supplier_reconciliation',{...args,p_provider_tx_id:'conflicting'});
    assert.equal(conflict.status,400);assert.match(conflict.body.message,/identity mismatch/);
    assert.equal(Number(await scalar('SELECT balance FROM public.wallets WHERE user_id=$1',[u])),18);
  });
  await check('HTTP new recovery APIs reject client roles and invalid batch sizes',async()=>{
    for(const role of [null,'authenticated'])for(const [name,args] of [
      ['claim_refill_supplier_reconciliation',{p_limit:1}],
      ['complete_refill_supplier_reconciliation',{p_execution_id:e,p_claim_token:randomUUID(),p_outcome:'success',p_provider_tx_id:'proof'}]
    ]){
      const result=await rpc(name,args,role);assert.ok([401,403].includes(result.status),JSON.stringify(result));
    }
    const result=await rpc('claim_refill_supplier_reconciliation',{p_limit:26});assert.equal(result.status,400);
  });
  await check('liveness HTTP uses atomic reservation, exact named event settlement and defaulted optional arguments',async()=>{
    const user=randomUUID(),line=randomUUID(),country=randomUUID();
    await client.query('INSERT INTO auth.users(id,email) VALUES($1,$2)',[user,user+'@fixture.test']);
    await client.query('INSERT INTO public.profiles(id,email) VALUES($1,$2)',[user,user+'@fixture.test']);
    await client.query("INSERT INTO public.countries(id,name,iso_code,dialing_code,currency_code,sms_verify_cost) VALUES($1,'Fixture','ZZ','+1','USD',1)",[country]);
    await client.query("INSERT INTO public.sim_lines(id,user_id,phone_number,country_id) VALUES($1,$2,'+15550001011',$3)",[line,user,country]);
    await client.query('SELECT public.ensure_wallet_v2($1)',[user]);
    await client.query("SELECT public.credit_wallet_for_deposit($1::uuid,10,'fixture',$2,jsonb_build_object('paypal_capture_id',$1::text))",[user,'paypal_'+user]);
    const args={p_user_id:user,p_sim_line_id:line,p_method:'sms',p_idempotency_key:randomUUID()};
    for(const role of [null,'authenticated'])assert.ok([401,403,404].includes((await rpc('begin_line_verification',args,role)).status));
    const start=await rpc('begin_line_verification',args);assert.equal(start.status,200,JSON.stringify(start));
    const attempt=start.body.attempt.id;assert.equal(start.body.dispatch,true);
    assert.equal((await rpc('begin_line_verification',args)).body.dispatch,false);
    assert.equal((await rpc('bind_line_verification_resource',{p_attempt_id:attempt,p_resource_id:'http-'+attempt})).status,200);
    const event={p_attempt_id:attempt,p_provider:'telnyx',p_resource_id:'http-'+attempt,p_event_type:'message.delivered',p_outcome:'succeeded'};
    for(const role of [null,'authenticated'])assert.ok([401,403,404].includes((await rpc('settle_line_verification_event',event,role)).status));
    assert.equal((await rpc('settle_line_verification_event',{...event,p_resource_id:'foreign'})).status,400);
    for(let i=0;i<2;i++){const settled=await rpc('settle_line_verification_event',event);assert.equal(settled.status,200,JSON.stringify(settled));assert.equal(settled.body.settlement_status,'captured');}
    assert.equal(Number(await scalar('SELECT balance FROM public.wallets WHERE user_id=$1',[user])),9);
    assert.equal(Number(await scalar("SELECT count(*) FROM public.wallet_transactions WHERE user_id=$1 AND type='verification_debit'",[user])),1);
    assert.ok([401,403,404].includes((await rpc('confirm_line_verification',{p_sim_line_id:line},'authenticated')).status));
  });
  await runCallsHTTP({client,rpc},check);
  console.log(`${passed} passed / ${failed} failed isolated HTTP scenarios`);
  if(process.env.FINANCIAL_TEST_REPORT)await fs.writeFile(process.env.FINANCIAL_TEST_REPORT,JSON.stringify({adapter:version,results},null,2)+'\n');
  if(failed)process.exitCode=1;
}catch(error){console.error('FAIL isolated HTTP setup: '+error.message);process.exitCode=1;}
finally{
  if(api&&api.exitCode===null){const ended=once(api,'close');api.kill('SIGTERM');await ended;}
  if(client)await client.end();await server.stop();await fs.rm(directory,{recursive:true,force:true});
}
if(process.exitCode)process.exit(process.exitCode);
