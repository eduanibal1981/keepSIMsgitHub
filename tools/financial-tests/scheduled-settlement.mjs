import assert from 'node:assert/strict';
import { randomUUID as uuid } from 'node:crypto';

// Real production-shaped RPCs; no supplier calls. Native runs use independent
// sessions for every race. All identities and funds below are synthetic.
export async function runScheduledSettlement({owner,one=owner,two=owner},check){
  const scalar=async(c,sql,args=[])=>Object.values((await c.query(sql,args)).rows[0])[0];
  const role=async(c,r='service_role')=>{
    await c.query('RESET ROLE');await c.query('SET ROLE '+r);
    await c.query("SELECT set_config('request.jwt.claims',$1,false)",[JSON.stringify({role:r})]);
  };
  const route={provider:'dtone',offerId:'fixture-pin',offerValue:200,costUsd:2,feeUsd:0,
    totalChargeUsd:2,targetLocalValue:2,targetLocalCurrency:'USD'};
  async function seed(type='refill_mini',balance=20){
    await role(owner,'none');
    const u=uuid(),l=uuid(),e=uuid();
    await owner.query('INSERT INTO auth.users(id,email) VALUES($1,$2)',[u,u+'@fixture.test']);
    await owner.query('INSERT INTO public.profiles(id,email) VALUES($1,$2)',[u,u+'@fixture.test']);
    await owner.query("INSERT INTO public.sim_lines(id,user_id,phone_number,plan_type,plan_expires_at) VALUES($1,$2,'+15550001010','premium',now()+interval '1 year')",[l,u]);
    await owner.query('SELECT public.ensure_wallet_v2($1)',[u]);
    await owner.query("SELECT public.credit_wallet_for_deposit($1::uuid,$2,'fixture',$3,jsonb_build_object('paypal_capture_id',$1::text))",[u,balance,'paypal_'+u]);
    await owner.query("INSERT INTO public.topup_executions(id,user_id,sim_line_id,execution_type,status,amount,base_cost_usd,app_fee_usd,currency,payment_gateway_code,max_authorized_usd,fulfillment_gateway) VALUES($1,$2,$3,$4,'processing',2,2,0,'USD','wallet',3,'API')",[e,u,l,type]);
    return {u,l,e,balance};
  }
  async function prepare(f,c=one,r=route){await role(c);const p=await scalar(c,'SELECT public.prepare_scheduled_refill($1,$2)',[f.e,r]);f.h=p.hold_id;f.route=p.route;return p;}
  async function begin(f,c=one){await role(c);return c.query('SELECT public.begin_scheduled_refill_submission($1,$2,$3)',[f.e,f.h,f.route]);}
  async function settle(f,c=one,proof='proof_'+f.e){await role(c);return scalar(c,"SELECT public.settle_successful_execution(p_execution_id=>$1,p_provider_tx_id=>$2,p_hold_id=>$3,p_pin_code=>'1234',p_pin_serial=>'serial',p_redeem_instructions=>'Dial code',p_metadata=>'{\"execution_id\":\"forged\",\"provider_tx_id\":\"forged\"}')",[f.e,proof,f.h]);}
  async function stop(f,c=one,status='failed'){await role(c);return scalar(c,'SELECT public.stop_scheduled_refill_before_submission($1,$2,$3)',[f.e,'fixture stop',status]);}
  async function ownerQuery(sql,args=[]){await role(owner,'none');return args.length?owner.query(sql,args):owner.query(sql);}
  async function balance(f){await role(owner,'none');return Number(await scalar(owner,'SELECT balance FROM public.wallets WHERE user_id=$1',[f.u]));}
  await ownerQuery("INSERT INTO public.payment_gateways(code,name) VALUES('wallet','Fixture wallet'),('paypal','Fixture external') ON CONFLICT DO NOTHING");
  await ownerQuery("INSERT INTO public.app_fee_rules(appfees_item,version,free_percentage,free_minimum,stand_percentage,stand_minimum,prem_percentage,prem_minimum,status) VALUES('refills',9999999,0,0,0,0,0,0,'published') ON CONFLICT DO NOTHING");

  await check('scheduled RPC catalog has one settlement signature and service-only grants',async()=>{
    const rows=(await ownerQuery("SELECT proname,proargnames,pronargdefaults FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname IN ('settle_successful_execution','update_execution_status')")).rows;
    assert.equal(rows.length,1);assert.equal(rows[0].proname,'settle_successful_execution');
    assert.equal(rows[0].pronargdefaults,5);
    for(const r of ['anon','authenticated'])for(const fn of ['prepare_scheduled_refill(uuid,jsonb)','begin_scheduled_refill_submission(uuid,uuid,jsonb)','settle_successful_execution(uuid,text,uuid,text,text,text,jsonb)','stop_scheduled_refill_before_submission(uuid,text,text)','assert_scheduled_refill_reservation(uuid,uuid)']){
      assert.equal(await scalar(owner,"SELECT has_function_privilege($1,$2,'EXECUTE')",[r,'public.'+fn]),false);
    }
    const f=await seed();
    for(const r of ['anon','authenticated']){
      await role(one,r);await assert.rejects(()=>one.query('SELECT public.prepare_scheduled_refill($1,$2)',[f.e,route]),/permission denied/);
    }
  });
  for(const type of ['refill_mini','refill_custom'])await check(type+' prepares, submits and captures exactly once with PIN fields',async()=>{
    const f=await seed(type);await prepare(f);await prepare(f);await begin(f);await settle(f);await settle(f);
    assert.equal(await balance(f),18);
    const row=(await ownerQuery('SELECT status,pin_code,pin_serial,redeem_instructions FROM public.topup_executions WHERE id=$1',[f.e])).rows[0];
    assert.deepEqual(row,{status:'success',pin_code:'1234',pin_serial:'serial',redeem_instructions:'Dial code'});
    assert.equal(Number(await scalar(owner,"SELECT count(*) FROM public.wallet_transactions WHERE user_id=$1 AND type='topup_debit'",[f.u])),1);
    await role(one);
    // Current two-argument and full named payloads resolve to the same API.
    assert.equal((await scalar(one,'SELECT public.settle_successful_execution(p_execution_id=>$1,p_provider_tx_id=>$2)',[f.e,'proof_'+f.e])).idempotent,true);
    await assert.rejects(()=>settle(f,one,'other-proof'),/identity mismatch/);
    await assert.rejects(()=>one.query("SELECT public.settle_successful_execution($1,$2,$3,'changed')",[f.e,'proof_'+f.e,f.h]),/identity mismatch/);
  });
  await check('missing holds and unproven external/prepaid funding cannot submit or settle',async()=>{
    const f=await seed();f.route=route;
    await assert.rejects(()=>begin(f),/reservation|reconciliation/);
    await assert.rejects(()=>settle(f),/reservation/);
    for(const change of ["payment_gateway_code='paypal'","funding_kind='legacy_prepaid'","currency='EUR'"]){
      await ownerQuery('UPDATE public.topup_executions SET '+change+' WHERE id=$1',[f.e]);
      await assert.rejects(()=>prepare(f),/funding required/);
      await ownerQuery("UPDATE public.topup_executions SET payment_gateway_code='wallet',funding_kind='wallet_due',currency='USD' WHERE id=$1",[f.e]);
    }
    assert.equal(await balance(f),20);
  });
  const mutations=[
    ['wrong payer',"user_id=$2"],['wrong wallet',"wallet_id=(SELECT id FROM public.wallets WHERE user_id=$2)"],
    ['wrong currency',"currency='EUR'"],['insufficient amount',"amount=1"],['excess amount',"amount=3"],
    ['wrong purpose',"order_type='refill_instant'"],['wrong execution',"order_reference_id='exec_wrong'"],
    ['released hold',"status='released'"],['legacy hold',"recovery_contract_version=0"],
    ['expired hold',"expires_at=now()-interval '1 minute'"],['missing hold',null]
  ];
  for(const [name,mutation] of mutations)await check('scheduled submission rejects '+name,async()=>{
    const f=await seed(),foreign=await seed();await prepare(f);
    if(mutation)await ownerQuery('UPDATE public.wallet_holds SET '+mutation+' WHERE id=$1',mutation.includes('$2')?[f.h,foreign.u]:[f.h]);
    else f.h=uuid();
    await assert.rejects(()=>begin(f),/reservation|binding|reconciliation/);
    assert.equal(await balance(f),20);
    assert.equal(await scalar(owner,'SELECT carrier_in_flight FROM public.topup_executions WHERE id=$1',[f.e]),false);
  });
  await check('route/price disagreement, authorization and stale prepared snapshots fail before submission',async()=>{
    const f=await seed();
    for(const patch of [{totalChargeUsd:4},{totalChargeUsd:2.01},{feeUsd:1}])await assert.rejects(()=>prepare(f,one,{...route,...patch}),/price|contract/,JSON.stringify(patch));
    await prepare(f);await ownerQuery("UPDATE public.topup_executions SET offer_id='different' WHERE id=$1",[f.e]);
    await assert.rejects(()=>begin(f),/reconciliation/);assert.equal(await balance(f),20);
  });
  await check('unfunded lot allocations and reused holds cannot authorize a purchase',async()=>{
    const f=await seed();await prepare(f);
    await ownerQuery('DELETE FROM public.wallet_hold_allocations WHERE hold_id=$1',[f.h]);
    await assert.rejects(()=>begin(f),/Funding reconciliation/);
    const g=await seed();await prepare(g);
    await ownerQuery("INSERT INTO public.topup_executions(user_id,sim_line_id,status,amount,execution_type,wallet_hold_id) VALUES($1,$2,'pending',2,'refill_custom',$3)",[g.u,g.l,g.h]);
    await assert.rejects(()=>begin(g),/reservation/);
  });
  await check('settlement revalidates hold and submission bindings and preserves ambiguous money',async()=>{
    const f=await seed();await prepare(f);
    await assert.rejects(()=>settle(f),/submission/);await begin(f);
    for(const mutation of ["currency='EUR'","amount=1","order_reference_id='wrong'","status='released'"]){
      await ownerQuery('UPDATE public.wallet_holds SET '+mutation+' WHERE id=$1',[f.h]);
      await assert.rejects(()=>settle(f),/reservation/);
      await ownerQuery("UPDATE public.wallet_holds SET currency='USD',amount=2,order_reference_id=$2,status='active' WHERE id=$1",[f.h,'exec_'+f.e]);
    }
    await ownerQuery("UPDATE public.topup_executions SET offer_id='changed-after-submission' WHERE id=$1",[f.e]);
    await assert.rejects(()=>settle(f),/submission binding/);
    await ownerQuery("UPDATE public.topup_executions SET offer_id='fixture-pin' WHERE id=$1",[f.e]);
    assert.equal((await stop(f)).reconciliation_required,true);
    await ownerQuery("UPDATE public.wallet_holds SET expires_at=now()-interval '1 day' WHERE id=$1",[f.h]);
    await settle(f);assert.equal(await balance(f),18); // expiry never proves non-delivery
  });
  await check('safe pre-submission stops release once; later attempts use a fresh bound reservation',async()=>{
    const f=await seed();await prepare(f);const old=f.h;
    assert.equal((await stop(f,one,'awaiting_approval')).success,true);
    assert.equal((await stop(f)).reconciliation_required,true);
    await ownerQuery("UPDATE public.topup_executions SET status='processing' WHERE id=$1",[f.e]);
    await prepare(f);assert.notEqual(f.h,old);await begin(f);await settle(f);assert.equal(await balance(f),18);
    assert.equal(await scalar(owner,'SELECT status FROM public.wallet_holds WHERE id=$1',[old]),'released');
  });
  await check('settlement rolls back capture when the execution write fails, then retries once',async()=>{
    const f=await seed();await prepare(f);await begin(f);
    await ownerQuery("CREATE FUNCTION public.fixture_reject_scheduled_success() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.id='"+f.e+"'::uuid AND NEW.status='success' THEN RAISE EXCEPTION 'fixture write failure'; END IF; RETURN NEW; END $$");
    await ownerQuery("CREATE TRIGGER fixture_reject_scheduled_success BEFORE UPDATE ON public.topup_executions FOR EACH ROW EXECUTE FUNCTION public.fixture_reject_scheduled_success()");
    try{await assert.rejects(()=>settle(f),/fixture write failure/);assert.equal(await balance(f),20);}
    finally{await ownerQuery('DROP TRIGGER fixture_reject_scheduled_success ON public.topup_executions');await ownerQuery('DROP FUNCTION public.fixture_reject_scheduled_success()');}
    await settle(f);await settle(f);assert.equal(await balance(f),18);
  });
  await check('insufficient available funds leave no partial reservation or route write',async()=>{
    const f=await seed('refill_custom',1);
    await assert.rejects(()=>prepare(f),/Insufficient available balance/);
    assert.equal(Number(await scalar(owner,'SELECT count(*) FROM public.wallet_holds WHERE user_id=$1',[f.u])),0);
  });
  if(one!==owner&&two!==owner){
    await check('concurrent scheduled preparation/submission/settlement use one hold and one debit',async()=>{
      const f=await seed();await Promise.all([prepare(f,one),prepare(f,two)]);
      assert.equal(Number(await scalar(owner,'SELECT count(*) FROM public.wallet_holds WHERE user_id=$1',[f.u])),1);
      const attempts=await Promise.allSettled([begin(f,one),begin(f,two)]);
      assert.equal(attempts.filter(x=>x.status==='fulfilled').length,1);
      await Promise.all([settle(f,one),settle(f,two)]);assert.equal(await balance(f),18);
    });
    await check('scheduled submission races safely with preflight failure and stale failure cannot downgrade success',async()=>{
      const f=await seed();await prepare(f);
      const results=await Promise.allSettled([begin(f,one),stop(f,two)]);
      const submitted=results[0].status==='fulfilled';
      if(submitted){await settle(f);assert.equal((await stop(f)).reconciliation_required,true);assert.equal(await balance(f),18);}
      else {assert.equal(results[1].value.success,true);assert.equal(await balance(f),20);}
      assert.equal(await scalar(owner,'SELECT status FROM public.wallet_holds WHERE id=$1',[f.h]),submitted?'captured':'released');
    });
  }
  await role(owner,'none');
}
