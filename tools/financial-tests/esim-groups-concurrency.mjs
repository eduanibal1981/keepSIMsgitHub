import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import net from 'node:net';
import {randomUUID} from 'node:crypto';
import EmbeddedPostgres from 'embedded-postgres';
import {createGroupsFixture,owner,other} from './esim-groups-fixture.mjs';
const port=await new Promise(resolve=>{const s=net.createServer();s.listen(0,'127.0.0.1',()=>{const p=s.address().port;s.close(()=>resolve(p));});});
const dir=await fs.mkdtemp(path.join(os.tmpdir(),'keepsims-groups-native-'));
const server=new EmbeddedPostgres({databaseDir:dir,user:'postgres',password:randomUUID(),port,persistent:false,
 initdbFlags:['--locale=C'],postgresFlags:['-h','127.0.0.1','-k','/tmp'],onLog(){},onError(){}});
const clients=[];
const connect=async()=>{const c=server.getPgClient();await c.connect();clients.push(c);return c;};
const scalar=async(c,s,p=[])=>Object.values((await c.query(s,p)).rows[0])[0];
const auth=async(c,u=owner)=>{await c.query('SET ROLE authenticated');await c.query("select set_config('request.jwt.claim.role','authenticated',false),set_config('request.jwt.claim.sub',$1,false),set_config('request.jwt.claims',$2,false)",[u,JSON.stringify({role:'authenticated',sub:u,session_id:u})]);};
const service=async c=>{await c.query('RESET ROLE');await c.query("select set_config('request.jwt.claim.role','service_role',false),set_config('request.jwt.claim.sub','',false),set_config('request.jwt.claims','{\"role\":\"service_role\"}',false)");};
try{
 await server.initialise();await server.start();const c=await connect(),a=await connect(),b=await connect();
 const f=await createGroupsFixture({exec:s=>c.query(s),query:(s,p)=>c.query(s,p),close:async()=>{}});
 await c.query('update esim_private.accounts set new_sales_enabled=true,wallet_boundary_verified=true,group_orders_enabled=true');
 await c.query(`insert into esim_offers_cache(provider,bundle_name,description,countries,data_amount_mb,duration_days,wholesale_price_usd,is_active,catalogue_details) values('esimaccess','GROUP_NATIVE','Native fixture',ARRAY['OM'],1024,7,1,true,'{"plan_type":"total","allowance_bytes":"1073741824","duration_value":7,"duration_unit":"DAY"}')`);
 const members=JSON.stringify([{offer_id:'GROUP_NATIVE',traveller_label:'A'},{offer_id:'GROUP_NATIVE',traveller_label:'B'}]);
 await f.user();const quote=await scalar(c,"select quote_esim_group('Trip',$1)",[members]),key=randomUUID();
 await auth(a);await auth(b);const accepted=await Promise.all([a,b].map(client=>scalar(client,'select accept_esim_group($1,$2,$3)',[quote.quote_id,quote.acceptance_key,key])));
 assert.equal(accepted[0].batch_id,accepted[1].batch_id);await f.service();assert.equal(Number(await scalar(c,'select count(*) from wallet_holds')),2);
 console.log('PASS native concurrent taps adopt one parent, two children and two reservations');
 await service(a);await service(b);const jobs=await Promise.all([a,b].map(client=>scalar(client,'select service_esim_claim_order()')));assert.equal(new Set(jobs.map(x=>x.order_id)).size,2);assert(jobs.every(j=>j.quantity===1&&j.group_batch_id===accepted[0].batch_id));
 console.log('PASS independent workers lease distinct child operations without duplicate issuance');
 await Promise.all(jobs.map((j,i)=>scalar(i?a:b,"select service_esim_fail_before_submit($1,$2,'COMPATIBILITY_CHANGED')",[j.order_id,j.lease])));
 await f.user();const first=await scalar(c,"select quote_esim_group('Trip one',$1)",[members]),second=await scalar(c,"select quote_esim_group('Trip two',$1)",[members]);await f.service();await c.query('update wallets set balance=4 where user_id=$1',[owner]);
 await auth(a);await auth(b);const competing=await Promise.all([scalar(a,'select accept_esim_group($1,$2,$3)',[first.quote_id,first.acceptance_key,randomUUID()]),scalar(b,'select accept_esim_group($1,$2,$3)',[second.quote_id,second.acceptance_key,randomUUID()])]);assert.equal(competing.filter(x=>x.status==='ACCEPTED').length,1);assert.equal(competing.filter(x=>x.status==='BALANCE_UNAVAILABLE').length,1);
 await f.service();assert.equal(Number(await scalar(c,"select sum(amount) from wallet_holds where status='active'")),3);
 console.log('PASS competing group orders cannot spend another group reservation');
 await auth(a,other);const hidden=await scalar(a,'select get_esim_organization($1)',[accepted[0].batch_id]);assert.deepEqual(hidden.groups,[]);assert.deepEqual(hidden.labels,[]);
 console.log('PASS native non-owner and potential manager receive no group or label access');
}finally{for(const c of clients)await c.end().catch(()=>{});await server.stop().catch(()=>{});await fs.rm(dir,{recursive:true,force:true});}
