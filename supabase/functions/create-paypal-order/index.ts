import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { APP_CHECK_HEADER, verifyAppCheckToken } from "./app_check.ts";

// G10: the two new headers must be listed here or a browser preflight strips
// them before they ever reach this function. Mobile has no preflight, but the
// Flutter web target (feature #8) would break silently without this.
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-firebase-appcheck, x-keepsims-device",
};

async function getPayPalAccessToken(apiBase: string, clientId: string, clientSecret: string): Promise<string> {
  const auth = btoa(`${clientId}:${clientSecret}`);
  const response = await fetch(`${apiBase}/v1/oauth2/token`, {
    method: "POST",
    headers: {
      "Authorization": `Basic ${auth}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: "grant_type=client_credentials",
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Failed to obtain PayPal access token (${response.status}): ${errorText}`);
  }

  const data = await response.json();
  return data.access_token;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const adminClient = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // 1. JWT & Authentication Check
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

    const userId = user.id;

    // 2. D2 Rate Limiting: paypal_order bucket (10 requests / 60 minutes) (BLOCKER 3 array fix)
    const { data: rateLimitResult, error: rateLimitErr } = await adminClient.rpc("consume_rate_limit", {
      p_bucket: "paypal_order",
      p_key: userId,
      p_capacity: 10,
      p_refill_per_minute: 0.1667,
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
          error: `RATE_LIMITED:paypal_order:${retryAfter}`,
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
    const kind = body.kind || "deposit";
    const plan = body.plan;
    const simLineId = body.sim_line_id;

    // ── G10: device identity + App Check ─────────────────────────────────────
    // Both are claims from the client. The device id is scored, never trusted;
    // the App Check token is cryptographically verified before it counts for
    // anything, and enforcement is a database flag rather than a deploy.
    const deviceId: string | null =
      (typeof body.device_id === "string" ? body.device_id : null) ??
      req.headers.get("x-keepsims-device");
    const platform: string | null =
      (typeof body.platform === "string" ? body.platform.toLowerCase() : null);

    const appCheck = await verifyAppCheckToken(req.headers.get(APP_CHECK_HEADER));
    await adminClient.rpc("log_app_check_result", {
      p_user_id: userId,
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

    let finalAmountUsd = 0;

    if (kind === "plan") {
      if (!plan || (plan !== "standard" && plan !== "premium")) {
        return new Response(
          JSON.stringify({ success: false, error: "BAD_REQUEST: Invalid plan type" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Server-side plan quote (BLOCKER 1 fix: NEVER accept client amount for plans)
      const { data: quotedPrice, error: quoteErr } = await adminClient.rpc("quote_plan_price", {
        p_sim_line_id: simLineId || null,
        p_plan: plan,
        p_gateway: "paypal",
      });

      if (quoteErr || !quotedPrice) {
        console.error("quote_plan_price failed:", quoteErr);
        return new Response(
          JSON.stringify({ success: false, error: "FAILED: Unable to calculate plan price" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      finalAmountUsd = Number(quotedPrice);
    } else {
      // Deposit path
      const requestedAmount = Number(body.amount_usd);

      // Read min / max deposit bounds from system_configs
      const { data: minConfig } = await adminClient
        .from("system_configs")
        .select("config_value")
        .eq("config_key", "PAYPAL_MIN_DEPOSIT_USD")
        .maybeSingle();

      const { data: maxConfig } = await adminClient
        .from("system_configs")
        .select("config_value")
        .eq("config_key", "PAYPAL_MAX_DEPOSIT_USD")
        .maybeSingle();

      const minDeposit = Number(minConfig?.config_value || 1.00);
      const maxDeposit = Number(maxConfig?.config_value || 500.00);

      if (isNaN(requestedAmount) || requestedAmount < minDeposit || requestedAmount > maxDeposit) {
        return new Response(
          JSON.stringify({
            success: false,
            error: `BAD_REQUEST: Deposit amount must be between $${minDeposit.toFixed(2)} and $${maxDeposit.toFixed(2)}`,
          }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      finalAmountUsd = Number(requestedAmount.toFixed(2));
    }

    // ── G10: device risk, last checkpoint before an order exists at PayPal ───
    // Assessed here rather than at capture time because this is the only point
    // in the deposit pipeline where a device is present at all: capture is a
    // client call with no amount context and paypal-webhook is PayPal talking to
    // us. The returned event id is stitched to the PayPal order id below, which
    // is what lets `device_velocity` count failed captures per device later.
    let deviceEventId: string | null = null;
    {
      const { data: guard, error: guardErr } = await adminClient.rpc("guard_money_action", {
        p_action: "deposit_order",
        p_amount_usd: finalAmountUsd,
        p_device_id: deviceId,
        p_reference_id: null,
        p_user_id: userId,
      });

      if (guardErr) {
        // A broken guard must not become a way to take money without one.
        console.error("guard_money_action failed:", guardErr);
        return new Response(
          JSON.stringify({ success: false, error: "FAILED: risk check unavailable, please try again" }),
          { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      deviceEventId = guard?.event_id ?? null;

      if (guard?.blocked === true) {
        return new Response(
          JSON.stringify({
            success: false,
            code: "DEVICE_BLOCKED",
            reason: guard?.reason ?? null,
            error: "This payment was stopped by a security check on this device. Contact support if this is a mistake.",
          }),
          { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }
    }

    // 3. Obtain PayPal Access Token
    const paypalClientId = Deno.env.get("PAYPAL_CLIENT_ID")!;
    const paypalClientSecret = Deno.env.get("PAYPAL_CLIENT_SECRET")!;
    const paypalApiBase = Deno.env.get("PAYPAL_API_BASE") || "https://api-m.sandbox.paypal.com";

    const accessToken = await getPayPalAccessToken(paypalApiBase, paypalClientId, paypalClientSecret);

    // 4. Create PayPal Order via PayPal REST API
    const customIdObj: Record<string, any> = { u: userId, k: kind };
    if (plan) customIdObj.p = plan;
    if (simLineId) customIdObj.l = simLineId;

    // Both URLs default to the paypal-return function in this same project, so
    // the return path works without a marketing-site deploy or an extra secret.
    // That page bounces the browser into io.supabase.keepsims://payment-success,
    // which is what actually closes the Custom Tab and wakes the checkout screen.
    const returnFnUrl = `${Deno.env.get("SUPABASE_URL")}/functions/v1/paypal-return`;
    const returnUrl = Deno.env.get("PAYPAL_RETURN_URL") || returnFnUrl;
    const cancelUrl = Deno.env.get("PAYPAL_CANCEL_URL") || `${returnFnUrl}?ks_cancel=1`;

    const paypalOrderReq = {
      intent: "CAPTURE",
      purchase_units: [
        {
          amount: {
            currency_code: "USD",
            value: finalAmountUsd.toFixed(2),
          },
          custom_id: JSON.stringify(customIdObj),
          description: kind === "plan" ? `KeepSIMs ${plan} Plan` : "KeepSIMs Wallet Refill",
        },
      ],
      application_context: {
        brand_name: "KeepSIMs",
        landing_page: "NO_PREFERENCE",
        user_action: "PAY_NOW",
        return_url: returnUrl,
        cancel_url: cancelUrl,
      },
    };

    const createRes = await fetch(`${paypalApiBase}/v2/checkout/orders`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(paypalOrderReq),
    });

    if (!createRes.ok) {
      const errText = await createRes.text();
      console.error("PayPal order creation failed:", errText);
      return new Response(
        JSON.stringify({ success: false, error: `PayPal order creation failed (${createRes.status}): ${errText}` }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const orderData = await createRes.json();
    const orderId = orderData.id;
    const approveLink = orderData.links?.find((l: any) => l.rel === "approve")?.href;

    if (!orderId || !approveLink) {
      return new Response(
        JSON.stringify({ success: false, error: "FAILED: Missing approval link from PayPal" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 5. Insert order into paypal_orders table (BLOCKER 2: Insert failure is FATAL)
    const { error: insertOrderErr } = await adminClient.from("paypal_orders").insert({
      order_id: orderId,
      user_id: userId,
      kind: kind,
      plan: plan || null,
      sim_line_id: simLineId || null,
      amount_usd: finalAmountUsd,
      status: "created",
    });

    if (insertOrderErr) {
      console.error("Failed to insert paypal_orders row:", insertOrderErr);
      return new Response(
        JSON.stringify({ success: false, error: `FAILED: Local order record creation failed (${insertOrderErr.message})` }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // G10: bind the attempt to the order. Write-once server side, and
    // best-effort here: losing the link costs one velocity signal, and failing
    // the deposit over it would be a worse trade.
    if (deviceEventId) {
      const { error: attachErr } = await adminClient.rpc("attach_device_money_reference", {
        p_event_id: deviceEventId,
        p_reference_id: orderId,
      });
      if (attachErr) console.error("attach_device_money_reference failed:", attachErr);
    }

    return new Response(
      JSON.stringify({
        success: true,
        order_id: orderId,
        approval_url: approveLink,
        amount_usd: finalAmountUsd,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    console.error("create-paypal-order internal error:", err);
    return new Response(
      JSON.stringify({ success: false, error: err.message || "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
