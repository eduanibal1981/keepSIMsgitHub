const test=require('node:test');const assert=require('node:assert/strict');const fs=require('node:fs');
const source=fs.readFileSync('supabase/functions/_shared/esimaccess-events.js','utf8');
const imported=import('data:text/javascript;base64,'+Buffer.from(source).toString('base64'));
const secret='fixture-event-secret-which-is-more-than-32-characters';
const payload={notifyType:'ORDER_STATUS',content:{orderNo:'FIXTURE_ORDER',transactionId:'fixture-intent',ac:'PRIVATE_ACTIVATION',eid:'PRIVATE_EID'}};
const request=(body=payload,headers={},url='https://fixture.invalid/events')=>new Request(url,{method:'POST',headers:{'content-type':'application/json','x-esimaccess-event-secret':secret,...headers},body:typeof body==='string'?body:JSON.stringify(body)});
test('missing/invalid secrets cause no event persistence, including URL tokens',async()=>{
 const {createEsimEventHandler}=await imported;let writes=0;
 const handler=createEsimEventHandler({getSecret:async()=>secret,acceptEvent:async()=>{writes++;return {accepted:true};}});
 for(const value of ['', 'wrong'])assert.equal((await handler(request(payload,{'x-esimaccess-event-secret':value}))).status,403);
 assert.equal((await handler(request(payload,{'x-esimaccess-event-secret':''},'https://fixture.invalid/events?token='+secret))).status,403);
 assert.equal(writes,0);
});
test('durable acknowledgment stores only minimized hints, not activation or usage fields',async()=>{
 const {createEsimEventHandler}=await imported;const accepted=[];
 const handler=createEsimEventHandler({getSecret:async()=>secret,acceptEvent:async(key,event)=>{accepted.push([key,event]);return {accepted:true};}});
 assert.equal((await handler(request())).status,202);
 assert.equal((await handler(request({content:payload.content,notifyType:'ORDER_STATUS'}))).status,202);
 assert.equal(accepted[0][0],accepted[1][0]);assert(!JSON.stringify(accepted).includes('PRIVATE_ACTIVATION'));assert(!JSON.stringify(accepted).includes('PRIVATE_EID'));
 assert.equal(accepted[0][1].order_ref,'FIXTURE_ORDER');
});
test('unknown event families, missing references, oversized and malformed bodies are rejected',async()=>{
 const {createEsimEventHandler}=await imported;let writes=0;const handler=createEsimEventHandler({getSecret:async()=>secret,acceptEvent:async()=>{writes++;}});
 assert.equal((await handler(request({notifyType:'UNKNOWN',content:{orderNo:'A'}}))).status,422);
 assert.equal((await handler(request({notifyType:'ESIM_STATUS',content:{}}))).status,422);
 assert.equal((await handler(request('{'))).status,400);
 assert.equal((await handler(request('x'.repeat(17000)))).status,413);
 assert.equal(writes,0);
});
test('missing authentication configuration and persistence failure fail closed',async()=>{
 const {createEsimEventHandler}=await imported;
 assert.equal((await createEsimEventHandler({getSecret:async()=>null})(request())).status,503);
 assert.equal((await createEsimEventHandler({getSecret:async()=>secret,acceptEvent:async()=>{throw new Error('PRIVATE');}})(request())).status,503);
 assert.equal((await createEsimEventHandler({getSecret:async()=>secret,acceptEvent:async()=>({rate_limited:true})})(request())).status,429);
});
