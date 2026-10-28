// The handler uses a customer JWT client. Service-role authority is never used.
export function createRechargeHandler({authenticate,call}) {
  const headers={'Content-Type':'application/json','Cache-Control':'no-store',
    'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, apikey, content-type, x-client-info',
    'Access-Control-Allow-Methods':'POST, OPTIONS'};
  const reply=(status,body)=>new Response(JSON.stringify(body),{status,headers});
  const uuid=v=>typeof v==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);
  return async request=>{
    if(request.method==='OPTIONS')return new Response(null,{status:204,headers});
    if(request.method!=='POST')return reply(405,{status:'METHOD_NOT_ALLOWED'});
    try {
      const auth=request.headers.get('authorization');
      if(!auth||!/^Bearer \S+$/.test(auth))return reply(401,{status:'AUTHENTICATION_REQUIRED'});
      const client=await authenticate(auth);
      if(!client)return reply(401,{status:'AUTHENTICATION_REQUIRED'});
      if(Number(request.headers.get('content-length')||0)>2048)return reply(413,{status:'INVALID_REQUEST'});
      const body=await request.text();if(body.length>2048)return reply(413,{status:'INVALID_REQUEST'});
      let b;try{b=JSON.parse(body);}catch(_){return reply(400,{status:'INVALID_REQUEST'});}
      if(!b||Array.isArray(b)||typeof b!=='object')return reply(400,{status:'INVALID_REQUEST'});
      let name,params;
      if(b.action==='quote_daily_purchase'&&typeof b.package_id==='string'&&b.package_id.length>0&&b.package_id.length<=100&&
        Number.isInteger(b.period_count)&&b.period_count>=1&&b.period_count<=365&&Number.isInteger(b.quantity)&&b.quantity>=1&&b.quantity<=3&&
        Object.keys(b).every(k=>['action','package_id','period_count','quantity'].includes(k))) {
        name='quote_esim_daily_purchase';params={p_offer_id:b.package_id,p_period_count:b.period_count,p_quantity:b.quantity};
      }else if(b.action==='quote_daily_extension'&&uuid(b.profile_id)&&uuid(b.offer_version)&&typeof b.package_id==='string'&&b.package_id.length>0&&b.package_id.length<=100&&
        Number.isInteger(b.period_count)&&b.period_count>=1&&b.period_count<=365&&
        Object.keys(b).every(k=>['action','profile_id','offer_version','package_id','period_count'].includes(k))) {
        name='quote_esim_daily_extension';params={p_profile_id:b.profile_id,p_package_id:b.package_id,p_offer_version:b.offer_version,p_period_count:b.period_count};
      }else if(b.action==='accept_daily_purchase'&&uuid(b.quote_id)&&uuid(b.acceptance_key)&&uuid(b.request_key)&&(b.device_id==null||uuid(b.device_id))&&
        Object.keys(b).every(k=>['action','quote_id','acceptance_key','request_key','device_id'].includes(k))) {
        name='accept_esim_daily_purchase';params={p_quote_id:b.quote_id,p_acceptance_key:b.acceptance_key,p_request_key:b.request_key,p_device_id:b.device_id??null};
      }else if(b.action==='discover'&&uuid(b.profile_id)&&Object.keys(b).every(k=>['action','profile_id'].includes(k))) {
        name='request_esim_topups';params={p_profile_id:b.profile_id};
      }else if(b.action==='quote'&&uuid(b.profile_id)&&uuid(b.offer_version)&&typeof b.package_id==='string'&&b.package_id.length>0&&b.package_id.length<=100&&
        typeof b.expected_total==='number'&&Number.isFinite(b.expected_total)&&b.expected_total>0&&
        Object.keys(b).every(k=>['action','profile_id','offer_version','package_id','expected_total'].includes(k))) {
        name='quote_esim_topup';params={p_profile_id:b.profile_id,p_package_id:b.package_id,p_offer_version:b.offer_version,p_expected_total:b.expected_total};
      }else if(b.action==='check'&&uuid(b.quote_id)&&Object.keys(b).every(k=>['action','quote_id'].includes(k))) {
        name='check_esim_topup_quote';params={p_quote_id:b.quote_id};
      }else if(b.action==='accept'&&uuid(b.quote_id)&&uuid(b.acceptance_key)&&(b.device_id==null||uuid(b.device_id))&&Object.keys(b).every(k=>['action','quote_id','acceptance_key','device_id'].includes(k))) {
        name='accept_esim_topup';params={p_quote_id:b.quote_id,p_acceptance_key:b.acceptance_key,p_device_id:b.device_id??null};
      }else if(b.action==='history'&&(b.profile_id==null||uuid(b.profile_id))&&Object.keys(b).every(k=>['action','profile_id'].includes(k))) {
        name='get_esim_operation_history';params={p_profile_id:b.profile_id??null};
      }else return reply(400,{status:'INVALID_REQUEST'});
      const result=await call(client,name,params);
      if(!result||result.error||result.data==null)return reply(503,{status:'TEMPORARILY_UNAVAILABLE'});
      return reply(200,result.data);
    }catch(_){return reply(503,{status:'TEMPORARILY_UNAVAILABLE'});}
  };
}
