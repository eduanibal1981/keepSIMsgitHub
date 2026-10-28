import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.108.2';
import { createEsimEventHandler } from '../_shared/esimaccess-events.js';
const client=createClient(Deno.env.get('SUPABASE_URL')??'',Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')??'',
  {auth:{persistSession:false,autoRefreshToken:false}});
Deno.serve(createEsimEventHandler({
  getSecret:async()=>{
    const result=await client.rpc('get_internal_secret',{p_name:'esimaccess_event_secret'});
    if(result.error)throw new Error('Unavailable');return result.data;
  },
  acceptEvent:async(eventKey:string,event:Record<string,unknown>)=>{
    const result=await client.rpc('service_esim_accept_event',{p_account_key:'primary',p_event_key:eventKey,p_event:event});
    if(result.error)throw new Error('Unavailable');return result.data;
  },
}));
