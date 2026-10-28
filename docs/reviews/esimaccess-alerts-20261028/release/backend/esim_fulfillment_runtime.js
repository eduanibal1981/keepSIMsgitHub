'use strict';
const adapter=require('./providers/esimaccess');
const {normalizeProfile}=require('./providers/esimaccess_profiles');
const {resolveEsimAccessCredentials}=require('./providers/esimaccess_credentials');
const {limitedFetch}=require('./esim_supplier_limiter');
const safeCode=error=>/^[A-Z0-9_]{1,64}$/.test(error?.code||'')?error.code:'ESIM_REFRESH_UNCERTAIN';

function createEsimRuntime({supabase,accountKey='primary',fetchImpl=fetch,onHealth=()=>{},logger=console}) {
  const request=limitedFetch(supabase,accountKey,fetchImpl);
  const rpc=async(name,params={})=>{
    const result=await supabase.rpc(name,params);
    if(result.error)throw Object.assign(new Error('ESIM_DATABASE_UNAVAILABLE'),{code:'ESIM_DATABASE_UNAVAILABLE'});
    return result.data;
  };
  const options=async()=>({...await resolveEsimAccessCredentials(supabase),fetchImpl:request});
  const checkpoint=(job,ref,error)=>rpc('service_esim_order_checkpoint',{
    p_order_id:job.order_id,p_lease:job.lease,p_provider_order_ref:ref||null,p_error_code:error||null});

  async function processOrder(job) {
    let ref=job.provider_order_ref;
    try {
      if(job.state==='prepared') {
        const credentials=await options();
        if(!await rpc('service_esim_mark_submitted',{p_order_id:job.order_id,p_lease:job.lease})) {
          await checkpoint(job,null,'SUBMISSION_GATE_CLOSED');return;
        }
        const response=await adapter.purchaseEsim({...credentials,packageCode:job.bundle_name,quantity:job.quantity,
          price:Number(job.wholesale_price_usd),transactionId:job.submission_ref});
        ref=response.orderNo;
        // Persist the accepted reference before polling. Any persistence failure
        // is recovered read-only; this intent will never be submitted again.
        await checkpoint(job,ref,ref?null:'MISSING_PROVIDER_REFERENCE');return;
      }
      const lookupRef=ref||job.hinted_order_ref;
      if(!lookupRef){await checkpoint(job,null,'EXACT_LOOKUP_UNAVAILABLE');return;}
      const result=await adapter.queryProfiles({...await options(),orderNo:lookupRef});
      if(!ref && (!result.esimList.length || result.esimList.some(p=>p.transactionId!==job.submission_ref))) {
        await checkpoint(job,null,'UNPROVEN_RECOVERY_BINDING');return;
      }
      const profiles=result.esimList.map(item=>normalizeProfile(item)).filter(p=>p?.issuance_proven);
      if(!profiles.length){await checkpoint(job,ref,'ISSUANCE_PENDING');return;}
      await rpc('service_esim_save_issuance',{p_order_id:job.order_id,p_lease:job.lease,p_provider_order_ref:lookupRef,
        p_profiles:profiles,p_transaction_id:ref?null:job.submission_ref});
    } catch(error) {
      await checkpoint(job,ref,safeCode(error));
      // No provider body, ICCID, activation material or financial action in logs.
      logger.warn('[esim-runtime] Order retained for reconciliation',safeCode(error));
    }
  }
  async function processProfile(job) {
    try {
      const credentials=await options();
      const result=await adapter.queryProfiles({...credentials,esimTranNo:job.supplier_profile_ref});
      if(result.esimList.length!==1)throw Object.assign(new Error('PROFILE_NOT_FOUND'),{code:'PROFILE_NOT_FOUND'});
      const profile=normalizeProfile(result.esimList[0]);
      if(!profile)throw Object.assign(new Error('PROFILE_RESPONSE_INVALID'),{code:'PROFILE_RESPONSE_INVALID'});
      const usage=await adapter.getEsimUsage({...credentials,esimTranNo:job.supplier_profile_ref});
      const observation={...profile,data_total_bytes:null,data_used_bytes:null,data_remaining_bytes:null,...(usage||{})};
      await rpc('service_esim_apply_observation',{p_profile_id:job.id,p_lease:job.lease,p_observation:observation});
    }catch(error){
      await rpc('service_esim_apply_observation',{p_profile_id:job.id,p_lease:job.lease,p_error_code:safeCode(error)});
      logger.warn('[esim-runtime] Last-known profile retained',safeCode(error));
    }
  }
  let running=false;
  async function runOnce({maxOrders=5,maxProfiles=10,maxEvents=25}={}) {
    if(running)return {busy:true};running=true;onHealth('begin');
    const counts={orders:0,profiles:0,events:0,errors:0};
    try {
      for(let i=0;i<maxEvents;i++) {
        const job=await rpc('service_esim_claim_event',{p_account_key:accountKey});if(!job)break;
        await rpc('service_esim_process_event',{p_event_id:job.id,p_lease:job.lease});counts.events++;
      }
      for(let i=0;i<maxOrders;i++) {
        const job=await rpc('service_esim_claim_order',{p_account_key:accountKey});if(!job)break;
        await processOrder(job);counts.orders++;
      }
      for(let i=0;i<maxProfiles;i++) {
        const job=await rpc('service_esim_claim_profile',{p_account_key:accountKey});if(!job)break;
        await processProfile(job);counts.profiles++;
      }
      // Alerts derive only from saved authenticated observations, including
      // near-expiry time windows between provider refreshes. No provider sends.
      const alerts=await rpc('service_esim_emit_alerts');
      counts.alerts=alerts?.created||0;
    }catch(_){counts.errors++;logger.warn('[esim-runtime] Cycle deferred; durable leases retain work');}
    finally {
      try{await rpc('service_esim_heartbeat',{p_account_key:accountKey,p_counts:counts});}catch(_){counts.errors++;}
      onHealth(counts.errors?'fail':'success');running=false;
    }
    return counts;
  }
  return {runOnce,processOrder,processProfile};
}
module.exports={createEsimRuntime};
