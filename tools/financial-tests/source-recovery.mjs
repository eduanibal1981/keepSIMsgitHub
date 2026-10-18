// Bounded clean/upgrade source-recovery regression. No network or database URL.
// This is not a full Supabase baseline/reset or a production deployment gate.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createHash} from 'node:crypto';
import {pathToFileURL} from 'node:url';
import {bootstrapProductionBaseline,applyFinancialMigrations} from './bootstrap.mjs';
const {PGlite}=await import(process.env.PGLITE_MODULE_PATH?pathToFileURL(process.env.PGLITE_MODULE_PATH).href:'@electric-sql/pglite');
const recovery=JSON.parse(fs.readFileSync(new URL('../../supabase/recovered/20261018/public-routines.json',import.meta.url),'utf8'));
const results=[];
for(const mode of ['clean captured public subset','upgrade captured public subset with existing identity/wallet']){
 const db=new PGlite();
 try{
  await bootstrapProductionBaseline(db);
  const user='22000000-0000-4000-8000-000000000022';
  if(mode.startsWith('upgrade')){
   await db.exec(`INSERT INTO auth.users(id,email) VALUES('${user}','source-test@example.invalid');
    INSERT INTO public.profiles(id,email) VALUES('${user}','source-test@example.invalid');
    SELECT public.ensure_wallet_v2('${user}');`);
  }
  await db.exec('SET check_function_bodies=false');
  for(const fn of recovery.functions){
   await db.exec(fn.definition);
   const signature=`public.${fn.name}(${fn.types})`;
   await db.exec(`REVOKE ALL ON FUNCTION ${signature} FROM PUBLIC,anon,authenticated,service_role`);
   // Preserve the recorded ACL rather than accidentally creating PUBLIC execute.
   // The fixture only has the API/service roles; postgres is its owner.
   for(const entry of (fn.acl||'').replace(/^\{|\}$/g,'').split(',')){
    const acl=/^([^=]*)=([^/]+)\//.exec(entry);if(!acl)continue;
    const role=acl[1];
    if(!['','anon','authenticated','service_role'].includes(role)||!acl[2].includes('X'))continue;
    await db.exec(`GRANT EXECUTE ON FUNCTION ${signature} TO ${role||'PUBLIC'}${acl[2].includes('X*')?' WITH GRANT OPTION':''}`);
   }
  }
  await db.exec('SET check_function_bodies=true');
  for(const fn of recovery.functions){
   const signature=`public.${fn.name}(${fn.types})`;
   const row=(await db.query('SELECT prosrc FROM pg_proc WHERE oid=to_regprocedure($1)',[signature])).rows[0];
   assert.ok(row,signature);
   assert.equal(createHash('sha256').update(row.prosrc).digest('hex'),fn.source_sha256,signature);
  }
  results.push({mode,name:'17 exact signatures and bodies restored in isolation',status:'passed'});
  await applyFinancialMigrations(db);
  for(const types of ['uuid,text,text','uuid,text,text,text,text,text']){
   assert.equal((await db.query(`SELECT to_regprocedure('public.update_execution_status(${types})') IS NULL AS gone`)).rows[0].gone,true);
  }
  const permissions=(await db.query(`SELECT has_function_privilege('authenticated',
    'public.claim_instant_executions(text,integer)','EXECUTE') AS customer,
    has_function_privilege('service_role','public.claim_instant_executions(text,integer)','EXECUTE') AS worker`)).rows[0];
  assert.equal(permissions.customer,false);assert.equal(permissions.worker,true);
  results.push({mode,name:'forward repairs retire legacy overloads and retain service-only claims',status:'passed'});
  if(mode.startsWith('upgrade')){
   const row=(await db.query('SELECT w.balance,p.email FROM public.wallets w JOIN public.profiles p ON p.id=w.user_id WHERE w.user_id=$1',[user])).rows[0];
   assert.equal(Number(row.balance),0);assert.equal(row.email,'source-test@example.invalid');
   results.push({mode,name:'existing identity and zero-balance wallet preserved without fabricated funding',status:'passed'});
  }
 }catch(error){results.push({mode,name:'source recovery',status:'failed',message:error.message});console.error(error.message,error.where||'');}
 finally{await db.close();}
}
const report={environment:'isolated PGlite, production-shaped bounded public fixture',
 full_fresh_provisioning:'BLOCKED: no approved complete baseline or non-public dependencies',
 full_current_shape_upgrade:'BLOCKED: not covered by this bounded fixture',results};
if(process.env.SOURCE_RECOVERY_REPORT)fs.writeFileSync(process.env.SOURCE_RECOVERY_REPORT,JSON.stringify(report,null,2)+'\n');
for(const result of results)console.log(result.status.toUpperCase()+' '+result.mode+': '+result.name);
if(results.some(r=>r.status==='failed'))process.exitCode=1;
