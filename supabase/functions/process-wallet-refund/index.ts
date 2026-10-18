import { ProviderConfigurationError, requireProviderSecret } from "../_shared/provider-secrets.ts";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { processRefundItem, reconcileRefundIdentity } from "../_shared/wallet-refunds.ts";
import { bearer, safeEqual, EndpointError, requireAdmin } from "../_shared/endpoint-auth.ts";

const headers = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json",
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers });

export async function handleRefundRequest(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  try {
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
    const url = Deno.env.get("SUPABASE_URL") || "";
    if (!serviceKey || !url) throw new EndpointError(503, "Authentication is not configured");
    const token = bearer(req);
    const service = safeEqual(token, serviceKey);
    const client = createClient(url, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: { user }, error } = service
      ? { data: { user: null }, error: null }
      : await client.auth.getUser(token);
    if (!service && (error || !user)) return json({ error: "Authentication required" }, 401);
    let body: any;
    try { body = await req.json(); } catch (_) { return json({ error: "Invalid refund request" }, 400); }
    const requestId = body?.refund_request_id;
    const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (typeof requestId !== "string" || !uuid.test(requestId)) return json({ error: "Invalid refund request" }, 400);
    const requestResult = await client.from("wallet_refund_requests").select("id,user_id,status").eq("id", requestId).maybeSingle();
    if (requestResult.error) throw new Error("Refund lookup failed");
    const request = requestResult.data;
    if (!request || (!service && request.user_id !== user!.id && user!.app_metadata?.is_power_user !== true)) {
      return json({ error: "Refund unavailable" }, 403);
    }
    if (!service && request.user_id !== user!.id) await requireAdmin(req, url, serviceKey);
    let reconciliationItem: any = null;
    if (body.reconciliation !== undefined) {
      if (!service) await requireAdmin(req, url, serviceKey);
      const { item_id: itemId, provider_refund_id: providerId } = body.reconciliation || {};
      if (typeof itemId !== "string" || !uuid.test(itemId) || typeof providerId !== "string") return json({ error: "Invalid reconciliation identity" }, 400);
      const found = await client.from("wallet_refund_items").select("id,provider,capture_id,amount,currency")
        .eq("id", itemId).eq("refund_request_id", requestId).maybeSingle();
      if (found.error || !found.data) return json({ error: "Refund item unavailable" }, 403);
      reconciliationItem = found.data;
    }
    const itemsResult = await client.rpc("list_wallet_refund_work", { p_request_id: requestId, p_limit: 5 });
    if (itemsResult.error) throw new Error("Refund item lookup failed");
    if (!itemsResult.data?.length && !reconciliationItem) return json({ success: true, status: request.status });
    const apiBase = Deno.env.get("PAYPAL_API_BASE") || "https://api-m.sandbox.paypal.com";
    if (!["https://api-m.sandbox.paypal.com", "https://api-m.paypal.com", "https://api.sandbox.paypal.com", "https://api.paypal.com"].includes(apiBase)) {
      throw new ProviderConfigurationError();
    }
    const [clientId, secret] = await Promise.all([
      requireProviderSecret(client, "PAYPAL_CLIENT_ID"),
      requireProviderSecret(client, "PAYPAL_CLIENT_SECRET"),
    ]);
    const auth = await fetch(`${apiBase}/v1/oauth2/token`, {
      method: "POST", headers: { Authorization: `Basic ${btoa(`${clientId}:${secret}`)}`, "Content-Type": "application/x-www-form-urlencoded" },
      body: "grant_type=client_credentials", signal: AbortSignal.timeout(20000),
    });
    if (!auth.ok) throw new Error("Refund provider unavailable");
    const { access_token: accessToken } = await auth.json();
    if (typeof accessToken !== "string" || !accessToken) throw new Error("Refund provider unavailable");
    if (reconciliationItem) await reconcileRefundIdentity(client, reconciliationItem,
      body.reconciliation.provider_refund_id, apiBase, accessToken, user?.id || null);
    const outcomes = [];
    let failed = false;
    const items = [...new Set([...(reconciliationItem ? [reconciliationItem.id] : []), ...itemsResult.data.map((item: any) => item.id)])].slice(0, 5);
    for (const itemId of items) {
      try { outcomes.push(await processRefundItem(client, itemId, apiBase, accessToken)); }
      catch (_) { failed = true; outcomes.push("reconciliation_required"); }
    }
    const latest = await client.from("wallet_refund_requests").select("status").eq("id", requestId).single();
    if (latest.error) throw new Error("Refund status unavailable");
    return json({ success: !failed, status: latest.data.status, outcomes }, failed ? 500 : 200);
  } catch (error) {
    if (error instanceof ProviderConfigurationError) return json({ success: false, error: error.message, code: error.code }, 503);
    if (error instanceof EndpointError) return json({ success: false, error: error.message }, error.status);
    return json({ success: false, error: "Refund processing requires retry or reconciliation" }, 500);
  }
}
serve(handleRefundRequest);
