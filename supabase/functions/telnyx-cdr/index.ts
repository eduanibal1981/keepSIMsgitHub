import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const serviceHeaders = {
  "apikey": SERVICE_ROLE_KEY,
  "Authorization": `Bearer ${SERVICE_ROLE_KEY}`,
  "Content-Type": "application/json",
};

async function rpc(name: string, args: Record<string, unknown>): Promise<{ ok: boolean; body: any }> {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: serviceHeaders,
    body: JSON.stringify(args),
  });
  const text = await res.text();
  let body: any = text;
  try { body = JSON.parse(text); } catch (_) { /* raw text */ }
  return { ok: res.ok, body };
}

function decodeClientState(clientStateStr?: string): any | null {
  if (!clientStateStr) return null;
  try {
    const jsonStr = atob(clientStateStr);
    return JSON.parse(jsonStr);
  } catch (_) {
    try {
      return JSON.parse(clientStateStr);
    } catch (_) {
      return null;
    }
  }
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const rawBody = await req.json();
    const event = rawBody?.data;
    if (!event) {
      return new Response(JSON.stringify({ status: "ignored" }), { headers: { "Content-Type": "application/json" }, status: 200 });
    }

    const eventType = event.event_type;
    const payload = event.payload;
    const callControlId = payload?.call_control_id;
    const clientState = decodeClientState(payload?.client_state);

    console.log(`Telnyx Voice Webhook: ${eventType}, call_control_id: ${callControlId}`);

    const callRecordId = clientState?.callRecordId;
    const userId = clientState?.userId;
    const ratePerMinute = Number(clientState?.ratePerMinute ?? 0.08);

    // 1. Destination is Ringing
    if (eventType === "call.ringing" || eventType === "call.initiated") {
      if (callRecordId) {
        await fetch(`${SUPABASE_URL}/rest/v1/call_records?id=eq.${callRecordId}`, {
          method: "PATCH",
          headers: serviceHeaders,
          body: JSON.stringify({ status: "ringing" }),
        });
      }
    }

    // 2. Recipient Actually Answered the Phone
    else if (eventType === "call.answered") {
      console.log(`Call answered by destination! Updating callRecordId: ${callRecordId}`);
      if (callRecordId) {
        await fetch(`${SUPABASE_URL}/rest/v1/call_records?id=eq.${callRecordId}`, {
          method: "PATCH",
          headers: serviceHeaders,
          body: JSON.stringify({
            status: "in_progress",
            answered_at: new Date().toISOString(),
          }),
        });
      }
    }

    // 3. Call Hangup / Terminated
    else if (eventType === "call.hangup") {
      const hangupCause = payload?.hangup_cause || "normal_clearing";
      const durationSecs = Number(payload?.call_duration_secs ?? 0);

      console.log(`Call ended: record=${callRecordId}, duration=${durationSecs}s, cause=${hangupCause}`);

      if (callRecordId) {
        // Check if the call was actually answered
        const recRes = await fetch(`${SUPABASE_URL}/rest/v1/call_records?id=eq.${callRecordId}`, {
          headers: serviceHeaders,
        });
        const records = recRes.ok ? await recRes.json() : [];
        const record = records[0];

        const wasAnswered = record?.answered_at !== null && record?.answered_at !== undefined;
        let finalStatus = "completed";

        if (!wasAnswered && durationSecs <= 0) {
          const lowerCause = hangupCause.toLowerCase();
          if (lowerCause.includes("busy") || lowerCause.includes("user_busy")) {
            finalStatus = "busy";
          } else if (lowerCause.includes("timeout") || lowerCause.includes("no_answer") || lowerCause.includes("unallocated")) {
            finalStatus = "no_answer";
          } else if (lowerCause.includes("rejected") || lowerCause.includes("declined")) {
            finalStatus = "declined";
          } else {
            finalStatus = "cancelled";
          }
        }

        let totalCost = 0.00;
        // ONLY debit wallet if the call was ACTUALLY answered and had positive duration
        if (wasAnswered && durationSecs > 0 && userId && ratePerMinute > 0) {
          totalCost = Number((durationSecs * (ratePerMinute / 60.0)).toFixed(4));
          
          if (totalCost > 0) {
            console.log(`Debiting wallet for user ${userId}: $${totalCost} for ${durationSecs}s answered call`);
            await rpc("debit_wallet_for_call", {
              p_user_id: userId,
              p_call_id: callRecordId,
              p_amount: totalCost,
              p_description: `International Call to ${clientState?.destinationNumber ?? "destination"} (${durationSecs}s)`,
            });
          }
        }

        await fetch(`${SUPABASE_URL}/rest/v1/call_records?id=eq.${callRecordId}`, {
          method: "PATCH",
          headers: serviceHeaders,
          body: JSON.stringify({
            status: finalStatus,
            ended_at: new Date().toISOString(),
            duration_seconds: wasAnswered ? durationSecs : 0,
            billed_duration_seconds: wasAnswered ? durationSecs : 0,
            total_cost_usd: totalCost,
            raw_cdr: payload,
          }),
        });
      }
    }

    return new Response(JSON.stringify({ received: true, event: eventType }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (err: any) {
    console.error("telnyx-cdr error:", err);
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500,
    });
  }
});
