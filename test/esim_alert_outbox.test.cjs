const test=require('node:test');const assert=require('node:assert/strict');
const {loadEdge,builder}=require('./edge_module_loader.cjs');
function fixture({current=true,enabled=true,quiet=false,owner='owner',event='esim_low_data',globalPush=true}={}) {
 let handler;const calls=[],requests=[];
 const job={id:'job',notification_id:'notice',attempt_count:1,payload:{user_id:'owner',category:'esim_low_data',
  event_type:event,channels:['push','telegram','email'],notification_id:'notice'}};
 const db={rpc:async(name,args)=>{calls.push([name,args]);return {data:name==='claim_notification_dispatch_jobs'?[job]
  :name==='service_esim_alert_is_current'?current:true};},from:table=>builder(()=>({data:{
   notifications:{id:'notice',user_id:owner,category:'esim_low_data'},
   alert_settings:{is_enabled:enabled,channels:['push','telegram','email']},
   notification_channels:[{channel_type:'push',is_enabled:true},{channel_type:'telegram',is_enabled:true},{channel_type:'email',is_enabled:true}],
   notification_channel_catalog:[{channel_key:'push',is_globally_enabled:globalPush},{channel_key:'telegram',is_globally_enabled:true},{channel_key:'email',is_globally_enabled:true}],
   user_preferences:quiet?{quiet_hours_start:`${new Date().getUTCHours()}:00`,quiet_hours_end:`${(new Date().getUTCHours()+1)%24}:00`,notification_timezone:'UTC'}:null,
  }[table]}))};
 loadEdge('supabase/functions/process-alert-outbox/index.ts',{
  serve:fn=>handler=fn,createClient:()=>db,env:{SUPABASE_URL:'https://fixture.invalid',SUPABASE_SERVICE_ROLE_KEY:'fixture'},
  fetch:async(url,options)=>{requests.push(JSON.parse(options.body));return Response.json({success:true});},
 });
 return {calls,requests,run:async()=> (await handler(new Request('https://fixture.invalid',{headers:{Authorization:'Bearer fixture'}}))).json()};
}
test('current eSIM events dispatch through the existing queue using push only',async()=>{
 const f=fixture();assert.equal((await f.run()).outcomes.complete,1);assert.deepEqual(f.requests[0].channels,['push']);
 assert(f.calls.some(([n])=>n==='service_esim_alert_is_current'));
});
test('recovered usage, old cycles and stale observations cancel delayed eSIM push',async()=>{
 const f=fixture({current:false});assert.equal((await f.run()).outcomes.canceled,1);assert.equal(f.requests.length,0);
});
test('saved category opt-out is rechecked before sending',async()=>{
 const f=fixture({enabled:false});assert.equal((await f.run()).outcomes.canceled,1);assert.equal(f.requests.length,0);
});
test('ownership mismatch cancels without sending',async()=>{
 const f=fixture({owner:'other'});assert.equal((await f.run()).outcomes.canceled,1);assert.equal(f.requests.length,0);
});
test('quiet hours defer eSIM updates in the saved IANA timezone',async()=>{
 const f=fixture({quiet:true});assert.equal((await f.run()).outcomes.deferred,1);assert.equal(f.requests.length,0);
 assert(f.calls.some(([n])=>n==='defer_notification_dispatch_job'));
});
test('globally disabled push cannot fall through to email or Telegram',async()=>{
 const f=fixture({globalPush:false});assert.equal((await f.run()).outcomes.canceled,1);assert.equal(f.requests.length,0);
});
test('non-eSIM events retain their original enabled channels',async()=>{
 const f=fixture({event:'other_event'});await f.run();assert.deepEqual(f.requests[0].channels,['push','telegram','email']);
 assert(!f.calls.some(([n])=>n==='service_esim_alert_is_current'));
});
