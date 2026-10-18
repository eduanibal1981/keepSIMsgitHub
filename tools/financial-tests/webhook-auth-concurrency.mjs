// Local independent PostgreSQL sessions exercise claim races, never production.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
const { default: EmbeddedPostgres } = await import(process.env.EMBEDDED_POSTGRES_MODULE_PATH
  ? pathToFileURL(process.env.EMBEDDED_POSTGRES_MODULE_PATH).href : 'embedded-postgres');
const directory=await fs.mkdtemp(path.join(os.tmpdir(),'keepsims-webhook-postgres-'));
const server=new EmbeddedPostgres({databaseDir:directory,user:'postgres',password:'isolated-test',
  port:Number(process.env.WEBHOOK_TEST_PORT||56544),persistent:false,initdbFlags:['--locale=C'],
  postgresFlags:['-h','127.0.0.1',...(process.platform==='win32'?[]:['-k',directory])],onLog:()=>{},onError:()=>{}});
const clients=[];
async function connect(){const client=server.getPgClient();await client.connect();clients.push(client);return client;}
const read=p=>fs.readFile(new URL('../../'+p,import.meta.url),'utf8');
const claim=async(c,event,resource='resource')=>(await c.query('select public.claim_verified_webhook($1,$2,$3,$4) as result',
  ['telnyx',event,resource,'a'.repeat(64)])).rows[0].result;
try{
  await server.initialise();await server.start();
  const owner=await connect(),a=await connect(),b=await connect();
  await owner.query(await read('supabase/tests/fixtures/endpoint_webhook_authentication.sql'));
  await owner.query(await read('supabase/migrations/20261017100000_endpoint_webhook_authentication.sql'));
  for(const c of [a,b]){
    await c.query('SET ROLE service_role');
    await c.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({role:'service_role'})]);
  }
  const same=await Promise.all([claim(a,'same'),claim(b,'same')]);
  assert.deepEqual(same.map(x=>x.state).sort(),['busy','claimed']);
  const token=same.find(x=>x.state==='claimed').token;
  await a.query('select public.finish_verified_webhook($1,$2,$3,true)',['telnyx','same',token]);
  assert.equal((await claim(b,'same')).state,'completed');
  console.log('PASS concurrent same-event delivery and completion admit one processor');
  const distinct=await Promise.all([claim(a,'event-a','shared'),claim(b,'event-b','shared')]);
  assert.deepEqual(distinct.map(x=>x.state).sort(),['busy','claimed']);
  console.log('PASS distinct events for one resource serialize across independent sessions');
  const independent=await Promise.all([claim(a,'event-c','one'),claim(b,'event-d','two')]);
  assert.ok(independent.every(x=>x.state==='claimed'));
  console.log('PASS independent resources process concurrently');
}finally{
  await Promise.allSettled(clients.map(c=>c.end()));await server.stop();await fs.rm(directory,{recursive:true,force:true});
}
