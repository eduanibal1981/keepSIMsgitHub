'use strict';
const {dailyIntent,validateDailyPackage}=require('./providers/esimaccess_daily');
const {submitFixedRecharge}=require('./providers/esimaccess_recharge');
const {requestEsimAccess}=require('./providers/esimaccess');
const {resolveEsimAccessCredentials}=require('./providers/esimaccess_credentials');
const {limitedFetch}=require('./esim_supplier_limiter');
const {createReceiptJournal}=require('./esim_receipt_journal');
function createRechargeSettlement({supabase,accountKey='primary',fetchImpl=fetch,journal=createReceiptJournal(),logger=console}) {
  const rpc=async(name,params={})=>{const r=await supabase.rpc(name,params);if(r.error)throw Object.assign(Error('ESIM_DATABASE_UNAVAILABLE'),{code:'ESIM_DATABASE_UNAVAILABLE'});return r.data;};
  const request=limitedFetch(supabase,accountKey,fetchImpl);
  const checkpoint=(job,code)=>rpc('service_esim_order_checkpoint',{p_order_id:job.order_id,p_lease:job.lease,p_error_code:code});
  const refuse=(job,code)=>rpc('service_esim_fail_before_submit',{p_order_id:job.order_id,p_lease:job.lease,p_code:code});
  const persist=async entry=>{
    if(entry.kind==='purchase_reference') {
      const adopted=await rpc('service_esim_adopt_purchase_reference',{p_order_id:entry.order_id,p_submission_ref:entry.submission_ref,p_provider_order_ref:entry.provider_order_ref});
      if(adopted!==true)throw Error('Unproven purchase reference');return;
    }
    await rpc('service_esim_record_topup_receipt',{p_order_id:entry.order_id,p_submission_ref:entry.submission_ref,p_receipt:entry.receipt});
    const result=await rpc('service_esim_settle_topup',{p_order_id:entry.order_id});
    if(!result?.completed)throw Error('Incomplete settlement');
  };
  async function recoverReceipts(){
    let count=0;
    for(const entry of journal.list()) {
      try {await persist(entry);journal.remove(entry.order_id);count++;}
      catch(_){logger.warn('[esim-settlement] Confirmed receipt retained for recovery');}
    }
    return count;
  }
  async function savePurchaseReference(job,ref) {
    const entry={kind:'purchase_reference',order_id:job.order_id,submission_ref:job.submission_ref,provider_order_ref:ref};
    let saved=false;
    try{journal.write(entry);saved=true;}catch(_){logger.warn('[esim-settlement] Purchase reference journal unavailable');}
    try{await persist(entry);if(saved)journal.remove(entry.order_id);}catch(_){logger.warn('[esim-settlement] Purchase reference retained for recovery');}
  }
  async function process(job) {
    if(job.state!=='prepared') {
      if(job.has_receipt) {await rpc('service_esim_settle_topup',{p_order_id:job.order_id});return;}
      // No documented transaction lookup exists for lost top-up responses.
      // Provider profile totals cannot prove this operation or authorize replay.
      await checkpoint(job,'EXACT_TOPUP_RECEIPT_REQUIRED');return;
    }
    let credentials;
    try{journal.ready();}catch(_){await refuse(job,'JOURNAL_UNAVAILABLE');return;}
    try{credentials=await resolveEsimAccessCredentials(supabase);if(!credentials.accessCode)throw Error();}
    catch(_){await refuse(job,'CREDENTIALS_UNAVAILABLE');return;}
    // Fresh compatibility/wholesale validation before the durable submission marker.
    try {
      const list=await requestEsimAccess('/package/list',{type:'TOPUP',iccid:job.iccid},{...credentials,fetchImpl:request});
      const pkg=list.obj?.packageList?.find(p=>p.packageCode===job.bundle_name);
      const facts=job.catalogue_snapshot?.catalogue_details;
      const daily=dailyIntent(job);
      if(daily?!validateDailyPackage(pkg,job):(!pkg||!facts||pkg.currencyCode!=='USD'||Number(pkg.dataType)!==1||Number(pkg.price)!==Math.round(Number(job.wholesale_price_usd)*10000)||pkg.enabled===false||
        !Number.isSafeInteger(Number(pkg.volume))||Number(pkg.volume)<=0||Number(pkg.volume)!==Number(facts.allowance_bytes)||
        Number(pkg.duration)!==Number(facts.duration_value)||pkg.durationUnit!==facts.duration_unit)) {
        await refuse(job,'COMPATIBILITY_CHANGED');return;
      }
    }catch(_){await refuse(job,'COMPATIBILITY_CHANGED');return;}
    if(!await rpc('service_esim_mark_submitted',{p_order_id:job.order_id,p_lease:job.lease}))return;
    // Exactly one supplier POST. No library retries or timeout refunds.
    const result=await submitFixedRecharge(job,{...credentials,fetchImpl:request});
    if(result.outcome==='rejected') {
      await rpc('service_esim_record_rejection',{p_order_id:job.order_id,p_lease:job.lease,p_submission_ref:job.submission_ref,p_code:result.code});return;
    }
    if(result.outcome!=='success'){await checkpoint(job,result.code);return;}
    const entry={order_id:job.order_id,submission_ref:job.submission_ref,receipt:result.receipt};
    let saved=false;
    try{journal.write(entry);saved=true;}catch(_){logger.warn('[esim-settlement] Receipt journal unavailable after supplier confirmation');}
    // A SQL failure after success never becomes a failed order/refund.
    try{await persist(entry);if(saved)journal.remove(entry.order_id);}
    catch(_){logger.warn('[esim-settlement] Supplier confirmation pending durable settlement');}
  }
  return {process,recoverReceipts,savePurchaseReference,ready:()=>journal.ready()};
}
module.exports={createRechargeSettlement};
