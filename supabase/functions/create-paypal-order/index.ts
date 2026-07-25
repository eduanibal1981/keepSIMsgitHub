import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
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

    // 2. D2 Rate Limiting: paypal_order bucket (10 requests / 60 minutes)
    const { data: rateLimitResult, error: rateLimitErr } = await adminClient.rpc("consume_rate_limit", {
      p_bucket: "paypal_order",
      p_key: userId,
      p_capacity: 10,
      p_refill_per_minute: 0.1667,
    });

    if (rateLimitErr) {
      console.error("Rate limit check failed:", rateLimitErr);
    } else if (rateLimitResult && rateLimitResult.allowed === false) {
      return new Response(
        JSON.stringify({
          success: false,
          error: `RATE_LIMITED:paypal_order:${rateLimitResult.retry_after_seconds || 60}`,
          retry_after: rateLimitResult.retry_after_seconds || 60,
        }),
        {
          status: 429,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
            "Retry-After": String(rateLimitResult.retry_after_seconds || 60),
          },
        }
      );
    }

    const body = await req.json();
    const kind = body.kind || "deposit";
    const plan = body.plan;
    const simLineId = body.sim_line_id;

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

    // 3. Obtain PayPal Access Token
    const paypalClientId = Deno.env.get("PAYPAL_CLIENT_ID")!;
    const paypalClientSecret = Deno.env.get("PAYPAL_CLIENT_SECRET")!;
    const paypalApiBase = Deno.env.get("PAYPAL_API_BASE") || "https://api-m.sandbox.paypal.com";

    const accessToken = await getPayPalAccessToken(paypalApiBase, paypalClientId, paypalClientSecret);

    // 4. Create PayPal Order via PayPal REST API
    const customIdObj: Record<string, any> = { u: userId, k: kind };
    if (plan) customIdObj.p = plan;
    if (simLineId) customIdObj.l = simLineId;

    const returnUrl = Deno.env.get("PAYPAL_RETURN_URL") || "https://keepsims.com/paypal-return";
    const cancelUrl = Deno.env.get("PAYPAL_CANCEL_URL") || "https://keepsims.com/paypal-cancel";

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

    // 5. Insert order into paypal_orders table (BLOCKER 2 order-of-record)
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
