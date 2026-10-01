// KeepSIMs Centralized WhatsApp Send & Routing Service
// Implements authoritative country routing, provider profile selection,
// entitlement gating, durable outbox attempts, and Baileys / Meta Cloud adapters.

import { durableWhatsAppRoute } from "./whatsapp_route.ts";
import { profileSecret } from "./whatsapp_profile.ts";
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
  replyProfileId?: string;
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
  retryable?: boolean;
  providerMessageId?: string;
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
export async function routeAndSendWhatsApp(supabase: SupabaseClient, req: OutboundWhatsAppRequest): Promise<WhatsAppRouteResult> {
  return durableWhatsAppRoute(supabase, req, { baileys: sendViaBaileys, meta: sendViaMeta });
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
  let endpointUrl = metadata.endpoint_url || "";

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
  let apiKey: string | null;
  try { apiKey = await profileSecret(supabase, profile, "key"); }
  catch (_) { return { success: false, state: "failed", retryable: true,
    detail: "Selected profile credential lookup failed; no send attempted.", errorCategory: "credential_unavailable" }; }

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
      signal: AbortSignal.timeout(10000),
    });

    const json = await res.json().catch(() => ({}));

    if (res.ok && json.success) {
      const jobId = json.job_id || null;
      if (json.duplicate && json.state === "canceled_before_send") return {
        success: false, state: "skipped", retryable: false, errorCategory: "worker_canceled",
        detail: "Baileys withheld this queued message after an owner route or consent change.",
      };
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
      return {
        success: true,
        state: "accepted",
        providerMessageId: jobId,
        detail: `Queued on Baileys VPS worker (job ${jobId || "local"}). Actual delivery verified by worker.`,
      };
    } else {
      const errTxt = json.error || `HTTP ${res.status}`;
      return {
        success: false,
        state: res.status >= 500 && json.safe_to_retry !== true ? "unknown" : "failed",
        detail: `Baileys worker returned error: ${errTxt}`,
        errorCategory: "worker_rejected",
        retryable: res.status === 429 || json.safe_to_retry === true,
      };
    }
  } catch (err: any) {
    const isTimeout = err.name === "AbortError";
    return {
      success: false,
      state: "unknown",
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
  const phoneNumberId = req.replyPhoneNumberId || metadata.phone_number_id;
  const apiVersion = metadata.api_version || "v26.0";

  if (!phoneNumberId) {
    return {
      success: false,
      state: "failed",
      detail: "Meta profile has no phone_number_id configured.",
      errorCategory: "meta_unconfigured",
    };
  }

  // Resolve Meta Access Token from Vault
  let accessToken: string | null;
  try { accessToken = await profileSecret(supabase, profile, "token"); }
  catch (_) { return { success: false, state: "failed", retryable: true,
    detail: "Selected profile credential lookup failed; no send attempted.", errorCategory: "credential_unavailable" }; }

  if (!accessToken) {
    return {
      success: false,
      state: "failed",
      detail: "Meta access token is not configured.",
      errorCategory: "meta_auth_missing",
    };
  }
  // Do not accept new sends without a way to authenticate delivery receipts.
  let appSecret: string | null;
  try { appSecret = await profileSecret(supabase, profile, "app_secret"); }
  catch (_) { return { success: false, state: "failed", retryable: true,
    detail: "Meta webhook credential lookup failed; no send attempted.", errorCategory: "credential_unavailable" }; }
  if (!appSecret) return { success: false, state: "failed", retryable: false,
    detail: "Configure this Meta profile's App Secret in Admin before sending alerts.", errorCategory: "meta_webhook_secret_missing" };

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
    const mapping = templateMappings[req.eventType || ""] || templateMappings[req.purpose] || templateMappings["default"];

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
    } else if (req.bodyText && mapping?.body_parameter_count !== 0) {
      components.push({
        type: "body",
        parameters: [{ type: "text", text: req.bodyText.slice(0, 1024) }],
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

  if (attemptId) requestPayload.biz_opaque_callback_data = attemptId;
  try {
    const res = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(requestPayload),
      signal: AbortSignal.timeout(12000),
    });

    const json = await res.json().catch(() => ({}));

    if (res.ok && json.messages && json.messages.length > 0) {
      const metaMsgId = json.messages[0].id;
      return {
        success: true,
        state: "accepted",
        providerMessageId: metaMsgId,
        detail: `Accepted by Meta Cloud API (ID: ${metaMsgId}). Awaiting delivery webhook.`,
      };
    } else {
      const errorMsg = json.error?.message || `HTTP ${res.status}`;
      return {
        success: false,
        state: res.status >= 500 && !json.error ? "unknown" : "failed",
        detail: `Meta Cloud API rejected: ${errorMsg}`,
        errorCategory: "meta_api_error",
        retryable: res.status === 429 || (res.status >= 500 && !!json.error),
      };
    }
  } catch (err: any) {
    const isTimeout = err.name === "AbortError";
    return {
      success: false,
      state: "unknown",
      detail: isTimeout
        ? "Meta Cloud API timed out after 12s. State is unknown; duplicate avoided."
        : `Meta Graph API error: ${err.message}`,
      errorCategory: isTimeout ? "timeout" : "network_error",
    };
  }
}
