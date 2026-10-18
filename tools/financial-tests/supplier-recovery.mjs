import assert from 'node:assert/strict';
import { randomUUID as uuid } from 'node:crypto';
export async function runSupplierRecovery({owner,one=owner,two=owner},check){
  const scalar=async(c,sql,args=[])=>Object.values((await c.query(sql,args)).rows[0])[0];
  async function role(c,r='service_role'){
    await c.query('RESET ROLE'); if(r!=='none')await c.query('SET ROLE '+r);
    await c.query("SELECT set_config('request.jwt.claims',$1,false)",[r==='none'?'':JSON.stringify({role:r})]);
  }
  async function oq(sql,args=[]){await role(owner,'none');return owner.query(sql,args);}
  const route={provider:'dtone',offerId:'fixture-recovery',offerValue:200,costUsd:2,feeUsd:0,
    totalChargeUsd:2,targetLocalValue:2,targetLocalCurrency:'USD'};
  async function seed(type='refill_mini'){
    const u=uuid(),l=uuid(),e=uuid();
    await oq('INSERT INTO auth.users(id,email) VALUES($1,$2)',[u,u+'@fixture.test']);
    await oq('INSERT INTO public.profiles(id,email) VALUES($1,$2)',[u,u+'@fixture.test']);
    await oq("INSERT INTO public.sim_lines(id,user_id,phone_number,plan_type,plan_expires_at) VALUES($1,$2,'+15550001011','premium',now()+interval '1 year')",[l,u]);
    await oq('SELECT public.ensure_wallet_v2($1)',[u]);
    await oq("SELECT public.credit_wallet_for_deposit($1::uuid,20,'fixture',$2,jsonb_build_object('paypal_capture_id',$1::text))",[u,'paypal_'+u]);
    await oq("INSERT INTO public.topup_executions(id,user_id,sim_line_id,execution_type,status,amount,base_cost_usd,app_fee_usd,currency,payment_gateway_code,max_authorized_usd,fulfillment_gateway,api_provider) VALUES($1,$2,$3,$4,'processing',2,2,0,'USD','wallet',3,'API','dtone')",[e,u,l,type]);
    await role(one);
    let h;
    if(type==='refill_instant'){
      h=await scalar(one,"SELECT public.reserve_wallet_funds($1,2,'refill_instant',$2)",[u,e]);
      await oq('UPDATE public.topup_executions SET wallet_hold_id=$1 WHERE id=$2',[h,e]);
    }else h=(await scalar(one,'SELECT public.prepare_scheduled_refill($1,$2)',[e,route])).hold_id;
    return{u,l,e,h,type};
  }
  async function begin(f,c=one){await role(c);return c.query(f.type==='refill_instant'?'SELECT public.begin_refill_submission($1,$2)':'SELECT public.begin_scheduled_refill_submission($1,$2,$3)',f.type==='refill_instant'?[f.e,f.h]:[f.e,f.h,route]);}
  async function claim(f,c=one){await oq("UPDATE public.refill_supplier_submissions SET next_check_at=now()-interval '1 hour' WHERE execution_id=$1",[f.e]);await role(c);const rows=(await c.query('SELECT * FROM public.claim_refill_supplier_reconciliation(1)')).rows;assert.equal(rows.length,1);assert.equal(rows[0].execution_id,f.e);return rows[0];}
  async function finish(f,s,outcome='success',c=one,tx='provider_'+f.e){await role(c);return scalar(c,'SELECT public.complete_refill_supplier_reconciliation($1,$2,$3,$4,$5,$6,$7)',[f.e,s.claim_token,outcome,tx,'1234','serial','Dial code']);}
  async function state(f){return(await oq('SELECT e.status,h.status AS hold,w.balance::text,s.outcome,s.attempts FROM public.topup_executions e JOIN public.wallet_holds h ON h.id=e.wallet_hold_id JOIN public.wallets w ON w.id=h.wallet_id LEFT JOIN public.refill_supplier_submissions s ON s.execution_id=e.id WHERE e.id=$1',[f.e])).rows[0];}
  await oq("INSERT INTO public.payment_gateways(code,name) VALUES('wallet','Fixture') ON CONFLICT DO NOTHING");
  await oq("INSERT INTO public.app_fee_rules(appfees_item,version,free_percentage,free_minimum,stand_percentage,stand_minimum,prem_percentage,prem_minimum,status) VALUES('refills',9999999,0,0,0,0,0,0,'published') ON CONFLICT DO NOTHING");
  await check('recovery queue and RPCs deny customers, foreign users and direct provenance forgery',async()=>{
    for(const r of ['anon','authenticated']){
      for(const fn of ['claim_refill_supplier_reconciliation(integer)','complete_refill_supplier_reconciliation(uuid,uuid,text,text,text,text,text)','recover_expired_wallet_holds(integer)','reap_stuck_executions(integer,integer)'])
        assert.equal(await scalar(owner,"SELECT has_function_privilege($1,$2,'EXECUTE')",[r,'public.'+fn]),false);
      assert.equal(await scalar(owner,"SELECT has_table_privilege($1,'public.refill_supplier_submissions','SELECT')",[r]),false);
      await role(one,r);await assert.rejects(()=>one.query('SELECT public.claim_refill_supplier_reconciliation(1)'),/permission denied/);
      await role(owner,'none');
    }
    const f=await seed();await role(one,'authenticated');
    // Exercise the actual invoker trigger under the client role in isolation.
    await role(owner,'none');await owner.query('CREATE TEMP TABLE provenance_probe(id uuid,supplier_recovery_version smallint DEFAULT 2,supplier_recovery_required_at timestamptz)');
    await owner.query('GRANT INSERT,UPDATE,SELECT ON provenance_probe TO authenticated');
    await owner.query('CREATE TRIGGER probe BEFORE INSERT OR UPDATE ON provenance_probe FOR EACH ROW EXECUTE FUNCTION public.guard_supplier_recovery_version()');
    await role(owner,'authenticated');await owner.query('INSERT INTO provenance_probe(id,supplier_recovery_version) VALUES($1,2)',[f.e]);
    assert.equal(await scalar(owner,'SELECT supplier_recovery_version FROM provenance_probe'),0);
    await assert.rejects(()=>owner.query('UPDATE provenance_probe SET supplier_recovery_version=2'),/Server-owned/);
    await role(owner,'none');await owner.query('DROP TABLE provenance_probe');
  });
  for(const type of ['refill_instant','refill_mini','refill_custom'])await check(type+' recovers delivery after worker crash and captures exactly once',async()=>{
    const f=await seed(type);await begin(f);
    await assert.rejects(()=>finish(f,{claim_token:null}),/lease/);
    const s=await claim(f);
    assert.equal(s.external_reference,'dt_'+f.e);assert.equal(s.provider,'dtone');assert.equal(s.binding.hold_id,f.h);
    await oq("UPDATE public.wallet_holds SET expires_at=now()-interval '1 day' WHERE id=$1",[f.h]);
    assert.equal((await finish(f,s)).outcome,'success');assert.equal((await finish(f,s)).idempotent,true);
    await assert.rejects(()=>finish(f,s,'success',one,'conflicting'),/identity mismatch/);
    const row=await state(f);assert.equal(row.status,'success');assert.equal(row.hold,'captured');assert.equal(Number(row.balance),18);
    assert.equal(Number(await scalar(owner,"SELECT count(*) FROM public.wallet_transactions WHERE metadata->>'execution_id'=$1 AND type='topup_debit'",[f.e])),1);
  });
  await check('confirmed failed submission releases once and cannot later be captured',async()=>{
    const f=await seed();await begin(f);const s=await claim(f);
    assert.equal((await finish(f,s,'failed')).outcome,'failed');assert.equal((await finish(f,s,'failed')).idempotent,true);
    assert.equal((await state(f)).hold,'released');assert.equal(Number((await state(f)).balance),20);
    await role(one);await assert.rejects(()=>one.query('SELECT public.settle_successful_execution($1,$2)',[f.e,'provider_'+f.e]),/reservation/);
  });
  for(const outcome of ['unknown','pending'])await check(outcome+' after crash immediately before purchase remains reserved and cannot resubmit',async()=>{
    const f=await seed();await begin(f);const s=await claim(f);
    await assert.rejects(()=>begin(f),/reconciliation/);
    assert.equal((await finish(f,s,outcome)).outcome,outcome);
    await oq("UPDATE public.wallet_holds SET expires_at=now()-interval '1 hour' WHERE id=$1",[f.h]);
    await role(one);await one.query('SELECT public.recover_expired_wallet_holds(100)');
    assert.equal((await state(f)).hold,'active');assert.equal(Number((await state(f)).balance),20);
    // Quarantine this pending fixture so later claim tests are deterministic.
    await oq("UPDATE public.refill_supplier_submissions SET next_check_at=now()+interval '1 year' WHERE execution_id=$1",[f.e]);
  });
  await check('lost lookup completion is leased, then reclaimed; old token cannot settle',async()=>{
    const f=await seed();await begin(f);const stale=await claim(f);
    await role(one);assert.equal((await one.query('SELECT * FROM public.claim_refill_supplier_reconciliation(1)')).rows.length,0);
    await oq("UPDATE public.refill_supplier_submissions SET lease_until=now()-interval '1 second' WHERE execution_id=$1",[f.e]);
    const fresh=await claim(f);assert.notEqual(fresh.claim_token,stale.claim_token);
    await assert.rejects(()=>finish(f,stale),/lease/);await finish(f,fresh);
  });
  await check('binding drift and delivery settlement errors retain all money with one operator alert',async()=>{
    const f=await seed();await begin(f);const s=await claim(f);
    await oq("UPDATE public.topup_executions SET offer_id='changed' WHERE id=$1",[f.e]);
    assert.equal((await finish(f,s)).outcome,'operator');await finish(f,s);
    assert.equal((await state(f)).hold,'active');assert.equal(Number((await state(f)).balance),20);
    assert.equal(Number(await scalar(owner,"SELECT count(*) FROM public.system_alerts WHERE details->>'execution_id'=$1",[f.e])),1);
    const g=await seed();await begin(g);const q=await claim(g);
    await oq('DELETE FROM public.wallet_hold_allocations WHERE hold_id=$1',[g.h]);
    assert.equal((await finish(g,q)).outcome,'operator');assert.equal(Number((await state(g)).balance),20);
  });
  await check('conflicting failure after ordinary worker delivery cannot release or downgrade',async()=>{
    const f=await seed();await begin(f);await role(one);await one.query('SELECT public.settle_successful_execution($1,$2)',[f.e,'provider_'+f.e]);
    const s=await claim(f);assert.equal((await finish(f,s,'failed')).outcome,'operator');
    assert.equal((await state(f)).status,'success');assert.equal((await state(f)).hold,'captured');
  });
  await check('bounded retries including repeated crashes surface one operator item',async()=>{
    for(const crashed of [false,true]){
      const f=await seed();await begin(f);const s=await claim(f);
      await oq("UPDATE public.refill_supplier_submissions SET attempts=12 WHERE execution_id=$1",[f.e]);
      if(crashed){await oq("UPDATE public.refill_supplier_submissions SET lease_until=now()-interval '1 second' WHERE execution_id=$1",[f.e]);await role(one);await one.query('SELECT * FROM public.claim_refill_supplier_reconciliation(1)');}
      else await finish(f,s,'unknown');
      assert.equal((await state(f)).outcome,'operator');assert.equal((await state(f)).hold,'active');
      await role(one);await one.query('SELECT * FROM public.claim_refill_supplier_reconciliation(1)');
      assert.equal(Number(await scalar(owner,"SELECT count(*) FROM public.system_alerts WHERE details->>'execution_id'=$1",[f.e])),1);
    }
  });
  await check('legacy false flags and legacy holds never authorize retry, release or new submission',async()=>{
    for(const legacyHold of [false,true]){
      const f=await seed('refill_instant');
      await oq(legacyHold?'UPDATE public.wallet_holds SET recovery_contract_version=0 WHERE id=$1':'UPDATE public.topup_executions SET supplier_recovery_version=0 WHERE id=$1',[legacyHold?f.h:f.e]);
      await assert.rejects(()=>begin(f),/Legacy|reservation/);
      await oq("UPDATE public.topup_executions SET status='failed' WHERE id=$1",[f.e]);
      await oq("UPDATE public.wallet_holds SET expires_at=now()-interval '1 day' WHERE id=$1",[f.h]);
      await role(one);await one.query('SELECT public.recover_expired_wallet_holds(100)');assert.equal((await state(f)).hold,'active');
    }
  });
  await check('safe pre-submission expiry releases valid holds and preserves mismatched reservations',async()=>{
    for(const mismatched of [false,true]){
      const f=await seed();await oq("UPDATE public.topup_executions SET status='failed' WHERE id=$1",[f.e]);
      await oq("UPDATE public.wallet_holds SET expires_at=now()-interval '1 day'"+(mismatched?",order_reference_id='wrong'":'')+' WHERE id=$1',[f.h]);
      await role(one);await one.query('SELECT public.recover_expired_wallet_holds(100)');await one.query('SELECT public.recover_expired_wallet_holds(100)');
      assert.equal((await state(f)).hold,mismatched?'active':'released');assert.equal(Number((await state(f)).balance),20);
    }
  });
  await check('cron-role reaper bounds, safe retries and submitted rows never requeue',async()=>{
    const safe=await seed(),submitted=await seed(),legacy=await seed();await begin(submitted);
    await oq('UPDATE public.topup_executions SET supplier_recovery_version=0 WHERE id=$1',[legacy.e]);
    await oq("UPDATE public.topup_executions SET processing_since=now()-interval '1 hour' WHERE id=ANY($1)",[[safe.e,submitted.e,legacy.e]]);
    await role(owner,'none');await assert.rejects(()=>owner.query('SELECT public.reap_stuck_executions(0,0)'),/bounds/);
    await owner.query('SELECT public.reap_stuck_executions(10,3)');
    assert.equal((await state(safe)).status,'pending');assert.equal((await state(submitted)).status,'processing');assert.equal((await state(legacy)).status,'processing');
    assert.equal((await state(submitted)).hold,'active');assert.equal((await state(legacy)).hold,'active');
  });
  await check('active call and pending refund reservations stay held with deduplicated operator evidence',async()=>{
    const f=await seed();
    for(const kind of ['call_budget','refund_request']){
      await role(one);let h;
      if(kind==='refund_request'){
        await role(owner,'none');const refund=await scalar(owner,'SELECT public.request_wallet_refund_once($1,2,$2)',[f.u,'intent_'+uuid()]);
        h=refund.hold_id;
        const item=await scalar(owner,'SELECT id FROM public.wallet_refund_items WHERE refund_request_id=$1',[refund.refund_request_id]);
        await role(one);const claim=await scalar(one,'SELECT public.claim_wallet_refund_item($1)',[item]);
        await one.query('SELECT public.begin_wallet_refund_submission($1,$2)',[item,claim.claim_token]);
        await oq("UPDATE public.wallet_refund_items SET claimed_at=now()-interval '1 hour' WHERE id=$1",[item]);
      } else h=await scalar(one,'SELECT public.reserve_wallet_funds($1,2,$2,$3)',[f.u,kind,uuid()]);
      await oq("UPDATE public.wallet_holds SET expires_at=now()-interval '1 day' WHERE id=$1",[h]);
      await role(one);await one.query('SELECT public.recover_expired_wallet_holds(100)');await one.query('SELECT public.recover_expired_wallet_holds(100)');
      await role(owner,'none');assert.equal(await scalar(owner,'SELECT status FROM public.wallet_holds WHERE id=$1',[h]),'active');
      assert.equal(Number(await scalar(owner,"SELECT count(*) FROM public.system_alerts WHERE details->>'hold_id'=$1",[h])),1);
    }
  });
  await check('an unresolved sibling submission blocks a different execution on the same line',async()=>{
    const f=await seed();await begin(f);
    const e=uuid();await oq("INSERT INTO public.topup_executions(id,user_id,sim_line_id,execution_type,status,amount,base_cost_usd,app_fee_usd,currency,payment_gateway_code,max_authorized_usd,fulfillment_gateway) VALUES($1,$2,$3,'refill_custom','processing',2,2,0,'USD','wallet',3,'API')",[e,f.u,f.l]);
    await role(one);const h=(await scalar(one,'SELECT public.prepare_scheduled_refill($1,$2)',[e,route])).hold_id;
    await assert.rejects(()=>begin({e,h,type:'refill_custom'}),/Previous supplier/);
    const s=await claim(f);await finish(f,s,'success');
    await begin({e,h,type:'refill_custom'});
  });
  if(one!==owner&&two!==owner){
    await check('independent concurrent claims and duplicate completion settle one debit',async()=>{
      const f=await seed();await begin(f);await oq("UPDATE public.refill_supplier_submissions SET next_check_at=now()-interval '1 hour' WHERE execution_id=$1",[f.e]);
      await role(one);await role(two);const claimed=await Promise.all([one,two].map(c=>c.query('SELECT * FROM public.claim_refill_supplier_reconciliation(1)')));
      assert.equal(claimed.flatMap(r=>r.rows).length,1);const s=claimed.flatMap(r=>r.rows)[0];
      await Promise.all([finish(f,s,'success',one),finish(f,s,'success',two)]);assert.equal(Number((await state(f)).balance),18);
    });
    await check('independent expiry vs delivery settlement preserves delivered money',async()=>{
      const f=await seed();await begin(f);const s=await claim(f);await oq("UPDATE public.wallet_holds SET expires_at=now()-interval '1 day' WHERE id=$1",[f.h]);
      await role(two);await Promise.all([finish(f,s,'success',one),two.query('SELECT public.recover_expired_wallet_holds(100)')]);
      assert.equal((await state(f)).hold,'captured');assert.equal(Number((await state(f)).balance),18);
    });
  }
  await role(owner,'none');
}
