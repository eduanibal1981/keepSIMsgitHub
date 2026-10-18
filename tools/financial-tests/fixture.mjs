import fs from 'node:fs';
import { pathToFileURL } from 'node:url';
import { bootstrapProductionBaseline, applyFinancialMigrations } from './bootstrap.mjs';
import { verifyProductionFixture } from './fixture-verification.mjs';
import { runSQLCases } from './sql-cases.mjs';
const { PGlite }=await import(process.env.PGLITE_MODULE_PATH?pathToFileURL(process.env.PGLITE_MODULE_PATH).href:'@electric-sql/pglite');
const db=new PGlite();
try{
  await bootstrapProductionBaseline(db);
  await verifyProductionFixture(db);
  await applyFinancialMigrations(db);
  const results=await runSQLCases(db,fs.readFileSync(new URL('../../supabase/tests/financial_fixture_tests.sql',import.meta.url),'utf8'),'fixture guard');
  if(results.some(r=>r.status==='failed'))process.exitCode=1;
}catch(error){console.error(error);process.exitCode=1;}
finally{await db.close();}
