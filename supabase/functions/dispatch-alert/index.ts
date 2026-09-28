// dispatch-alert — KeepSIMs notification dispatcher (C1).
//
// Invoked by the public.notifications AFTER INSERT trigger
// (trg_fn_dispatch_notification) via pg_net. Delivery model:
//   push  -> OneSignal per device; only definitive rejection falls back to FCM.
//            Ambiguous sends are retried with the same idempotency key.
//   email -> Resend (quota-guarded for non-critical categories)
//   telegram / whatsapp / webhook -> unchanged legacy channels.
// Every attempt is logged to public.notification_deliveries.
//
// Which channels arrive here is decided by the trigger: it intersects the
// user's global notification_channels switches with the per-category opt-in in
// alert_settings.channels (C2), so this function just delivers what it is told.
//
// Secrets: the trigger authenticates with a shared secret stored in Supabase
// Vault (dispatch_shared_secret), read back here via the get_internal_secret
// RPC. Provider keys come from Edge Function secrets / env only.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

import { postOneSignal, pushIdempotencyKey, routePushDevices, type PushDevice } from "./push_delivery.ts";
import { routeAndSendWhatsApp } from "../_shared/whatsapp_router.ts";

const ONESIGNAL_APP_ID = "434b9552-8005-4d08-b3b1-a7a35f0b15dc";


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
  channelId = "ks_updates_v1",
  isUrgent = false,
  extraData: Record<string, string>,
  devices: PushDevice[],
): Promise<{ status: "accepted_by_provider" | "failed" | "skipped"; detail: string }> {
  const saRaw = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
  if (!saRaw) return { status: "skipped", detail: "FCM_SERVICE_ACCOUNT_JSON not configured." };

  let sa: { project_id: string; client_email: string; private_key: string };
  try {
    sa = JSON.parse(saRaw);
  } catch {
    return { status: "failed", detail: "FCM service account JSON is invalid." };
  }

  const tokens = [...new Set(devices.flatMap((d) => d.fcm_token ? [d.fcm_token] : []))];
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
              android: {
                priority: "HIGH", // Visible user notifications should not wait for Doze.
                notification: {
                  channel_id: channelId,
                  icon: "ic_stat_keepsims",
                  tag: extraData.notification_id || undefined,
                  color: "#4CD7F6",
                },
              },
              data: {
                ...extraData,
                action_url: actionUrl || "",
              },
            },
          }),
        },
      );
      if (r.ok) {
        ok++;
      } else {
        const errJson = await r.json().catch(() => ({} as Record<string, any>));
        const errorCode =
          errJson?.error?.details?.find((d: any) => d["@type"]?.includes("FcmError"))?.errorCode ||
          errJson?.error?.status ||
          `HTTP ${r.status}`;
        errs.push(errorCode);

        // Terminal invalid token handling: UNREGISTERED means app uninstalled or token expired
        if (errorCode === "UNREGISTERED" || errJson?.error?.status === "NOT_FOUND") {
          console.warn(`[sendFcm] Token UNREGISTERED for user ${userId}; pruning stale device token.`);
          // Safe compare-and-clear so concurrent refreshed tokens are preserved
          await supabase
            .from("device_push_tokens")
            .update({ fcm_token: null, updated_at: new Date().toISOString() })
            .eq("user_id", userId)
            .eq("fcm_token", token);
        }
      }
    } catch (e) {
      errs.push((e as Error).message ?? String(e));
    }
  }

  if (ok > 0) {
    const failureSummary = errs.length > 0 ? `; failed: ${errs.join(", ")}` : "";
    return { status: errs.length ? "failed" : "accepted_by_provider", detail: `FCM accepted ${ok}/${tokens.length} device message(s); display not confirmed${failureSummary}.` };
  }
  return { status: "failed", detail: `FCM failed on all ${tokens.length} device(s): ${errs.join("; ")}` };
}

// --------------------------------------------------------------------------
serve(async (req: Request) => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  // 1. Validate authorization: accept shared secret OR service role key
  const reqSecret = req.headers.get("x-keep-sims-secret");
  const authHeader = req.headers.get("Authorization");
  const isServiceRole = authHeader === `Bearer ${supabaseServiceKey}`;

  if (!isServiceRole) {
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
  }

  try {
    const payload = await req.json();

    // Fast-path: Direct VoIP Incoming Call Wakeup Push
    if (payload.category === "voip_call") {
      const { user_id, voip_payload, fcm_tokens } = payload;
      let delivered = false;
      let onesignalResult = null;
      let fcmResult = null;

      // 1. Fetch registered push devices for this user
      const { data: devices } = await supabase
        .from("device_push_tokens")
        .select("device_id, onesignal_player_id, fcm_token")
        .eq("user_id", user_id);

      const oneSignalApiKey = Deno.env.get("ONESIGNAL_REST_API_KEY");
      const callerName = voip_payload?.caller_name || "KeepSIMs User";
      const dispatchId = voip_payload?.call_id || crypto.randomUUID();

      // Dispatch via OneSignal
      if (oneSignalApiKey && devices && devices.length > 0) {
        for (const device of devices) {
          if (device.onesignal_player_id) {
            try {
              const res = await postOneSignal({
                app_id: ONESIGNAL_APP_ID,
                include_subscription_ids: [device.onesignal_player_id],
                idempotency_key: await pushIdempotencyKey(dispatchId, device.onesignal_player_id),
                contents: { en: `${callerName} is calling you...` },
                headings: { en: "Incoming KeepSIMs Call" },
                large_icon: "launcher_icon",
                small_icon: "ic_stat_keepsims",
                android_accent_color: "FF4CD7F6",
                existing_android_channel_id: "ks_urgent_v1",
                priority: 10,
                collapse_id: dispatchId,
                data: {
                  type: "INCOMING_VOIP_CALL",
                  action_url: `/calling/active/${voip_payload?.call_id || ""}`,
                  ...(voip_payload || {}),
                },
              }, oneSignalApiKey);
              if (res.outcome === "accepted") delivered = true;
              onesignalResult = res;
            } catch (e) {
              console.error("[dispatch-alert] OneSignal voip error:", e);
            }
          }
        }
      }

      // Also dispatch via direct FCM
      const allFcmTokens = [
        ...(Array.isArray(fcm_tokens) ? fcm_tokens : []),
        ...(devices || []).map((d: any) => d.fcm_token).filter(Boolean),
      ];
      const uniqueFcm = [...new Set(allFcmTokens)];

      if (uniqueFcm.length > 0) {
        try {
          const fcmRes = await sendFcm(
            supabase,
            user_id,
            `Incoming call from ${callerName}`,
            "Tap to answer",
            `/calling/active/${voip_payload?.call_id || ""}`,
            "ks_urgent_v1",
            true,
            {
              type: "INCOMING_VOIP_CALL",
              ...(voip_payload || {}),
            },
            uniqueFcm.map((t: string) => ({ fcm_token: t, device_id: "voip_device", onesignal_player_id: null })),
          );
          if (fcmRes.status === "delivered") delivered = true;
          fcmResult = fcmRes;
        } catch (e) {
          console.error("[dispatch-alert] FCM voip error:", e);
        }
      }

      return new Response(JSON.stringify({ success: true, delivered, onesignal: onesignalResult, fcm: fcmResult }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const {
      notification_id,
      user_id,
      category,
      title,
      body,
      action_url,
      sim_line_id,
      channels,
      event_type,
      template_data,
      target,
      language,
    } = payload;

    const results: Record<string, string> = {};
    const deliveries: Array<Record<string, unknown>> = [];

    const logDelivery = (
      channel: string,
      status: "delivered" | "failed" | "skipped" | "accepted_by_provider" | "retrying" | "unknown",
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

    // Priority, Android Channel, and Large Icon resolution
    const isUrgent =
      event_type === "recharge_due_today" ||
      event_type === "recharge_failed" ||
      event_type === "recharge_blocked_funds" ||
      event_type === "line_critical" ||
      category === "top_up_failed" ||
      category === "line_critical" ||
      category === "wallet_depleted";

    const isQuiet =
      event_type === "line_added" ||
      event_type === "auto_recharge_scheduled";

    let channelId = "ks_updates_v1";
    if (isUrgent) {
      channelId = "ks_urgent_v1";
    } else if (isQuiet) {
      channelId = "ks_confirmations_v1";
    }

    let largeIcon = "ic_notif_reminder";
    if (
      event_type === "line_added" ||
      event_type === "auto_recharge_scheduled" ||
      event_type === "recharge_succeeded" ||
      category === "top_up_success"
    ) {
      largeIcon = "ic_notif_success";
    } else if (event_type === "recharge_failed" || category === "top_up_failed") {
      largeIcon = "ic_notif_error";
    } else if (
      event_type === "recharge_due_today" ||
      event_type === "line_setup_incomplete" ||
      event_type === "wallet_low" ||
      event_type === "recharge_blocked_funds" ||
      event_type === "line_critical" ||
      category === "wallet_low" ||
      category === "line_critical"
    ) {
      largeIcon = "ic_notif_warning";
    }

    // Localized headings and contents
    const userLang = language || "en";
    const headings: Record<string, string> = { en: title };
    const contents: Record<string, string> = { en: body };
    if (userLang !== "en") {
      headings[userLang] = title;
      contents[userLang] = body;
    }

    const canonicalActionUrl = action_url || (sim_line_id ? `/sim-lines/detail/${sim_line_id}` : "");
    const pushData: Record<string, string> = {
      notification_id: notification_id ? String(notification_id) : "",
      sim_line_id: sim_line_id ? String(sim_line_id) : "",
      action_url: canonicalActionUrl,
      event_type: event_type ? String(event_type) : "",
      target: target ? (typeof target === "string" ? target : JSON.stringify(target)) : "",
    };

    // 2. Dispatch only the channels selected by the preference/entitlement gate.
    for (const channel of channels) {
      try {
        if (channel === "push") {
          const oneSignalApiKey = Deno.env.get("ONESIGNAL_REST_API_KEY");
          const { data: rows, error } = await supabase
            .from("device_push_tokens")
            .select("device_id, onesignal_player_id, fcm_token, updated_at")
            .eq("user_id", user_id)
            .order("updated_at", { ascending: false });
          if (error) throw new Error("Cannot load push devices: " + error.message);
          const devices = (rows ?? []) as PushDevice[];
          if (!devices.some((d) => d.onesignal_player_id || d.fcm_token)) {
            logDelivery("push", "skipped", "No push devices registered.");
          }
          const dispatchId = notification_id || crypto.randomUUID();
          await routePushDevices(devices, async (device) => {
            if (!oneSignalApiKey) {
              logDelivery("push_onesignal", "skipped", "ONESIGNAL_REST_API_KEY not configured.");
              return "rejected";
            }
            const response = await postOneSignal({
              app_id: ONESIGNAL_APP_ID,
              include_subscription_ids: [device.onesignal_player_id],
              idempotency_key: await pushIdempotencyKey(dispatchId, device.onesignal_player_id!),
              contents,
              headings,
              large_icon: "launcher_icon",
              small_icon: "ic_stat_keepsims",
              android_accent_color: "FF4CD7F6",
              existing_android_channel_id: channelId,
              priority: 10,
              collapse_id: dispatchId,
              data: pushData,
            }, oneSignalApiKey);
            const label = device.device_id || device.onesignal_player_id;
            const detail = response.outcome === "accepted"
              ? `OneSignal accepted for device ${label} (id ${response.id}); display not confirmed.`
              : `OneSignal ${response.outcome} for device ${label}: ${response.detail}.`;
            results["push"] = detail;
            logDelivery("push_onesignal", response.outcome === "accepted"
              ? "accepted_by_provider"
              : response.outcome === "unknown" ? "unknown" : "failed",
              detail + (response.outcome === "unknown" ? " FCM withheld to avoid a duplicate; retry with the same notification ID." : ""),
              response.status);
            return response.outcome;
          }, async (fallbackDevices) => {
            const fcm = await sendFcm(supabase, user_id, title, body,
              canonicalActionUrl, channelId, isUrgent, pushData, fallbackDevices);
            results["push_fcm"] = fcm.detail;
            logDelivery("push_fcm", fcm.status, fcm.detail);
          });
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
            results["telegram"] = response.ok
              ? `Telegram accepted the message (HTTP ${response.status}); recipient delivery is unconfirmed.`
              : `Telegram rejected the message (HTTP ${response.status}).`;
            logDelivery("telegram", response.ok ? "accepted_by_provider" : "failed", results["telegram"], response.status);
          } else {
            results["telegram"] = "Skipped: Telegram Bot Token or Chat ID not configured.";
            logDelivery("telegram", "skipped", results["telegram"]);
          }
        }

        else if (channel === "email") {
          // Verify tier: only Standard and Premium lines/users receive email alerts
          let userTier = "standard";
          if (sim_line_id) {
            const { data: line } = await supabase
              .from("sim_lines")
              .select("protection_tier, plan_type")
              .eq("id", sim_line_id)
              .maybeSingle();
            if (line?.protection_tier) {
              userTier = line.protection_tier.toLowerCase();
            } else if (line?.plan_type) {
              userTier = line.plan_type.toLowerCase();
            }
          }
          if (userTier === "standard" || userTier === "basic") {
            const { data: profile } = await supabase
              .from("profiles")
              .select("subscription_tier")
              .eq("id", user_id)
              .maybeSingle();
            if (profile?.subscription_tier) {
              const profileTier = profile.subscription_tier.toLowerCase();
              if (profileTier === "premium") userTier = "premium";
              else if (userTier === "basic") userTier = profileTier;
            }
          }

          const isStandardOrPremium = userTier === "standard" || userTier === "premium";
          if (!isStandardOrPremium) {
            results["email"] = "Skipped: Email alerts require Standard or Premium plan.";
            logDelivery("email", "skipped", results["email"]);
            continue;
          }

          const isDeactivationThreat =
            category === "top_up_failed" || category === "line_critical" || category === "wallet_depleted";
          const isLineAdded = event_type === "line_added";
          const isWeeklyDigest = event_type === "weekly_digest";

          if (!isDeactivationThreat && !isLineAdded && !isWeeklyDigest) {
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

          // The settings UI writes config.email; older rows/tests use
          // config.email_address. Accept both — reading only the latter meant a
          // user's configured address was silently ignored in favour of their
          // account email (same shape as the phone_number/phone pair below).
          let emailAddress = channelData?.config?.email_address ?? channelData?.config?.email;
          if (!emailAddress) {
            const { data: profile } = await supabase
              .from("profiles")
              .select("email")
              .eq("id", user_id)
              .maybeSingle();
            emailAddress = profile?.email;
          }

          if (resendKey && emailAddress) {
            const headerColor = isDeactivationThreat ? "#ef4444" : "#10b981";
            const footerNote = isDeactivationThreat
              ? "Please open the KeepSIMs application to resolve any outstanding wallet issues or SIM line blocks immediately."
              : "Your line is now active and protected under your plan. You can view your line details, auto-recharge schedule, and status in the KeepSIMs application.";

            const response = await fetch("https://api.resend.com/emails", {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                Authorization: `Bearer ${resendKey}`,
              },
              body: JSON.stringify({
                from: "KeepSIMs <alerts@keepsims.com>",
                to: emailAddress,
                subject: title,
                html: `<div style="font-family:sans-serif;padding:30px;background-color:#0d0e12;color:#ffffff;border-radius:16px;max-width:600px;margin:0 auto;border:1px solid #1f222e;">
                         <h2 style="color:${headerColor};border-bottom:1px solid #1f222e;padding-bottom:12px;margin-top:0;">${title}</h2>
                         <p style="font-size:16px;line-height:1.6;color:#a9abb3;">${body}</p>
                         <p style="font-size:14px;color:#858894;margin-top:20px;">${footerNote}</p>
                         <div style="margin-top:30px;padding:16px;background-color:#161822;border-radius:8px;font-size:11px;color:#4b5563;border:1px solid #202433;">
                           Notification event reference: ${notification_id} • KeepSIMs Auto-Protection System
                         </div>
                       </div>`,
              }),
            });
            results["email"] = response.ok
              ? `Resend accepted the email (HTTP ${response.status}); inbox delivery is unconfirmed.`
              : `Resend rejected the email (HTTP ${response.status}).`;
            logDelivery("email", response.ok ? "accepted_by_provider" : "failed", results["email"], response.status);
          } else {
            results["email"] = "Skipped: Resend API Key or recipient email not configured.";
            logDelivery("email", "skipped", results["email"]);
          }
        }

        else if (channel === "whatsapp") {
          const { data: channelData } = await supabase
            .from("notification_channels")
            .select("config")
            .eq("user_id", user_id)
            .eq("channel_type", "whatsapp")
            .eq("is_enabled", true)
            .maybeSingle();

          const phoneNumber = channelData?.config?.phone_number || channelData?.config?.phone;
          if (!phoneNumber) {
            results["whatsapp"] = "Skipped: Destination phone not configured in notification channels.";
            logDelivery("whatsapp", "skipped", results["whatsapp"]);
            continue;
          }

          const routeOutcome = await routeAndSendWhatsApp(supabase, {
            purpose: "subscription_alert",
            recipientPhone: String(phoneNumber),
            titleText: title,
            bodyText: body,
            notificationId: notification_id ? String(notification_id) : undefined,
            simLineId: sim_line_id ? String(sim_line_id) : undefined,
            userId: user_id,
            category: category,
            eventType: event_type,
          });

          results["whatsapp"] = routeOutcome.detail;
          const deliveryStatus = (routeOutcome.state === "delivered")
            ? "delivered"
            : (routeOutcome.state === "accepted" || routeOutcome.state === "sent")
            ? "accepted_by_provider"
            : (routeOutcome.state === "unknown" ? "unknown"
              : routeOutcome.state === "skipped" ? "skipped" : "failed");

          logDelivery("whatsapp", deliveryStatus, routeOutcome.detail);
          // Safe retry on selected provider only: do NOT mutate channels or force unsolicited email/push.
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
            results["webhook"] = response.ok
              ? `Webhook endpoint accepted the request (HTTP ${response.status}); downstream processing is unconfirmed.`
              : `Webhook endpoint rejected the request (HTTP ${response.status}).`;
            logDelivery("webhook", response.ok ? "accepted_by_provider" : "failed", results["webhook"], response.status);
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

    // 3. Persist the delivery log before acknowledging the logical dispatch job.
    // Provider sends may already have occurred, so callers quarantine a failed
    // log write as an unknown outcome rather than replaying the job.
    if (deliveries.length > 0) {
      const { error: logErr } = await supabase.from("notification_deliveries").insert(deliveries);
      if (logErr) {
        return new Response(JSON.stringify({ success: false, error: `Delivery log write failed: ${logErr.message}`, results }), {
          status: 503,
          headers: { "Content-Type": "application/json" },
        });
      }

      // Only verified recipient receipts belong in delivered_via.
      if (notification_id) {
        const successfulChannels = [
          ...new Set(
            deliveries
              .filter((d) => d.status === "delivered")
              .map((d) => {
                const ch = String(d.channel);
                if (ch.startsWith("push")) return "push";
                return ch;
              }),
          ),
        ];

        if (successfulChannels.length > 0) {
          await supabase
            .from("notifications")
            .update({ delivered_via: successfulChannels })
            .eq("id", notification_id);
        }
      }
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
