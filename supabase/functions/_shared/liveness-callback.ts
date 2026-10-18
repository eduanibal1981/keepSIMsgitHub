import { EndpointError } from "./endpoint-auth.ts";
import { trustedDatabase } from "./webhook-events.ts";

// client_state is correlation only. The stored provider resource is authority.
export async function handleLivenessCallback(
  db: ReturnType<typeof trustedDatabase>, provider: string, resourceId: string,
  eventType: string, payload: any, credentials: () => Promise<Record<string, string>>,
  expectedAttemptId?: string,
): Promise<Response> {
  const attempts = await db(`line_verification_attempts?provider=eq.${provider}&provider_resource_id=eq.${encodeURIComponent(resourceId)}&select=*`);
  if (attempts.length !== 1) throw new EndpointError(503, "Verification correlation pending");
  const attempt = attempts[0];
  if (expectedAttemptId && attempt.id !== expectedAttemptId) throw new EndpointError(403, "Verification resource mismatch");
  const voice = eventType.startsWith("call.");
  if ((voice && attempt.method !== "voice") || (!voice && attempt.method !== "sms")) throw new EndpointError(403, "Verification method mismatch");
  if (attempt.status === "terminal") return new Response("OK (already terminal)");
  let outcome: string | null = null;
  let carrier: string | null = null;
  let detail: string | null = null;
  const ringing = ["call.ringing", "call.answered", "call.in-progress"].includes(eventType);
  if (ringing) {
    const config = await credentials();
    let response: Response;
    if (provider === "telnyx") {
      response = await fetch(`https://api.telnyx.com/v2/calls/${encodeURIComponent(attempt.provider_resource_id)}/actions/hangup`, {
        method: "POST", headers: { Authorization: `Bearer ${config.apiKey}`, "Content-Type": "application/json" },
        body: JSON.stringify({ command_id: attempt.id }),
      });
      if (!response.ok) {
        const body = await response.json().catch(() => ({}));
        if (!body.errors?.some((e: any) => String(e.code) === "90018")) throw new EndpointError(503, "Call cancellation unavailable");
      }
    } else {
      response = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${encodeURIComponent(config.accountSid)}/Calls/${encodeURIComponent(attempt.provider_resource_id)}.json`, {
        method: "POST", headers: { Authorization: `Basic ${btoa(`${config.accountSid}:${config.authToken}`)}`,
          "Content-Type": "application/x-www-form-urlencoded" }, body: new URLSearchParams({ Status: "completed" }).toString(),
      });
      if (!response.ok) {
        const body = await response.json().catch(() => ({}));
        if (body.code !== 21220) throw new EndpointError(503, "Call cancellation unavailable");
      }
    }
    outcome = "succeeded";
  } else if (eventType === "call.hangup") {
    outcome = "inconclusive";
    detail = "Call ended without observed ringing";
  } else if (eventType === "call.completed") {
    outcome = "inconclusive"; detail = "Call completed without observed ringing";
  } else if (["call.failed", "call.busy", "call.no-answer", "call.canceled"].includes(eventType)) {
    outcome = "failed"; detail = "Call reached terminal state";
  } else if (eventType === "message.finalized") {
    const destinations = payload.to;
    if (!Array.isArray(destinations) || destinations.length !== 1) throw new EndpointError(403, "Verification destination mismatch");
    const destination = destinations[0];
    if (destination.phone_number && destination.phone_number.replace(/\s+/g, "") !== attempt.destination_phone.replace(/\s+/g, "")) throw new EndpointError(403, "Verification destination mismatch");
    const status = String(destination?.status || "").toLowerCase();
    if (["delivered", "failed", "undelivered"].includes(status)) {
      outcome = status === "delivered" ? "succeeded" : "failed";
      carrier = destination?.carrier || null;
      if (outcome === "failed") detail = "SMS delivery failed";
    }
  }
  if (outcome) {
    const result = await db("rpc/settle_line_verification_event", "POST", {
      p_attempt_id: attempt.id, p_provider: provider, p_resource_id: resourceId,
      p_event_type: eventType === "message.finalized" ? `message.${String(payload.to[0].status).toLowerCase()}` : eventType, p_outcome: outcome, p_carrier_name: carrier, p_error_message: detail,
    });
    if (result?.success !== true) throw new EndpointError(503, "Verification settlement unavailable");
  }
  return new Response("OK");
}
