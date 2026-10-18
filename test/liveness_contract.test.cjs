const {test}=require('node:test');
const assert=require('node:assert/strict');
const {loadEdge,builder}=require('./edge_module_loader.cjs');
const request=body=>new Request('https://fixture.invalid/functions/v1/liveness-verification',{method:'POST',headers:{authorization:'Bearer fixture','content-type':'application/json'},body:JSON.stringify({action:'start',simLineId:'line',method:'voice',idempotencyKey:'key',...body})});
function fixture({dispatch=true,reject=false,response='accepted',bindFailure=false,settleFailure=false}={}){
 let handler;const calls=[],provider=[],writes=[];
 const attempt={id:'attempt',method:'voice',destination_phone:'+15550001011',status:dispatch?'dispatching':'pending',outcome:'pending'};
 const client={auth:{getUser:async()=>({data:{user:{id:'owner'}}})},rpc:async(name,args)=>{
   calls.push({name,args});
   if(name==='get_internal_secret')return{data:'fixture-secret'};
   if(name==='begin_line_verification')return reject?{error:{message:'denied'}}:{data:{attempt,dispatch}};
   if(name==='bind_line_verification_resource')return bindFailure?{error:{message:'failed'}}:{data:{success:true}};
   if(name==='settle_line_verification_event')return settleFailure?{error:{message:'failed'}}:{data:{success:true}};
   throw Error(name);
 },from:table=>builder((filters,op)=>{writes.push({table,filters,op});return{data:null,error:null};})};
 loadEdge('supabase/functions/liveness-verification/index.ts',{serve:fn=>handler=fn,createClient:()=>client,
 env:{SUPABASE_URL:'https://fixture.invalid',SUPABASE_SERVICE_ROLE_KEY:'service',TELNYX_CALL_CONTROL_APP_ID:'app',TELNYX_DEFAULT_CALLER_ID:'+15550001012'},
 fetch:async(url,options)=>{provider.push({url,options});if(response==='timeout')throw Error('timeout');if(response==='rejected')return new Response('{}',{status:422});if(response==='unavailable')return new Response('{}',{status:503});return Response.json({data:response==='missing-id'?{call_leg_id:'wrong-kind-of-id'}:{call_control_id:'resource'}});}});
 return{handler,calls,provider,writes};
}
test('start requires a stable idempotency key and an owned atomic reservation before provider dispatch',async()=>{
 let f=fixture();assert.equal((await f.handler(request({idempotencyKey:null}))).status,400);assert.equal(f.provider.length,0);
 f=fixture({reject:true});assert.equal((await f.handler(request({}))).status,409);assert.equal(f.provider.length,0);
 const begin=f.calls.find(c=>c.name==='begin_line_verification');assert.equal(begin.args.p_user_id,'owner');assert.equal(begin.args.p_sim_line_id,'line');assert.equal(begin.args.p_idempotency_key,'key');
});
test('adopted attempts never redispatch and accepted calls bind the control identity',async()=>{
 let f=fixture({dispatch:false});assert.equal((await f.handler(request({}))).status,200);assert.equal(f.provider.length,0);
 f=fixture();assert.equal((await f.handler(request({}))).status,200);assert.equal(f.provider.length,1);
 assert.deepEqual(f.calls.find(c=>c.name==='bind_line_verification_resource').args,{p_attempt_id:'attempt',p_resource_id:'resource'});
});
for(const response of ['timeout','unavailable','missing-id'])test(response+' retains reservation and records reconciliation rather than claiming failure',async()=>{
 const f=fixture({response});const result=await f.handler(request({}));assert.equal(result.status,503);
 assert.equal((await result.json()).status,'reconciliation_required');assert.equal(f.calls.some(c=>c.name==='settle_line_verification_event'),false);
 assert.equal(f.writes[0].op.update.status,'reconciliation_required');
});
test('failed binding retains uncertainty and definitive rejection checks settlement errors',async()=>{
 let f=fixture({bindFailure:true});assert.equal((await f.handler(request({}))).status,503);
 f=fixture({response:'rejected'});assert.equal((await f.handler(request({}))).status,502);
 assert.equal(f.calls.find(c=>c.name==='settle_line_verification_event').args.p_event_type,'dispatch.rejected');
 f=fixture({response:'rejected',settleFailure:true});assert.equal((await f.handler(request({}))).status,503);assert.equal(f.writes[0].op.update.status,'reconciliation_required');
});
