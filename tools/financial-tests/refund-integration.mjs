import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
const { loadEdge }=createRequire(import.meta.url)('../../test/edge_module_loader.cjs');
const { processRefundItem,reconcileRefundIdentity }=loadEdge(fileURLToPath(new URL('../../supabase/functions/_shared/wallet-refunds.ts',import.meta.url)));
const rpcNames=new Set(['claim_wallet_refund_item','begin_wallet_refund_submission','record_wallet_refund_evidence','finish_wallet_refund_item','adopt_wallet_refund_identity']);
export function refundRPC(db,intercept){
 return {async rpc(name,args){
  assert.ok(rpcNames.has(name));
  if(intercept){const overridden=await intercept(name,args);if(overridden)return overridden;}
  const entries=Object.entries(args);assert.ok(entries.every(([key])=>/^p_[a-z_]+$/.test(key)));
  try{return {data:(await db.query(`SELECT public.${name}(${entries.map(([key],i)=>`${key}=>$${i+1}`).join(',')}) AS result`,entries.map(([,value])=>value))).rows[0].result,error:null};}
  catch(error){return {data:null,error:{code:error.code,message:error.message}};}
 }};
}
const scalar=async(db,sql,args=[])=>Object.values((await db.query(sql,args)).rows[0])[0];
async function seed(db,amount=10){
 const user=crypto.randomUUID();await db.query('INSERT INTO auth.users(id,email) VALUES($1,$2)',[user,user+'@keepsims.test']);
 await db.query('INSERT INTO public.profiles(id,email) VALUES($1,$2)',[user,user+'@keepsims.test']);
 await db.query("SELECT public.credit_wallet_for_deposit($1,$2,'fixture',$3,jsonb_build_object('paypal_capture_id',$4::text))",[user,amount,'paypal_'+user,user]);
 const request=await scalar(db,'SELECT public.request_wallet_refund_once($1,5,$2)',[user,'intent_'+crypto.randomUUID()]);
 const item=(await db.query('SELECT * FROM public.wallet_refund_items WHERE refund_request_id=$1',[request.refund_request_id])).rows[0];
 return {user,request,item};
}
function provider(item,options={}){
 const calls=[];let posts=0,gets=0;
 const refund={id:'provider_'+item.id,custom_id:item.id,status:options.pending?'PENDING':'COMPLETED',
  amount:{value:Number(item.amount).toFixed(2),currency_code:item.currency},links:[{rel:'up',href:'https://provider.test/v2/payments/captures/'+item.capture_id}]};
 return {calls,refund,get posts(){return posts;},get gets(){return gets;},async fetch(url,init={}){
  calls.push({url,method:init.method||'GET'});
  if(init.method==='POST'){
   posts++;assert.equal(JSON.parse(init.body).custom_id,item.id);
   assert.equal(init.headers['PayPal-Request-Id'],item.idempotency_key);assert.ok(item.idempotency_key.length<=38);
   if(options.timeout)throw Error('lost provider response');
  }else gets++;
  return Response.json(refund);
 }};
}
async function balances(db,user){
 return (await db.query(`SELECT w.balance::text AS balance,
  (SELECT coalesce(sum(remaining_amount),0)::text FROM public.wallet_funding_lots WHERE wallet_id=w.id) AS lots,
  (SELECT coalesce(sum(amount),0)::text FROM public.wallet_holds WHERE wallet_id=w.id AND status='active') AS held,
  (SELECT count(*)::int FROM public.wallet_transactions WHERE wallet_id=w.id AND type='refund_payout') AS payouts
  FROM public.wallets w WHERE user_id=$1`,[user])).rows[0];
}
async function assertState(db,user,balance,held,payouts){
 const actual=await balances(db,user);assert.equal(Number(actual.balance),balance);assert.equal(Number(actual.lots),balance);
 assert.equal(Number(actual.held),held);assert.equal(actual.payouts,payouts);
 assert.equal(Number(await scalar(db,'SELECT drift FROM public.wallet_reconciliation WHERE user_id=$1',[user])),0);
}
export async function runRefundIntegration({owner,one,two},check){
 await check('actual adapter and SQL: concurrent processors issue one provider payout and one ledger debit',async()=>{
  const f=await seed(owner),p=provider(f.item);
  const outcomes=await Promise.all([processRefundItem(refundRPC(one),f.item.id,'https://provider.test','fixture',p.fetch),
   processRefundItem(refundRPC(two),f.item.id,'https://provider.test','fixture',p.fetch)]);
  assert.deepEqual(outcomes.sort(),['completed','unclaimed']);assert.equal(p.posts,1);assert.equal(p.gets,0);
  await assertState(owner,f.user,5,0,1);
 });
 await check('actual adapter and SQL: known PENDING refund is polled then settled without another POST',async()=>{
  const f=await seed(owner),p=provider(f.item,{pending:true}),client=refundRPC(one);
  assert.equal(await processRefundItem(client,f.item.id,'https://provider.test','fixture',p.fetch),'pending');
  await assertState(owner,f.user,10,5,0);p.refund.status='COMPLETED';
  assert.equal(await processRefundItem(client,f.item.id,'https://provider.test','fixture',p.fetch),'completed');
  assert.equal(p.posts,1);assert.equal(p.gets,1);await assertState(owner,f.user,5,0,1);
 });
 await check('actual adapter and SQL: provider success and settlement rollback recover from durable evidence',async()=>{
  const f=await seed(owner),p=provider(f.item),client=refundRPC(one);
  await owner.query("ALTER TABLE public.wallet_transactions ADD CONSTRAINT fixture_provider_success_rollback CHECK(type<>'refund_payout') NOT VALID");
  try{
   await assert.rejects(processRefundItem(client,f.item.id,'https://provider.test','fixture',p.fetch),/settlement/);
   await assertState(owner,f.user,10,5,0);
   assert.equal(await scalar(owner,'SELECT provider_outcome FROM public.wallet_refund_items WHERE id=$1',[f.item.id]),'completed');
  }finally{await owner.query('ALTER TABLE public.wallet_transactions DROP CONSTRAINT fixture_provider_success_rollback');}
  assert.equal(await processRefundItem(client,f.item.id,'https://provider.test','fixture',p.fetch),'completed');
  assert.equal(p.posts,1);assert.equal(p.gets,0);await assertState(owner,f.user,5,0,1);
 });
 await check('actual adapter and SQL: a lost POST response never resubmits and verified operator recovery polls the original refund',async()=>{
  const f=await seed(owner),p=provider(f.item,{timeout:true}),client=refundRPC(one);
  assert.equal(await processRefundItem(client,f.item.id,'https://provider.test','fixture',p.fetch),'unknown');
  await owner.query("UPDATE public.wallet_refund_items SET claimed_at=now()-interval '8 days' WHERE id=$1",[f.item.id]);
  for(let i=0;i<3;i++)assert.equal(await processRefundItem(client,f.item.id,'https://provider.test','fixture',p.fetch),'reconciliation_required');
  assert.equal(p.posts,1);await assertState(owner,f.user,10,5,0);
  await reconcileRefundIdentity(client,f.item,p.refund.id,'https://provider.test','fixture',null,p.fetch);
  assert.equal(await processRefundItem(client,f.item.id,'https://provider.test','fixture',p.fetch),'completed');
  assert.equal(p.posts,1);assert.equal(p.gets,2);await assertState(owner,f.user,5,0,1);
  assert.equal(Number(await scalar(owner,"SELECT count(*) FROM public.security_logs WHERE event_type='wallet_refund_identity_adopted' AND metadata->>'refund_item_id'=$1",[f.item.id])),1);
 });
 await check('actual adapter and SQL: a crash before submission is reclaimed without duplicate POSTs',async()=>{
  const f=await seed(owner),p=provider(f.item);
  const claim=await scalar(one,'SELECT public.claim_wallet_refund_item($1)',[f.item.id]);
  await owner.query("UPDATE public.wallet_refund_items SET claimed_at=now()-interval '6 minutes' WHERE id=$1",[f.item.id]);
  assert.equal(await processRefundItem(refundRPC(two),f.item.id,'https://provider.test','fixture',p.fetch),'completed');
  await assert.rejects(scalar(one,'SELECT public.begin_wallet_refund_submission($1,$2)',[f.item.id,claim.claim_token]));
  assert.equal(p.posts,1);await assertState(owner,f.user,5,0,1);
 });
 await check('actual adapter and SQL: client intent retries adopt completed refunds, while a new key creates a distinct request',async()=>{
  const f=await seed(owner),p=provider(f.item),key=await scalar(owner,'SELECT request_key FROM public.wallet_refund_request_keys WHERE refund_request_id=$1',[f.request.refund_request_id]);
  assert.equal(await processRefundItem(refundRPC(one),f.item.id,'https://provider.test','fixture',p.fetch),'completed');
  const retries=await Promise.all([one,two].map(db=>scalar(db,'SELECT public.request_wallet_refund_once($1,5,$2)',[f.user,key])));
  assert.ok(retries.every(r=>r.refund_request_id===f.request.refund_request_id&&r.already_requested));
  assert.equal(Number(await scalar(owner,'SELECT count(*) FROM public.wallet_refund_requests WHERE user_id=$1',[f.user])),1);
  await assert.rejects(scalar(one,'SELECT public.request_wallet_refund_once($1,4,$2)',[f.user,key]),/key mismatch/);
  const next=await scalar(one,'SELECT public.request_wallet_refund_once($1,5,$2)',[f.user,'new_intent_'+crypto.randomUUID()]);
  assert.notEqual(next.refund_request_id,f.request.refund_request_id);await assertState(owner,f.user,5,5,1);assert.equal(p.posts,1);
 });
}
