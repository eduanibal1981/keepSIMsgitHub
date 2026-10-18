// Task 12: production-shaped constraints/funding; no external provider or DB writes.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';
import { bootstrap } from './bootstrap.mjs';
const {PGlite}=await import(process.env.PGLITE_MODULE_PATH?pathToFileURL(process.env.PGLITE_MODULE_PATH).href:'@electric-sql/pglite');
export async function runLiveness({owner,one=owner,two=owner},check){
  assert.deepEqual((await owner.query(fs.readFileSync(new URL('../../supabase/tests/liveness_verification_contract_tests.sql',import.meta.url),'utf8'))).rows,[]);
  const scalar=async(c,sql,args=[])=>Object.values((await c.query(sql,args)).rows[0])[0];
  async function role(c,r='service_role',sub=null){await c.query('RESET ROLE');if(r!=='none')await c.query('SET ROLE '+r);await c.query("SELECT set_config('request.jwt.claims',$1,false)",[JSON.stringify({role:r,sub})]);}
  async function oq(sql,args=[]){await role(owner,'none');return owner.query(sql,args);}
  async function seed({price=1,plan='free',balance=10}={}){
    const u=crypto.randomUUID(),l=crypto.randomUUID(),country=crypto.randomUUID();
    await oq('INSERT INTO auth.users(id,email) VALUES($1,$2)',[u,u+'@fixture.test']);
    await oq('INSERT INTO public.profiles(id,email) VALUES($1,$2)',[u,u+'@fixture.test']);
    await oq("INSERT INTO public.countries(id,name,iso_code,dialing_code,currency_code,sms_verify_cost,call_verify_cost) VALUES($1::uuid,'Fixture',$1::text,'+1','USD',$2,$2)",[country,price]);
    await oq("INSERT INTO public.sim_lines(id,user_id,phone_number,country_id,plan_type,plan_expires_at,health_score) VALUES($1,$2,'+15550001011',$3,$4::text,CASE WHEN $4::text='free' THEN NULL ELSE now()+interval '1 year' END,0)",[l,u,country,plan]);
    await role(one);await one.query('SELECT public.ensure_wallet_v2($1)',[u]);
    if(balance)await one.query("SELECT public.credit_wallet_for_deposit($1::uuid,$2,'fixture',$3,jsonb_build_object('paypal_capture_id',$1::text))",[u,balance,'paypal_'+u]);
    return{u,l,country};
  }
  async function begin(f,method='sms',key=crypto.randomUUID(),c=one){await role(c);return scalar(c,'SELECT public.begin_line_verification($1,$2,$3,$4)',[f.u,f.l,method,key]);}
  async function bind(a,resource='resource-'+a.id,c=one){await role(c);await c.query('SELECT public.bind_line_verification_resource($1,$2)',[a.id,resource]);return resource;}
  async function settle(a,outcome='succeeded',event=a.method==='sms'?'message.delivered':'call.ringing',resource='resource-'+a.id,c=one){await role(c);return scalar(c,'SELECT public.settle_line_verification_event($1,$2,$3,$4,$5,$6,$7)',[a.id,'telnyx',resource,event,outcome,'Fixture',null]);}
  async function state(f){return(await oq('SELECT verification_status,is_carrier_verified,health_score,(SELECT balance::text FROM public.wallets WHERE user_id=$2) balance FROM public.sim_lines WHERE id=$1',[f.l,f.u])).rows[0];}
  await check('customer and anonymous roles cannot self-confirm, settle, bind, reserve attempts or mutate evidence',async()=>{
    const f=await seed();
    for(const r of ['anon','authenticated']){
      await role(one,r,f.u);
      for(const fn of ['confirm_line_verification(uuid,text,text)','settle_line_verification_attempt(uuid,text,text,text)','begin_line_verification(uuid,uuid,text,text)','bind_line_verification_resource(uuid,text)','settle_line_verification_event(uuid,text,text,text,text,text,text)'])assert.equal(await scalar(one,"SELECT has_function_privilege(current_user,$1,'EXECUTE')",['public.'+fn]),false);
      for(const table of ['line_verification_attempts','line_verification_allowances'])for(const p of ['INSERT','UPDATE','DELETE','TRUNCATE'])assert.equal(await scalar(one,'SELECT has_table_privilege(current_user,$1,$2)',['public.'+table,p]),false);
      await assert.rejects(()=>one.query('SELECT public.confirm_line_verification($1)',[f.l]),/permission denied/);
    }
  });
  await check('quote rejects anonymous impersonation and foreign users; free plans cannot gain legacy premium allowance',async()=>{
    const f=await seed(),other=await seed();await role(one,'anon');await assert.rejects(()=>one.query('SELECT public.quote_line_verification($1,$2)',[f.l,f.u]),/permission denied/);
    await role(one,'authenticated',other.u);await assert.rejects(()=>one.query('SELECT public.quote_line_verification($1,$2)',[f.l,f.u]),/Unauthorized/);
    await assert.rejects(()=>one.query('SELECT public.quote_line_verification($1)',[f.l]),/Unauthorized/);
    await oq("UPDATE public.sim_lines SET protection_tier='premium' WHERE id=$1",[f.l]);await role(one,'authenticated',f.u);
    assert.equal((await scalar(one,'SELECT public.quote_line_verification($1)',[f.l])).has_annual_allowance,false);
    await assert.rejects(()=>begin({...f,u:other.u}),/Owned SIM/);
  });
  await check('paid SMS captures once, preserves ledger/funding/reconciliation and earns only 25 verification points',async()=>{
    const f=await seed();const {attempt:a}=await begin(f);await bind(a);
    assert.equal((await settle(a)).settlement_status,'captured');
    assert.equal((await settle(a,'failed','message.failed')).outcome,'succeeded');
    const row=await state(f);assert.equal(row.verification_status,'verified');assert.equal(row.is_carrier_verified,true);assert.equal(row.health_score,25);assert.equal(Number(row.balance),9);
    const ledger=(await oq("SELECT * FROM public.wallet_transactions WHERE user_id=$1 AND type='verification_debit'",[f.u])).rows;assert.equal(ledger.length,1);assert.equal(Number(ledger[0].amount),1);
    assert.equal(Number(await scalar(owner,'SELECT drift FROM public.wallet_reconciliation WHERE user_id=$1',[f.u])),0);
    await owner.query('SELECT public.assert_wallet_funding_integrity((SELECT id FROM public.wallets WHERE user_id=$1))',[f.u]);
  });
  await check('verified health preserves the notify and recent-refill pillars instead of fabricating a perfect score',async()=>{
    const f=await seed();await oq('UPDATE public.sim_lines SET last_topup_at=now() WHERE id=$1',[f.l]);
    await oq("INSERT INTO public.scheduled_topups(user_id,sim_line_id,amount,frequency_days,schedule_type,status,is_active,next_execution_at) VALUES($1,$2,1,30,'notify','active',true,now()+interval '1 day')",[f.u,f.l]);
    const {attempt:a}=await begin(f);await bind(a);await settle(a);assert.equal((await state(f)).health_score,100);
  });
  await check('failed wallet capture rolls back evidence, ledger, balance and verification together',async()=>{
    const f=await seed(),{attempt:a}=await begin(f);await bind(a);
    await oq('DELETE FROM public.wallet_hold_allocations WHERE hold_id=$1',[a.wallet_hold_id]);
    await assert.rejects(()=>settle(a),/allocat|funding/i);
    assert.equal(Number((await state(f)).balance),10);assert.equal((await state(f)).is_carrier_verified,false);
    assert.equal(await scalar(owner,'SELECT status FROM public.line_verification_attempts WHERE id=$1',[a.id]),'pending');
  });
  await check('ring evidence settles voice; no-answer and normal clearing alone cannot verify',async()=>{
    for(const event of ['call.hangup','call.no-answer','call.completed']){
      const f=await seed(),{attempt:a}=await begin(f,'voice');await bind(a);
      await assert.rejects(()=>settle(a,'succeeded',event),/Positive provider/);
      await settle(a,'inconclusive',event);assert.equal((await state(f)).is_carrier_verified,false);assert.equal(Number((await state(f)).balance),10);
      assert.equal((await settle(a)).outcome,'inconclusive');
    }
    const f=await seed(),{attempt:a}=await begin(f,'voice');await bind(a);await settle(a);assert.equal((await state(f)).health_score,25);
  });
  await check('free corridor and annual allowance success charge no wallet money; allowance is consumed once',async()=>{
    for(const options of [{price:0},{plan:'standard'}]){
      const f=await seed(options),{attempt:a}=await begin(f);await bind(a);await settle(a);await settle(a);
      assert.equal(Number((await state(f)).balance),10);
      assert.equal(Number(await scalar(owner,"SELECT count(*) FROM public.wallet_transactions WHERE user_id=$1 AND type='verification_debit'",[f.u])),0);
      if(options.plan){const next=await begin(f);assert.equal(next.attempt.funding_kind,'wallet');await settle(next.attempt,'failed','dispatch.rejected',null);}
    }
  });
  await check('failure releases only its exact allowance or hold; repeated release and delayed success cannot award verification',async()=>{
    for(const options of [{},{plan:'premium'}]){
      const f=await seed(options),{attempt:a}=await begin(f);await bind(a);await settle(a,'failed','message.failed');await settle(a,'failed','message.failed');
      assert.equal((await settle(a)).outcome,'failed');assert.equal(Number((await state(f)).balance),10);
      const next=await begin(f);assert.equal(next.attempt.funding_kind,options.plan?'annual_allowance':'wallet');
    }
  });
  await check('provider/resource/method/outcome mismatches cannot settle another attempt or release its funds',async()=>{
    const f=await seed(),g=await seed(),{attempt:a}=await begin(f),{attempt:b}=await begin(g);await bind(a);await bind(b);
    await assert.rejects(()=>settle(a,'succeeded','message.delivered','resource-'+b.id),/Provider identity/);
    await assert.rejects(()=>settle(a,'succeeded','call.ringing'),/Positive provider/);
    await assert.rejects(()=>settle(a,'pending'),/Invalid verification outcome/);
    await assert.rejects(()=>settle(a,'succeeded',null),/Provider event type required/);
    await assert.rejects(()=>settle(a,'failed','dispatch.rejected',null),/Not an undispatched/);
    assert.equal(Number((await state(f)).balance),10);assert.equal((await state(g)).is_carrier_verified,false);
  });
  await check('idempotent start adopts one reservation; key mismatch and insufficient funds cannot create extra attempts',async()=>{
    const f=await seed(),key=crypto.randomUUID(),first=await begin(f,'sms',key),again=await begin(f,'sms',key);assert.equal(first.attempt.id,again.attempt.id);assert.equal(again.dispatch,false);
    assert.equal((await begin(f)).dispatch,false);await assert.rejects(()=>begin(f,'voice',key),/Idempotency terms/);
    assert.equal(Number(await scalar(owner,"SELECT count(*) FROM public.wallet_holds WHERE user_id=$1 AND status='active'",[f.u])),1);
    const g=await seed({balance:0});await assert.rejects(()=>begin(g),/Insufficient/);
    assert.equal(Number(await scalar(owner,'SELECT count(*) FROM public.line_verification_attempts WHERE user_id=$1',[g.u])),0);
  });
  await check('unknown dispatch remains blocked after expiry and cannot be repeated or implicitly released',async()=>{
    const f=await seed(),{attempt:a}=await begin(f);
    await oq("UPDATE public.line_verification_attempts SET status='reconciliation_required',settlement_status='reconciliation_required' WHERE id=$1",[a.id]);
    await oq("UPDATE public.wallet_holds SET expires_at=now()-interval '1 hour' WHERE id=$1",[a.wallet_hold_id]);
    await role(one);await one.query('SELECT public.recover_expired_wallet_holds(100)');
    assert.equal((await begin(f)).dispatch,false);
    assert.equal(await scalar(owner,'SELECT status FROM public.wallet_holds WHERE id=$1',[a.wallet_hold_id]),'active');
    await assert.rejects(()=>settle(a,'failed','dispatch.rejected',null),/Not an undispatched/);
    await bind(a);await settle(a);assert.equal(Number((await state(f)).balance),9);
  });
  await check('foreign hold or allowance binding makes settlement atomic and leaves line unverified',async()=>{
    for(const options of [{},{plan:'premium'}]){
      const f=await seed(options),g=await seed(options),{attempt:a}=await begin(f),{attempt:b}=await begin(g);await bind(a);
      await oq(options.plan?'UPDATE public.line_verification_attempts SET allowance_id=$1 WHERE id=$2':'UPDATE public.line_verification_attempts SET wallet_hold_id=$1 WHERE id=$2',[options.plan?b.allowance_id:b.wallet_hold_id,a.id]);
      await assert.rejects(()=>settle(a),/mismatch/);assert.equal((await state(f)).is_carrier_verified,false);assert.equal(Number((await state(g)).balance),10);
    }
  });
  await check('arbitrary verification prose and legacy succeeded attempts cannot earn health points',async()=>{
    const f=await seed();await oq("INSERT INTO public.line_activity_log(sim_line_id,user_id,event_type,description) VALUES($1,$2,'health_update','SIM live verified active via invented channel')",[f.l,f.u]);
    await oq("INSERT INTO public.line_verification_attempts(sim_line_id,user_id,method,destination_phone,funding_kind,status,outcome,settlement_status) VALUES($1,$2,'sms','+15550001011','country_zero','terminal','succeeded','no_charge')",[f.l,f.u]);
    assert.equal(Number(await scalar(owner,"SELECT public.calculate_health_score($1,'active',NULL)",[f.l])),0);
  });
  await check('identity edits during pending verification are blocked; later edits clear verification',async()=>{
    const f=await seed(),{attempt:a}=await begin(f);await bind(a);
    await assert.rejects(()=>oq("UPDATE public.sim_lines SET phone_number='+15550001012' WHERE id=$1",[f.l]),/Unresolved/);
    await settle(a);await oq("UPDATE public.sim_lines SET phone_number='+15550001012' WHERE id=$1",[f.l]);assert.equal((await state(f)).is_carrier_verified,false);assert.equal((await state(f)).health_score,0);
  });
  await check('direct invoker trigger prevents forged client fields on insert/update while preserving nickname updates',async()=>{
    // Real trigger body, isolated probe avoids unrelated live household/auth adapters.
    const f=await seed();await oq('CREATE TEMP TABLE verification_probe (LIKE public.sim_lines INCLUDING DEFAULTS)');
    await owner.query('GRANT SELECT,INSERT,UPDATE ON verification_probe TO authenticated');
    await owner.query('CREATE TRIGGER probe BEFORE INSERT OR UPDATE ON verification_probe FOR EACH ROW EXECUTE FUNCTION public.guard_line_verification_fields()');
    await role(owner,'authenticated',f.u);
    await owner.query("INSERT INTO verification_probe(id,user_id,phone_number,verification_status,health_score,is_carrier_verified) VALUES($1,$2,'+15550001011','verified',100,true)",[f.l,f.u]);
    assert.equal(await scalar(owner,'SELECT is_carrier_verified FROM verification_probe'),false);
    await assert.rejects(()=>owner.query("UPDATE verification_probe SET is_carrier_verified=true"),/server owned/);
    await owner.query("UPDATE verification_probe SET nickname='Permitted'");await role(owner,'none');await owner.query('DROP TABLE verification_probe');
  });
  if(one!==owner&&two!==owner){
    await check('independent simultaneous starts dispatch once and reserve one wallet hold',async()=>{
      const f=await seed();const results=await Promise.all([begin(f,'sms','one',one),begin(f,'sms','two',two)]);
      assert.equal(results.filter(r=>r.dispatch).length,1);assert.equal(results[0].attempt.id,results[1].attempt.id);
    });
    await check('independent duplicate callbacks capture one debit and one allowance',async()=>{
      for(const options of [{},{plan:'premium'}]){
        const f=await seed(options),{attempt:a}=await begin(f);await bind(a);
        await Promise.all([settle(a,'succeeded','message.delivered','resource-'+a.id,one),settle(a,'succeeded','message.delivered','resource-'+a.id,two)]);
        assert.equal(Number((await state(f)).balance),options.plan?10:9);
      }
    });
    await check('independent failure versus delivery events cannot change the first committed terminal outcome',async()=>{
      const f=await seed(),{attempt:a}=await begin(f);await bind(a);
      const results=await Promise.all([settle(a,'succeeded','message.delivered','resource-'+a.id,one),settle(a,'failed','message.failed','resource-'+a.id,two)]);
      assert.equal(results[0].outcome,results[1].outcome);
      assert.equal(Number((await state(f)).balance),results[0].outcome==='succeeded'?9:10);
    });
  }
  await role(owner,'none');
}
async function main(){
 const db=new PGlite(),results=[];
 try{await bootstrap(db);
 await runLiveness({owner:db},async(name,body)=>{try{await body();results.push({name,status:'passed'});console.log('PASS '+name);}catch(e){results.push({name,status:'failed',message:e.message});console.error('FAIL '+name+': '+e.message);}});
 }finally{await db.close();}
 console.log(`${results.filter(x=>x.status==='passed').length} passed / ${results.filter(x=>x.status==='failed').length} failed liveness scenarios`);
 if(process.env.FINANCIAL_TEST_REPORT)fs.writeFileSync(process.env.FINANCIAL_TEST_REPORT,JSON.stringify({results},null,2)+'\n');
 if(results.some(x=>x.status==='failed'))process.exitCode=1;
}
if(process.argv[1]===new URL(import.meta.url).pathname)await main();
