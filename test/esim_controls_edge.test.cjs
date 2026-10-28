const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs');
const source=fs.readFileSync('supabase/functions/_shared/esim-recharge-discovery.js','utf8');
const modulePromise=import('data:text/javascript;base64,'+Buffer.from(source).toString('base64'));
const id='10000000-0000-4000-8000-000000000001';
async function send(body,auth=true){const calls=[];const {createRechargeHandler}=await modulePromise;const h=createRechargeHandler({authenticate:async()=>auth?{}:null,call:async(c,n,p)=>{calls.push([n,p]);return {data:{status:'OK'}};}});const r=await h(new Request('https://fixture.invalid',{method:'POST',headers:{authorization:'Bearer fixture'},body:JSON.stringify(body)}));return {r,calls};}
test('control endpoint dispatches owner JWT with no supplied payer or provider',async()=>{const {r,calls}=await send({action:'control',profile_id:id,request_key:id,control:'suspend'});assert.equal(r.status,200);assert.equal(calls[0][0],'request_esim_control');});
test('revoke and financial injection refused',async()=>{for(const body of [{action:'control',profile_id:id,request_key:id,control:'revoke'},{action:'control',profile_id:id,request_key:id,control:'cancel',refund_amount:100},{action:'set_automation',profile_id:id,expected_revision:0,enabled:true,payer_id:id}]){assert.equal((await send(body)).r.status,400);}});
test('unauthenticated controls denied',async()=>{assert.equal((await send({action:'controls',profile_id:id},false)).r.status,401);});
test('pause requires a consent revision and strict boolean',async()=>{assert.equal((await send({action:'set_automation',profile_id:id,expected_revision:2,enabled:false})).calls[0][0],'set_esim_automation');assert.equal((await send({action:'set_automation',profile_id:id,expected_revision:2,enabled:'false'})).r.status,400);});
