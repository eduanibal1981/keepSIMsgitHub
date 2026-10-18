process.on('uncaughtException', error => { console.error(error.message, error.code || ''); process.exitCode=1; });
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {bootstrapPayPal,seedPayPal,evidence,user,other} from './paypal-bootstrap.mjs';
const {PGlite}=await import(process.env.PGLITE_MODULE_PATH?pathToFileURL(process.env.PGLITE_MODULE_PATH).href:'@electric-sql/pglite');
let count=0;
for(const mode of ['live','m2']){
  const db=new PGlite();
  const value=async(sql,args=[])=>(await db.query(sql,args)).rows[0]?.value;
  const fulfill=(data=evidence(),order='ORDER0001')=>value('select public.fulfill_paypal_capture($1,$2::jsonb) as value',[order,JSON.stringify(data)]);
  const stats=()=>value(`select jsonb_build_object('balance',(select sum(balance) from public.wallets),
    'ledger',(select count(*) from public.wallet_transactions),'lots',(select count(*) from public.wallet_funding_lots),
    'receipts',(select count(*) from public.paypal_capture_receipts),'captured',(select count(*) from public.paypal_orders where status='captured')) as value`);
  async function test(name,run){await db.exec('BEGIN');try{await run();console.log(`PASS ${mode}: ${name}`);count++;}finally{await db.exec('ROLLBACK');}}
  try{
    await bootstrapPayPal(sql=>db.exec(sql),mode);await seedPayPal((sql,args)=>db.query(sql,args));
    await test('one capture commits one deposit, receipt and refundable source with canonical identity',async()=>{
      assert.equal((await fulfill()).success,true);assert.deepEqual(await stats(),{balance:10,ledger:1,lots:1,receipts:1,captured:1});
      const {rows:[row]}=await db.query('select t.reference_id,l.original_reference_id,l.original_order_id,l.funded_amount,l.remaining_amount,l.is_refundable from public.wallet_transactions t join public.wallet_funding_lots l on l.wallet_id=t.wallet_id');
      assert.deepEqual(row,{reference_id:'paypal_CAPTURE001',original_reference_id:'CAPTURE001',original_order_id:'ORDER0001',funded_amount:'10.00',remaining_amount:'10.00',is_refundable:true});
    });
    await test('client/webhook replay returns the existing result without another deposit or lot',async()=>{
      await fulfill();assert.equal((await fulfill(evidence({source:'webhook',event_id:'event-2'}))).duplicate,true);assert.deepEqual(await stats(),{balance:10,ledger:1,lots:1,receipts:1,captured:1});
    });
    await test('unknown, foreign, amount, currency, purpose, merchant and incomplete evidence all reject without writes',async()=>{
      for(const overrides of [{user_id:other},{amount:'10.01'},{amount:'NaN'},{amount:'0'},{currency:'EUR'},{kind:'plan'},
        {merchant_id:'FOREIGN'},{expected_merchant_id:null},{status:'PENDING'},{capture_id:'ORDER0001'},{order_id:'UNKNOWN'}]){
        await db.exec('SAVEPOINT invalid');await assert.rejects(fulfill(evidence(overrides)));await db.exec('ROLLBACK TO SAVEPOINT invalid');
        assert.equal((await stats()).ledger,0);
      }
    });
    await test('receipt metadata keeps numeric gross, fee and net for existing wallet clients',async()=>{
      await fulfill(evidence({paypal_fee:{currency_code:'USD',value:'0.50'},net:{currency_code:'USD',value:'9.50'}}));
      assert.deepEqual(await value("select jsonb_build_object('gross',metadata->'gross','fee',metadata->'paypal_fee','net',metadata->'net') as value from public.wallet_transactions"),{gross:10,fee:0.5,net:9.5});
    });
    await test('same order cannot adopt a different capture',async()=>{
      await fulfill();await db.exec('SAVEPOINT conflict');await assert.rejects(fulfill(evidence({capture_id:'CAPTURE002'})));await db.exec('ROLLBACK TO SAVEPOINT conflict');assert.equal((await stats()).ledger,1);
    });
    await test('same capture cannot credit another owner/order',async()=>{
      await fulfill();await db.exec('SAVEPOINT conflict');await assert.rejects(fulfill(evidence({user_id:other,order_id:'ORDER0002'}),'ORDER0002'));await db.exec('ROLLBACK TO SAVEPOINT conflict');assert.equal((await stats()).ledger,1);
    });
    await test('late receipt failure rolls back wallet, ledger, lot and visible captured status; retry succeeds',async()=>{
      await db.exec(`CREATE FUNCTION public.fixture_fail_receipt() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'fixture unavailable'; END $$;
        CREATE TRIGGER fixture_failure BEFORE INSERT ON public.paypal_capture_receipts FOR EACH ROW EXECUTE FUNCTION public.fixture_fail_receipt();`);
      await db.exec('SAVEPOINT fail');await assert.rejects(fulfill());await db.exec('ROLLBACK TO SAVEPOINT fail');
      assert.deepEqual(await stats(),{balance:null,ledger:0,lots:0,receipts:0,captured:0});
      await db.exec('DROP TRIGGER fixture_failure ON public.paypal_capture_receipts');await fulfill();assert.equal((await stats()).balance,10);
    });
    await test('canonical legacy deposit is adopted without replenishing its spent funding lot',async()=>{
      await value("select public.credit_wallet_for_deposit($1,10,'fixture','paypal_CAPTURE001',$2::jsonb) as value",[user,JSON.stringify({order_id:'ORDER0001',paypal_capture_id:'CAPTURE001'})]);
      await db.exec('update public.wallets set balance=4;update public.wallet_funding_lots set remaining_amount=4');
      assert.equal((await fulfill()).duplicate,true);assert.equal((await stats()).balance,4);assert.equal((await stats()).lots,1);
    });
    await test('legacy order-ID fallback is quarantined without a second credit',async()=>{
      await value("select public.credit_wallet_for_deposit($1,10,'fixture','paypal_ORDER0001',$2::jsonb) as value",[user,JSON.stringify({order_id:'ORDER0001',paypal_capture_id:'ORDER0001'})]);
      await db.exec('SAVEPOINT legacy');await assert.rejects(fulfill());await db.exec('ROLLBACK TO SAVEPOINT legacy');assert.equal((await stats()).balance,10);assert.equal((await stats()).receipts,0);
    });
    await test('missing legacy funding source is not invented',async()=>{
      await value("select public.credit_wallet_for_deposit($1,10,'fixture','paypal_CAPTURE001',$2::jsonb) as value",[user,JSON.stringify({order_id:'ORDER0001',paypal_capture_id:'CAPTURE001'})]);
      await db.exec('delete from public.wallet_funding_lots');await db.exec('SAVEPOINT legacy');await assert.rejects(fulfill());await db.exec('ROLLBACK TO SAVEPOINT legacy');assert.equal((await stats()).lots,0);assert.equal((await stats()).balance,10);
    });
    await test('legacy plan fulfillment records one payment and never credits the wallet',async()=>{
      await db.exec("update public.paypal_orders set kind='plan',plan='standard' where order_id='ORDER0001'");
      const data=evidence({kind:'plan',plan:'standard'});await fulfill(data);assert.equal((await fulfill(data)).duplicate,true);
      assert.equal((await stats()).ledger,0);assert.equal((await stats()).lots,0);assert.equal(await value('select count(*)::int as value from public.plan_payments'),1);
    });
    await test('completed receipt restores an older status downgrade without another credit',async()=>{
      await fulfill();await db.exec("update public.paypal_orders set status='failed' where order_id='ORDER0001'");
      assert.equal((await fulfill()).duplicate,true);assert.equal((await stats()).captured,1);assert.equal((await stats()).ledger,1);
    });
    await test('unknown stored order is rejected without a financial mutation',async()=>{
      await assert.rejects(fulfill(evidence({order_id:'UNKNOWN1'}),'UNKNOWN1'));
    });
    await test('read-only release catalog accepts the actual migration',async()=>{
      assert.deepEqual((await db.query(fs.readFileSync(new URL('../../supabase/tests/paypal_capture_fulfillment_catalog.sql',import.meta.url),'utf8'))).rows,[]);
    });
    await test('API roles cannot invoke fulfillment or access receipts directly; service uses only the RPC',async()=>{
      for(const role of ['anon','authenticated']){
        await db.exec('SAVEPOINT acl');await db.exec('SET LOCAL ROLE '+role);await assert.rejects(fulfill(),e=>e.code==='42501');await db.exec('ROLLBACK TO SAVEPOINT acl');
      }
      for(const role of ['anon','authenticated','service_role']){
        await db.exec('SAVEPOINT acl');await db.exec('SET LOCAL ROLE '+role);await assert.rejects(db.query('select * from public.paypal_capture_receipts'),e=>e.code==='42501');await db.exec('ROLLBACK TO SAVEPOINT acl');
      }
      await db.exec('SET LOCAL ROLE service_role');await fulfill();
    });
  }finally{await db.close();}
}
console.log(`${count} PayPal SQL regressions passed`);
