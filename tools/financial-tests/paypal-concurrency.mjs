// Real independent local PostgreSQL sessions; no external payment/network calls.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {bootstrapPayPal,seedPayPal,evidence,user} from './paypal-bootstrap.mjs';
const {default:EmbeddedPostgres}=await import(process.env.EMBEDDED_POSTGRES_MODULE_PATH?pathToFileURL(process.env.EMBEDDED_POSTGRES_MODULE_PATH).href:'embedded-postgres');
const directory=await fs.mkdtemp(path.join(os.tmpdir(),'keepsims-paypal-postgres-'));
const server=new EmbeddedPostgres({databaseDir:directory,user:'postgres',password:'isolated-test',port:Number(process.env.PAYPAL_TEST_PORT||56545),
  persistent:false,initdbFlags:['--locale=C'],postgresFlags:['-h','127.0.0.1',...(process.platform==='win32'?[]:['-k',directory])],onLog:()=>{},onError:()=>{}});
const clients=[];
async function connect(name){const c=server.getPgClient(name);await c.connect();clients.push(c);return c;}
const fulfill=async(c,data=evidence(),order='ORDER0001')=>(await c.query('select public.fulfill_paypal_capture($1,$2::jsonb) as result',[order,JSON.stringify(data)])).rows[0].result;
try{
  await server.initialise();await server.start();const admin=await connect();
  for(const mode of ['live','m2']){
    const name='paypal_'+mode;await admin.query('CREATE DATABASE '+name);const owner=await connect(name);
    // Roles are cluster-global; omit their repeated declaration for the second database.
    await bootstrapPayPal(sql=>owner.query(mode==='m2'?sql.replace('CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role BYPASSRLS;',''):sql),mode);
    await seedPayPal((sql,args)=>owner.query(sql,args));const a=await connect(name),b=await connect(name);
    for(const c of [a,b]){await c.query('SET ROLE service_role');await c.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({role:'service_role'})]);}
    const results=await Promise.all([fulfill(a),fulfill(b,evidence({source:'webhook'}))]);
    assert.ok(results.every(r=>r.success));assert.equal(results.filter(r=>r.duplicate).length,1);
    const counts=(await owner.query(`select (select count(*) from public.wallet_transactions)::int as ledger,
      (select count(*) from public.wallet_funding_lots)::int as lots,(select count(*) from public.paypal_capture_receipts)::int as receipts,
      (select balance from public.wallets where user_id='${user}')::text as balance`)).rows[0];
    assert.deepEqual(counts,{ledger:1,lots:1,receipts:1,balance:'10.00'});
    console.log('PASS '+mode+': concurrent client/webhook fulfillment commits one credit, receipt and lot');
    const conflict=await Promise.allSettled([fulfill(a,evidence({capture_id:'CAPTURE002'})),fulfill(b,evidence({capture_id:'CAPTURE003'}))]);
    assert.ok(conflict.every(r=>r.status==='rejected'));console.log('PASS '+mode+': competing capture IDs cannot fulfill the same order again');
  }
}finally{await Promise.allSettled(clients.map(c=>c.end()));await server.stop();await fs.rm(directory,{recursive:true,force:true});}
