'use strict';
const adapter=require('./providers/esimaccess');
const {normalizeProfile}=require('./providers/esimaccess_profiles');
const {resolveEsimAccessCredentials}=require('./providers/esimaccess_credentials');
const {limitedFetch}=require('./esim_supplier_limiter');
// A durable submission marker precedes exactly one POST. Recovery only queries
// the stable profile reference; generic success/empty obj never proves a refund.
function createProfileControls({supabase,accountKey='primary',fetchImpl=fetch,logger=console}) {
 const request=limitedFetch(supabase,accountKey,fetchImpl);
 const rpc=async(n,p={})=>{const r=await supabase.rpc(n,p);if(r.error)throw Error('ESIM_DATABASE_UNAVAILABLE');return r.data;};
 async function process(job){
  const base={p_operation_id:job.id,p_lease:job.lease};
  try {
   const options={...await resolveEsimAccessCredentials(supabase),fetchImpl:request};
   const observe=async()=>{
    const r=await adapter.queryProfiles({...options,esimTranNo:job.supplier_profile_ref});
    if(r.esimList.length!==1)throw Error('PROFILE_UNAVAILABLE');
    const p=normalizeProfile(r.esimList[0]);
    if(!p||p.supplier_profile_ref!==job.supplier_profile_ref||p.iccid!==job.iccid||p.provider_order_ref!==job.provider_order_ref)throw Error('PROFILE_BINDING_CHANGED');
    return p;
   };
   if(job.state==='prepared'){
    const before=await observe();
    if(!await rpc('service_esim_mark_control_submitted',{...base,p_observation:before}))return;
    // No retries, no transaction-id assumption, no permanent revoke endpoint.
    try{await adapter.requestEsimAccess('/esim/'+({cancel:'cancel',suspend:'suspend',resume:'unsuspend'})[job.action],{esimTranNo:job.supplier_profile_ref},options);}
    catch(_){/* A read-only query may still confirm an accepted request. */}
   }
   await rpc('service_esim_finish_control',{...base,p_observation:await observe()});
  }catch(_){
   await rpc('service_esim_finish_control',{...base,p_error_code:'CONTROL_OUTCOME_UNKNOWN'});
   logger.warn('[esim-controls] Outcome retained for read-only reconciliation');
  }
 }
 async function run(limit=3){let count=0;for(let i=0;i<limit;i++){const job=await rpc('service_esim_claim_control',{p_account_key:accountKey});if(!job)break;await process(job);count++;}return count;}
 return {process,run};
}
module.exports={createProfileControls};
