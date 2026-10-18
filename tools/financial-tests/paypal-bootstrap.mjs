import fs from 'node:fs';
const read = p => fs.readFileSync(new URL('../../'+p,import.meta.url),'utf8');
export async function bootstrapPayPal(exec, mode='live') {
  await exec(read('supabase/tests/fixtures/paypal_capture_baseline.sql'));
  if (mode==='live') await exec(read('supabase/tests/fixtures/paypal_live_credit.sql'));
  else {
    // Deposit-only M2 integration. Reconstruct actual reservation/refund shapes
    // for the funding trigger's binding checks; never weaken the trigger for a
    // smaller fixture. No reservation/refund RPCs are exercised by this suite.
    const snapshot=JSON.parse(read('supabase/tests/fixtures/financial_production_snapshot.json'));
    const names=['wallet_holds','wallet_hold_allocations','wallet_refund_requests','wallet_refund_items'];
    for(const table of names){
      const columns=snapshot.columns.filter(c=>c.table===table).map(c=>`"${c.column}" ${c.type}${c.default?' DEFAULT '+c.default:''}${c.not_null?' NOT NULL':''}`);
      await exec(`CREATE TABLE public.${table} (${columns.join(',')})`);
    }
    for(const kind of ['p','u','c','f'])for(const c of snapshot.constraints.filter(c=>names.includes(c.table)&&c.type===kind)){
      await exec(`ALTER TABLE public.${c.table} ADD CONSTRAINT "${c.name}" ${c.definition}`);
    }
    await exec("ALTER TABLE public.wallet_refund_items ADD COLUMN provider_outcome text CHECK(provider_outcome IN ('completed','failed','pending','unknown'))");
    const m2=read('supabase/migrations/20261016020000_wallet_funding_integrity.sql');
    const definitions=m2.slice(m2.indexOf('CREATE TABLE public.wallet_transaction_funding'),
      m2.indexOf('-- Refund holds have no time-based release')) +
      m2.slice(m2.indexOf('CREATE OR REPLACE FUNCTION public.credit_wallet_for_deposit('),
        m2.indexOf('CREATE OR REPLACE FUNCTION public.credit_wallet_for_refund('));
    await exec(definitions);
  }
  await exec(read('supabase/migrations/20261017110000_paypal_capture_fulfillment.sql'));
}
export const user='10000000-0000-4000-8000-000000000001';
export const other='10000000-0000-4000-8000-000000000002';
export const evidence=(overrides={})=>({order_id:'ORDER0001',capture_id:'CAPTURE001',status:'COMPLETED',
  user_id:user,kind:'deposit',amount:'10.00',currency:'USD',merchant_id:'MERCHANT00001',
  expected_merchant_id:'MERCHANT00001',source:'capture_endpoint',...overrides});
export async function seedPayPal(query) {
  await query('insert into auth.users(id) values($1),($2)',[user,other]);
  await query("insert into public.paypal_orders(order_id,user_id,kind,amount_usd) values('ORDER0001',$1,'deposit',10),('ORDER0002',$2,'deposit',10)",[user,other]);
  await query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({role:'service_role'})]);
}
