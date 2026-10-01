import { postOneSignal, pushIdempotencyKey, uniquePushDevices } from "./push_delivery.ts";
import { routeAndSendWhatsApp } from "../_shared/whatsapp_router.ts";
import { deliverTarget, httpOutcome, escapeHtml, type TargetOutcome } from "../_shared/notification_delivery.ts";

export async function dispatchChannels(db: any, p: any, fcm: any) {
  const outcomes: TargetOutcome[] = [], deliveries: any[] = [];
  const log = (channel: string, status: string, detail: string, providerStatus: number | null = null) =>
    deliveries.push({ notification_id: p.notification_id, user_id: p.user_id, channel,
      status, detail: detail.slice(0, 1000), provider_status: providerStatus });
  for (const channel of [...new Set(p.channels)] as string[]) {
    if (channel === "push") {
      const { data, error } = await db.from("device_push_tokens")
        .select("device_id,onesignal_player_id,fcm_token,updated_at")
        .eq("user_id", p.user_id).order("updated_at", { ascending: false });
      if (error) { outcomes.push({ channel, target: "devices", state: "failed", retryable: true, detail: "Cannot load registered push devices; no send attempted." }); continue; }
      const devices = uniquePushDevices(data || []).filter((d: any) => d.onesignal_player_id || d.fcm_token);
      if (!devices.length) { outcomes.push({ channel, target: "devices", state: "skipped", detail: "No push devices registered." }); continue; }
      for (const device of devices) {
        const target = device.device_id || device.onesignal_player_id || device.fcm_token;
        const outcome = await deliverTarget(db, p.notification_id, channel, String(target), { ...device, message: p }, async (snapshot) => {
          const { message: p, ...saved } = snapshot;
          const key = Deno.env.get("ONESIGNAL_REST_API_KEY");
          if (saved.onesignal_player_id && key) {
            const os = await postOneSignal({
              app_id: p.onesignalAppId, include_subscription_ids: [saved.onesignal_player_id],
              idempotency_key: await pushIdempotencyKey(p.notification_id, saved.onesignal_player_id),
              contents: p.contents, headings: p.headings, large_icon: "launcher_icon", small_icon: "ic_stat_keepsims",
              android_accent_color: "FF4CD7F6", existing_android_channel_id: p.channelId,
              priority: 10, collapse_id: p.notification_id, data: p.pushData,
            }, key);
            const state = os.outcome === "accepted" ? "accepted_by_provider" : os.outcome === "unknown" ? "unknown" : "failed";
            const detail = `OneSignal ${os.outcome} for device ${target}; display not confirmed. ${os.detail || ""}`;
            log("push_onesignal", state, detail, os.status);
            if (os.outcome !== "rejected") return { state: state as any, detail };
          }
          if (!saved.fcm_token) return { state: "failed", retryable: false, detail: "Push transport rejected this device and no FCM fallback is registered." };
          const result = await fcm([saved], p);
          log("push_fcm", result.status, result.detail);
          return { state: result.status, detail: result.detail, retryable: result.retryable === true };
        });
        outcomes.push(outcome);
      }
      continue;
    }

    const { data: row, error } = await db.from("notification_channels").select("config")
      .eq("user_id", p.user_id).eq("channel_type", channel).eq("is_enabled", true).maybeSingle();
    if (error) { outcomes.push({ channel, target: "primary", state: "failed", retryable: true, detail: "Cannot load the channel configuration; no send attempted." }); continue; }
    if (!row && channel !== "push") { outcomes.push({ channel, target: "primary", state: "skipped", detail: "Channel is disabled or unavailable." }); continue; }
    let config = row?.config || {};
    if (channel === "email" && !config.email_address && !config.email) {
      const { data: user, error: profileError } = await db.from("profiles").select("email").eq("id", p.user_id).maybeSingle();
      if (profileError) { outcomes.push({ channel, target: "primary", state: "failed", retryable: true, detail: "Cannot load the account email." }); continue; }
      config = { ...config, email: user?.email };
    }
    const outcome = await deliverTarget(db, p.notification_id, channel, "primary", { ...config, message: p }, async (snapshot) => {
      const { message: p, ...saved } = snapshot;
      const recipient = (c: any) => channel === "email" ? c.email_address || c.email : channel === "telegram"
        ? c.chat_id : channel === "whatsapp" ? c.phone_number || c.phone : c.url;
      if (recipient(saved) !== recipient(config)) return { state: "skipped", detail: "Saved recipient changed; the original alert is withheld." };
      if (channel === "telegram") {
        const token = Deno.env.get("TELEGRAM_BOT_TOKEN");
        if (!token || !saved.chat_id || !saved.binding_verified_at) return { state: "skipped", detail: "Telegram must be linked through the verified bot binding." };
        const response = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
          method: "POST", headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ chat_id: saved.chat_id, text: `${p.title}\n\n${p.body}` }),
          signal: AbortSignal.timeout(10000),
        });
        const body = await response.json().catch(() => null);
        if (!body || (response.ok && body.ok !== true)) return { state: "unknown", detail: "Telegram response did not confirm acceptance or rejection." };
        return httpOutcome("Telegram", response.status, response.ok && body.ok === true);
      }
      if (channel === "email") {
        const { data: eligible, error: eligibilityError } = await db.rpc("notification_channel_eligible", {
          p_user_id: p.user_id, p_sim_line_id: p.sim_line_id || null, p_channel: "email", p_event_type: p.event_type || null,
        });
        if (eligibilityError) return { state: "failed", retryable: true, detail: "Cannot verify Email eligibility; no send attempted." };
        if (!eligible) return { state: "skipped", detail: "Email requires an eligible Standard or Premium originating line." };
        const critical = ["top_up_failed", "line_critical", "wallet_depleted"].includes(p.category);
        const confirmation = ["line_added", "auto_recharge_scheduled", "line_setup_incomplete", "weekly_digest", "notification_test"].includes(p.event_type);
        if (!critical && !confirmation) return { state: "skipped", detail: "Email covers critical line alerts, setup confirmations and opted-in weekly summaries." };
        const token = Deno.env.get("RESEND_API_KEY"), address = saved.email_address || saved.email;
        if (!token || !address) return { state: "skipped", detail: "Email sender or recipient is not configured." };
        const response = await fetch("https://api.resend.com/emails", {
          method: "POST", headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}`,
            "Idempotency-Key": `${p.notification_id}:email:primary` },
          body: JSON.stringify({ from: "KeepSIMs <alerts@keepsims.com>", to: address, subject: p.title,
            html: `<div style="font-family:sans-serif"><h2>${escapeHtml(p.title)}</h2><p>${escapeHtml(p.body)}</p><p>Open KeepSIMs to review your lines.</p></div>` }),
          signal: AbortSignal.timeout(10000),
        });
        return httpOutcome("Resend", response.status, response.ok);
      }
      if (channel === "whatsapp") {
        const phone = saved.phone_number || saved.phone;
        if (!phone) return { state: "skipped", detail: "WhatsApp recipient is not configured." };
        const result = await routeAndSendWhatsApp(db, { purpose: "subscription_alert", recipientPhone: phone,
          titleText: p.title, bodyText: p.body, notificationId: p.notification_id, simLineId: p.sim_line_id,
          userId: p.user_id, category: p.category, eventType: p.event_type });
        return { state: result.state === "accepted" || result.state === "sent" ? "accepted_by_provider" : result.state,
          detail: result.detail, retryable: result.retryable === true };
      }
      // Webhook destinations must be configured by the owner, not customer JSON.
      if (channel === "webhook") {
        if (saved.owner_verified !== true || !saved.url || !saved.url.startsWith("https://")) return { state: "skipped", detail: "Webhook destination requires owner verification and HTTPS." };
        const response = await fetch(saved.url, { method: "POST", redirect: "error",
          headers: { "Content-Type": "application/json", "x-keep-sims-event": p.category,
            "Idempotency-Key": `${p.notification_id}:webhook:primary` },
          body: JSON.stringify({ event: p.category, title: p.title, body: p.body,
            sim_line_id: p.sim_line_id, notification_id: p.notification_id }), signal: AbortSignal.timeout(10000) });
        if (response.status >= 500) return { state: "unknown", detail: "Webhook returned a server error; receiver side effects require reconciliation." };
        return httpOutcome("Webhook", response.status, response.ok);
      }
      return { state: "skipped", detail: "Unsupported channel." };
    });
    outcomes.push(outcome);
    log(channel, outcome.state, outcome.detail);
  }
  return { outcomes, deliveries };
}
