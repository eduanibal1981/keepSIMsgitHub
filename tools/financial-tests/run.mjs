import { runCalls } from './calls.mjs';
import { runLiveness } from './liveness.mjs';
import { runSupplierRecovery } from './supplier-recovery.mjs';
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';
import { bootstrapProductionBaseline, applyFinancialMigrations } from './bootstrap.mjs';
import { verifyProductionFixture } from './fixture-verification.mjs';
import { runSetupSettlement } from './setup-settlement.mjs';
import { runScheduledSettlement } from './scheduled-settlement.mjs';
import { runSQLCases } from './sql-cases.mjs';
const { PGlite } = await import(process.env.PGLITE_MODULE_PATH
  ? pathToFileURL(process.env.PGLITE_MODULE_PATH).href : '@electric-sql/pglite');
const db = new PGlite();
let results=[];
try {
  await bootstrapProductionBaseline(db);
  await verifyProductionFixture(db);
  await applyFinancialMigrations(db);
  const suites=[['funding and refund integrity','wallet_funding_refund_integrity_tests.sql'],['transaction contracts','financial_transaction_contract_tests.sql'],
    ['wallet accounting','wallet_accounting_invariants_tests.sql'],['financial remediation','financial_remediation_tests.sql']];
  for(const [label,file] of suites)results.push(...await runSQLCases(db,
    fs.readFileSync(new URL('../../supabase/tests/'+file,import.meta.url),'utf8'),label));
  const check=async(name,body)=>{
    try{await body();results.push({name,status:'passed'});console.log('PASS '+name);}
    catch(error){results.push({name,status:'failed',message:error.message});console.error('FAIL '+name+': '+error.message);}
  };
  await runSetupSettlement({owner:db},check);
  await runScheduledSettlement({owner:db},check);
  await runSupplierRecovery({owner:db},check);
  await runLiveness({owner:db},check);
  await runCalls({owner:db},check);
  const failed=results.filter(r=>r.status==='failed').length;
  console.log(`${results.length-failed} passed / ${failed} failed financial SQL blocks`);
  if(process.env.FINANCIAL_TEST_REPORT)fs.writeFileSync(process.env.FINANCIAL_TEST_REPORT,JSON.stringify({results},null,2)+'\n');
  if(failed)process.exitCode=1;
} catch(error){console.error('FAIL bootstrap: '+error.message);process.exitCode=1;}
finally { await db.close(); }
