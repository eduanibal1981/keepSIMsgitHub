import {createClient,type SupabaseClient} from 'https://esm.sh/@supabase/supabase-js@2.108.2';
import {createRechargeHandler} from '../_shared/esim-recharge-discovery.js';
const url=Deno.env.get('SUPABASE_URL')??'',key=Deno.env.get('SUPABASE_ANON_KEY')??'';
Deno.serve(createRechargeHandler({
 authenticate:async(authorization:string)=>{
  const client=createClient(url,key,{global:{headers:{Authorization:authorization}},auth:{persistSession:false,autoRefreshToken:false}});
  const {data,error}=await client.auth.getUser();return !error&&data.user?client:null;
 },
 call:(client:SupabaseClient,name:string,params:Record<string,unknown>)=>client.rpc(name,params),
}));
