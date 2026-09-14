import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

async function fetchConfig(supabase: any, key: string, fallback: string = ""): Promise<string> {
  const envVal = Deno.env.get(key);
  if (envVal) return envVal;
  try {
    const { data } = await supabase
      .from("system_configs")
      .select("config_value")
      .eq("config_key", key)
      .maybeSingle();
    return data?.config_value || fallback;
  } catch (_) {
    return fallback;
  }
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. Authenticate the caller
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 401,
      });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const jwt = authHeader.replace(/^Bearer\s+/i, "");
    const { data: { user }, error: authErr } = await supabase.auth.getUser(jwt);

    if (authErr || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 401,
      });
    }

    const body = await req.json();
    const { action } = body;

    // ── NEW SECURE ACTION: START ──
    if (action === "start") {
      const { simLineId, method, idempotencyKey } = body;
      if (!simLineId || !method) {
        return new Response(JSON.stringify({ error: "Missing simLineId or method" }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 400,
        });
      }

      let normalizedMethod = method;
      if (normalizedMethod === "missed_call" || normalizedMethod === "call") {
        normalizedMethod = "voice";
      }

      if (normalizedMethod !== "sms" && normalizedMethod !== "voice") {
        return new Response(JSON.stringify({ error: "Method must be 'sms' or 'voice'" }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 400,
        });
      }

      // Check idempotency if key provided
      if (idempotencyKey) {
        const { data: existingAttempt } = await supabase
          .from("line_verification_attempts")
          .select("*")
          .eq("user_id", user.id)
          .eq("idempotency_key", idempotencyKey)
          .maybeSingle();

        if (existingAttempt) {
          return new Response(JSON.stringify({
            success: true,
            attemptId: existingAttempt.id,
            status: existingAttempt.status,
            outcome: existingAttempt.outcome,
            settlementStatus: existingAttempt.settlement_status,
          }), {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 200,
          });
        }
      }

      // 1. Get Quote from Database
      const { data: quote, error: quoteErr } = await supabase.rpc("quote_line_verification", {
        p_sim_line_id: simLineId,
        p_user_id: user.id,
      });

      if (quoteErr || !quote) {
        return new Response(JSON.stringify({ error: quoteErr?.message || "Failed to generate quote" }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 400,
        });
      }

      // If an unresolved attempt is already in flight, return it
      if (quote.in_flight_attempt_id) {
        return new Response(JSON.stringify({
          success: true,
          attemptId: quote.in_flight_attempt_id,
          status: "pending",
          message: "Verification already in progress",
        }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        });
      }

      const cost = normalizedMethod === "sms" ? Number(quote.sms_verify_cost_usd) : Number(quote.call_verify_cost_usd);
      let fundingKind = "wallet";
      let effectivePrice = cost;

      if (quote.has_annual_allowance) {
        fundingKind = "annual_allowance";
        effectivePrice = 0.00;
      } else if (cost <= 0) {
        fundingKind = "country_zero";
        effectivePrice = 0.00;
      } else {
        if (Number(quote.wallet_available_usd) < cost) {
          return new Response(JSON.stringify({ error: "Insufficient available wallet balance" }), {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 402,
          });
        }
      }

      const attemptId = crypto.randomUUID();
      let walletHoldId: string | null = null;

      // 2. Reserve Funds or Allowance
      if (fundingKind === "wallet") {
        const { data: holdId, error: holdErr } = await supabase.rpc("reserve_wallet_funds", {
          p_user_id: user.id,
          p_order_type: "line_verification",
          p_order_reference_id: attemptId,
          p_amount: cost,
          p_reason: `Real Live Verification (${normalizedMethod.toUpperCase()})`,
          p_ttl_minutes: 60,
        });

        if (holdErr || !holdId) {
          return new Response(JSON.stringify({ error: holdErr?.message || "Failed to reserve wallet funds" }), {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 400,
          });
        }
        walletHoldId = holdId;
      } else if (fundingKind === "annual_allowance") {
        await supabase
          .from("line_verification_allowances")
          .update({
            reserved_attempt_id: attemptId,
            updated_at: new Date().toISOString(),
          })
          .eq("sim_line_id", simLineId)
          .is("consumed_attempt_id", null);
      }

      // 3. Record Attempt
      const { error: insertErr } = await supabase
        .from("line_verification_attempts")
        .insert({
          id: attemptId,
          sim_line_id: simLineId,
          user_id: user.id,
          method: normalizedMethod,
          destination_phone: quote.phone_number,
          country_id: quote.country_id,
          retail_price: effectivePrice,
          funding_kind: fundingKind,
          wallet_hold_id: walletHoldId,
          status: "dispatching",
          outcome: "pending",
          settlement_status: "reserved",
          price_version: quote.price_version,
          idempotency_key: idempotencyKey || null,
        });

      if (insertErr) {
        // Rollback hold
        if (walletHoldId) {
          await supabase.rpc("release_wallet_hold", { p_hold_id: walletHoldId, p_reason: "Failed to record attempt" });
        }
        return new Response(JSON.stringify({ error: insertErr.message }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 500,
        });
      }

      // 4. Dispatch Telephony Call or SMS
      const webhookUrl = `${SUPABASE_URL}/functions/v1/liveness-verification-webhook`;

      if (normalizedMethod === "voice") {
        const telnyxApiKey = await fetchConfig(supabase, "TELNYX_API_KEY", "KEY01A049E00656B79B4314CFFBC7969C10_k9JM7HV9u4sB2MadneUT1M");
        const telnyxAppId = await fetchConfig(supabase, "TELNYX_CALL_CONTROL_APP_ID", "3036680705380714233");
        const defaultCallerId = (await fetchConfig(supabase, "TELNYX_DEFAULT_CALLER_ID", "+17543180369")) || "+17543180369";

        if (!telnyxApiKey || !telnyxAppId) {
          await supabase.rpc("settle_line_verification_attempt", {
            p_attempt_id: attemptId,
            p_outcome: "failed",
            p_error_message: "Telnyx Voice gateway is not configured",
          });
          return new Response(JSON.stringify({ error: "Telnyx voice gateway not configured" }), {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 500,
          });
        }

        const cleanDest = quote.phone_number.replace(/\s+/g, "");
        const clientState = btoa(JSON.stringify({
          attemptId: attemptId,
          simLineId: simLineId,
          method: "voice",
        }));

        const resp = await fetch("https://api.telnyx.com/v2/calls", {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${telnyxApiKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            connection_id: telnyxAppId,
            to: cleanDest,
            from: defaultCallerId,
            client_state: clientState,
            webhook_url: webhookUrl,
            timeout_secs: 30,
            send_ringing_webhook: true,
          }),
        });

        if (resp.ok || resp.status === 201) {
          const telnyxData = await resp.json();
          const callControlId = telnyxData?.data?.call_control_id || telnyxData?.data?.call_leg_id;

          await supabase
            .from("line_verification_attempts")
            .update({
              status: "pending",
              provider: "telnyx",
              provider_resource_id: callControlId,
              dispatched_at: new Date().toISOString(),
            })
            .eq("id", attemptId);

          return new Response(JSON.stringify({
            success: true,
            attemptId,
            status: "pending",
            method: "voice",
            resourceId: callControlId,
          }), {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 200,
          });
        } else {
          const errText = await resp.text();
          await supabase.rpc("settle_line_verification_attempt", {
            p_attempt_id: attemptId,
            p_outcome: "failed",
            p_error_message: `Telnyx call dispatch failed: ${errText}`,
          });
          return new Response(JSON.stringify({ error: "Telnyx call dispatch failed", details: errText }), {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 502,
          });
        }
      } else {
        // SMS method (Telnyx)
        const telnyxApiKey = await fetchConfig(supabase, "TELNYX_API_KEY", "KEY01A049E00656B79B4314CFFBC7969C10_k9JM7HV9u4sB2MadneUT1M");
        const telnyxProfileId = (await fetchConfig(supabase, "TELNYX_MESSAGING_PROFILE_ID", "4001a054-0cfd-45aa-aed2-dd83279e7777")) || "4001a054-0cfd-45aa-aed2-dd83279e7777";

        if (!telnyxApiKey) {
          await supabase.rpc("settle_line_verification_attempt", {
            p_attempt_id: attemptId,
            p_outcome: "failed",
            p_error_message: "Telnyx SMS gateway is not configured",
          });
          return new Response(JSON.stringify({ error: "Telnyx gateway not configured" }), {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 500,
          });
        }

        const resp = await fetch("https://api.telnyx.com/v2/messages", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${telnyxApiKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            from: "KeepSIMs",
            to: quote.phone_number.replace(/\s+/g, ""),
            text: "KeepSIMs line verification handshake: SIM Line confirmed active.",
            messaging_profile_id: telnyxProfileId,
            webhook_url: webhookUrl,
          }),
        });

        if (resp.ok || resp.status === 201) {
          const telnyxData = await resp.json();
          const messageId = telnyxData?.data?.id;

          await supabase
            .from("line_verification_attempts")
            .update({
              status: "pending",
              provider: "telnyx",
              provider_resource_id: messageId,
              dispatched_at: new Date().toISOString(),
            })
            .eq("id", attemptId);

          return new Response(JSON.stringify({
            success: true,
            attemptId,
            status: "pending",
            method: "sms",
            resourceId: messageId,
          }), {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 200,
          });
        } else {
          const errText = await resp.text();
          await supabase.rpc("settle_line_verification_attempt", {
            p_attempt_id: attemptId,
            p_outcome: "failed",
            p_error_message: `Telnyx SMS dispatch failed: ${errText}`,
          });
          return new Response(JSON.stringify({ error: "Telnyx SMS dispatch failed" }), {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 502,
          });
        }
      }
    }

    // ── NEW SECURE ACTION: STATUS ──
    if (action === "status") {
      const { attemptId } = body;
      if (!attemptId) {
        return new Response(JSON.stringify({ error: "Missing attemptId" }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 400,
        });
      }

      const { data: attempt, error: attemptErr } = await supabase
        .from("line_verification_attempts")
        .select("*")
        .eq("id", attemptId)
        .eq("user_id", user.id)
        .maybeSingle();

      if (attemptErr || !attempt) {
        return new Response(JSON.stringify({ error: "Attempt not found" }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 404,
        });
      }

      return new Response(JSON.stringify({
        success: true,
        attemptId: attempt.id,
        status: attempt.status,
        outcome: attempt.outcome,
        isSuccess: attempt.outcome === "succeeded",
        carrierName: attempt.carrier_name,
        carrier_name: attempt.carrier_name,
        errorMessage: attempt.error_message,
        error_message: attempt.error_message,
        settlementStatus: attempt.settlement_status,
        completedAt: attempt.completed_at,
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      });
    }

    // ── Cancel In-Flight Call (Telnyx / Twilio) ──
    if (action === "twilio_cancel_call" || action === "cancel_call") {
      const callSid = body.callSid || body.callControlId || body.resourceId;
      if (!callSid) {
        return new Response(JSON.stringify({ error: "Missing call identifier" }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 400,
        });
      }

      // 1. Try Telnyx Call Control hangup
      const telnyxApiKey = await fetchConfig(supabase, "TELNYX_API_KEY", "KEY01A049E00656B79B4314CFFBC7969C10_k9JM7HV9u4sB2MadneUT1M");
      if (telnyxApiKey) {
        try {
          const telnyxResp = await fetch(
            `https://api.telnyx.com/v2/calls/${callSid}/actions/hangup`,
            {
              method: "POST",
              headers: {
                Authorization: `Bearer ${telnyxApiKey}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify({}),
            },
          );
          if (telnyxResp.ok) {
            return new Response(JSON.stringify({ success: true, provider: "telnyx" }), {
              headers: { ...corsHeaders, "Content-Type": "application/json" },
              status: 200,
            });
          }
        } catch (_) {}
      }

      // 2. Fallback to Twilio cancel
      try {
        const twilioAccountSid = await fetchConfig(supabase, "TWILIO_ACCOUNT_SID", "ACb6df4af349214929b8fc9796c3b6490e");
        const twilioAuthToken = await fetchConfig(supabase, "TWILIO_AUTH_TOKEN", "0bf6edf400be1b8fef90eb0898dd5a97");
        const basicAuth = btoa(`${twilioAccountSid}:${twilioAuthToken}`);
        const response = await fetch(
          `https://api.twilio.com/2010-04-01/Accounts/${twilioAccountSid}/Calls/${callSid}.json`,
          {
            method: "POST",
            headers: {
              Authorization: `Basic ${basicAuth}`,
              "Content-Type": "application/x-www-form-urlencoded",
            },
            body: new URLSearchParams({ Status: "canceled" }).toString(),
          },
        );

        return new Response(JSON.stringify({ success: response.ok, provider: "twilio" }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        });
      } catch (_) {}

      return new Response(JSON.stringify({ success: false }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      });
    }

    return new Response(JSON.stringify({ error: `Unknown action: ${action}` }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500,
    });
  }
});
