import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

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
    return new Response("ok", { headers: { "Access-Control-Allow-Origin": "*" } });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const contentType = req.headers.get("content-type") || "";

  try {
    // ── 1. TWILIO STATUS CALLBACK ──
    if (contentType.includes("application/x-www-form-urlencoded")) {
      const formData = await req.formData();
      const callSid = formData.get("CallSid")?.toString();
      const callStatus = (formData.get("CallStatus")?.toString() || "").toLowerCase();

      if (!callSid) {
        return new Response("Missing CallSid", { status: 400 });
      }

      // Find attempt
      const { data: attempt } = await supabase
        .from("line_verification_attempts")
        .select("*")
        .eq("provider", "twilio")
        .eq("provider_resource_id", callSid)
        .maybeSingle();

      if (!attempt) {
        // Callback might arrive for older or unrecognized call
        return new Response("OK (untracked call)", { status: 200 });
      }

      if (attempt.status === "terminal") {
        return new Response("OK (already terminal)", { status: 200 });
      }

      if (callStatus === "ringing" || callStatus === "in-progress" || callStatus === "answered") {
        // 1. Immediately cancel the call so the user's phone stops ringing and voice minutes are not consumed
        try {
          const twilioAccountSid = await fetchConfig(supabase, "TWILIO_ACCOUNT_SID", "ACb6df4af349214929b8fc9796c3b6490e");
          const twilioAuthToken = await fetchConfig(supabase, "TWILIO_AUTH_TOKEN", "0bf6edf400be1b8fef90eb0898dd5a97");
          if (twilioAccountSid && twilioAuthToken) {
            const basicAuth = btoa(`${twilioAccountSid}:${twilioAuthToken}`);
            await fetch(
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
          }
        } catch (e) {
          console.error("Failed to cancel ringing Twilio call:", e);
        }

        // 2. Settle attempt as SUCCEEDED
        await supabase.rpc("settle_line_verification_attempt", {
          p_attempt_id: attempt.id,
          p_outcome: "succeeded",
          p_carrier_name: null,
          p_error_message: null,
        });

        return new Response("OK (ringing verified)", { status: 200 });
      }

      if (callStatus === "failed" || callStatus === "busy" || callStatus === "no-answer") {
        // If not already marked succeeded by ringing
        if (attempt.outcome !== "succeeded") {
          await supabase.rpc("settle_line_verification_attempt", {
            p_attempt_id: attempt.id,
            p_outcome: "failed",
            p_carrier_name: null,
            p_error_message: `Call reached terminal state: ${callStatus}`,
          });
        }
        return new Response("OK (call failed)", { status: 200 });
      }

      return new Response("OK", { status: 200 });
    }

    // ── 2. TELNYX DLR & CALL CONTROL WEBHOOK ──
    if (contentType.includes("application/json")) {
      const body = await req.json();
      const eventType = body?.data?.event_type;
      const payload = body?.data?.payload;

      // ── 2A. TELNYX VOICE CALL CONTROL EVENTS ──
      if (eventType && eventType.startsWith("call.")) {
        const callControlId = payload?.call_control_id || payload?.call_leg_id;
        let attemptId: string | null = null;

        if (payload?.client_state) {
          try {
            const decoded = JSON.parse(atob(payload.client_state));
            attemptId = decoded.attemptId || null;
          } catch (_) {
            try {
              const decoded = JSON.parse(payload.client_state);
              attemptId = decoded.attemptId || null;
            } catch (_) {}
          }
        }

        let attempt: any = null;
        if (attemptId) {
          const { data } = await supabase
            .from("line_verification_attempts")
            .select("*")
            .eq("id", attemptId)
            .maybeSingle();
          attempt = data;
        }

        if (!attempt && callControlId) {
          const { data } = await supabase
            .from("line_verification_attempts")
            .select("*")
            .eq("provider", "telnyx")
            .eq("provider_resource_id", callControlId)
            .maybeSingle();
          attempt = data;
        }

        if (!attempt) {
          return new Response("OK (untracked call event)", { status: 200 });
        }

        if (attempt.status === "terminal") {
          return new Response("OK (already terminal)", { status: 200 });
        }

        // Recipient line is ringing or was answered:
        // Immediately hang up call so user's phone stops ringing and no talk minutes are billed!
        if (eventType === "call.ringing" || eventType === "call.answered") {
          try {
            const telnyxApiKey = await fetchConfig(supabase, "TELNYX_API_KEY", "KEY01A049E00656B79B4314CFFBC7969C10_k9JM7HV9u4sB2MadneUT1M");
            if (telnyxApiKey && callControlId) {
              await fetch(`https://api.telnyx.com/v2/calls/${encodeURIComponent(callControlId)}/actions/hangup`, {
                method: "POST",
                headers: {
                  "Authorization": `Bearer ${telnyxApiKey}`,
                  "Content-Type": "application/json",
                },
                body: JSON.stringify({}),
              });
            }
          } catch (e) {
            console.error("Failed to hang up ringing Telnyx call:", e);
          }

          await supabase.rpc("settle_line_verification_attempt", {
            p_attempt_id: attempt.id,
            p_outcome: "succeeded",
            p_carrier_name: null,
            p_error_message: null,
          });

          return new Response("OK (call ringing confirmed & hung up)", { status: 200 });
        }

        // Call hung up
        if (eventType === "call.hangup") {
          if (attempt.outcome !== "succeeded") {
            const rawCause = payload?.hangup_cause || "call_ended";
            const hangupCause = rawCause.toLowerCase();

            // If the user rejected/declined (user_busy) or the handset rang until timeout (no_answer/timeout)
            // or normal disconnect, the phone was confirmed reached and alerted by the cellular network!
            if (
              hangupCause === "user_busy" ||
              hangupCause === "no_answer" ||
              hangupCause === "timeout" ||
              hangupCause === "normal_clearing"
            ) {
              await supabase.rpc("settle_line_verification_attempt", {
                p_attempt_id: attempt.id,
                p_outcome: "succeeded",
                p_carrier_name: null,
                p_error_message: null,
              });
              return new Response("OK (hangup confirmed ringing signal)", { status: 200 });
            }

            await supabase.rpc("settle_line_verification_attempt", {
              p_attempt_id: attempt.id,
              p_outcome: "failed",
              p_carrier_name: null,
              p_error_message: `Call ended without ringing: ${rawCause}`,
            });
          }
          return new Response("OK (hangup processed)", { status: 200 });
        }

        return new Response("OK (call event recorded)", { status: 200 });
      }

      // ── 2B. TELNYX SMS DLR EVENTS ──
      if (eventType === "message.finalized") {
        const messageId = payload?.id;
        const toList = payload?.to || [];
        const toItem = toList[0] || {};
        const deliveryStatus = (toItem.status || "").toLowerCase();
        const carrier = toItem.carrier || null;

        if (!messageId) {
          return new Response("Missing messageId in Telnyx payload", { status: 400 });
        }

        const { data: attempt } = await supabase
          .from("line_verification_attempts")
          .select("*")
          .eq("provider", "telnyx")
          .eq("provider_resource_id", messageId)
          .maybeSingle();

        if (!attempt) {
          return new Response("OK (untracked message)", { status: 200 });
        }

        if (attempt.status === "terminal") {
          return new Response("OK (already terminal)", { status: 200 });
        }

        if (deliveryStatus === "delivered") {
          await supabase.rpc("settle_line_verification_attempt", {
            p_attempt_id: attempt.id,
            p_outcome: "succeeded",
            p_carrier_name: carrier,
            p_error_message: null,
          });
          return new Response("OK (delivered)", { status: 200 });
        } else if (deliveryStatus === "failed" || deliveryStatus === "undelivered") {
          const errors = payload?.errors || [];
          const errDetail = errors.length > 0 ? errors[0]?.detail : `SMS delivery status: ${deliveryStatus}`;
          await supabase.rpc("settle_line_verification_attempt", {
            p_attempt_id: attempt.id,
            p_outcome: "failed",
            p_carrier_name: carrier,
            p_error_message: errDetail,
          });
          return new Response("OK (delivery failed)", { status: 200 });
        }
      }

      return new Response("OK", { status: 200 });
    }

    return new Response("Unsupported media type", { status: 415 });
  } catch (err: any) {
    console.error("Webhook processing error:", err);
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});
