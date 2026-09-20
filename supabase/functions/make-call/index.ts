import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { CallMedia } from "./call-media.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const jsonResponse = (body: Record<string, unknown>, status: number) =>
  new Response(JSON.stringify(body), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status,
  });

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const serviceHeaders = {
  "apikey": SERVICE_ROLE_KEY,
  "Authorization": `Bearer ${SERVICE_ROLE_KEY}`,
  "Content-Type": "application/json",
};

async function resolveUserId(req: Request): Promise<string | null> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return null;
  const res = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { "apikey": SERVICE_ROLE_KEY, "Authorization": authHeader },
  });
  if (!res.ok) return null;
  const user = await res.json();
  return user?.id ?? null;
}

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

async function fetchUserWallet(userId: string): Promise<any | null> {
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/wallets?user_id=eq.${userId}&select=*`,
    { headers: serviceHeaders },
  );
  if (!res.ok) return null;
  const rows = await res.json();
  return rows[0] ?? null;
}

function normalizeE164(phone: string): string | null {
  if (!phone || typeof phone !== "string") return null;
  let clean = phone.trim().replace(/[^0-9+]/g, "");
  if (!clean.startsWith("+")) {
    clean = "+" + clean;
  }
  const digitsOnly = clean.substring(1);
  if (digitsOnly.length < 7 || digitsOnly.length > 15) return null;
  return clean;
}

async function fetchUserCallerIdPreference(userId: string): Promise<{ mode: string; callerIdId: string | null; phoneNumber: string | null } | null> {
  // 1. Check user_caller_id_preferences
  const prefRes = await fetch(
    `${SUPABASE_URL}/rest/v1/user_caller_id_preferences?user_id=eq.${userId}&select=*`,
    { headers: serviceHeaders },
  );
  if (prefRes.ok) {
    const prefs = await prefRes.json();
    if (prefs.length > 0) {
      const p = prefs[0];
      if (p.selected_mode === "gateway") {
        return { mode: "gateway", callerIdId: null, phoneNumber: null };
      }
      if (p.selected_caller_id_id) {
        const idRes = await fetch(
          `${SUPABASE_URL}/rest/v1/user_caller_ids?id=eq.${p.selected_caller_id_id}&user_id=eq.${userId}&is_verified=eq.true&select=id,phone_number`,
          { headers: serviceHeaders },
        );
        if (idRes.ok) {
          const rows = await idRes.json();
          if (rows.length > 0) {
            return { mode: "verified_number", callerIdId: rows[0].id, phoneNumber: rows[0].phone_number };
          }
        }
      }
    }
  }

  // 2. Fallback check user_caller_ids for is_default = true
  const defRes = await fetch(
    `${SUPABASE_URL}/rest/v1/user_caller_ids?user_id=eq.${userId}&is_verified=eq.true&is_default=eq.true&select=id,phone_number`,
    { headers: serviceHeaders },
  );
  if (defRes.ok) {
    const rows = await defRes.json();
    if (rows.length > 0) {
      return { mode: "verified_number", callerIdId: rows[0].id, phoneNumber: rows[0].phone_number };
    }
  }

  return { mode: "gateway", callerIdId: null, phoneNumber: null };
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const userId = await resolveUserId(req);
    if (!userId) {
      return jsonResponse({ success: false, errorMessage: "Unauthorized. Please sign in." }, 401);
    }

    const body = await req.json();
    const {
      action = "dial",
      callId,
      destinationNumber,
      callerIdId,
      explicitGateway = false,
      userCallbackNumber,
      simLineId,
      idempotencyKey,
      mediaSessionId,
    } = body;

    const telnyxApiKey = await fetchSystemConfig("TELNYX_API_KEY");
    if (!telnyxApiKey) {
      return jsonResponse({ success: false, errorMessage: "Telnyx Voice is not configured on this server" }, 500);
    }

    const defaultCallerIdConfig = await fetchSystemConfig("TELNYX_DEFAULT_CALLER_ID", "+17543180369");
    const normalizedGateway = normalizeE164(defaultCallerIdConfig) || "+17543180369";
    const audio = new CallMedia(SUPABASE_URL, serviceHeaders, telnyxApiKey,
      await fetchSystemConfig("TELNYX_CALL_CONTROL_APP_ID"));

    if (action === "prepare_media") {
      const telnyxPublicKey = (await fetchSystemConfig("TELNYX_PUBLIC_KEY")) || Deno.env.get("TELNYX_PUBLIC_KEY");
      if (!telnyxPublicKey) {
        return jsonResponse({ success: false, errorMessage: "In-app calling audio is not configured yet." }, 503);
      }
      const session = await audio.prepare(userId, await fetchSystemConfig("TELNYX_WEBRTC_CONNECTION_ID"));
      return jsonResponse({ success: true, ...session }, 200);
    }

    if (action === "media_ready") {
      if (typeof callId !== "string") return jsonResponse({ success: false, errorMessage: "callId is required" }, 400);
      const record = await audio.record(callId);
      if (!record || record.user_id !== userId || record.call_type !== "app_to_phone_webrtc") {
        return jsonResponse({ success: false, errorMessage: "Call not found" }, 404);
      }
      await audio.ready(callId, "media_ready");
      return jsonResponse({ success: true }, 200);
    }

    // ── ACTION: HANGUP ──
    if (action === "hangup") {
      if (!callId) {
        return jsonResponse({ success: false, errorMessage: "callId is required for hangup" }, 400);
      }

      const recRes = await fetch(
        `${SUPABASE_URL}/rest/v1/call_records?id=eq.${encodeURIComponent(callId)}&user_id=eq.${userId}&select=*`,
        { headers: serviceHeaders },
      );
      const records = recRes.ok ? await recRes.json() : [];
      if (records.length === 0) {
        return jsonResponse({ success: false, errorMessage: "Call record not found or not owned by user" }, 404);
      }

      const record = records[0];
      if (record.call_type === "app_to_phone_webrtc") {
        // Keep finalization with the provider webhook, including the talk duration.
        await audio.patch(record.id, { cancellation_requested_at: new Date().toISOString() });
        await audio.close(record);
        if (!record.telnyx_call_control_id_leg_a) {
          await audio.patch(record.id, { status: "cancelled", ended_at: new Date().toISOString() });
        }
        return jsonResponse({ success: true }, 200);
      }
      const terminalStatuses = ["completed", "declined", "busy", "no_answer", "cancelled", "failed"];
      if (terminalStatuses.includes(record.status)) {
        return jsonResponse({ success: true, message: "Call already terminated", status: record.status }, 200);
      }

      if (record.telnyx_call_control_id_leg_a) {
        try {
          await fetch(`https://api.telnyx.com/v2/calls/${encodeURIComponent(record.telnyx_call_control_id_leg_a)}/actions/hangup`, {
            method: "POST",
            headers: {
              "Authorization": `Bearer ${telnyxApiKey}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({}),
          });
        } catch (e) {
          console.warn("[make-call] Hangup Telnyx call control error:", e);
        }
      }

      const nextStatus = record.status === "in_progress" ? "completed" : "cancelled";
      const nowIso = new Date().toISOString();

      await fetch(`${SUPABASE_URL}/rest/v1/call_records?id=eq.${encodeURIComponent(callId)}&user_id=eq.${userId}`, {
        method: "PATCH",
        headers: serviceHeaders,
        body: JSON.stringify({
          status: nextStatus,
          ended_at: nowIso,
          cancellation_requested_at: nowIso,
        }),
      });

      return jsonResponse({ success: true, message: "Call terminated", status: nextStatus }, 200);
    }

    // ── ACTIONS: PREVIEW & DIAL ──
    if (action !== "preview" && action !== "dial") {
      return jsonResponse({ success: false, errorMessage: `Unknown action '${action}'` }, 400);
    }

    if (action === "dial" && (typeof mediaSessionId !== "string" || !/^[0-9a-f-]{36}$/i.test(mediaSessionId))) {
      return jsonResponse({ success: false, errorMessage: "Please update KeepSIMs to connect call audio before dialing." }, 400);
    }

    if (!destinationNumber || typeof destinationNumber !== "string") {
      return jsonResponse({ success: false, errorMessage: "destinationNumber is required" }, 400);
    }

    const cleanDest = normalizeE164(destinationNumber);
    if (!cleanDest) {
      return jsonResponse({
        success: false,
        errorMessage: "Invalid destination phone number. Please enter in international E.164 format (e.g. +968...)",
      }, 400);
    }

    // Validate SIM line ownership if provided
    if (simLineId) {
      const simRes = await fetch(
        `${SUPABASE_URL}/rest/v1/sim_lines?id=eq.${encodeURIComponent(simLineId)}&user_id=eq.${userId}&select=id`,
        { headers: serviceHeaders },
      );
      const sims = simRes.ok ? await simRes.json() : [];
      if (sims.length === 0) {
        return jsonResponse({ success: false, errorMessage: "Unauthorized SIM line reference" }, 403);
      }
    }

    // 1. Resolve Outbound Caller ID
    let requestedCallerId: string = normalizedGateway;
    let callerIdType: "gateway" | "verified_number" = "gateway";

    if (explicitGateway === true || callerIdId === "gateway") {
      requestedCallerId = normalizedGateway;
      callerIdType = "gateway";
    } else if (callerIdId) {
      const cidRes = await fetch(
        `${SUPABASE_URL}/rest/v1/user_caller_ids?id=eq.${encodeURIComponent(callerIdId)}&user_id=eq.${userId}&select=*`,
        { headers: serviceHeaders },
      );
      const cidRows = cidRes.ok ? await cidRes.json() : [];
      if (cidRows.length === 0) {
        return jsonResponse({ success: false, errorMessage: "Specified Caller ID does not belong to your account" }, 403);
      }
      if (!cidRows[0].is_verified) {
        return jsonResponse({ success: false, errorMessage: "Specified Caller ID is not verified" }, 403);
      }
      requestedCallerId = normalizeE164(cidRows[0].phone_number) || cidRows[0].phone_number;
      callerIdType = "verified_number";
    } else if (userCallbackNumber && typeof userCallbackNumber === "string") {
      // Compatibility path for older clients
      const normalizedCallback = normalizeE164(userCallbackNumber);
      if (normalizedCallback === normalizedGateway) {
        requestedCallerId = normalizedGateway;
        callerIdType = "gateway";
      } else if (normalizedCallback) {
        const checkRes = await fetch(
          `${SUPABASE_URL}/rest/v1/user_caller_ids?user_id=eq.${userId}&phone_number=eq.${encodeURIComponent(normalizedCallback)}&is_verified=eq.true&select=id,phone_number`,
          { headers: serviceHeaders },
        );
        const checkRows = checkRes.ok ? await checkRes.json() : [];
        if (checkRows.length > 0) {
          requestedCallerId = normalizedCallback;
          callerIdType = "verified_number";
        } else {
          return jsonResponse({
            success: false,
            errorMessage: `Phone number ${userCallbackNumber} is not verified for this account. Please select KeepSIMs Gateway or verify the number first.`,
          }, 403);
        }
      }
    } else {
      // Resolve from stored user preference
      const pref = await fetchUserCallerIdPreference(userId);
      if (pref && pref.mode === "verified_number" && pref.phoneNumber) {
        requestedCallerId = normalizeE164(pref.phoneNumber) || pref.phoneNumber;
        callerIdType = "verified_number";
      } else {
        requestedCallerId = normalizedGateway;
        callerIdType = "gateway";
      }
    }

    // 2. Evaluate Route Eligibility Policy
    let eligible = true;
    let policyCode = "approved";
    let policyReason = "Route verified and approved.";
    let suggestedAction: string | null = null;
    const effectiveCallerId = requestedCallerId;

    // Check emergency & short numbers
    const destDigits = cleanDest.replace(/\D/g, "");
    if (["911", "999", "112", "993", "997", "998"].includes(destDigits) || destDigits.length < 7) {
      eligible = false;
      policyCode = "blocked_destination";
      policyReason = "Calls to emergency or special utility services are not supported.";
    }

    // Check self-dialing conflict
    if (callerIdType === "verified_number" && effectiveCallerId === cleanDest) {
      eligible = false;
      policyCode = "self_dial_conflict";
      policyReason = "Calling your own Caller ID number is not supported directly. Please use KeepSIMs Voice Gateway to place this call.";
      suggestedAction = "use_gateway";
    }

    // Check external same-country route restrictions
    // E.g. External Oman number (+968) calling Oman destination (+968)
    if (callerIdType === "verified_number" && effectiveCallerId.startsWith("+968") && cleanDest.startsWith("+968")) {
      eligible = false;
      policyCode = "unsupported_same_country_route";
      policyReason = "External Oman mobile numbers cannot be used as caller ID to call Oman destinations due to local carrier CLI restrictions. Please switch to KeepSIMs Voice Gateway to connect your call.";
      suggestedAction = "use_gateway";
    }

    // 3. Lookup call rate for destination (Fail-Closed: no unquoted fallback)
    const rateRes = await rpc("get_call_rate_for_number", { p_phone_number: cleanDest });
    if (!rateRes.ok || !Array.isArray(rateRes.body) || rateRes.body.length === 0) {
      return jsonResponse({
        success: false,
        code: "destination_not_routable",
        errorMessage: `Destination ${cleanDest} is not currently routable or supported for outbound calls.`,
      }, 422);
    }
    const rateData = rateRes.body[0];
    if (!rateData || typeof rateData.rate_per_minute_usd !== "number" || rateData.rate_per_minute_usd <= 0) {
      return jsonResponse({
        success: false,
        code: "destination_not_routable",
        errorMessage: `Unable to obtain a valid tariff for destination ${cleanDest}.`,
      }, 422);
    }

    // 4. Fetch User Wallet Available Balance
    const summaryRes = await rpc("get_wallet_summary", { p_user_id: userId });
    let availableBalance = 0;
    let postedBalance = 0;
    if (summaryRes.ok && summaryRes.body) {
      availableBalance = Number(summaryRes.body.available_balance ?? 0);
      postedBalance = Number(summaryRes.body.posted_balance ?? 0);
    } else {
      const wallet = await fetchUserWallet(userId);
      postedBalance = Number(wallet?.balance ?? 0);
      availableBalance = postedBalance;
    }

    // ── PREVIEW RESPONSE ──
    if (action === "preview") {
      return jsonResponse({
        success: true,
        eligible,
        policyCode,
        policyReason,
        suggestedAction,
        requestedCallerId,
        effectiveCallerId,
        callerIdType,
        destination: {
          number: cleanDest,
          countryName: rateData.country_name,
          countryCode: rateData.country_code,
          ratePerMinute: rateData.rate_per_minute_usd,
          ratePerSecond: (rateData.rate_per_minute_usd / 60).toFixed(5),
        },
        walletBalance: postedBalance,
        availableBalance,
        gatewayNumber: normalizedGateway,
      }, 200);
    }

    // ── DIAL ACTION ENFORCEMENT ──
    if (!eligible) {
      return jsonResponse({
        success: false,
        code: policyCode,
        errorMessage: policyReason,
        suggestedAction,
        requestedCallerId,
        effectiveCallerId,
        callerIdType,
      }, 422);
    }

    const minRequired = Number(rateData.rate_per_minute_usd);
    if (availableBalance < minRequired) {
      return jsonResponse({
        success: false,
        code: "insufficient_funds",
        errorMessage: `Insufficient available balance ($${availableBalance.toFixed(2)}). At least $${minRequired.toFixed(2)} is required to call this destination.`,
        availableBalance,
        requiredAmount: minRequired,
      }, 402);
    }

    // 5. Check Idempotency Key (prevent double creation from repeated taps)
    if (idempotencyKey) {
      const existingCallRes = await fetch(
        `${SUPABASE_URL}/rest/v1/call_records?user_id=eq.${userId}&idempotency_key=eq.${encodeURIComponent(idempotencyKey)}&select=*`,
        { headers: serviceHeaders },
      );
      if (existingCallRes.ok) {
        const existingRows = await existingCallRes.json();
        if (existingRows.length > 0) {
          const callRecord = existingRows[0];
          return jsonResponse({
            success: true,
            callId: callRecord.id,
            status: callRecord.status,
            destination: {
              number: cleanDest,
              countryName: rateData.country_name,
              countryCode: rateData.country_code,
              ratePerMinute: rateData.rate_per_minute_usd,
              ratePerSecond: (rateData.rate_per_minute_usd / 60).toFixed(5),
            },
            callerId: callRecord.effective_caller_id || callRecord.caller_number,
            callerIdType: callRecord.caller_id_type || callerIdType,
            walletBalance: balance,
          }, 200);
        }
      }
    }

    // 6. Fetch Telnyx Configuration
    if (!await fetchSystemConfig("TELNYX_CALL_CONTROL_APP_ID")) {
      return jsonResponse({ success: false, errorMessage: "In-app calling audio is not configured yet." }, 503);
    }

    // 7. Insert Initial Pending Call Record
    const insertCallRes = await fetch(`${SUPABASE_URL}/rest/v1/call_records`, {
      method: "POST",
      headers: { ...serviceHeaders, "Prefer": "return=representation" },
      body: JSON.stringify({
        user_id: userId,
        sim_line_id: simLineId || null,
        call_type: "app_to_phone_webrtc",
        caller_number: effectiveCallerId,
        requested_caller_id: requestedCallerId,
        effective_caller_id: effectiveCallerId,
        caller_id_type: callerIdType,
        policy_reason: policyReason,
        policy_version: "2026-09-17",
        destination_number: cleanDest,
        destination_country_code: rateData.country_code,
        destination_country_name: rateData.country_name,
        rate_per_minute_usd: rateData.rate_per_minute_usd,
        billing_increment_seconds: rateData.billing_increment_seconds || 60,
        status: "initiated",
        idempotency_key: idempotencyKey || null,
      }),
    });

    if (!insertCallRes.ok) {
      const errText = await insertCallRes.text();
      return jsonResponse({ success: false, errorMessage: `Failed to create call record: ${errText}` }, 500);
    }

    const callRecord = (await insertCallRes.json())[0];

    // 8. Atomically Reserve Call Budget Hold
    const holdAmount = Math.min(
      availableBalance,
      Math.max(minRequired, Number((rateData.rate_per_minute_usd * 5).toFixed(4)))
    );

    const holdRes = await rpc("reserve_wallet_funds", {
      p_user_id: userId,
      p_amount: holdAmount,
      p_order_type: "call_budget",
      p_order_reference_id: callRecord.id,
      p_reason: `Call budget reservation to ${cleanDest}`,
      p_ttl_minutes: 60,
    });

    if (!holdRes.ok) {
      await audio.patch(callRecord.id, {
        status: "failed",
        error_message: "Failed to reserve call funds: " + JSON.stringify(holdRes.body),
        ended_at: new Date().toISOString(),
      });
      return jsonResponse({
        success: false,
        code: "insufficient_funds",
        errorMessage: "Could not reserve funds for this call.",
      }, 402);
    }

    const holdId = typeof holdRes.body === "string" ? holdRes.body : holdRes.body?.id;

    try {
      const session = await audio.claim(mediaSessionId, userId, callRecord.id);
      await audio.dialApp(callRecord, session, normalizedGateway);
    } catch (error: any) {
      if (holdId) {
        await rpc("release_wallet_hold", {
          p_hold_id: holdId,
          p_reason: "Dial setup failed: " + error.message,
        });
      }
      await audio.patch(callRecord.id, { status: "failed", error_message: error.message, ended_at: new Date().toISOString() });
      return jsonResponse({ success: false, errorMessage: error.message }, 502);
    }

    return jsonResponse({
      success: true,
      callId: callRecord.id,
      status: "initiated",
      destination: {
        number: cleanDest,
        countryName: rateData.country_name,
        countryCode: rateData.country_code,
        ratePerMinute: rateData.rate_per_minute_usd,
        ratePerSecond: (rateData.rate_per_minute_usd / 60).toFixed(5),
      },
      callerId: effectiveCallerId,
      callerIdType: callerIdType,
      walletBalance: postedBalance,
      availableBalance: Number((availableBalance - holdAmount).toFixed(4)),
    }, 200);

  } catch (err: any) {
    console.error("[make-call] error:", err);
    return jsonResponse({ success: false, errorMessage: err.message }, 500);
  }
});
