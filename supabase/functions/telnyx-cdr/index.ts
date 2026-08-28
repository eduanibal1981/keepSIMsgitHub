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

async function fetchSystemConfig(key: string, defaultVal: string = ""): Promise<string> {
  const envVal = Deno.env.get(key);
  if (envVal) return envVal;
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/system_configs?config_key=eq.${encodeURIComponent(key)}&select=config_value`,
    { headers: serviceHeaders },
  );
  if (!res.ok) return defaultVal;
  const rows = await res.json();
  return rows[0]?.config_value ?? defaultVal;
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

    const telnyxApiKey = await fetchSystemConfig("TELNYX_API_KEY");
    const defaultCallerId = await fetchSystemConfig("TELNYX_DEFAULT_CALLER_ID", "+18337746746");

    // 1. Leg A Answered -> Dial Leg B and Bridge
    if (eventType === "call.answered") {
      const callRecordId = clientState?.callRecordId;
      const destinationNumber = clientState?.destinationNumber;
      const userCallbackNumber = clientState?.userCallbackNumber;

      if (callControlId && destinationNumber) {
        console.log(`Leg A answered! Transferring/bridging to destination: ${destinationNumber}`);
        
        // Transfer the call to destination number
        const transferRes = await fetch(`https://api.telnyx.com/v2/calls/${callControlId}/actions/transfer`, {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${telnyxApiKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            to: destinationNumber,
            from: defaultCallerId || userCallbackNumber,
            timeout_secs: 60,
            client_state: payload?.client_state,
          }),
        });

        if (!transferRes.ok) {
          console.error("Transfer failed:", await transferRes.text());
        }
      }

      // Update call record
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

    // 2. Call Ringing
    else if (eventType === "call.ringing") {
      const callRecordId = clientState?.callRecordId;
      if (callRecordId) {
        await fetch(`${SUPABASE_URL}/rest/v1/call_records?id=eq.${callRecordId}`, {
          method: "PATCH",
          headers: serviceHeaders,
          body: JSON.stringify({ status: "ringing" }),
        });
      }
    }

    // 3. Call Bridged
    else if (eventType === "call.bridged") {
      const callRecordId = clientState?.callRecordId;
      if (callRecordId) {
        await fetch(`${SUPABASE_URL}/rest/v1/call_records?id=eq.${callRecordId}`, {
          method: "PATCH",
          headers: serviceHeaders,
          body: JSON.stringify({ status: "in_progress" }),
        });
      }
    }

    // 4. Call Hangup / Completed -> Bill user wallet per second
    else if (eventType === "call.hangup") {
      const callRecordId = clientState?.callRecordId;
      const userId = clientState?.userId;
      const ratePerMinute = Number(clientState?.ratePerMinute ?? 0.08);
      const hangupCause = payload?.hangup_cause || "normal_clearing";

      // Duration calculation
      const durationSecs = Number(payload?.call_duration_secs ?? 0);
      const startTime = payload?.start_time ? new Date(payload.start_time).getTime() : 0;
      const endTime = payload?.end_time ? new Date(payload.end_time).getTime() : Date.now();
      const calculatedDuration = durationSecs > 0 ? durationSecs : Math.max(0, Math.round((endTime - startTime) / 1000));

      console.log(`Call ended: record=${callRecordId}, duration=${calculatedDuration}s, cause=${hangupCause}`);

      if (callRecordId) {
        // Fetch existing call record to verify answered status
        const recRes = await fetch(`${SUPABASE_URL}/rest/v1/call_records?id=eq.${callRecordId}`, {
          headers: serviceHeaders,
        });
        const records = recRes.ok ? await recRes.json() : [];
        const record = records[0];

        const isAnswered = record?.answered_at || calculatedDuration > 0;
        const finalStatus = isAnswered ? "completed" : (hangupCause.toLowerCase().includes("busy") ? "busy" : "no_answer");

        let totalCost = 0.00;
        if (isAnswered && calculatedDuration > 0 && userId && ratePerMinute > 0) {
          // Pay-per-second billing formula: duration in seconds * (rate per minute / 60)
          totalCost = Number((calculatedDuration * (ratePerMinute / 60.0)).toFixed(4));
          
          if (totalCost > 0) {
            console.log(`Debiting wallet for user ${userId}: $${totalCost} for ${calculatedDuration}s call`);
            const debitRes = await rpc("debit_wallet_for_call", {
              p_user_id: userId,
              p_call_id: callRecordId,
              p_amount: totalCost,
              p_description: `International Call to ${clientState?.destinationNumber ?? "destination"} (${calculatedDuration}s)`,
            });
            if (!debitRes.ok) {
              console.error("debit_wallet_for_call error:", debitRes.body);
            }
          }
        }

        await fetch(`${SUPABASE_URL}/rest/v1/call_records?id=eq.${callRecordId}`, {
          method: "PATCH",
          headers: serviceHeaders,
          body: JSON.stringify({
            status: finalStatus,
            ended_at: new Date().toISOString(),
            duration_seconds: calculatedDuration,
            billed_duration_seconds: calculatedDuration,
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