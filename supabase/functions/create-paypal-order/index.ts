import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const PAYPAL_CLIENT_ID = Deno.env.get("PAYPAL_CLIENT_ID") ?? "";
const PAYPAL_CLIENT_SECRET = Deno.env.get("PAYPAL_CLIENT_SECRET") ?? "";
const PAYPAL_API_BASE = Deno.env.get("PAYPAL_API_BASE") ?? ("https://api-m." + "sandbox" + ".paypal.com");

async function getPayPalAccessToken(): Promise<string> {
  const res = await fetch(`${PAYPAL_API_BASE}/v1/oauth2/token`, {
    method: "POST",
    headers: {
      "Authorization": `Basic ${btoa(`${PAYPAL_CLIENT_ID}:${PAYPAL_CLIENT_SECRET}`)}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: "grant_type=client_credentials",
  });
  if (!res.ok) {
    throw new Error(`PayPal OAuth failed (${res.status}): ${await res.text()}`);
  }
  const data = await res.json();
  return data.access_token;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ success: false, error: "UNAUTHORIZED: Missing Authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const client = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const adminClient = createClient(supabaseUrl, supabaseServiceKey);

    const { data: { user }, error: userError } = await client.auth.getUser();
    if (userError || !user) {
      return new Response(
        JSON.stringify({ success: false, error: "UNAUTHORIZED: Invalid user token" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Rate limiting: D2 bucket paypal_order (10 requests per 60 mins per user)
    const { data: limitRes } = await adminClient.rpc("consume_rate_limit", {
      p_bucket: "paypal_order",
      p_key: user.id,
      p_capacity: 10,
      p_refill_per_minute: 10.0 / 60.0,
    });

    if (limitRes && Array.isArray(limitRes) && limitRes[0]?.allowed === false) {
      const retryAfter = limitRes[0]?.retry_after_seconds ?? 3600;
      return new Response(
        JSON.stringify({ success: false, code: "KS429", error: `RATE_LIMITED:paypal_order:${retryAfter}`, retry_after: retryAfter }),
        { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json", "Retry-After": String(retryAfter) } }
      );
    }

    const body = await req.json();
    const kind: string = body.kind ?? "deposit";
    const simLineId: string | null = body.sim_line_id ?? null;
    let amountUsd = 0.00;

    // Server-side pricing
    if (kind === "plan") {
      let planFee = 2.50;
      try {
        const { data: configRow } = await adminClient
          .from("system_configs")
          .select("config_value")
          .eq("config_key", "BASE_SERVICE_FEE_USD")
          .maybeSingle();
        if (configRow?.config_value) {
          planFee = Number(configRow.config_value) || 2.50;
        }
      } catch (_) {
        planFee = 2.50;
      }
      amountUsd = planFee;
    } else if (kind === "deposit") {
      const requestedAmt = Number(body.amount_usd);
      if (!Number.isFinite(requestedAmt) || requestedAmt < 1.00 || requestedAmt > 500.00) {
        return new Response(
          JSON.stringify({ success: false, error: "BAD_REQUEST: Deposit amount must be between $1.00 and $500.00" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      amountUsd = Math.round(requestedAmt * 100) / 100;
    } else {
      return new Response(
        JSON.stringify({ success: false, error: `BAD_REQUEST: Unsupported payment kind '${kind}'` }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!PAYPAL_CLIENT_ID || !PAYPAL_CLIENT_SECRET) {
      return new Response(
        JSON.stringify({ success: false, error: "INTERNAL_ERROR: PayPal credentials not configured" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const accessToken = await getPayPalAccessToken();
    const customId = JSON.stringify({ u: user.id, k: kind, l: simLineId ?? "" });

    const orderRes = await fetch(`${PAYPAL_API_BASE}/v2/checkout/orders`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        intent: "CAPTURE",
        purchase_units: [
          {
            amount: {
              currency_code: "USD",
              value: amountUsd.toFixed(2),
            },
            custom_id: customId,
          },
        ],
        application_context: {
          user_action: "PAY_NOW",
          return_url: "https://keepsims.com/paypal-return",
          cancel_url: "https://keepsims.com/paypal-cancel",
        },
      }),
    });

    if (!orderRes.ok) {
      const errText = await orderRes.text();
      return new Response(
        JSON.stringify({ success: false, error: `PayPal order creation failed: ${errText}` }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const orderData = await orderRes.json();
    const orderId = orderData.id;
    const approveLink = orderData.links?.find((l: any) => l.rel === "approve");
    const approveUrl = approveLink?.href ?? "";

    return new Response(
      JSON.stringify({
        success: true,
        order_id: orderId,
        approve_url: approveUrl,
        amount_usd: amountUsd,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ success: false, error: err.message || "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
