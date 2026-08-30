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

async function checkIsNumberVerifiedOnTelnyx(telnyxApiKey: string, cleanNumber: string): Promise<boolean> {
  try {
    const res = await fetch("https://api.telnyx.com/v2/verified_numbers", {
      headers: { "Authorization": `Bearer ${telnyxApiKey}` },
    });
    if (!res.ok) return false;
    const json = await res.json();
    const list = json.data as Array<{ phone_number: string }>;
    return list.some(item => item.phone_number.replace(/\s+/g, "") === cleanNumber.replace(/\s+/g, ""));
  } catch (_) {
    return false;
  }
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

    const { action, phoneNumber, code, method, label } = await req.json();
    const telnyxApiKey = await fetchSystemConfig("TELNYX_API_KEY");

    if (!telnyxApiKey) {
      return jsonResponse({ success: false, errorMessage: "Telnyx API key not configured" }, 500);
    }

    // ── 1. Request Verification (SMS or Call) ──
    if (action === "request_verification") {
      if (!phoneNumber || typeof phoneNumber !== "string") {
        return jsonResponse({ success: false, errorMessage: "phoneNumber is required" }, 400);
      }

      const cleanNumber = phoneNumber.trim().startsWith("+") ? phoneNumber.trim().replace(/\s+/g, "") : `+${phoneNumber.trim().replace(/\s+/g, "")}`;

      // Check if already verified on Telnyx
      const alreadyVerified = await checkIsNumberVerifiedOnTelnyx(telnyxApiKey, cleanNumber);
      if (alreadyVerified) {
        // Set other caller IDs for user to false
        await fetch(`${SUPABASE_URL}/rest/v1/user_caller_ids?user_id=eq.${userId}`, {
          method: "PATCH",
          headers: serviceHeaders,
          body: JSON.stringify({ is_default: false }),
        });

        // Upsert as verified and default
        await fetch(`${SUPABASE_URL}/rest/v1/user_caller_ids`, {
          method: "POST",
          headers: { ...serviceHeaders, "Prefer": "resolution=merge-duplicates" },
          body: JSON.stringify({
            user_id: userId,
            phone_number: cleanNumber,
            label: label || "Mobile Number",
            is_verified: true,
            is_default: true,
            verified_at: new Date().toISOString(),
          }),
        });

        return jsonResponse({
          success: true,
          isAlreadyVerified: true,
          message: `${cleanNumber} is verified and activated as your Outbound Caller ID!`,
          phoneNumber: cleanNumber,
        }, 200);
      }

      // Not verified yet -> Call Telnyx Verified Numbers API with specified method (sms or call)
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

      // Upsert record in database as pending
      await fetch(`${SUPABASE_URL}/rest/v1/user_caller_ids`, {
        method: "POST",
        headers: { ...serviceHeaders, "Prefer": "resolution=merge-duplicates" },
        body: JSON.stringify({
          user_id: userId,
          phone_number: cleanNumber,
          label: label || "Mobile Number",
          is_verified: false,
        }),
      });

      return jsonResponse({
        success: true,
        isAlreadyVerified: false,
        message: verifyMethod === "call" 
          ? `Calling ${cleanNumber} with your 6-digit verification code...`
          : `Verification code sent via SMS to ${cleanNumber}`,
        phoneNumber: cleanNumber,
      }, 200);
    }

    // ── 2. Verify 6-digit Code ──
    if (action === "verify_code") {
      if (!phoneNumber || !code) {
        return jsonResponse({ success: false, errorMessage: "phoneNumber and code are required" }, 400);
      }

      const cleanNumber = phoneNumber.trim().startsWith("+") ? phoneNumber.trim().replace(/\s+/g, "") : `+${phoneNumber.trim().replace(/\s+/g, "")}`;
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
        // If it failed because already verified on Telnyx
        const alreadyVerified = await checkIsNumberVerifiedOnTelnyx(telnyxApiKey, cleanNumber);
        if (!alreadyVerified) {
          const errDetail = telnyxJson.errors?.[0]?.detail || "Invalid or expired verification code";
          return jsonResponse({ success: false, errorMessage: errDetail }, 400);
        }
      }

      // Set other caller IDs for this user to is_default = false
      await fetch(`${SUPABASE_URL}/rest/v1/user_caller_ids?user_id=eq.${userId}`, {
        method: "PATCH",
        headers: serviceHeaders,
        body: JSON.stringify({ is_default: false }),
      });

      // Update this caller ID to verified and default
      await fetch(`${SUPABASE_URL}/rest/v1/user_caller_ids?user_id=eq.${userId}&phone_number=eq.${encodedNumber}`, {
        method: "PATCH",
        headers: serviceHeaders,
        body: JSON.stringify({
          is_verified: true,
          is_default: true,
          verified_at: new Date().toISOString(),
        }),
      });

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
      const defaultGateway = await fetchSystemConfig("TELNYX_DEFAULT_CALLER_ID", "+17543180369");

      return jsonResponse({
        success: true,
        callerIds: rows,
        defaultGatewayNumber: defaultGateway,
      }, 200);
    }

    // ── 4. Set Default Caller ID ──
    if (action === "set_default") {
      if (!phoneNumber) {
        return jsonResponse({ success: false, errorMessage: "phoneNumber is required" }, 400);
      }
      const cleanNumber = phoneNumber.trim().startsWith("+") ? phoneNumber.trim().replace(/\s+/g, "") : `+${phoneNumber.trim().replace(/\s+/g, "")}`;
      const encodedNumber = encodeURIComponent(cleanNumber);

      await fetch(`${SUPABASE_URL}/rest/v1/user_caller_ids?user_id=eq.${userId}`, {
        method: "PATCH",
        headers: serviceHeaders,
        body: JSON.stringify({ is_default: false }),
      });

      await fetch(`${SUPABASE_URL}/rest/v1/user_caller_ids?user_id=eq.${userId}&phone_number=eq.${encodedNumber}`, {
        method: "PATCH",
        headers: serviceHeaders,
        body: JSON.stringify({ is_default: true }),
      });

      return jsonResponse({ success: true, message: "Default caller ID updated" }, 200);
    }

    return jsonResponse({ success: false, errorMessage: "Invalid action" }, 400);

  } catch (err: any) {
    console.error("manage-caller-id error:", err);
    return jsonResponse({ success: false, errorMessage: err.message }, 500);
  }
});
