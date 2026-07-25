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

    const body = await req.json();
    const orderId = body.order_id;

    if (!orderId) {
      return new Response(
        JSON.stringify({ success: false, error: "BAD_REQUEST: Missing order_id" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Ownership Check via paypal_orders
    const { data: existingOrder } = await adminClient
      .from("paypal_orders")
      .select("*")
      .eq("order_id", orderId)
      .maybeSingle();

    if (existingOrder && existingOrder.user_id !== user.id) {
      return new Response(
        JSON.stringify({ success: false, error: "FORBIDDEN: Order does not belong to caller" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // If order is already captured in paypal_orders, return idempotent success
    if (existingOrder && existingOrder.status === "captured") {
      return new Response(
        JSON.stringify({ success: true, order_id: orderId, status: "captured", message: "ORDER_ALREADY_CAPTURED" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. Call PayPal REST API to Capture Order
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

    const isAlreadyCaptured =
      resText.includes("ORDER_ALREADY_CAPTURED") ||
      resText.includes("ORDER_ALREADY_COMPLETED") ||
      resData.name === "UNPROCESSABLE_ENTITY";

    if (!captureRes.ok && !isAlreadyCaptured) {
      console.error(`PayPal capture failed for order ${orderId}:`, resText);
      return new Response(
        JSON.stringify({ success: false, error: `PayPal capture failed (${captureRes.status}): ${resText}` }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Update paypal_orders status
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
