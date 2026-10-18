const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const { loadEdge, builder } = require('./edge_module_loader.cjs');
const project='https://project.invalid', api='https://api-m.sandbox.paypal.com';
const user='10000000-0000-4000-8000-000000000001',other='10000000-0000-4000-8000-000000000002';
async function fixture(t, options={}) {
  const modulePath=process.env.PGLITE_MODULE_PATH||path.join(process.cwd(),'tools/financial-tests/node_modules/@electric-sql/pglite/dist/index.js');
  const {PGlite}=await import(pathToFileURL(modulePath).href);
  const {bootstrapPayPal,seedPayPal}=await import('../tools/financial-tests/paypal-bootstrap.mjs');
  const db=new PGlite(); t.after(()=>db.close());
  await bootstrapPayPal(sql=>db.exec(sql)); await seedPayPal((sql,args)=>db.query(sql,args));
  if(options.stored) for(const [key,value] of Object.entries(options.stored)) {
    assert.ok(['kind','status','amount_usd','merchant_id','user_id'].includes(key));
    await db.query(`update public.paypal_orders set ${key}=$1 where order_id='ORDER0001'`,[value]);
  }
  let provider={id:'ORDER0001',intent:'CAPTURE',status:options.completed?'COMPLETED':'APPROVED',purchase_units:[{
    custom_id:JSON.stringify({u:user,k:'deposit'}),payee:{merchant_id:'MERCHANT00001'},amount:{currency_code:'USD',value:'10.00'},
    payments:{captures:options.completed?[{id:'CAPTURE001',status:'COMPLETED',amount:{currency_code:'USD',value:'10.00'},final_capture:true}]:[]},
  }]};
  if(options.provider)options.provider(provider);
  const requests=[],mutations=[]; let failures=options.dbFailures||0;
  const rpc=async(name,args)=>{
    if(name==='get_internal_secret')return {data:options.missingSecret?null:'fixture-secret',error:null};
    if(name==='consume_rate_limit')return {data:[{allowed:true}],error:null};
    if(name==='log_app_check_result')return {data:null,error:null};
    if(name==='app_check_should_enforce')return {data:false,error:null};
    if(name==='guard_money_action')return {data:{blocked:false},error:null};
    if(name==='attach_device_money_reference')return {data:null,error:null};
    assert.equal(name,'fulfill_paypal_capture');mutations.push(args);
    if(failures-->0)return {data:null,error:{message:'fixture database unavailable'}};
    try{return {data:(await db.query('select public.fulfill_paypal_capture($1,$2::jsonb) as result',[args.p_order_id,JSON.stringify(args.p_evidence)])).rows[0].result,error:null};}
    catch(error){return {data:null,error:{message:error.message}};}
  };
  const client={auth:{getUser:async(token)=>({data:{user:token==='valid'?{id:options.user||user}:null},error:token==='valid'?null:Error('invalid')})},rpc,
    from:table=>builder(async(filters,ops)=>{
      if(table==='system_configs')return {data:null,error:null};
      assert.equal(table,'paypal_orders');
      if(ops.insert){const o=ops.insert;await db.query('insert into public.paypal_orders(order_id,user_id,kind,amount_usd,status,merchant_id) values($1,$2,$3,$4,$5,$6)',[o.order_id,o.user_id,o.kind,o.amount_usd,o.status,o.merchant_id]);return {error:null};}
      return {data:(await db.query('select * from public.paypal_orders where order_id=$1',[filters.order_id])).rows[0]||null,error:null};
    })};
  const fetch=async(address,init={})=>{
    requests.push({address:String(address),...init});
    if(address===api+'/v1/oauth2/token')return Response.json({access_token:'provider-access'});
    if(address===api+'/v1/notifications/verify-webhook-signature')return Response.json({verification_status:options.badSignature?'FAILURE':'SUCCESS'});
    if(address===api+'/v2/checkout/orders'&&init.method==='POST')return Response.json({id:'ORDERNEW1',links:[{rel:'approve',href:'https://approval.invalid/'}]});
    if(address===api+'/v2/checkout/orders/ORDER0001/capture'){
      if(!options.noCapture){provider.status='COMPLETED';provider.purchase_units[0].payments.captures=[{id:'CAPTURE001',status:'COMPLETED',amount:{currency_code:'USD',value:'10.00'},final_capture:true}];}
      if(options.timeout)throw Error('provider timeout after capture');
      return Response.json(options.alreadyCaptured?{details:[{issue:'ORDER_ALREADY_CAPTURED'}]}:provider,{status:options.alreadyCaptured?422:201});
    }
    if(address===api+'/v2/checkout/orders/ORDER0001')return Response.json(provider);
    if(String(address).startsWith(project+'/rest/v1/rpc/')){
      const result=await rpc(String(address).split('/').pop(),JSON.parse(init.body));
      return Response.json(result.error||result.data,{status:result.error?500:200});
    }
    if(String(address).startsWith(project+'/rest/v1/paypal_orders?')){
      const params=new URL(address).searchParams;
      const id=params.get('order_id').slice(3);
      if(init.method==='PATCH'){
        await db.query("update public.paypal_orders set status='failed' where order_id=$1 and status<>'captured'",[id]);return Response.json([]);
      }
      return Response.json((await db.query('select * from public.paypal_orders where order_id=$1',[id])).rows);
    }
    if(String(address).endsWith('/system_alerts'))return Response.json([]);
    throw Error('Unexpected request '+address);
  };
  const env={SUPABASE_URL:project,SUPABASE_SERVICE_ROLE_KEY:'service',PAYPAL_MERCHANT_ID:'MERCHANT00001',PAYPAL_API_BASE:api,PAYPAL_WEBHOOK_ID:'webhook',...options.env};
  const handlers={};
  for(const slug of ['capture-paypal-order','paypal-webhook','create-paypal-order'])loadEdge('supabase/functions/'+slug+'/index.ts',{serve:fn=>handlers[slug]=fn,createClient:()=>client,env,fetch});
  const capture=(body={order_id:'ORDER0001'},token='valid')=>handlers['capture-paypal-order'](new Request(project+'/capture',{method:'POST',headers:{authorization:'Bearer '+token},body:JSON.stringify(body)}));
  const webhook=(type='PAYMENT.CAPTURE.COMPLETED',overrides={})=>handlers['paypal-webhook'](new Request(project+'/webhook',{method:'POST',headers:{'paypal-transmission-id':'transmission','paypal-transmission-time':new Date().toISOString(),'paypal-cert-url':'https://api.paypal.com/cert','paypal-auth-algo':'SHA256withRSA','paypal-transmission-sig':'fixture-signature'},
    body:JSON.stringify({id:'EVENT001',event_type:type,resource:{id:type==='CHECKOUT.ORDER.APPROVED'?'ORDER0001':'CAPTURE001',status:'COMPLETED',amount:{currency_code:'USD',value:'10.00'},supplementary_data:{related_ids:{order_id:'ORDER0001'}},...overrides}})}));
  const counts=async()=>(await db.query(`select jsonb_build_object('balance',(select sum(balance) from public.wallets),'ledger',(select count(*) from public.wallet_transactions),'lots',(select count(*) from public.wallet_funding_lots),'receipts',(select count(*) from public.paypal_capture_receipts),'captured',(select count(*) from public.paypal_orders where status='captured')) as result`)).rows[0].result;
  return {db,provider,requests,mutations,capture,webhook,counts,handlers};
}
const funded={balance:10,ledger:1,lots:1,receipts:1,captured:1};
test('client-first, webhook-first and concurrent paths commit one deposit and one funding lot',async t=>{
  for(const scenario of ['client-first','webhook-first','concurrent']){
    const f=await fixture(t,{completed:scenario!=='client-first'});
    if(scenario==='client-first'){assert.equal((await f.capture()).status,200);assert.equal((await f.webhook()).status,200);}
    else if(scenario==='webhook-first'){assert.equal((await f.webhook()).status,200);assert.equal((await f.capture()).status,200);}
    else {const responses=await Promise.all([f.capture(),f.webhook(),f.capture(),f.webhook()]);assert.ok(responses.every(r=>r.status===200));}
    assert.deepEqual(await f.counts(),funded);
  }
});
test('ORDER_ALREADY_CAPTURED and ambiguous provider timeout adopt only an authoritative completed capture',async t=>{
  for(const options of [{alreadyCaptured:true},{timeout:true}]){
    const f=await fixture(t,options);assert.equal((await f.capture()).status,200);assert.deepEqual(await f.counts(),funded);
    const post=f.requests.find(r=>r.address.endsWith('/capture'));assert.match(post.headers['PayPal-Request-Id'],/^ksc-[0-9a-f]{32}$/);
  }
  const f=await fixture(t,{alreadyCaptured:true,noCapture:true});assert.equal((await f.capture()).status,409);assert.equal((await f.counts()).ledger,0);
});
test('database failure after PayPal capture returns retryable failure without a false captured status',async t=>{
  const f=await fixture(t,{dbFailures:1});assert.equal((await f.capture()).status,503);
  assert.equal((await f.counts()).captured,0);assert.equal((await f.capture()).status,200);assert.deepEqual(await f.counts(),funded);
  assert.equal(f.requests.filter(r=>r.address.endsWith('/capture')).length,1);
});
test('failed webhook fulfillment is retryable and duplicate completed callbacks credit once',async t=>{
  const f=await fixture(t,{completed:true,dbFailures:1});assert.equal((await f.webhook()).status,503);
  assert.equal((await f.webhook()).status,200);assert.equal((await f.webhook()).status,200);assert.deepEqual(await f.counts(),funded);
});
test('APPROVED captures but never credits or exposes captured before completed-event fulfillment',async t=>{
  const f=await fixture(t);assert.equal((await f.webhook('CHECKOUT.ORDER.APPROVED')).status,200);
  assert.equal((await f.counts()).captured,0);assert.equal((await f.counts()).ledger,0);
  assert.equal((await f.webhook()).status,200);assert.deepEqual(await f.counts(),funded);
  assert.equal((await f.webhook('CHECKOUT.ORDER.APPROVED')).status,200);assert.deepEqual(await f.counts(),funded);
});
test('provider owner/purpose/payee/amount/currency mismatch rejects before capture and credit',async t=>{
  const changes=[p=>p.purchase_units[0].custom_id=JSON.stringify({u:other,k:'deposit'}),p=>p.purchase_units[0].custom_id=JSON.stringify({u:user,k:'plan'}),
    p=>p.purchase_units[0].payee.merchant_id='FOREIGN',p=>p.purchase_units[0].amount.value='10.01',p=>p.purchase_units[0].amount.currency_code='EUR'];
  for(const change of changes){const f=await fixture(t,{provider:change});assert.equal((await f.capture()).status,409);assert.equal(f.requests.some(r=>r.address.endsWith('/capture')),false);assert.equal(f.mutations.length,0);}
});
test('foreign and invalid client tokens cannot cause provider actions or fulfillment',async t=>{
  let f=await fixture(t,{user:other});assert.equal((await f.capture()).status,403);assert.equal(f.requests.length,0);assert.equal(f.mutations.length,0);
  f=await fixture(t);assert.equal((await f.capture(undefined,'forged')).status,401);assert.equal(f.requests.length,0);assert.equal(f.mutations.length,0);
});
test('missing merchant/credentials and invalid webhook signatures cannot credit',async t=>{
  for(const options of [{env:{PAYPAL_MERCHANT_ID:''}},{missingSecret:true},{badSignature:true,completed:true}]){
    const f=await fixture(t,options);const response=options.badSignature?await f.webhook():await f.capture();assert.ok([400,503].includes(response.status));assert.equal(f.mutations.length,0);assert.equal((await f.counts()).ledger,0);
  }
});
test('wrong event capture identity, amount, currency or missing local order cannot credit',async t=>{
  for(const resource of [{id:'FOREIGNCAP'},{payee:{merchant_id:'FOREIGN'}},{custom_id:JSON.stringify({u:other,k:'deposit'})},{amount:{currency_code:'USD',value:'10.01'}},{amount:{currency_code:'EUR',value:'10.00'}},{supplementary_data:{related_ids:{order_id:'UNKNOWN1'}}}]){
    const f=await fixture(t,{completed:true});assert.ok([409,503].includes((await f.webhook('PAYMENT.CAPTURE.COMPLETED',resource)).status));assert.equal(f.mutations.length,0);
  }
});
test('premature legacy captured flag cannot suppress a missing credit',async t=>{
  const f=await fixture(t,{completed:true,stored:{status:'captured'}});assert.equal((await f.capture()).status,200);assert.deepEqual(await f.counts(),funded);
});
test('late failed events cannot downgrade a fulfilled order',async t=>{
  const f=await fixture(t,{completed:true});await f.webhook();assert.equal((await f.webhook('PAYMENT.CAPTURE.DENIED')).status,200);assert.deepEqual(await f.counts(),funded);
});
test('new deposit orders pin the configured merchant in PayPal and local records',async t=>{
  const f=await fixture(t);const response=await f.handlers['create-paypal-order'](new Request(project+'/create',{method:'POST',headers:{authorization:'Bearer valid'},body:JSON.stringify({kind:'deposit',amount_usd:10})}));
  assert.equal(response.status,200);const create=f.requests.find(r=>r.address===api+'/v2/checkout/orders'&&r.method==='POST');assert.equal(JSON.parse(create.body).purchase_units[0].payee.merchant_id,'MERCHANT00001');
  assert.equal((await f.db.query("select merchant_id from public.paypal_orders where order_id='ORDERNEW1'")).rows[0].merchant_id,'MERCHANT00001');
});

test('concurrent approval and client capture use the same provider idempotency key',async t=>{
  const f=await fixture(t);const responses=await Promise.all([f.capture(),f.webhook('CHECKOUT.ORDER.APPROVED')]);
  assert.ok(responses.every(r=>r.status===200));assert.equal((await f.webhook()).status,200);assert.deepEqual(await f.counts(),funded);
  const posts=f.requests.filter(r=>r.address.endsWith('/capture'));assert.ok(posts.length>=1);assert.equal(new Set(posts.map(p=>p.headers['PayPal-Request-Id'])).size,1);
});
test('completed orders without one full completed capture are never credited',async t=>{
  for(const change of [p=>p.purchase_units[0].payments.captures=[],p=>delete p.purchase_units[0].payments.captures[0].id,
    p=>p.purchase_units[0].payments.captures[0].status='PENDING',p=>p.purchase_units[0].payments.captures.push({...p.purchase_units[0].payments.captures[0],id:'CAPTURE002'})]){
    const f=await fixture(t,{completed:true,provider:change});assert.equal((await f.capture()).status,409);assert.equal(f.mutations.length,0);
  }
});
