import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";
import { routeAndSendWhatsApp } from "../_shared/whatsapp_router.ts";
import { profileSecret, profileReady } from "../_shared/whatsapp_profile.ts";

const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
const json = (body: any, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { "Content-Type": "application/json" },
});
async function signature(secret: string, raw: string) {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const digest = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(raw));
  return "sha256=" + Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, "0")).join("");
}
function equal(a: string, b: string) {
  if (a.length !== b.length) return false;
  let difference = 0;
  for (let i = 0; i < a.length; i++) difference |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return difference === 0;
}

serve(async (req: Request) => {
  if (req.method !== "GET" && req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  try {
    const { data: profiles, error } = await db.from("whatsapp_provider_profiles")
      .select("id,provider_kind,is_enabled,ready_state,expected_sender_number,observed_sender_number,connection_metadata")
      .eq("provider_kind", "meta_cloud");
    if (error || !profiles?.length) return json({ error: "webhook_profile_unavailable" }, 503);
    if (req.method === "GET") {
      const url = new URL(req.url), token = url.searchParams.get("hub.verify_token");
      if (url.searchParams.get("hub.mode") !== "subscribe" || !token) return json({ error: "forbidden" }, 403);
      for (const profile of profiles) {
        if (!profile.is_enabled) continue;
        const verify = await profileSecret(db, profile, "verify");
        if (verify && equal(token, verify)) return new Response(url.searchParams.get("hub.challenge") || "", { status: 200 });
      }
      return json({ error: "forbidden" }, 403);
    }
    const raw = await req.text();
    if (raw.length > 1024 * 1024) return json({ error: "payload_too_large" }, 413);
    let payload: any;
    try { payload = JSON.parse(raw); } catch (_) { return json({ error: "bad_json" }, 400); }
    const header = req.headers.get("x-hub-signature-256") || "";
    if (!/^sha256=[0-9a-f]{64}$/.test(header)) return json({ error: "bad_signature" }, 401);
    // Only inspect untrusted routing identifiers before verification. Verify all
    // changes before commands or receipts; multiple Meta profiles are supported.
    const verified: { profile: any; value: any }[] = [];
    for (const entry of payload.entry || []) {
      for (const change of entry.changes || []) {
        const value = change.value || {}, senderId = value.metadata?.phone_number_id;
        const candidates = profiles.filter((p: any) => p.connection_metadata?.phone_number_id === senderId);
        if (!senderId || candidates.length !== 1) return json({ error: "unknown_sender" }, 401);
        const profile = candidates[0];
        const accountId = profile.connection_metadata?.waba_account_id;
        if (accountId && String(entry.id) !== String(accountId)) return json({ error: "sender_account_mismatch" }, 401);
        const secret = await profileSecret(db, profile, "app_secret");
        if (!secret) return json({ error: "webhook_secret_unconfigured" }, 503);
        if (!equal(header, await signature(secret, raw))) return json({ error: "bad_signature" }, 401);
        verified.push({ profile, value });
      }
    }
    if (!verified.length) return json({ error: "no_verified_changes" }, 400);
    for (const { profile, value } of verified) {
      for (const receipt of value.statuses || []) {
        const state = receipt.status === "read" || receipt.status === "delivered" ? "delivered"
          : receipt.status === "sent" ? "sent" : receipt.status === "failed" ? "failed" : null;
        if (!receipt.id || !state) continue;
        const patch: any = { state, updated_at: new Date().toISOString() };
        if (state === "delivered") patch.delivered_at = patch.updated_at;
        if (state === "sent") patch.sent_at = patch.updated_at;
        if (state === "failed") {
          patch.retryable = false; patch.error_category = "meta_delivery_failed";
          patch.error_detail = JSON.stringify(receipt.errors || []).slice(0, 1000);
        }
        const opaque = receipt.biz_opaque_callback_data;
        const hasAttempt = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(opaque || "");
        if (hasAttempt) patch.provider_message_id = receipt.id;
        let update = db.from("whatsapp_message_attempts").update(patch)
          .eq("profile_id", profile.id).eq("route_mode", "meta_cloud");
        update = hasAttempt ? update.eq("id", opaque) : update.eq("provider_message_id", receipt.id);
        const { error: receiptError } = await update;
        if (receiptError) throw new Error("Receipt persistence failed");
      }
      if (!profileReady(profile)) continue; // Receipts still work while sends are paused.
      for (const message of value.messages || []) {
        if (message.type !== "text" || !message.from || !message.id) continue;
        const phone = "+" + String(message.from).replace(/\D/g, "");
        const { data: command, error: commandError } = await db.rpc("handle_inbound_command", {
          p_provider: "whatsapp", p_provider_msg_id: message.id, p_sender_phone: phone,
          p_channel: "whatsapp", p_body: message.text?.body || "", p_raw: message,
        });
        if (commandError) throw new Error("Command persistence failed");
        if (command?.reply_text) {
          const reply = await routeAndSendWhatsApp(db, { purpose: "offline_refill_reply",
            recipientPhone: phone, commandId: message.id, bodyText: command.reply_text,
            replyProfileId: profile.id, replyPhoneNumberId: value.metadata.phone_number_id });
          if (reply.state === "failed" && reply.retryable) throw new Error("Reply temporarily unavailable");
        }
      }
    }
    return json({ received: true });
  } catch (_) {
    // Meta retries failures. Never acknowledge a failed persistence operation.
    return json({ error: "webhook_processing_unavailable" }, 503);
  }
});
