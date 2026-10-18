import { providerSecretClient, requireProviderSecret } from "../_shared/provider-secrets.ts";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { EndpointError } from "../_shared/endpoint-auth.ts";
import { verifyTwilio, webhookUrl } from "../_shared/webhook-auth.ts";
import { trustedDatabase, withWebhookEvent } from "../_shared/webhook-events.ts";

const url = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const db = trustedDatabase(url, serviceKey);
const reject = () => new Response('<?xml version="1.0" encoding="UTF-8"?><Response><Reject reason="busy"/></Response>', {
  headers: { "Content-Type": "text/xml" }, status: 200,
});
serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  try {
    const token = await requireProviderSecret(providerSecretClient(url, serviceKey), "TWILIO_AUTH_TOKEN");
    const raw = await req.text();
    const params = await verifyTwilio(req, raw, token, webhookUrl(req,
      Deno.env.get("TWILIO_VOICE_WEBHOOK_URL"), url, "twilio-voice-webhook"));
    if (!params.From || !params.CallSid) throw new EndpointError(400, "Missing callback correlation");
    const response = await withWebhookEvent(db, "twilio-voice", params.CallSid, params.CallSid, params, async () => {
      const ip = req.headers.get("x-forwarded-for")?.split(",")[0].trim() || "unknown_ip";
      const limit = await db("rpc/consume_rate_limit", "POST", { p_bucket: "webhook_ip", p_key: ip, p_capacity: 60, p_refill_per_minute: 60 });
      if (limit?.[0]?.allowed === false) throw new EndpointError(429, "Rate limited");
      await db("rpc/ingest_offline_refill", "POST", { p_provider: "twilio", p_provider_msg_id: params.CallSid,
        p_sender_phone: params.From, p_channel: "missed_call", p_amount_usd: null, p_raw: params });
      return reject();
    });
    // Duplicates must also receive TwiML so Twilio rejects the inbound call.
    return response.ok ? reject() : response;
  } catch (error) {
    return new Response(error instanceof EndpointError ? error.message : "Webhook unavailable", {
      status: error instanceof EndpointError ? error.status : 503,
    });
  }
});
