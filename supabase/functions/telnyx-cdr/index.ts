import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import * as nacl from "https://esm.sh/tweetnacl@1.0.3";

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

function verifyTelnyxSignature(
  rawBody: string,
  signatureHeader: string | null,
  timestampHeader: string | null,
  publicKeyStr: string,
): { valid: boolean; reason?: string } {
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

    const isValid = nacl.sign.detached.verify(payloadToVerify, signatureBytes, publicKeyBytes);
    return { valid: isValid, reason: isValid ? undefined : "Ed25519 signature verification failed" };
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
    if (TELNYX_PUBLIC_KEY) {
      const verification = verifyTelnyxSignature(rawBody, signatureHeader, timestampHeader, TELNYX_PUBLIC_KEY);
      if (!verification.valid) {
        console.warn(`[telnyx-cdr] Rejected unauthenticated webhook: ${verification.reason}`);
        return new Response(JSON.stringify({ error: "Unauthorized", reason: verification.reason }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 401,
        });
      }
    } else {
      console.warn("[telnyx-cdr] WARNING: TELNYX_PUBLIC_KEY is not configured in Supabase Secrets. Webhook signature check bypassed.");
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

    const eventType = event.event_type;
    const payload = event.payload;
    const callControlId = payload?.call_control_id || payload?.call_session_id;
    const clientState = decodeClientState(payload?.client_state);

    console.log(`Telnyx Voice Webhook: ${eventType}, call_control_id: ${callControlId}`);

    // Resolve callRecordId from client_state or payload
    const clientCallRecordId = clientState?.callRecordId;

    // ── 1B. Real Live Verification Handler (Missed Call) Fallback ──
    if (clientState?.attemptId) {
      const attemptId = clientState.attemptId;
      console.log(`[telnyx-cdr] Processing line verification attempt ${attemptId}, event: ${eventType}`);
      const telnyxApiKey = Deno.env.get("TELNYX_API_KEY") || "KEY01A049E00656B79B4314CFFBC7969C10_k9JM7HV9u4sB2MadneUT1M";

      if (eventType === "call.ringing" || eventType === "call.answered") {
        if (callControlId) {
          try {
            await fetch(`https://api.telnyx.com/v2/calls/${callControlId}/actions/hangup`, {
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
        return new Response(JSON.stringify({ status: "verification_succeeded" }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        });
      } else if (eventType === "call.hangup") {
        const hangupCause = payload?.hangup_cause || "call_ended";
        // Check if already succeeded
        const checkRes = await fetch(`${SUPABASE_URL}/rest/v1/line_verification_attempts?id=eq.${encodeURIComponent(attemptId)}&select=outcome`, {
          headers: serviceHeaders,
        });
        if (checkRes.ok) {
          const attempts = await checkRes.json();
          if (attempts[0] && attempts[0].outcome !== "succeeded") {
            await rpc("settle_line_verification_attempt", {
              p_attempt_id: attemptId,
              p_outcome: "failed",
              p_carrier_name: null,
              p_error_message: `Call ended without ringing: ${hangupCause}`,
            });
          }
        }
        return new Response(JSON.stringify({ status: "verification_hangup" }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        });
      }
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
      // Fallback query by call session / control leg
      const recRes = await fetch(
        `${SUPABASE_URL}/rest/v1/call_records?or=(telnyx_call_session_id.eq.${encodeURIComponent(callControlId)},telnyx_call_control_id_leg_a.eq.${encodeURIComponent(callControlId)},telnyx_call_control_id_leg_b.eq.${encodeURIComponent(callControlId)})`,
        { headers: serviceHeaders },
      );
      if (recRes.ok) {
        const records = await recRes.json();
        dbRecord = records[0] ?? null;
      }
    }

    const callRecordId = dbRecord?.id || clientCallRecordId;

    // ── 3. Destination is Ringing ──
    if (eventType === "call.ringing" || eventType === "call.initiated") {
      if (callRecordId) {
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

    // ── 4. Recipient Answered the Phone ──
    else if (eventType === "call.answered") {
      console.log(`Call answered by destination! Updating callRecordId: ${callRecordId}`);
      if (callRecordId) {
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

    // ── 5. Call Hangup / Terminated ──
    else if (eventType === "call.hangup") {
      const hangupCause = payload?.hangup_cause || "normal_clearing";
      const durationSecs = Number(payload?.call_duration_secs ?? payload?.duration_secs ?? 0);

      console.log(`Call ended: record=${callRecordId}, duration=${durationSecs}s, cause=${hangupCause}`);

      if (callRecordId) {
        // Re-read latest record state
        if (!dbRecord) {
          const recRes = await fetch(`${SUPABASE_URL}/rest/v1/call_records?id=eq.${encodeURIComponent(callRecordId)}`, {
            headers: serviceHeaders,
          });
          const records = recRes.ok ? await recRes.json() : [];
          dbRecord = records[0] ?? null;
        }

        const wasAnswered = dbRecord?.answered_at !== null && dbRecord?.answered_at !== undefined;
        let finalStatus = "completed";

        if (!wasAnswered && durationSecs <= 0) {
          const lowerCause = hangupCause.toLowerCase();
          if (lowerCause.includes("busy") || lowerCause.includes("user_busy")) {
            finalStatus = "busy";
          } else if (lowerCause.includes("timeout") || lowerCause.includes("no_answer") || lowerCause.includes("unallocated")) {
            finalStatus = "no_answer";
          } else if (lowerCause.includes("rejected") || lowerCause.includes("declined")) {
            finalStatus = "declined";
          } else {
            finalStatus = "cancelled";
          }
        }

        // CRITICAL SECURITY ENFORCEMENT:
        // Use user_id and rate_per_minute strictly from the database record (NEVER trusting client_state!)
        const verifiedUserId = dbRecord?.user_id;
        const verifiedRatePerMinute = Number(dbRecord?.rate_per_minute_usd ?? 0.08);

        let totalCost = 0.00;
        // ONLY debit wallet if the call was ACTUALLY answered and had positive duration
        if (wasAnswered && durationSecs > 0 && verifiedUserId && verifiedRatePerMinute > 0) {
          totalCost = Number((durationSecs * (verifiedRatePerMinute / 60.0)).toFixed(4));

          if (totalCost > 0) {
            console.log(`Debiting wallet for user ${verifiedUserId}: $${totalCost} for ${durationSecs}s answered call`);
            await rpc("debit_wallet_for_call", {
              p_user_id: verifiedUserId,
              p_call_id: callRecordId,
              p_amount: totalCost,
              p_description: `International Call to ${dbRecord?.destination_number ?? "destination"} (${durationSecs}s)`,
            });
          }
        }

        await fetch(`${SUPABASE_URL}/rest/v1/call_records?id=eq.${encodeURIComponent(callRecordId)}`, {
          method: "PATCH",
          headers: serviceHeaders,
          body: JSON.stringify({
            status: finalStatus,
            ended_at: new Date().toISOString(),
            duration_seconds: wasAnswered ? durationSecs : 0,
            billed_duration_seconds: wasAnswered ? durationSecs : 0,
            total_cost_usd: totalCost,
            raw_cdr: payload,
          }),
        });
      }
    }

    return new Response(JSON.stringify({ received: true, event: eventType }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (err: any) {
    console.error("telnyx-cdr error:", err);
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500,
    });
  }
});
