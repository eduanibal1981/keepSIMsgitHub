import { ProviderConfigurationError, providerSecretClient } from "../_shared/provider-secrets.ts";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { EndpointError } from "../_shared/endpoint-auth.ts";
import { trustedDatabase } from "../_shared/webhook-events.ts";
import { paypalSession, paypalOrder, capturePayPalOrder, verifiedPayPalCapture, validatePayPalCaptureEvent, fulfillPayPalCapture } from "../_shared/paypal-capture.ts";

const url = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const webhookId = Deno.env.get("PAYPAL_WEBHOOK_ID") || "";
const db = trustedDatabase(url, serviceKey);
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { "Content-Type": "application/json" },
});
const client = { async rpc(name: string, args: Record<string, unknown>) {
  return { data: await db(`rpc/${name}`, "POST", args), error: null };
} };
async function storedOrder(orderId: string) {
  if (typeof orderId !== "string" || !/^[A-Z0-9]{1,36}$/.test(orderId)) throw new EndpointError(400, "Missing payment order identity");
  const rows = await db(`paypal_orders?order_id=eq.${encodeURIComponent(orderId)}&select=*`);
  // The webhook can race the server's initial order INSERT. Keep it retryable.
  if (rows.length !== 1) throw new EndpointError(503, "Stored payment order unavailable");
  return rows[0];
}

serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  try {
    if (!webhookId) throw new EndpointError(503, "Webhook verification is not configured");
    const raw = await req.text();
    let event;
    try { event = JSON.parse(raw); } catch (_) { throw new EndpointError(400, "Invalid JSON"); }
    const headers = req.headers;
    const verification = {
      transmission_id: headers.get("paypal-transmission-id"), transmission_time: headers.get("paypal-transmission-time"),
      cert_url: headers.get("paypal-cert-url"), auth_algo: headers.get("paypal-auth-algo"),
      transmission_sig: headers.get("paypal-transmission-sig"), webhook_id: webhookId, webhook_event: event,
    };
    if (!verification.transmission_id || !verification.transmission_time || !verification.cert_url ||
        !verification.auth_algo || !verification.transmission_sig) throw new EndpointError(400, "Missing webhook signature");
    const session = await paypalSession(providerSecretClient(url, serviceKey));
    const verified = await fetch(`${session.base}/v1/notifications/verify-webhook-signature`, {
      method: "POST", headers: { Authorization: `Bearer ${session.token}`, "Content-Type": "application/json" },
      body: JSON.stringify(verification),
    });
    if (!verified.ok) throw new EndpointError(503, "Webhook verification unavailable");
    if ((await verified.json()).verification_status !== "SUCCESS") throw new EndpointError(400, "Invalid webhook signature");
    if (!event?.id || !event?.event_type) throw new EndpointError(400, "Missing webhook identity");
    // No privileged writes occur before provider signature verification.
    const limit = await db("rpc/consume_rate_limit", "POST", {
      p_bucket: "webhook_ip", p_key: headers.get("x-forwarded-for")?.split(",")[0].trim() || "unknown_ip",
      p_capacity: 60, p_refill_per_minute: 60,
    });
    if (limit?.[0]?.allowed === false) throw new EndpointError(429, "Rate limited");
    const resource = event.resource || {};
    if (event.event_type === "CHECKOUT.ORDER.APPROVED") {
      const stored = await storedOrder(resource.id);
      const evidence = await capturePayPalOrder(stored, session);
      // Approval initiates/adopts capture. Fulfillment belongs to the completed
      // capture event or authenticated client path; never mark captured early.
      return json({ received: true, captured: true, order_id: stored.order_id, capture_id: evidence.capture_id });
    }
    if (event.event_type === "PAYMENT.CAPTURE.COMPLETED") {
      if (resource.status !== "COMPLETED" || !resource.id) throw new EndpointError(409, "Completed capture evidence required");
      const orderId = resource.supplementary_data?.related_ids?.order_id;
      const stored = await storedOrder(orderId);
      const order = await paypalOrder(session, orderId);
      const evidence = verifiedPayPalCapture(stored, order, session.merchant, resource.id);
      // Event amount is corroborated, never used instead of authoritative data.
      validatePayPalCaptureEvent(evidence, resource);
      const fulfilled = await fulfillPayPalCapture(client, evidence, "webhook", event.id);
      return json({ received: true, success: true, duplicate: fulfilled.duplicate });
    }
    if (["PAYMENT.CAPTURE.REFUNDED", "PAYMENT.CAPTURE.REVERSED", "PAYMENT.CAPTURE.DENIED",
      "PAYMENT.CAPTURE.DECLINED", "CHECKOUT.PAYMENT-APPROVAL.REVERSED"].includes(event.event_type)) {
      const orderId = resource.supplementary_data?.related_ids?.order_id ||
        (event.event_type.startsWith("CHECKOUT.") ? resource.id : null);
      if (orderId) await db(`paypal_orders?order_id=eq.${encodeURIComponent(orderId)}&status=neq.captured`, "PATCH", { status: "failed" });
      await db("system_alerts", "POST", { kind: "paypal_payment_problem", message: "PayPal payment requires reconciliation",
        details: { event_id: event.id, event_type: event.event_type, order_id: orderId, resource_id: resource.id || null } });
      return json({ received: true });
    }
    return json({ received: true, ignored: event.event_type });
  } catch (error) {
    return json({ success: false, error: error instanceof EndpointError || error instanceof ProviderConfigurationError
      ? error.message : "PayPal processing unavailable" }, error instanceof EndpointError ? error.status : 503);
  }
});
