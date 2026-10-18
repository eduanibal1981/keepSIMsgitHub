import { ProviderConfigurationError, providerSecretClient, requireProviderSecret } from "../_shared/provider-secrets.ts";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

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

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const userId = await resolveUserId(req);
    if (!userId) {
      return jsonResponse({ success: false, errorMessage: "Unauthorized" }, 401);
    }

    const body = await req.json();
    const { action, phoneNumber, callerIdId, code, method, label } = body;
    const telnyxApiKey = await fetchSystemConfig("TELNYX_API_KEY");
    const defaultGateway = await fetchSystemConfig("TELNYX_DEFAULT_CALLER_ID", "+17543180369");

    if (!telnyxApiKey) {
      return jsonResponse({ success: false, errorMessage: "Telnyx API key not configured" }, 500);
    }

    // ── 1. Request Verification (SMS or Voice Call) ──
    if (action === "request_verification") {
      if (!phoneNumber || typeof phoneNumber !== "string") {
        return jsonResponse({ success: false, errorMessage: "phoneNumber is required" }, 400);
      }

      const cleanNumber = normalizeE164(phoneNumber);
      if (!cleanNumber) {
        return jsonResponse({ success: false, errorMessage: "Invalid phone number format. Must be E.164 (e.g. +968...)" }, 400);
      }

      // Check if THIS SPECIFIC USER already verified this number
      const existingUserRecRes = await fetch(
        `${SUPABASE_URL}/rest/v1/user_caller_ids?user_id=eq.${userId}&phone_number=eq.${encodeURIComponent(cleanNumber)}&select=*`,
        { headers: serviceHeaders },
      );
      const existingRows = existingUserRecRes.ok ? await existingUserRecRes.json() : [];
      const userRecord = existingRows[0];

      if (userRecord && userRecord.is_verified) {
        // Set this verified number as active default atomically
        await rpc("set_user_caller_id_preference", {
          p_user_id: userId,
          p_caller_id_id: userRecord.id,
          p_use_gateway: false,
        });

        return jsonResponse({
          success: true,
          isAlreadyVerified: true,
          message: `${cleanNumber} is already verified and activated as your Outbound Caller ID!`,
          phoneNumber: cleanNumber,
        }, 200);
      }

      // Fresh user-bound OTP challenge via Telnyx Verified Numbers API
      const verifyMethod = method === "call" ? "call" : "sms";
      const telnyxRes = await fetch("https://api.telnyx.com/v2/verified_numbers", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${telnyxApiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          phone_number: cleanNumber,
          verification_method: verifyMethod,
        }),
      });

      const telnyxJson = await telnyxRes.json();

      if (!telnyxRes.ok) {
        const errDetail = telnyxJson.errors?.[0]?.detail || "Failed to initiate phone verification";
        return jsonResponse({ success: false, errorMessage: errDetail }, telnyxRes.status);
      }

      // Record in database as pending for THIS user
      if (userRecord) {
        await fetch(`${SUPABASE_URL}/rest/v1/user_caller_ids?id=eq.${userRecord.id}`, {
          method: "PATCH",
          headers: serviceHeaders,
          body: JSON.stringify({
            label: label || userRecord.label || "Mobile Number",
            is_verified: false,
          }),
        });
      } else {
        await fetch(`${SUPABASE_URL}/rest/v1/user_caller_ids`, {
          method: "POST",
          headers: { ...serviceHeaders, "Prefer": "resolution=merge-duplicates" },
          body: JSON.stringify({
            user_id: userId,
            phone_number: cleanNumber,
            label: label || "Mobile Number",
            is_verified: false,
            is_default: false,
          }),
        });
      }

      return jsonResponse({
        success: true,
        isAlreadyVerified: false,
        message: verifyMethod === "call"
          ? `Calling ${cleanNumber} with your verification code...`
          : `Verification code sent via SMS to ${cleanNumber}`,
        phoneNumber: cleanNumber,
      }, 200);
    }

    // ── 2. Verify 6-digit Code ──
    if (action === "verify_code") {
      if (!phoneNumber || !code) {
        return jsonResponse({ success: false, errorMessage: "phoneNumber and code are required" }, 400);
      }

      const cleanNumber = normalizeE164(phoneNumber);
      if (!cleanNumber) {
        return jsonResponse({ success: false, errorMessage: "Invalid phone number format" }, 400);
      }

      const encodedNumber = encodeURIComponent(cleanNumber);
      const telnyxRes = await fetch(`https://api.telnyx.com/v2/verified_numbers/${encodedNumber}/actions/verify`, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${telnyxApiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          code: String(code).trim(),
        }),
      });

      const telnyxJson = await telnyxRes.json();

      if (!telnyxRes.ok) {
        const errDetail = telnyxJson.errors?.[0]?.detail || "Invalid or expired verification code";
        return jsonResponse({ success: false, errorMessage: errDetail }, 400);
      }

      // Lookup or insert record for user
      const userRecRes = await fetch(
        `${SUPABASE_URL}/rest/v1/user_caller_ids?user_id=eq.${userId}&phone_number=eq.${encodeURIComponent(cleanNumber)}&select=*`,
        { headers: serviceHeaders },
      );
      const rows = userRecRes.ok ? await userRecRes.json() : [];
      let targetId: string;

      if (rows.length > 0) {
        targetId = rows[0].id;
        await fetch(`${SUPABASE_URL}/rest/v1/user_caller_ids?id=eq.${targetId}`, {
          method: "PATCH",
          headers: serviceHeaders,
          body: JSON.stringify({
            is_verified: true,
            verified_at: new Date().toISOString(),
          }),
        });
      } else {
        const insRes = await fetch(`${SUPABASE_URL}/rest/v1/user_caller_ids`, {
          method: "POST",
          headers: { ...serviceHeaders, "Prefer": "return=representation" },
          body: JSON.stringify({
            user_id: userId,
            phone_number: cleanNumber,
            label: label || "Mobile Number",
            is_verified: true,
            is_default: false,
            verified_at: new Date().toISOString(),
          }),
        });
        const insRows = insRes.ok ? await insRes.json() : [];
        targetId = insRows[0]?.id;
      }

      // Atomically activate this newly verified number as default
      if (targetId) {
        await rpc("set_user_caller_id_preference", {
          p_user_id: userId,
          p_caller_id_id: targetId,
          p_use_gateway: false,
        });
      }

      return jsonResponse({
        success: true,
        message: `${cleanNumber} has been verified and set as your Outbound Caller ID!`,
        phoneNumber: cleanNumber,
        isVerified: true,
      }, 200);
    }

    // ── 3. List Verified Caller IDs ──
    if (action === "list") {
      const res = await fetch(
        `${SUPABASE_URL}/rest/v1/user_caller_ids?user_id=eq.${userId}&select=*&order=created_at.desc`,
        { headers: serviceHeaders },
      );
      const rows = res.ok ? await res.json() : [];

      // Check user preference
      const prefRes = await fetch(
        `${SUPABASE_URL}/rest/v1/user_caller_id_preferences?user_id=eq.${userId}&select=*`,
        { headers: serviceHeaders },
      );
      const prefs = prefRes.ok ? await prefRes.json() : [];
      const userPref = prefs[0];

      let isGatewayActive = true;
      let activeCallerId = defaultGateway;

      if (userPref && userPref.selected_mode === "verified_number") {
        const matched = rows.find((r: any) => r.id === userPref.selected_caller_id_id && r.is_verified);
        if (matched) {
          isGatewayActive = false;
          activeCallerId = matched.phone_number;
        }
      } else if (!userPref) {
        const defaultVerified = rows.find((r: any) => r.is_default && r.is_verified);
        if (defaultVerified) {
          isGatewayActive = false;
          activeCallerId = defaultVerified.phone_number;
        }
      }

      return jsonResponse({
        success: true,
        callerIds: rows,
        defaultGatewayNumber: defaultGateway,
        isGatewayActive,
        activeCallerId,
      }, 200);
    }

    // ── 4. Set Default / Switch Caller ID ──
    if (action === "set_default") {
      const targetPhone = phoneNumber ? String(phoneNumber).trim() : null;
      const cleanTarget = targetPhone ? normalizeE164(targetPhone) : null;

      // User chose KeepSIMs Gateway explicitly
      if (
        callerIdId === "gateway" ||
        targetPhone === "gateway" ||
        cleanTarget === defaultGateway
      ) {
        await rpc("set_user_caller_id_preference", {
          p_user_id: userId,
          p_caller_id_id: null,
          p_use_gateway: true,
        });

        return jsonResponse({
          success: true,
          message: "KeepSIMs Voice Gateway set as active Outbound Caller ID",
          isGateway: true,
          activeCallerId: defaultGateway,
        }, 200);
      }

      // User chose a verified number
      let targetRow: any = null;
      if (callerIdId) {
        const res = await fetch(
          `${SUPABASE_URL}/rest/v1/user_caller_ids?id=eq.${encodeURIComponent(callerIdId)}&user_id=eq.${userId}&select=*`,
          { headers: serviceHeaders },
        );
        const rows = res.ok ? await res.json() : [];
        targetRow = rows[0];
      } else if (cleanTarget) {
        const res = await fetch(
          `${SUPABASE_URL}/rest/v1/user_caller_ids?phone_number=eq.${encodeURIComponent(cleanTarget)}&user_id=eq.${userId}&select=*`,
          { headers: serviceHeaders },
        );
        const rows = res.ok ? await res.json() : [];
        targetRow = rows[0];
      }

      if (!targetRow) {
        return jsonResponse({ success: false, errorMessage: "Caller ID not found in your account" }, 404);
      }
      if (!targetRow.is_verified) {
        return jsonResponse({ success: false, errorMessage: "This number is not verified yet" }, 400);
      }

      // Atomically set preference
      const rpcResult = await rpc("set_user_caller_id_preference", {
        p_user_id: userId,
        p_caller_id_id: targetRow.id,
        p_use_gateway: false,
      });

      if (!rpcResult.ok) {
        return jsonResponse({ success: false, errorMessage: "Failed to update default caller ID" }, 500);
      }

      return jsonResponse({
        success: true,
        message: `${targetRow.phone_number} set as your Outbound Caller ID`,
        isGateway: false,
        activeCallerId: targetRow.phone_number,
      }, 200);
    }

    // ── 5. Delete Caller ID ──
    if (action === "delete") {
      let targetRow: any = null;
      if (callerIdId) {
        const res = await fetch(
          `${SUPABASE_URL}/rest/v1/user_caller_ids?id=eq.${encodeURIComponent(callerIdId)}&user_id=eq.${userId}&select=*`,
          { headers: serviceHeaders },
        );
        const rows = res.ok ? await res.json() : [];
        targetRow = rows[0];
      } else if (phoneNumber) {
        const clean = normalizeE164(phoneNumber);
        if (clean) {
          const res = await fetch(
            `${SUPABASE_URL}/rest/v1/user_caller_ids?phone_number=eq.${encodeURIComponent(clean)}&user_id=eq.${userId}&select=*`,
            { headers: serviceHeaders },
          );
          const rows = res.ok ? await res.json() : [];
          targetRow = rows[0];
        }
      }

      if (!targetRow) {
        return jsonResponse({ success: false, errorMessage: "Caller ID not found" }, 404);
      }

      // If it was the active default, revert preference to gateway
      if (targetRow.is_default) {
        await rpc("set_user_caller_id_preference", {
          p_user_id: userId,
          p_caller_id_id: null,
          p_use_gateway: true,
        });
      }

      await fetch(`${SUPABASE_URL}/rest/v1/user_caller_ids?id=eq.${targetRow.id}&user_id=eq.${userId}`, {
        method: "DELETE",
        headers: serviceHeaders,
      });

      return jsonResponse({ success: true, message: "Caller ID removed" }, 200);
    }

    return jsonResponse({ success: false, errorMessage: "Invalid action" }, 400);

  } catch (err: any) {
    if (err instanceof ProviderConfigurationError) return jsonResponse({ success: false, errorMessage: err.message, code: err.code }, 503);
    console.error("[manage-caller-id] error:", err);
    return jsonResponse({ success: false, errorMessage: err.message }, 500);
  }
});
