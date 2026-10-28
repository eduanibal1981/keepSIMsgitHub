'use strict';
const sleep = ms => new Promise(resolve=>setTimeout(resolve,ms));
function limitedFetch(supabase, accountKey='primary', fetchImpl=fetch, wait=sleep) {
  return async (url, options) => {
    for (let attempt=0;attempt<120;attempt++) {
      const {data,error}=await supabase.rpc('service_esim_acquire_slot',{p_account_key:accountKey});
      if (error || !data) throw new Error('ESIM_LIMITER_UNAVAILABLE');
      if (data.granted===true) return fetchImpl(url,{...options,signal:options?.signal || AbortSignal.timeout(20000)});
      if (data.granted!==false) throw new Error('ESIM_LIMITER_UNAVAILABLE');
      await wait(Math.min(1000,Math.max(50,Number(data.retry_after_ms)||500)));
    }
    throw new Error('ESIM_LIMITER_BUSY');
  };
}
module.exports={limitedFetch};
