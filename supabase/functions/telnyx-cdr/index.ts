import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import naclModule from "https://esm.sh/tweetnacl@1.0.3";
const nacl: any = (naclModule as any)?.sign ? naclModule : (naclModule as any)?.default ?? naclModule;
import { CallMedia } from "./call-media.ts";
import { handleMediaEvent } from "./media-events.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, telnyx-signature-ed25519, telnyx-timestamp",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const TELNYX_PUBLIC_KEY = Deno.env.get("TELNYX_PUBLIC_KEY") || "";

const serviceHeaders = {
  "apikey": SERVICE_ROLE_KEY,
  "Authorization": `Bearer ${SERVICE_ROLE_KEY}`,
  "Content-Type": "application/json",
};

async function rpc(name: string, args: Record<string, unknown>): Promise<{ ok: boolean; body: any }> {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: serviceHeaders,
    body: JSON.stringify(args),
  });
  const text = await res.text();
  let body: any = text;
  try { body = JSON.parse(text); } catch (_) { /* raw text */ }
  return { ok: res.ok, body };
}

async function fetchSystemConfig(key: string, defaultVal: string = ""): Promise<string> {
  const envVal = Deno.env.get(key);
  if (envVal) return envVal;
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/system_configs?config_key=eq.${encodeURIComponent(key)}&select=config_value`,
    { headers: serviceHeaders },
  );
  if (!res.ok) return defaultVal;
  const rows = await res.json();
  return rows[0]?.config_value ?? defaultVal;
}

function decodeClientState(clientStateStr?: string): any | null {
  if (!clientStateStr) return null;
  try {
    const jsonStr = atob(clientStateStr);
    return JSON.parse(jsonStr);
  } catch (_) {
    try {
      return JSON.parse(clientStateStr);
    } catch (_) {
      return null;
    }
  }
}

function decodeBase64OrHex(str: string): Uint8Array {
  const clean = str.trim();
  try {
    const bin = atob(clean);
    const bytes = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    // If SPKI format (44 bytes), extract the last 32 bytes of raw public key
    if (bytes.length === 44 && bytes[0] === 0x30) {
      return bytes.slice(12);
    }
    return bytes;
  } catch (_) {}

  if (/^[0-9a-fA-F]+$/.test(clean) && clean.length % 2 === 0) {
    const bytes = new Uint8Array(clean.length / 2);
    for (let i = 0; i < clean.length; i += 2) {
      bytes[i / 2] = parseInt(clean.substring(i, i + 2), 16);
    }
    return bytes;
  }
  throw new Error("Unable to decode key or signature");
}

async function verifyTelnyxSignature(
  rawBody: string,
  signatureHeader: string | null,
  timestampHeader: string | null,
  publicKeyStr: string,
): Promise<{ valid: boolean; reason?: string }> {
  if (!signatureHeader || !timestampHeader) {
    return { valid: false, reason: "Missing telnyx-signature-ed25519 or telnyx-timestamp header" };
  }

  // 1. Check timestamp freshness to prevent replay attacks (tolerance: 300 seconds = 5 minutes)
  const currentTimestamp = Math.floor(Date.now() / 1000);
  const eventTimestamp = parseInt(timestampHeader, 10);
  if (isNaN(eventTimestamp) || Math.abs(currentTimestamp - eventTimestamp) > 300) {
    return { valid: false, reason: `Timestamp out of acceptable 300s window (delta: ${Math.abs(currentTimestamp - eventTimestamp)}s)` };
  }

  // 2. Perform Ed25519 signature check
  try {
    const publicKeyBytes = decodeBase64OrHex(publicKeyStr);
    const signatureBytes = decodeBase64OrHex(signatureHeader);
    const payloadToVerify = new TextEncoder().encode(`${timestampHeader}|${rawBody}`);

    // Primary: WebCrypto Ed25519 (standard in Deno runtime)
    try {
      const key = await crypto.subtle.importKey(
        "raw",
        publicKeyBytes,
        { name: "Ed25519" },
        false,
        ["verify"],
      );
      const valid = await crypto.subtle.verify(
        { name: "Ed25519" },
        key,
        signatureBytes,
        payloadToVerify,
      );
      if (valid) return { valid: true };
    } catch (_) {
      // Fall through to tweetnacl fallback
    }

    // Secondary: tweetnacl fallback
    const naclLib: any = (nacl as any)?.sign ? nacl : (nacl as any)?.default;
    if (naclLib?.sign?.detached?.verify) {
      const isValid = naclLib.sign.detached.verify(payloadToVerify, signatureBytes, publicKeyBytes);
      return { valid: isValid, reason: isValid ? undefined : "Ed25519 signature verification failed" };
    }

    return { valid: false, reason: "Ed25519 verification algorithm unavailable" };
  } catch (err: any) {
    return { valid: false, reason: `Signature verification error: ${err.message}` };
  }
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 405,
    });
  }

  try {
    const rawBody = await req.text();
    const signatureHeader = req.headers.get("telnyx-signature-ed25519");
    const timestampHeader = req.headers.get("telnyx-timestamp");

    // ── 1. Webhook Authentication & Signature Verification ──
    const effectivePublicKey = TELNYX_PUBLIC_KEY || (await fetchSystemConfig("TELNYX_PUBLIC_KEY"));
    if (effectivePublicKey) {
      const verification = await verifyTelnyxSignature(rawBody, signatureHeader, timestampHeader, effectivePublicKey);
      if (!verification.valid) {
        console.warn(`[telnyx-cdr] Rejected unauthenticated webhook: ${verification.reason}`);
        return new Response(JSON.stringify({ error: "Unauthorized", reason: verification.reason }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 401,
        });
      }
    }

    let parsedBody: any;
    try {
      parsedBody = JSON.parse(rawBody);
    } catch (_) {
      return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      });
    }

    const event = parsedBody?.data;
    if (!event) {
      return new Response(JSON.stringify({ status: "ignored" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      });
    }

    const eventId = event.id;
    const eventType = event.event_type;
    const payload = event.payload;
    const callControlId = payload?.call_control_id || payload?.call_session_id;
    const clientState = decodeClientState(payload?.client_state);

    console.log(`[telnyx-cdr] Event: ${eventType}, id: ${eventId}, call_control_id: ${callControlId}`);

    // Durable Webhook Deduplication:
    if (eventId) {
      try {
        const checkRes = await fetch(
          `${SUPABASE_URL}/rest/v1/processed_webhook_events?event_id=eq.${encodeURIComponent(eventId)}&select=event_id`,
          { headers: serviceHeaders },
        );
        if (checkRes.ok) {
          const rows = await checkRes.json();
          if (rows.length > 0) {
            console.log(`[telnyx-cdr] Duplicate webhook event ${eventId} (${eventType}) ignored.`);
            return new Response(JSON.stringify({ received: true, duplicate: true }), {
              headers: { ...corsHeaders, "Content-Type": "application/json" },
              status: 200,
            });
          }
        }
      } catch (_) {}
    }

    const recordProcessedEvent = async (callRecId?: string | null) => {
      if (!eventId) return;
      try {
        await fetch(`${SUPABASE_URL}/rest/v1/processed_webhook_events`, {
          method: "POST",
          headers: serviceHeaders,
          body: JSON.stringify({
            event_id: eventId,
            event_type: eventType,
            call_record_id: callRecId || null,
          }),
        });
      } catch (_) {}
    };

    // Resolve callRecordId from client_state
    const clientCallRecordId = clientState?.callRecordId;

    // ── 1B. Line Verification Attempt (Missed Call) Handling ──
    if (clientState?.attemptId) {
      const attemptId = clientState.attemptId;
      console.log(`[telnyx-cdr] Processing line verification attempt ${attemptId}, event: ${eventType}`);
      const telnyxApiKey = await fetchSystemConfig("TELNYX_API_KEY");

      if (eventType === "call.ringing" || eventType === "call.answered") {
        if (callControlId && telnyxApiKey) {
          try {
            await fetch(`https://api.telnyx.com/v2/calls/${encodeURIComponent(callControlId)}/actions/hangup`, {
              method: "POST",
              headers: { "Authorization": `Bearer ${telnyxApiKey}`, "Content-Type": "application/json" },
              body: JSON.stringify({}),
            });
          } catch (_) {}
        }
        await rpc("settle_line_verification_attempt", {
          p_attempt_id: attemptId,
          p_outcome: "succeeded",
          p_carrier_name: null,
          p_error_message: null,
        });
        await recordProcessedEvent(null);
        return new Response(JSON.stringify({ status: "verification_succeeded" }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        });
      } else if (eventType === "call.hangup") {
        const rawCause = payload?.hangup_cause || "call_ended";
        const hangupCause = rawCause.toLowerCase();

        const checkRes = await fetch(`${SUPABASE_URL}/rest/v1/line_verification_attempts?id=eq.${encodeURIComponent(attemptId)}&select=outcome`, {
          headers: serviceHeaders,
        });
        if (checkRes.ok) {
          const attempts = await checkRes.json();
          if (attempts[0] && attempts[0].outcome !== "succeeded") {
            if (
              hangupCause === "user_busy" ||
              hangupCause === "no_answer" ||
              hangupCause === "timeout" ||
              hangupCause === "normal_clearing"
            ) {
              await rpc("settle_line_verification_attempt", {
                p_attempt_id: attemptId,
                p_outcome: "succeeded",
                p_carrier_name: null,
                p_error_message: null,
              });
            } else {
              await rpc("settle_line_verification_attempt", {
                p_attempt_id: attemptId,
                p_outcome: "failed",
                p_carrier_name: null,
                p_error_message: `Call ended without ringing: ${rawCause}`,
              });
            }
          }
        }
        await recordProcessedEvent(null);
        return new Response(JSON.stringify({ status: "verification_hangup" }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        });
      }
      await recordProcessedEvent(null);
      return new Response(JSON.stringify({ status: "verification_event_acknowledged" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      });
    }

    // ── 2. Look up the verified Call Record from Database (SOURCE OF TRUTH) ──
    let dbRecord: any = null;
    if (clientCallRecordId) {
      const recRes = await fetch(`${SUPABASE_URL}/rest/v1/call_records?id=eq.${encodeURIComponent(clientCallRecordId)}`, {
        headers: serviceHeaders,
      });
      if (recRes.ok) {
        const records = await recRes.json();
        dbRecord = records[0] ?? null;
      }
    }

    if (!dbRecord && callControlId) {
      const recRes = await fetch(
        `${SUPABASE_URL}/rest/v1/call_records?or=(telnyx_call_session_id.eq.${encodeURIComponent(callControlId)},telnyx_call_control_id_leg_a.eq.${encodeURIComponent(callControlId)})`,
        { headers: serviceHeaders },
      );
      if (recRes.ok) {
        const records = await recRes.json();
        dbRecord = records[0] ?? null;
      }
    }

    const callRecordId = dbRecord?.id || clientCallRecordId;
    if (!callRecordId) {
      console.warn(`[telnyx-cdr] No call record matched for callControlId ${callControlId}`);
      return new Response(JSON.stringify({ received: true, matched: false }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      });
    }

    if (dbRecord?.call_type === "app_to_phone_webrtc") {
      const appId = await fetchSystemConfig("TELNYX_CALL_CONTROL_APP_ID");
      if (String(payload?.connection_id) !== appId) {
        return new Response(JSON.stringify({ error: "Call application mismatch" }), { status: 403 });
      }
      await handleMediaEvent(new CallMedia(SUPABASE_URL, serviceHeaders,
        await fetchSystemConfig("TELNYX_API_KEY"), appId), dbRecord, event, rpc);
      await recordProcessedEvent(dbRecord.id);
      return new Response(JSON.stringify({ received: true }), { status: 200 });
    }

    const terminalStatuses = ["completed", "declined", "busy", "no_answer", "cancelled", "failed"];
    const isAlreadyTerminal = terminalStatuses.includes(dbRecord?.status);

    // ── 3. Event: Call Initiated (Setup started - NOT ringing) ──
    if (eventType === "call.initiated") {
      if (!isAlreadyTerminal) {
        await fetch(`${SUPABASE_URL}/rest/v1/call_records?id=eq.${encodeURIComponent(callRecordId)}`, {
          method: "PATCH",
          headers: serviceHeaders,
          body: JSON.stringify({
            status: "initiated", // Remain initiated; do NOT mark ringing prematurely
            telnyx_call_control_id_leg_a: payload?.call_control_id || undefined,
            telnyx_call_session_id: payload?.call_session_id || undefined,
          }),
        });
      }
    }

    // ── 4. Event: Destination Alerting (Physical Ringing) ──
    else if (eventType === "call.ringing") {
      if (!isAlreadyTerminal && dbRecord?.status !== "in_progress") {
        await fetch(`${SUPABASE_URL}/rest/v1/call_records?id=eq.${encodeURIComponent(callRecordId)}`, {
          method: "PATCH",
          headers: serviceHeaders,
          body: JSON.stringify({
            status: "ringing",
            telnyx_call_control_id_leg_a: payload?.call_control_id || undefined,
            telnyx_call_session_id: payload?.call_session_id || undefined,
          }),
        });
      }
    }

    // ── 5. Event: Call Answered (Connected) ──
    else if (eventType === "call.answered") {
      console.log(`[telnyx-cdr] Call answered: ${callRecordId}`);
      if (!isAlreadyTerminal) {
        await fetch(`${SUPABASE_URL}/rest/v1/call_records?id=eq.${encodeURIComponent(callRecordId)}`, {
          method: "PATCH",
          headers: serviceHeaders,
          body: JSON.stringify({
            status: "in_progress",
            answered_at: new Date().toISOString(),
          }),
        });
      }
    }

    // ── 6. Event: Call Hangup (Terminal Outcome & Billing) ──
    else if (eventType === "call.hangup") {
      // Re-read latest record state
      const recRes = await fetch(`${SUPABASE_URL}/rest/v1/call_records?id=eq.${encodeURIComponent(callRecordId)}`, {
        headers: serviceHeaders,
      });
      const records = recRes.ok ? await recRes.json() : [];
      dbRecord = records[0] ?? dbRecord;

      const rawCause = String(payload?.hangup_cause || "normal_clearing");
      const rawSipCause = payload?.sip_hangup_cause;
      const rawSource = String(payload?.hangup_source || "callee");
      const durationSecs = Number(payload?.call_duration_secs ?? payload?.duration_secs ?? 0);
      const sipCode = parseInt(String(rawSipCause), 10);

      console.log(`[telnyx-cdr] Call hangup: id=${callRecordId}, sip=${rawSipCause}, cause=${rawCause}, source=${rawSource}, duration=${durationSecs}s`);

      // If call record was already marked terminal (e.g. earlier hangup event or user cancellation),
      // preserve the terminal status and avoid double-charging
      if (terminalStatuses.includes(dbRecord?.status)) {
        console.log(`[telnyx-cdr] Call ${callRecordId} already in terminal status ${dbRecord?.status}. Preserving state.`);
        await fetch(`${SUPABASE_URL}/rest/v1/call_records?id=eq.${encodeURIComponent(callRecordId)}`, {
          method: "PATCH",
          headers: serviceHeaders,
          body: JSON.stringify({
            sip_hangup_cause: isNaN(sipCode) ? null : sipCode,
            telnyx_hangup_cause: rawCause,
            hangup_source: rawSource,
            raw_cdr: payload,
          }),
        });
        return new Response(JSON.stringify({ received: true, event: eventType, alreadyTerminal: true }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        });
      }

      const wasAnswered = dbRecord?.answered_at !== null && dbRecord?.answered_at !== undefined;
      let finalStatus = "completed";
      let errorMsg: string | null = null;
      let totalCost = 0.0000;
      let billedDuration = 0;

      if (wasAnswered) {
        finalStatus = "completed";
        billedDuration = durationSecs > 0 ? durationSecs : 1;

        // Calculate cost based strictly on authoritative database record rate
        const verifiedUserId = dbRecord?.user_id;
        const verifiedRatePerMinute = Number(dbRecord?.rate_per_minute_usd ?? 0.08);

        if (billedDuration > 0 && verifiedUserId && verifiedRatePerMinute > 0) {
          totalCost = Number((billedDuration * (verifiedRatePerMinute / 60.0)).toFixed(4));
          if (totalCost > 0) {
            console.log(`[telnyx-cdr] Debiting wallet for user ${verifiedUserId}: $${totalCost} for ${billedDuration}s answered call`);
            await rpc("debit_wallet_for_call", {
              p_user_id: verifiedUserId,
              p_call_id: callRecordId,
              p_amount: totalCost,
              p_description: `International Call to ${dbRecord?.destination_number ?? "destination"} (${billedDuration}s)`,
            });
          }
        }
      } else {
        // UNANSWERED CALLS: ALWAYS $0.00 COST
        totalCost = 0.0000;
        billedDuration = 0;

        // Classification using both SIP Code and Hangup Cause
        const lowerCause = rawCause.toLowerCase();

        if (sipCode === 603) {
          // SIP 603 Decline / Callee / Carrier rejection
          finalStatus = "declined";
          errorMsg = "Call declined or rejected by the destination network";
        } else if (sipCode === 486 || (lowerCause.includes("user_busy") && sipCode !== 603)) {
          finalStatus = "busy";
          errorMsg = "Destination line is busy";
        } else if (sipCode === 487) {
          if (dbRecord?.cancellation_requested_at || rawSource === "caller") {
            finalStatus = "cancelled";
            errorMsg = "Call cancelled";
          } else {
            finalStatus = "no_answer";
            errorMsg = "No answer from recipient";
          }
        } else if ([408, 480].includes(sipCode) || lowerCause.includes("timeout") || lowerCause.includes("no_answer")) {
          finalStatus = "no_answer";
          errorMsg = "No answer from recipient";
        } else if ([404, 484, 410].includes(sipCode) || lowerCause.includes("unallocated") || lowerCause.includes("invalid")) {
          finalStatus = "failed";
          errorMsg = "Invalid destination phone number";
        } else if ([503, 502, 500].includes(sipCode) || lowerCause.includes("service_unavailable") || lowerCause.includes("congestion")) {
          finalStatus = "failed";
          errorMsg = "Carrier route temporarily unavailable";
        } else if (dbRecord?.cancellation_requested_at) {
          finalStatus = "cancelled";
          errorMsg = "Call cancelled";
        } else {
          finalStatus = "failed";
          errorMsg = "Call could not be completed";
        }
      }

      await fetch(`${SUPABASE_URL}/rest/v1/call_records?id=eq.${encodeURIComponent(callRecordId)}`, {
        method: "PATCH",
        headers: serviceHeaders,
        body: JSON.stringify({
          status: finalStatus,
          ended_at: new Date().toISOString(),
          duration_seconds: wasAnswered ? durationSecs : 0,
          billed_duration_seconds: billedDuration,
          total_cost_usd: totalCost,
          sip_hangup_cause: isNaN(sipCode) ? null : sipCode,
          telnyx_hangup_cause: rawCause,
          hangup_source: rawSource,
          error_message: errorMsg,
          raw_cdr: payload,
        }),
      });
    }

    await recordProcessedEvent(callRecordId);

    return new Response(JSON.stringify({ received: true, event: eventType }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (err: any) {
    console.error("[telnyx-cdr] error:", err);
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500,
    });
  }
});
