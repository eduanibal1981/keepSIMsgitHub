import { ProviderConfigurationError, requireProviderSecret } from "./provider-secrets.ts";
import { EndpointError } from "./endpoint-auth.ts";

export function paypalMerchant(): string {
  const merchant = Deno.env.get("PAYPAL_MERCHANT_ID")?.trim();
  if (!merchant) throw new ProviderConfigurationError();
  return merchant;
}

export function usdCents(value: unknown): number {
  const text = String(value ?? "");
  if (!/^\d+(\.\d{1,2})?$/.test(text)) throw new EndpointError(409, "Invalid payment amount");
  const [whole, fraction = ""] = text.split(".");
  const cents = Number(whole) * 100 + Number(fraction.padEnd(2, "0"));
  if (!Number.isSafeInteger(cents) || cents <= 0) throw new EndpointError(409, "Invalid payment amount");
  return cents;
}

function customIdentity(value: unknown): any {
  if (typeof value !== "string") throw new EndpointError(409, "Missing payment identity");
  try { const parsed = JSON.parse(value); if (parsed?.u && parsed?.k) return parsed; } catch (_) { /* Legacy deposit UUID below. */ }
  if (/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value)) return { u: value, k: "deposit" };
  throw new EndpointError(409, "Invalid payment identity");
}

export async function paypalSession(client: any) {
  const merchant = paypalMerchant();
  const [id, secret] = await Promise.all([
    requireProviderSecret(client, "PAYPAL_CLIENT_ID"), requireProviderSecret(client, "PAYPAL_CLIENT_SECRET"),
  ]);
  const base = Deno.env.get("PAYPAL_API_BASE") || "https://api-m.sandbox.paypal.com";
  const response = await fetch(`${base}/v1/oauth2/token`, {
    method: "POST", headers: { Authorization: `Basic ${btoa(`${id}:${secret}`)}`, "Content-Type": "application/x-www-form-urlencoded" },
    body: "grant_type=client_credentials",
  });
  if (!response.ok) throw new EndpointError(503, "Payment authentication unavailable");
  const token = (await response.json()).access_token;
  if (!token) throw new EndpointError(503, "Payment authentication unavailable");
  return { base, merchant, token };
}

export async function paypalOrder(session: Awaited<ReturnType<typeof paypalSession>>, orderId: string) {
  if (typeof orderId !== "string" || !/^[A-Z0-9]{1,36}$/.test(orderId)) throw new EndpointError(400, "Invalid PayPal order ID");
  const response = await fetch(`${session.base}/v2/checkout/orders/${encodeURIComponent(orderId)}`, {
    headers: { Authorization: `Bearer ${session.token}` },
  });
  if (!response.ok) throw new EndpointError(503, "Payment evidence unavailable");
  return await response.json();
}

export function validatePayPalOrder(stored: any, order: any, merchant: string) {
  const unit = order?.purchase_units?.[0];
  const custom = customIdentity(unit?.custom_id);
  if (order.id !== stored.order_id || order.intent !== "CAPTURE" || order.purchase_units.length !== 1 ||
      custom.u !== stored.user_id || custom.k !== stored.kind || !["deposit", "plan"].includes(stored.kind) ||
      (stored.kind === "plan" && (custom.l !== stored.sim_line_id || custom.p !== stored.plan)) ||
      unit.payee?.merchant_id !== merchant || (stored.merchant_id && stored.merchant_id !== merchant) ||
      unit.amount?.currency_code !== "USD" || usdCents(unit.amount?.value) !== usdCents(stored.amount_usd)) {
    throw new EndpointError(409, "Payment evidence does not match the stored order");
  }
  return { unit, custom };
}

export async function capturePayPalOrder(stored: any, session: Awaited<ReturnType<typeof paypalSession>>) {
  let order = await paypalOrder(session, stored.order_id);
  validatePayPalOrder(stored, order, session.merchant);
  if (order.status !== "COMPLETED") {
    if (order.status !== "APPROVED") throw new EndpointError(409, "Payment is not approved");
    const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(`capture:${stored.order_id}`));
    const requestId = "ksc-" + Array.from(new Uint8Array(digest), b => b.toString(16).padStart(2, "0")).join("").slice(0, 32);
    // A timeout, concurrent request or ORDER_ALREADY_CAPTURED is never evidence
    // of a credit. Retrieve the authoritative completed capture in every case.
    await fetch(`${session.base}/v2/checkout/orders/${encodeURIComponent(stored.order_id)}/capture`, {
      method: "POST", headers: { Authorization: `Bearer ${session.token}`, "Content-Type": "application/json",
        "PayPal-Request-Id": requestId, Prefer: "return=representation" }, body: "{}",
    }).catch(() => null);
    order = await paypalOrder(session, stored.order_id);
  }
  return verifiedPayPalCapture(stored, order, session.merchant);
}

export function verifiedPayPalCapture(stored: any, order: any, merchant: string, captureId?: string) {
  const { unit, custom } = validatePayPalOrder(stored, order, merchant);
  const captures = unit.payments?.captures;
  const capture = captures?.[0];
  if (order.status !== "COMPLETED" || !Array.isArray(captures) || captures.length !== 1 ||
      typeof capture?.id !== "string" || !capture.id || capture.id === stored.order_id ||
      capture.status !== "COMPLETED" || capture.final_capture === false ||
      (captureId && capture.id !== captureId) || capture.amount?.currency_code !== "USD" ||
      usdCents(capture.amount?.value) !== usdCents(stored.amount_usd) ||
      (capture.payee && capture.payee.merchant_id !== merchant) ||
      (capture.supplementary_data?.related_ids?.order_id && capture.supplementary_data.related_ids.order_id !== stored.order_id)) {
    throw new EndpointError(409, "A matching completed PayPal capture is required");
  }
  if (capture.custom_id) {
    const identity = customIdentity(capture.custom_id);
    if (identity.u !== custom.u || identity.k !== custom.k) throw new EndpointError(409, "Capture identity mismatch");
  }
  return { capture_id: capture.id, order_id: stored.order_id, status: capture.status,
    user_id: custom.u, kind: custom.k, plan: stored.plan || null, sim_line_id: stored.sim_line_id || null,
    amount: capture.amount.value, currency: "USD", merchant_id: merchant, expected_merchant_id: merchant,
    paypal_fee: capture.seller_receivable_breakdown?.paypal_fee || null,
    net: capture.seller_receivable_breakdown?.net_amount || null };
}

export async function fulfillPayPalCapture(client: any, evidence: any, source: string, eventId: string | null = null) {
  const { data, error } = await client.rpc("fulfill_paypal_capture", {
    p_order_id: evidence.order_id, p_evidence: { ...evidence, source, event_id: eventId },
  });
  if (error || data?.success !== true) throw new EndpointError(503, "Payment fulfillment pending; retry this order");
  return data;
}

export function validatePayPalCaptureEvent(evidence: any, resource: any): void {
  if (resource.amount?.currency_code !== evidence.currency || usdCents(resource.amount?.value) !== usdCents(evidence.amount) ||
      (resource.payee && resource.payee.merchant_id !== evidence.merchant_id)) throw new EndpointError(409, "Capture event evidence mismatch");
  if (resource.custom_id) {
    const identity = customIdentity(resource.custom_id);
    if (identity.u !== evidence.user_id || identity.k !== evidence.kind) throw new EndpointError(409, "Capture event identity mismatch");
  }
}
