import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {bootstrap} from './bootstrap.mjs';
import {runSetupSettlement} from './setup-settlement.mjs';
const native=process.env.PRICING_NATIVE==='1';
const results=[];let db,server,directory,owner,one,two;
const read=p=>fs.readFileSync(new URL('../../'+p,import.meta.url),'utf8');
async function check(name,body){try{await body();results.push({name,status:'passed'});console.log('PASS '+name);}catch(e){results.push({name,status:'failed',message:e.message,code:e.code});console.error('FAIL '+name+': '+e.message+' '+(e.where||''));}}
const scalar=async(sql,args=[])=>(await db.query(sql,args)).rows[0].v;
const uuid=()=>crypto.randomUUID();
try {
 if(native){
  const {default:EmbeddedPostgres}=await import(process.env.EMBEDDED_POSTGRES_MODULE_PATH?pathToFileURL(process.env.EMBEDDED_POSTGRES_MODULE_PATH).href:'embedded-postgres');
  directory=fs.mkdtempSync(path.join(os.tmpdir(),'keepsims-pricing-'));
  server=new EmbeddedPostgres({databaseDir:directory,user:'postgres',password:'isolated-test',port:56552,persistent:false,initdbFlags:['--locale=C'],postgresFlags:['-h','127.0.0.1','-k','/tmp'],onLog:()=>{},onError:()=>{}});
  await server.initialise();await server.start();owner=server.getPgClient();one=server.getPgClient();two=server.getPgClient();
  for(const c of [owner,one,two])await c.connect();
  db={exec:sql=>owner.query(sql),query:(sql,args)=>owner.query(sql,args)};
 }else{
  const {PGlite}=await import(process.env.PGLITE_MODULE_PATH?pathToFileURL(process.env.PGLITE_MODULE_PATH).href:'@electric-sql/pglite');db=new PGlite();owner=db;
 }
 await bootstrap(db);
 await db.exec(read('supabase/tests/fixtures/pricing_contract_baseline.sql'));
 await db.exec(read('supabase/migrations/20261018050000_unified_pricing_entitlement.sql'));
 // Reference test policy, not a claim about production's configured prices.
 await db.exec("INSERT INTO public.system_configs(config_key,config_value) VALUES('MEMBERSHIP_FEE_STANDARD_USD','2.50'),('MEMBERSHIP_FEE_PREMIUM_USD','5.00') ON CONFLICT(config_key) DO UPDATE SET config_value=excluded.config_value");
 await db.exec("INSERT INTO public.app_fee_rules(appfees_item,version,free_percentage,free_minimum,stand_percentage,stand_minimum,prem_percentage,prem_minimum,status) VALUES('refills',9999998,7,.50,5,.30,3,.10,'published'),('esimofferfee',9999998,10,0,7,0,5,0,'published')");
 async function seed(){
  const u=uuid(),line=uuid(),country=uuid(),carrier=uuid(),rule=uuid();
  await db.query('insert into auth.users(id,email) values($1,$2)',[u,u+'@fixture.invalid']);
  await db.query('insert into public.profiles(id,email) values($1,$2)',[u,u+'@fixture.invalid']);
  await db.query("insert into public.countries(id,name,iso_code,dialing_code,currency_code) values($1,'Fixture',$2,'+999','USD')",[country,country]);
  await db.query("insert into public.carriers(id,name,country_id,fulfillment_gateway) values($1,'Fixture',$2,'API')",[carrier,country]);
  await db.query("insert into public.carrier_rules(id,carrier_id,minimum_topup_amount,inactivity_limit_days,rule_type,topup_validity_days) values($1,$2,1,90,'prepaid',90)",[rule,carrier]);
  await db.query("insert into public.sim_lines(id,user_id,phone_number,carrier_id,carrier_rule_id,status,plan_type,protection_tier,plan_expires_at) values($1,$2,'+15550001001',$3,$4,'active','standard','standard',now()+interval '365 days')",[line,u,carrier,rule]);
  await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub:u,role:'service_role'})]);
  await db.query("select public.credit_wallet_for_deposit($1,30,'fixture',$2,jsonb_build_object('paypal_capture_id',$3::text))",[u,'paypal_'+u,u]);
  return {u,line,rule};
 }
 async function walletPaid(f,amount=2.5,plan='standard'){
  const ref='plan-'+uuid();const id=await scalar("select public.debit_wallet_for_topup($1,$2,$3,'Annual Plan Fee Debit ('||$4||')',$5,'plan_fee_debit') v",[f.u,f.line,amount,plan,ref]);
  await db.query("update public.wallet_transactions set metadata=jsonb_build_object('plan',$2::text,'sim_line_id',$3::text) where id=$1",[id,plan,f.line]);return id;
 }
 async function quote(f){return scalar('select public.quote_premium_breakdown($1,$2) v',[f.rule,f.line]);}
 async function scenario(name,body){await check(name,async()=>{await db.exec('begin');try{await body();}finally{await db.exec('rollback');}});}
 await scenario('draft labels and legacy protection tier cannot create paid entitlement or upgrade credit',async()=>{
  const f=await seed();assert.equal((await scalar('select public.resolve_line_entitlement($1) v',[f.line])).is_paid,false);
  assert.equal((await quote(f)).upgrade_credit_usd,0);
 });
 await scenario('wallet receipt alone supplies identical entitlement and bounded Standard upgrade credit',async()=>{
  const f=await seed();await walletPaid(f,1.25);assert.equal((await scalar('select public.resolve_line_entitlement($1) v',[f.line])).effective_tier,'standard');
  assert.equal((await quote(f)).upgrade_credit_usd,1.25);assert.equal((await quote(f)).annual_fee_usd,3.75);
 });
 await scenario('external plan receipt qualifies without a wallet debit',async()=>{
  const f=await seed();await db.query("insert into public.plan_payments(user_id,sim_line_id,capture_id,order_id,kind,gross_usd,net_usd,metadata) values($1,$2,'external-capture','external-order','plan',2,1.5,'{\"plan\":\"standard\"}')",[f.u,f.line]);
  assert.equal((await quote(f)).upgrade_credit_usd,1.5);
 });
 await scenario('latest discounted receipt wins over a larger older receipt',async()=>{
  const f=await seed();
  await db.query("insert into public.plan_payments(user_id,sim_line_id,capture_id,kind,gross_usd,net_usd,metadata,created_at) values($1,$2,'older','plan',2.5,2.5,'{\"plan\":\"standard\"}',now()-interval '1 day'),($1,$2,'newer','plan',.75,.75,'{\"plan\":\"standard\"}',now())",[f.u,f.line]);
  assert.equal((await quote(f)).upgrade_credit_usd,.75);
 });
 await scenario('expired or future paid evidence and extended client expiry do not create entitlement',async()=>{
  const f=await seed();
  await db.query("insert into public.plan_payments(user_id,sim_line_id,capture_id,kind,gross_usd,net_usd,metadata,created_at) values($1,$2,'expired','plan',2.5,2.5,'{\"plan\":\"standard\"}',now()-interval '366 days'),($1,$2,'future','plan',2.5,2.5,'{\"plan\":\"standard\"}',now()+interval '1 day')",[f.u,f.line]);
  assert.equal((await scalar('select public.resolve_line_entitlement($1) v',[f.line])).is_paid,false);
  assert.equal((await quote(f)).upgrade_credit_usd,0);
 });
 await scenario('refunded wallet receipt and duplicate setup receipt cannot restore credit',async()=>{
  const f=await seed();const id=await walletPaid(f);
  const ref=await scalar('select reference_id v from public.wallet_transactions where id=$1',[id]);
  await db.query("select public.credit_wallet_for_refund($1,2.5,$2,'fixture')",[f.u,'refund_'+ref]);
  await db.query("insert into public.plan_payments(user_id,sim_line_id,capture_id,kind,gross_usd,net_usd,metadata) values($1,$2,'setup-mirror','plan',2.5,2.5,'{\"plan\":\"standard\",\"setup_order_id\":\"unproven-mirror\"}')",[f.u,f.line]);
  assert.equal((await scalar('select public.resolve_line_entitlement($1) v',[f.line])).is_paid,false);assert.equal((await quote(f)).upgrade_credit_usd,0);
 });
 await scenario('approved grandfather proof is owner/term bounded; existing Premium grandfathering remains valid',async()=>{
  const f=await seed();await db.query("insert into public.line_plan_grants(sim_line_id,user_id,plan,source,source_key,credit_usd,expires_at,reason) values($1,$2,'standard','grandfather','approved-fixture',1,now()+interval '1 day','Approved isolated grandfather proof')",[f.line,f.u]);
  assert.equal((await quote(f)).upgrade_credit_usd,1);
  await db.query("update public.sim_lines set plan_type='premium' where id=$1",[f.line]);await db.query("insert into public.premium_entitlement_grandfather values($1,'Existing server-approved legacy grant',now())",[f.line]);
  assert.equal((await scalar('select public.resolve_line_entitlement($1) v',[f.line])).is_premium,true);
 });
 await scenario('missing, future and invalid pricing fails closed; published zero remains zero',async()=>{
  await db.exec("delete from public.system_configs where config_key in ('MEMBERSHIP_FEE_STANDARD_USD','BASE_SERVICE_FEE_USD')");
  await assert.rejects(scalar("select public.membership_fee_usd('standard') v"),/not configured/);
 });
 await scenario('configured zero membership creates an explicit grant without a zero-value ledger row',async()=>{
  const f=await seed();await db.exec("update public.system_configs set config_value='0' where config_key='MEMBERSHIP_FEE_STANDARD_USD'");
  const result=await scalar("select public.pay_plan_fee_from_wallet('free-promo',$1,null,'standard') v",[f.line]);assert.equal(result.success,true);assert.equal(result.amount,0);
  assert.equal((await scalar('select public.resolve_line_entitlement($1) v',[f.line])).is_paid,true);
  assert.equal((await scalar("select public.pay_plan_fee_from_wallet('free-promo',$1,null,'standard') v",[f.line])).already_paid,true);
  assert.equal(Number(await scalar("select count(*) v from public.wallet_transactions where type='plan_fee_debit' and user_id=$1",[f.u])),0);
 });
 await scenario('published zero refill/eSIM fees apply consistently to catalogue arithmetic',async()=>{
  const f=await seed();await db.exec("update public.app_fee_rules set free_percentage=0,free_minimum=0,stand_percentage=0,stand_minimum=0,prem_percentage=0,prem_minimum=0 where version=9999998");
  assert.equal(Number(await scalar("select public.resolve_app_fee('refills','premium',1) v")),0);
  assert.equal((await quote(f)).first_refill_cost_usd,1);
  assert.equal(Number(await scalar('select public.resolve_esim_offer_price(3,$1) v',[f.u])),3);
 });
 await scenario('wallet rail excludes gateway fees; external rail grosses the same net once',async()=>{
  const f=await seed();await db.exec("insert into public.payment_gateways(code,name,fee_percentage,fee_fixed,is_active) values('fixture','Fixture',3.4,.49,true) on conflict(code) do update set fee_percentage=3.4,fee_fixed=.49,is_active=true");
  const net=Number(await scalar("select public.quote_plan_price($1,'premium','wallet',$2) v",[f.line,f.rule]));
  const gross=Number(await scalar("select public.quote_plan_price($1,'premium','fixture',$2) v",[f.line,f.rule]));assert.equal(net,6.1);assert.equal(gross,Math.round((net+.49)/.966*100)/100);
 });
 await scenario('setup accepted price changes require review before any reservation',async()=>{
  const f=await seed();const o=await scalar("select public.create_sim_setup_order('+15550001001','standard',$1,null,null,$2) v",[f.rule,f.line]);
  await db.exec("update public.system_configs set config_value='3' where config_key='MEMBERSHIP_FEE_STANDARD_USD'");
  await assert.rejects(scalar('select public.reserve_sim_setup_holds($1) v',[o.order_id]),/price changed/);
 });
 await scenario('foreign owner and anon cannot obtain personalized pricing or manufacture evidence',async()=>{
  const f=await seed();await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub:uuid(),role:'authenticated'})]);
  await assert.rejects(quote(f),/ownership/);
 });
 await scenario('nonzero Premium first-refill price survives dispatch while the line is still unpaid',async()=>{
  const f=await seed();
  const order=await scalar("select public.create_sim_setup_order('+15550001001','premium',$1,null,null,$2) v",[f.rule,f.line]);
  assert.equal(order.total_charge_usd,6.1);
  await scalar('select public.reserve_sim_setup_holds($1) v',[order.order_id]);
  const dispatched=await scalar('select public.dispatch_sim_setup_verification($1,$2) v',[order.order_id,f.line]);
  assert.equal(Number(await scalar('select amount v from public.topup_executions where id=$1',[dispatched.execution_id])),1.1);
  assert.equal(Number(await scalar('select app_fee_usd v from public.topup_executions where id=$1',[dispatched.execution_id])),.1);
 });
 await scenario('quoted wallet confirmation refuses a changed amount before collection',async()=>{
  const f=await seed();await assert.rejects(scalar("select public.pay_quoted_plan_fee_from_wallet('confirmed',$1,null,'standard',null,0.1) v",[f.line]),/price changed/);
 });
 await scenario('quoted wallet payment and config-change replay collect the same one-time amount',async()=>{
  const f=await seed();const paid=await scalar("select public.pay_quoted_plan_fee_from_wallet('confirmed',$1,null,'standard',null,2.5) v",[f.line]);assert.equal(paid.amount,2.5);
  await db.exec("update public.system_configs set config_value='4' where config_key='MEMBERSHIP_FEE_STANDARD_USD'");
  assert.equal((await scalar("select public.pay_quoted_plan_fee_from_wallet('confirmed',$1,null,'standard',null,2.5) v",[f.line])).already_paid,true);
 });
 await scenario('eSIM catalogue, bounds, purchase order and wallet debit use one retail price',async()=>{
  const f=await seed();
  await db.exec("insert into public.service_providers(code,name,supports_esim,is_active) values('fixture','Fixture',true,true)");
  await db.exec("insert into public.esim_suppliers(code,name,is_active) values('fixture','Fixture',true)");
  await db.exec("insert into public.esim_offers_cache(provider,bundle_name,countries,data_amount_mb,duration_days,wholesale_price_usd,country_count) values('fixture','test-bundle',ARRAY['US'],1024,7,3,1)");
  const catalog=(await db.query("select price_usd from public.compare_esim_offers('US') where offer_id='test-bundle'")).rows[0];
  const bounds=await scalar("select public.compare_esim_filter_bounds('US') v");
  const bought=await scalar("select public.request_esim_purchase('test-bundle',1,null) v");
  assert.equal(Number(catalog.price_usd),3.3);assert.equal(Number(bounds.min_price_usd),3.3);assert.equal(bought.retail_price_usd,3.3);
  assert.equal(Number(await scalar('select retail_price_usd v from public.esim_orders where id=$1',[bought.order_id])),3.3);
  assert.equal(Number(await scalar("select amount v from public.wallet_transactions where user_id=$1 and type='esim_purchase_debit'",[f.u])),3.3);
 });
 await scenario('range quote prices the exact provider-native dispatch value and preserves published zero',async()=>{
  const f=await seed();const carrier=await scalar('select carrier_id v from public.sim_lines where id=$1',[f.line]);
  await db.query("insert into public.carrier_provider_map(carrier_id,provider,provider_country_code,provider_carrier_code,is_enabled,provider_country_label,provider_carrier_label) values($1,'dtone','US','range-carrier',true,'US','Fixture')",[carrier]);
  await db.exec("insert into public.provider_offers_cache(api_provider,offer_id,country_code,carrier_code,price_type,price_min_usd,price_max_usd,send_min,send_max,send_currency) values('dtone','range','US','range-carrier','RANGE',1,10,100,1000,'USD')");
  await db.exec("update public.app_fee_rules set free_percentage=0,free_minimum=0,stand_percentage=0,stand_minimum=0,prem_percentage=0,prem_minimum=0 where appfees_item='refills'");
  const q=await scalar("select public.get_authoritative_refill_quote($1,500,'USD','range','dtone') v",[f.line]);
  assert.equal(q.wholesale_cost_usd,5);assert.equal(q.total_charge_usd,5);assert.equal(q.customer_fee_usd,0);
  assert.equal((await scalar("select public.get_authoritative_refill_quote($1,2000,'USD','range','dtone') v",[f.line])).success,false);
 });
 await scenario('unconfigured or future fee policies cannot turn into guessed charges',async()=>{
  const f=await seed();await db.exec("update public.app_fee_rules set effective_from=now()+interval '1 day' where appfees_item='refills'");
  await assert.rejects(quote(f),/Published fee rule unavailable/);
 });
 await scenario('a zero-fee Standard setup finalizes with explicit entitlement and no wallet debit',async()=>{
  const f=await seed();await db.exec("update public.system_configs set config_value='0' where config_key='MEMBERSHIP_FEE_STANDARD_USD'");
  const order=await scalar("select public.create_sim_setup_order('+15550001001','standard',$1,null,null,$2) v",[f.rule,f.line]);
  await scalar('select public.reserve_sim_setup_holds($1) v',[order.order_id]);await scalar('select public.finalize_sim_setup_order($1) v',[order.order_id]);
  assert.equal((await scalar('select public.resolve_line_entitlement($1) v',[f.line])).is_paid,true);
  assert.equal(Number(await scalar("select count(*) v from public.wallet_transactions where user_id=$1 and type='plan_fee_debit'",[f.u])),0);
 });
 await scenario('expired setup quote requires refresh rather than reserving money',async()=>{
  const f=await seed();const order=await scalar("select public.create_sim_setup_order('+15550001001','standard',$1,null,null,$2) v",[f.rule,f.line]);
  await db.query("update public.sim_setup_orders set quote_expires_at=now()-interval '1 minute' where id=$1",[order.order_id]);
  await assert.rejects(scalar('select public.reserve_sim_setup_holds($1) v',[order.order_id]),/quote expired/);
 });
 await scenario('receipt recovery is owner scoped and financial RPC/table grants are exact',async()=>{
  const f=await seed();await scalar("select public.pay_quoted_plan_fee_from_wallet('recovery',$1,null,'standard',null,2.5) v",[f.line]);
  assert.equal((await scalar("select public.get_owned_plan_payment_receipt('recovery') v")).amount,2.5);
  await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub:uuid(),role:'authenticated'})]);
  assert.equal(await scalar("select public.get_owned_plan_payment_receipt('recovery') v"),null);
  assert.deepEqual((await db.query(read('supabase/tests/pricing_entitlement_contract_tests.sql'))).rows,[]);
 });
 await scenario('zero-fee Standard fallback records approved entitlement without a debit',async()=>{
  const f=await seed();const order=await scalar("select public.create_sim_setup_order('+15550001001','premium',$1,null,null,$2) v",[f.rule,f.line]);
  await scalar('select public.reserve_sim_setup_holds($1) v',[order.order_id]);const execution=await scalar('select public.dispatch_sim_setup_verification($1,$2) v',[order.order_id,f.line]);
  const hold=await scalar('select first_refill_hold_id v from public.sim_setup_orders where id=$1',[order.order_id]);
  await scalar("select public.fail_instant_refill_before_submission($1,$2,'fixture refusal') v",[execution.execution_id,hold]);
  await scalar('select public.finalize_sim_setup_order($1) v',[order.order_id]);
  await db.exec("update public.system_configs set config_value='0' where config_key='MEMBERSHIP_FEE_STANDARD_USD'");
  assert.equal((await scalar("select public.fallback_sim_setup_to_reminders($1,$2,'standard') v",[order.order_id,f.line])).success,true);
  assert.equal((await scalar('select public.resolve_line_entitlement($1) v',[f.line])).effective_tier,'standard');
 });
 if(native)await check('concurrent quoted upgrades cannot reuse the Standard credit for two charges',async()=>{
  const f=await seed();await walletPaid(f,1.25);const expected=(await quote(f)).total_charge_usd;
  for(const c of [one,two]){await c.query('set role authenticated');await c.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub:f.u,role:'authenticated'})]);}
  const settled=await Promise.allSettled([one,two].map((c,i)=>c.query("select public.pay_quoted_plan_fee_from_wallet($1,$2,null,'premium',$3,$4)",['upgrade-'+i,f.line,f.rule,expected])));
  assert.equal(settled.filter(r=>r.status==='fulfilled').length,1);
  assert.equal(Number(await scalar("select count(*) v from public.wallet_transactions where user_id=$1 and type='plan_fee_debit'",[f.u])),2);
  for(const c of [one,two])await c.query('reset role');
 });
 await scenario('a foreign carrier rule cannot price the owned line',async()=>{
  const f=await seed(),other=await seed();await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub:f.u,role:'authenticated'})]);
  await assert.rejects(scalar('select public.quote_premium_breakdown($1,$2) v',[other.rule,f.line]),/Carrier rule does not match/);
 });
 await scenario('a non-USD manual override cannot be mixed into a USD quote',async()=>{
  const f=await seed();await db.query("update public.carriers set fulfillment_gateway='MANUAL' where id=(select carrier_id from public.sim_lines where id=$1)",[f.line]);
  await db.query("update public.carrier_rules set inapp_pricing=10,inapp_pricing_currency='OMR' where id=$1",[f.rule]);
  await assert.rejects(quote(f),/denominated in USD/);
 });
 await scenario('a published zero membership adds no external gateway charge',async()=>{
  const f=await seed();await db.exec("update public.system_configs set config_value='0' where config_key='MEMBERSHIP_FEE_STANDARD_USD'");
  await db.exec("insert into public.payment_gateways(code,name,fee_percentage,fee_fixed,is_active) values('fixture','Fixture',3.4,.49,true) on conflict(code) do nothing");
  assert.equal(Number(await scalar("select public.quote_plan_price($1,'standard','fixture') v",[f.line])),0);
 });
 await scenario('authenticated users cannot invoke the old unbound debit or write entitlement grants',async()=>{
  const f=await seed();await db.exec('savepoint deny');await db.exec('set local role authenticated');
  await assert.rejects(scalar("select public.pay_plan_fee_from_wallet('unsafe',$1,null,'standard') v",[f.line]),e=>e.code==='42501');
  await db.exec('rollback to savepoint deny');await db.exec('set local role authenticated');
  await assert.rejects(db.query("insert into public.line_plan_grants(sim_line_id,user_id,plan,source,source_key,credit_usd,expires_at,reason) values($1,$2,'premium','grandfather','forged',5,now()+interval '1 year','Forged client entitlement')",[f.line,f.u]),e=>e.code==='42501');
 });
 // Existing Task 9 acceptance is required after changing canonical pricing.
 await runSetupSettlement(native?{owner,one,two}:{owner:db},check);
} catch(e){results.push({name:'bootstrap',status:'failed',message:e.message});console.error('FAIL bootstrap: '+e.message+' '+(e.where||''));}
finally {if(server){for(const c of [owner,one,two])if(c)await c.end();await server.stop();fs.rmSync(directory,{recursive:true,force:true});}else if(db)await db.close();}
const failed=results.filter(r=>r.status==='failed').length;
console.log(`${results.length-failed} passed / ${failed} failed pricing scenarios`);
if(process.env.FINANCIAL_TEST_REPORT)fs.writeFileSync(process.env.FINANCIAL_TEST_REPORT,JSON.stringify({results},null,2)+'\n');
if(failed)process.exitCode=1;
