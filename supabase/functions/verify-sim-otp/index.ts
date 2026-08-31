// verify-sim-otp — Verify Voice Call or SMS OTP via Telnyx 2FA to confirm SIM line liveness

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function formatMsisdn(raw: string): string {
  let cleaned = raw.replace(/[\s\-\(\)]/g, "");
  if (!cleaned.startsWith("+")) {
    cleaned = `+${cleaned}`;
  }
  return cleaned;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const nowIso = new Date().toISOString();

  try {
    const authHeader = req.headers.get("Authorization");
    const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

    if (supabaseUrl && supabaseServiceKey && authHeader) {
      const token = authHeader.replace("Bearer ", "").trim();
      const supabase = createClient(supabaseUrl, supabaseServiceKey);
      const { data: { user } } = await supabase.auth.getUser(token);

      if (user) {
        try {
          await supabase.rpc("consume_rate_limit", {
            p_bucket: "verify_sim_otp",
            p_key: user.id,
            p_capacity: 15,
            p_refill_per_minute: 3.0,
          });
        } catch (_) {}
      }
    }

    const { phoneNumber, code, operatorName, countryCode } = await req.json();

    if (!phoneNumber || !code) {
      return new Response(
        JSON.stringify({ success: false, message: "Phone number and verification code are required." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const formattedPhone = formatMsisdn(phoneNumber);
    const apiKey = Deno.env.get("TELNYX_API_KEY") || "KEY01A049E00656B79B4314CFFBC7969C10_k9JM7HV9u4sB2MadneUT1M";
    const profileId = Deno.env.get("TELNYX_VERIFY_PROFILE_ID") || "490001a0-5878-8d2d-2d6e-5a06fcffd1cf";

    const payload = {
      code: String(code).trim(),
      verify_profile_id: profileId,
    };

    const res = await fetch(`https://api.telnyx.com/v2/verifications/by_phone_number/${encodeURIComponent(formattedPhone)}/actions/verify`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify(payload),
    });

    const resData = await res.json();
    console.log(`[verify-sim-otp] to=${formattedPhone} status=${res.status}`, resData);

    if (res.ok && resData.data?.response_code === "accepted") {
      return new Response(
        JSON.stringify({
          success: true,
          is_valid: true,
          is_active: true,
          carrier_status: "active",
          detected_operator_name: operatorName || null,
          country_code: countryCode || null,
          message: `Active on ${operatorName || "Carrier"} (OTP Verified)`,
          provider: "telnyx",
          verified_at: nowIso,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    } else {
      const errorMsg = resData.data?.response_code === "rejected"
        ? "Incorrect verification code. Please check and try again."
        : resData.errors?.[0]?.detail || resData.message || "Invalid or expired verification code.";

      return new Response(
        JSON.stringify({
          success: false,
          is_valid: false,
          is_active: false,
          carrier_status: "unsupported",
          message: errorMsg,
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }
  } catch (error: any) {
    console.error("[verify-sim-otp] error:", error);
    return new Response(
      JSON.stringify({
        success: false,
        is_valid: false,
        message: error.message || "Internal error verifying OTP.",
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
