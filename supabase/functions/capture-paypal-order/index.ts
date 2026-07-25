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

    if (!orderId) {
      return new Response(
        JSON.stringify({ success: false, error: "BAD_REQUEST: Missing order_id" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. Ownership & Existence Check via paypal_orders (BLOCKER 2: Hard 404 on missing, 403 on foreign)
    const { data: existingOrder } = await adminClient
      .from("paypal_orders")
      .select("*")
      .eq("order_id", orderId)
      .maybeSingle();

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

    // If order is already captured in paypal_orders, return idempotent success
    if (existingOrder.status === "captured") {
      return new Response(
        JSON.stringify({ success: true, order_id: orderId, status: "captured", message: "ORDER_ALREADY_CAPTURED" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 4. Call PayPal REST API to Capture Order
    const paypalClientId = Deno.env.get("PAYPAL_CLIENT_ID")!;
    const paypalClientSecret = Deno.env.get("PAYPAL_CLIENT_SECRET")!;
    const paypalApiBase = Deno.env.get("PAYPAL_API_BASE") || "https://api-m.sandbox.paypal.com";

    const accessToken = await getPayPalAccessToken(paypalApiBase, paypalClientId, paypalClientSecret);

    const captureRes = await fetch(`${paypalApiBase}/v2/checkout/orders/${orderId}/capture`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
    });

    const resText = await captureRes.text();
    let resData: any = {};
    try {
      resData = JSON.parse(resText);
    } catch (_) {}

    // Check for exact ORDER_ALREADY_CAPTURED issue
    const issueCode = resData.details?.[0]?.issue || resData.name || "";
    const isAlreadyCapturedIssue = issueCode === "ORDER_ALREADY_CAPTURED";
    const isCompleted = captureRes.ok && resData.status === "COMPLETED";

    // BLOCKER 1 Fix: Success requires captureRes.ok && COMPLETED, or explicit ORDER_ALREADY_CAPTURED
    if (!isCompleted && !isAlreadyCapturedIssue) {
      console.error(`PayPal capture failed for order ${orderId}:`, resText);

      // Update status to failed (NEVER mark captured from an error branch)
      await adminClient
        .from("paypal_orders")
        .update({ status: "failed" })
        .eq("order_id", orderId);

      const errDescription = resData.details?.[0]?.description || issueCode || `HTTP ${captureRes.status}`;
      return new Response(
        JSON.stringify({
          success: false,
          error: `PAYPAL_CAPTURE_FAILED:${issueCode}`,
          description: errDescription,
          raw: resData,
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Success path: Update paypal_orders status to captured
    await adminClient
      .from("paypal_orders")
      .update({
        status: "captured",
        captured_at: new Date().toISOString(),
      })
      .eq("order_id", orderId);

    return new Response(
      JSON.stringify({ success: true, order_id: orderId, status: "captured" }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    console.error("capture-paypal-order internal error:", err);
    return new Response(
      JSON.stringify({ success: false, error: err.message || "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
