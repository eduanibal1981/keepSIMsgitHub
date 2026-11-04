const {test}=require('node:test');
const assert=require('node:assert/strict');
const {loadEdge}=require('./edge_module_loader.cjs');
const caller='11111111-1111-4111-8111-111111111111';
const target='22222222-2222-4222-8222-222222222222';
function fixture({authorized=true,deny=false,busy=false,missing=false}={}){
  const requests=[];let handler;
  loadEdge('supabase/functions/initiate-voip-call/index.ts',{
    env:{SUPABASE_URL:'https://database.test',SUPABASE_SERVICE_ROLE_KEY:'test-only-service-key'},
    createClient:()=>({rpc:async()=>({data:'test-only-relay-secret',error:null})}),
    serve:fn=>{handler=fn;},
    fetch:async(url,options={})=>{
      const u=new URL(url),body=options.body&&JSON.parse(options.body);requests.push({url:u,body,method:options.method||'GET'});
      if(u.pathname==='/auth/v1/user')return Response.json({id:caller},{status:authorized?200:401});
      if(u.pathname.endsWith('/profiles'))return Response.json(missing?[]:[{id:target,full_name:'Fixture',avatar_url:null}]);
      if(u.pathname.endsWith('/voip_call_sessions')){
        if(options.method==='POST')return Response.json(deny?{message:'private database diagnostic'}:[{id:'call-id'}],{status:deny?403:201});
        return Response.json(busy?[{id:'existing',created_at:new Date().toISOString()}]:[]);
      }
      if(u.pathname.endsWith('/voip_push_tokens'))return Response.json([{fcm_token:'test-only-device-token'}]);
      if(u.pathname.endsWith('/dispatch-alert'))return Response.json({ok:true});
      throw Error('Unexpected request '+u.pathname);
    },
  });
  return {requests,call:(body={callee_id:target},method='POST')=>handler(new Request('https://edge.test',{
    method,headers:{Authorization:'Bearer test-only-user-token'},...(method==='POST'?{body:JSON.stringify(body)}:{})}))};
}
test('existing internet call entrypoint routes to canonical UUID and sends no private profile phones',async()=>{
  const f=fixture(),r=await f.call();assert.equal(r.status,200);const data=await r.json();
  assert.equal(data.callee.id,target);assert.equal(data.callee.phone,'');
  const insert=f.requests.find(r=>r.method==='POST'&&r.url.pathname.endsWith('/voip_call_sessions'));
  assert.equal(insert.body.caller_id,caller);assert.equal(insert.body.callee_id,target);
  const push=f.requests.find(r=>r.url.pathname.endsWith('/dispatch-alert'));assert.equal(push.body.user_id,target);assert.equal(push.body.voip_payload.caller_phone,'');
  for(const r of f.requests.filter(r=>r.url.pathname.endsWith('/profiles')))assert(!r.url.searchParams.get('select').includes('phone'));
  assert(f.requests.every(r=>r.url.hostname==='database.test'));
});
test('database block/lifecycle rejection stops push and returns the same generic failure',async()=>{
  const f=fixture({deny:true}),r=await f.call();assert.equal(r.status,403);
  assert.deepEqual(await r.json(),{error:'KeepSIMs contact unavailable'});
  assert.equal(f.requests.some(r=>r.url.pathname.endsWith('/dispatch-alert')),false);
  const missing=await fixture({missing:true}).call();assert.equal(missing.status,403);
  assert.deepEqual(await missing.json(),{error:'KeepSIMs contact unavailable'});
});
test('unauthenticated, injected target, self-call and wrong HTTP method cannot create sessions',async()=>{
  for(const [options,body,method,status] of [[{authorized:false},{callee_id:target},'POST',401],[{}, {callee_id:'eq.target&select=phone'},'POST',400],[{},{callee_id:caller},'POST',400],[{}, {},'GET',405]]){
    const f=fixture(options);assert.equal((await f.call(body,method)).status,status);
    assert.equal(f.requests.some(r=>r.url.pathname.endsWith('/voip_call_sessions')),false);
  }
});
test('existing busy state is retained without creating another call',async()=>{
  const f=fixture({busy:true}),r=await f.call();assert.equal(r.status,200);assert.equal((await r.json()).status,'busy');
  assert.equal(f.requests.some(r=>r.method==='POST'),false);
});
