import { profileReady } from "./whatsapp_profile.ts";

// Outbound subscription alerts always obey Admin's recipient-country route.
// A reply is scoped to the authenticated receiving Meta conversation instead.
export async function durableWhatsAppRoute(db: any, req: any, adapters: any): Promise<any> {
  const digits = String(req.recipientPhone || "").replace(/\D/g, "").replace(/^00/, "");
  const phone = `+${digits}`;
  const stop = (category: string, detail: string, state = "skipped") =>
    ({ success: false, state, errorCategory: category, detail, retryable: state === "failed" && category.endsWith("unavailable") });
  if (!/^[1-9]\d{6,14}$/.test(digits)) return stop("invalid_phone", "Enter a valid international phone number.");

  if (req.purpose === "subscription_alert") {
    if (!req.notificationId || !req.userId || !req.simLineId) {
      return stop("line_required", "WhatsApp alerts require an originating SIM line.");
    }
    const { data: permitted, error } = await db.rpc("notification_channel_eligible", {
      p_user_id: req.userId, p_sim_line_id: req.simLineId, p_channel: "whatsapp",
      p_event_type: req.eventType || null,
    });
    if (error) return stop("eligibility_unavailable", "Cannot verify alert eligibility.", "failed");
    if (permitted !== true) return stop("not_eligible", "The originating line or channel is not eligible for WhatsApp alerts.");

    const { data: healthy, error: scheduleError } = await db.rpc("whatsapp_refill_healthy", {
      p_sim_line_id: req.simLineId,
    });
    if (scheduleError) return stop("schedule_unavailable", "Cannot verify refill state.", "failed");
    if (healthy && req.category !== "top_up_failed" && !["notification_test", "line_added", "auto_recharge_scheduled", "line_setup_incomplete"].includes(req.eventType)) {
      return stop("auto_refill_suppressed", "A healthy automatic refill is protecting this line.");
    }
  }

  const { data: countryId, error: countryError } = await db.rpc("resolve_country_by_phone", { p_phone: phone });
  if (countryError && req.purpose !== "offline_refill_reply") return stop("routing_unavailable", "Country routing could not be verified.", "failed");
  let route: any;
  let profile: any;
  if (req.purpose === "offline_refill_reply") {
    if (!req.replyProfileId || !req.replyPhoneNumberId || !req.commandId) {
      return stop("reply_identity_missing", "The verified receiving Meta profile is required.");
    }
    const { data, error } = await db.from("whatsapp_provider_profiles")
      .select("id,provider_kind,label,expected_sender_number,observed_sender_number,is_enabled,ready_state,version,connection_metadata")
      .eq("id", req.replyProfileId).maybeSingle();
    if (error) return stop("profile_unavailable", "Cannot verify the receiving profile.", "failed");
    profile = data;
    if (profile?.provider_kind !== "meta_cloud" ||
        profile.connection_metadata?.phone_number_id !== req.replyPhoneNumberId) {
      return stop("reply_identity_mismatch", "The reply must use the authenticated receiving Meta sender.");
    }
    route = { route_mode: "meta_cloud", profile_id: profile.id, version: profile.version };
  } else {
    if (!countryId) return stop("country_unresolved", "No country matches this international number.");
    const { data, error } = await db.from("whatsapp_country_routes")
      .select("route_mode,profile_id,version,health_reason").eq("country_id", countryId).maybeSingle();
    if (error) return stop("routing_unavailable", "Cannot load the Admin country selection.", "failed");
    route = data;
    if (!route || route.route_mode === "disabled" || !route.profile_id) {
      return stop("route_disabled", "WhatsApp is disabled or unconfigured for this recipient country.");
    }
    const { data: assigned, error: profileError } = await db.from("whatsapp_provider_profiles")
      .select("id,provider_kind,label,expected_sender_number,observed_sender_number,is_enabled,ready_state,version,connection_metadata")
      .eq("id", route.profile_id).maybeSingle();
    if (profileError) return stop("profile_unavailable", "Cannot load the assigned provider.", "failed");
    profile = assigned;
  }
  if (!profileReady(profile) || profile.provider_kind !== route.route_mode) {
    return stop("profile_not_ready", "The selected provider must be ready with its expected sender verified.");
  }

  const conversation = req.purpose === "offline_refill_reply" ? `${req.replyProfileId}_` : "";
  const key = req.idempotencyKey || `${req.purpose}_${req.notificationId || req.commandId || crypto.randomUUID()}_${conversation}${digits}`;
  const snapshot = {
    purpose: req.purpose, notification_id: req.notificationId || null,
    command_id: req.commandId || null, recipient_phone: phone, recipient_country_id: countryId || null,
    sim_line_id: req.simLineId || null, route_mode: route.route_mode,
    profile_id: profile.id, profile_version: profile.version,
    sender_number: profile.expected_sender_number,
    template_name: req.templateName || null, template_language: req.templateLanguage || null,
    request: { ...req, recipientPhone: phone },
  };
  const { data: claim, error: claimError } = await db.rpc("claim_whatsapp_message_attempt", {
    p_key: key, p_snapshot: snapshot,
  });
  if (claimError || !claim) return stop("outbox_unavailable", "Could not persist and claim the WhatsApp send.", "failed");
  const attempt = claim.attempt;
  if (!claim.claimed) {
    const state = claim.state || attempt?.state || "unknown";
    return { success: ["accepted", "sent", "delivered"].includes(state),
      state: state === "pending" ? "unknown" : state,
      detail: claim.detail || "Existing WhatsApp attempt retained; duplicate send withheld.",
      attemptId: attempt?.id, provider: attempt?.route_mode || route.route_mode,
      countryId, errorCategory: claim.reason, retryable: false };
  }

  const frozenReq = attempt.request_snapshot || req;
  let outcome: any;
  try {
    const adapter = attempt.route_mode === "baileys" ? adapters.baileys : adapters.meta;
    outcome = await adapter(db, profile, digits, frozenReq, attempt.id, key);
  } catch (_) {
    outcome = stop("provider_outcome_unknown", "The provider outcome could not be confirmed.", "unknown");
  }
  const { data: finished, error: finishError } = await db.rpc("finish_whatsapp_message_attempt", {
    p_id: attempt.id, p_claim_token: claim.claim_token, p_state: outcome.state,
    p_retryable: outcome.retryable === true, p_error_category: outcome.errorCategory || null,
    p_detail: outcome.detail, p_provider_message_id: outcome.providerMessageId || null,
  });
  if (finishError || finished !== true) {
    return { ...stop("attempt_persistence_unknown", "Send attempted; its final state requires reconciliation.", "unknown"),
      attemptId: attempt.id, provider: attempt.route_mode, countryId };
  }
  return { ...outcome, attemptId: attempt.id, provider: attempt.route_mode, countryId };
}
