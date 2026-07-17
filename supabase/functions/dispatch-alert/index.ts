// dispatch-alert — KeepSIMs notification dispatcher (C1).
//
// Invoked by the public.notifications AFTER INSERT trigger
// (trg_fn_dispatch_notification) via pg_net. Delivery model:
//   push  -> OneSignal REST first; on non-2xx / timeout / no-recipients,
//            fall back to FCM HTTP v1 using device_push_tokens.fcm_token.
//   email -> Resend (quota-guarded for non-critical categories)
//   telegram / whatsapp / webhook -> unchanged legacy channels.
// Every attempt is logged to public.notification_deliveries.
//
// Secrets: the trigger authenticates with a shared secret stored in Supabase
// Vault (dispatch_shared_secret), read back here via the get_internal_secret
// RPC. Provider keys come from Edge Function secrets / env only.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const ONESIGNAL_APP_ID = "434b9552-8005-4d08-b3b1-a7a35f0b15dc";
const ONESIGNAL_TIMEOUT_MS = 5000;

interface CacheEntry { url: string; timestamp: number; }
const countryCache: Record<string, CacheEntry> = {};
const CACHE_TTL = 5 * 60 * 1000; // 5 mins

// Module-level caches (persist across warm invocations).
let cachedSecret: string | null = null;
let cachedFcmToken: { token: string; exp: number } | null = null;

// --------------------------------------------------------------------------
// FCM HTTP v1 helpers
// --------------------------------------------------------------------------
function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const bin = atob(b64);
  const buf = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i);
  return buf.buffer;
}

function base64url(input: string | Uint8Array): string {
  const bin = typeof input === "string"
    ? input
    : String.fromCharCode(...input);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function getFcmAccessToken(serviceAccount: {
  client_email: string;
  private_key: string;
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedFcmToken && cachedFcmToken.exp > now + 60) return cachedFcmToken.token;

  const header = { alg: "RS256", typ: "JWT" };
  const claims = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };
  const unsigned = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(claims))}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(serviceAccount.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${base64url(new Uint8Array(sig))}`;

  const resp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  const data = await resp.json();
  if (!data.access_token) {
    throw new Error(`FCM token exchange failed: ${JSON.stringify(data)}`);
  }
  cachedFcmToken = { token: data.access_token, exp: now + (data.expires_in ?? 3600) };
  return data.access_token;
}

async function sendFcm(
  supabase: SupabaseClient,
  userId: string,
  title: string,
  body: string,
  actionUrl: string | null,
): Promise<{ status: "delivered" | "failed" | "skipped"; detail: string }> {
  const saRaw = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
  if (!saRaw) return { status: "skipped", detail: "FCM_SERVICE_ACCOUNT_JSON not configured." };

  let sa: { project_id: string; client_email: string; private_key: string };
  try {
    sa = JSON.parse(saRaw);
  } catch {
    return { status: "failed", detail: "FCM service account JSON is invalid." };
  }

  const { data: rows } = await supabase
    .from("device_push_tokens")
    .select("fcm_token")
    .eq("user_id", userId)
    .not("fcm_token", "is", null);

  const tokens = (rows ?? []).map((r: { fcm_token: string }) => r.fcm_token).filter(Boolean);
  if (tokens.length === 0) {
    return { status: "skipped", detail: "No FCM tokens registered for this user." };
  }

  let accessToken: string;
  try {
    accessToken = await getFcmAccessToken(sa);
  } catch (e) {
    return { status: "failed", detail: `FCM auth failed: ${(e as Error).message}` };
  }

  let ok = 0;
  const errs: string[] = [];
  for (const token of tokens) {
    try {
      const r = await fetch(
        `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify({
            message: {
              token,
              notification: { title, body },
              data: actionUrl ? { action_url: actionUrl } : {},
            },
          }),
        },
      );
      if (r.ok) {
        ok++;
      } else {
        errs.push(`HTTP ${r.status}`);
      }
    } catch (e) {
      errs.push((e as Error).message ?? String(e));
    }
  }

  if (ok > 0) {
    return { status: "delivered", detail: `FCM delivered to ${ok}/${tokens.length} device(s).` };
  }
  return { status: "failed", detail: `FCM failed on all ${tokens.length} device(s): ${errs.join("; ")}` };
}

// --------------------------------------------------------------------------
serve(async (req: Request) => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  // 1. Validate the shared secret against the Vault-stored value.
  const reqSecret = req.headers.get("x-keep-sims-secret");
  if (!cachedSecret) {
    const { data } = await supabase.rpc("get_internal_secret", {
      p_name: "dispatch_shared_secret",
    });
    cachedSecret = (data as string | null) ?? null;
  }
  if (!cachedSecret || reqSecret !== cachedSecret) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const payload = await req.json();
    const {
      notification_id,
      user_id,
      category,
      title,
      body,
      action_url,
      sim_line_id,
      channels,
    } = payload;

    const results: Record<string, string> = {};
    const deliveries: Array<Record<string, unknown>> = [];
    let isFallbackTriggered = false; // WhatsApp failure forces email past the quota guard.

    const logDelivery = (
      channel: string,
      status: "delivered" | "failed" | "skipped",
      detail: string,
      providerStatus: number | null = null,
    ) => {
      deliveries.push({
        notification_id: notification_id ?? null,
        user_id,
        channel,
        status,
        detail: (detail ?? "").slice(0, 1000),
        provider_status: providerStatus,
      });
    };

    // 2. Dispatch to each active channel. for...of so whatsapp fallback can
    //    push extra channels onto the array mid-loop.
    for (const channel of channels) {
      try {
        if (channel === "push") {
          // --- PUSH: OneSignal first, FCM fallback ---
          const oneSignalApiKey = Deno.env.get("ONESIGNAL_REST_API_KEY");
          let oneSignalOk = false;

          if (oneSignalApiKey) {
            try {
              const controller = new AbortController();
              const timer = setTimeout(() => controller.abort(), ONESIGNAL_TIMEOUT_MS);
              const response = await fetch("https://onesignal.com/api/v1/notifications", {
                method: "POST",
                headers: {
                  "Content-Type": "application/json",
                  Authorization: `Basic ${oneSignalApiKey}`,
                },
                body: JSON.stringify({
                  app_id: ONESIGNAL_APP_ID,
                  contents: { en: body },
                  headings: { en: title },
                  large_icon: "launcher_icon",
                  small_icon: "ic_launcher_foreground",
                  android_accent_color: "FF4CD7F6",
                  include_aliases: { external_id: [user_id] },
                  target_channel: "push",
                }),
                signal: controller.signal,
              });
              clearTimeout(timer);

              const osBody = await response.json().catch(() => ({} as Record<string, unknown>));
              const recipients = Number(osBody?.recipients ?? 0);
              const hasErrors = osBody?.errors != null;
              const osId = osBody?.id ?? null;

              // An alias-targeted send is accepted when OneSignal returns 200 with a
              // notification id and no errors; the recipients count in that immediate
              // response is resolved asynchronously and is NOT authoritative. Only a
              // real error (e.g. "All included players are not subscribed") means
              // nobody was reached. Treating recipients===0 as failure would fall back
              // to FCM on every send and deliver the notification twice.
              if (response.ok && !hasErrors && osId != null) {
                oneSignalOk = true;
                results["push"] = `Delivered via OneSignal (id ${osId}, recipients ${recipients}).`;
                logDelivery("push_onesignal", "delivered", results["push"], response.status);
              } else {
                results["push"] =
                  `OneSignal did not deliver (status ${response.status}, errors ${JSON.stringify(osBody?.errors ?? null)}). Falling back to FCM.`;
                logDelivery(
                  "push_onesignal",
                  "failed",
                  `status ${response.status}, recipients ${recipients}, id ${osId}, errors ${JSON.stringify(osBody?.errors ?? null)}`,
                  response.status,
                );
              }
            } catch (e) {
              results["push"] = `OneSignal error: ${(e as Error).message}. Falling back to FCM.`;
              logDelivery("push_onesignal", "failed", `Exception: ${(e as Error).message ?? e}`);
            }
          } else {
            logDelivery("push_onesignal", "skipped", "ONESIGNAL_REST_API_KEY not configured.");
          }

          if (!oneSignalOk) {
            const fcm = await sendFcm(supabase, user_id, title, body, action_url ?? null);
            results["push_fcm"] = fcm.detail;
            logDelivery("push_fcm", fcm.status, fcm.detail);
          }
        }

        else if (channel === "telegram") {
          const tgToken = Deno.env.get("TELEGRAM_BOT_TOKEN");
          const { data: channelData } = await supabase
            .from("notification_channels")
            .select("config")
            .eq("user_id", user_id)
            .eq("channel_type", "telegram")
            .eq("is_enabled", true)
            .maybeSingle();

          const chatId = channelData?.config?.chat_id;
          if (tgToken && chatId) {
            const response = await fetch(`https://api.telegram.org/bot${tgToken}/sendMessage`, {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({
                chat_id: chatId,
                text: `*${title}*\n\n${body}`,
                parse_mode: "Markdown",
              }),
            });
            results["telegram"] = `Delivered. Status: ${response.status}`;
            logDelivery("telegram", response.ok ? "delivered" : "failed", results["telegram"], response.status);
          } else {
            results["telegram"] = "Skipped: Telegram Bot Token or Chat ID not configured.";
            logDelivery("telegram", "skipped", results["telegram"]);
          }
        }

        else if (channel === "email") {
          const isDeactivationThreat =
            category === "top_up_failed" || category === "line_critical" || category === "wallet_depleted";

          if (!isDeactivationThreat && !isFallbackTriggered) {
            results["email"] = "Skipped: Non-critical email bypassed to protect Resend free plan limits.";
            logDelivery("email", "skipped", results["email"]);
            continue;
          }

          const resendKey = Deno.env.get("RESEND_API_KEY");
          const { data: channelData } = await supabase
            .from("notification_channels")
            .select("config")
            .eq("user_id", user_id)
            .eq("channel_type", "email")
            .eq("is_enabled", true)
            .maybeSingle();

          let emailAddress = channelData?.config?.email_address;
          if (!emailAddress) {
            const { data: profile } = await supabase
              .from("profiles")
              .select("email")
              .eq("id", user_id)
              .maybeSingle();
            emailAddress = profile?.email;
          }

          if (resendKey && emailAddress) {
            const fallbackWarning = isFallbackTriggered
              ? `<p style="color:#ef4444;font-weight:bold;">⚠️ AUTOMATED FALLBACK: We could not reach you via WhatsApp, so this alert was rerouted to your email.</p>`
              : "";

            const response = await fetch("https://api.resend.com/emails", {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                Authorization: `Bearer ${resendKey}`,
              },
              body: JSON.stringify({
                from: "SIM Shield <alerts@keep-sims.com>",
                to: emailAddress,
                subject: isFallbackTriggered ? `[Fallback Alert] ${title}` : title,
                html: `<div style="font-family:sans-serif;padding:30px;background-color:#0d0e12;color:#ffffff;border-radius:16px;max-width:600px;margin:0 auto;border:1px solid #1f222e;">
                         <h2 style="color:#ef4444;border-bottom:1px solid #1f222e;padding-bottom:12px;margin-top:0;">${title}</h2>
                         ${fallbackWarning}
                         <p style="font-size:16px;line-height:1.6;color:#a9abb3;">${body}</p>
                         <p style="font-size:14px;color:#858894;margin-top:20px;">Please open the KeepSIMs application to resolve any outstanding wallet issues or SIM line blocks immediately.</p>
                         <div style="margin-top:30px;padding:16px;background-color:#161822;border-radius:8px;font-size:11px;color:#4b5563;border:1px solid #202433;">
                           Notification event reference: ${notification_id} • Shield Auto-Protection System
                         </div>
                       </div>`,
              }),
            });
            results["email"] = `Delivered. Status: ${response.status}`;
            logDelivery("email", response.ok ? "delivered" : "failed", results["email"], response.status);
          } else {
            results["email"] = "Skipped: Resend API Key or recipient email not configured.";
            logDelivery("email", "skipped", results["email"]);
          }
        }

        else if (channel === "whatsapp") {
          if (!sim_line_id) {
            results["whatsapp"] = "Skipped: No SIM line ID provided for WhatsApp route.";
            logDelivery("whatsapp", "skipped", results["whatsapp"]);
            continue;
          }

          const vpsApiKey = Deno.env.get("WHATSAPP_VPS_API_KEY");
          if (!vpsApiKey) {
            results["whatsapp"] = "Skipped: WHATSAPP_VPS_API_KEY not configured.";
            logDelivery("whatsapp", "skipped", results["whatsapp"]);
            continue;
          }

          const { data: schedule } = await supabase
            .from("scheduled_topups")
            .select("id, is_active, status, whatsapp_sent_this_cycle, schedule_type")
            .eq("sim_line_id", sim_line_id)
            .maybeSingle();

          const autoRefillApplied =
            schedule?.is_active === true && schedule?.status === "active" && schedule?.schedule_type === "refill";

          if (autoRefillApplied && category !== "top_up_failed") {
            results["whatsapp"] = "Skipped: Auto-refill is active and healthy. WhatsApp reminder unnecessary.";
            logDelivery("whatsapp", "skipped", results["whatsapp"]);
            continue;
          }

          if (schedule?.whatsapp_sent_this_cycle === true) {
            results["whatsapp"] = "Skipped: WhatsApp alert already delivered for this schedule cycle.";
            logDelivery("whatsapp", "skipped", results["whatsapp"]);
            continue;
          }

          let nodeApiUrl = Deno.env.get("WHATSAPP_NODE_API_URL") || "http://34.185.194.90:3000/send";
          const { data: simLine } = await supabase
            .from("sim_lines")
            .select("country_id")
            .eq("id", sim_line_id)
            .maybeSingle();

          const countryId = simLine?.country_id;
          if (countryId) {
            const now = Date.now();
            const cached = countryCache[countryId];
            if (cached && now - cached.timestamp < CACHE_TTL) {
              nodeApiUrl = cached.url;
            } else {
              const { data: country } = await supabase
                .from("countries")
                .select("whatsapp_server_url")
                .eq("id", countryId)
                .maybeSingle();
              if (country?.whatsapp_server_url) {
                nodeApiUrl = country.whatsapp_server_url;
                countryCache[countryId] = { url: nodeApiUrl, timestamp: now };
              }
            }
          }

          if (!nodeApiUrl.endsWith("/send")) {
            nodeApiUrl = nodeApiUrl.endsWith("/") ? `${nodeApiUrl}send` : `${nodeApiUrl}/send`;
          }

          const { data: channelData } = await supabase
            .from("notification_channels")
            .select("config")
            .eq("user_id", user_id)
            .eq("channel_type", "whatsapp")
            .eq("is_enabled", true)
            .maybeSingle();

          const phoneNumber = channelData?.config?.phone_number || channelData?.config?.phone;
          if (phoneNumber) {
            const cleanPhone = String(phoneNumber).replace(/[^0-9]/g, "");
            const messageBody = `*${title}*\n\n${body}`;
            try {
              const response = await fetch(nodeApiUrl, {
                method: "POST",
                headers: { "Content-Type": "application/json", "x-api-key": vpsApiKey },
                body: JSON.stringify({ phone: cleanPhone, message: messageBody }),
              });
              if (response.ok) {
                results["whatsapp"] = "Delivered successfully via KeepSIMs VPS.";
                logDelivery("whatsapp", "delivered", results["whatsapp"], response.status);
                if (schedule?.id) {
                  await supabase
                    .from("scheduled_topups")
                    .update({ whatsapp_sent_this_cycle: true })
                    .eq("id", schedule.id);
                }
              } else {
                const errTxt = await response.text();
                throw new Error(`Status ${response.status}: ${errTxt}`);
              }
            } catch (err) {
              results["whatsapp"] = `Failed via VPS. Error: ${(err as Error).message}. FALLBACK TRIGGERED!`;
              logDelivery("whatsapp", "failed", results["whatsapp"]);
              isFallbackTriggered = true;
              if (!channels.includes("email")) channels.push("email");
              if (!channels.includes("push")) channels.push("push");
            }
          } else {
            results["whatsapp"] = "Skipped: Destination phone not configured.";
            logDelivery("whatsapp", "skipped", results["whatsapp"]);
          }
        }

        else if (channel === "webhook") {
          const { data: channelData } = await supabase
            .from("notification_channels")
            .select("config")
            .eq("user_id", user_id)
            .eq("channel_type", "webhook")
            .eq("is_enabled", true)
            .maybeSingle();

          const webhookUrl = channelData?.config?.url;
          if (webhookUrl) {
            const response = await fetch(webhookUrl, {
              method: "POST",
              headers: { "Content-Type": "application/json", "x-keep-sims-event": category },
              body: JSON.stringify({
                event: category,
                title,
                body,
                sim_line_id,
                timestamp: new Date().toISOString(),
              }),
            });
            results["webhook"] = `Delivered. Status: ${response.status}`;
            logDelivery("webhook", response.ok ? "delivered" : "failed", results["webhook"], response.status);
          } else {
            results["webhook"] = "Skipped: Webhook URL not configured.";
            logDelivery("webhook", "skipped", results["webhook"]);
          }
        }
      } catch (err) {
        results[channel] = `Exception: ${(err as Error).message || err}`;
        logDelivery(channel, "failed", `Exception: ${(err as Error).message || err}`);
      }
    }

    // 3. Persist the delivery log (best-effort; never fail the response on it).
    if (deliveries.length > 0) {
      const { error: logErr } = await supabase.from("notification_deliveries").insert(deliveries);
      if (logErr) results["_log_error"] = logErr.message;
    }

    return new Response(JSON.stringify({ success: true, results }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: (e as Error).message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
