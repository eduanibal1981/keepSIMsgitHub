const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const load=()=>import('data:text/javascript;base64,'+Buffer.from(fs.readFileSync('supabase/functions/_shared/esim-recharge-discovery.js')).toString('base64'));
const id='10000000-0000-4000-8000-000000000001';
const req=body=>new Request('https://fixture.invalid/',{method:'POST',headers:{authorization:'Bearer fixture'},body:JSON.stringify(body)});
test('daily purchase and extension quote use only allowlisted intent under customer authority',async()=>{
 const {createRechargeHandler}=await load();const calls=[];const h=createRechargeHandler({authenticate:async()=>({customer:true}),call:async(c,name,p)=>{calls.push([name,p]);return {data:{status:'DURATION_PRICE_UNAVAILABLE'}};}});
 assert.equal((await h(req({action:'quote_daily_purchase',package_id:'DAY_A',period_count:5,quantity:1}))).status,200);
 assert.equal((await h(req({action:'quote_daily_extension',package_id:'DAY_A',profile_id:id,offer_version:id,period_count:5}))).status,200);
 assert.deepEqual(calls,[['quote_esim_daily_purchase',{p_offer_id:'DAY_A',p_period_count:5,p_quantity:1}],['quote_esim_daily_extension',{p_profile_id:id,p_package_id:'DAY_A',p_offer_version:id,p_period_count:5}]]);
});
test('invalid duration, quantity, injected prices/payers and service operations never reach SQL',async()=>{
 const {createRechargeHandler}=await load();let calls=0;const h=createRechargeHandler({authenticate:async()=>({}),call:async()=>{calls++;}});
 const base={action:'quote_daily_purchase',package_id:'DAY_A',period_count:5,quantity:1};
 for(const change of [{period_count:0},{period_count:366},{period_count:'5'},{period_count:1.5},{quantity:4},{wholesale_usd:1},{payer_id:id},{action:'service_esim_store_daily_price'}])assert.equal((await h(req({...base,...change}))).status,400);assert.equal(calls,0);
});
test('daily purchase accepts a quote capability and stable nonce, never a client price',async()=>{
 const {createRechargeHandler}=await load();let got;const h=createRechargeHandler({authenticate:async()=>({}),call:async(c,n,p)=>{got=[n,p];return {data:{status:'SALES_DISABLED'}};}});
 const body={action:'accept_daily_purchase',quote_id:id,acceptance_key:id,request_key:id};assert.equal((await h(req(body))).status,200);assert.equal(got[0],'accept_esim_daily_purchase');assert.equal(got[1].p_request_key,id);
 assert.equal((await h(req({...body,total:1}))).status,400);
});
