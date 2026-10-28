import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import net from 'node:net';
import {randomUUID} from 'node:crypto';
import EmbeddedPostgres from 'embedded-postgres';
import {createFixture,owner,other} from './esim-settlement-fixture.mjs';
const port=await new Promise(resolve=>{const s=net.createServer();s.listen(0,'127.0.0.1',()=>{const p=s.address().port;s.close(()=>resolve(p));});});
const dir=await fs.mkdtemp(path.join(os.tmpdir(),'keepsims-esim08-native-'));
const server=new EmbeddedPostgres({databaseDir:dir,user:'postgres',password:randomUUID(),port,persistent:false,
 initdbFlags:['--locale=C'],postgresFlags:['-h','127.0.0.1','-k','/tmp'],onLog(){},onError(){}});
const clients=[];
const connect=async()=>{const c=server.getPgClient();await c.connect();clients.push(c);return c;};
const scalar=async(c,s,p=[])=>Object.values((await c.query(s,p)).rows[0])[0];
const auth=async(c,u=owner)=>{await c.query('SET ROLE authenticated');await c.query("select set_config('request.jwt.claim.role','authenticated',false),set_config('request.jwt.claim.sub',$1,false),set_config('request.jwt.claims',$2,false)",[u,JSON.stringify({role:'authenticated',sub:u,session_id:u})]);};
const service=async c=>{await c.query('RESET ROLE');await c.query("select set_config('request.jwt.claim.role','service_role',false),set_config('request.jwt.claim.sub','',false),set_config('request.jwt.claims','{\"role\":\"service_role\"}',false)");};
try {
 await server.initialise();await server.start();const c=await connect(),a=await connect(),b=await connect();
 const f=await createFixture({exec:s=>c.query(s),query:(s,p)=>c.query(s,p),close:async()=>{}});await f.enable();const quote=await f.makeQuote();
 await auth(a);await auth(b);
 const accepted=await Promise.all([a,b].map(client=>scalar(client,'select accept_esim_topup($1,$2)',[quote.quote_id,quote.acceptance_key])));
 assert.equal(accepted[0].order_id,accepted[1].order_id);await f.service();
 assert.equal(Number(await scalar(c,'select count(*) from wallet_holds')),1);
 console.log('PASS concurrent taps adopt one durable order and one reservation');
 const job=await f.claim();assert.equal(await f.submit(job),true);const receipt=f.receipt(job);await f.record(job,receipt);
 await service(a);await service(b);
 const settled=await Promise.all([a,b].map(client=>scalar(client,'select service_esim_settle_topup($1)',[job.order_id])));
 assert(settled.every(x=>x.completed));assert.equal(Number(await scalar(c,"select count(*) from wallet_transactions where type='esim_recharge_debit'")),1);
 assert.equal(Number(await scalar(c,'select balance from wallets where user_id=$1',[owner])),18.27);
 console.log('PASS concurrent recovery captures once, records one entitlement, and preserves other funds');
 assert.equal(Number(await scalar(c,'select count(*) from esim_private.entitlements')),1);
 assert.equal(Number(await scalar(c,'select drift from wallet_reconciliation where user_id=$1',[owner])),0);
 console.log('PASS native PostgreSQL ledger reconciliation includes recharge settlement');
 await f.user(other);assert.deepEqual(await f.one('select get_esim_operation_history($1) v',[f.profile]),[]);
 console.log('PASS native non-owner operation reads return no receipt');
 await f.user();assert.equal(Number(await scalar(c,'select count(*) from public.customer_esim_orders')),1);
 await f.user(other);assert.equal(Number(await scalar(c,'select count(*) from public.customer_esim_orders')),0);
 console.log('PASS native customer order view enforces owner RLS after replacement');
 console.log('5 native ESIM-08 concurrency/boundary groups passed');
} finally {
 for(const c of clients)await c.end().catch(()=>{});
 await server.stop().catch(()=>{});await fs.rm(dir,{recursive:true,force:true});
}
