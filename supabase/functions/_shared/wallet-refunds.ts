import { usdCents } from "./paypal-capture.ts";

type RefundClient = { rpc: (name: string, args: Record<string, unknown>) => PromiseLike<any> };
const providerIdentity = (value: unknown): value is string => typeof value === "string" && /^[A-Za-z0-9_-]{1,128}$/.test(value);

function captureLinkMatches(result: any, captureId: string, apiBase: string): boolean {
  const up = result?.links?.filter((link: any) => link.rel === "up");
  if (!Array.isArray(up) || up.length !== 1) return false;
  try {
    const link = new URL(up[0].href), base = new URL(apiBase);
    const hosts = new Set([base.hostname]);
    if (["api.paypal.com", "api-m.paypal.com"].includes(base.hostname)) {
      hosts.add("api.paypal.com"); hosts.add("api-m.paypal.com");
    }
    if (["api.sandbox.paypal.com", "api-m.sandbox.paypal.com"].includes(base.hostname)) {
      hosts.add("api.sandbox.paypal.com"); hosts.add("api-m.sandbox.paypal.com");
    }
    return link.protocol === "https:" && hosts.has(link.hostname) && !link.port && !link.username && !link.password &&
      link.pathname === `/v2/payments/captures/${encodeURIComponent(captureId)}` && !link.search;
  } catch (_) { return false; }
}

function verifiedAmount(item: any, result: any): boolean {
  try { return item.currency === "USD" && result.amount?.currency_code === item.currency && usdCents(result.amount?.value) === usdCents(item.amount); }
  catch (_) { return false; }
}

// The SQL claim is fenced and the submission boundary commits before any POST.
// A missing response/ID never causes a second automatic payout, regardless of age.
export async function processRefundItem(
  client: RefundClient, itemId: string, apiBase: string, accessToken: string,
  fetcher: typeof fetch = fetch,
): Promise<string> {
  const claim = await client.rpc("claim_wallet_refund_item", { p_item_id: itemId });
  if (claim.error) throw new Error("Refund claim failed");
  if (!claim.data?.claimed) return claim.data?.reconciliation_required ? "reconciliation_required" : "unclaimed";
  const { item, claim_token: claimToken, action } = claim.data;
  if (!claimToken || item?.id !== itemId || item.provider !== "paypal" || item.currency !== "USD" ||
    !["submit", "poll", "settle"].includes(action)) throw new Error("Invalid refund claim");
  let providerId: string | null = item.provider_refund_id || null;
  let outcome = "unknown";
  if (action === "settle") {
    if (!providerIdentity(providerId) || !["completed", "failed"].includes(item.provider_outcome)) throw new Error("Invalid saved refund evidence");
    outcome = item.provider_outcome;
  } else {
    if (!providerIdentity(item.capture_id) || (action === "poll" && !providerIdentity(providerId))) throw new Error("Invalid refund provider identity");
    const amount = (usdCents(item.amount) / 100).toFixed(2);
    if (action === "submit") {
      if (providerId || !/^ksr-[a-f0-9]{32}$/.test(item.idempotency_key)) throw new Error("Invalid refund submission identity");
      const started = await client.rpc("begin_wallet_refund_submission", { p_item_id: itemId, p_claim_token: claimToken });
      if (started.error) throw new Error("Refund submission unavailable");
      if (started.data !== true) return "unclaimed";
    }
    try {
      const polling = action === "poll";
      const response = await fetcher(polling
        ? `${apiBase}/v2/payments/refunds/${encodeURIComponent(providerId!)}`
        : `${apiBase}/v2/payments/captures/${encodeURIComponent(item.capture_id)}/refund`, {
        method: polling ? "GET" : "POST",
        headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json", Prefer: "return=representation",
          ...(polling ? {} : { "PayPal-Request-Id": item.idempotency_key }) },
        ...(polling ? {} : { body: JSON.stringify({ amount: { value: amount, currency_code: item.currency }, custom_id: item.id }) }),
        redirect: "error",
        signal: AbortSignal.timeout(20000),
      });
      const result = await response.json();
      if (response.ok && providerIdentity(result?.id) && (!providerId || result.id === providerId) &&
        (!result.links?.some((link: any) => link.rel === "up") || captureLinkMatches(result, item.capture_id, apiBase))) {
        providerId = result.id;
        if (result.custom_id === item.id && verifiedAmount(item, result)) {
          if (result.status === "COMPLETED") outcome = "completed";
          else if (result.status === "PENDING") outcome = "pending";
          else if (["FAILED", "CANCELLED"].includes(result.status)) outcome = "failed";
        }
      }
    } catch (_) { /* Ambiguous HTTP/timeout/malformed responses retain the reservation. */ }
    const recorded = await client.rpc("record_wallet_refund_evidence", { p_item_id: itemId, p_claim_token: claimToken,
      p_outcome: outcome, p_provider_refund_id: providerId });
    if (recorded.error || recorded.data?.persisted !== true) throw new Error("Refund evidence requires reconciliation");
  }
  const args = { p_item_id: itemId, p_claim_token: claimToken, p_outcome: outcome, p_provider_refund_id: providerId };
  const settled = await client.rpc("finish_wallet_refund_item", args);
  if (settled.error) {
    // Evidence is already durable. A later claim settles it without another POST.
    await client.rpc("finish_wallet_refund_item", { ...args, p_outcome: "unknown" });
    throw new Error("Refund settlement requires reconciliation");
  }
  return outcome;
}

// Operator recovery after a lost POST response. The endpoint restricts this to
// verified admins/service callers; provider parent/amount/currency must all bind.
export async function reconcileRefundIdentity(
  client: RefundClient, item: any, providerId: string, apiBase: string, accessToken: string,
  actorUserId: string | null, fetcher: typeof fetch = fetch,
): Promise<void> {
  if (!providerIdentity(providerId) || item.provider !== "paypal") throw new Error("Invalid refund reconciliation identity");
  const response = await fetcher(`${apiBase}/v2/payments/refunds/${encodeURIComponent(providerId)}`, {
    headers: { Authorization: `Bearer ${accessToken}` }, signal: AbortSignal.timeout(20000), redirect: "error",
  });
  const result = await response.json();
  if (!response.ok || result?.id !== providerId || result.custom_id !== item.id || !verifiedAmount(item, result) ||
    !captureLinkMatches(result, item.capture_id, apiBase) || !["COMPLETED", "PENDING", "FAILED", "CANCELLED"].includes(result.status)) {
    throw new Error("Refund reconciliation evidence mismatch");
  }
  const adopted = await client.rpc("adopt_wallet_refund_identity", {
    p_item_id: item.id, p_provider_refund_id: providerId, p_actor_user_id: actorUserId,
  });
  if (adopted.error || adopted.data !== true) throw new Error("Refund identity adoption unavailable");
}
