'use strict';
async function resolveEsimAccessCredentials(supabase, {
  envAccessCode=process.env.ESIM_ACCESS_ACCESS_CODE,
  envSecretKey=process.env.ESIM_ACCESS_SECRET_KEY,
}={}) {
  if(!supabase)return {accessCode:envAccessCode,secretKey:envSecretKey};
  const results=await Promise.all(['esim_access_access_code','esim_access_secret_key'].map(p_name=>supabase.rpc('get_internal_secret',{p_name})));
  if(results.some(r=>r.error))throw new Error('ESIM_CREDENTIAL_LOOKUP_FAILED');
  const values=results.map(r=>{
    if(r.data==null)return null;
    if(typeof r.data!=='string'||!r.data.trim())throw new Error('ESIM_CREDENTIALS_UNAVAILABLE');
    return r.data.trim();
  });
  return {accessCode:values[0]??envAccessCode,secretKey:values[1]??envSecretKey};
}
module.exports={resolveEsimAccessCredentials};
