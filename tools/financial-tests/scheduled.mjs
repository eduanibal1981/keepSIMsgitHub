import { pathToFileURL } from 'node:url';
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { bootstrapProductionBaseline,financialMigrationFiles,exec } from './bootstrap.mjs';
import { runScheduledSettlement } from './scheduled-settlement.mjs';
const {PGlite}=await import(process.env.PGLITE_MODULE_PATH?pathToFileURL(process.env.PGLITE_MODULE_PATH).href:'@electric-sql/pglite');
const db=new PGlite();let failed=0,passed=0;
try{
  await bootstrapProductionBaseline(db);
  const final=financialMigrationFiles().find(f=>f.endsWith('_scheduled_refill_worker_contracts.sql'));
  for(const file of financialMigrationFiles().filter(f=>f<final))await exec(db,file,
    fs.readFileSync(new URL('../../supabase/migrations/'+file,import.meta.url),'utf8'));
  const migration=fs.readFileSync(new URL('../../supabase/migrations/'+final,import.meta.url),'utf8');
  // A parsed SQL body gives PostgreSQL a real dependency on the legacy API.
  await db.exec("CREATE FUNCTION public.fixture_status_dependency() RETURNS void LANGUAGE sql BEGIN ATOMIC SELECT public.update_execution_status(NULL::uuid,'pending'::text,NULL::text,NULL::text,NULL::text,NULL::text); END");
  await assert.rejects(()=>db.exec(migration),/depend/);
  await db.exec('ROLLBACK');
  assert.equal((await db.query("SELECT count(*)::int AS n FROM pg_attribute WHERE attrelid='public.topup_executions'::regclass AND attname='scheduled_refill_submission' AND NOT attisdropped")).rows[0].n,0);
  await db.exec('DROP FUNCTION public.fixture_status_dependency()');
  await exec(db,final,migration);
  for(const file of financialMigrationFiles().filter(f=>f>final))await exec(db,file,fs.readFileSync(new URL('../../supabase/migrations/'+file,import.meta.url),'utf8'));
  passed++;console.log('PASS unexpected legacy API dependency stops and rolls back the forward migration');
  await runScheduledSettlement({owner:db},async(name,body)=>{
    try{await body();passed++;console.log('PASS '+name);}
    catch(error){failed++;console.error('FAIL '+name+': '+error.message);}
  });
  console.log(`${passed} passed / ${failed} failed scheduled-refill scenarios`);
  if(failed)process.exitCode=1;
}finally{await db.close();}
