// Isolated production-shaped fixture only. No network/production credentials.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';
import { bootstrapProductionBaseline, applyFinancialMigrations } from './bootstrap.mjs';

const { PGlite } = await import(process.env.PGLITE_MODULE_PATH
  ? pathToFileURL(process.env.PGLITE_MODULE_PATH).href : '@electric-sql/pglite');
const db = new PGlite();
const sql = fs.readFileSync(new URL('../../supabase/verification/coordinated_rollout_preflight.sql', import.meta.url), 'utf8');
let passed = 0;
const check = async (name, body) => { await body(); passed++; console.log('PASS ' + name); };

async function inventory() {
  const before = await db.query(`SELECT count(*) FROM public.wallet_transactions`);
  const output = await db.exec(sql);
  assert.deepEqual((await db.query('SELECT count(*) FROM public.wallet_transactions')).rows, before.rows);
  assert.equal(output[3].rows[0].read_only, 'on');
  return output.filter(r => r.rows.length);
}

try {
  await bootstrapProductionBaseline(db);
  await check('old schema inventory reports absent new evidence objects', async () => {
    const output = await inventory();
    const presence = output.find(r => r.rows[0]?.name === 'account_purge_jobs').rows;
    assert.equal(presence.find(r => r.name === 'wallet_transaction_funding').present, false);
    assert.equal(presence.find(r => r.name === 'refill_supplier_submissions').present, false);
  });
  await check('legacy executions report missing versions and ambiguous terminal evidence', async () => {
    // No wallet/customer/provider call. Retained failed executions with a supplier
    // identity still require investigation; the inventory must not hide them.
    await db.exec(`INSERT INTO auth.users(id,email) VALUES
      ('00000000-0000-0000-0000-000000000025','rollout-fixture@example.test');
      INSERT INTO public.profiles(id,email) VALUES
      ('00000000-0000-0000-0000-000000000025','rollout-fixture@example.test');
      INSERT INTO public.sim_lines(id,user_id,phone_number) VALUES
      ('00000000-0000-0000-0000-000000000225','00000000-0000-0000-0000-000000000025','+15550000025');
      INSERT INTO public.topup_executions(id,user_id,sim_line_id,amount,status,
      reloadly_transaction_id,carrier_in_flight,updated_at)
      VALUES('00000000-0000-0000-0000-000000000125','00000000-0000-0000-0000-000000000025',
        '00000000-0000-0000-0000-000000000225',1,'failed',
        'isolated-provider-reference',true,now()-interval '1 hour')`);
    const output = await inventory();
    const execution = output.flatMap(r => r.rows).find(r => r.executions !== undefined);
    assert.equal(execution.status, 'failed');
    assert.equal(execution.recovery_version, 'missing');
    assert.equal(execution.schedule_version, 'missing');
    assert.equal(Number(execution.older_than_15_minutes), 1);
    // Aggregate output must not include the stored provider reference/phone/ID.
    const serialized = JSON.stringify(output);
    assert.equal(serialized.includes('isolated-provider-reference'), false);
    assert.equal(serialized.includes('+15550000025'), false);
    assert.equal(serialized.includes('00000000-0000-0000-0000-000000000125'), false);
    await db.exec("DELETE FROM public.topup_executions WHERE id='00000000-0000-0000-0000-000000000125'");
  });
  await check('original-debit linkage separates missing, ambiguous and single candidates', async () => {
    // Deliberately inconsistent legacy ledger evidence in the old isolated
    // fixture. Preserve real type/unique/CHECK constraints, then remove these
    // diagnostic rows before applying the financial migrations.
    await db.exec(`SELECT public.ensure_wallet_v2('00000000-0000-0000-0000-000000000025');
      INSERT INTO public.wallet_transactions(wallet_id,user_id,type,amount,balance_before,balance_after,reference_id)
      SELECT w.id,w.user_id,v.type,1,v.before,v.after,v.reference
      FROM public.wallets w CROSS JOIN (VALUES
        ('topup_debit',10,9,'original-a'),
        ('plan_fee_debit',9,8,'original-a'),
        ('esim_purchase_debit',8,7,'esim_a'),
        ('refund',7,8,'refund_original-a'),
        ('refund',8,9,'refund_missing'),
        ('esim_purchase_refund',9,10,'esim_refund_a'),
        ('call_refund',10,11,'call_refund_a')
      ) AS v(type,before,after,reference)
      WHERE w.user_id='00000000-0000-0000-0000-000000000025'`);
    const output = (await inventory()).flatMap(r => r.rows);
    const generic = output.find(r => r.type === 'refund');
    assert.equal(Number(generic.missing_original), 1);
    assert.equal(Number(generic.ambiguous_original), 1);
    assert.equal(Number(output.find(r => r.type === 'esim_purchase_refund').single_candidate_requires_allocation_review), 1);
    assert.equal(Number(output.find(r => r.type === 'call_refund').missing_original), 1);
    await db.exec("DELETE FROM public.wallet_transactions WHERE user_id='00000000-0000-0000-0000-000000000025'");
  });
  await applyFinancialMigrations(db);
  await check('repaired schema inventory sees funding and supplier evidence without fabricating rows', async () => {
    const output = await inventory();
    const presence = output.find(r => r.rows[0]?.name === 'account_purge_jobs').rows;
    assert.equal(presence.find(r => r.name === 'wallet_transaction_funding').present, true);
    assert.equal(presence.find(r => r.name === 'refill_supplier_submissions').present, true);
    assert.equal(Number((await db.query('SELECT count(*) FROM public.wallet_transaction_funding')).rows[0].count), 0);
  });
  console.log(`${passed} passed / 0 failed rollout preflight scenarios (isolated PGlite; not full upgrade/live proof)`);
} catch (error) {
  console.error('FAIL rollout preflight: ' + error.message);
  process.exitCode = 1;
} finally { await db.close(); }
