const esimAccessBaseUrl = process.env.ESIM_ACCESS_BASE_URL || 'https://api.esimaccess.com/api/v1/open';

const ESIMACCESS_SPEED_TIER_MAP = {
  'fixed': 'fixed',
  'Fixed': 'fixed',
  '3G/4G': 'fixed',
  '4G': 'fixed',
  '4G/5G': 'plus',
  '5G': 'plus',
  'lite': 'lite',
  'Lite': 'lite',
  'essential': 'essential',
  'Essential': 'essential',
  'plus': 'plus',
  'Plus': 'plus',
  'Standard': 'fixed',
  'standard': 'fixed',
  'Fast': 'lite',
  'fast': 'lite',
  'Faster': 'essential',
  'faster': 'essential',
  'Fastest': 'plus',
  'fastest': 'plus',
  'long_duration': 'long_duration',
  'Long Duration': 'long_duration',
};

const { normalizeEsimAccessOffer, extractIsoCountries } = require('./esimaccess_catalog');

async function fetchEsimCatalog({
  baseUrl = esimAccessBaseUrl,
  accessCode,
  secretKey,
  locationCode,
  packageCode,
  slug,
  iccid,
  type = 'BASE',
  fetchImpl = fetch,
}) {
  if (!accessCode) {
    throw new Error('ESIM_ACCESS_ACCESS_CODE is required to fetch eSIM Access catalog');
  }

  const headers = {
    'RT-AccessCode': accessCode,
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  if (secretKey) {
    headers['secretKey'] = secretKey;
  }

  if (!['BASE', 'TOPUP'].includes(type)) throw new Error('Invalid catalogue discovery type');
  if (type === 'TOPUP' && !packageCode && !slug && !iccid) throw new Error('TOPUP requires a compatibility reference');
  const body = { type };
  if (locationCode) body.locationCode = locationCode;
  if (packageCode) body.packageCode = packageCode;
  if (slug) body.slug = slug;
  if (iccid) body.iccid = iccid;

  const res = await fetchImpl(`${baseUrl}/package/list`, {
    method: 'POST',
    headers,
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`eSIM Access Package List API returned HTTP ${res.status}: ${errText}`);
  }

  const json = await res.json();
  if (json.success !== true && json.success !== 'true') {
    throw new Error(`eSIM Access Package List API error [${json.errorCode}]: ${json.errorMsg || json.errorMessage}`);
  }

  if (!Array.isArray(json.obj?.packageList)) throw new Error('Invalid eSIM Access catalogue response');
  const packageList = json.obj.packageList;

  return {
    offers: packageList,
    complete: true,
    raw: json,
  };
}

const { normalizeProfile, normalizeUsage } = require('./esimaccess_profiles');

function providerError(code) {
  const error = new Error(code); error.code = code; return error;
}
async function requestEsimAccess(path, body, {baseUrl=esimAccessBaseUrl,accessCode,secretKey,fetchImpl=fetch}) {
  if (!accessCode) throw providerError('ESIM_CREDENTIALS_UNAVAILABLE');
  const headers={'RT-AccessCode':accessCode,'Content-Type':'application/json',Accept:'application/json'};
  if(secretKey)headers.secretKey=secretKey;
  let response,json;
  try { response=await fetchImpl(`${baseUrl}${path}`,{method:'POST',headers,body:JSON.stringify(body),signal:AbortSignal.timeout(20000)});
    json=await response.json();
  } catch (_) { throw providerError('ESIM_PROVIDER_UNCERTAIN'); }
  if(!response.ok)throw providerError(`ESIM_PROVIDER_HTTP_${response.status}`);
  if(json.success!==true&&json.success!=='true') {
    const code=/^[0-9]{1,12}$/.test(String(json.errorCode))?String(json.errorCode):'UNKNOWN';
    throw providerError('ESIM_PROVIDER_'+code);
  }
  return json;
}
async function purchaseEsim({packageCode,quantity=1,price,transactionId,periodNum,...options}) {
  if(!packageCode||!transactionId||transactionId.length>50||!Number.isInteger(quantity)||quantity<1||quantity>3)throw providerError('ESIM_INVALID_INTENT');
  if(periodNum!=null&&(!Number.isInteger(periodNum)||periodNum<1||periodNum>365))throw providerError('ESIM_INVALID_INTENT');
  const info={packageCode,count:quantity,...(periodNum!=null?{periodNum}:{})};
  if(periodNum==null&&typeof price==='number'&&Number.isFinite(price)&&price>0)info.price=Math.round(price*10000);
  const json=await requestEsimAccess('/esim/order',{transactionId,packageInfoList:[info],...(Number.isFinite(price)&&price>0?{amount:Math.round(price*10000)*quantity}:{})},options);
  const orderNo=typeof json.obj?.orderNo==='string'&&json.obj.orderNo.trim()?json.obj.orderNo.trim():null;
  // No retry, broad first-page adoption, fabricated order reference or refund.
  return {orderNo,transactionId,status:orderNo?'ACCEPTED':'UNKNOWN'};
}
async function queryProfiles({orderNo,esimTranNo,iccid,maxPages=10,...options}) {
  if(!orderNo&&!esimTranNo&&!iccid)throw providerError('ESIM_EXACT_REFERENCE_REQUIRED');
  const items=[];
  for(let page=1;page<=maxPages;page++) {
    let json;
    try { json=await requestEsimAccess('/esim/query',{...(orderNo?{orderNo}:esimTranNo?{esimTranNo}:{iccid}),pager:{pageNum:page,pageSize:100}},options); }
    catch(error){if(error.code==='ESIM_PROVIDER_200010')return {esimList:[],complete:false,pending:true};throw error;}
    const list=json.obj?.esimList;
    if(!Array.isArray(list))throw providerError('ESIM_PROFILE_RESPONSE_INVALID');
    if(list.some(item=>orderNo?item.orderNo!==orderNo:esimTranNo?item.esimTranNo!==esimTranNo:item.iccid!==iccid))throw providerError('ESIM_PROFILE_REFERENCE_MISMATCH');
    items.push(...list);
    const total=Number(json.obj?.pager?.total);
    if((Number.isFinite(total)&&items.length>=total)||list.length<100)return {esimList:items,complete:true};
  }
  return {esimList:items,complete:false};
}
async function pollEsimOrderStatus({orderNo,transactionId,maxPolls=15,pollDelayMs=2500,...options}) {
  if(!orderNo)return {status:'RECONCILING',isSuccess:false,isFailed:false,esimList:[]};
  let items=[];
  for(let i=0;i<maxPolls;i++) {
    if(i||pollDelayMs)await new Promise(resolve=>setTimeout(resolve,pollDelayMs));
    try {
      const response=await queryProfiles({orderNo,...options});items=response.esimList;
      if(response.complete&&items.length&&items.every(item=>normalizeProfile(item)?.issuance_proven))return {status:'COMPLETED',isSuccess:true,isFailed:false,esimList:items};
    } catch(_) { /* A lookup failure is uncertainty, never definitive allocation failure. */ }
  }
  return {status:'RECONCILING',isSuccess:false,isFailed:false,esimList:items};
}
async function getEsimUsage({esimTranNo,iccid,...options}) {
  try {
    if(esimTranNo) {
      const json=await requestEsimAccess('/esim/usage/query',{esimTranNoList:[String(esimTranNo)]},options);
      const list=json.obj?.esimUsageList;
      if(!Array.isArray(list))return null;
      const item=list.find(item=>String(item.esimTranNo)===String(esimTranNo));
      const usage=normalizeUsage(item,String(esimTranNo));
      if(!usage)return null;
      return {...usage,dataTotalMb:Math.floor(usage.data_total_bytes/1048576),dataUsageMb:Math.floor(usage.data_used_bytes/1048576),dataRemainingMb:Math.floor(usage.data_remaining_bytes/1048576)};
    }
    if(iccid) {
      const response=await queryProfiles({iccid,...options});
      if(response.esimList.length!==1)return null;
      const profile=normalizeProfile(response.esimList[0]);
      if(!profile||profile.data_total_bytes===null||profile.data_used_bytes===null)return null;
      return {...profile,dataTotalMb:Math.floor(profile.data_total_bytes/1048576),dataUsageMb:Math.floor(profile.data_used_bytes/1048576),dataRemainingMb:Math.floor(profile.data_remaining_bytes/1048576)};
    }
  }catch(_){return null;}
  return null;
}

module.exports = {
  ESIMACCESS_SPEED_TIER_MAP,
  extractIsoCountries,
  normalizeEsimAccessOffer,
  fetchEsimCatalog,
  purchaseEsim,
  queryProfiles,
  requestEsimAccess,
  pollEsimOrderStatus,
  getEsimUsage,
};

