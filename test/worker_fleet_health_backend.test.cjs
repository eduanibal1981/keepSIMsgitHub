const {test}=require('node:test');
const assert=require('node:assert/strict');
const {loadEdge}=require('./edge_module_loader.cjs');
const {createHealthHandler}=loadEdge('supabase/functions/health/handler.ts');
const request=()=>new Request('https://health.invalid');
function fixture(result={data:{manifest_version:1,status:'healthy',healthy:52,unhealthy:0}}){
 const calls=[];
 return {calls,handler:createHealthHandler(()=>({async rpc(name){calls.push(name);return result;}}),key=>({SUPABASE_URL:'https://db.invalid',SUPABASE_SERVICE_ROLE_KEY:'private-service-key'})[key])};
}
test('health uses the full service-only fleet contract',async()=>{
 const f=fixture();const r=await f.handler(request());assert.equal(r.status,200);assert.deepEqual(f.calls,['get_worker_fleet_health']);
 const b=await r.json();assert.equal(b.status,'healthy');assert.deepEqual(b.fleet,{healthy:52,unhealthy:0});assert.equal(r.headers.get('Cache-Control'),'no-store');
});
test('a partial fleet failure returns 503 while database remains online',async()=>{
 const f=fixture({data:{manifest_version:1,status:'degraded',healthy:51,unhealthy:1,components:[{backlog:77,version:'private-version',key:'private-queue'}]}});
 const r=await f.handler(request());assert.equal(r.status,503);const text=await r.text();assert.ok(text.includes('degraded'));assert.doesNotMatch(text,/private-|backlog|version|components/);
});
test('database errors are sanitized and cannot produce a healthy response',async()=>{
 const r=await fixture({data:null,error:{message:'private-token private-phone'}}).handler(request());assert.equal(r.status,503);assert.doesNotMatch(await r.text(),/private-/);
});
test('unconfigured health fails closed before creating a client',async()=>{
 const h=createHealthHandler(()=>{throw Error('Should not initialize');},()=>undefined);const r=await h(request());assert.equal(r.status,503);
});
for(const data of [null,{manifest_version:1,status:'healthy',healthy:1,unhealthy:0},
 {manifest_version:1,status:'healthy',healthy:50,unhealthy:1},
 {manifest_version:1,status:'degraded',healthy:50,unhealthy:0},
 {manifest_version:1,status:'healthy',healthy:-5,unhealthy:0}]){
 test('inconsistent health contract fails closed: '+JSON.stringify(data),async()=>{
  const r=await fixture({data}).handler(request());assert.equal(r.status,503);assert.equal((await r.json()).status,'unhealthy');
 });
}
test('public health only accepts GET and preflight OPTIONS',async()=>{
 const f=fixture();assert.equal((await f.handler(new Request('https://health.invalid',{method:'OPTIONS'}))).status,200);
 assert.equal((await f.handler(new Request('https://health.invalid',{method:'POST'}))).status,405);assert.equal(f.calls.length,0);
});
