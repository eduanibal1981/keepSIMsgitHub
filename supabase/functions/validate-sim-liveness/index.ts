// validate-sim-liveness — KeepSIMs Carrier BSS Liveness & Activity Verification Edge Function
// Zero-cost live Carrier BSS validation via wholesale gateways (DTOne, Zendit, Reloadly, Telnyx).

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface LivenessValidationResponse {
  is_active: boolean;
  carrier_status: "active" | "inactive" | "unsupported" | "pending";
  detected_operator_name: string | null;
  country_code: string | null;
  reason: string | null;
  message: string;
  provider: "zendit" | "dtone" | "reloadly" | "telnyx" | "none";
  verified_at: string;
}

function jsonResponse(body: LivenessValidationResponse | Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function formatMsisdn(raw: string): string {
  let cleaned = raw.replace(/[\s\-\(\)]/g, "");
  if (!cleaned.startsWith("+")) {
    cleaned = `+${cleaned}`;
  }
  return cleaned;
}

function cleanOperatorName(rawName: string): string {
  return rawName
    .replace(/ PIN.*$/i, "")
    .replace(/ Direct.*$/i, "")
    .replace(/ Topup.*$/i, "")
    .replace(/ Oman.*$/i, "")
    .replace(/ Egypt.*$/i, "")
    .replace(/ Saudi.*$/i, "")
    .replace(/ UAE.*$/i, "")
    .replace(/ Company.*$/i, "")
    .replace(/ SAOC.*$/i, "")
    .trim();
}

// Explicit deactivation error keywords from carrier BSS
const EXPLICIT_DEACTIVATION_CODES = [
  "SUBSCRIBER_NOT_FOUND",
  "ACCOUNT_BARRED",
  "ACCOUNT_DEACTIVATED",
  "DEACTIVATED",
  "SUBSCRIBER_BARRED",
  "NUMBER_DISCONNECTED",
  "SUSPENDED",
  "INVALID_MSISDN_DEACTIVATED",
];

function isExplicitlyDeactivated(errStr: string): boolean {
  const upper = errStr.toUpperCase();
  return EXPLICIT_DEACTIVATION_CODES.some((code) => upper.includes(code));
}

// 1. DTOne BSS Mobile Number Lookup
async function queryDTOne(
  formattedPhone: string,
  countryCode?: string,
): Promise<{ success: boolean; active?: boolean; operatorName?: string; country?: string; reason?: string; raw?: any }> {
  const apiKey = Deno.env.get("DTONE_API_KEY") || "2b05ef8e-87af-4c60-baa8-1bcc70f7e8a2";
  const apiSecret = Deno.env.get("DTONE_API_SECRET") || "963d8def-45d4-4bf9-8b11-9732f545784f";
  const baseUrl = Deno.env.get("DTONE_BASE_URL") || "https://preprod-dvs-api.dtone.com/v1";

  const authHeader = `Basic ${btoa(`${apiKey}:${apiSecret}`)}`;
  const headers = {
    Authorization: authHeader,
    Accept: "application/json",
  };

  const testUrls = [
    `${baseUrl}/lookup/mobile-number/${encodeURIComponent(formattedPhone)}`,
    `${baseUrl}/lookup/mobile-number/${encodeURIComponent(formattedPhone.replace("+", ""))}`,
  ];

  for (const url of testUrls) {
    try {
      const res = await fetch(url, { headers });
      const text = await res.text();
      console.log(`[DTOne GET ${url}] status=${res.status} body=${text}`);

      if (res.ok) {
        let data: any = {};
        try { data = JSON.parse(text); } catch (_) {}

        if (Array.isArray(data)) {
          const activeOp = data.find((item: any) => item.identified === true);
          if (activeOp) {
            const opName = cleanOperatorName(activeOp.name || "Carrier");
            const cCode = activeOp.country?.iso_code || countryCode;
            return {
              success: true,
              active: true,
              operatorName: opName,
              country: cCode ? String(cCode) : undefined,
              raw: activeOp,
            };
          }
          // Note: If no product in DTOne's catalog had identified: true, it means
          // DTOne does not have a mapped SKU for this line/MVNO. Do not assume deactivated.
        } else if (data && typeof data === "object") {
          if (data.identified === true) {
            const op = data.operator || data;
            const rawName = op.name || op.brand;
            if (rawName) {
              return {
                success: true,
                active: true,
                operatorName: cleanOperatorName(rawName),
                country: op.country?.iso_code || countryCode,
                raw: data,
              };
            }
          }
        }
      } else if (isExplicitlyDeactivated(text)) {
        return { success: true, active: false, reason: "SUBSCRIBER_NOT_FOUND_OR_DEACTIVATED", raw: text };
      }
    } catch (e) {
      console.error(`[DTOne GET] error:`, e);
    }
  }

  return { success: false, reason: "INCONCLUSIVE" };
}

// 2. Zendit BSS Lookup
async function queryZendit(
  formattedPhone: string,
  countryCode?: string,
): Promise<{ success: boolean; active?: boolean; operatorName?: string; country?: string; reason?: string; raw?: any }> {
  const apiSecret = Deno.env.get("ZENDIT_API_SECRET") || Deno.env.get("ZENDIT_API_KEY") || "sand_0296bcc7-526e-4efb-b4f9-8b11108e7c396a29abd0a371a4c9f33194dd";
  const baseUrl = Deno.env.get("ZENDIT_BASE_URL") || "https://api.zendit.io/v1";
  const headers = {
    Authorization: `Bearer ${apiSecret}`,
    "Content-Type": "application/json",
    Accept: "application/json",
  };

  const testUrls = [
    `${baseUrl}/operators/auto-detect?phoneNumber=${encodeURIComponent(formattedPhone)}`,
    `${baseUrl}/operators/auto-detect?phone_number=${encodeURIComponent(formattedPhone)}`,
    `${baseUrl}/topups/lookup?phoneNumber=${encodeURIComponent(formattedPhone)}`,
    `${baseUrl}/topups/lookup?recipientPhoneNumber=${encodeURIComponent(formattedPhone)}`,
  ];

  for (const url of testUrls) {
    try {
      const res = await fetch(url, { headers });
      const text = await res.text();
      console.log(`[Zendit GET ${url}] status=${res.status} body=${text}`);

      if (res.ok) {
        let data: any = {};
        try { data = JSON.parse(text); } catch (_) {}
        const rawName = data.name || data.brand || data.operator?.name || data.operator?.brand || (data.list && data.list[0]?.brand);
        const cCode = data.country || data.countryCode || (data.list && data.list[0]?.country) || countryCode;
        if (rawName) {
          return {
            success: true,
            active: true,
            operatorName: cleanOperatorName(String(rawName)),
            country: cCode ? String(cCode) : undefined,
            raw: data,
          };
        }
      } else if (isExplicitlyDeactivated(text)) {
        return { success: true, active: false, reason: "DEACTIVATED_OR_UNALLOCATED", raw: text };
      }
    } catch (e) {
      console.error(`[Zendit GET] error:`, e);
    }
  }

  return { success: false, reason: "INCONCLUSIVE" };
}

// 3. Reloadly Auto-Detect Lookup
async function queryReloadly(
  formattedPhone: string,
  countryCode?: string,
): Promise<{ success: boolean; active?: boolean; operatorName?: string; country?: string; reason?: string; raw?: any }> {
  const clientId = Deno.env.get("RELOADLY_CLIENT_ID") || "dd6gftTPkt6O1o0sYypMinikCxtnr2k7";
  const clientSecret = Deno.env.get("RELOADLY_CLIENT_SECRET") || "MryXmVGmH4-Ul4JILEmGCbdLK3xfMG-bd5R3kG05jiZBCFckvPBHMPMDE6iE8dM";

  try {
    const authRes = await fetch("https://auth.reloadly.com/oauth/token", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        client_id: clientId,
        client_secret: clientSecret,
        grant_type: "client_credentials",
        audience: "https://topups-sandbox.reloadly.com",
      }),
    });

    if (!authRes.ok) return { success: false, reason: "AUTH_FAILED" };
    const authData = await authRes.json();
    const token = authData.access_token;
    if (!token) return { success: false, reason: "TOKEN_MISSING" };

    const cleanDigits = formattedPhone.replace("+", "");
    const cIso = (countryCode || "").toUpperCase();
    const autoUrl = cIso
      ? `https://topups-sandbox.reloadly.com/operators/auto-detect/phone/${cleanDigits}/countries/${cIso}`
      : `https://topups-sandbox.reloadly.com/operators/auto-detect/phone/${cleanDigits}`;

    const autoRes = await fetch(autoUrl, {
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: "application/com.reloadly.topups-v1+json",
      },
    });

    const text = await autoRes.text();
    console.log(`[Reloadly GET] status=${autoRes.status} body=${text}`);

    if (autoRes.ok) {
      let data: any = {};
      try { data = JSON.parse(text); } catch (_) {}
      const rawName = data.name || data.operatorName;
      if (rawName && data.status === "ACTIVE") {
        return {
          success: true,
          active: true,
          operatorName: cleanOperatorName(rawName),
          country: data.country?.isoName || countryCode,
          raw: data,
        };
      }
    } else if (isExplicitlyDeactivated(text)) {
      return { success: true, active: false, reason: "UNALLOCATED_OR_EXPIRED", raw: text };
    }
  } catch (e) {
    console.error("[Reloadly] error:", e);
  }

  return { success: false, reason: "INCONCLUSIVE" };
}

// 4. Telnyx Number Lookup (Carrier network validation fallback)
async function queryTelnyx(
  formattedPhone: string,
  countryCode?: string,
): Promise<{ success: boolean; valid?: boolean; operatorName?: string; country?: string; raw?: any }> {
  const apiKey = Deno.env.get("TELNYX_API_KEY") || "KEY01A049E00656B79B4314CFFBC7969C10_k9JM7HV9u4sB2MadneUT1M";

  try {
    const res = await fetch(`https://api.telnyx.com/v2/number_lookup/${encodeURIComponent(formattedPhone)}?type=carrier`, {
      headers: { Authorization: `Bearer ${apiKey}`, Accept: "application/json" },
    });
    if (res.ok) {
      const data = await res.json();
      const numData = data?.data;
      if (numData && numData.valid_number === true) {
        const opName = numData.carrier?.name ? cleanOperatorName(numData.carrier.name) : undefined;
        return {
          success: true,
          valid: true,
          operatorName: opName,
          country: numData.country_code || countryCode,
          raw: numData,
        };
      } else if (numData && numData.valid_number === false) {
        return { success: true, valid: false, raw: numData };
      }
    }
  } catch (e) {
    console.error("[Telnyx] error:", e);
  }
  return { success: false };
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
            p_bucket: "validate_liveness",
            p_key: user.id,
            p_capacity: 30,
            p_refill_per_minute: 6.0,
          });
        } catch (_) {}
      }
    }

    const { phoneNumber, countryCode } = await req.json();

    if (!phoneNumber || typeof phoneNumber !== "string" || phoneNumber.trim().length < 6) {
      return jsonResponse({
        is_active: false,
        carrier_status: "inactive",
        detected_operator_name: null,
        country_code: countryCode || null,
        reason: "INVALID_PHONE_FORMAT",
        message: "Invalid phone number format. Please provide a valid mobile number.",
        provider: "none",
        verified_at: nowIso,
      }, 400);
    }

    const formattedPhone = formatMsisdn(phoneNumber);

    // 1. Primary: DTOne BSS Lookup
    const dtoneResult = await queryDTOne(formattedPhone, countryCode);
    if (dtoneResult.success) {
      if (dtoneResult.active) {
        return jsonResponse({
          is_active: true,
          carrier_status: "active",
          detected_operator_name: dtoneResult.operatorName ?? null,
          country_code: dtoneResult.country ?? countryCode ?? null,
          reason: null,
          message: `Active on ${dtoneResult.operatorName || "Carrier"} (Prepaid)`,
          provider: "dtone",
          verified_at: nowIso,
        });
      } else if (dtoneResult.active === false && dtoneResult.reason === "SUBSCRIBER_NOT_FOUND_OR_DEACTIVATED") {
        return jsonResponse({
          is_active: false,
          carrier_status: "inactive",
          detected_operator_name: null,
          country_code: countryCode ?? null,
          reason: dtoneResult.reason,
          message: "Number inactive or expired at carrier. Cannot register for auto-refill.",
          provider: "dtone",
          verified_at: nowIso,
        });
      }
    }

    // 2. Secondary: Zendit BSS Lookup
    const zenditResult = await queryZendit(formattedPhone, countryCode);
    if (zenditResult.success) {
      if (zenditResult.active) {
        return jsonResponse({
          is_active: true,
          carrier_status: "active",
          detected_operator_name: zenditResult.operatorName ?? null,
          country_code: zenditResult.country ?? countryCode ?? null,
          reason: null,
          message: `Active on ${zenditResult.operatorName || "Carrier"} (Prepaid)`,
          provider: "zendit",
          verified_at: nowIso,
        });
      } else if (zenditResult.active === false && zenditResult.reason === "DEACTIVATED_OR_UNALLOCATED") {
        return jsonResponse({
          is_active: false,
          carrier_status: "inactive",
          detected_operator_name: null,
          country_code: countryCode ?? null,
          reason: zenditResult.reason,
          message: "Number inactive or expired at carrier. Cannot register for auto-refill.",
          provider: "zendit",
          verified_at: nowIso,
        });
      }
    }

    // 3. Tertiary: Reloadly Auto-Detect Lookup
    const reloadlyResult = await queryReloadly(formattedPhone, countryCode);
    if (reloadlyResult.success) {
      if (reloadlyResult.active) {
        return jsonResponse({
          is_active: true,
          carrier_status: "active",
          detected_operator_name: reloadlyResult.operatorName ?? null,
          country_code: reloadlyResult.country ?? countryCode ?? null,
          reason: null,
          message: `Active on ${reloadlyResult.operatorName || "Carrier"} (Prepaid)`,
          provider: "reloadly",
          verified_at: nowIso,
        });
      } else if (reloadlyResult.active === false) {
        return jsonResponse({
          is_active: false,
          carrier_status: "inactive",
          detected_operator_name: null,
          country_code: countryCode ?? null,
          reason: reloadlyResult.reason || "EXPIRED_OR_DEACTIVATED",
          message: "Number inactive or expired at carrier. Cannot register for auto-refill.",
          provider: "reloadly",
          verified_at: nowIso,
        });
      }
    }

    // 4. Quaternary: Telnyx carrier verification fallback
    const telnyxResult = await queryTelnyx(formattedPhone, countryCode);
    if (telnyxResult.success && telnyxResult.valid === false) {
      return jsonResponse({
        is_active: false,
        carrier_status: "inactive",
        detected_operator_name: null,
        country_code: countryCode ?? null,
        reason: "INVALID_NUMBER_RANGE",
        message: "Invalid or unassigned phone number range.",
        provider: "telnyx",
        verified_at: nowIso,
      });
    }

    // 5. Inconclusive: Carrier BSS verification not available for this corridor
    const detectedOp = telnyxResult.operatorName ?? null;
    return jsonResponse({
      is_active: false,
      carrier_status: "unsupported",
      detected_operator_name: detectedOp,
      country_code: countryCode ?? null,
      reason: "GATEWAY_LOOKUP_INCONCLUSIVE",
      message: "Carrier verification unavailable for this corridor.",
      provider: "none",
      verified_at: nowIso,
    });
  } catch (error: any) {
    console.error("[validate-sim-liveness] Unhandled error:", error);
    return jsonResponse({
      is_active: false,
      carrier_status: "unsupported",
      detected_operator_name: null,
      country_code: null,
      reason: error.message || "INTERNAL_ERROR",
      message: "Verification service temporarily unavailable.",
      provider: "none",
      verified_at: nowIso,
    }, 500);
  }
});
