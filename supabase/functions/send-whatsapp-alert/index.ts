import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";
import { routeAndSendWhatsApp } from "../_shared/whatsapp_router.ts";
import { profileSecret } from "../_shared/whatsapp_profile.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return new Response(JSON.stringify({ error: "method_not_allowed" }),
    { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });

  try {
    // 1. Authenticate caller
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 401,
      });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const jwt = authHeader.replace(/^Bearer\s+/i, "");
    const caller = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY,
      { global: { headers: { Authorization: `Bearer ${jwt}` } } });
    const { data: { user }, error: authErr } = await supabase.auth.getUser(jwt);

    if (authErr || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 401,
      });
    }

    // getUser verifies identity and retrieves server-owned app metadata. Do not
    // run a caller-claim RPC with this separate service-role client.
    const { data: account, error: accountError } = await supabase.from("profiles")
      .select("is_suspended").eq("id", user.id).maybeSingle();
    if (user.app_metadata?.is_power_user !== true || accountError || !account || account.is_suspended === true) {
      return new Response(
        JSON.stringify({
          error: "Forbidden: Direct WhatsApp testing is restricted to administrator accounts.",
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 403,
        },
      );
    }

    // 3. Rate-limit admin test sends (max 10 tests / 5 mins)
    try {
      const { data: rateCheck, error: rateError } = await supabase.rpc("consume_rate_limit", {
        p_bucket: "admin_whatsapp_test",
        p_key: user.id,
        p_capacity: 10,
        p_refill_per_minute: 2.0,
      });
      if (rateError || !rateCheck?.length) throw new Error("Rate limit unavailable");
      if (rateCheck && rateCheck.length > 0 && rateCheck[0]?.allowed === false) {
        return new Response(
          JSON.stringify({ error: "Rate limit exceeded for test sends. Please wait before retrying." }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 429,
          },
        );
      }
    } catch (_) {
      return new Response(JSON.stringify({ error: "Management rate limit unavailable" }),
        { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const body = await req.json();
    const action = body.action || "test";
    if (!["test", "probe", "qr", "logout"].includes(action)) return new Response(
      JSON.stringify({ error: "unsupported_action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });

    if (action === "probe") {
      const { profile_id } = body;
      if (!profile_id) {
        return new Response(JSON.stringify({ error: "profile_id is required" }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 400,
        });
      }

      const { data: profile, error: pErr } = await supabase
        .from("whatsapp_provider_profiles")
        .select("*")
        .eq("id", profile_id)
        .single();

      if (pErr || !profile) {
        return new Response(JSON.stringify({ error: "Profile not found" }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 404,
        });
      }

      let isHealthy = false;
      let errorMessage: string | null = null;
      let metaPatch: Record<string, any> = {};

      const connMeta = profile.connection_metadata || {};
      const providerKind = profile.provider_kind || profile.provider_type;

      if (providerKind === "baileys") {
        const secret = await profileSecret(supabase, profile, "key");
        const endpoint = connMeta.endpoint_url;
        if (!endpoint || !secret) {
          errorMessage = "Selected profile endpoint or credential is missing";
        } else {
          try {
            const controller = new AbortController();
            const timeoutId = setTimeout(() => controller.abort(), 6000);
            const res = await fetch(`${endpoint.replace(/\/$/, "")}/health`, {
              headers: { "x-api-key": secret },
          signal: AbortSignal.timeout(10000),
              signal: controller.signal,
            });
            clearTimeout(timeoutId);

            if (!res.ok) {
              errorMessage = `Worker responded with HTTP ${res.status}`;
            } else {
              const data = await res.json();
              isHealthy = data.whatsapp === "connected";
              metaPatch = {
                observed_phone: data.phone || null,
                queue_length: data.queue_length ?? 0,
                uptime_seconds: data.uptime ?? null,
              };
              if (!isHealthy) {
                errorMessage = `Baileys status: ${data.whatsapp || 'disconnected'}`;
              }
            }
          } catch (e: any) {
            errorMessage = e.name === "AbortError" ? "Worker health check timed out" : (e.message || "Failed to reach worker");
          }
        }
      } else if (providerKind === "meta_cloud") {
        const token = await profileSecret(supabase, profile, "token");
        const phoneNumberId = connMeta.phone_number_id;
        if (!token || !phoneNumberId) {
          errorMessage = "Meta Cloud API credentials or phone number ID missing";
        } else {
          try {
            const controller = new AbortController();
            const timeoutId = setTimeout(() => controller.abort(), 6000);
            const res = await fetch(
              `https://graph.facebook.com/v26.0/${phoneNumberId}?fields=verified_name,code_verification_status,display_phone_number,quality_rating`,
              {
                headers: { Authorization: `Bearer ${token}` },
                signal: controller.signal,
              },
            );
            clearTimeout(timeoutId);

            const data = await res.json();
            if (!res.ok || data.error) {
              errorMessage = data.error?.message || `Meta Graph API HTTP ${res.status}`;
            } else {
              isHealthy = true;
              metaPatch = {
                observed_phone: data.display_phone_number || null,
                verified_name: data.verified_name || null,
                code_verification_status: data.code_verification_status || null,
                quality_rating: data.quality_rating || null,
              };
            }
          } catch (e: any) {
            errorMessage = e.name === "AbortError" ? "Meta API request timed out" : (e.message || "Failed to reach Meta API");
          }
        }
      }

      const observed = String(metaPatch.observed_phone || "").replace(/\D/g, "");
      if (isHealthy && providerKind === "meta_cloud" && !await profileSecret(supabase, profile, "app_secret")) {
        isHealthy = false;
        errorMessage = "Configure the Meta App Secret in this profile to authenticate delivery webhooks.";
      }
      const expected = String(profile.expected_sender_number || "").replace(/\D/g, "");
      if (isHealthy && (!expected || observed !== expected)) {
        isHealthy = false;
        errorMessage = "Connected sender does not match this profile's expected sender.";
      }
      const { error: recordError } = await caller.rpc("admin_record_whatsapp_probe", {
        p_profile_id: profile_id,
        p_observed_sender: metaPatch.observed_phone || null,
        p_ready_state: isHealthy ? "ready" : "degraded",
        p_error_category: isHealthy ? null : "connection_failure",
        p_error_detail: errorMessage,
        p_metadata_patch: metaPatch,
      });
      if (recordError) throw new Error("Could not save the provider probe result.");

      return new Response(
        JSON.stringify({
          success: true,
          is_healthy: isHealthy,
          error_message: errorMessage,
          metadata: metaPatch,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (action === "qr") {
      const { profile_id } = body;
      if (!profile_id) {
        return new Response(JSON.stringify({ error: "profile_id is required" }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 400,
        });
      }

      const { data: profile, error: pErr } = await supabase
        .from("whatsapp_provider_profiles")
        .select("*")
        .eq("id", profile_id)
        .single();

      const connMeta = profile?.connection_metadata || {};
      const providerKind = profile?.provider_kind || profile?.provider_type;

      if (pErr || !profile || providerKind !== "baileys") {
        return new Response(
          JSON.stringify({ error: "QR action is only available for Baileys profiles" }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 },
        );
      }

      const secret = await profileSecret(supabase, profile, "key");
      const endpoint = connMeta.endpoint_url;
      if (!endpoint || !secret) {
        return new Response(
          JSON.stringify({ error: "Baileys endpoint URL not configured" }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 },
        );
      }

      try {
        const res = await fetch(`${endpoint.replace(/\/$/, "")}/qr`, {
          headers: { "x-api-key": secret },
          signal: AbortSignal.timeout(10000),
        });
        const qrData = await res.json();
        return new Response(JSON.stringify(qrData), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: res.status,
        });
      } catch (e: any) {
        return new Response(
          JSON.stringify({ error: `Failed to contact Baileys worker: ${e.message}` }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 502 },
        );
      }
    }

    if (action === "logout") {
      const { profile_id } = body;
      if (!profile_id) {
        return new Response(JSON.stringify({ error: "profile_id is required" }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 400,
        });
      }

      const { data: profile, error: pErr } = await supabase
        .from("whatsapp_provider_profiles")
        .select("*")
        .eq("id", profile_id)
        .single();

      const connMeta = profile?.connection_metadata || {};
      const providerKind = profile?.provider_kind || profile?.provider_type;

      if (pErr || !profile || providerKind !== "baileys") {
        return new Response(
          JSON.stringify({ error: "Logout action is only available for Baileys profiles" }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 },
        );
      }

      const secret = await profileSecret(supabase, profile, "key");
      const endpoint = connMeta.endpoint_url;
      if (!endpoint || !secret) {
        return new Response(
          JSON.stringify({ error: "Baileys endpoint URL not configured" }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 },
        );
      }

      try {
        const res = await fetch(`${endpoint.replace(/\/$/, "")}/logout`, {
          method: "POST",
          headers: { "x-api-key": secret },
          signal: AbortSignal.timeout(10000),
        });
        const logoutData = await res.json();
        if (!res.ok) return new Response(JSON.stringify(logoutData), {
          headers: { ...corsHeaders, "Content-Type": "application/json" }, status: res.status,
        });
        const { error: recordError } = await caller.rpc("admin_record_whatsapp_probe", {
          p_profile_id: profile_id,
          p_observed_sender: null,
          p_ready_state: "unconfigured",
          p_error_category: "admin_logout",
          p_error_detail: "Logged out by administrator",
          p_metadata_patch: { observed_phone: null },
        });
        if (recordError) throw new Error("Could not save provider logout state.");
        return new Response(JSON.stringify(logoutData), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: res.status,
        });
      } catch (e: any) {
        return new Response(
          JSON.stringify({ error: `Failed to contact Baileys worker: ${e.message}` }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 502 },
        );
      }
    }

    // Default Action: Test Send
    const { phone, message, templateName, templateLanguage } = body;

    if (!phone) {
      return new Response(JSON.stringify({ error: "phone is required for test send" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      });
    }

    // 4. Dispatch via Central WhatsApp Router with purpose: admin_test
    const outcome = await routeAndSendWhatsApp(supabase, {
      purpose: "admin_test",
      recipientPhone: phone,
      bodyText: message || "KeepSIMs Admin Test Message",
      templateName,
      templateLanguage,
      userId: user.id,
    });

    return new Response(
      JSON.stringify({
        success: outcome.success,
        state: outcome.state,
        detail: outcome.detail,
        attempt_id: outcome.attemptId,
        provider: outcome.provider,
        country_id: outcome.countryId,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: outcome.success ? 200 : (outcome.state === "skipped" ? 422 : 502),
      },
    );
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500,
    });
  }
});
