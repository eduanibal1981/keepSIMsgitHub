import assert from 'node:assert/strict';
export async function runCallsHTTP({client,rpc},check){
 const u=crypto.randomUUID(),session=crypto.randomUUID();
 await client.query('INSERT INTO auth.users(id,email) VALUES($1,$2)',[u,u+'@fixture.test']);
 await client.query('INSERT INTO public.profiles(id,email) VALUES($1,$2)',[u,u+'@fixture.test']);
 await client.query("INSERT INTO public.call_rates(country_code,country_name,phone_prefix,cost_per_minute_usd,rate_per_minute_usd,billing_increment_seconds) VALUES('http-call','Fixture','+198765',0,1,60)");
 await client.query("INSERT INTO public.call_media_sessions(id,user_id,credential_id,sip_username,expires_at) VALUES($1,$2,'synthetic','synthetic',now()+interval '5 minutes')",[session,u]);
 await client.query('SELECT public.ensure_wallet_v2($1)',[u]);
 await client.query("SELECT public.credit_wallet_for_deposit($1::uuid,60,'fixture',$2,jsonb_build_object('paypal_capture_id',$1::text))",[u,'paypal_'+u]);
 const args={p_user_id:u,p_media_session_id:session,p_request:{destination_number:'+19876543210',effective_caller_id:'+15550001111',requested_caller_id:'+15550001111',caller_id_type:'gateway',idempotency_key:crypto.randomUUID()}};
 let call;
 await check('call HTTP named preparation adopts one reservation and clients cannot reserve',async()=>{
  for(const role of [null,'authenticated'])assert.ok([401,403,404].includes((await rpc('prepare_budgeted_media_call',args,role)).status));
  const response=await rpc('prepare_budgeted_media_call',args);assert.equal(response.status,200,JSON.stringify(response));call=response.body.call;assert.equal(call.max_duration_seconds,300);assert.equal(Number(call.reserved_budget_usd),5);
  const retry=await rpc('prepare_budgeted_media_call',args);assert.equal(retry.status,200);assert.equal(retry.body.created,false);assert.equal(retry.body.call.id,call.id);
 });
 if(!call)return;
 await check('call HTTP durable submission/evidence/settlement payloads resolve and capture once',async()=>{
  const start=await rpc('begin_media_call_leg',{p_call_id:call.id,p_leg:'app'});assert.equal(start.status,200,JSON.stringify(start));assert.equal(start.body.dispatch,true);
  assert.equal((await rpc('begin_media_call_leg',{p_call_id:call.id,p_leg:'app'})).body.dispatch,false);
  const at=s=>new Date(new Date(call.started_at).getTime()+s*1000).toISOString();
  async function evidence(leg,event,seconds,payload={}){
   const res=await rpc('record_media_call_evidence',{p_call_id:call.id,p_leg:leg,p_event_type:event,p_occurred_at:at(seconds),p_payload:{call_control_id:'http-'+leg,...payload}});assert.equal(res.status,204,JSON.stringify(res));
  }
  await evidence('app','command.accepted',1);
  await client.query('UPDATE public.call_media_sessions SET app_answered=true,media_ready=true WHERE call_record_id=$1',[call.id]);
  assert.equal((await rpc('begin_media_call_leg',{p_call_id:call.id,p_leg:'destination'})).body.dispatch,true);
  await evidence('destination','call.bridged',2);
  await evidence('destination','call.hangup',62,{hangup_cause:'normal_clearing'});
  const finish={p_call_id:call.id,p_ended_at:at(62),p_status:'completed',p_error:null,p_payload:{call_control_id:'http-destination',hangup_cause:'normal_clearing'}};
  for(const role of [null,'authenticated'])assert.ok([401,403,404].includes((await rpc('finish_media_call',finish,role)).status));
  for(let i=0;i<2;i++){const res=await rpc('finish_media_call',finish);assert.equal(res.status,204,JSON.stringify(res));}
  const row=(await client.query('SELECT balance FROM public.wallets WHERE user_id=$1',[u])).rows[0];assert.equal(Number(row.balance),59);
 });
}
