import { EndpointError } from "./endpoint-auth.ts";

export function trustedDatabase(url: string, serviceKey: string) {
  return async (path: string, method = "GET", body?: unknown): Promise<any> => {
    const response = await fetch(`${url}/rest/v1/${path}`, {
      method, headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}`,
        "Content-Type": "application/json", Prefer: "return=representation" },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
    if (!response.ok) throw new EndpointError(503, "Webhook persistence unavailable");
    return response.status === 204 ? null : await response.json();
  };
}

// Delivery envelopes and form ordering may change on a legitimate retry.
// Callers pass authenticated event data, excluding transport-only metadata.
function canonicalPayload(value: any): string {
  if (Array.isArray(value)) return "[" + value.map(canonicalPayload).join(",") + "]";
  if (value !== null && typeof value === "object") return "{" + Object.keys(value).sort()
    .map(key => JSON.stringify(key) + ":" + canonicalPayload(value[key])).join(",") + "}";
  return JSON.stringify(value) ?? "null";
}

export async function withWebhookEvent(
  db: ReturnType<typeof trustedDatabase>, scope: string, eventId: string,
  resourceId: string, payload: unknown, run: () => Promise<Response>,
): Promise<Response> {
  if (!eventId || !resourceId) throw new EndpointError(400, "Missing webhook correlation");
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(canonicalPayload(payload)));
  const hash = Array.from(new Uint8Array(digest), b => b.toString(16).padStart(2, "0")).join("");
  const args = { p_scope: scope, p_event_id: eventId };
  const claim = await db("rpc/claim_verified_webhook", "POST", {
    ...args, p_resource_id: resourceId, p_payload_hash: hash,
  });
  if (claim.state === "completed") return new Response(JSON.stringify({ received: true, duplicate: true }), {
    status: 200, headers: { "Content-Type": "application/json" },
  });
  if (claim.state === "conflict") throw new EndpointError(409, "Webhook identity conflict");
  if (claim.state !== "claimed") throw new EndpointError(503, "Webhook processing in progress");
  try {
    const response = await run();
    if (!response.ok) {
      await db("rpc/finish_verified_webhook", "POST", { ...args, p_token: claim.token, p_success: false });
      return response;
    }
    await db("rpc/finish_verified_webhook", "POST", { ...args, p_token: claim.token, p_success: true });
    return response;
  } catch (error) {
    // Failure is explicitly retryable. A crashed/ambiguous invocation retains its
    // processing claim for operator reconciliation; never steal it on a timer.
    await db("rpc/finish_verified_webhook", "POST", { ...args, p_token: claim.token, p_success: false }).catch(() => {});
    throw error;
  }
}
