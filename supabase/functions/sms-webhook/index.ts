import { EndpointError } from "../_shared/endpoint-auth.ts";
import { verifyTwilio, verifyTelnyx, webhookUrl } from "../_shared/webhook-auth.ts";
import { providerSecretClient, requireProviderSecret } from "../_shared/provider-secrets.ts";
import { SecondNumbers } from "../_shared/second-number.ts";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const url=Deno.env.get("SUPABASE_URL")!;
const key=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const service=new SecondNumbers(url,key);
const twiml=(inner="")=>new Response(`<?xml version="1.0" encoding="UTF-8"?><Response>${inner}</Response>`,
  {headers:{"Content-Type":"text/xml"},status:200});
const escapeXml=(s:string)=>s.replaceAll("&","&amp;").replaceAll("<","&lt;").replaceAll(">","&gt;").replaceAll('"',"&quot;").replaceAll("'","&apos;");

serve(async(req:Request)=>{
  if(req.method!=="POST")return new Response("Method not allowed",{status:405});
  try {
    const raw=await req.text();
    if(raw.length>100000)throw new EndpointError(413,"Message too large");
    let provider:string,from:string,to:string,body:string,id:string,received:string;
    let params:any;
    if(req.headers.has("telnyx-signature-ed25519")) {
      const publicKey=await service.config("TELNYX_PUBLIC_KEY");
      await verifyTelnyx(req,raw,publicKey);
      const event=JSON.parse(raw).data;
      if(event?.event_type!=="message.received")return Response.json({received:true});
      const payload=event.payload;
      if(!Array.isArray(payload?.to)||payload.to.length!==1)throw new EndpointError(400,"Invalid recipient");
      provider="telnyx"; from=payload.from?.phone_number; to=payload.to[0]?.phone_number;
      body=payload.text??""; id=payload.id; received=event.occurred_at;
      params={};
    } else {
      const token=await requireProviderSecret(providerSecretClient(url,key),"TWILIO_AUTH_TOKEN");
      params=await verifyTwilio(req,raw,token,webhookUrl(req,
        Deno.env.get("TWILIO_SMS_WEBHOOK_URL")||Deno.env.get("PUBLIC_FUNCTION_URL"),url,"sms-webhook"));
      provider="twilio";from=params.From;to=params.To;body=params.Body??"";
      id=params.MessageSid||params.SmsSid;received=new Date().toISOString();
    }
    if(!from||!to||!id||!received||!Number.isFinite(Date.parse(received)))throw new EndpointError(400,"Missing message identity");
    const routing=await service.rpc("route_second_number_sms",{p_provider:provider,p_provider_msg_id:id,
      p_to:to,p_from:from,p_body:body,p_received_at:received});
    if(!["did","refill","ignore"].includes(routing?.route))throw new EndpointError(503,"Message routing unavailable");
    if(routing.route!=="refill")return provider==="twilio"?twiml():Response.json({received:true});
    const rate=await service.rpc("consume_rate_limit",{p_bucket:"webhook_ip",
      p_key:req.headers.get("x-forwarded-for")?.split(",")[0].trim()||"unknown_ip",p_capacity:60,p_refill_per_minute:60});
    if(Array.isArray(rate)&&rate[0]?.allowed===false)throw new EndpointError(429,"Rate limited");
    const out=await service.rpc("handle_inbound_command",{p_provider:provider==="twilio"?"sms":"telnyx",
      p_provider_msg_id:id,p_sender_phone:from,p_channel:"sms",p_body:body,p_raw:params});
    return provider==="twilio"?twiml(typeof out?.reply_text==="string"?`<Message>${escapeXml(out.reply_text)}</Message>`:""):
      Response.json({received:true});
  } catch(error) {
    return new Response(error instanceof EndpointError?error.message:"Message processing temporarily unavailable",
      {status:error instanceof EndpointError?error.status:503});
  }
});
