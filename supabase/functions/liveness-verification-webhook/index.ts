import { ProviderConfigurationError, providerSecretClient, requireProviderSecret } from "../_shared/provider-secrets.ts";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { EndpointError } from "../_shared/endpoint-auth.ts";
import { verifyTelnyx, verifyTwilio, webhookUrl } from "../_shared/webhook-auth.ts";
import { trustedDatabase, withWebhookEvent } from "../_shared/webhook-events.ts";
import { handleLivenessCallback } from "../_shared/liveness-callback.ts";

const url = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const db = trustedDatabase(url, serviceKey);
const secrets = providerSecretClient(url, serviceKey);

serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  try {
    if (!url || !serviceKey) throw new ProviderConfigurationError();
    const raw = await req.text();
    const contentType = req.headers.get("content-type") || "";
    if (contentType.includes("application/x-www-form-urlencoded")) {
      const authToken = await requireProviderSecret(secrets, "TWILIO_AUTH_TOKEN");
      const params = await verifyTwilio(req, raw, authToken, webhookUrl(req,
        Deno.env.get("LIVENESS_WEBHOOK_URL"), url, "liveness-verification-webhook"));
      const resource = params.CallSid;
      const status = String(params.CallStatus || "").toLowerCase();
      if (!resource || !status) throw new EndpointError(400, "Missing callback correlation");
      const eventId = `${resource}:${params.SequenceNumber || status}`;
      return await withWebhookEvent(db, "twilio-liveness", eventId, resource, params, () =>
        handleLivenessCallback(db, "twilio", resource, `call.${status}`, params, async () => ({
          accountSid: await requireProviderSecret(secrets, "TWILIO_ACCOUNT_SID"), authToken,
        })));
    }
    if (contentType.includes("application/json")) {
      let publicKey = Deno.env.get("TELNYX_PUBLIC_KEY") || "";
      if (!publicKey) publicKey = (await db("system_configs?config_key=eq.TELNYX_PUBLIC_KEY&select=config_value"))[0]?.config_value || "";
      await verifyTelnyx(req, raw, publicKey);
      let body;
      try { body = JSON.parse(raw); } catch (_) { throw new EndpointError(400, "Invalid JSON"); }
      const event = body?.data;
      const payload = event?.payload;
      const resource = event?.event_type === "message.finalized" ? payload?.id : payload?.call_control_id;
      if (!event?.id || !event?.event_type || !resource) throw new EndpointError(400, "Missing callback correlation");
      return await withWebhookEvent(db, "telnyx", event.id, resource, event, () =>
        handleLivenessCallback(db, "telnyx", resource, event.event_type, payload, async () => ({
          apiKey: await requireProviderSecret(secrets, "TELNYX_API_KEY"),
        })));
    }
    return new Response("Unsupported media type", { status: 415 });
  } catch (error) {
    return new Response(JSON.stringify({ error: error instanceof EndpointError || error instanceof ProviderConfigurationError
      ? error.message : "Verification callback unavailable" }), {
      status: error instanceof EndpointError ? error.status : 503, headers: { "Content-Type": "application/json" },
    });
  }
});
