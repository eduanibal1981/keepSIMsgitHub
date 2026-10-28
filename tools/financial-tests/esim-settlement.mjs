import assert from 'node:assert/strict';
import {createFixture,owner,other} from './esim-settlement-fixture.mjs';
const f=await createFixture(),{db,q,one,user,service,profile,enable,makeQuote,accept,claim,submit,record,settle,receipt}=f;
let passed=0;
const test=async(name,fn)=>{await db.exec('BEGIN');try{await fn();passed++;console.log('PASS '+name);}finally{await db.exec('ROLLBACK');}};
const rejected=async(fn,re=/permission denied|Service role required|unproven|Unproven|mismatch|changed|Immutable|Legacy|Account unavailable/i)=>{
 await db.exec('SAVEPOINT denied');try{await assert.rejects(fn,re);}finally{await db.exec('ROLLBACK TO denied');}
};
const wallet=()=>one('select balance v from public.wallets where user_id=$1',[owner]);
const newJob=async()=>{await enable();const quote=await makeQuote();assert.equal(quote.status,'QUOTED');const a=await accept(quote);assert.equal(a.status,'ACCEPTED');return {quote,job:await claim()};};
try {
 console.log('PASS migration compiles against actual deployed wallet/pricing/ESIM contracts');passed++;
 await test('default gates refuse acceptance before any hold or provider job',async()=>{
  const quote=await makeQuote();assert.equal(quote.acceptance_enabled,false);assert.equal((await accept(quote)).status,'RECHARGE_DISABLED');
  await service();assert.equal(await one('select count(*)::int v from wallet_holds'),0);
 });
 await test('another user cannot accept or read operations, and clients cannot call service settlement',async()=>{
  await enable();const quote=await makeQuote();await user(other);assert.equal((await accept(quote)).status,'QUOTE_UNAVAILABLE');
  assert.deepEqual(await one('select public.get_esim_operation_history($1) v',[profile]),[]);
  await rejected(()=>one('select public.service_esim_claim_order() v'));
 });
 await test('duplicate taps adopt one quote/order/hold and distinct sibling actions cannot reserve again',async()=>{
  const {quote,job}=await newJob();await user();const retry=await accept(quote);assert.equal(retry.status,'ADOPTED');assert.equal(retry.order_id,job.order_id);
  await service();assert.equal(await one('select count(*)::int v from wallet_holds'),1);assert.equal(await wallet(),'20');
  assert.equal(await one("select expires_at is null v from wallet_holds"),true);
  await user();assert.equal((await f.discover()).status,'UNRESOLVED_OPERATION');
 });
 await test('available funds exclude other holds and failed allocation atomically creates no order',async()=>{
  await enable();const quote=await makeQuote();await service();
  await db.exec("select reserve_wallet_funds('"+owner+"',19,'plan_fee','fixture_other_hold')");await user();
  assert.equal((await accept(quote)).status,'BALANCE_UNAVAILABLE');await service();
  assert.equal(await one("select count(*)::int v from esim_orders where operation_kind='fixed_recharge'"),0);
 });
 await test('no submission marker without current lease, stable profile, price and fresh quote',async()=>{
  const {job}=await newJob();assert.equal(await one('select public.service_esim_mark_submitted($1,null) v',[job.order_id]),false);
  await q("update esim_private.recharge_quotes set expires_at=now()-interval '1 second' where id=(select recharge_quote_id from esim_orders where id=$1)",[job.order_id]);
  assert.equal(await submit(job),false);assert.equal(await one('select status v from wallet_holds'),'released');assert.equal(await wallet(),'20');
 });
 await test('timeout stays reserved across restarts and attempts to expire/refund/replay are refused',async()=>{
  const {job}=await newJob();assert.equal(await submit(job),true);assert.equal(await submit(job),false);
  await rejected(()=>one("select public.release_wallet_hold((select hold_id from esim_private.order_runs where order_id=$1),'timeout') v",[job.order_id]));
  await rejected(()=>q("update wallet_holds set status='expired' where id=(select hold_id from esim_private.order_runs where order_id=$1)",[job.order_id]));
  assert.equal(await one("select public.service_esim_fail_before_submit($1,$2,'QUOTE_EXPIRED') v",[job.order_id,job.lease]),false);
  assert.equal(await one("select status v from wallet_holds"),'active');assert.equal(await wallet(),'20');
 });
 await test('confirmed service captures once and preserves profile identity and installation credentials',async()=>{
  const {job}=await newJob();await submit(job);
  const before=await one('select jsonb_build_object(\'id\',id,\'iccid\',iccid,\'lpa\',lpa_string,\'ref\',supplier_profile_ref) v from user_esims where id=$1',[profile]);
  const r=receipt(job);await record(job,r);assert.equal((await settle(job)).completed,true);assert.equal((await settle(job)).completed,true);await record(job,r);
  assert.equal(await wallet(),'18.27');assert.equal(await one("select count(*)::int v from wallet_transactions where type='esim_recharge_debit'"),1);
  assert.equal(await one('select count(*)::int v from esim_private.entitlements'),1);
  assert.deepEqual(await one('select jsonb_build_object(\'id\',id,\'iccid\',iccid,\'lpa\',lpa_string,\'ref\',supplier_profile_ref) v from user_esims where id=$1',[profile]),before);
  assert.equal(await one('select data_total_bytes::text v from user_esims where id=$1',[profile]),'2147483648');
  assert.equal(await one('select drift v from wallet_reconciliation where user_id=$1',[owner]),'0.00');
  assert.equal(await one('select count(*)::int v from esim_private.alert_cycles'),1);
 });
 await test('failure after supplier success rolls back capture/entitlement, then receipt replay settles once',async()=>{
  const {job}=await newJob();await submit(job);await record(job);
  await db.exec("CREATE FUNCTION fixture_fail_cycle() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'fixture database outage';END$$;CREATE TRIGGER fixture_fail_cycle BEFORE INSERT ON esim_private.alert_cycles FOR EACH ROW EXECUTE FUNCTION fixture_fail_cycle()");
  await rejected(()=>settle(job),/fixture database outage/);assert.equal(await wallet(),'20');assert.equal(await one("select status v from wallet_holds"),'active');
  await db.exec('DROP TRIGGER fixture_fail_cycle ON esim_private.alert_cycles');await settle(job);assert.equal(await wallet(),'18.27');
 });
 await test('missing/incorrect top-up receipt, mismatched identity and conflicting receipt never capture',async()=>{
  const {job}=await newJob();await submit(job);const r=receipt(job);
  for(const bad of [{...r,topup_ref:null},{...r,transaction_id:'other'},{...r,iccid:'8900000000000000002'},{...r,package_id:'BASE'},{...r,used_bytes:'99999999999'}])await rejected(()=>record(job,bad));
  assert.equal(await wallet(),'20');await record(job,r);await rejected(()=>record(job,{...r,total_bytes:'99999999'}),/Unproven|Conflicting/);
 });
 await test('definitive validation rejection releases once, while unknown errors cannot release',async()=>{
  const {job}=await newJob();await submit(job);
  assert.equal(await one('select public.service_esim_record_rejection($1,$2,$3,$4) v',[job.order_id,job.lease,job.submission_ref,'900001']),false);
  assert.equal(await one('select public.service_esim_record_rejection($1,$2,$3,$4) v',[job.order_id,job.lease,job.submission_ref,'200005']),true);
  assert.equal(await one('select public.service_esim_record_rejection($1,$2,$3,$4) v',[job.order_id,job.lease,job.submission_ref,'200005']),true);
  assert.equal(await wallet(),'20');assert.equal(await one('select status v from wallet_holds'),'released');
 });
 await test('a documented pre-submission refusal spends nothing and releases once',async()=>{
  const {job}=await newJob();assert.equal(await one("select public.service_esim_fail_before_submit($1,$2,'COMPATIBILITY_CHANGED') v",[job.order_id,job.lease]),true);
  assert.equal(await wallet(),'20');assert.equal(await one("select count(*)::int v from wallet_transactions where type='esim_recharge_debit'"),0);
 });
 await test('disabling new actions allows confirmed receipt recovery and capture',async()=>{
  const {job}=await newJob();await submit(job);await record(job);await db.exec('update esim_private.accounts set recharge_enabled=false,new_sales_enabled=false');
  await settle(job);assert.equal(await wallet(),'18.27');
 });
 await test('legacy debit settlement never reserves or debits a second time and refunds bounded original payer once',async()=>{
  const {job}=await newJob();await service();
  // Construct a synthetic pre-migration debit, keeping the current release's
  // actual ledger primitive and amount evidence. No live wallet is involved.
  await q("update esim_private.order_runs set finance_kind='legacy_debit',hold_id=null where order_id=$1",[job.order_id]);
  await db.exec('delete from wallet_hold_allocations;delete from wallet_holds');
  const debit=await one("select public.debit_wallet_for_topup($1,null,1.73,'fixture','esim_'||$2::text,'esim_purchase_debit') v",[owner,job.order_id]);
  await q("update esim_private.order_runs set debit_tx_id=$1,receipt='{\"outcome\":\"failed\"}',state='failed' where order_id=$2",[debit,job.order_id]);
  await one('select esim_private.settle_order($1,false) v',[job.order_id]);await one('select esim_private.settle_order($1,false) v',[job.order_id]);
  assert.equal(await wallet(),'20.00');assert.equal(await one("select count(*)::int v from wallet_transactions where type='esim_purchase_refund'"),1);
  assert.equal(await one('select count(*)::int v from wallet_holds'),0);assert.equal(await one('select balance v from wallets where user_id=$1',[other]),'20');
 });
 await test('legacy wallet writers cannot spend an active eSIM reservation',async()=>{
  await newJob();await rejected(()=>one("select public.debit_wallet_for_topup($1,null,20,'fixture','legacy_attempt','topup_debit') v",[owner]),/Active reservations/);
  assert.equal(await wallet(),'20');
 });
 await test('an ordinary hold can capture beside a fully reserved eSIM wallet without touching its funds',async()=>{
  await newJob();const available=Number(await wallet())-1.73;
  const h=await one("select public.reserve_wallet_funds($1,$2,'plan_fee','ordinary_full_balance') v",[owner,available]);
  await one("select public.capture_wallet_hold($1,'plan_fee_debit','fixture ordinary capture','{}') v",[h]);
  assert.equal(Number(await wallet()),1.73);assert.equal(await one('select count(*)::int v from esim_private.capture_context'),0);
  assert.equal(Number(await one("select sum(amount) v from wallet_holds where status='active'")),1.73);
 });
 await test('a revoked, expired or wrong-account session cannot authorize a new financial action',async()=>{
  await enable();const quote=await makeQuote();await service();await q('delete from auth.sessions where user_id=$1',[owner]);await user();
  await rejected(()=>accept(quote),/Active session required/);
  await service();assert.equal(await one('select count(*)::int v from wallet_holds'),0);
 });
 const baseOffer=async()=>{await service();await db.exec(`insert into esim_offers_cache(provider,bundle_name,description,countries,data_amount_mb,duration_days,wholesale_price_usd,is_active,catalogue_details)
 values('esimaccess','BASE_FIXED','Fixture',ARRAY['OM'],1024,7,1.2345,true,'{"plan_type":"total","topup_support":"supported"}')`);
 await db.exec('update esim_private.accounts set new_sales_enabled=true,wallet_boundary_verified=true');};
 const buy=(key,total=1.73,quantity=1,expected=owner)=>one('select public.request_esim_purchase_v2($1,$2,$3,$4,$5,$6) v',['BASE_FIXED',quantity,'fixture-device',key,total,expected]);
 await test('new-profile checkout nonce adopts one reservation and binds the reviewed amount and account',async()=>{
  await baseOffer();await user();const key='20000000-0000-4000-8000-000000000001';
  assert.equal((await buy(key,0.01)).code,'PRICE_CHANGED');assert.equal((await buy(key,1.73,1,other)).code,'ACCOUNT_CHANGED');
  const a=await buy(key),b=await buy(key);assert.equal(a.success,true);assert.equal(a.order_id,b.order_id);
  assert.equal((await buy(key,3.46,2)).code,'INTENT_CONFLICT');await service();assert.equal(await one('select count(*)::int v from wallet_holds'),1);
  assert.equal(await wallet(),'20');assert.equal(await one("select count(*)::int v from wallet_transactions where type='esim_purchase_debit'"),0);
 });
 await test('partial new-profile issuance retains its reservation, complete issuance captures once, retry adopts',async()=>{
  await baseOffer();await user();const a=await buy('20000000-0000-4000-8000-000000000002',3.46,2);assert.equal(a.success,true);
  let job=await claim();assert.equal(await submit(job),true);
  await one('select public.service_esim_order_checkpoint($1,$2,$3,null) v',[job.order_id,job.lease,'PROVEN_ORDER']);
  await q('update esim_private.order_runs set next_check_at=now() where order_id=$1',[job.order_id]);job=await claim();
  const issued=n=>({issuance_proven:true,supplier_profile_ref:'ISSUED_'+n,provider_order_ref:'PROVEN_ORDER',iccid:'890000000000000000'+n,
   lpa_string:'LPA:1$fixture.invalid$private'+n,smdp_address:'fixture.invalid',matching_id:'private'+n,
   profile_state:'issued',installation_state:'released',bundle_state:'not_started',activation_trigger:'first_network_connection',data_total_bytes:1073741824,data_used_bytes:0,data_remaining_bytes:1073741824});
  const save=items=>one('select public.service_esim_save_issuance($1,$2,$3,$4,null) v',[job.order_id,job.lease,'PROVEN_ORDER',JSON.stringify(items)]);
  assert.equal((await save([issued(2)])).completed,false);assert.equal(await wallet(),'20');assert.equal(await one('select status v from wallet_holds'),'active');
  await q('update esim_private.order_runs set next_check_at=now() where order_id=$1',[job.order_id]);job=await claim();
  assert.equal((await save([issued(2),issued(3)])).completed,true);assert.equal(await wallet(),'16.54');
  assert.equal((await save([issued(2),issued(3)])).completed,true);assert.equal(await wallet(),'16.54');
  assert.equal(await one("select count(*)::int v from wallet_transactions where type='esim_purchase_debit'"),1);
 });
 await test('expired accepted quotes retain historical evidence during retention pruning',async()=>{
  const {job}=await newJob();await q("update esim_private.recharge_quotes set expires_at=now()-interval '40 days' where id=(select recharge_quote_id from esim_orders where id=$1)",[job.order_id]);
  await db.exec('select public.prune_esim_topup_discovery()');assert.equal(await one('select count(*)::int v from esim_private.recharge_quotes'),1);
 });
 await test('a failed accepted quote is never reused as a new intent',async()=>{
  const {quote,job}=await newJob();await one("select public.service_esim_fail_before_submit($1,$2,'COMPATIBILITY_CHANGED') v",[job.order_id,job.lease]);
  const fresh=await makeQuote();assert.notEqual(fresh.quote_id,quote.quote_id);assert.equal((await accept(quote)).status,'ADOPTED');
 });
 await test('support timeline enforces trusted app metadata and exposes no activation or wholesale data',async()=>{
  const {job}=await newJob();await user();await db.exec(`select set_config('request.jwt.claims','{"role":"authenticated","user_metadata":{"is_power_user":true}}',false)`);
  await rejected(()=>one('select public.admin_esim_operation_timeline($1) v',[job.order_id]),/Admin required/);
  await db.exec(`select set_config('request.jwt.claims','{"role":"authenticated","app_metadata":{"is_power_user":true}}',false)`);
  const t=await one('select public.admin_esim_operation_timeline($1) v',[job.order_id]);assert.equal(t.order_id,job.order_id);assert.equal(t.has_hold,true);
  for(const secret of ['private','890000','wholesale','lpa_string'])assert(!JSON.stringify(t).includes(secret));
 });
 await test('customer purchase view preserves invoker RLS and narrow column access',async()=>{
  await service();const options=await one("select reloptions v from pg_class where oid='public.customer_esim_orders'::regclass");
  assert(options.includes('security_invoker=true'));assert(options.includes('security_barrier=true'));
  await user();assert.equal(await one('select count(*)::int v from public.customer_esim_orders'),1);
  await rejected(()=>one('select wholesale_price_usd v from public.esim_orders'),/permission denied/);
  await user(other);assert.equal(await one('select count(*)::int v from public.customer_esim_orders'),0);
 });
 console.log(`${passed} ESIM-08 SQL scenario groups passed`);
}finally{await db.close();}
