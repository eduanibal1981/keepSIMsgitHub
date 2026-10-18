const {test}=require('node:test');
const assert=require('node:assert/strict');
const {createHmac,generateKeyPairSync,sign}=require('node:crypto');
const {loadEdge}=require('./edge_module_loader.cjs');
const base='https://db.invalid';
const owner='10000000-0000-4000-8000-000000000001';
const quote='20000000-0000-4000-8000-000000000001';
const phone='+447700900123';
function service(options={}) {
  let submitted=false;const calls=[];
  const stored={id:quote,user_id:owner,phone_number:phone,country_code:'GB',state:options.quoted?'quoted':'submitting',number_type:'mobile',wholesale_monthly_usd:3,wholesale_setup_usd:2};
  const fetch=async(url,init={})=>{
    calls.push({url,method:init.method||'GET',body:init.body?JSON.parse(init.body):null});
    const path=new URL(url).pathname;
    if(path.endsWith('/rpc/get_internal_secret'))return Response.json('private-provider-token');
    if(path.endsWith('/rpc/resolve_account_commerce_benefit'))return Response.json(options.tier||'free');
    if(path.endsWith('/rpc/resolve_app_fee')){const body=JSON.parse(init.body);return Response.json(body.p_base_amount*(body.p_tier==='premium'?.03:.15));}
    if(path.endsWith('/system_configs'))return Response.json(options.noProfile?[]:[{config_value:'messaging-profile'}]);
    if(path.endsWith('/rpc/authorize_second_number_purchase')){const submit=!submitted;submitted=true;return Response.json({submit,order_id:quote});}
    if(path.endsWith('/second_number_orders')) {
      if(init.method==='PATCH')return Response.json([stored]);
      if(init.method==='POST')return Response.json([{id:quote,expires_at:'2026-10-18T00:00:00Z'}]);
      return Response.json([stored]);
    }
    if(path.endsWith('/second_number_purchase_gate'))return Response.json([{enabled:!options.disabled,pilot_user_ids:[owner]}]);
    if(path.endsWith('/second_number_policies'))return Response.json([{country_code:'GB',country_name:'United Kingdom',number_type:'mobile',minimum_monthly_usd:4,usage_terms:'Approved incoming SMS subscription terms',terms_version:'pilot',kyc_status:'not_required'}]);
    if(path.endsWith('/app_fee_rules'))return Response.json([{free_percentage:15,stand_percentage:7,prem_percentage:3}]);
    if(path.endsWith('/sim_lines'))return Response.json([]);
    if(path.endsWith('/rpc/finish_second_number_purchase')||path.endsWith('/rpc/fail_second_number_purchase'))return Response.json(null);
    if(path==='/v2/available_phone_numbers')return Response.json({data:options.inventory||[{phone_number:phone,features:[{name:'sms'}],cost_information:{monthly_cost:'3.00',upfront_cost:'2.00',currency:'USD'}}]});
    if(path==='/v2/number_orders'&&init.method==='POST'){
      if(options.timeout)throw Error('network timeout');
      return Response.json({data:{id:'provider-order'}},{status:options.reject?422:200});
    }
    if(path==='/v2/number_orders')return Response.json({data:[{id:'provider-order',customer_reference:options.foreign?'foreign':quote,phone_numbers:[{phone_number:phone}],requirements_met:true,status:'success'}]});
    if(path==='/v2/phone_numbers')return Response.json({data:[{id:'provider-number',phone_number:phone,status:'active'}]});
    if(path.endsWith('/messaging'))return Response.json({data:{messaging_profile_id:options.bindFailure?'foreign':'messaging-profile'}});
    throw Error('Unexpected '+path);
  };
  const {SecondNumbers,money}=loadEdge('supabase/functions/_shared/second-number.ts',{fetch,env:{}});
  return {api:new SecondNumbers(base,'service'),money,calls,stored};
}
test('inventory quotes actual prices, setup cost and the approved retail floor; no client price authorizes a charge',async()=>{
  const f=service();const result=await f.api.search(owner,{country_code:'GB'});const n=result.numbers[0];
  assert.equal(n.total_monthly_usd,4);assert.equal(n.setup_fee_usd,2);assert.equal(n.total_due_usd,6);assert.equal(n.quote_id,quote);
  for(const field of ['monthly_number_fee_usd','app_fee_usd','wholesale_monthly_usd','wholesale_upfront_usd'])assert(!Object.hasOwn(n,field));
  assert.deepEqual(n.features,['sms']);assert(!JSON.stringify(n).includes('whatsapp'));
  assert.throws(()=>f.money(null));assert.throws(()=>f.money('Infinity'));assert.throws(()=>f.money(''));
});
test('inventory never defaults missing price/currency or advertises voice from number geography',async()=>{
  const f=service({inventory:[{phone_number:phone,features:[{name:'voice'}],cost_information:{monthly_cost:'1',currency:'USD'}},
    {phone_number:phone,features:[{name:'sms'}],cost_information:{monthly_cost:'1',currency:'EUR'}}]});
  assert.deepEqual((await f.api.search(owner,{country_code:'GB'})).numbers,[]);
});
test('duplicate purchase and network timeout never place a second carrier order or release an uncertain reservation',async()=>{
  const f=service({timeout:true});await f.api.purchase(owner,{quote_id:quote});await f.api.purchase(owner,{quote_id:quote});
  assert.equal(f.calls.filter(c=>c.url.endsWith('/v2/number_orders')&&c.method==='POST').length,1);
  assert(!f.calls.some(c=>c.url.includes('fail_second_number_purchase')));
});
test('explicit carrier rejection releases the original reservation',async()=>{
  const f=service({reject:true});await f.api.purchase(owner,{quote_id:quote});
  assert.equal(f.calls.filter(c=>c.url.includes('fail_second_number_purchase')).length,1);
});
test('missing messaging configuration prevents reservation and provider purchase',async()=>{
  const f=service({noProfile:true});await assert.rejects(f.api.purchase(owner,{quote_id:quote}));
  assert(!f.calls.some(c=>c.url.includes('authorize_second_number_purchase')||c.url.includes('api.telnyx')));
});
test('activation requires exact order/number correlation and confirmed messaging-profile binding',async()=>{
  for(const options of [{foreign:true},{bindFailure:true}]){
    const f=service(options);await f.api.reconcile(f.stored);assert(!f.calls.some(c=>c.url.includes('finish_second_number_purchase')));
  }
  const f=service();await f.api.reconcile(f.stored);assert.equal(f.calls.filter(c=>c.url.includes('finish_second_number_purchase')).length,1);
});
function smsFixture(route='did',failed=false){
  let handler;const calls=[];const pair=generateKeyPairSync('ed25519');
  const publicKey=pair.publicKey.export({format:'der',type:'spki'}).subarray(-32).toString('base64');
  const fetch=async(url,init={})=>{
    const body=init.body?JSON.parse(init.body):null;calls.push({url,body});
    if(url.endsWith('/get_internal_secret'))return Response.json('twilio-secret');
    if(url.endsWith('/route_second_number_sms'))return Response.json({route},{status:failed?503:200});
    if(url.endsWith('/consume_rate_limit'))return Response.json([{allowed:true}]);
    if(url.endsWith('/handle_inbound_command'))return Response.json({reply_text:'Balance available'});
    throw Error('Unexpected '+url);
  };
  loadEdge('supabase/functions/sms-webhook/index.ts',{fetch,serve:fn=>handler=fn,env:{SUPABASE_URL:base,SUPABASE_SERVICE_ROLE_KEY:'service',TELNYX_PUBLIC_KEY:publicKey,TWILIO_AUTH_TOKEN:'twilio-secret'}});
  const twilio=(valid=true)=>{
    const params={From:'+12025550123',To:phone,Body:'REFILL 10',MessageSid:'message'};
    const url=base+'/functions/v1/sms-webhook';
    const signature=createHmac('sha1','twilio-secret').update(url+Object.keys(params).sort().map(k=>k+params[k]).join('')).digest('base64');
    return new Request(url,{method:'POST',body:new URLSearchParams(params),headers:{'x-twilio-signature':valid?signature:'invalid'}});
  };
  const telnyx=(valid=true)=>{
    const raw=JSON.stringify({data:{event_type:'message.received',occurred_at:new Date().toISOString(),payload:{id:'telnyx-message',from:{phone_number:'Example'},to:[{phone_number:phone}],text:'Your code is 482910'}}});
    const ts=String(Math.floor(Date.now()/1000));
    const signature=sign(null,Buffer.from(ts+'|'+raw),pair.privateKey).toString('base64');
    return new Request(base+'/functions/v1/sms-webhook',{method:'POST',body:raw,headers:{'telnyx-timestamp':ts,'telnyx-signature-ed25519':valid?signature:'invalid'}});
  };
  return {handler,calls,twilio,telnyx};
}
test('signed Telnyx and Twilio DID messages route to the inbox without executing refill commands',async()=>{
  const f=smsFixture();assert.equal((await f.handler(f.twilio())).status,200);assert.equal((await f.handler(f.telnyx())).status,200);
  assert.equal(f.calls.filter(c=>c.url.endsWith('/route_second_number_sms')).length,2);
  assert(!f.calls.some(c=>c.url.endsWith('/handle_inbound_command')));
});
test('only an explicit refill route executes a command; routing failure never falls through',async()=>{
  const f=smsFixture('refill');assert.equal((await f.handler(f.twilio())).status,200);assert.equal(f.calls.filter(c=>c.url.endsWith('/handle_inbound_command')).length,1);
  for(const [item,status] of [[smsFixture('ignore'),200],[smsFixture('did',true),503]]){
    const response=await item.handler(item.twilio());assert.equal(response.status,status);
    assert(!item.calls.some(c=>c.url.endsWith('/handle_inbound_command')));
  }
});
test('forged provider signatures never reach message routing or money commands',async()=>{
  const f=smsFixture();assert.equal((await f.handler(f.twilio(false))).status,403);assert.equal((await f.handler(f.telnyx(false))).status,401);
  assert(!f.calls.some(c=>c.url.endsWith('/route_second_number_sms')||c.url.endsWith('/handle_inbound_command')));
});
function releaseFixture({legacy=false,stillOwned=false,wrongNumber=false}={}) {
  let deleted=false;let result;const calls=[];
  const fetch=async(url,init={})=>{
    calls.push({url,method:init.method||'GET'});const path=new URL(url).pathname;
    if(path.endsWith('/get_internal_secret'))return Response.json('provider-token');
    if(path.endsWith('/second_number_orders'))return Response.json([]);
    if(path.endsWith('/process_second_number_renewals'))return Response.json(0);
    if(path.endsWith('/claim_second_number_releases'))return Response.json([{id:quote,phone_number:phone,provider_sid:legacy?null:'number-id',release_claim:owner}]);
    if(path.endsWith('/finish_second_number_release')){result=JSON.parse(init.body).p_confirmed;return Response.json(null);}
    if(path.endsWith('/virtual_did_numbers'))return Response.json([]);
    if(path==='/v2/phone_numbers')return Response.json({data:deleted&&!stillOwned?[]:[{id:'number-id',phone_number:phone}]});
    if(path==='/v2/phone_numbers/number-id'){
      if(init.method==='DELETE'){deleted=true;return Response.json({data:{}}, {status:200});}
      return deleted?Response.json({},{status:404}):Response.json({data:{phone_number:wrongNumber?'+12025550199':phone}});
    }
    throw Error('Unexpected '+path);
  };
  const {SecondNumbers}=loadEdge('supabase/functions/_shared/second-number.ts',{fetch,env:{}});
  return {api:new SecondNumbers(base,'service'),calls,result:()=>result};
}
test('release confirms provider absence and resolves legacy resource IDs before deletion',async()=>{
  for(const legacy of [false,true]){
    const f=releaseFixture({legacy});await f.api.sweep();assert.equal(f.result(),true);
    assert.equal(f.calls.filter(c=>c.method==='DELETE').length,1);
    assert(f.calls.some(c=>new URL(c.url).pathname==='/v2/phone_numbers'));
  }
});
test('a missing old resource does not finish release while the exact number remains on the provider account',async()=>{
  const f=releaseFixture({stillOwned:true});await f.api.sweep();assert.equal(f.result(),false);
});
test('release never deletes a provider resource belonging to a different number',async()=>{
  const f=releaseFixture({wrongNumber:true});await f.api.sweep();assert.equal(f.result(),false);assert(!f.calls.some(c=>c.method==='DELETE'));
});

test('disabled gate and a changed supplier quote cannot submit or reserve',async()=>{
  const disabled=service({disabled:true,quoted:true});
  assert.deepEqual((await disabled.api.search(owner,{country_code:'GB'})).numbers,[]);
  await assert.rejects(disabled.api.purchase(owner,{quote_id:quote}));
  const changed=service({quoted:true,inventory:[{phone_number:phone,features:[{name:'sms'}],cost_information:{monthly_cost:'99',upfront_cost:'2',currency:'USD'}}]});
  await assert.rejects(changed.api.purchase(owner,{quote_id:quote}),/price changed/);
  for(const f of [disabled,changed])assert(!f.calls.some(c=>c.url.includes('authorize_second_number_purchase') || c.method==='POST'&&c.url.endsWith('/number_orders')));
});
test('fresh exact supplier price authorizes only the stored quote; client prices are ignored',async()=>{
  const f=service({quoted:true});await f.api.purchase(owner,{quote_id:quote,monthly_fee_usd:0,provider:'foreign'});
  const request=f.calls.find(c=>c.url.includes('authorize_second_number_purchase'));
  assert.equal(request.body.p_supplier_monthly,3);assert.equal(request.body.p_supplier_setup,2);
  assert(f.calls.find(c=>c.url.includes('available_phone_numbers')).url.includes('filter%5Bphone_number%5D%5Bstarts_with%5D'));
});

function renewalFixture(options={}) {
  const calls=[];
  const fetch=async(url,init={})=>{
    const body=init.body?JSON.parse(init.body):null;calls.push({url,method:init.method||'GET',body});
    const path=new URL(url).pathname;
    if(path.endsWith('/get_internal_secret'))return Response.json('provider-token');
    if(path.endsWith('/process_second_number_renewals'))return Response.json(0);
    if(path.endsWith('/claim_second_number_releases'))return Response.json([]);
    if(path.endsWith('/second_number_orders'))return Response.json([]);
    if(path.endsWith('/virtual_did_numbers'))return Response.json(init.method==='PATCH'?[]:[{id:quote,provider_sid:'provider-number',phone_number:phone,renews_at:'2026-10-01T00:00:00.123456+00:00'}]);
    if(path.endsWith('/system_configs'))return Response.json([{config_value:'messaging-profile'}]);
    if(path==='/v2/phone_numbers/provider-number') {
      if(options.timeout)throw Error('timeout');
      return Response.json({data:{id:'provider-number',phone_number:options.foreign?'+12025550199':phone,status:options.inactive?'deleted':'active'}});
    }
    if(path.endsWith('/messaging'))return Response.json({data:{messaging_profile_id:options.unbound?'foreign':'messaging-profile'}});
    if(path.endsWith('/settle_second_number_renewal'))return Response.json(null,{status:options.captureFailure?503:200});
    throw Error('Unexpected '+path);
  };
  const {SecondNumbers}=loadEdge('supabase/functions/_shared/second-number.ts',{fetch,env:{}});
  return {api:new SecondNumbers(base,'service'),calls};
}
test('renewal requires exact active provider resource and messaging binding; uncertainty cannot charge',async()=>{
  for(const options of [{timeout:true},{foreign:true},{inactive:true},{unbound:true}]) {
    const f=renewalFixture(options);await f.api.sweep();
    assert(!f.calls.some(c=>c.url.includes('settle_second_number_renewal')));
    assert(!f.calls.some(c=>c.body?.status==='active'));
  }
  const f=renewalFixture();await f.api.sweep();
  const capture=f.calls.find(c=>c.url.includes('settle_second_number_renewal'));
  assert.equal(capture.body.p_period_start,'2026-10-01T00:00:00.123456+00:00');
  assert.equal(capture.body.p_provider_sid,'provider-number');
});
test('failed renewal capture stays pending without any activation write',async()=>{
  const f=renewalFixture({captureFailure:true});const result=await f.api.sweep();
  assert.equal(result.errors,1);assert(!f.calls.some(c=>c.body?.status==='active'));
});
test('provider absence checks use digits only, then compare the full E.164 identity',async()=>{
  const f=releaseFixture({stillOwned:true});await f.api.sweep();
  for(const c of f.calls.filter(c=>new URL(c.url).pathname==='/v2/phone_numbers'))
    assert.match(new URL(c.url).searchParams.get('filter[phone_number]'),/^[0-9]+$/);
  assert.equal(f.result(),false);
});

test('DID pricing uses settled account entitlement and server fee rules instead of client-visible plan labels',async()=>{
  const inventory=[{phone_number:phone,features:[{name:'sms'}],cost_information:{monthly_cost:'10',upfront_cost:'0',currency:'USD'}}];
  for(const [tier,total] of [['free',11.5],['premium',10.3]]){
    const f=service({inventory,tier});const result=await f.api.search(owner,{country_code:'GB'});
    assert.equal(result.numbers[0].total_monthly_usd,total);
    assert(f.calls.some(c=>c.url.includes('resolve_account_commerce_benefit')));
    assert(!f.calls.some(c=>new URL(c.url).pathname.endsWith('/sim_lines')));
  }
});
