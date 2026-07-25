// detect-country — KeepSIMs IP-based Travel & Geolocation Edge Function (C8).
//
// Resolves the caller's country from request IP server-side, checks flap-guard,
// updates profiles.last_country, and inserts geo_fence_triggered / welcome_home_ready
// notifications with an action_url (/esim or /settings/geo).
//
// Security: Requires valid user JWT (verify_jwt). D2 Rate limited (12/60min).

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const COUNTRY_NAMES: Record<string, string> = {
  US: "United States",
  GB: "United Kingdom",
  CA: "Canada",
  DE: "Germany",
  FR: "France",
  AE: "United Arab Emirates",
  EG: "Egypt",
  LK: "Sri Lanka",
  IN: "India",
  TR: "Turkey",
  ES: "Spain",
  NP: "Nepal",
  BD: "Bangladesh",
};

function getCountryName(iso: string): string {
  return COUNTRY_NAMES[iso.toUpperCase()] ?? iso.toUpperCase();
}

async function resolveCountryFromIp(req: Request): Promise<string> {
  const cfCountry = req.headers.get("cf-ipcountry");
  if (cfCountry && cfCountry.length === 2 && cfCountry.toUpperCase() !== "XX") {
    return cfCountry.toUpperCase();
  }

  const xCountry = req.headers.get("x-country-code") || req.headers.get("x-appengine-country") || req.headers.get("x-client-ip-country");
  if (xCountry && xCountry.length === 2 && xCountry.toUpperCase() !== "XX") {
    return xCountry.toUpperCase();
  }

  const xForwardedFor = req.headers.get("x-forwarded-for");
  const clientIp = xForwardedFor ? xForwardedFor.split(",")[0].trim() : req.headers.get("x-real-ip");

  if (!clientIp || clientIp === "127.0.0.1" || clientIp.startsWith("10.") || clientIp.startsWith("192.168.")) {
    return "US";
  }

  try {
    const res = await fetch(`https://ipapi.co/${clientIp}/country/`, {
      headers: { "User-Agent": "KeepSIMs-Geo/1.0" },
    });
    if (res.ok) {
      const countryText = (await res.text()).trim().toUpperCase();
      if (countryText.length === 2 && countryText !== "UNDEFINED") {
        return countryText;
      }
    }
  } catch (_) {
    // Ignore external fetch errors and fall through
  }

  return "US";
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization header" }), {
        status: 401,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
      });
    }

    const token = authHeader.replace("Bearer ", "").trim();
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: { user }, error: userError } = await supabase.auth.getUser(token);
    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Not authenticated" }), {
        status: 401,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
      });
    }

    // D2 Rate Limiter (detect_country bucket: 12/60min)
    const { data: limitData, error: limitErr } = await supabase.rpc("consume_rate_limit", {
      p_bucket: "detect_country",
      p_key: user.id,
      p_capacity: 12,
      p_refill_per_minute: 12.0 / 60.0,
    });

    if (limitErr || !limitData || (Array.isArray(limitData) && limitData[0]?.allowed === false)) {
      const retryAfter = (Array.isArray(limitData) && limitData[0]?.retry_after_seconds) ? limitData[0].retry_after_seconds : 60;
      return new Response(
        JSON.stringify({ code: "rate_limited", bucket: "detect_country", retry_after: retryAfter }),
        {
          status: 429,
          headers: {
            "Content-Type": "application/json",
            "Retry-After": String(retryAfter),
            "Access-Control-Allow-Origin": "*",
          },
        }
      );
    }

    // Resolve country
    const detectedCountry = await resolveCountryFromIp(req);

    // Fetch user profile
    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("id, last_country, home_country_code, updated_at")
      .eq("id", user.id)
      .single();

    if (profileError || !profile) {
      return new Response(JSON.stringify({ error: "Profile not found" }), {
        status: 404,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
      });
    }

    const lastCountry = profile.last_country ? profile.last_country.toUpperCase() : null;
    const homeCountry = profile.home_country_code ? profile.home_country_code.toUpperCase() : "US";

    if (lastCountry === detectedCountry) {
      return new Response(JSON.stringify({
        status: "noop",
        detected_country: detectedCountry,
        last_country: lastCountry,
        reason: "same_country",
      }), {
        status: 200,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
      });
    }

    let flapGuardHours = 1;
    const { data: configData } = await supabase
      .from("system_configs")
      .select("config_value")
      .eq("config_key", "GEO_FLAP_GUARD_HOURS")
      .single();

    if (configData && configData.config_value) {
      const parsed = parseInt(configData.config_value, 10);
      if (!isNaN(parsed) && parsed > 0) {
        flapGuardHours = parsed;
      }
    }

    if (lastCountry !== null) {
      const cutoff = new Date(Date.now() - flapGuardHours * 60 * 60 * 1000).toISOString();
      const { data: recentNotifications } = await supabase
        .from("notifications")
        .select("id")
        .eq("user_id", user.id)
        .in("category", ["geo_fence_triggered", "welcome_home_ready"])
        .gte("created_at", cutoff)
        .limit(1);

      if (recentNotifications && recentNotifications.length > 0) {
        return new Response(JSON.stringify({
          status: "suppressed",
          detected_country: detectedCountry,
          last_country: lastCountry,
          reason: "flap_guard",
        }), {
          status: 200,
          headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
        });
      }
    }

    const nowIso = new Date().toISOString();
    await supabase
      .from("profiles")
      .update({ last_country: detectedCountry, updated_at: nowIso })
      .eq("id", user.id);

    const countryName = getCountryName(detectedCountry);
    const isHome = detectedCountry === homeCountry;

    const category = isHome ? "welcome_home_ready" : "geo_fence_triggered";
    const title = isHome ? "Welcome Home! 🏠" : `Welcome to ${countryName}! ✈️`;
    const body = isHome
      ? `You are back in ${countryName}. Unfreeze your local lines if needed.`
      : `You have arrived in ${countryName}. Secure your prepaid line or get an eSIM package to avoid roaming fees.`;
    const actionUrl = isHome ? "/settings/geo" : "/esim";

    const { data: insertedNotif, error: notifError } = await supabase
      .from("notifications")
      .insert({
        user_id: user.id,
        category: category,
        title: title,
        body: body,
        action_url: actionUrl,
      })
      .select("id")
      .single();

    if (notifError) {
      console.error("Failed to insert geo notification:", notifError);
    }

    return new Response(JSON.stringify({
      status: "updated",
      detected_country: detectedCountry,
      last_country: lastCountry,
      category: category,
      action_url: actionUrl,
      notification_id: insertedNotif?.id ?? null,
    }), {
      status: 200,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  }
});
