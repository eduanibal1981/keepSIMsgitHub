import { EndpointError } from "../_shared/endpoint-auth.ts";
import { paypalSession, capturePayPalOrder, fulfillPayPalCapture } from "../_shared/paypal-capture.ts";
import { ProviderConfigurationError } from "../_shared/provider-secrets.ts";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { APP_CHECK_HEADER, verifyAppCheckToken } from "./app_check.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-firebase-appcheck, x-keepsims-device",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const adminClient = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // 1. JWT Authentication Check
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ success: false, error: "UNAUTHORIZED: Missing Authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await adminClient.auth.getUser(token);

    if (authError || !user) {
      return new Response(
        JSON.stringify({ success: false, error: "UNAUTHORIZED: Invalid JWT token" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. D2 Rate Limiting (bucket: paypal_capture, capacity: 5) (BLOCKER 2 & 3)
    const { data: rateLimitResult, error: rateLimitErr } = await adminClient.rpc("consume_rate_limit", {
      p_bucket: "paypal_capture",
      p_key: user.id,
      p_capacity: 5,
      p_refill_per_minute: 5.0 / 60.0,
    });

    const rateLimitObj = Array.isArray(rateLimitResult) ? rateLimitResult[0] : rateLimitResult;

    if (rateLimitErr) {
      console.error("Rate limit check failed:", rateLimitErr);
    } else if (rateLimitObj && rateLimitObj.allowed === false) {
      const retryAfter = rateLimitObj.retry_after_seconds || 60;
      return new Response(
        JSON.stringify({
          success: false,
          code: "KS429",
          error: `RATE_LIMITED:paypal_capture:${retryAfter}`,
          retry_after: retryAfter,
        }),
        {
          status: 429,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
            "Retry-After": String(retryAfter),
          },
        }
      );
    }

    const body = await req.json();
    const orderId = body.order_id;

    // ── G10: App Check only ──────────────────────────────────────────────────
    // No device-risk assessment here on purpose. Capture carries no amount and
    // no new spending decision — the order it captures was already assessed at
    // creation time, and re-scoring the same money twice would double every
    // deposit in the velocity counters. Attestation, on the other hand, is worth
    // checking on every authenticated money call.
    const deviceId: string | null =
      (typeof body.device_id === "string" ? body.device_id : null) ??
      req.headers.get("x-keepsims-device");
    const platform: string | null =
      (typeof body.platform === "string" ? body.platform.toLowerCase() : null);

    const appCheck = await verifyAppCheckToken(req.headers.get(APP_CHECK_HEADER));
    await adminClient.rpc("log_app_check_result", {
      p_user_id: user.id,
      p_outcome: appCheck.outcome,
      p_device_id: deviceId,
      p_platform: platform,
      p_detail: appCheck.detail ?? null,
    });

    if (appCheck.outcome !== "pass") {
      const { data: mustEnforce } = await adminClient.rpc("app_check_should_enforce", {
        p_platform: platform,
      });
      if (mustEnforce === true) {
        return new Response(
          JSON.stringify({
            success: false,
            code: "APP_CHECK_FAILED",
            error: "This app installation could not be verified. Please update KeepSIMs from the Play Store and try again.",
          }),
          { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }
    }

    if (!orderId) {
      return new Response(
        JSON.stringify({ success: false, error: "BAD_REQUEST: Missing order_id" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. Ownership & Existence Check via paypal_orders (BLOCKER 2: Hard 404 on missing, 403 on foreign)
    const { data: existingOrder, error: orderError } = await adminClient
      .from("paypal_orders")
      .select("*")
      .eq("order_id", orderId)
      .maybeSingle();

    if (orderError) throw new EndpointError(503, "Order lookup unavailable");
    if (!existingOrder) {
      return new Response(
        JSON.stringify({ success: false, error: "NOT_FOUND: Order not found in local records" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (existingOrder.user_id !== user.id) {
      return new Response(
        JSON.stringify({ success: false, error: "FORBIDDEN: Order does not belong to caller" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const session = await paypalSession(adminClient);
    const evidence = await capturePayPalOrder(existingOrder, session);
    const fulfilled = await fulfillPayPalCapture(adminClient, evidence, "capture_endpoint");
    return new Response(JSON.stringify({ success: true, order_id: orderId,
      capture_id: evidence.capture_id, status: "captured", duplicate: fulfilled.duplicate }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err: any) {
    if (err instanceof EndpointError) return new Response(JSON.stringify({ success: false, error: err.message }), { status: err.status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    if (err instanceof ProviderConfigurationError) return new Response(JSON.stringify({ success: false, error: err.message, code: err.code }), { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    console.error("capture-paypal-order internal error:", err);
    return new Response(
      JSON.stringify({ success: false, error: err.message || "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
