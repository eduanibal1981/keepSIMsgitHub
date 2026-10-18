import { ProviderConfigurationError, providerSecretClient, requireProviderSecret } from "../_shared/provider-secrets.ts";
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
  if (key === "TELNYX_API_KEY") {
    return await requireProviderSecret(providerSecretClient(SUPABASE_URL, SERVICE_ROLE_KEY), key);
  }
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
      if (record.budget_contract_version !== 1) return jsonResponse({ success: false, errorMessage: "This call requires reconciliation." }, 409);
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
        await audio.rpc("request_media_call_termination", { p_call_id: record.id });
        // Re-read after the serialized cancellation marker. A lost dial response
        // never proves that no provider leg exists.
        await audio.close(await audio.record(record.id));
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

    if (action === "dial" && typeof idempotencyKey === "string" && idempotencyKey.trim()) {
      const existing = await audio.db(`call_records?user_id=eq.${userId}&idempotency_key=eq.${encodeURIComponent(idempotencyKey)}&select=*`);
      if (existing.length) {
        const saved = existing[0];
        if (saved.destination_number !== cleanDest || saved.effective_caller_id !== effectiveCallerId ||
            (saved.sim_line_id ?? null) !== (simLineId || null)) {
          return jsonResponse({ success: false, errorMessage: "Call idempotency terms mismatch" }, 409);
        }
        const summary = await rpc("get_wallet_summary", { p_user_id: userId });
        if (!summary.ok) return jsonResponse({ success: false, errorMessage: "Wallet availability is temporarily unavailable." }, 503);
        return jsonResponse({ success: true, callId: saved.id, status: saved.status,
          billingState: saved.billing_state, maxDurationSeconds: saved.max_duration_seconds,
          reservedBudget: saved.reserved_budget_usd,
          destination: { number: saved.destination_number, countryName: saved.destination_country_name,
            countryCode: saved.destination_country_code, ratePerMinute: saved.rate_per_minute_usd,
            ratePerSecond: (Number(saved.rate_per_minute_usd) / 60).toFixed(5),
            connectionFee: saved.connection_fee_usd, billingIncrementSeconds: saved.billing_increment_seconds },
          callerId: saved.effective_caller_id || saved.caller_number, callerIdType: saved.caller_id_type,
          walletBalance: Number(summary.body.posted_balance), availableBalance: Number(summary.body.available_balance),
        }, 200);
      }
    }

    // 3. Lookup call rate for destination (Fail-Closed: no unquoted fallback)
    const rateRes = await rpc("get_call_rate_for_number", { p_phone_number: cleanDest, p_user_id: userId });
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
      return jsonResponse({ success: false, errorMessage: "Wallet availability is temporarily unavailable." }, 503);
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
          rateId: rateData.id,
          number: cleanDest,
          countryName: rateData.country_name,
          countryCode: rateData.country_code,
          ratePerMinute: rateData.rate_per_minute_usd,
          ratePerSecond: (rateData.rate_per_minute_usd / 60).toFixed(5),
          connectionFee: Number(rateData.connection_fee_usd ?? 0),
          billingIncrementSeconds: Number(rateData.billing_increment_seconds ?? 1),
          accountTier: rateData.account_tier ?? null,
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

    if (typeof idempotencyKey !== "string" || !idempotencyKey.trim() || idempotencyKey.length > 200) {
      return jsonResponse({ success: false, errorMessage: "A call idempotency key is required." }, 400);
    }
    if (!await fetchSystemConfig("TELNYX_CALL_CONTROL_APP_ID")) {
      return jsonResponse({ success: false, errorMessage: "In-app calling audio is not configured yet." }, 503);
    }
    // Tariff, owned media session, available funds, call record, and hold commit
    // together. Retrying adopts the original terms and cannot dial again.
    const prepared = await rpc("prepare_budgeted_media_call", {
      p_user_id: userId, p_media_session_id: mediaSessionId,
      p_request: { sim_line_id: simLineId || null, destination_number: cleanDest,
        requested_caller_id: requestedCallerId, effective_caller_id: effectiveCallerId,
        caller_id_type: callerIdType, policy_reason: policyReason, idempotency_key: idempotencyKey },
    });
    if (!prepared.ok) {
      return jsonResponse({ success: false, errorMessage: "Could not reserve this call. Check your available funds and call audio session." }, 409);
    }
    const { call: callRecord, created, posted_balance: walletBalance, available_balance: remaining } = prepared.body;
    if (created) {
      try {
        await audio.dialApp(callRecord, await audio.session(callRecord.id), normalizedGateway);
      } catch (_) {
        // Submission may already have reached the provider. Keep the hold and
        // expose a recoverable state; never release/re-dial on an HTTP timeout.
        await audio.patch(callRecord.id, { billing_state: "reconciliation_required", reconciliation_reason: "app_submission_unknown" });
        return jsonResponse({ success: false, callId: callRecord.id, code: "call_reconciliation_required",
          errorMessage: "Call setup could not be confirmed. Its reserved funds are awaiting reconciliation." }, 503);
      }
    }
    return jsonResponse({ success: true, callId: callRecord.id, status: callRecord.status,
      billingState: callRecord.billing_state, maxDurationSeconds: callRecord.max_duration_seconds,
      reservedBudget: callRecord.reserved_budget_usd,
      destination: { number: callRecord.destination_number, countryName: callRecord.destination_country_name,
        countryCode: callRecord.destination_country_code, ratePerMinute: callRecord.rate_per_minute_usd,
        ratePerSecond: (Number(callRecord.rate_per_minute_usd) / 60).toFixed(5),
        connectionFee: callRecord.connection_fee_usd, billingIncrementSeconds: callRecord.billing_increment_seconds },
      callerId: callRecord.effective_caller_id, callerIdType: callRecord.caller_id_type,
      walletBalance, availableBalance: remaining,
    }, 200);

  } catch (err: any) {
    if (err instanceof ProviderConfigurationError) return jsonResponse({ success: false, errorMessage: err.message, code: err.code }, 503);
    console.error("[make-call] error:", err);
    return jsonResponse({ success: false, errorMessage: err.message }, 500);
  }
});
