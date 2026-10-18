const {test}=require('node:test');
const assert=require('node:assert/strict');
const {loadEdge}=require('./edge_module_loader.cjs');
const url='https://fixture.invalid',user='10000000-0000-4000-8000-000000000001',id='20000000-0000-4000-8000-000000000002',session='30000000-0000-4000-8000-000000000003';
function fixture(options={}){
 let handler;const calls=[];
 const record={id,user_id:user,call_type:'app_to_phone_webrtc',status:'initiated',destination_number:'+15550001111',effective_caller_id:'+15550002222',caller_id_type:'gateway',rate_per_minute_usd:1,connection_fee_usd:0,billing_increment_seconds:60,reserved_budget_usd:5,max_duration_seconds:300,budget_contract_version:1,billing_state:'reserved',...options.record};
 const fetch=async(address,init={})=>{
  const u=new URL(address),body=init.body?JSON.parse(init.body):null,path=u.pathname;calls.push({path,body,method:init.method||'GET'});
  const json=(x,status=200)=>Response.json(x,{status});
  if(path==='/auth/v1/user')return json({id:user},options.unauthorized?401:200);
  if(path.endsWith('/get_internal_secret'))return json('fixture-api-key');
  if(path.endsWith('/system_configs'))return json([{config_value:u.searchParams.get('config_key')==='eq.TELNYX_DEFAULT_CALLER_ID'?record.effective_caller_id:'fixture-app'}]);
  if(path.endsWith('/user_caller_id_preferences')||path.endsWith('/user_caller_ids'))return json([]);
  if(path.endsWith('/get_wallet_summary'))return json({posted_balance:60,available_balance:55},options.summaryFailure?503:200);
  if(path.endsWith('/get_call_rate_for_number'))return json([{id:'rate',rate_per_minute_usd:99,country_code:'XX',country_name:'Fixture',billing_increment_seconds:1}]);
  if(path.endsWith('/prepare_budgeted_media_call'))return json({call:record,created:true,posted_balance:60,available_balance:55});
  if(path.endsWith('/begin_media_call_leg'))return json({dispatch:true,call:record});
  if(path.endsWith('/record_media_call_evidence'))return json(null);
  if(path.endsWith('/call_records')){
    if(init.method==='PATCH')return json([Object.assign(record,body)]);
    if(u.searchParams.has('idempotency_key'))return json(options.retry?[record]:[]);
    return json([record]);
  }
  if(path.endsWith('/call_media_sessions'))return json([{id:session,sip_username:'synthetic',call_record_id:id}]);
  if(u.hostname==='api.telnyx.com')return json({data:{call_control_id:'app-leg'}},options.providerFailure?503:200);
  throw Error('Unhandled fixture path '+path);
 };
 loadEdge('supabase/functions/make-call/index.ts',{env:{SUPABASE_URL:url,SUPABASE_SERVICE_ROLE_KEY:'fixture-service'},fetch,serve:fn=>handler=fn});
 const request=(extra={})=>handler(new Request(url+'/functions/v1/make-call',{method:'POST',headers:{Authorization:'Bearer fixture-user','Content-Type':'application/json'},body:JSON.stringify({destinationNumber:record.destination_number,mediaSessionId:session,idempotencyKey:'stable-fixture',...extra})}));
 return{calls,record,request};
}
test('dial returns accepted SQL tariff, budget and bounded provider duration',async()=>{
 const f=fixture(),response=await f.request(),body=await response.json();assert.equal(response.status,200);assert.equal(body.reservedBudget,5);assert.equal(body.maxDurationSeconds,300);assert.equal(body.destination.ratePerMinute,1);assert.equal(body.availableBalance,55);
 const provider=f.calls.find(x=>x.path==='/v2/calls');assert.equal(provider.body.time_limit_secs,360);
 assert.equal(f.calls.some(x=>x.path.endsWith('/reserve_wallet_funds')),false);assert.equal(f.calls.some(x=>x.path.endsWith('/call_records')&&x.method==='POST'),false);
});
test('retry returns saved tariff and valid wallet values without reserving or dialing again',async()=>{
 const f=fixture({retry:true}),response=await f.request(),body=await response.json();assert.equal(response.status,200);assert.equal(body.walletBalance,60);assert.equal(body.destination.ratePerMinute,1);
 for(const suffix of ['/prepare_budgeted_media_call','/begin_media_call_leg','/get_call_rate_for_number','/v2/calls'])assert.equal(f.calls.some(x=>x.path.endsWith(suffix)),false);
});
test('wallet summary failure cannot fall back to posted balance or authorize a call',async()=>{
 const f=fixture({summaryFailure:true}),response=await f.request();assert.equal(response.status,503);assert.equal(f.calls.some(x=>x.path.endsWith('/prepare_budgeted_media_call')),false);
});
test('ambiguous provider failure preserves call identity and reservation for recovery',async()=>{
 const f=fixture({providerFailure:true}),response=await f.request(),body=await response.json();assert.equal(response.status,503);assert.equal(body.callId,id);assert.equal(body.code,'call_reconciliation_required');assert.equal(f.record.billing_state,'reconciliation_required');assert.equal(f.calls.some(x=>x.path.endsWith('/release_wallet_hold')),false);
});
test('unauthenticated requests and missing stable keys cause no call or reservation',async()=>{
 for(const options of [{unauthorized:true},{}]){const f=fixture(options),response=await f.request(options.unauthorized?{}:{idempotencyKey:null});assert.equal(response.status,options.unauthorized?401:400);assert.equal(f.calls.some(x=>x.path.endsWith('/prepare_budgeted_media_call')),false);}
});
