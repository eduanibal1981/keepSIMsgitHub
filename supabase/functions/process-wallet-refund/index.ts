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

    // 1. Verify caller (Admin or Service Role or owner)
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
    const refundRequestId = body.refund_request_id;

    if (!refundRequestId) {
      return new Response(
        JSON.stringify({ success: false, error: "BAD_REQUEST: Missing refund_request_id" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Fetch refund request and its items
    const { data: request, error: reqErr } = await adminClient
      .from("wallet_refund_requests")
      .select("*")
      .eq("id", refundRequestId)
      .single();

    if (reqErr || !request) {
      return new Response(
        JSON.stringify({ success: false, error: "NOT_FOUND: Refund request not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Check ownership or admin role
    const isOwner = request.user_id === user.id;
    const isPowerUser = user.app_metadata?.is_power_user === true;

    if (!isOwner && !isPowerUser) {
      return new Response(
        JSON.stringify({ success: false, error: "FORBIDDEN: Not authorized to process this refund" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data: items, error: itemsErr } = await adminClient
      .from("wallet_refund_items")
      .select("*")
      .eq("refund_request_id", refundRequestId)
      .eq("status", "pending");

    if (itemsErr || !items || items.length === 0) {
      return new Response(
        JSON.stringify({ success: true, message: "No pending refund items to process", request_status: request.status }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. Obtain PayPal access token
    const paypalClientId = Deno.env.get("PAYPAL_CLIENT_ID")!;
    const paypalClientSecret = Deno.env.get("PAYPAL_CLIENT_SECRET")!;
    const paypalApiBase = Deno.env.get("PAYPAL_API_BASE") || "https://api-m.sandbox.paypal.com";

    const accessToken = await getPayPalAccessToken(paypalApiBase, paypalClientId, paypalClientSecret);

    let processedCount = 0;
    let failedCount = 0;

    for (const item of items) {
      // Mark processing
      await adminClient
        .from("wallet_refund_items")
        .update({ status: "processing", updated_at: new Date().toISOString() })
        .eq("id", item.id);

      try {
        const refundRes = await fetch(`${paypalApiBase}/v2/payments/captures/${item.capture_id}/refund`, {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${accessToken}`,
            "Content-Type": "application/json",
            "PayPal-Request-Id": item.idempotency_key,
          },
          body: JSON.stringify({
            amount: {
              value: Number(item.amount).toFixed(2),
              currency_code: item.currency || "USD",
            },
            note_to_payer: "KeepSIMs unused wallet funds refund",
          }),
        });

        const resText = await refundRes.text();
        let resData: any = {};
        try {
          resData = JSON.parse(resText);
        } catch (_) {}

        if (refundRes.ok && (resData.status === "COMPLETED" || resData.status === "PENDING")) {
          // Success: Update item to completed
          await adminClient
            .from("wallet_refund_items")
            .update({
              status: "completed",
              provider_refund_id: resData.id,
              completed_at: new Date().toISOString(),
              updated_at: new Date().toISOString(),
            })
            .eq("id", item.id);

          // Update lot remaining_amount
          const { data: lot } = await adminClient
            .from("wallet_funding_lots")
            .select("remaining_amount")
            .eq("id", item.lot_id)
            .single();

          if (lot) {
            const newRemaining = Math.max(0, Number(lot.remaining_amount) - Number(item.amount));
            await adminClient
              .from("wallet_funding_lots")
              .update({
                remaining_amount: newRemaining,
                status: newRemaining === 0 ? "fully_refunded" : "partially_refunded",
                updated_at: new Date().toISOString(),
              })
              .eq("id", item.lot_id);
          }

          // Debit the wallet balance for the refund payout
          const { data: wallet } = await adminClient
            .from("wallets")
            .select("balance")
            .eq("id", request.wallet_id)
            .single();

          if (wallet) {
            const newBal = Math.max(0, Number(wallet.balance) - Number(item.amount));
            await adminClient
              .from("wallets")
              .update({
                balance: newBal,
                updated_at: new Date().toISOString(),
              })
              .eq("id", request.wallet_id);

            // Insert completed ledger transaction
            await adminClient
              .from("wallet_transactions")
              .insert({
                wallet_id: request.wallet_id,
                user_id: request.user_id,
                type: "refund_payout",
                amount: Number(item.amount),
                balance_before: Number(wallet.balance),
                balance_after: newBal,
                description: `Refund payout to PayPal capture ${item.capture_id}`,
                reference_id: `refund_${item.id}`,
                status: "completed",
                metadata: {
                  refund_request_id: request.id,
                  refund_item_id: item.id,
                  paypal_refund_id: resData.id,
                  capture_id: item.capture_id,
                },
              });
          }

          processedCount++;
        } else {
          console.error(`PayPal refund error for capture ${item.capture_id}:`, resText);
          const failureMsg = resData.details?.[0]?.description || resData.message || `HTTP ${refundRes.status}`;
          
          await adminClient
            .from("wallet_refund_items")
            .update({
              status: "failed",
              failure_reason: failureMsg,
              updated_at: new Date().toISOString(),
            })
            .eq("id", item.id);

          failedCount++;
        }
      } catch (err: any) {
        console.error(`Exception refunding item ${item.id}:`, err);
        await adminClient
          .from("wallet_refund_items")
          .update({
            status: "failed",
            failure_reason: err.message,
            updated_at: new Date().toISOString(),
          })
          .eq("id", item.id);

        failedCount++;
      }
    }

    // 4. Update overall request status and release/capture hold
    const overallStatus = failedCount === 0 ? "completed" : (processedCount > 0 ? "partially_completed" : "failed");
    await adminClient
      .from("wallet_refund_requests")
      .update({
        status: overallStatus,
        updated_at: new Date().toISOString(),
      })
      .eq("id", refundRequestId);

    // If hold exists, mark hold captured or released
    if (request.hold_id) {
      if (overallStatus === "completed") {
        await adminClient
          .from("wallet_holds")
          .update({ status: "captured", captured_at: new Date().toISOString() })
          .eq("id", request.hold_id);
      } else if (overallStatus === "failed") {
        await adminClient
          .from("wallet_holds")
          .update({ status: "released", released_at: new Date().toISOString(), reason: "Refund failed by provider" })
          .eq("id", request.hold_id);
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        refund_request_id: refundRequestId,
        status: overallStatus,
        processed_count: processedCount,
        failed_count: failedCount,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    console.error("process-wallet-refund internal error:", err);
    return new Response(
      JSON.stringify({ success: false, error: err.message || "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
