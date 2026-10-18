import fs from 'node:fs';
import { pathToFileURL } from 'node:url';
import { bootstrap } from './bootstrap.mjs';
import { runSetupSettlement } from './setup-settlement.mjs';
const {PGlite}=await import(process.env.PGLITE_MODULE_PATH?pathToFileURL(process.env.PGLITE_MODULE_PATH).href:'@electric-sql/pglite');
const db=new PGlite(),results=[];
try{
  await bootstrap(db);
  await runSetupSettlement({owner:db},async(name,body)=>{
    try{await body();results.push({name,status:'passed'});console.log('PASS '+name);}
    catch(error){results.push({name,status:'failed',message:error.message});console.error('FAIL '+name+': '+error.message);}
  });
}finally{await db.close();}
console.log(`${results.filter(x=>x.status==='passed').length} passed / ${results.filter(x=>x.status==='failed').length} failed setup scenarios`);
if(process.env.FINANCIAL_TEST_REPORT)fs.writeFileSync(process.env.FINANCIAL_TEST_REPORT,JSON.stringify({results},null,2)+'\n');
if(results.some(x=>x.status==='failed'))process.exitCode=1;
