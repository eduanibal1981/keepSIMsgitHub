// Intentional replacement, not recovered source of deployed send-admin-email v2.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { safeEqual } from "../_shared/endpoint-auth.ts";

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export async function handleAdminEmail(req: Request): Promise<Response> {
  const reply = (status: number, body: object) => Response.json(body, { status });
  if (req.method !== "POST") return reply(405, { success: false });
  const url = Deno.env.get("SUPABASE_URL"), key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return reply(503, { success: false });
  const client = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
  try {
    const secret = await client.rpc("get_internal_secret", { p_name: "admin_email_secret" });
    if (secret.error) return reply(503, { success: false });
    if (!secret.data || typeof secret.data !== "string" || !safeEqual(req.headers.get("x-sync-secret") || "", secret.data)) return reply(401, { success: false });
    let body: any;
    try { body = await req.json(); } catch { return reply(400, { success: false }); }
    if (!body || typeof body.email_id !== "string" || !uuid.test(body.email_id)) return reply(400, { success: false });
    const apiKey = Deno.env.get("RESEND_API_KEY");
    if (!apiKey) return reply(503, { success: false, error: "Email provider unavailable" });
    const claim = await client.rpc("claim_admin_email", { p_email_id: body.email_id });
    if (claim.error) return reply(503, { success: false });
    if (!claim.data?.claimed) return reply(202, { success: false, status: "not_queued" });
    const email = claim.data.email;
    let sent = false, providerId: string | null = null, errorCode: string | null = "provider_outcome_unknown";
    try {
      const response = await fetch("https://api.resend.com/emails", {
        method: "POST", signal: AbortSignal.timeout(20000),
        headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json", "Idempotency-Key": `admin-email-${body.email_id}` },
        body: JSON.stringify({ from: email.from_address, to: email.to_addresses, cc: email.cc_addresses,
          reply_to: email.reply_to || undefined, subject: email.subject, text: email.body_text }),
      });
      if (!response.ok) errorCode = response.status >= 500 || [408, 409].includes(response.status) ? "provider_outcome_unknown" : "provider_rejected";
      else {
        const result = await response.json();
        if (typeof result.id === "string" && result.id) { sent = true; providerId = result.id; errorCode = null; }
      }
    } catch { /* Ambiguous provider result is retained for manual review. */ }
    const finished = await client.rpc("finish_admin_email", {
      p_email_id: body.email_id, p_claim_token: claim.data.claim_token, p_sent: sent,
      p_provider_message_id: providerId, p_error_code: errorCode,
    });
    if (finished.error || finished.data !== true) return reply(503, { success: false, error: "Email outcome could not be recorded" });
    // 'sent' here is provider acceptance, not proof of mailbox delivery.
    return reply(sent ? 200 : 503, { success: sent, status: sent ? "accepted_by_provider" : errorCode });
  } catch { return reply(503, { success: false, error: "Email service unavailable" }); }
}
serve(handleAdminEmail);
