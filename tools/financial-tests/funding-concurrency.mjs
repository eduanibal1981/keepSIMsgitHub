import assert from 'node:assert/strict';
const scalar=async(db,sql,args=[])=>Object.values((await db.query(sql,args)).rows[0])[0];
async function user(db,cash=10,promo=0){
 const id=crypto.randomUUID();await db.query('INSERT INTO auth.users(id,email) VALUES($1,$2)',[id,id+'@keepsims.test']);
 await db.query('INSERT INTO public.profiles(id,email) VALUES($1,$2)',[id,id+'@keepsims.test']);
 await db.query('SELECT public.ensure_wallet_v2($1)',[id]);
 if(cash)await db.query("SELECT public.credit_wallet_for_deposit($1,$2,'fixture',$3,jsonb_build_object('paypal_capture_id',$4::text))",[id,cash,'paypal_'+id,id]);
 if(promo)await db.query("SELECT public.credit_wallet_for_deposit($1,$2,'referral_credit',$3)",[id,promo,'refredeem_'+id]);
 return id;
}
async function actor(db,id=null,admin=false){
 await db.query('RESET ROLE');await db.query('SET ROLE '+(id?'authenticated':'service_role'));
 await db.query("SELECT set_config('request.jwt.claims',$1,false)",[JSON.stringify(id?{role:'authenticated',sub:id,app_metadata:{is_power_user:admin}}:{role:'service_role'})]);
}
async function invariant(db,ids){
 for(const id of ids){
  const row=(await db.query(`SELECT w.balance,(SELECT coalesce(sum(remaining_amount),0) FROM public.wallet_funding_lots WHERE wallet_id=w.id) AS lots,
    (SELECT coalesce(sum(amount),0) FROM public.wallet_holds WHERE wallet_id=w.id AND status='active') AS held,
    (SELECT drift FROM public.wallet_reconciliation WHERE wallet_id=w.id) AS drift FROM public.wallets w WHERE user_id=$1`,[id])).rows[0];
  assert.equal(Number(row.balance),Number(row.lots));assert.ok(Number(row.balance)>=Number(row.held));assert.equal(Number(row.drift),0);
  await db.query('SELECT public.assert_wallet_funding_integrity((SELECT id FROM public.wallets WHERE user_id=$1))',[id]);
 }
}
export async function runFundingConcurrency({owner,one,two},check){
 const run=async(name,body)=>check(name,async()=>{try{await body();}finally{await actor(one);await actor(two);}});
 await run('concurrent eSIM aliases restore mixed original funding once and reject over-reversal',async()=>{
  const id=await user(owner,10,2),ref=crypto.randomUUID();
  await owner.query("SELECT public.debit_wallet_for_topup($1,NULL,5,'fixture',$2,'esim_purchase_debit')",[id,'esim_'+ref]);
  const refunds=await Promise.all([scalar(one,"SELECT public.credit_wallet_for_refund($1,5,$2,'worker',NULL,'refund')",[id,'esim_refund_'+ref]),
   scalar(two,"SELECT public.credit_wallet_for_refund($1,5,$2,'reaper',NULL,'esim_purchase_refund')",[id,'esim_refund_'+ref])]);
  assert.equal(refunds[0],refunds[1]);assert.equal(Number(await scalar(owner,'SELECT count(*) FROM public.wallet_funding_lots WHERE user_id=$1',[id])),2);
  assert.equal(Number(await scalar(owner,"SELECT remaining_amount FROM public.wallet_funding_lots WHERE user_id=$1 AND origin_type='promotional'",[id])),2);
  const other=crypto.randomUUID();await owner.query("SELECT public.debit_wallet_for_topup($1,NULL,5,'fixture',$2,'esim_purchase_debit')",[id,'esim_'+other]);
  const races=await Promise.allSettled([scalar(one,"SELECT public.credit_wallet_for_refund($1,5,$2,'worker')",[id,'esim_refund_'+other]),
   scalar(two,"SELECT public.credit_wallet_for_refund($1,5,$2,'reaper',NULL,'esim_purchase_refund')",[id,'refund_esim_'+other])]);
  assert.equal(races.filter(r=>r.status==='fulfilled').length,1);await invariant(owner,[id]);
  assert.equal(Number(await scalar(owner,"SELECT (public.quote_wallet_refund($1)->>'eligible_amount')::numeric",[id])),10);
 });
 await run('competing gifts spend only remaining transferable cash and cannot launder promotional rewards',async()=>{
  const sender=await user(owner,3,5),recipient=await user(owner,0);
  await actor(one,sender);await actor(two,sender);
  const gifts=await Promise.all([one,two].map((db,i)=>scalar(db,'SELECT public.transfer_wallet_credit($1,2,$2)',[recipient+'@keepsims.test','gift_'+crypto.randomUUID()+i])));
  assert.equal(gifts.filter(r=>r.success).length,1);assert.equal(gifts.filter(r=>r.code==='NOT_GIFTABLE').length,1);
  assert.equal(Number(await scalar(owner,'SELECT balance FROM public.wallets WHERE user_id=$1',[recipient])),2);
  assert.equal(Number(await scalar(owner,"SELECT remaining_amount FROM public.wallet_funding_lots WHERE user_id=$1 AND origin_type='promotional'",[sender])),5);
  await invariant(owner,[sender,recipient]);
 });
 await run('opposing gifts lock wallets consistently and preserve nonrefundable recipient provenance',async()=>{
  const a=await user(owner),b=await user(owner);await actor(one,a);await actor(two,b);
  const gifts=await Promise.all([scalar(one,'SELECT public.transfer_wallet_credit($1,2,$2)',[b+'@keepsims.test','gift_'+crypto.randomUUID()]),
   scalar(two,'SELECT public.transfer_wallet_credit($1,3,$2)',[a+'@keepsims.test','gift_'+crypto.randomUUID()])]);
  assert.ok(gifts.every(r=>r.success));assert.equal(Number(await scalar(owner,'SELECT balance FROM public.wallets WHERE user_id=$1',[a])),11);
  assert.equal(Number(await scalar(owner,'SELECT balance FROM public.wallets WHERE user_id=$1',[b])),9);
  assert.equal(Number(await scalar(owner,"SELECT count(*) FROM public.wallet_funding_lots WHERE user_id IN ($1,$2) AND origin_type='gift_received' AND is_refundable",[a,b])),0);
  await invariant(owner,[a,b]);
 });
 await run('duplicate gift keys reject competing transfer terms instead of returning an unrelated receipt',async()=>{
  const sender=await user(owner),recipient=await user(owner,0),ref='gift_'+crypto.randomUUID();await actor(one,sender);await actor(two,sender);
  const gifts=await Promise.allSettled([scalar(one,'SELECT public.transfer_wallet_credit($1,2,$2)',[recipient+'@keepsims.test',ref]),
   scalar(two,'SELECT public.transfer_wallet_credit($1,3,$2)',[recipient+'@keepsims.test',ref])]);
  assert.equal(gifts.filter(r=>r.status==='fulfilled').length,1);
  assert.match(gifts.find(r=>r.status==='rejected').reason.message,/Gift reference mismatch/);await invariant(owner,[sender,recipient]);
 });
 await run('concurrent support retries adopt one signed adjustment and reject altered terms',async()=>{
  const id=await user(owner),admin=await user(owner,0),ref='correction_'+crypto.randomUUID();
  await actor(one,admin,true);await actor(two,admin,true);
  const results=await Promise.all([one,two].map(db=>scalar(db,"SELECT public.admin_adjust_wallet_once($1,2,'Fixture support credit',$2)",[id,ref])));
  assert.equal(results[0].transaction_id,results[1].transaction_id);
  await assert.rejects(scalar(two,"SELECT public.admin_adjust_wallet_once($1,-2,'Fixture support credit',$2)",[id,ref]),/Adjustment reference mismatch/);
  assert.equal(Number(await scalar(owner,'SELECT balance FROM public.wallets WHERE user_id=$1',[id])),12);await invariant(owner,[id]);
 });
 await run('signed admin corrections compete with reservations without spending held or promotional funds twice',async()=>{
  const id=await user(owner,3,5),admin=await user(owner,0);await actor(one,admin,true);
  const outcomes=await Promise.allSettled([scalar(one,"SELECT public.admin_adjust_wallet($1,-6,'Fixture correction')",[id]),
   scalar(two,"SELECT public.reserve_wallet_funds($1,3,'refill_instant',$2)",[id,crypto.randomUUID()])]);
  assert.equal(outcomes.filter(r=>r.status==='fulfilled').length,1);await invariant(owner,[id]);
 });
}
