import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";
import { routeAndSendWhatsApp } from "../_shared/whatsapp_router.ts";

// WhatsApp Business (Cloud) API Webhook
// Handles:
// 1. Webhook subscription verification (GET)
// 2. Delivery & read status updates (POST statuses[])
// 3. Inbound offline refill commands and replies with sender affinity (POST messages[])

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const WABA_VERIFY_TOKEN = Deno.env.get("WABA_VERIFY_TOKEN") ?? "";
const WABA_APP_SECRET = Deno.env.get("WABA_APP_SECRET") ?? "";

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

const json = (body: Record<string, unknown>, status: number) =>
  new Response(JSON.stringify(body), {
    headers: { "Content-Type": "application/json" },
    status,
  });

async function hmacSha256Hex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message));
  return Array.from(new Uint8Array(sig)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

serve(async (req: Request) => {
  const url = new URL(req.url);

  // 1. Webhook Verification (GET)
  if (req.method === "GET") {
    const mode = url.searchParams.get("hub.mode");
    const token = url.searchParams.get("hub.verify_token");
    const challenge = url.searchParams.get("hub.challenge");

    if (mode === "subscribe") {
      let isVerified = WABA_VERIFY_TOKEN && token === WABA_VERIFY_TOKEN;

      // Also check profile-specific verify tokens if global token did not match
      if (!isVerified) {
        const { data: profiles } = await supabase
          .from("whatsapp_provider_profiles")
          .select("id, connection_metadata")
          .eq("provider_kind", "meta_cloud");

        if (profiles) {
          for (const p of profiles) {
            const vaultId = p.connection_metadata?.webhook_verify_token_vault_id;
            if (vaultId) {
              const { data: secret } = await supabase.rpc("get_internal_secret", {
                p_name: `wa_meta_verify_${p.id}`,
              });
              if (secret && secret === token) {
                isVerified = true;
                break;
              }
            }
          }
        }
      }

      if (isVerified) {
        return new Response(challenge ?? "", { status: 200 });
      }
    }
    return new Response("Forbidden", { status: 403 });
  }

  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  // 2. IP Rate Limiter (60 requests / minute)
  const xForwardedFor = req.headers.get("x-forwarded-for");
  const clientIp = xForwardedFor
    ? xForwardedFor.split(",")[0].trim()
    : req.headers.get("x-real-ip") || "unknown_ip";

  try {
    const { data: limitRes } = await supabase.rpc("consume_rate_limit", {
      p_bucket: "webhook_ip",
      p_key: clientIp,
      p_capacity: 60,
      p_refill_per_minute: 60.0,
    });
    if (limitRes && limitRes.length > 0 && limitRes[0]?.allowed === false) {
      const retryAfter = limitRes[0]?.retry_after_seconds ?? 60;
      return json({ code: "rate_limited", bucket: "webhook_ip", retry_after: retryAfter }, 429);
    }
  } catch (_) {
    // Non-fatal if rate limiting table not configured
  }

  // 3. Webhook Signature Check
  const raw = await req.text();
  const signatureHeader = req.headers.get("x-hub-signature-256") ?? "";

  let appSecret = WABA_APP_SECRET;
  if (!appSecret) {
    // Attempt lookup from active Meta profiles in DB
    const { data: metaProfile } = await supabase
      .from("whatsapp_provider_profiles")
      .select("id, connection_metadata")
      .eq("provider_kind", "meta_cloud")
      .maybeSingle();

    if (metaProfile?.connection_metadata?.app_secret_vault_id) {
      const { data: secret } = await supabase.rpc("get_internal_secret", {
        p_name: `wa_meta_app_secret_${metaProfile.id}`,
      });
      if (secret) appSecret = secret;
    }
  }

  if (appSecret) {
    const expected = "sha256=" + await hmacSha256Hex(appSecret, raw);
    if (!safeEqual(signatureHeader, expected)) {
      console.error("waba-webhook: signature mismatch");
      return json({ error: "bad_signature" }, 401);
    }
  } else {
    console.warn("waba-webhook: WABA_APP_SECRET unset — skipping signature check");
  }

  let payload: any;
  try {
    payload = JSON.parse(raw);
  } catch (_) {
    return json({ error: "bad_json" }, 400);
  }

  const results: unknown[] = [];

  try {
    const entries = Array.isArray(payload?.entry) ? payload.entry : [];
    for (const entry of entries) {
      const changes = Array.isArray(entry?.changes) ? entry.changes : [];
      for (const change of changes) {
        const value = change?.value ?? {};
        const receivingPhoneNumberId = value?.metadata?.phone_number_id;

        // A. Handle Status Updates (sent, delivered, read, failed)
        const statuses = Array.isArray(value?.statuses) ? value.statuses : [];
        for (const st of statuses) {
          const providerMsgId = st.id;
          const statusVal = st.status; // 'sent' | 'delivered' | 'read' | 'failed'
          if (!providerMsgId || !statusVal) continue;

          let normalizedState: "sent" | "delivered" | "failed" | null = null;
          if (statusVal === "delivered" || statusVal === "read") {
            normalizedState = "delivered";
          } else if (statusVal === "sent") {
            normalizedState = "sent";
          } else if (statusVal === "failed") {
            normalizedState = "failed";
          }

          if (normalizedState) {
            const updatePayload: Record<string, any> = {
              state: normalizedState,
              updated_at: new Date().toISOString(),
            };
            if (normalizedState === "delivered") {
              updatePayload.delivered_at = new Date().toISOString();
            }
            if (normalizedState === "failed" && st.errors && st.errors.length > 0) {
              updatePayload.error_category = "meta_delivery_failed";
              updatePayload.error_detail = JSON.stringify(st.errors[0]).slice(0, 500);
            }

            // Monotonic state update: only update if not already delivered
            await supabase
              .from("whatsapp_message_attempts")
              .update(updatePayload)
              .eq("provider_message_id", providerMsgId)
              .neq("state", "delivered");
          }
        }

        // B. Handle Inbound Messages & Offline Refill Commands
        const messages = Array.isArray(value?.messages) ? value.messages : [];
        for (const msg of messages) {
          if (msg?.type && msg.type !== "text") continue;
          const from: string | undefined = msg?.from;
          const msgId: string | undefined = msg?.id;
          const bodyText: string | undefined = msg?.text?.body;
          if (!from || !msgId) continue;

          const senderPhone = "+" + from.replace(/\D/g, "");

          // 1. Process command via handle_inbound_command RPC
          const { data: commandResult, error: commandErr } = await supabase.rpc(
            "handle_inbound_command",
            {
              p_provider: "whatsapp",
              p_provider_msg_id: msgId,
              p_sender_phone: senderPhone,
              p_channel: "whatsapp",
              p_body: bodyText ?? "",
              p_raw: msg,
            },
          );

          if (commandErr) {
            console.error("handle_inbound_command error:", commandErr);
            results.push({ error: commandErr.message });
            continue;
          }

          // 2. Dispatch reply preserving the exact receiving Meta sender (Phone Number ID)
          const replyText = commandResult?.reply_text;
          if (typeof replyText === "string" && replyText.trim().length > 0) {
            const replyOutcome = await routeAndSendWhatsApp(supabase, {
              purpose: "offline_refill_reply",
              recipientPhone: senderPhone,
              bodyText: replyText,
              commandId: msgId,
              replyPhoneNumberId: receivingPhoneNumberId, // Strict conversation sender affinity
            });
            results.push({ commandResult, replyOutcome });
          } else {
            results.push({ commandResult });
          }
        }
      }
    }
  } catch (e: any) {
    console.error("waba-webhook processing error:", e);
  }

  return json({ received: true, results }, 200);
});
