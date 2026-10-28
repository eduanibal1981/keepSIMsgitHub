// Callback values only schedule authenticated refreshes. No direct state settlement.
const kinds=new Set(['ORDER_STATUS','ESIM_STATUS','DATA_USAGE','VALIDITY_USAGE','SMDP_EVENT']);
const reply=(status,body)=>new Response(JSON.stringify(body),{status,headers:{'content-type':'application/json','cache-control':'no-store'}});
function equalSecret(a,b) {
  if(typeof a!=='string'||typeof b!=='string'||a.length>512||b.length<32)return false;
  const x=new TextEncoder().encode(a),y=new TextEncoder().encode(b);let difference=x.length^y.length;
  for(let i=0;i<Math.max(x.length,y.length);i++)difference|=(x[i]||0)^(y[i]||0);
  return difference===0;
}
function canonical(value,depth=0) {
  if(depth>32)throw new Error('Invalid nesting');
  if(Array.isArray(value))return value.map(v=>canonical(v,depth+1));
  if(value&&typeof value==='object')return Object.fromEntries(Object.keys(value).sort().map(k=>[k,canonical(value[k],depth+1)]));
  return value;
}
export function createEsimEventHandler({getSecret,acceptEvent,cryptoImpl=crypto}) {
  return async req=>{
    if(req.method!=='POST')return reply(405,{error:'method_not_allowed'});
    const presented=req.headers.get('x-esimaccess-event-secret');
    if(!presented||presented.length>512)return reply(403,{error:'forbidden'});
    let secret;try{secret=await getSecret();}catch(_){return reply(503,{error:'unavailable'});}
    if(!secret)return reply(503,{error:'unavailable'});
    // Dedicated header capability avoids activation/credential material in URLs.
    if(!equalSecret(presented,secret))return reply(403,{error:'forbidden'});
    if(!req.headers.get('content-type')?.toLowerCase().startsWith('application/json'))return reply(415,{error:'invalid_content_type'});
    if(Number(req.headers.get('content-length'))>16384)return reply(413,{error:'too_large'});
    let body,eventKey;
    try {
      const reader=req.body?.getReader();if(!reader)throw new Error('Missing body');
      const chunks=[];let size=0;
      while(true){const part=await reader.read();if(part.done)break;size+=part.value.length;
        if(size>16384){await reader.cancel();return reply(413,{error:'too_large'});}chunks.push(part.value);}
      const bytes=new Uint8Array(size);let at=0;for(const chunk of chunks){bytes.set(chunk,at);at+=chunk.length;}
      body=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));
      eventKey=Array.from(new Uint8Array(await cryptoImpl.subtle.digest('SHA-256',new TextEncoder().encode(JSON.stringify(canonical(body)))))).map(v=>v.toString(16).padStart(2,'0')).join('');
    }catch(_){return reply(400,{error:'invalid_event'});}
    if(!body||!kinds.has(body.notifyType)||!body.content||Array.isArray(body.content)||typeof body.content!=='object')return reply(422,{error:'unsupported_event'});
    const value=v=>typeof v==='string'&&v.trim()&&v.length<=100?v.trim():null;
    const content=body.content;
    const state=value(content.esimStatus)||value(content.orderStatus)||value(content.smdpStatus);
    const event={kind:body.notifyType,order_ref:value(content.orderNo),submission_ref:value(content.transactionId),
      profile_ref:value(content.esimTranNo),iccid:value(content.iccid),state_hint:state&&/^[A-Z0-9_]{1,64}$/.test(state)?state:null};
    if(!event.order_ref&&!event.submission_ref&&!event.profile_ref&&!event.iccid)return reply(422,{error:'missing_reference'});
    try {
      const result=await acceptEvent(eventKey,event);
      if(result?.rate_limited)return reply(429,{error:'retry_later'});
      if(result?.accepted!==true)return reply(503,{error:'unavailable'});
      return reply(202,{accepted:true});
    }catch(_){return reply(503,{error:'unavailable'});}
  };
}
