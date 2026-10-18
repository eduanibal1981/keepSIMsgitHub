const {test}=require('node:test');
const assert=require('node:assert/strict');
const {loadEdge,builder}=require('./edge_module_loader.cjs');
const user='10000000-0000-4000-8000-000000000001',other='10000000-0000-4000-8000-000000000002';
const requestId='20000000-0000-4000-8000-000000000001',itemId='30000000-0000-4000-8000-000000000001';
const project='https://project.invalid',api='https://api-m.sandbox.paypal.com';
function fixture(options={}){
 const calls=[],requests=[],claimed=new Set();let status='requested';
 const items=[{id:itemId,provider:'paypal',capture_id:'CAPTURE001',amount:5,currency:'USD',idempotency_key:'ksr-'+'a'.repeat(32)}];
 if(options.twoItems)items.push({...items[0],id:'30000000-0000-4000-8000-000000000002',capture_id:'CAPTURE002',idempotency_key:'ksr-'+'b'.repeat(32)});
 const client={auth:{async getUser(token){calls.push({name:'getUser'});return {data:{user:token==='valid'?{id:options.foreign?other:user,app_metadata:options.admin?{is_power_user:true}:{}}:null},error:token==='valid'?null:{message:'invalid'}};}},
  from:table=>builder(filters=>{
   calls.push({table,filters});if(table==='wallet_refund_requests')return {data:{id:requestId,user_id:user,status}};
   assert.equal(table,'wallet_refund_items');return {data:items.find(i=>i.id===filters.id)||null};
  }),async rpc(name,args){
   calls.push({name,args});
   if(name==='get_internal_secret')return {data:options.missingSecret?null:'fixture-secret'};
   if(name==='list_wallet_refund_work')return {data:options.noWork?[]:items.map(({id})=>({id}))};
   if(name==='claim_wallet_refund_item'){
    if(claimed.has(args.p_item_id))return {data:{claimed:false}};claimed.add(args.p_item_id);
    return {data:{claimed:true,claim_token:'claim',action:'submit',item:items.find(i=>i.id===args.p_item_id)}};
   }
   if(name==='begin_wallet_refund_submission'||name==='adopt_wallet_refund_identity')return {data:true};
   if(name==='record_wallet_refund_evidence')return {data:{persisted:true}};
   if(name==='finish_wallet_refund_item'){
    if(options.failedSettlement&&args.p_item_id===itemId&&args.p_outcome==='completed')return {error:{message:'secret provider SQL failure'}};
    status=options.failedSettlement?'under_review':'completed';return {data:{item_status:args.p_outcome}};
   }
   throw Error('Unexpected RPC '+name);
  }};
 const fetch=async(address,init={})=>{
  requests.push({address,method:init.method||'GET'});
  if(address===project+'/auth/v1/user')return Response.json({id:other,app_metadata:options.admin?{is_power_user:true}:{}});
  if(address===project+'/rest/v1/rpc/assert_admin')return Response.json({}, {status:options.adminDenied||!options.admin?403:200});
  if(address===api+'/v1/oauth2/token')return Response.json({access_token:'fixture-access'}, {status:options.badOAuth?503:200});
  const item=init.method==='POST'?items.find(i=>address.includes(i.capture_id)):items[0];assert.ok(item);
  const response={id:'REFUND001',custom_id:item.id,status:'COMPLETED',amount:{value:'5.00',currency_code:'USD'},
   links:[{rel:'up',href:api+'/v2/payments/captures/'+item.capture_id}]};
  return Response.json({...response,...options.provider});
 };
 const env={SUPABASE_URL:project,SUPABASE_SERVICE_ROLE_KEY:'service',PAYPAL_API_BASE:api,...options.env};
 const {handleRefundRequest}=loadEdge('supabase/functions/process-wallet-refund/index.ts',{serve:()=>{},createClient:()=>client,env,fetch});
 const run=(body={refund_request_id:requestId},token='valid',method='POST')=>handleRefundRequest(new Request(project+'/refund',{
  method,headers:token?{authorization:'Bearer '+token}:{},...(method==='POST'?{body:typeof body==='string'?body:JSON.stringify(body)}:{})}));
 return {run,calls,requests};
}
for(const token of [null,'forged-service-role-claim','service extra'])test('unverified credential '+token+' is rejected before provider or payout access',async()=>{
 const f=fixture();assert.equal((await f.run(undefined,token)).status,401);assert.equal(f.requests.length,0);assert.equal(f.calls.some(c=>c.name==='claim_wallet_refund_item'),false);
});
test('foreign owners cannot process another users refund',async()=>{
 const f=fixture({foreign:true});assert.equal((await f.run()).status,403);assert.equal(f.requests.length,0);
});
test('cross-owner admin access must also pass the existing assert_admin backend contract',async()=>{
 const f=fixture({foreign:true,admin:true,adminDenied:true});assert.equal((await f.run()).status,403);
 assert.equal(f.calls.some(c=>c.name==='list_wallet_refund_work'),false);assert.equal(f.requests.some(r=>r.address.startsWith(api)),false);
});
test('owner processes their bound item and a service credential bypasses Auth-user lookup',async()=>{
 for(const token of ['valid','service']){
  const f=fixture();const r=await f.run(undefined,token);assert.equal(r.status,200);assert.equal((await r.json()).status,'completed');
  assert.equal(f.requests.filter(r=>r.method==='POST'&&r.address.endsWith('/refund')).length,1);
  if(token==='service')assert.equal(f.calls.some(c=>c.name==='getUser'),false);
 }
});
test('malformed IDs and JSON never reach a provider',async()=>{
 for(const body of [{refund_request_id:'-'.repeat(36)},'{bad',null]){const f=fixture();assert.equal((await f.run(body)).status,400);assert.equal(f.requests.length,0);}
});
test('missing server identity or provider configuration fails closed',async()=>{
 for(const options of [{env:{SUPABASE_SERVICE_ROLE_KEY:''}},{env:{SUPABASE_URL:''}},{missingSecret:true},{env:{PAYPAL_API_BASE:'https://foreign.invalid'}}]){
  const f=fixture(options);assert.equal((await f.run()).status,503);assert.equal(f.requests.length,0);assert.equal(f.calls.some(c=>c.name==='begin_wallet_refund_submission'),false);
 }
});
test('no actionable work skips OAuth and provider calls',async()=>{const f=fixture({noWork:true});assert.equal((await f.run()).status,200);assert.equal(f.requests.length,0);});
test('ordinary owners cannot adopt a provider refund identity',async()=>{
 const f=fixture();assert.equal((await f.run({refund_request_id:requestId,reconciliation:{item_id:itemId,provider_refund_id:'REFUND001'}})).status,403);
 assert.equal(f.calls.some(c=>c.name==='adopt_wallet_refund_identity'),false);
});
test('manual recovery rejects a different item, capture or amount before attaching provider identity',async()=>{
 for(const provider of [{custom_id:'other'},{amount:{value:'99.00',currency_code:'USD'}},{links:[{rel:'up',href:api+'/v2/payments/captures/FOREIGN'}]}]){
  const f=fixture({provider,noWork:true});assert.equal((await f.run({refund_request_id:requestId,reconciliation:{item_id:itemId,provider_refund_id:'REFUND001'}},'service')).status,500);
  assert.equal(f.calls.some(c=>c.name==='adopt_wallet_refund_identity'),false);assert.equal(f.requests.some(r=>r.address.endsWith('/refund')),false);
 }
});
test('a failed item does not hide later item work or report the whole request as successful',async()=>{
 const f=fixture({twoItems:true,failedSettlement:true});const response=await f.run();assert.equal(response.status,500);
 const body=await response.json();assert.equal(body.success,false);assert.deepEqual(body.outcomes,['reconciliation_required','completed']);
 assert.equal(f.requests.filter(r=>r.address.endsWith('/refund')).length,2);assert.equal(JSON.stringify(body).includes('secret provider SQL failure'),false);
});
test('method handling is bounded before authentication',async()=>{
 const f=fixture();assert.equal((await f.run(undefined,null,'OPTIONS')).status,200);assert.equal((await f.run(undefined,null,'GET')).status,405);assert.equal(f.calls.length,0);
});

test('wallet_transact forwards the persisted intent key to the exactly-once request RPC and derives ownership from Auth',async()=>{
 const requests=[];let handler;
 loadEdge('supabase/functions/wallet_transact/index.ts',{serve:fn=>handler=fn,env:{SUPABASE_URL:project,SUPABASE_SERVICE_ROLE_KEY:'service'},fetch:async(url,init)=>{
  if(url===project+'/auth/v1/user')return Response.json({id:user});requests.push({url,body:JSON.parse(init.body)});return Response.json({success:true,refund_request_id:requestId});
 }});
 const request=body=>handler(new Request(project+'/wallet',{method:'POST',headers:{authorization:'Bearer valid'},body:JSON.stringify(body)}));
 assert.equal((await request({action:'request_refund',amount:5,user_id:other,refund_request_key:'refund_'+'a'.repeat(32)})).status,200);
 assert.equal(requests[0].url,project+'/rest/v1/rpc/request_wallet_refund_once');assert.equal(requests[0].body.p_user_id,user);
 assert.equal(requests[0].body.p_request_key,'refund_'+'a'.repeat(32));
 assert.equal((await request({action:'request_refund',amount:5,refund_request_key:'invalid?'})).status,400);assert.equal(requests.length,1);
 assert.equal((await request({action:'request_refund',amount:5,expected_user_id:other,refund_request_key:'refund_'+'a'.repeat(32)})).status,409);assert.equal(requests.length,1);
});
