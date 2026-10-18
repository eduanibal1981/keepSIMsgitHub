import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {once} from 'node:events';
import {createHmac} from 'node:crypto';

// Optional real PostgREST adapter, confined to the disposable native database.
export async function runScheduleHTTP(db,check){
 const port=Number(process.env.SCHEDULE_HTTP_PORT||56559);
 const dbPort=Number(process.env.SCHEDULE_TEST_PORT||56558);
 const key='isolated-schedule-http-key-not-production-secret';
 const user='10000000-0000-4000-8000-000000000001';
 const line='20000000-0000-4000-8000-000000000001';
 const jwt=(sub=user,role='authenticated')=>{
  const parts=[{alg:'HS256',typ:'JWT'},{sub,role,exp:Math.floor(Date.now()/1000)+300}].map(v=>Buffer.from(JSON.stringify(v)).toString('base64url'));
  return parts.join('.')+'.'+createHmac('sha256',key).update(parts.join('.')).digest('base64url');
 };
 const request=async(route,body,token=jwt(),method='POST')=>{
  const r=await fetch(`http://127.0.0.1:${port}/${route}`,{method,headers:{'content-type':'application/json',...(token?{authorization:'Bearer '+token}:{})},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(5000)});
  const raw=await r.text();return {status:r.status,body:raw?JSON.parse(raw):null};
 };
 await db.query("CREATE ROLE schedule_http_authenticator LOGIN NOINHERIT PASSWORD 'isolated-http'; GRANT anon,authenticated,service_role TO schedule_http_authenticator");
 const api=spawn(process.env.POSTGREST_BINARY,[],{env:{PATH:process.env.PATH,
  ...(process.env.POSTGREST_LIBRARY_PATH?{DYLD_LIBRARY_PATH:process.env.POSTGREST_LIBRARY_PATH}:{}),
  PGRST_DB_URI:`postgres://schedule_http_authenticator:isolated-http@127.0.0.1:${dbPort}/postgres`,
  PGRST_DB_SCHEMAS:'public',PGRST_DB_ANON_ROLE:'anon',PGRST_JWT_SECRET:key,PGRST_DB_POOL:'4',
  PGRST_SERVER_HOST:'127.0.0.1',PGRST_SERVER_PORT:String(port),PGRST_LOG_LEVEL:'crit'},stdio:['ignore','ignore','pipe']});
 let error,stderr='';api.on('error',e=>error=e);api.stderr.on('data',x=>stderr+=x);
 const input={p_sim_line_id:line,p_schedule_type:'refill_mini',p_frequency_days:23,p_next_execution_at:new Date(Date.now()+86400000).toISOString(),p_max_authorized_usd:3};
 let mini,notify;
 try{
  let ready=false;
  for(let i=0;i<100;i++){
   if(error||api.exitCode!==null)throw Error('PostgREST failed: '+(error?.message||stderr));
   try{if((await request('',undefined,null,'GET')).status===200){ready=true;break;}}catch{}
   await new Promise(r=>setTimeout(r,100));
  }
  if(!ready)throw Error('PostgREST startup timed out');
  await check('HTTP anonymous and foreign schedule mutations are denied',async()=>{
   for(const token of [null,jwt('10000000-0000-4000-8000-000000000002')]){
    const r=await request('rpc/save_customer_schedule',input,token);assert.ok([401,403,404].includes(r.status),JSON.stringify(r));assert.notEqual(r.body?.code,'PGRST203');
   }
  });
  await check('HTTP raw insert and financial update fail closed',async()=>{
   for(const method of ['POST','PATCH']){
    const r=await request('scheduled_topups',method==='POST'?{user_id:user,sim_line_id:line,amount:.01,frequency_days:1,next_execution_at:input.p_next_execution_at}:{amount:.01,engine_version:99,pricing_tier:'premium'},jwt(),method);
    assert.equal(r.status,403,JSON.stringify(r));
   }
  });
  await check('HTTP extra authoritative RPC arguments cannot resolve an unsafe overload',async()=>{
   const r=await request('rpc/save_customer_schedule',{...input,p_amount:.01,p_user_id:user,p_engine_version:99});
   assert.equal(r.status,404,JSON.stringify(r));assert.equal(r.body.code,'PGRST202');
  });
  await check('HTTP named and default arguments save one retail-priced next occurrence',async()=>{
   for(let i=0;i<2;i++){
    const r=await request('rpc/save_customer_schedule',input);assert.equal(r.status,200,JSON.stringify(r));mini=r.body;
    assert.equal(Number(mini.amount),2.1);assert.equal(mini.base_cost_usd,undefined);assert.equal(mini.user_id,user);
   }
   assert.equal((await db.query("SELECT count(*)::int n FROM public.topup_executions WHERE scheduled_topup_id=$1 AND status='pending'",[mini.id])).rows[0].n,1);
  });
  await check('HTTP pause resume and next-date controls retain one occurrence',async()=>{
   for(const active of [false,true])assert.equal((await request('rpc/set_customer_schedule_active',{p_schedule_id:mini.id,p_is_active:active})).status,200);
   const r=await request('rpc/reschedule_mini_refill',{p_sim_line_id:line,p_new_date:new Date(Date.now()+2*86400000).toISOString()});assert.ok([200,204].includes(r.status),JSON.stringify(r));
   assert.equal((await db.query("SELECT count(*)::int n FROM public.topup_executions WHERE scheduled_topup_id=$1 AND status='pending'",[mini.id])).rows[0].n,1);
  });
  await check('HTTP initialized paid settings report authorization and retirement is enforced',async()=>{
   const r=await request('rpc/initialize_line_schedules',{p_sim_line_id:line});assert.equal(r.status,200,JSON.stringify(r));assert.equal(r.body.needs_authorization,false);
   const old=await request('rpc/queue_premium_refill_executions',{p_sim_line_id:line,p_scheduled_topup_id:mini.id});assert.ok([403,404].includes(old.status),JSON.stringify(old));assert.ok(['42501','PGRST202'].includes(old.body.code));
  });
  await check('HTTP overdue reminder synchronization and deletion retain supported controls',async()=>{
   const r=await request('rpc/save_customer_schedule',{p_sim_line_id:line,p_schedule_type:'notify',p_frequency_days:30,p_next_execution_at:new Date(Date.now()-86400000).toISOString()});
   assert.equal(r.status,200,JSON.stringify(r));notify=r.body;
   const deleted=await request('rpc/delete_customer_schedule',{p_schedule_id:notify.id});assert.ok([200,204].includes(deleted.status),JSON.stringify(deleted));
  });
 }finally{
  if(api.exitCode===null){const closed=once(api,'close');api.kill('SIGTERM');await closed;}
 }
}
