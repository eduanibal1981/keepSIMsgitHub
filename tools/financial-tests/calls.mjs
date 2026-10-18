// Task 13: real financial constraints/functions; synthetic media/provider evidence.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';
import { bootstrap } from './bootstrap.mjs';
const {PGlite}=await import(process.env.PGLITE_MODULE_PATH?pathToFileURL(process.env.PGLITE_MODULE_PATH).href:'@electric-sql/pglite');
export async function runCalls({owner,one=owner,two=owner},check){
  assert.deepEqual((await owner.query(fs.readFileSync(new URL('../../supabase/tests/call_budget_contract_tests.sql',import.meta.url),'utf8'))).rows,[]);
  const scalar=async(c,sql,args=[])=>Object.values((await c.query(sql,args)).rows[0])[0];
  async function role(c,r='service_role',sub=null){await c.query('RESET ROLE');if(r!=='none')await c.query('SET ROLE '+r);await c.query("SELECT set_config('request.jwt.claims',$1,false)",[JSON.stringify({role:r,sub})]);}
  async function oq(sql,args=[]){await role(owner,'none');return owner.query(sql,args);}
  let n=0;
  async function seed({balance=60,rate=1,increment=60}={}){
    const u=crypto.randomUUID(),session=crypto.randomUUID(),prefix='+1900'+String(++n).padStart(4,'0');
    await oq('INSERT INTO auth.users(id,email) VALUES($1,$2)',[u,u+'@fixture.test']);
    await oq('INSERT INTO public.profiles(id,email) VALUES($1,$2)',[u,u+'@fixture.test']);
    await oq("INSERT INTO public.call_rates(country_code,country_name,phone_prefix,cost_per_minute_usd,rate_per_minute_usd,billing_increment_seconds) VALUES($1,'Fixture',$2,0,$3,$4)",[prefix,prefix,rate,increment]);
    await oq("INSERT INTO public.call_media_sessions(id,user_id,credential_id,sip_username,expires_at) VALUES($1,$2,'synthetic','synthetic',now()+interval '5 minutes')",[session,u]);
    await role(one);await one.query('SELECT public.ensure_wallet_v2($1)',[u]);
    if(balance)await one.query("SELECT public.credit_wallet_for_deposit($1::uuid,$2,'fixture',$3,jsonb_build_object('paypal_capture_id',$1::text))",[u,balance,'paypal_'+u]);
    return{u,session,request:{idempotency_key:crypto.randomUUID(),destination_number:prefix+'1111',effective_caller_id:'+15550001111',requested_caller_id:'+15550001111',caller_id_type:'gateway'}};
  }
  async function prepare(f,c=one){await role(c);return scalar(c,'SELECT public.prepare_budgeted_media_call($1,$2,$3)',[f.u,f.request,f.session]);}
  async function row(id){return(await oq('SELECT * FROM public.call_records WHERE id=$1',[id])).rows[0];}
  async function begin(r,leg,c=one){await role(c);return scalar(c,'SELECT public.begin_media_call_leg($1,$2)',[r.id,leg]);}
  async function evidence(r,leg,type,seconds=1,extra={},c=one){await role(c);const at=new Date(new Date(r.started_at).getTime()+seconds*1000).toISOString();const payload={call_control_id:leg+'-'+r.id,...extra};await c.query('SELECT public.record_media_call_evidence($1,$2,$3,$4,$5)',[r.id,leg,type,at,payload]);return{at,payload};}
  async function connected(f){const {call:r}=await prepare(f);assert.equal((await begin(r,'app')).dispatch,true);await evidence(r,'app','call.initiated');await oq('UPDATE public.call_media_sessions SET app_answered=true,media_ready=true WHERE call_record_id=$1',[r.id]);assert.equal((await begin(r,'destination')).dispatch,true);await evidence(r,'destination','call.initiated');return r;}
  async function finish(r,terminal,c=one){await role(c);return c.query('SELECT public.finish_media_call($1,$2,$3,NULL,$4)',[r.id,terminal.at,'failed',terminal.payload]);}
  async function balance(f){return Number(await scalar(owner,'SELECT balance FROM public.wallets WHERE user_id=$1',[f.u]));}
  await check('call budget APIs deny anonymous, ordinary, foreign and power-user clients',async()=>{
    const f=await seed();
    for(const r of ['anon','authenticated']){
      await role(one,r,crypto.randomUUID());
      for(const sig of ['prepare_budgeted_media_call(uuid,jsonb,uuid)','begin_media_call_leg(uuid,text)','record_media_call_evidence(uuid,text,text,timestamptz,jsonb)','request_media_call_termination(uuid)','finish_media_call(uuid,timestamptz,text,text,jsonb)'])assert.equal(await scalar(one,"SELECT has_function_privilege(current_user,$1,'EXECUTE')",['public.'+sig]),false);
      await assert.rejects(()=>one.query('SELECT public.prepare_budgeted_media_call($1,$2,$3)',[f.u,f.request,f.session]),/permission denied/);
    }
    await one.query("SELECT set_config('request.jwt.claims',$1,false)",[JSON.stringify({role:'authenticated',sub:f.u,app_metadata:{is_power_user:true}})]);
    await assert.rejects(()=>one.query('SELECT public.begin_media_call_leg($1,$2)',[crypto.randomUUID(),'app']),/permission denied/);
    const p=await prepare(f);
    for(const r of ['anon','authenticated']){
      await role(one,r,f.u);
      try { const changed=await one.query('UPDATE public.call_records SET reserved_budget_usd=900 WHERE id=$1',[p.call.id]);assert.equal(changed.rowCount??changed.affectedRows,0); }
      catch(error){assert.match(error.message,/permission denied/);}
    }
    assert.equal(Number((await row(p.call.id)).reserved_budget_usd),5);
  });
  await check('five minutes of funding never authorizes sixty minutes from posted funds',async()=>{
    const f=await seed(),p=await prepare(f);assert.equal(Number(p.call.reserved_budget_usd),5);assert.equal(p.call.max_duration_seconds,300);assert.equal(Number(p.available_balance),55);
    const again=await prepare(f);assert.equal(again.created,false);assert.equal(again.call.id,p.call.id);
    await assert.rejects(()=>prepare({...f,request:{...f.request,destination_number:'+15550009999'}}),/idempotency terms/);
    await assert.rejects(()=>prepare({...f,request:{...f.request,effective_caller_id:'+15550009999'}}),/idempotency terms/);
    await oq('UPDATE public.call_rates SET rate_per_minute_usd=9 WHERE phone_prefix=$1',[f.request.destination_number.slice(0,-4)]);
    assert.equal(Number((await prepare(f)).call.rate_per_minute_usd),1);
  });
  await check('exact fee/increment/cent boundaries use one formula including unanswered and partial calls',async()=>{
    await role(one);
    for(const [rate,fee,inc,seconds,expected] of [[.1,.25,60,0,0],[.1,.25,60,1,.35],[.1,.25,60,60,.35],[.1,.25,60,61,.45],[.009,0,1,1,0],[.009,0,1,34,.01],[.01,0,60,30,.01]]){
      assert.equal(Number(await scalar(one,'SELECT public.media_call_cost($1,$2,$3,$4)',[rate,fee,inc,seconds])),expected);
    }
    for(const args of [[-1,0,60,1],[1,-1,60,1],[1,0,0,1],[1,0,60,-1],['NaN',0,60,1]])await assert.rejects(()=>one.query('SELECT public.media_call_cost($1,$2,$3,$4)',args),/Invalid call pricing/);
    const f=await seed({balance:.15,rate:.1,increment:60}),p=await prepare(f);assert.equal(p.call.max_duration_seconds,60);assert.equal(Number(p.call.reserved_budget_usd),.15);
  });
  await check('owned session and authoritative tariff are required; failures roll back call and hold',async()=>{
    const f=await seed({balance:0});await assert.rejects(()=>prepare(f),/Insufficient/);
    const g=await seed();await assert.rejects(()=>prepare({...g,session:f.session}),/audio session/);
    const h=await seed({increment:0});await assert.rejects(()=>prepare(h),/tariff/);
    const i=await seed();i.request.sim_line_id=crypto.randomUUID();await assert.rejects(()=>prepare(i),/Owned SIM/);
    assert.equal(Number(await scalar(owner,'SELECT count(*) FROM public.call_records WHERE user_id=$1',[g.u])),0);
  });
  await check('answered call settles one increment and ledger/funding/balance agree on the actual debit',async()=>{
    const f=await seed({rate:.1}),r=await connected(f);await evidence(r,'destination','call.bridged',2);
    const terminal=await evidence(r,'destination','call.hangup',3,{hangup_cause:'normal_clearing'});await finish(r,terminal);await finish(r,terminal);
    const saved=await row(r.id);assert.equal(Number(saved.total_cost_usd),.1);assert.equal(saved.duration_seconds,1);assert.equal(saved.billed_duration_seconds,60);assert.equal(await balance(f),59.9);
    assert.equal(Number(await scalar(owner,"SELECT count(*) FROM public.wallet_transactions WHERE user_id=$1 AND type='call_debit'",[f.u])),1);
    assert.equal(Number(await scalar(owner,'SELECT drift FROM public.wallet_reconciliation WHERE user_id=$1',[f.u])),0);
    await owner.query('SELECT public.assert_wallet_funding_integrity((SELECT id FROM public.wallets WHERE user_id=$1))',[f.u]);
  });
  await check('unanswered decline releases its hold once without charging a connection fee',async()=>{
    const f=await seed(),r=await connected(f),terminal=await evidence(r,'destination','call.hangup',3,{sip_hangup_cause:'603'});
    await finish(r,terminal);await finish(r,terminal);assert.equal(await balance(f),60);assert.equal((await row(r.id)).billing_state,'settled');
    assert.equal(await scalar(owner,'SELECT status FROM public.wallet_holds WHERE id=$1',[r.wallet_hold_id]),'released');
  });
  await check('hangup before bridge retains funds then late bridge settles from original provider times',async()=>{
    const f=await seed(),r=await connected(f),terminal=await evidence(r,'destination','call.hangup',62,{hangup_cause:'normal_clearing'});
    await finish(r,terminal);assert.equal((await row(r.id)).billing_state,'reconciliation_required');assert.equal(await balance(f),60);
    await evidence(r,'destination','call.bridged',2);await finish(r,terminal);assert.equal(Number((await row(r.id)).total_cost_usd),1);
  });
  await check('app hangup cannot prematurely release a submitted destination or trigger another dial',async()=>{
    const f=await seed(),r=await connected(f);await evidence(r,'app','call.hangup',3);
    assert.equal((await row(r.id)).billing_state,'termination_pending');assert.equal((await begin(r,'destination')).dispatch,false);
    await assert.rejects(()=>finish(r,{at:new Date(new Date(r.started_at).getTime()+3000).toISOString(),payload:{}}),/Stored destination/);
    assert.equal(await scalar(owner,'SELECT status FROM public.wallet_holds WHERE id=$1',[r.wallet_hold_id]),'active');
  });
  await check('submission markers fence retries and expired/unknown calls keep their holds',async()=>{
    const f=await seed(),{call:r}=await prepare(f);assert.equal((await begin(r,'app')).dispatch,true);assert.equal((await begin(r,'app')).dispatch,false);
    await oq("UPDATE public.wallet_holds SET expires_at=now()-interval '1 hour' WHERE id=$1",[r.wallet_hold_id]);await role(one);await one.query('SELECT public.recover_expired_wallet_holds(100)');
    assert.equal(await scalar(owner,'SELECT status FROM public.wallet_holds WHERE id=$1',[r.wallet_hold_id]),'active');assert.equal((await prepare(f)).created,false);
    const g=await seed(),p=await prepare(g);await oq("UPDATE public.wallet_holds SET expires_at=now()-interval '1 hour' WHERE id=$1",[p.call.wallet_hold_id]);await assert.rejects(()=>begin(p.call,'app'),/Matching active/);
  });
  await check('pre-submission cancellation releases once; post-submission cancellation retains money',async()=>{
    for(const submitted of [false,true]){const f=await seed(),{call:r}=await prepare(f);if(submitted)await begin(r,'app');await role(one);await one.query('SELECT public.request_media_call_termination($1)',[r.id]);await one.query('SELECT public.request_media_call_termination($1)',[r.id]);assert.equal((await row(r.id)).billing_state,submitted?'termination_pending':'settled');assert.equal(await scalar(owner,'SELECT status FROM public.wallet_holds WHERE id=$1',[r.wallet_hold_id]),submitted?'active':'released');}
  });
  await check('settlement failure preserves committed evidence, funding and recoverable active hold',async()=>{
    const f=await seed(),r=await connected(f);await evidence(r,'destination','call.bridged',2);const terminal=await evidence(r,'destination','call.hangup',62,{hangup_cause:'normal_clearing'});
    const alloc=(await oq('DELETE FROM public.wallet_hold_allocations WHERE hold_id=$1 RETURNING *',[r.wallet_hold_id])).rows;
    await assert.rejects(()=>finish(r,terminal),/Funding/);assert.equal(await balance(f),60);assert.ok((await row(r.id)).destination_ended_at);
    for(const a of alloc)await oq('INSERT INTO public.wallet_hold_allocations(hold_id,lot_id,amount) VALUES($1,$2,$3)',[a.hold_id,a.lot_id,a.amount]);
    await finish(r,terminal);assert.equal(await balance(f),59);
  });
  await check('provider overrun is capped to the reserved money and recorded for reconciliation',async()=>{
    const f=await seed(),r=await connected(f);await evidence(r,'destination','call.bridged',2);const terminal=await evidence(r,'destination','call.hangup',3602,{hangup_cause:'normal_clearing'});await finish(r,terminal);
    const saved=await row(r.id);assert.equal(Number(saved.total_cost_usd),5);assert.equal(Number(saved.observed_cost_usd),60);assert.equal(saved.reconciliation_reason,'provider_duration_overrun');assert.equal(await balance(f),55);
  });
  await check('foreign hold binding and conflicting terminal evidence cannot settle or steal money',async()=>{
    const f=await seed(),g=await seed(),r=await connected(f),q=(await prepare(g)).call;
    await evidence(r,'destination','call.bridged',2);const terminal=await evidence(r,'destination','call.hangup',62,{hangup_cause:'normal_clearing'});
    await assert.rejects(()=>evidence(r,'destination','call.hangup',63,{hangup_cause:'normal_clearing'}),/Conflicting/);
    await oq('UPDATE public.call_records SET wallet_hold_id=NULL,budget_contract_version=0 WHERE id=$1',[q.id]);
    await oq('UPDATE public.call_records SET wallet_hold_id=$1 WHERE id=$2',[q.wallet_hold_id,r.id]);await assert.rejects(()=>finish(r,terminal),/Matching active/);assert.equal(await balance(g),60);
  });
  await check('legacy calls require reconciliation and never debit unreserved funds',async()=>{
    const f=await seed();const id=await scalar(owner,"INSERT INTO public.call_records(user_id,call_type,caller_number,destination_number,rate_per_minute_usd,answered_at) VALUES($1,'app_to_phone_webrtc','+15550001111',$2,1,now()) RETURNING id",[f.u,f.request.destination_number]);
    await role(one);await one.query("SELECT public.finish_media_call($1,now()+interval '1 minute','completed',NULL,'{}')",[id]);assert.equal((await row(id)).billing_state,'reconciliation_required');assert.equal(await balance(f),60);
  });
  if(one!==owner&&two!==owner){
    await check('independent concurrent duplicate creations adopt one call, session and reservation',async()=>{
      const f=await seed();const p=await Promise.all([prepare(f,one),prepare(f,two)]);assert.equal(p[0].call.id,p[1].call.id);assert.equal(p.filter(x=>x.created).length,1);
    });
    await check('independent simultaneous calls cannot reserve the same five dollars',async()=>{
      const f=await seed({balance:5}),session=crypto.randomUUID();await oq("INSERT INTO public.call_media_sessions(id,user_id,credential_id,sip_username,expires_at) VALUES($1,$2,'synthetic2','synthetic2',now()+interval '5 minutes')",[session,f.u]);
      const g={...f,session,request:{...f.request,idempotency_key:crypto.randomUUID()}};const attempts=await Promise.allSettled([prepare(f,one),prepare(g,two)]);assert.equal(attempts.filter(x=>x.status==='fulfilled').length,1);
    });
    await check('independent cancellation versus submission never releases a submitted call',async()=>{
      const f=await seed(),r=(await prepare(f)).call;
      await role(two);
      await Promise.all([begin(r,'app',one),two.query('SELECT public.request_media_call_termination($1)',[r.id])]);
      const saved=await row(r.id),hold=await scalar(owner,'SELECT status FROM public.wallet_holds WHERE id=$1',[r.wallet_hold_id]);
      assert.equal(hold,saved.app_submission_at?'active':'released');
      assert.equal(saved.billing_state,saved.app_submission_at?'termination_pending':'settled');
    });
    await check('independent readiness and terminal callbacks each commit once',async()=>{
      const f=await seed(),r=await connected(f);await evidence(r,'destination','call.bridged',2);const terminal=await evidence(r,'destination','call.hangup',62,{hangup_cause:'normal_clearing'});
      await Promise.all([finish(r,terminal,one),finish(r,terminal,two)]);assert.equal(await balance(f),59);
      const g=await seed(),p=(await prepare(g)).call;const starts=await Promise.all([begin(p,'app',one),begin(p,'app',two)]);assert.equal(starts.filter(x=>x.dispatch).length,1);
    });
  }
  await role(owner,'none');
}
async function main(){const db=new PGlite(),results=[];try{await bootstrap(db);await runCalls({owner:db},async(name,body)=>{try{await body();results.push({name,status:'passed'});console.log('PASS '+name);}catch(e){results.push({name,status:'failed',message:e.message});console.error('FAIL '+name+': '+e.message);}});}finally{await db.close();}console.log(`${results.filter(x=>x.status==='passed').length} passed / ${results.filter(x=>x.status==='failed').length} failed call scenarios`);if(process.env.FINANCIAL_TEST_REPORT)fs.writeFileSync(process.env.FINANCIAL_TEST_REPORT,JSON.stringify({results},null,2)+'\n');if(results.some(x=>x.status==='failed'))process.exitCode=1;}
if(process.argv[1]===new URL(import.meta.url).pathname)await main();
