export async function acquireEsimSlot(client, accountKey='primary') {
  for(let attempt=0;attempt<120;attempt++) {
    const {data,error}=await client.rpc('service_esim_acquire_slot',{p_account_key:accountKey});
    if(error||!data)throw new Error('Supplier request coordination unavailable');
    if(data.granted===true)return;
    if(data.granted!==false)throw new Error('Supplier request coordination unavailable');
    await new Promise(resolve=>setTimeout(resolve,Math.min(1000,Math.max(50,Number(data.retry_after_ms)||500))));
  }
  throw new Error('Supplier request coordination busy');
}
