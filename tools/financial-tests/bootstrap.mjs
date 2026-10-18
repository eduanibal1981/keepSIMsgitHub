import { createProductionTables, installProductionFunctions, installProductionSecurityAndTriggers } from './production-fixture.mjs';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import migrationSource from '../migration-source.cjs';
const root = fileURLToPath(new URL('../../', import.meta.url));
const read=file=>fs.readFileSync(path.join(root,file),'utf8');
export async function exec(db,label,sql) {
  try { await db.exec(sql); console.log('PASS '+label); }
  catch(error) { throw new Error('FAIL '+label+': '+error.message+'\n'+(error.where||'')); }
}
export async function bootstrapProductionBaseline(db) {
  if(process.env.TEST_OCTOBER4_APPLIED)throw Error('Historical shape mode was removed: this fixture starts from captured production, not a pre-October-4 schema');
  await exec(db,'isolated schema',read('supabase/tests/fixtures/financial_remediation_baseline.sql'));
  await createProductionTables(db);
  await installProductionFunctions(db);
  await installProductionSecurityAndTriggers(db);
  await exec(db,'captured media-session dependency',migrationSource('20260917182910_calling_media_sessions.sql').split("-- Ensure 'declined'")[0]);
  console.log('PASS captured production tables, constraints, functions, grants, policies and financial triggers');
}
export function financialMigrationFiles() {
  // The credential control-plane migration has its own Vault/auth fixture in
  // credentials.mjs; it is not part of the financial schema under test here.
  const migrations=fs.readdirSync(path.join(root,'supabase/migrations')).filter(x=>/^202610160.*\.sql$/.test(x)||x.endsWith('_sim_setup_instant_settlement.sql')||x.endsWith('_scheduled_refill_worker_contracts.sql')||x.endsWith('_supplier_outcome_recovery.sql')||x.endsWith('_liveness_verification_contract.sql')||x.endsWith('_call_budget_contract.sql')).sort();
  return migrations;
}
export async function applyFinancialMigrations(db) {
  for(const file of financialMigrationFiles()) await exec(db,file,read('supabase/migrations/'+file));
}
export async function bootstrap(db) {
  await bootstrapProductionBaseline(db);
  await applyFinancialMigrations(db);
}
