import assert from 'node:assert/strict';
import fs from 'node:fs';
import {PGlite} from '@electric-sql/pglite';
const root=new URL('../../',import.meta.url),read=p=>fs.readFileSync(new URL(p,root),'utf8');
const db=new PGlite();
const q=async(s,p=[]) => (await db.query(s,p)).rows,one=async(s,p=[]) => (await q(s,p))[0]?.v;
const owner='10000000-0000-4000-8000-000000000001',other='10000000-0000-4000-8000-000000000002';
let profile,order,passed=0;
const test=async(name,fn)=>{await db.exec('BEGIN');try{await fn();passed++;console.log('PASS '+name);}finally{await db.exec('ROLLBACK');}};
const asOwner=async(u=owner)=>db.exec(`SET ROLE authenticated; SELECT set_config('request.jwt.claim.role','authenticated',false); SELECT set_config('request.jwt.claim.sub','${u}',false)`);
const asService=async()=>db.exec("RESET ROLE;SELECT set_config('request.jwt.claim.role','service_role',false); SELECT set_config('request.jwt.claim.sub','',false)");
const discover=()=>one('select public.request_esim_topups($1) v',[profile]);
const quote=(version,expected=1.73,id='TOPUP_A')=>one('select public.quote_esim_topup($1,$2,$3,$4) v',[profile,id,version,expected]);
const check=id=>one('select public.check_esim_topup_quote($1) v',[id]);
const offers=[{package_id:'TOPUP_A',title:'Fixture 1GB',discovery_type:'TOPUP',wholesale_usd:1.2345,currency:'USD',allowance_bytes:'1073741824',data_type:1,duration_value:7,duration_unit:'DAY',effect:'allowance_and_validity',quote_supported:true},
 {package_id:'DAILY',title:'Fixture daily',discovery_type:'TOPUP',wholesale_usd:2,currency:'USD',allowance_bytes:'1073741824',data_type:2,duration_value:1,duration_unit:'DAY',effect:'validity_only',quote_supported:false}];
const cache=async(items=offers)=>{
 await asOwner();assert.equal((await discover()).status,'PENDING');await asService();
 const job=await one('select public.service_esim_claim_topups() v');assert.equal(job.profile_id,profile);
 assert.equal((await one('select public.service_esim_save_topups($1,$2,$3) v',[profile,job.lease,JSON.stringify(items)])).saved,true);
 await asOwner();return discover();
};
const deny=async(s,p=[])=>{
 await db.exec('SAVEPOINT denied');try{await assert.rejects(()=>q(s,p),/permission denied|Service role required|Authentication required/);}
 finally{await db.exec('ROLLBACK TO denied');}
};
try {
 await db.exec(`CREATE ROLE anon;CREATE ROLE authenticated;CREATE ROLE service_role BYPASSRLS;
 CREATE SCHEMA auth;GRANT USAGE ON SCHEMA auth,public TO anon,authenticated,service_role;
 CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
 CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS $$select current_setting('request.jwt.claim.role',true)$$;
 CREATE FUNCTION public.assert_admin() RETURNS void LANGUAGE sql AS $$select$$;
 CREATE FUNCTION public.admin_log(text,text,text,jsonb,jsonb,text) RETURNS void LANGUAGE sql AS $$select$$;
 CREATE FUNCTION public.resolve_account_commerce_benefit(uuid) RETURNS text LANGUAGE sql STABLE AS $$select coalesce(nullif(current_setting('fixture.tier',true),''),'free')$$;
 CREATE TABLE profiles(id uuid PRIMARY KEY);`);
 await db.exec(read('supabase/tests/fixtures/esim_recharge_tables.sql'));
 await db.exec(`ALTER TABLE esim_orders ADD PRIMARY KEY(id);ALTER TABLE esim_orders ADD COLUMN catalogue_snapshot jsonb;
 ALTER TABLE user_esims ADD PRIMARY KEY(id);ALTER TABLE user_esims ADD UNIQUE(iccid);
 ALTER TABLE system_configs ADD PRIMARY KEY(config_key);SELECT set_config('request.jwt.claim.role','service_role',false);`);
 const preflight=JSON.parse(read('docs/reviews/esimaccess-recharge-discovery-20261028/evidence/preflight.json'))[0].v;
 for(const f of preflight.functions)if(f.definition)await db.exec(f.definition);
 const deps=JSON.parse(read('docs/reviews/esimaccess-recharge-discovery-20261028/evidence/pricing-dependencies.json'));
 await db.exec(deps.find(f=>f.proname==='resolve_app_fee').definition);
 await db.exec(read('supabase/migrations/20261027235408_esim_profile_identity_lifecycle.sql'));
 await db.exec(read('supabase/migrations/20261027235409_esim_event_inbox_reconciliation.sql'));
 await db.exec(read('supabase/migrations/20261028070000_esim_recharge_discovery_quotes.sql'));
 passed++;console.log('PASS migration compiles over captured tables and actual deployed pricing/wallet functions');
 await db.exec(`insert into profiles values('${owner}'),('${other}');
 insert into esim_suppliers(code,name,is_active) values('esimaccess','Fixture',true);
 insert into app_fee_rules(appfees_item,version,status,free_percentage,free_minimum,stand_percentage,stand_minimum,prem_percentage,prem_minimum)
 values('esimofferfee',999,'published',10,0.5,7,0.3,5,0.1);
 insert into wallets(user_id,balance,currency) values('${owner}',20,'USD');
 insert into wallet_holds(wallet_id,user_id,amount,status,order_type,order_reference_id) select id,'${owner}',19,'active','esim_purchase','fixture' from wallets;
 update esim_private.accounts set new_sales_enabled=true;`);
 order=await one(`insert into esim_orders(user_id,provider,bundle_name,quantity,wholesale_price_usd,retail_price_usd,markup_percent,status)
 values($1,'esimaccess','FIXTURE',1,1,1.4,40,'completed') returning id v`,[owner]);
 profile=await one(`insert into user_esims(user_id,order_id,provider,bundle_name,iccid,smdp_address,matching_id,lpa_string,status,data_total_mb,data_remaining_mb,
 supplier_account_id,supplier_profile_ref,profile_state,installation_state,bundle_state,last_observation_at,confirmed_expires_at,plan_details)
 select $1,$2,'esimaccess','FIXTURE','8900000000000000001','fixture.invalid','private','LPA:1$fixture.invalid$private','active',1024,0,id,'FIXTURE_PROFILE','active','enabled','depleted',now(),now()+interval '5 days',
 '{"topup_support":"supported"}' from esim_private.accounts returning user_esims.id v`,[owner,order]);
 await db.exec("update esim_private.order_runs set state='completed';update esim_private.accounts set new_sales_enabled=false;");
 await test('read-only rollout starts disabled without enabling new sales',async()=>{
  await asOwner();assert.equal((await discover()).status,'DISCOVERY_DISABLED');
  await asService();assert.equal(await one('select new_sales_enabled v from esim_private.accounts'),false);
 });
 await db.exec('update esim_private.recharge_policy set discovery_enabled=true');
 await test('other user and anonymous callers cannot discover, quote or read private tables',async()=>{
  await asOwner(other);assert.equal((await discover()).status,'PROFILE_UNAVAILABLE');assert.equal((await quote(null)).status,'PROFILE_UNAVAILABLE');
  await deny('select * from esim_private.topup_cache');await deny('select public.service_esim_claim_topups()');
  await db.exec("RESET ROLE;SET ROLE anon;SELECT set_config('request.jwt.claim.sub','',false);SELECT set_config('request.jwt.claim.role','anon',false)");
  await deny('select public.request_esim_topups($1)',[profile]);await deny('select public.quote_esim_topup($1,$2,$3,$4)',[profile,'A',null,1]);
 });
 await test('depleted active profile discovers its own compatible TOPUP list and retail only',async()=>{
  const d=await cache();assert.equal(d.status,'READY');assert.equal(d.offers.length,2);assert.equal(d.offers[0].retail_total,1.73);
  const s=JSON.stringify(d);for(const secret of ['wholesale','FIXTURE_PROFILE','890000','account_id'])assert(!s.includes(secret));
  assert.equal((await discover()).offer_version,d.offer_version);assert.equal(d.acceptance_enabled,false);
 });
 await test('immutable profile/payer/package/action quote uses available rather than posted balance, with no second fee',async()=>{
  const d=await cache(),a=await quote(d.offer_version),b=await quote(d.offer_version);
  assert.equal(a.status,'QUOTED');assert.equal(a.owner_id,owner);assert.equal(a.payer_id,owner);assert.equal(a.profile_id,profile);
  assert.equal(a.offer.retail_total,1.73);assert.equal(a.balance_state,'insufficient');assert.equal(a.available_balance,1);
  assert.equal(a.acceptance_enabled,false);assert.equal(a.quote_id,b.quote_id);assert.equal(a.acceptance_key,b.acceptance_key);
  assert.equal(a.action,'fixed_bundle_recharge');assert.equal(a.offer.post_recharge_expires_at,null);
  assert(new Date(a.expires_at)<=new Date(d.expires_at));assert(new Date(a.expires_at)<=new Date(Date.now()+121000));
  await deny('update esim_private.recharge_quotes set retail_total=0');
  await asOwner(other);assert.equal((await check(a.quote_id)).status,'QUOTE_UNAVAILABLE');
 });
 await test('incompatible BASE/destination packages, daily pricing, changed client price and version are refused',async()=>{
  const d=await cache();assert.equal((await quote(d.offer_version,1.73,'BASE_ANYWHERE')).status,'INCOMPATIBLE_OFFER');
  assert.equal((await quote(d.offer_version,2,'DAILY')).status,'DURATION_QUOTE_UNAVAILABLE');
  assert.equal((await quote(d.offer_version,0.01)).status,'PRICE_CHANGED');assert.equal((await quote(other)).status,'STALE_OFFERS');
 });
 await test('price policy/tier changes invalidate quotes without rewriting them',async()=>{
  const d=await cache(),a=await quote(d.offer_version);await asService();
  await db.exec('update app_fee_rules set free_minimum=1');await asOwner();
  assert.equal((await quote(d.offer_version)).status,'PRICE_CHANGED');assert.equal((await check(a.quote_id)).status,'STALE_QUOTE');
  await asService();await db.exec("select set_config('fixture.tier','premium',false)");await asOwner();
  assert.equal((await quote(d.offer_version,1.33)).status,'QUOTED');
 });
 await test('profile, catalogue and supplier changes invalidate outstanding offers and quotes',async()=>{
  const d=await cache(),a=await quote(d.offer_version);await asService();
  await q("update user_esims set last_observation_at=now()+interval '1 second' where id=$1",[profile]);await asOwner();
  assert.equal((await check(a.quote_id)).status,'STALE_QUOTE');assert.equal((await quote(d.offer_version)).status,'STALE_OFFERS');
  await asService();await db.exec('update public.esim_offers_cache set is_active=is_active where false');await asOwner();
  assert.equal((await check(a.quote_id)).status,'STALE_QUOTE');
  await asService();await db.exec('update esim_suppliers set is_active=false');await asOwner();
  assert.equal((await discover()).status,'SUPPLIER_DISABLED');assert.equal((await quote(d.offer_version)).status,'SUPPLIER_DISABLED');
 });
 await test('expired, stale, failed, unknown and unresolved profiles explain refusal before queueing',async()=>{
  for(const [change,expected] of [["profile_state='expired'",'PROFILE_EXPIRED'],["confirmed_expires_at=now()-interval '1 second'",'PROFILE_EXPIRED'],
   ["last_observation_at=now()-interval '20 minutes'",'PROFILE_REFRESH_REQUIRED'],["usage_error_code='FAIL'",'PROFILE_REFRESH_REQUIRED'],
   ["confirmed_expires_at=null",'PROFILE_REFRESH_REQUIRED'],["plan_details='{}'",'CAPABILITY_UNVERIFIED'],["installation_state='deleted'",'PROFILE_UNAVAILABLE']]){
   await asService();await db.exec('SAVEPOINT profile_change');await q('update user_esims set '+change+' where id=$1',[profile]);await asOwner();
   assert.equal((await discover()).status,expected);await asService();await db.exec('ROLLBACK TO profile_change');
  }
  await q("update esim_private.order_runs set state='support_required' where order_id=$1",[order]);await asOwner();
  assert.equal((await discover()).status,'UNRESOLVED_OPERATION');
 });
 await test('cache and quote expiries require new discovery/quote; expired lease and null lease cannot save',async()=>{
  const d=await cache(),a=await quote(d.offer_version);await asService();
  await q("update esim_private.recharge_quotes set expires_at=now()-interval '1 second' where id=$1",[a.quote_id]);await asOwner();
  assert.equal((await check(a.quote_id)).status,'STALE_QUOTE');await asService();
  await db.exec("update esim_private.topup_cache set expires_at=now()-interval '1 second'");await asOwner();
  assert.equal((await quote(d.offer_version)).status,'STALE_OFFERS');assert.equal((await discover()).status,'PENDING');await asService();
  const job=await one('select public.service_esim_claim_topups() v');
  assert.equal((await one('select public.service_esim_save_topups($1,null,$2) v',[profile,JSON.stringify(offers)])).saved,false);
  await db.exec("update esim_private.topup_cache set lease_until=now()-interval '1 second'");
  assert.equal((await one('select public.service_esim_save_topups($1,$2,$3) v',[profile,job.lease,JSON.stringify(offers)])).saved,false);
 });
 await test('owner changes during provider request fence the saved list',async()=>{
  await asOwner();await discover();await asService();const job=await one('select public.service_esim_claim_topups() v');
  await q('update user_esims set user_id=$1 where id=$2',[other,profile]);
  assert.equal((await one('select public.service_esim_save_topups($1,$2,$3) v',[profile,job.lease,JSON.stringify(offers)])).saved,false);
  assert.equal(await one('select offers v from esim_private.topup_cache'),null);
 });
 await test('empty compatibility stays distinct from failed discovery',async()=>{
  assert.equal((await cache([])).status,'NO_COMPATIBLE_OFFERS');
 });
 await test('unknown wallet read stays unknown while quotes remain non-spending',async()=>{
  const d=await cache();await asService();await db.exec("CREATE OR REPLACE FUNCTION public.get_wallet_summary(p_user_id uuid) RETURNS jsonb LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'fixture outage';END$$");
  await asOwner();const a=await quote(d.offer_version);assert.equal(a.status,'QUOTED');assert.equal(a.balance_state,'unknown');assert.equal(a.available_balance,null);
 });
 await test('browsing/quotes never mutate wallet, holds, ledger, orders or provider submission state',async()=>{
  const before=await one("select jsonb_build_object('wallets',(select jsonb_agg(to_jsonb(w)) from wallets w),'holds',(select jsonb_agg(to_jsonb(h)) from wallet_holds h),'orders',(select jsonb_agg(to_jsonb(o)) from esim_orders o),'runs',(select jsonb_agg(to_jsonb(r)) from esim_private.order_runs r)) v");
  const d=await cache();await quote(d.offer_version);await discover();await asService();
  assert.deepEqual(await one("select jsonb_build_object('wallets',(select jsonb_agg(to_jsonb(w)) from wallets w),'holds',(select jsonb_agg(to_jsonb(h)) from wallet_holds h),'orders',(select jsonb_agg(to_jsonb(o)) from esim_orders o),'runs',(select jsonb_agg(to_jsonb(r)) from esim_private.order_runs r)) v"),before);
 });
 console.log(`${passed} ESIM-07 SQL scenario groups passed`);
}finally{await db.close();}
