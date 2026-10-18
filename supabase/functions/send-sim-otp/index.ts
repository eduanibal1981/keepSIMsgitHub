// send-sim-otp — Send Voice Call or SMS OTP via Telnyx 2FA to verify SIM line liveness

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";
import { ProviderConfigurationError, requireProviderSecret } from "../_shared/provider-secrets.ts";

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
            p_bucket: "send_sim_otp",
            p_key: user.id,
            p_capacity: 10,
            p_refill_per_minute: 2.0,
          });
        } catch (_) {}
      }
    }

    const { phoneNumber, channel, countryCode } = await req.json();

    if (!phoneNumber || typeof phoneNumber !== "string" || phoneNumber.trim().length < 6) {
      return new Response(
        JSON.stringify({ success: false, message: "Invalid phone number format." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const formattedPhone = formatMsisdn(phoneNumber);
    const chosenChannel = channel === "sms" ? "sms" : "call";

    if (!supabaseUrl || !supabaseServiceKey) throw new ProviderConfigurationError();
    const apiKey = await requireProviderSecret(
      createClient(supabaseUrl, supabaseServiceKey), "TELNYX_API_KEY",
    );
    const profileId = Deno.env.get("TELNYX_VERIFY_PROFILE_ID")?.trim();
    if (!profileId) throw new ProviderConfigurationError();

    const payload = {
      phone_number: formattedPhone,
      verify_profile_id: profileId,
      type: chosenChannel,
      timeout_secs: chosenChannel === "call" ? 180 : 300,
    };

    const res = await fetch("https://api.telnyx.com/v2/verifications/by_phone_number", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify(payload),
    });

    const resData = await res.json();
    console.log("[send-sim-otp] Provider response status", res.status);

    if (res.ok) {
      return new Response(
        JSON.stringify({
          success: true,
          channel: chosenChannel,
          phone_number: formattedPhone,
          message: chosenChannel === "call"
            ? "Calling your SIM with verification code..."
            : "SMS verification code sent.",
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    } else {
      const errorDetail = resData.errors?.[0]?.detail || resData.message || "Failed to dispatch verification OTP.";
      return new Response(
        JSON.stringify({
          success: false,
          message: errorDetail,
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }
  } catch (error: any) {
    if (error instanceof ProviderConfigurationError) {
      return new Response(
        JSON.stringify({ success: false, code: error.code, message: error.message }),
        { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }
    console.error("[send-sim-otp] Request failed");
    return new Response(
      JSON.stringify({
        success: false,
        message: "Unable to send verification OTP.",
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
