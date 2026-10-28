'use strict';
// Standard API contract reviewed 2026-10-28. No undocumented lookup/retry.
const {requestEsimAccess}=require('./esimaccess');
const text=x=>typeof x==='string'&&x.trim()?x.trim():null;
const bytes=x=>x!==null&&x!==undefined&&x!==''&&typeof x!=='boolean'&&Number.isSafeInteger(Number(x))&&Number(x)>=0?Number(x):null;
const rejected=new Set(['200005','200006','200007','200008','310241','310243']);
function normalizeReceipt(obj,job) {
  const expires=text(obj?.expiredTime),total=bytes(obj?.totalVolume),used=bytes(obj?.orderUsage),ref=text(obj?.topUpEsimTranNo);
  if(!obj||obj.transactionId!==job.submission_ref||obj.iccid!==job.iccid||!ref||ref.length>100||
    !expires||!Number.isFinite(Date.parse(expires))||total===null||used===null||used>total)return null;
  return {outcome:'success',source:'authenticated_inline_response',transaction_id:job.submission_ref,
    supplier_profile_ref:job.supplier_profile_ref,iccid:job.iccid,package_id:job.bundle_name,
    topup_ref:ref,expires_at:new Date(expires).toISOString(),total_bytes:String(total),used_bytes:String(used)};
}
async function submitFixedRecharge(job,options) {
  const amount=Math.round(Number(job.wholesale_price_usd)*10000);
  if(!job.supplier_profile_ref||!/^\d{15,22}$/.test(job.iccid||'')||!job.bundle_name||
    !job.submission_ref||job.submission_ref.length>50||!Number.isSafeInteger(amount)||amount<=0)
    throw Object.assign(new Error('Invalid recharge intent'),{code:'ESIM_INVALID_INTENT'});
  try {
    const result=await requestEsimAccess('/esim/topup',{esimTranNo:job.supplier_profile_ref,
      packageCode:job.bundle_name,transactionId:job.submission_ref,amount:String(amount)},options);
    const receipt=normalizeReceipt(result.obj,job);
    return receipt?{outcome:'success',receipt}:{outcome:'unknown',code:'UNPROVEN_TOPUP_RECEIPT'};
  }catch(e) {
    const code=String(e?.code||'').replace(/^ESIM_PROVIDER_/,'');
    return rejected.has(code)?{outcome:'rejected',code}:{outcome:'unknown',code:'TOPUP_OUTCOME_UNKNOWN'};
  }
}
module.exports={normalizeReceipt,submitFixedRecharge};
