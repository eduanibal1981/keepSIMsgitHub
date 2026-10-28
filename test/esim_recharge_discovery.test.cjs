const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const source=fs.readFileSync('supabase/functions/_shared/esim-recharge-discovery.js','utf8');
const load=()=>import('data:text/javascript;base64,'+Buffer.from(source).toString('base64'));
const id='10000000-0000-4000-8000-000000000001';
const request=(body,headers={authorization:'Bearer fixture'},method='POST')=>new Request('https://fixture.invalid/',{method,headers,...(method==='POST'?{body:JSON.stringify(body)}:{})});
test('anonymous/invalid identity and unexpected methods cannot reach SQL',async()=>{
 const {createRechargeHandler}=await load();let calls=0;
 const handler=createRechargeHandler({authenticate:async()=>null,call:async()=>{calls++;}});
 assert.equal((await handler(request({action:'discover',profile_id:id},{}))).status,401);
 assert.equal((await handler(request({action:'discover',profile_id:id}))).status,401);
 assert.equal((await handler(request(null,{},'GET'))).status,405);assert.equal(calls,0);
});
test('authenticated discovery uses the customer client, exact profile and fixed RPC allowlist',async()=>{
 const {createRechargeHandler}=await load();const client={owner:'fixture'};let captured;
 const handler=createRechargeHandler({authenticate:async()=>client,call:async(c,name,p)=>{captured={c,name,p};return {data:{status:'PENDING'}};}});
 const r=await handler(request({action:'discover',profile_id:id}));assert.equal(r.status,200);
 assert.deepEqual(captured,{c:client,name:'request_esim_topups',p:{p_profile_id:id}});assert.equal(r.headers.get('cache-control'),'no-store');
});
test('payer overrides, acceptance, raw RPC names, malformed IDs and oversized requests are refused',async()=>{
 const {createRechargeHandler}=await load();let calls=0;
 const handler=createRechargeHandler({authenticate:async()=>({}),call:async()=>{calls++;}});
 for(const b of [{action:'accept',quote_id:id},{action:'discover',profile_id:'bad'},{action:'discover',profile_id:id,payer_id:id},
  {action:'quote',profile_id:id,package_id:'P',offer_version:id,expected_total:1,wholesale_usd:0.01},{action:'service_esim_claim_topups'},null,[]])
  assert.equal((await handler(request(b))).status,400);
 assert.equal((await handler(request({action:'discover',profile_id:id,large:'x'.repeat(3000)}))).status,413);assert.equal(calls,0);
});
test('quote/check bind only reviewed offer fields and owner-checked IDs',async()=>{
 const {createRechargeHandler}=await load();const calls=[];
 const handler=createRechargeHandler({authenticate:async()=>({}),call:async(c,name,p)=>{calls.push([name,p]);return {data:{status:'QUOTED',acceptance_enabled:false}};}});
 await handler(request({action:'quote',profile_id:id,package_id:'EXACT',offer_version:id,expected_total:1.3}));
 await handler(request({action:'check',quote_id:id}));
 assert.deepEqual(calls[0],['quote_esim_topup',{p_profile_id:id,p_package_id:'EXACT',p_offer_version:id,p_expected_total:1.3}]);
 assert.deepEqual(calls[1],['check_esim_topup_quote',{p_quote_id:id}]);
});
test('database errors and thrown auth errors never expose internal data',async()=>{
 const {createRechargeHandler}=await load();
 for(const deps of [{authenticate:async()=>({}),call:async()=>({error:{message:'PRIVATE wholesale secret'}})},
  {authenticate:async()=>{throw Error('PRIVATE');}}]){
  const r=await createRechargeHandler(deps)(request({action:'discover',profile_id:id}));assert.equal(r.status,503);assert(!JSON.stringify(await r.json()).includes('PRIVATE'));
 }
});
