import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const TWILIO_ACCOUNT_SID = Deno.env.get("TWILIO_ACCOUNT_SID") || "ACb6df4af349214929b8fc9796c3b6490e";
const TWILIO_AUTH_TOKEN = Deno.env.get("TWILIO_AUTH_TOKEN") || "0bf6edf400be1b8fef90eb0898dd5a97";
const TWILIO_FROM_NUMBER = Deno.env.get("TWILIO_FROM_NUMBER") || "+18676755999";

const TELNYX_API_KEY = Deno.env.get("TELNYX_API_KEY") || "KEY01A049E00656B79B4314CFFBC7969C10_k9JM7HV9u4sB2MadneUT1M";
const TELNYX_MESSAGING_PROFILE_ID = Deno.env.get("TELNYX_MESSAGING_PROFILE_ID") || "4001a054-0cfd-45aa-aed2-dd83279e7777";

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

    // ── Twilio Missed Call Actions ──
    if (action === "twilio_trigger_call") {
      const toPhoneNumber = body.phoneNumber;
      if (!toPhoneNumber) {
        return new Response(JSON.stringify({ error: "Missing phoneNumber" }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 400,
        });
      }

      const basicAuth = btoa(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`);
      const twilioParams = new URLSearchParams({
        To: toPhoneNumber,
        From: TWILIO_FROM_NUMBER,
        Twiml: "<Response><Reject/></Response>",
      });

      const response = await fetch(
        `https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Calls.json`,
        {
          method: "POST",
          headers: {
            Authorization: `Basic ${basicAuth}`,
            "Content-Type": "application/x-www-form-urlencoded",
          },
          body: twilioParams.toString(),
        },
      );

      if (response.ok || response.status === 201) {
        const data = await response.json();
        return new Response(JSON.stringify({ success: true, sid: data.sid }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        });
      }
      return new Response(JSON.stringify({ success: false, error: "Twilio call failed" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: response.status,
      });
    }

    if (action === "twilio_fetch_status") {
      const callSid = body.callSid;
      if (!callSid) {
        return new Response(JSON.stringify({ error: "Missing callSid" }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 400,
        });
      }

      const basicAuth = btoa(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`);
      const response = await fetch(
        `https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Calls/${callSid}.json`,
        {
          headers: { Authorization: `Basic ${basicAuth}` },
        },
      );

      if (response.ok) {
        const data = await response.json();
        return new Response(JSON.stringify({ success: true, status: data.status }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        });
      }
      return new Response(JSON.stringify({ success: false, status: "unknown" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      });
    }

    if (action === "twilio_cancel_call") {
      const callSid = body.callSid;
      if (!callSid) {
        return new Response(JSON.stringify({ error: "Missing callSid" }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 400,
        });
      }

      const basicAuth = btoa(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`);
      const response = await fetch(
        `https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Calls/${callSid}.json`,
        {
          method: "POST",
          headers: {
            Authorization: `Basic ${basicAuth}`,
            "Content-Type": "application/x-www-form-urlencoded",
          },
          body: new URLSearchParams({ Status: "canceled" }).toString(),
        },
      );

      return new Response(JSON.stringify({ success: response.ok }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      });
    }

    // ── Telnyx SMS Verification Actions ──
    if (action === "telnyx_send_sms") {
      const toPhoneNumber = (body.phoneNumber || "").replace(/\s+/g, "");
      if (!toPhoneNumber) {
        return new Response(JSON.stringify({ error: "Missing phoneNumber" }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 400,
        });
      }

      const response = await fetch("https://api.telnyx.com/v2/messages", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${TELNYX_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: "KeepSIMs",
          to: toPhoneNumber,
          text: "KeepSIMs line verification handshake: SIM Line confirmed active.",
          messaging_profile_id: TELNYX_MESSAGING_PROFILE_ID,
        }),
      });

      if (response.ok || response.status === 201) {
        const data = await response.json();
        return new Response(JSON.stringify({ success: true, messageId: data?.data?.id }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        });
      }
      return new Response(JSON.stringify({ success: false, error: "Telnyx SMS failed" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: response.status,
      });
    }

    if (action === "telnyx_fetch_status") {
      const messageId = body.messageId;
      if (!messageId) {
        return new Response(JSON.stringify({ error: "Missing messageId" }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 400,
        });
      }

      const response = await fetch(`https://api.telnyx.com/v2/messages/${messageId}`, {
        headers: {
          Authorization: `Bearer ${TELNYX_API_KEY}`,
          "Content-Type": "application/json",
        },
      });

      if (response.ok) {
        const data = await response.json();
        const dataMap = data?.data ?? {};
        const toObj = (dataMap?.to as Array<any>)?.firstOrNull ?? dataMap?.to?.[0];
        const rawStatus = (toObj?.status || dataMap?.status || "").toLowerCase();
        const carrier = toObj?.carrier || null;
        const errors = dataMap?.errors || [];
        const errDetail = errors.length > 0 ? errors[0]?.detail : null;

        return new Response(
          JSON.stringify({
            success: true,
            status: rawStatus,
            carrier,
            errorMessage: errDetail,
            completedAt: dataMap?.completed_at || null,
            sentAt: dataMap?.sent_at || null,
          }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 200,
          },
        );
      }
      return new Response(JSON.stringify({ success: false, status: "unknown" }), {
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
