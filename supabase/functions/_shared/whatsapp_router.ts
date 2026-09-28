// KeepSIMs Centralized WhatsApp Send & Routing Service
// Implements authoritative country routing, provider profile selection,
// entitlement gating, durable outbox attempts, and Baileys / Meta Cloud adapters.

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

export type WhatsAppPurpose = "subscription_alert" | "offline_refill_reply" | "admin_test";

export interface OutboundWhatsAppRequest {
  purpose: WhatsAppPurpose;
  recipientPhone: string;
  bodyText?: string;
  titleText?: string;
  notificationId?: string;
  commandId?: string;
  simLineId?: string;
  userId?: string;
  category?: string;
  eventType?: string;
  templateName?: string;
  templateLanguage?: string;
  templateParams?: string[];
  replyPhoneNumberId?: string; // Preserve inbound Meta sender for replies
  idempotencyKey?: string;
}

export interface WhatsAppRouteResult {
  success: boolean;
  state: "accepted" | "sent" | "delivered" | "failed" | "skipped" | "unknown";
  detail: string;
  attemptId?: string;
  provider?: string;
  countryId?: string | null;
  errorCategory?: string;
}

/**
 * Normalizes phone numbers to standard digit strings.
 */
export function normalizePhone(raw: string): { cleanDigits: string; e164: string } {
  let clean = raw.replace(/\D/g, "");
  if (clean.startsWith("00")) clean = clean.substring(2);
  const e164 = `+${clean}`;
  return { cleanDigits: clean, e164 };
}

/**
 * Central routing and dispatch function for all KeepSIMs outbound WhatsApp messaging.
 */
export async function routeAndSendWhatsApp(
  supabase: SupabaseClient,
  req: OutboundWhatsAppRequest,
): Promise<WhatsAppRouteResult> {
  const { cleanDigits, e164 } = normalizePhone(req.recipientPhone);

  if (!cleanDigits || cleanDigits.length < 7) {
    return {
      success: false,
      state: "skipped",
      detail: "Invalid or too short recipient phone number format.",
      errorCategory: "invalid_phone",
    };
  }

  // 1. Resolve recipient country by phone using longest-prefix match
  const { data: resolvedCountryId } = await supabase.rpc("resolve_country_by_phone", {
    p_phone: e164,
  });

  // 2. Fetch SIM Line & Entitlement Details if simLineId is present
  let simCountryId: string | null = null;
  let lineTier = "basic";
  let isLineExpired = false;

  if (req.simLineId) {
    const { data: line } = await supabase
      .from("sim_lines")
      .select("country_id, protection_tier, plan_type, validity_expires_at")
      .eq("id", req.simLineId)
      .maybeSingle();

    if (line) {
      simCountryId = line.country_id || null;
      lineTier = (line.protection_tier || line.plan_type || "basic").toLowerCase();
      if (line.validity_expires_at) {
        isLineExpired = new Date(line.validity_expires_at).getTime() < Date.now();
      }
    }
  }

  // 3. Gate by Purpose before routing
  if (req.purpose === "subscription_alert") {
    // 3a. Global Channel Killswitch Check
    const { data: catalogRow } = await supabase
      .from("notification_channel_catalog")
      .select("is_globally_enabled, min_tier")
      .eq("channel_key", "whatsapp")
      .maybeSingle();

    if (catalogRow && catalogRow.is_globally_enabled === false) {
      return {
        success: false,
        state: "skipped",
        detail: "WhatsApp alerts are globally disabled across the platform.",
        countryId: resolvedCountryId,
        errorCategory: "global_alert_disabled",
      };
    }

    // 3b. Line-level Entitlement & Expiry Verification
    const requiredTier = catalogRow?.min_tier === "premium" ? "Premium" : "Standard or Premium";
    const isEntitled = (requiredTier === "Premium"
      ? lineTier === "premium"
      : lineTier === "standard" || lineTier === "premium") && !isLineExpired;
    if (!isEntitled) {
      const reason = isLineExpired
        ? "Line validity has expired; WhatsApp alert not permitted."
        : `Line tier is ${lineTier}; WhatsApp alerts require an active ${requiredTier} plan.`;
      return {
        success: false,
        state: "skipped",
        detail: reason,
        countryId: resolvedCountryId,
        errorCategory: isLineExpired ? "line_expired" : "tier_not_entitled",
      };
    }

    // 3c. Top-Up Cycle & Auto-Refill Suppression
    if (req.simLineId) {
      const { data: schedule } = await supabase
        .from("scheduled_topups")
        .select("id, is_active, status, whatsapp_sent_this_cycle, schedule_type")
        .eq("sim_line_id", req.simLineId)
        .maybeSingle();

      const autoRefillActive =
        schedule?.is_active === true && schedule?.status === "active" && schedule?.schedule_type === "refill";

      if (autoRefillActive && req.category !== "top_up_failed") {
        return {
          success: false,
          state: "skipped",
          detail: "Auto-refill is active and healthy. WhatsApp reminder unnecessary.",
          countryId: resolvedCountryId,
          errorCategory: "auto_refill_suppressed",
        };
      }

      if (schedule?.whatsapp_sent_this_cycle === true) {
        return {
          success: false,
          state: "skipped",
          detail: "A WhatsApp alert was already accepted for this schedule cycle; delivery may still be pending.",
          countryId: resolvedCountryId,
          errorCategory: "cycle_quota_consumed",
        };
      }
    }
  }

  // 4. Resolve Route for Recipient Country (FAIL CLOSED: NO silent global fallback)
  if (!resolvedCountryId) {
    return {
      success: false,
      state: "skipped",
      detail: `No registered country matches recipient dialing prefix for ${e164}. Routing fails closed.`,
      errorCategory: "country_unresolved",
    };
  }

  const { data: route } = await supabase
    .from("whatsapp_country_routes")
    .select("route_mode, profile_id, health_status, health_reason, version")
    .eq("country_id", resolvedCountryId)
    .maybeSingle();

  if (!route || route.route_mode === "disabled" || !route.profile_id) {
    return {
      success: false,
      state: "skipped",
      detail: `WhatsApp route for recipient country is explicitly disabled or unconfigured. Reason: ${route?.health_reason || "Route disabled"}.`,
      countryId: resolvedCountryId,
      errorCategory: "route_disabled",
    };
  }

  // 5. Load Assigned Provider Profile
  const { data: profile } = await supabase
    .from("whatsapp_provider_profiles")
    .select("id, provider_kind, label, expected_sender_number, observed_sender_number, is_enabled, ready_state, version, connection_metadata")
    .eq("id", route.profile_id)
    .maybeSingle();

  if (!profile || profile.is_enabled === false) {
    return {
      success: false,
      state: "failed",
      detail: `Assigned WhatsApp provider profile "${profile?.label || route.profile_id}" is disabled or missing.`,
      countryId: resolvedCountryId,
      provider: route.route_mode,
      errorCategory: "profile_disabled",
    };
  }

  // 6. Generate Idempotency Key & Register Outbox Attempt
  const idempotencyKey =
    req.idempotencyKey ||
    `${req.purpose}_${req.notificationId || req.commandId || Date.now()}_${cleanDigits}`;

  // Check existing attempt with same idempotency key
  const { data: existingAttempt } = await supabase
    .from("whatsapp_message_attempts")
    .select("id, state, provider_message_id, created_at")
    .eq("idempotency_key", idempotencyKey)
    .maybeSingle();

  if (existingAttempt) {
    if (existingAttempt.state === "delivered" || existingAttempt.state === "sent" || existingAttempt.state === "accepted") {
      return {
        success: true,
        state: existingAttempt.state,
        detail: `Message previously accepted/sent with provider ID ${existingAttempt.provider_message_id}.`,
        attemptId: existingAttempt.id,
        provider: route.route_mode,
        countryId: resolvedCountryId,
      };
    }
    if (existingAttempt.state === "pending" || existingAttempt.state === "unknown") {
      return {
        success: false,
        state: "unknown",
        detail: `Message attempt ${existingAttempt.id} is already in-flight or in unknown state. Duplicate send withheld.`,
        attemptId: existingAttempt.id,
        provider: route.route_mode,
        countryId: resolvedCountryId,
        errorCategory: "in_flight_duplicate",
      };
    }
  }

  let attemptId = existingAttempt?.id;
  if (!existingAttempt) {
    const { data: attemptRow, error: attemptErr } = await supabase
      .from("whatsapp_message_attempts")
      .insert({
        purpose: req.purpose,
        notification_id: req.notificationId || null,
        command_id: req.commandId || null,
        recipient_phone: e164,
        recipient_country_id: resolvedCountryId,
        sim_line_id: req.simLineId || null,
        sim_country_id: simCountryId,
        route_mode: route.route_mode,
        profile_id: profile.id,
        profile_version: profile.version,
        sender_number: profile.expected_sender_number,
        idempotency_key: idempotencyKey,
        template_name: req.templateName || null,
        template_language: req.templateLanguage || null,
        state: "pending",
      })
      .select("id")
      .single();

    if (attemptErr) {
      // Handle potential race condition on unique idempotency_key
      const { data: racedAttempt } = await supabase
        .from("whatsapp_message_attempts")
        .select("id, state, provider_message_id")
        .eq("idempotency_key", idempotencyKey)
        .maybeSingle();
      if (racedAttempt) {
        return {
          success: racedAttempt.state === "delivered" || racedAttempt.state === "sent" || racedAttempt.state === "accepted",
          state: racedAttempt.state,
          detail: `Concurrent attempt detected (id ${racedAttempt.id}). Duplicate send withheld.`,
          attemptId: racedAttempt.id,
          provider: route.route_mode,
          countryId: resolvedCountryId,
        };
      }
      return {
        success: false,
        state: "failed",
        detail: `Could not persist WhatsApp attempt: ${attemptErr.message}`,
        provider: route.route_mode,
        countryId: resolvedCountryId,
        errorCategory: "outbox_write_failed",
      };
    }
    attemptId = attemptRow?.id;
  } else {
    // Retry of previously failed attempt: update state back to pending
    const { error: retryErr } = await supabase
      .from("whatsapp_message_attempts")
      .update({
        state: "pending",
        route_mode: route.route_mode,
        profile_id: profile.id,
        profile_version: profile.version,
        updated_at: new Date().toISOString(),
      })
      .eq("id", attemptId);
    if (retryErr) {
      return {
        success: false,
        state: "failed",
        detail: `Could not claim WhatsApp retry: ${retryErr.message}`,
        provider: route.route_mode,
        countryId: resolvedCountryId,
        errorCategory: "outbox_write_failed",
      };
    }
  }

  // 7. Dispatch to Selected Provider Adapter
  let dispatchOutcome: WhatsAppRouteResult;

  if (route.route_mode === "baileys") {
    dispatchOutcome = await sendViaBaileys(supabase, profile, cleanDigits, req, attemptId, idempotencyKey);
  } else if (route.route_mode === "meta_cloud") {
    dispatchOutcome = await sendViaMeta(supabase, profile, cleanDigits, req, attemptId);
  } else {
    dispatchOutcome = {
      success: false,
      state: "failed",
      detail: `Unsupported route_mode: ${route.route_mode}`,
      errorCategory: "unsupported_provider",
    };
  }

  // 8. Update Outbox Attempt with outcome
  if (attemptId) {
    await supabase
      .from("whatsapp_message_attempts")
      .update({
        state: dispatchOutcome.state,
        error_category: dispatchOutcome.errorCategory || null,
        error_detail: dispatchOutcome.detail.slice(0, 1000),
        updated_at: new Date().toISOString(),
      })
      .eq("id", attemptId)
      .eq("state", "pending");
  }

  // 9. Accepted queue jobs consume this cycle's send quota. This flag is not
  // evidence of recipient delivery; the attempt receipt is tracked separately.
  if (dispatchOutcome.success && req.purpose === "subscription_alert" && req.simLineId) {
    await supabase
      .from("scheduled_topups")
      .update({ whatsapp_sent_this_cycle: true })
      .eq("sim_line_id", req.simLineId);
  }

  return {
    ...dispatchOutcome,
    attemptId,
    provider: route.route_mode,
    countryId: resolvedCountryId,
  };
}

/**
 * Adapter: Baileys Worker HTTP API
 */
async function sendViaBaileys(
  supabase: SupabaseClient,
  profile: any,
  cleanPhone: string,
  req: OutboundWhatsAppRequest,
  attemptId?: string,
  idempotencyKey?: string,
): Promise<WhatsAppRouteResult> {
  const metadata = profile.connection_metadata || {};
  let endpointUrl = metadata.endpoint_url || Deno.env.get("WHATSAPP_NODE_API_URL") || "";

  if (!endpointUrl) {
    return {
      success: false,
      state: "failed",
      detail: "Baileys profile has no endpoint_url configured.",
      errorCategory: "missing_endpoint",
    };
  }

  if (!endpointUrl.endsWith("/send")) {
    endpointUrl = endpointUrl.endsWith("/") ? `${endpointUrl}send` : `${endpointUrl}/send`;
  }

  // Resolve API Key
  let apiKey = Deno.env.get("WHATSAPP_VPS_API_KEY") || "";
  if (metadata.auth_secret_vault_id) {
    const { data: secret } = await supabase.rpc("get_internal_secret", {
      p_name: `wa_baileys_key_${profile.id}`,
    });
    if (secret) apiKey = secret;
  }

  if (!apiKey) {
    return {
      success: false,
      state: "failed",
      detail: "Baileys worker API key is not configured.",
      errorCategory: "missing_api_key",
    };
  }

  const messageText = req.bodyText
    ? (req.titleText ? `*${req.titleText}*\n\n${req.bodyText}` : req.bodyText)
    : "KeepSIMs Alert Notification";

  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 10000);

    const res = await fetch(endpointUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": apiKey,
      },
      body: JSON.stringify({
        phone: cleanPhone,
        message: messageText,
        idempotency_key: idempotencyKey || req.idempotencyKey,
        attempt_id: attemptId,
      }),
      signal: controller.signal,
    });
    clearTimeout(timeout);

    const json = await res.json().catch(() => ({}));

    if (res.ok && json.success) {
      const jobId = json.job_id || null;
      if (json.duplicate && json.state === "unknown") {
        return {
          success: false,
          state: "unknown",
          detail: `Baileys job ${jobId || "unknown"} has an unresolved send outcome; duplicate withheld.`,
          errorCategory: "worker_outcome_unknown",
        };
      }
      if (json.duplicate && (json.state === "sent" || json.state === "delivered")) {
        return {
          success: true,
          state: json.state,
          detail: `Baileys job ${jobId || "unknown"} was already ${json.state}; duplicate withheld.`,
        };
      }
      if (attemptId && jobId) {
        await supabase
          .from("whatsapp_message_attempts")
          .update({ provider_message_id: jobId })
          .eq("id", attemptId);
      }

      return {
        success: true,
        state: "accepted",
        detail: `Queued on Baileys VPS worker (job ${jobId || "local"}). Actual delivery verified by worker.`,
      };
    } else {
      const errTxt = json.error || `HTTP ${res.status}`;
      return {
        success: false,
        state: "failed",
        detail: `Baileys worker returned error: ${errTxt}`,
        errorCategory: "worker_rejected",
      };
    }
  } catch (err: any) {
    const isTimeout = err.name === "AbortError";
    return {
      success: false,
      state: isTimeout ? "unknown" : "failed",
      detail: isTimeout
        ? "Baileys worker timed out after 10s. State is unknown; duplicate avoided."
        : `Baileys connection error: ${err.message}`,
      errorCategory: isTimeout ? "timeout" : "network_error",
    };
  }
}

/**
 * Adapter: Direct Meta WhatsApp Cloud API (Graph API)
 */
async function sendViaMeta(
  supabase: SupabaseClient,
  profile: any,
  cleanPhone: string,
  req: OutboundWhatsAppRequest,
  attemptId?: string,
): Promise<WhatsAppRouteResult> {
  const metadata = profile.connection_metadata || {};
  // If an inbound conversation reply provided the receiving phone_number_id, preserve it!
  const phoneNumberId = req.replyPhoneNumberId || metadata.phone_number_id || Deno.env.get("WABA_PHONE_NUMBER_ID");
  const apiVersion = metadata.api_version || "v20.0";

  if (!phoneNumberId) {
    return {
      success: false,
      state: "failed",
      detail: "Meta profile has no phone_number_id configured.",
      errorCategory: "meta_unconfigured",
    };
  }

  // Resolve Meta Access Token from Vault
  let accessToken = Deno.env.get("WABA_ACCESS_TOKEN") || "";
  if (metadata.access_token_vault_id) {
    const { data: secret } = await supabase.rpc("get_internal_secret", {
      p_name: `wa_meta_token_${profile.id}`,
    });
    if (secret) accessToken = secret;
  }

  if (!accessToken) {
    return {
      success: false,
      state: "failed",
      detail: "Meta access token is not configured.",
      errorCategory: "meta_auth_missing",
    };
  }

  const url = `https://graph.facebook.com/${apiVersion}/${phoneNumberId}/messages`;
  let requestPayload: any;

  // Operational replies (e.g. offline refill reply within customer window) can send free-form text
  if (req.purpose === "offline_refill_reply") {
    requestPayload = {
      messaging_product: "whatsapp",
      recipient_type: "individual",
      to: cleanPhone,
      type: "text",
      text: { body: req.bodyText || "" },
    };
  } else {
    // Business-initiated subscription alerts REQUIRE approved Meta template!
    const templateMappings = metadata.template_mappings || {};
    const mapping = templateMappings[req.purpose] || templateMappings["default"];

    const templateName = req.templateName || mapping?.name;
    const templateLang = req.templateLanguage || mapping?.language || "en_US";

    if (!templateName) {
      return {
        success: false,
        state: "failed",
        detail: `No approved Meta template mapped for purpose "${req.purpose}". Meta policy requires approved templates for outbound notifications.`,
        errorCategory: "meta_template_missing",
      };
    }

    const components: any[] = [];
    if (req.templateParams && req.templateParams.length > 0) {
      components.push({
        type: "body",
        parameters: req.templateParams.map((p) => ({ type: "text", text: p })),
      });
    } else if (req.bodyText) {
      components.push({
        type: "body",
        parameters: [{ type: "text", text: req.bodyText.slice(0, 100) }],
      });
    }

    requestPayload = {
      messaging_product: "whatsapp",
      recipient_type: "individual",
      to: cleanPhone,
      type: "template",
      template: {
        name: templateName,
        language: { code: templateLang },
        components: components.length > 0 ? components : undefined,
      },
    };
  }

  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 12000);

    const res = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(requestPayload),
      signal: controller.signal,
    });
    clearTimeout(timeout);

    const json = await res.json().catch(() => ({}));

    if (res.ok && json.messages && json.messages.length > 0) {
      const metaMsgId = json.messages[0].id;
      if (attemptId && metaMsgId) {
        await supabase
          .from("whatsapp_message_attempts")
          .update({ provider_message_id: metaMsgId, state: "accepted" })
          .eq("id", attemptId);
      }

      return {
        success: true,
        state: "accepted",
        detail: `Accepted by Meta Cloud API (ID: ${metaMsgId}). Awaiting delivery webhook.`,
      };
    } else {
      const errorMsg = json.error?.message || `HTTP ${res.status}`;
      return {
        success: false,
        state: "failed",
        detail: `Meta Cloud API rejected: ${errorMsg}`,
        errorCategory: "meta_api_error",
      };
    }
  } catch (err: any) {
    const isTimeout = err.name === "AbortError";
    return {
      success: false,
      state: isTimeout ? "unknown" : "failed",
      detail: isTimeout
        ? "Meta Cloud API timed out after 12s. State is unknown; duplicate avoided."
        : `Meta Graph API error: ${err.message}`,
      errorCategory: isTimeout ? "timeout" : "network_error",
    };
  }
}
