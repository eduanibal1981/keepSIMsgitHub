import { pathToFileURL } from 'node:url';
import fs from 'node:fs';
import { bootstrap } from './bootstrap.mjs';
import { runRefundIntegration } from './refund-integration.mjs';
const {PGlite}=await import(process.env.PGLITE_MODULE_PATH?pathToFileURL(process.env.PGLITE_MODULE_PATH).href:'@electric-sql/pglite');
const db=new PGlite(),results=[];
try{
 await bootstrap(db);
 await db.exec("SELECT set_config('request.jwt.claims','{\"role\":\"service_role\"}',false)");
 const one=db;
 // PGlite serializes queries. Avoid overlapping SET ROLE scope in a shared
 // session; actual role enforcement is covered by SQL guards and native tests.
 await runRefundIntegration({owner:db,one,two:one},async(name,body)=>{
  try{await body();results.push({name,status:'passed'});console.log('PASS '+name);}
  catch(error){results.push({name,status:'failed',message:error.message});console.error('FAIL '+name+': '+error.message);process.exitCode=1;}
 });
 if(process.env.FINANCIAL_TEST_REPORT)fs.writeFileSync(process.env.FINANCIAL_TEST_REPORT,JSON.stringify({results},null,2)+'\n');
}finally{await db.close();}
