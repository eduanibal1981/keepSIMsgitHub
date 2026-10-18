import {runScheduleHTTP} from './schedule-http.mjs';
import {runScheduleConcurrency} from './schedule-concurrency.mjs';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {bootstrap} from './bootstrap.mjs';
const read=p=>fs.readFileSync(new URL('../../'+p,import.meta.url),'utf8');
const {default:EmbeddedPostgres}=await import(process.env.EMBEDDED_POSTGRES_MODULE_PATH?pathToFileURL(process.env.EMBEDDED_POSTGRES_MODULE_PATH).href:'embedded-postgres');
const directory=fs.mkdtempSync(path.join(os.tmpdir(),'keepsims-schedule-'));
const server=new EmbeddedPostgres({databaseDir:directory,user:'postgres',password:'isolated-test',port:Number(process.env.SCHEDULE_TEST_PORT||56558),persistent:false,
  initdbFlags:['--locale=C'],postgresFlags:['-h','127.0.0.1','-k',directory],onLog:()=>{},onError:()=>{}});
let db; let failed=false; const results=[];
try{
 await server.initialise();await server.start();db=server.getPgClient();await db.connect();
 await bootstrap({exec:s=>db.query(s),query:(s,p)=>db.query(s,p)});
 await db.query(read('supabase/tests/fixtures/pricing_contract_baseline.sql'));
 await db.query(read('supabase/tests/fixtures/retail_ownership_baseline.sql'));
 await db.query(read('supabase/migrations/20261018050000_unified_pricing_entitlement.sql'));
 await db.query(read('supabase/migrations/20261018060000_retail_ownership_contract.sql'));
 await db.query(read('supabase/tests/fixtures/schedule_mutation_baseline.sql'));
 await db.query(read('supabase/tests/schedule_mutation_contract_tests.sql').split('-- CASE:')[0]);
 await db.query(read('supabase/tests/fixtures/schedule_mutation_legacy_seed.sql'));
 await db.query(read('supabase/migrations/20261018070000_scheduled_pricing_boundary.sql'));
 console.log('PASS actual forward migration on production-shaped dependencies');
 const chunks=read('supabase/tests/schedule_mutation_contract_tests.sql').split('-- CASE:');
 const cases=chunks.slice(1);
 for(const block of cases){const name=block.slice(0,block.indexOf('\n')).trim();await db.query('BEGIN');
  try{await db.query(block.slice(block.indexOf('\n')));results.push({name,status:'passed'});console.log('PASS '+name);}
  catch(e){results.push({name,status:'failed',message:e.message,code:e.code});console.error('FAIL '+name+': '+e.message+' '+(e.where||''));}
  finally{await db.query('ROLLBACK');}
 }
 await runScheduleConcurrency(server,db,async(name,body)=>{try{await body();results.push({name,status:'passed'});console.log('PASS '+name);}catch(e){results.push({name,status:'failed',message:e.message});console.error('FAIL '+name+': '+e.message);}});
 if(process.env.POSTGREST_BINARY)await runScheduleHTTP(db,async(name,body)=>{try{await body();results.push({name,status:'passed'});console.log('PASS '+name);}catch(e){results.push({name,status:'failed',message:e.message});console.error('FAIL '+name+': '+e.message);}});
 if(results.some(r=>r.status==='failed'))failed=true;
} catch(e){console.error(e.message,e.code,e.where||'',e.position||'');failed=true;}
finally{
 if(db)await db.end();await server.stop();fs.rmSync(directory,{recursive:true,force:true});
 console.log(JSON.stringify({passed:results.filter(r=>r.status==='passed').length,failed:results.filter(r=>r.status==='failed').length}));
 if(process.env.SCHEDULE_TEST_REPORT)fs.writeFileSync(process.env.SCHEDULE_TEST_REPORT,JSON.stringify({environment:'isolated native PostgreSQL',results},null,2)+'\n');
}

// embedded-postgres cleanup resets exitCode; set it after stopping the server.
process.exit(failed ? 1 : 0);
