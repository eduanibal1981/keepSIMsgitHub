const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const load=()=>import('data:text/javascript;base64,'+Buffer.from(fs.readFileSync('supabase/functions/_shared/esim-recharge-discovery.js')).toString('base64'));
const id='10000000-0000-4000-8000-000000000001';
const request=body=>new Request('https://fixture.invalid/',{method:'POST',headers:{authorization:'Bearer fixture'},body:JSON.stringify(body)});
test('acceptance forwards only the quote capability and device ID using customer SQL authority',async()=>{
 const {createRechargeHandler}=await load();const customer={actor:'fixture'};let got;
 const h=createRechargeHandler({authenticate:async()=>customer,call:async(c,name,params)=>{got={c,name,params};return {data:{status:'RECHARGE_DISABLED'}};}});
 const r=await h(request({action:'accept',quote_id:id,acceptance_key:id,device_id:id}));assert.equal(r.status,200);
 assert.deepEqual(got,{c:customer,name:'accept_esim_topup',params:{p_quote_id:id,p_acceptance_key:id,p_device_id:id}});
});
test('no client price, payer, supplier, receipt or settlement command can be injected into acceptance',async()=>{
 const {createRechargeHandler}=await load();let calls=0;const h=createRechargeHandler({authenticate:async()=>({}),call:async()=>{calls++;}});
 for(const extra of [{payer_id:id},{price:0.01},{receipt:{outcome:'success'}},{rpc:'service_esim_settle_topup'},{device_id:'bad'}]){
  assert.equal((await h(request({action:'accept',quote_id:id,acceptance_key:id,...extra}))).status,400);
 }assert.equal(calls,0);
});
test('history remains an owner-scoped RPC and a genuine empty result is preserved',async()=>{
 const {createRechargeHandler}=await load();let params;
 const h=createRechargeHandler({authenticate:async()=>({}),call:async(c,name,p)=>{assert.equal(name,'get_esim_operation_history');params=p;return {data:[]};}});
 const r=await h(request({action:'history',profile_id:id}));assert.equal(r.status,200);assert.deepEqual(params,{p_profile_id:id});assert.deepEqual(await r.json(),[]);
});
