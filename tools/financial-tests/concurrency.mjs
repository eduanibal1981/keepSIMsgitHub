import { runCalls } from './calls.mjs';
import { runLiveness } from './liveness.mjs';
import { runSupplierRecovery } from './supplier-recovery.mjs';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { bootstrapProductionBaseline, applyFinancialMigrations } from './bootstrap.mjs';
import { verifyProductionFixture } from './fixture-verification.mjs';
import { runSQLCases } from './sql-cases.mjs';
import { runRefundIntegration } from './refund-integration.mjs';
import { runSetupSettlement } from './setup-settlement.mjs';
import { runScheduledSettlement } from './scheduled-settlement.mjs';
import { runFundingConcurrency } from './funding-concurrency.mjs';
const importTool = (name, env) => import(process.env[env] ? pathToFileURL(process.env[env]).href : name);
const { default: EmbeddedPostgres } = await importTool('embedded-postgres','EMBEDDED_POSTGRES_MODULE_PATH');
const directory=await fs.mkdtemp(path.join(os.tmpdir(),'keepsims-financial-postgres-'));
// Local fixtures only. This runner cannot connect to an external database.
const server=new EmbeddedPostgres({ databaseDir:directory,user:'postgres',password:'isolated-test',
  port:Number(process.env.FINANCIAL_TEST_PORT||56543),persistent:false,initdbFlags:['--locale=C'],
  postgresFlags:['-h','127.0.0.1',...(process.platform==='win32'?[]:['-k','/tmp'])],onLog:()=>{},onError:()=>{} });
const clients=[];
const results=[];
async function check(name,body){
  try{await body();results.push({name,status:'passed'});console.log('PASS '+name);}
  catch(error){results.push({name,status:'failed',code:error.code||null,constraint:error.constraint||null,message:error.message});console.error(`FAIL ${name}: ${error.message} [${error.code||'assertion'}]`);}
}
async function connect() { const c=server.getPgClient(); await c.connect(); clients.push(c); return c; }
async function scalar(c,sql,args=[]) { return Object.values((await c.query(sql,args)).rows[0])[0]; }
async function wallet(c,amount=20) {
  const u=crypto.randomUUID(); await c.query('INSERT INTO auth.users(id,email) VALUES($1,$2)',[u,u+'@keepsims.test']);
  await c.query('INSERT INTO public.profiles(id,email) VALUES($1,$2)',[u,u+'@keepsims.test']);
  await c.query('SELECT public.ensure_wallet_v2($1)',[u]);
  await c.query("SELECT public.credit_wallet_for_deposit($1,$2,'fixture',$3,jsonb_build_object('paypal_capture_id',$4::text))",[u,amount,'paypal_'+u,u]); return u;
}
try {
  await server.initialise(); await server.start();
  const c=await connect(), a=await connect(), b=await connect();
  const db={exec:sql=>c.query(sql),query:sql=>c.query(sql)};
  await bootstrapProductionBaseline(db);
  await verifyProductionFixture(db);
  await applyFinancialMigrations(db);
  for(const file of ['financial_fixture_tests.sql','wallet_funding_refund_integrity_tests.sql','financial_transaction_contract_tests.sql','wallet_accounting_invariants_tests.sql','financial_remediation_tests.sql']){
    results.push(...await runSQLCases(db,await fs.readFile(new URL('../../supabase/tests/'+file,import.meta.url),'utf8'),file));
  }
  // Use the actual trusted API role for money RPC races, rather than relying
  // on the fixture owner's table/RLS bypass privileges.
  for(const client of [a,b]){
    await client.query('SET ROLE service_role');
    await client.query("SELECT set_config('request.jwt.claims','{\"role\":\"service_role\"}',false)");
  }
  await check('concurrent reservations and immediate debits respect funding allocations',async()=>{
  const u=await wallet(c), ref=crypto.randomUUID();
  const [one,two]=await Promise.all([a,b].map(client=>scalar(client,"SELECT public.reserve_wallet_funds($1,12,'refill_instant',$2)",[u,ref])));
  assert.equal(one,two);
  assert.equal(Number(await scalar(c,"SELECT count(*) FROM public.wallet_holds WHERE user_id=$1 AND status='active'",[u])),1);
  console.log('PASS concurrent duplicate reservation adopts one hold');
  const attempts=await Promise.allSettled([a,b].map((client,i)=>scalar(client,"SELECT public.reserve_wallet_funds($1,6,'refill_scheduled',$2)",[u,ref+i])));
  assert.equal(attempts.filter(x=>x.status==='fulfilled').length,1);
  assert.equal(Number(await scalar(c,"SELECT sum(amount) FROM public.wallet_holds WHERE user_id=$1 AND status='active'",[u])),18);
  assert.equal(Number(await scalar(c,`SELECT count(*) FROM public.wallet_funding_lots l WHERE user_id=$1
    AND remaining_amount<(SELECT coalesce(sum(x.amount),0) FROM public.wallet_hold_allocations x JOIN public.wallet_holds h ON h.id=x.hold_id WHERE x.lot_id=l.id AND h.status='active')`,[u])),0);
  console.log('PASS competing holds cannot overspend or reuse lot allocations');
  const spending=await Promise.allSettled([a,b].map((client,i)=>scalar(client,"SELECT public.debit_wallet_for_topup($1,NULL,2,'fixture',$2)",[u,'spend-'+ref+i])));
  assert.equal(spending.filter(x=>x.status==='fulfilled').length,1);
  assert.equal(Number(await scalar(c,'SELECT balance FROM public.wallets WHERE user_id=$1',[u])),18);
  console.log('PASS competing immediate debits respect all reservations');
  });

  await check('concurrent refund request, claim and payout settle once',async()=>{
  const refundUser=await wallet(c,10);
  const requests=await Promise.all([a,b].map(client=>scalar(client,'SELECT public.request_wallet_refund($1,10)',[refundUser])));
  assert.equal(requests[0].refund_request_id,requests[1].refund_request_id);
  const request=requests[0];
  console.log('PASS concurrent duplicate refund requests adopt one reservation');
  const item=await scalar(c,'SELECT id FROM public.wallet_refund_items WHERE refund_request_id=$1',[request.refund_request_id]);
  const claims=await Promise.all([a,b].map(client=>scalar(client,'SELECT public.claim_wallet_refund_item($1)',[item])));
  assert.equal(claims.filter(x=>x.claimed).length,1);
  const claim=claims.find(x=>x.claimed);
  await scalar(a,'SELECT public.begin_wallet_refund_submission($1,$2)',[item,claim.claim_token]);
  await scalar(a,"SELECT public.record_wallet_refund_evidence($1,$2,'completed','provider-proof')",[item,claim.claim_token]);
  await Promise.all([a,b].map(client=>scalar(client,"SELECT public.finish_wallet_refund_item($1,$2,'completed','provider-proof')",[item,claim.claim_token])));
  assert.equal(Number(await scalar(c,'SELECT balance FROM public.wallets WHERE user_id=$1',[refundUser])),0);
  assert.equal(Number(await scalar(c,"SELECT count(*) FROM public.wallet_transactions WHERE user_id=$1 AND type='refund_payout'",[refundUser])),1);
  console.log('PASS concurrent refund claims and settlement produce one ledger payout');
  });

  await runFundingConcurrency({owner:c,one:a,two:b},check);
  await runRefundIntegration({owner:c,one:a,two:b},check);

  await check('concurrent finalizers activate and charge once',async()=>{
  const setupUser=await wallet(c,10), line=crypto.randomUUID(), order=crypto.randomUUID();
  await c.query("INSERT INTO public.sim_lines(id,user_id,phone_number,plan_type) VALUES($1,$2,'+15550000999','standard')",[line,setupUser]);
  const hold=await scalar(c,"SELECT public.reserve_wallet_funds($1,2.5,'plan_fee',$2)",[setupUser,'setup_fee_'+order]);
  await c.query("INSERT INTO public.sim_setup_orders(id,user_id,sim_line_id,plan,phone_number,annual_fee_usd,total_charge_usd,annual_fee_hold_id,status) VALUES($1,$2,$3,'standard','+15550000999',2.5,2.5,$4,'reserved')",[order,setupUser,line,hold]);
  for(const client of [a,b]){
    await client.query('RESET ROLE');
    await client.query('SET ROLE authenticated');
    await client.query("SELECT set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub:setupUser,role:'authenticated'})]);
  }
  const finalizations=await Promise.all([a,b].map(client=>scalar(client,'SELECT public.finalize_sim_setup_order($1)',[order])));
  assert.ok(finalizations.every(x=>x.success));
  assert.equal(Number(await scalar(c,'SELECT balance FROM public.wallets WHERE user_id=$1',[setupUser])),7.5);
  assert.equal(Number(await scalar(c,'SELECT count(*) FROM public.plan_payments WHERE sim_line_id=$1',[line])),1);
  console.log('PASS concurrent finalizers activate and charge once');
  });
  await runSetupSettlement({owner:c,one:a,two:b},check);
  await runScheduledSettlement({owner:c,one:a,two:b},check);
  await runSupplierRecovery({owner:c,one:a,two:b},check);
  await runLiveness({owner:c,one:a,two:b},check);
  await runCalls({owner:c,one:a,two:b},check);
  const failed=results.filter(r=>r.status==='failed').length;
  console.log(`${results.length-failed} passed / ${failed} failed native PostgreSQL blocks`);
  if(process.env.FINANCIAL_TEST_REPORT)await fs.writeFile(process.env.FINANCIAL_TEST_REPORT,JSON.stringify({results},null,2)+'\n');
  if(failed)process.exitCode=1;
} catch(error){
  console.error('FAIL native bootstrap: '+error.message);process.exitCode=1;
} finally {
  await Promise.allSettled(clients.map(c=>c.end()));
  await server.stop();
  await fs.rm(directory,{recursive:true,force:true});
}
// async-exit-hook (used by embedded-postgres) defaults beforeExit to zero;
// explicitly preserve a red test result after the server has been cleaned up.
if(process.exitCode)process.exit(process.exitCode);
