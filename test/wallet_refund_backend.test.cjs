const { test } = require('node:test');
const assert = require('node:assert/strict');
const { loadEdge } = require('./edge_module_loader.cjs');
const { processRefundItem, reconcileRefundIdentity } = loadEdge('supabase/functions/_shared/wallet-refunds.ts');
function fixture(overrides = {}, action) {
  const item = { id:'item',provider:'paypal',capture_id:'capture',amount:5,currency:'USD',
    idempotency_key:'ksr-'+ 'a'.repeat(32),provider_refund_id:null,...overrides };
  const calls = []; let claimed=false;
  return { item,calls,client:{async rpc(name,args){
    calls.push({name,args});
    if(name==='claim_wallet_refund_item'){
      if(claimed)return {data:{claimed:false}};
      claimed=true;return {data:{claimed:true,claim_token:'claim',action:action||(item.provider_refund_id?'poll':'submit'),item}};
    }
    if(name==='begin_wallet_refund_submission'||name==='adopt_wallet_refund_identity')return {data:true};
    if(name==='record_wallet_refund_evidence')return {data:{persisted:true}};
    if(name==='finish_wallet_refund_item')return {data:{item_status:args.p_outcome}};
    throw Error('Unexpected RPC '+name);
  }}};
}
const result=(status,extra={})=>Response.json({id:'refund',custom_id:'item',status,amount:{value:'5.00',currency_code:'USD'},...extra});
test('simultaneous processors persist a boundary then issue one payout with a stable bounded provider key',async()=>{
 const f=fixture();let requests=0;
 const fetcher=async(url,options)=>{requests++;assert.equal(options.method,'POST');assert.equal(options.headers['PayPal-Request-Id'],f.item.idempotency_key);
   assert.ok(options.headers['PayPal-Request-Id'].length<=38);assert.equal(JSON.parse(options.body).custom_id,'item');
   assert.equal(f.calls.at(-1).name,'begin_wallet_refund_submission');return result('COMPLETED');};
 const outcomes=await Promise.all([processRefundItem(f.client,'item','https://provider.test','token',fetcher),processRefundItem(f.client,'item','https://provider.test','token',fetcher)]);
 assert.equal(requests,1);assert.deepEqual(outcomes.sort(),['completed','unclaimed']);
 assert.deepEqual(f.calls.slice(-2).map(c=>c.name),['record_wallet_refund_evidence','finish_wallet_refund_item']);
});
test('PENDING records evidence and keeps funds reserved',async()=>{
 const f=fixture();assert.equal(await processRefundItem(f.client,'item','https://provider.test','token',async()=>result('PENDING')),'pending');
 assert.equal(f.calls.at(-1).args.p_provider_refund_id,'refund');assert.equal(f.calls.at(-1).args.p_outcome,'pending');
});
test('known refunds are polled without opening another submission boundary',async()=>{
 const f=fixture({provider_refund_id:'refund'});
 await processRefundItem(f.client,'item','https://provider.test','token',async(url,options)=>{
   assert.equal(url,'https://provider.test/v2/payments/refunds/refund');assert.equal(options.method,'GET');return result('COMPLETED');});
 assert.equal(f.calls.some(c=>c.name==='begin_wallet_refund_submission'),false);
 assert.equal(f.calls.at(-1).args.p_outcome,'completed');
});
for(const scenario of ['timeout','invalid-json','server-error','wrong-amount','wrong-currency','wrong-provider-id','wrong-custom-id','wrong-capture','missing-amount','non-finite-amount']){
 test(scenario+' retains exposure and cannot complete or fail the payout',async()=>{
  const f=fixture(scenario==='wrong-provider-id'?{provider_refund_id:'original'}:{});
  const fetcher=async()=>{
   if(scenario==='timeout')throw Error('timeout');
   if(scenario==='invalid-json')return new Response('malformed');
   if(scenario==='server-error')return Response.json({},{status:503});
   if(scenario==='wrong-amount')return result('COMPLETED',{amount:{value:'50.00',currency_code:'USD'}});
   if(scenario==='wrong-currency')return result('COMPLETED',{amount:{value:'5.00',currency_code:'EUR'}});
   if(scenario==='wrong-custom-id')return result('COMPLETED',{custom_id:'another-item'});
   if(scenario==='wrong-capture')return result('COMPLETED',{links:[{rel:'up',href:'https://provider.test/v2/payments/captures/other'}]});
   if(scenario==='missing-amount')return result('COMPLETED',{amount:null});
   if(scenario==='non-finite-amount')return result('COMPLETED',{amount:{value:'Infinity',currency_code:'USD'}});
   return result('COMPLETED');
  };
  assert.equal(await processRefundItem(f.client,'item','https://provider.test','token',fetcher),'unknown');
  assert.equal(f.calls.at(-1).args.p_outcome,'unknown');
 });
}
for(const status of ['FAILED','CANCELLED'])test(status+' releases only when the complete evidence matches',async()=>{
 const f=fixture();assert.equal(await processRefundItem(f.client,'item','https://provider.test','token',async()=>result(status)),'failed');
 const wrong=fixture();assert.equal(await processRefundItem(wrong.client,'item','https://provider.test','token',async()=>result(status,{amount:{value:'99.00',currency_code:'USD'}})),'unknown');
});
test('persisted completed evidence settles after a crash without any provider request',async()=>{
 const f=fixture({provider_refund_id:'refund',provider_outcome:'completed'},'settle');
 assert.equal(await processRefundItem(f.client,'item','https://provider.test','token',async()=>{throw Error('Provider must not be called');}),'completed');
 assert.deepEqual(f.calls.map(c=>c.name),['claim_wallet_refund_item','finish_wallet_refund_item']);
});
test('failed financial settlement preserves durable evidence and requests reconciliation',async()=>{
 const f=fixture(),rpc=f.client.rpc;
 f.client.rpc=async(name,args)=>name==='finish_wallet_refund_item'&&args.p_outcome==='completed'
  ?(f.calls.push({name,args}),{error:{message:'db unavailable'}}):rpc(name,args);
 await assert.rejects(processRefundItem(f.client,'item','https://provider.test','token',async()=>result('COMPLETED')),/reconciliation/);
 assert.ok(f.calls.some(c=>c.name==='record_wallet_refund_evidence'&&c.args.p_outcome==='completed'));
 assert.equal(f.calls.at(-1).args.p_outcome,'unknown');
});
test('a refused submission boundary never calls the provider',async()=>{
 const f=fixture(),rpc=f.client.rpc;
 f.client.rpc=async(name,args)=>name==='begin_wallet_refund_submission'?{data:false}:rpc(name,args);
 assert.equal(await processRefundItem(f.client,'item','https://provider.test','token',async()=>assert.fail('Unexpected POST')),'unclaimed');
});
test('failed evidence persistence never attempts financial settlement',async()=>{
 const f=fixture(),rpc=f.client.rpc;
 f.client.rpc=async(name,args)=>name==='record_wallet_refund_evidence'?{error:{message:'db unavailable'}}:rpc(name,args);
 await assert.rejects(processRefundItem(f.client,'item','https://provider.test','token',async()=>result('COMPLETED')),/evidence/);
 assert.equal(f.calls.some(c=>c.name==='finish_wallet_refund_item'),false);
});
test('ambiguous submitted work stays quarantined instead of resubmitting after a stale claim',async()=>{
 const client={rpc:async()=>({data:{claimed:false,reconciliation_required:true}})};
 assert.equal(await processRefundItem(client,'item','https://provider.test','token',async()=>assert.fail('Unexpected provider request')),'reconciliation_required');
});
test('operator identity recovery requires parent capture, exact amount, custom item identity and currency',async()=>{
 for(const change of [{},{custom_id:'other'},{id:'other'},{amount:{value:'6.00',currency_code:'USD'}},{links:[]}]){
  const f=fixture();const response={links:[{rel:'up',href:'https://provider.test/v2/payments/captures/capture'}],...change};
  const recovery=()=>reconcileRefundIdentity(f.client,f.item,'refund','https://provider.test','token','admin',async()=>result('COMPLETED',response));
  if(Object.keys(change).length){await assert.rejects(recovery);assert.equal(f.calls.length,0);}
  else{await recovery();assert.equal(f.calls.at(-1).name,'adopt_wallet_refund_identity');assert.equal(f.calls.at(-1).args.p_actor_user_id,'admin');}
 }
});
