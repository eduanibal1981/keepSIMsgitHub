import assert from 'node:assert/strict';
import { randomUUID as uuid } from 'node:crypto';

// Same production-shaped fixture and real RPCs in WASM and independent native
// sessions. Provider catalogue/risk adapters remain the documented fixture ones.
export async function runSetupSettlement({owner,one=owner,two=owner},check){
  const scalar=async(c,sql,args=[])=>Object.values((await c.query(sql,args)).rows[0])[0];
  const claim=async(c,user,role='authenticated')=>{
    await c.query('RESET ROLE');await c.query('SET ROLE '+role);
    await c.query("SELECT set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub:user,role})]);
  };
  async function seed(balance=20,plan='premium'){
    await owner.query('RESET ROLE');await owner.query("SELECT set_config('request.jwt.claims','',false)");
    const u=uuid(),l=uuid(),e=uuid(),country=uuid(),carrier=uuid(),rule=uuid();
    await owner.query('INSERT INTO auth.users(id,email) VALUES($1,$2)',[u,u+'@fixture.test']);
    await owner.query('INSERT INTO public.profiles(id,email) VALUES($1,$2)',[u,u+'@fixture.test']);
    await owner.query("INSERT INTO public.countries(id,name,iso_code,dialing_code,currency_code) VALUES($1,'Fixture',$2,'+999','USD')",[country,country]);
    await owner.query("INSERT INTO public.carriers(id,country_id,name) VALUES($1,$2,'Fixture')",[carrier,country]);
    await owner.query("INSERT INTO public.carrier_rules(id,carrier_id,minimum_topup_amount,inactivity_limit_days,rule_type,topup_validity_days) VALUES($1,$2,1,90,'prepaid',90)",[rule,carrier]);
    await owner.query("INSERT INTO public.sim_lines(id,user_id,phone_number,carrier_id,carrier_rule_id) VALUES($1,$2,'+15550001001',$3,$4)",[l,u,carrier,rule]);
    await owner.query('SELECT public.ensure_wallet_v2($1)',[u]);
    await owner.query("SELECT public.credit_wallet_for_deposit($1::uuid,$2,'fixture',$3,jsonb_build_object('paypal_capture_id',$1::text))",[u,balance,'paypal_'+u]);
    const fee=plan==='premium'?5:2.5,refill=plan==='premium'?1:0;
    await claim(one,u);
    const quote=await scalar(one,"SELECT public.quote_sim_setup('+15550001001',$1,$2,$3)",[plan,rule,l]);
    const created=await scalar(one,"SELECT public.create_sim_setup_order(p_phone_number=>'+15550001001',p_plan=>$1,p_carrier_rule_id=>$2,p_sim_line_id=>$3)",[plan,rule,l]);
    const o=created.order_id;
    assert.equal(Number(quote.total_charge_usd),fee+refill);
    assert.equal(Number(created.total_charge_usd),Number(quote.total_charge_usd));
    assert.equal((await scalar(one,'SELECT public.reserve_sim_setup_holds($1)',[o])).success,true);
    const holds=(await owner.query('SELECT annual_fee_hold_id AS fee,first_refill_hold_id AS refill FROM public.sim_setup_orders WHERE id=$1',[o])).rows[0];
    return {u,l,o,e,rule,holds,balance,fee,refill};
  }
  async function dispatch(f){
    await claim(one,f.u);
    const r=await scalar(one,'SELECT public.dispatch_sim_setup_verification($1,$2)',[f.o,f.l]);
    f.e=r.execution_id;return r;
  }
  async function submit(f){await claim(one,f.u,'service_role');await one.query('SELECT public.begin_refill_submission($1,$2)',[f.e,f.holds.refill]);}
  async function settle(f){return scalar(one,"SELECT public.settle_instant_refill_execution($1,$2,$3,'1234','serial','Dial code')",[f.e,'provider_'+f.e,f.holds.refill]);}
  async function balance(f){return Number(await scalar(owner,'SELECT balance FROM public.wallets WHERE user_id=$1',[f.u]));}

  await owner.query("INSERT INTO public.app_fee_rules(appfees_item,version,free_percentage,free_minimum,stand_percentage,stand_minimum,prem_percentage,prem_minimum,status) VALUES('refills',9999999,0,0,0,0,0,0,'published') ON CONFLICT DO NOTHING");
  await check('setup API catalog has one compatible overload and restrictive internal grants',async()=>{
    await owner.query('RESET ROLE');
    const rows=(await owner.query("SELECT oid::regprocedure::text AS signature,proargnames,pronargdefaults FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname='finalize_sim_setup_order'")).rows;
    assert.equal(rows.length,1);assert.deepEqual(rows[0].proargnames,['p_order_id','p_sim_line_id']);assert.equal(rows[0].pronargdefaults,1);
    for(const role of ['anon','authenticated'])for(const fn of ['begin_refill_submission(uuid,uuid)','settle_instant_refill_execution(uuid,text,uuid,text,text,text,jsonb)','fail_instant_refill_before_submission(uuid,uuid,text)','assert_instant_refill_reservation(uuid,uuid)']){
      assert.equal(await scalar(owner,'SELECT has_function_privilege($1,$2,\'EXECUTE\')',[role,'public.'+fn]),false);
    }
  });
  for(const amount of [6,20])await check(`Premium setup with balance ${amount} charges one fee/refill and supports both finalizer call shapes`,async()=>{
    const f=await seed(amount);await dispatch(f);await dispatch(f);await submit(f);await settle(f);await settle(f);
    assert.equal(await balance(f),amount-1);
    await claim(one,f.u);assert.equal((await scalar(one,'SELECT public.finalize_sim_setup_order(p_order_id=>$1,p_sim_line_id=>$2)',[f.o,f.l])).success,true);
    assert.equal((await scalar(one,'SELECT public.finalize_sim_setup_order($1)',[f.o])).success,true);
    assert.equal(await balance(f),amount-6);
    assert.equal(Number(await scalar(owner,"SELECT count(*) FROM public.wallet_transactions WHERE user_id=$1 AND type IN ('topup_debit','plan_fee_debit')",[f.u])),2);
    assert.equal(Number(await scalar(owner,'SELECT count(*) FROM public.plan_payments WHERE order_id=$1',[f.o])),1);
    assert.equal(Number(await scalar(owner,'SELECT count(*) FROM public.scheduled_topups WHERE sim_line_id=$1',[f.l])),2);
    assert.equal(await scalar(owner,'SELECT pin_code FROM public.topup_executions WHERE id=$1',[f.e]),'1234');
    await claim(one,f.u,'service_role');await assert.rejects(()=>scalar(one,'SELECT public.settle_instant_refill_execution($1,$2,$3)',[f.e,'different-provider',f.holds.refill]),/identity mismatch/);
    assert.equal(await balance(f),amount-6);
  });
  await check('completed/failed orders reject foreign owner and foreign or differently bound line before returns',async()=>{
    const f=await seed(10,'standard'),foreign=await seed(10,'standard');
    await claim(one,f.u);await one.query('SELECT public.finalize_sim_setup_order($1)',[f.o]);
    await owner.query('RESET ROLE');await owner.query("UPDATE public.sim_setup_orders SET status='failed' WHERE id=$1",[foreign.o]);
    await claim(one,f.u);await assert.rejects(()=>one.query('SELECT public.finalize_sim_setup_order($1)',[foreign.o]),/unavailable/);
    await claim(one,foreign.u);await assert.rejects(()=>one.query('SELECT public.finalize_sim_setup_order($1)',[f.o]),/unavailable/);
    await claim(one,f.u);await assert.rejects(()=>one.query('SELECT public.finalize_sim_setup_order($1,$2)',[f.o,foreign.l]),/another line/);
    await assert.rejects(()=>one.query("SELECT public.fallback_sim_setup_to_reminders($1,$2,'standard')",[f.o,foreign.l]),/owned SIM/);
    await claim(one,f.u,'anon');await assert.rejects(()=>one.query('SELECT public.finalize_sim_setup_order($1)',[f.o]),/permission denied/);
  });
  await check('before-submit failure releases safely; Standard/free fallback uses current canonical interface',async()=>{
    for(const plan of ['standard','free']){
      const f=await seed(6);await dispatch(f);await claim(one,f.u,'service_role');
      assert.equal((await scalar(one,"SELECT public.fail_instant_refill_before_submission($1,$2,'catalog rejected')",[f.e,f.holds.refill])).success,true);
      await claim(one,f.u);assert.equal((await scalar(one,'SELECT public.finalize_sim_setup_order($1)',[f.o])).status,'failed');
      await owner.query('RESET ROLE');
      const fee=plan==='free'?0:Number(await scalar(owner,"SELECT public.membership_fee_usd('standard')"));
      await claim(one,f.u);
      const r=await scalar(one,'SELECT public.fallback_sim_setup_to_reminders($1,$2,$3)',[f.o,f.l,plan]);assert.equal(r.success,true);
      assert.equal((await scalar(one,'SELECT public.fallback_sim_setup_to_reminders($1,$2,$3)',[f.o,f.l,plan])).success,true);
      assert.equal(await balance(f),6-fee);
      assert.equal(Number(await scalar(owner,"SELECT count(*) FROM public.scheduled_topups WHERE sim_line_id=$1 AND is_active AND schedule_type='notify'",[f.l])),1);
      assert.equal(Number(await scalar(owner,"SELECT count(*) FROM public.wallet_holds WHERE user_id=$1 AND status='active'",[f.u])),0);
    }
  });
  await check('ambiguous submission rejects stale failure, cancellation, finalizer release and fallback',async()=>{
    const f=await seed(6);await dispatch(f);await submit(f);
    assert.equal((await scalar(one,"SELECT public.fail_instant_refill_before_submission($1,$2,'stale worker')",[f.e,f.holds.refill])).reconciliation_required,true);
    await owner.query("UPDATE public.topup_executions SET status='failed' WHERE id=$1",[f.e]);
    await claim(one,f.u);assert.equal((await scalar(one,'SELECT public.finalize_sim_setup_order($1)',[f.o])).pending,true);
    await assert.rejects(()=>one.query("SELECT public.fallback_sim_setup_to_reminders($1,$2,'free')",[f.o,f.l]),/reconciliation/);
    await assert.rejects(()=>one.query('SELECT public.cancel_sim_setup_order($1)',[f.o]),/reconciliation/);
    assert.equal(await scalar(owner,'SELECT status FROM public.wallet_holds WHERE id=$1',[f.holds.refill]),'active');
    assert.equal(await balance(f),6);
    await claim(one,f.u,'service_role');await settle(f);
  });
  await check('fallback insufficient funds remains retryable without retaining old reservations',async()=>{
    const f=await seed(6);await dispatch(f);await claim(one,f.u,'service_role');
    await scalar(one,"SELECT public.fail_instant_refill_before_submission($1,$2,'preflight failed')",[f.e,f.holds.refill]);
    await claim(one,f.u);await one.query('SELECT public.finalize_sim_setup_order($1)',[f.o]);
    await claim(one,f.u,'service_role');
    const competing=await scalar(one,"SELECT public.reserve_wallet_funds($1,5,'refill_instant',$2)",[f.u,uuid()]);
    await claim(one,f.u);const r=await scalar(one,"SELECT public.fallback_sim_setup_to_reminders($1,$2,'standard')",[f.o,f.l]);
    assert.equal(r.code,'insufficient_funds');assert.equal(await balance(f),6);
    await claim(one,f.u,'service_role');await one.query('SELECT public.release_wallet_hold($1)',[competing]);
    await claim(one,f.u);assert.equal((await scalar(one,"SELECT public.fallback_sim_setup_to_reminders($1,$2,'standard')",[f.o,f.l])).success,true);
    assert.equal(await balance(f),6-Number(await scalar(owner,'SELECT annual_fee_usd FROM public.sim_setup_orders WHERE id=$1',[f.o])));
  });
  await check('reservation rejects wrong owner/wallet/currency/amount/purpose/reference/released/expired/legacy before submission',async()=>{
    const f=await seed(20);await dispatch(f);const foreign=await seed(20);
    const mutations=[
      ['user_id=$2',foreign.u],['wallet_id=(SELECT id FROM public.wallets WHERE user_id=$2)',foreign.u],
      ["currency='EUR'"],['amount=amount+1'],["order_type='plan_fee'"],["order_reference_id='another-order'"],
      ["status='released'"],["expires_at=now()-interval '1 hour'"],['recovery_contract_version=0']
    ];
    for(const [mutation,arg] of mutations){
      await owner.query('RESET ROLE');await owner.query('BEGIN');
      try{
        await owner.query('UPDATE public.wallet_holds SET '+mutation+' WHERE id=$1',arg?[f.holds.refill,arg]:[f.holds.refill]);
        await claim(owner,f.u,'service_role');
        await assert.rejects(()=>owner.query('SELECT public.begin_refill_submission($1,$2)',[f.e,f.holds.refill]),/reservation|binding/);
      }finally{await owner.query('ROLLBACK');await owner.query('RESET ROLE');}
    }
    await claim(one,f.u,'service_role');await assert.rejects(()=>one.query('SELECT public.begin_refill_submission($1,NULL)',[f.e]),/reservation/);
    assert.equal(await scalar(owner,'SELECT carrier_in_flight FROM public.topup_executions WHERE id=$1',[f.e]),false);
  });
  await check('settlement requires committed submission and revalidates the hold on delivery',async()=>{
    const f=await seed(6);await dispatch(f);await claim(one,f.u,'service_role');
    await assert.rejects(()=>settle(f),/submission required/);await submit(f);
    await owner.query('RESET ROLE');await owner.query("UPDATE public.wallet_holds SET currency='EUR' WHERE id=$1",[f.holds.refill]);
    await claim(one,f.u,'service_role');await assert.rejects(()=>settle(f),/reservation/);
    assert.equal(await balance(f),6);
    await owner.query("UPDATE public.wallet_holds SET currency='USD' WHERE id=$1",[f.holds.refill]);await settle(f);
    assert.equal(await balance(f),5);
  });
  await check('fee/receipt/schedules rollback together when schedule write fails, then retry once',async()=>{
    const f=await seed(6);await dispatch(f);await submit(f);await settle(f);
    await owner.query('RESET ROLE');
    await owner.query("CREATE FUNCTION public.task9_reject_schedule() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'synthetic schedule failure'; END; $$");
    await owner.query('CREATE TRIGGER task9_reject_schedule BEFORE INSERT ON public.scheduled_topups FOR EACH ROW EXECUTE FUNCTION public.task9_reject_schedule()');
    try{await claim(one,f.u);await assert.rejects(()=>one.query('SELECT public.finalize_sim_setup_order($1)',[f.o]),/synthetic schedule failure/);
      assert.equal(await balance(f),5);assert.equal(Number(await scalar(owner,'SELECT count(*) FROM public.plan_payments WHERE order_id=$1',[f.o])),0);
    }finally{await owner.query('RESET ROLE');await owner.query('DROP TRIGGER task9_reject_schedule ON public.scheduled_topups');await owner.query('DROP FUNCTION public.task9_reject_schedule()');}
    await claim(one,f.u);await one.query('SELECT public.finalize_sim_setup_order($1)',[f.o]);assert.equal(await balance(f),0);
  });
  if(one!==two){
    await check('concurrent Premium finalizers and duplicate settlement charge one fee and one refill',async()=>{
      const f=await seed(6);await dispatch(f);await submit(f);await claim(two,f.u,'service_role');
      await Promise.all([one,two].map(c=>scalar(c,'SELECT public.settle_instant_refill_execution($1,$2,$3)',[f.e,'provider_'+f.e,f.holds.refill])));
      for(const c of [one,two])await claim(c,f.u);
      const r=await Promise.all([one,two].map(c=>scalar(c,'SELECT public.finalize_sim_setup_order($1,$2)',[f.o,f.l])));assert.ok(r.every(x=>x.success));
      assert.equal(await balance(f),0);assert.equal(Number(await scalar(owner,'SELECT count(*) FROM public.plan_payments WHERE order_id=$1',[f.o])),1);
    });
    await check('concurrent submission vs fallback cannot release a supplier reservation',async()=>{
      const f=await seed(6);await dispatch(f);await claim(one,f.u,'service_role');await claim(two,f.u);
      await owner.query("UPDATE public.sim_setup_orders SET status='reserved' WHERE id=$1",[f.o]);
      const r=await Promise.allSettled([one.query('SELECT public.begin_refill_submission($1,$2)',[f.e,f.holds.refill]),two.query("SELECT public.fallback_sim_setup_to_reminders($1,$2,'free')",[f.o,f.l])]);
      assert.equal(r.filter(x=>x.status==='fulfilled').length,1);
      assert.equal(await scalar(owner,'SELECT status FROM public.wallet_holds WHERE id=$1',[f.holds.refill]),r[0].status==='fulfilled'?'active':'released');
      assert.equal(await scalar(owner,'SELECT carrier_in_flight FROM public.topup_executions WHERE id=$1',[f.e]),r[0].status==='fulfilled');
    });
  }
  await owner.query('RESET ROLE');
}
