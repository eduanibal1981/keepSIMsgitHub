'use strict';
// ESIM-07: only the exact owned profile's TOPUP catalogue. No purchase endpoint.
const {requestEsimAccess}=require('./providers/esimaccess');
const {resolveEsimAccessCredentials}=require('./providers/esimaccess_credentials');
const {limitedFetch}=require('./esim_supplier_limiter');
const text=v=>typeof v==='string'&&v.trim()?v.trim():null;
const integer=v=>typeof v==='number'&&Number.isSafeInteger(v)&&v>=0?v:null;
function normalizeTopups(items) {
  if(!Array.isArray(items)||items.length>500)throw Object.assign(new Error('ESIM_TOPUP_RESPONSE_INVALID'),{code:'ESIM_TOPUP_RESPONSE_INVALID'});
  const seen=new Set(),offers=[];
  for(const p of items) {
    const id=text(p?.packageCode),price=integer(p?.price),volume=integer(p?.volume),duration=integer(p?.duration);
    if(!id||id.length>100||seen.has(id)||p.currencyCode!=='USD'||price===null||price<=0||volume===null||
      duration===null||duration<1||duration>3660||!['DAY','HOUR'].includes(p.durationUnit)||![1,2,3,4].includes(p.dataType)||
      (p.type!=null&&p.type!=='TOPUP'))throw Object.assign(new Error('ESIM_TOPUP_RESPONSE_INVALID'),{code:'ESIM_TOPUP_RESPONSE_INVALID'});
    seen.add(id);
    if(p.enabled===false||(p.status!=null&&!['ACTIVE','NORMAL','ENABLED'].includes(p.status)))continue;
    offers.push({package_id:id,alias:text(p.slug)?.slice(0,100)||null,
      title:(text(p.name)||text(p.description)||id).slice(0,250),wholesale_usd:price/10000,
      currency:'USD',allowance_bytes:String(volume),data_type:p.dataType,duration_value:duration,duration_unit:p.durationUnit,
      // Fixed bundles add allowance and validity. Daily plans extend time; daily data does not stack.
      effect:p.dataType===1?'allowance_and_validity':'validity_only',
      quote_supported:p.dataType===1,discovery_type:'TOPUP'});
  }
  return offers;
}
function createRechargeDiscovery({supabase,accountKey='primary',fetchImpl=fetch}) {
  const fetchLimited=limitedFetch(supabase,accountKey,fetchImpl);
  const rpc=async(name,params={})=>{const r=await supabase.rpc(name,params);if(r.error)throw Object.assign(new Error('ESIM_DATABASE_UNAVAILABLE'),{code:'ESIM_DATABASE_UNAVAILABLE'});return r.data;};
  return async function run({maxJobs=3}={}) {
    let processed=0;
    for(let i=0;i<maxJobs;i++) {
      const job=await rpc('service_esim_claim_topups',{p_account_key:accountKey});
      if(!job)break;
      let offers=null,error=null;
      try {
        if(job.account_key!==accountKey||!/^\d{15,22}$/.test(job.iccid||'')||!job.supplier_profile_ref)
          throw Object.assign(new Error('ESIM_PROFILE_REFERENCE_INVALID'),{code:'ESIM_PROFILE_REFERENCE_INVALID'});
        const credentials=await resolveEsimAccessCredentials(supabase);
        const json=await requestEsimAccess('/package/list',{type:'TOPUP',iccid:job.iccid},
          {...credentials,fetchImpl:fetchLimited});
        offers=normalizeTopups(json.obj?.packageList);
      } catch(e) {error=/^[A-Z0-9_]{1,64}$/.test(e?.code||'')?e.code:'ESIM_TOPUP_UNAVAILABLE';}
      // Saving failure propagates: do not reinterpret it as a provider failure.
      await rpc('service_esim_save_topups',{p_profile_id:job.profile_id,p_lease:job.lease,p_offers:offers,p_error_code:error});
      processed++;
    }
    await rpc('prune_esim_topup_discovery');
    return processed;
  };
}
module.exports={normalizeTopups,createRechargeDiscovery};
