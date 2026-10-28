try { require('dotenv').config({path:require('path').join(__dirname,'.env'),quiet:true}); } catch (_) {}
const {activation,normalizeProfile}=require('./providers/esimaccess_profiles');
const {createEsimRuntime}=require('./esim_fulfillment_runtime');
function assembleLpaString(address,matching){return activation(null,String(address||'').replace(/^LPA:1\$/,''),matching)?.lpa_string||'';}
function formatOrderPayload(order,isValidate=false){return {type:isValidate?'validate':'transaction',assign:true,Order:[{type:'bundle',item:order.bundle_name,quantity:Number(order.quantity)||1}]};}
function bind(item,order,provider){return {...item,user_id:order.user_id,order_id:order.id,bundle_name:order.bundle_name,provider,purchased_at:order.created_at||null};}
function parseEsimGoOrderResponse(json,order){return (Array.isArray(json?.esims)?json.esims:[]).map(item=>{
 const credentials=activation(null,item.smdpAddress||item.smdp_address,item.matchingId||item.matching_id);
 return item.iccid&&credentials?bind({...credentials,iccid:item.iccid,profile_state:'unknown'},order,'esim_go'):null;
}).filter(Boolean);}
function parseZenditOrderConfirmation(result,order){const item=result?.confirmation;if(!item?.iccid)return [];
 const credentials=activation(null,item.smdpAddress,item.matchingId||item.activationCode);
 return credentials?[bind({...credentials,iccid:item.iccid,profile_state:'unknown'},order,'zendit')]:[];}
function parseEsimAccessOrderConfirmation(result,order){return (result?.esimList||[]).map(item=>normalizeProfile(item)).filter(item=>item?.issuance_proven).map(item=>bind(item,order,'esimaccess'));}
let runtime;
function getRuntime(){if(!runtime){const {createClient}=require('@supabase/supabase-js');
 runtime=createEsimRuntime({supabase:createClient(process.env.SUPABASE_URL,process.env.SUPABASE_SERVICE_ROLE_KEY,{auth:{persistSession:false,autoRefreshToken:false}})});}return runtime;}
const processPendingOrders=()=>getRuntime().runOnce();
const pollEsimUsage=()=>getRuntime().runOnce({maxOrders:0,maxEvents:0});
if(require.main===module){console.log('[esim-runtime] Fulfillment, profile refresh and reconciliation started');processPendingOrders();setInterval(processPendingOrders,20000);}
module.exports={assembleLpaString,formatOrderPayload,parseEsimGoOrderResponse,parseZenditOrderConfirmation,parseEsimAccessOrderConfirmation,processPendingOrders,pollEsimUsage};
