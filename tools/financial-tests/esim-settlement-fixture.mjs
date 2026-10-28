import fs from 'node:fs';
import assert from 'node:assert/strict';
import {PGlite} from '@electric-sql/pglite';
const root=new URL('../../',import.meta.url),read=p=>fs.readFileSync(new URL(p,root),'utf8');
export const owner='10000000-0000-4000-8000-000000000001',other='10000000-0000-4000-8000-000000000002';
export const topups=[{package_id:'TOPUP_A',title:'Fixture 1GB',discovery_type:'TOPUP',wholesale_usd:1.2345,currency:'USD',allowance_bytes:'1073741824',data_type:1,duration_value:7,duration_unit:'DAY',effect:'allowance_and_validity',quote_supported:true}];
export async function createFixture(database=null) {
 const db=database??new PGlite();
 const q=async(s,p=[]) => (await db.query(s,p)).rows,one=async(s,p=[]) => (await q(s,p))[0]?.v;
 const service=async()=>db.exec("RESET ROLE;SELECT set_config('request.jwt.claim.role','service_role',false);SELECT set_config('request.jwt.claim.sub','',false);SELECT set_config('request.jwt.claims','{\"role\":\"service_role\"}',false)");
 const user=async(u=owner)=>db.exec(`RESET ROLE;SET ROLE authenticated;SELECT set_config('request.jwt.claim.role','authenticated',false);SELECT set_config('request.jwt.claim.sub','${u}',false);SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"${u}","session_id":"${u}"}',false)`);
 await db.exec(`CREATE ROLE anon;CREATE ROLE authenticated;CREATE ROLE service_role BYPASSRLS;
 CREATE SCHEMA auth;GRANT USAGE ON SCHEMA auth,public TO anon,authenticated,service_role;
 CREATE TABLE auth.users(id uuid PRIMARY KEY,banned_until timestamptz,deleted_at timestamptz);
 CREATE TABLE auth.sessions(id uuid PRIMARY KEY,user_id uuid,not_after timestamptz);
 CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
 CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS $$select current_setting('request.jwt.claim.role',true)$$;
 CREATE FUNCTION public.assert_admin() RETURNS void LANGUAGE plpgsql AS $$BEGIN IF coalesce(current_setting('request.jwt.claims',true),'{}')::jsonb#>>'{app_metadata,is_power_user}' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Admin required' USING ERRCODE='42501';END IF;END$$;
 CREATE FUNCTION public.admin_log(text,text,text,jsonb,jsonb,text) RETURNS void LANGUAGE sql AS $$select$$;
 CREATE FUNCTION public.resolve_account_commerce_benefit(uuid) RETURNS text LANGUAGE sql STABLE AS $$select 'free'::text$$;
 CREATE FUNCTION public.enforce_rate_limit(text,text) RETURNS void LANGUAGE sql AS $$select$$;
 CREATE FUNCTION public.guard_money_action(text,numeric,text,uuid,uuid) RETURNS jsonb LANGUAGE sql AS $$select '{"blocked":false}'::jsonb$$;
 CREATE TABLE profiles(id uuid PRIMARY KEY,is_suspended boolean DEFAULT false);
 CREATE TABLE sim_lines(id uuid,user_id uuid);`);
 // ESIM-07 table snapshot includes older wallet shapes; replace only those with
 // fresh actual deployed shapes, then use the actual live wallet functions.
 let tables=read('supabase/tests/fixtures/esim_recharge_tables.sql');
 for(const name of ['wallets','wallet_holds','wallet_funding_lots']) {
  const a=tables.indexOf('CREATE TABLE public.'+name+' (');const b=tables.indexOf('\n);',a)+4;assert(a>=0);tables=tables.slice(0,a)+tables.slice(b);
 }
 await db.exec(tables);await db.exec(read('supabase/tests/fixtures/esim_settlement_wallet.sql'));
 await db.exec(read('supabase/tests/fixtures/esim_settlement_support.sql'));
 await db.exec(`ALTER TABLE esim_orders ADD PRIMARY KEY(id);ALTER TABLE esim_orders ADD COLUMN catalogue_snapshot jsonb;
 ALTER TABLE user_esims ADD PRIMARY KEY(id);ALTER TABLE user_esims ADD UNIQUE(iccid);ALTER TABLE system_configs ADD PRIMARY KEY(config_key);ALTER TABLE esim_offers_cache ADD COLUMN catalogue_details jsonb;
 ALTER TABLE notifications ADD PRIMARY KEY(id);ALTER TABLE alert_settings ADD UNIQUE(user_id,category);ALTER TABLE notification_dispatch_jobs ADD UNIQUE(notification_id);
 CREATE FUNCTION public.notification_channel_eligible(uuid,uuid,text,text) RETURNS boolean LANGUAGE sql AS $$select true$$;`);
 const e='docs/reviews/esimaccess-recharge-settlement-20261028/evidence/';
 const old=JSON.parse(read('docs/reviews/esimaccess-recharge-discovery-20261028/evidence/preflight.json'))[0].v;
 for(const f of old.functions)if(f.definition)await db.exec(f.definition);
 const deps=JSON.parse(read('docs/reviews/esimaccess-recharge-discovery-20261028/evidence/pricing-dependencies.json'));
 await db.exec(deps.find(f=>f.proname==='resolve_app_fee').definition);
 await service();
 for(const name of ['20261027235408_esim_profile_identity_lifecycle.sql','20261027235409_esim_event_inbox_reconciliation.sql']) await db.exec(read('supabase/migrations/'+name));
 await db.exec(read('docs/reviews/esimaccess-alerts-20261028/evidence/notification-trigger-before.sql'));
 await db.exec(read('supabase/migrations/20261028013756_esim_actionable_alerts.sql'));
 await db.exec(read('supabase/migrations/20261028070000_esim_recharge_discovery_quotes.sql'));
 for(const f of JSON.parse(read(e+'wallet.json')))if(f.definition)await db.exec(f.definition);
 const ops=JSON.parse(read(e+'operation.json'))[0].operation_contract;
 for(const f of ops.functions)await db.exec(f.definition);
 for(const f of JSON.parse(read(e+'patch.json')))await db.exec(f.definition);
 await db.exec('CREATE TRIGGER snapshot_esim_catalogue_order BEFORE INSERT ON esim_orders FOR EACH ROW EXECUTE FUNCTION snapshot_esim_catalogue_order()');
 const shapes=JSON.parse(read(e+'shapes.json'));await db.exec('CREATE VIEW public.wallet_reconciliation AS '+shapes.reconciliation);
 const migrations=fs.readdirSync(new URL('supabase/migrations/',root)).filter(n=>n.endsWith('_esim_fixed_recharge_settlement.sql'));assert.equal(migrations.length,1);
 await db.exec(read('supabase/migrations/'+migrations[0]));
 await db.exec(read('supabase/migrations/20261028042528_esim_settlement_view_boundary.sql'));
 // Actual live orders RLS and view ACL predate the ESIM-03 migration.
 await db.exec(`ALTER TABLE public.esim_orders ENABLE ROW LEVEL SECURITY;CREATE POLICY "Users can read own esim orders" ON public.esim_orders FOR SELECT TO authenticated USING(auth.uid()=user_id);GRANT SELECT ON public.customer_esim_orders TO authenticated,service_role;`);
 await db.exec(`insert into auth.users(id) values('${owner}'),('${other}');insert into auth.sessions(id,user_id) values('${owner}','${owner}'),('${other}','${other}');
 insert into profiles(id) values('${owner}'),('${other}');insert into esim_suppliers(code,name,is_active) values('esimaccess','Fixture',true);
 insert into app_fee_rules(appfees_item,version,status,free_percentage,free_minimum,stand_percentage,stand_minimum,prem_percentage,prem_minimum) values('esimofferfee',999,'published',10,0.5,7,0.3,5,0.1);
 insert into wallets(user_id,balance,currency) values('${owner}',20,'USD'),('${other}',20,'USD');
 insert into wallet_transactions(wallet_id,user_id,type,amount,balance_before,balance_after,status,reference_id) select id,user_id,'deposit',20,0,20,'completed','fixture_deposit_'||user_id::text from wallets;
 insert into wallet_funding_lots(wallet_id,user_id,origin_type,funded_amount,remaining_amount,currency,status) select id,user_id,'unverified_legacy',20,20,'USD','active' from wallets;
 update esim_private.accounts set new_sales_enabled=true,wallet_boundary_verified=true;
 update esim_private.recharge_policy set discovery_enabled=true;`);
 // A proven historical profile, not an order waiting for this release to issue.
 const order=await one(`insert into esim_orders(user_id,provider,bundle_name,quantity,wholesale_price_usd,retail_price_usd,markup_percent,total_amount_usd,status)
 values($1,'esimaccess','BASE_FIXTURE',1,1,1.5,50,1.5,'completed') returning id v`,[owner]);
 const profile=await one(`insert into user_esims(user_id,order_id,provider,bundle_name,iccid,smdp_address,matching_id,lpa_string,status,data_total_mb,data_remaining_mb,
 supplier_account_id,supplier_profile_ref,profile_state,installation_state,bundle_state,last_observation_at,confirmed_expires_at,plan_details)
 select $1,$2,'esimaccess','BASE_FIXTURE','8900000000000000001','fixture.invalid','private','LPA:1$fixture.invalid$private','active',1024,0,id,'FIXTURE_PROFILE','active','enabled','depleted',now(),now()+interval '5 days',
 '{"topup_support":"supported"}' from esim_private.accounts returning user_esims.id v`,[owner,order]);
 await q("update esim_private.order_runs set state='completed' where order_id=$1",[order]);
 await db.exec('update esim_private.accounts set new_sales_enabled=false,wallet_boundary_verified=false');
 const enable=async()=>{await service();await db.exec('update esim_private.accounts set recharge_enabled=true,recharge_contract_verified=true,wallet_boundary_verified=true');};
 const discover=()=>one('select public.request_esim_topups($1) v',[profile]);
 const makeQuote=async()=>{
  await user();const discovery=await discover();
  if(discovery.status!=='READY') {
   assert.equal(discovery.status,'PENDING');await service();const job=await one('select public.service_esim_claim_topups() v');assert(job);
   await one('select public.service_esim_save_topups($1,$2,$3) v',[profile,job.lease,JSON.stringify(topups)]);await user();
  }
  const d=await discover();assert.equal(d.status,'READY');return one('select public.quote_esim_topup($1,$2,$3,$4) v',[profile,'TOPUP_A',d.offer_version,1.73]);
 };
 const accept=quote=>one('select public.accept_esim_topup($1,$2) v',[quote.quote_id,quote.acceptance_key]);
 const claim=async()=>{await service();return one('select public.service_esim_claim_order() v');};
 const submit=job=>one('select public.service_esim_mark_submitted($1,$2) v',[job.order_id,job.lease]);
 const receipt=job=>({outcome:'success',source:'authenticated_inline_response',transaction_id:job.submission_ref,supplier_profile_ref:'FIXTURE_PROFILE',iccid:'8900000000000000001',package_id:'TOPUP_A',topup_ref:'FIXTURE_TOPUP_'+job.order_id,expires_at:new Date(Date.now()+12*86400000).toISOString(),total_bytes:'2147483648',used_bytes:'1073741824'});
 const record=(job,r=receipt(job))=>one('select public.service_esim_record_topup_receipt($1,$2,$3) v',[job.order_id,job.submission_ref,JSON.stringify(r)]);
 const settle=job=>one('select public.service_esim_settle_topup($1) v',[job.order_id]);
 return {db,q,one,user,service,profile,order,enable,discover,makeQuote,accept,claim,submit,receipt,record,settle};
}
