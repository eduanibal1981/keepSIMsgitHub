import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const jsonResponse = (body: Record<string, unknown>, status: number) =>
  new Response(JSON.stringify(body), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status,
  });

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const serviceHeaders = {
  "apikey": SERVICE_ROLE_KEY,
  "Authorization": `Bearer ${SERVICE_ROLE_KEY}`,
  "Content-Type": "application/json",
};

async function resolveUserId(req: Request): Promise<string | null> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return null;
  const res = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { "apikey": SERVICE_ROLE_KEY, "Authorization": authHeader },
  });
  if (!res.ok) return null;
  const user = await res.json();
  return user?.id ?? null;
}

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

async function fetchUserWallet(userId: string): Promise<any | null> {
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/wallets?user_id=eq.${userId}&select=*`,
    { headers: serviceHeaders },
  );
  if (!res.ok) return null;
  const rows = await res.json();
  return rows[0] ?? null;
}

async function fetchUserDefaultCallerId(userId: string): Promise<string | null> {
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/user_caller_ids?user_id=eq.${userId}&is_verified=eq.true&is_default=eq.true&select=phone_number`,
    { headers: serviceHeaders },
  );
  if (!res.ok) return null;
  const rows = await res.json();
  return rows[0]?.phone_number ?? null;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const userId = await resolveUserId(req);
    if (!userId) {
      return jsonResponse({ success: false, errorMessage: "Unauthorized. Please sign in." }, 401);
    }

    const body = await req.json();
    const { action, callId, destinationNumber, userCallbackNumber, simLineId } = body;
    const telnyxApiKey = await fetchSystemConfig("TELNYX_API_KEY");

    if (!telnyxApiKey) {
      return jsonResponse({ success: false, errorMessage: "Telnyx Voice is not configured on this server" }, 500);
    }

    // ── HANGUP ACTION ──
    if (action === "hangup") {
      if (!callId) {
        return jsonResponse({ success: false, errorMessage: "callId is required for hangup" }, 400);
      }

      // Fetch call record to get call_control_id
      const recRes = await fetch(`${SUPABASE_URL}/rest/v1/call_records?id=eq.${callId}&user_id=eq.${userId}&select=*`, {
        headers: serviceHeaders,
      });
      const records = recRes.ok ? await recRes.json() : [];
      const record = records[0];

      if (record?.telnyx_call_control_id_leg_a) {
        await fetch(`https://api.telnyx.com/v2/calls/${record.telnyx_call_control_id_leg_a}/actions/hangup`, {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${telnyxApiKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({}),
        });
      }

      await fetch(`${SUPABASE_URL}/rest/v1/call_records?id=eq.${callId}`, {
        method: "PATCH",
        headers: serviceHeaders,
        body: JSON.stringify({
          status: "completed",
          ended_at: new Date().toISOString(),
        }),
      });

      return jsonResponse({ success: true, message: "Call terminated" }, 200);
    }

    // ── INITIATE OUTBOUND CALL ──
    if (!destinationNumber || typeof destinationNumber !== "string") {
      return jsonResponse({ success: false, errorMessage: "destinationNumber is required" }, 400);
    }

    // 1. Check user wallet balance
    const wallet = await fetchUserWallet(userId);
    const balance = Number(wallet?.balance ?? 0);
    if (balance < 0.15) {
      return jsonResponse({
        success: false,
        code: "insufficient_funds",
        errorMessage: `Insufficient wallet balance ($${balance.toFixed(2)}). Please add credit to make international calls.`,
        balance,
      }, 402);
    }

    // 2. Lookup call rate for destination number
    const rateRes = await rpc("get_call_rate_for_number", { p_phone_number: destinationNumber });
    let rateData = null;
    if (rateRes.ok && Array.isArray(rateRes.body) && rateRes.body.length > 0) {
      rateData = rateRes.body[0];
    } else {
      rateData = {
        country_code: "GLOBAL",
        country_name: "International Destination",
        phone_prefix: "+",
        rate_per_minute_usd: 0.15,
        billing_increment_seconds: 1,
      };
    }

    // 3. Fetch Telnyx Configuration
    const telnyxAppId = await fetchSystemConfig("TELNYX_CALL_CONTROL_APP_ID", "3036680705380714233");
    const defaultCallerId = await fetchSystemConfig("TELNYX_DEFAULT_CALLER_ID", "+17543180369");

    // 4. Resolve Verified Caller ID
    const cleanDest = destinationNumber.replace(/\s+/g, "");
    const userVerifiedNumber = await fetchUserDefaultCallerId(userId);

    // If user has a verified phone number, present it as Caller ID!
    // If calling their own phone, fallback to default gateway to prevent telecom self-loop block.
    let fromNumber = defaultCallerId;
    if (userVerifiedNumber && userVerifiedNumber !== cleanDest) {
      fromNumber = userVerifiedNumber;
    } else if (userCallbackNumber && userCallbackNumber !== cleanDest) {
      fromNumber = userCallbackNumber;
    }

    // 5. Create initial pending call record
    const insertCallRes = await fetch(`${SUPABASE_URL}/rest/v1/call_records`, {
      method: "POST",
      headers: { ...serviceHeaders, "Prefer": "return=representation" },
      body: JSON.stringify({
        user_id: userId,
        sim_line_id: simLineId || null,
        call_type: "outbound_direct",
        caller_number: fromNumber,
        destination_number: cleanDest,
        destination_country_code: rateData.country_code,
        destination_country_name: rateData.country_name,
        rate_per_minute_usd: rateData.rate_per_minute_usd,
        status: "initiating",
      }),
    });

    if (!insertCallRes.ok) {
      const errText = await insertCallRes.text();
      return jsonResponse({ success: false, errorMessage: `Failed to create call record: ${errText}` }, 500);
    }

    const callRecord = (await insertCallRes.json())[0];

    // 6. Build client state payload
    const clientState = btoa(JSON.stringify({
      callRecordId: callRecord.id,
      userId: userId,
      destinationNumber: cleanDest,
      userCallbackNumber: fromNumber,
      ratePerMinute: rateData.rate_per_minute_usd,
      countryCode: rateData.country_code,
    }));

    // 7. Initiate Call to the Destination Number
    const telnyxRes = await fetch("https://api.telnyx.com/v2/calls", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${telnyxApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        connection_id: telnyxAppId,
        to: cleanDest,
        from: fromNumber,
        client_state: clientState,
        timeout_secs: 30,
        answering_machine_detection: "detect",
      }),
    });

    const telnyxJson = await telnyxRes.json();

    if (!telnyxRes.ok) {
      const errDetail = telnyxJson.errors?.[0]?.detail || JSON.stringify(telnyxJson);
      await fetch(`${SUPABASE_URL}/rest/v1/call_records?id=eq.${callRecord.id}`, {
        method: "PATCH",
        headers: serviceHeaders,
        body: JSON.stringify({ status: "failed", error_message: errDetail }),
      });
      return jsonResponse({
        success: false,
        errorMessage: `Failed to initiate call via Telnyx: ${errDetail}`,
      }, 502);
    }

    const telnyxCallData = telnyxJson.data;
    const callControlId = telnyxCallData.call_control_id;
    const callSessionId = telnyxCallData.call_session_id;

    await fetch(`${SUPABASE_URL}/rest/v1/call_records?id=eq.${callRecord.id}`, {
      method: "PATCH",
      headers: serviceHeaders,
      body: JSON.stringify({
        telnyx_call_control_id_leg_a: callControlId,
        telnyx_call_session_id: callSessionId,
      }),
    });

    return jsonResponse({
      success: true,
      callId: callRecord.id,
      status: "initiating",
      destination: {
        number: cleanDest,
        countryName: rateData.country_name,
        countryCode: rateData.country_code,
        ratePerMinute: rateData.rate_per_minute_usd,
        ratePerSecond: (rateData.rate_per_minute_usd / 60).toFixed(5),
      },
      callerId: fromNumber,
      walletBalance: balance,
    }, 200);

  } catch (err: any) {
    console.error("make-call error:", err);
    return jsonResponse({ success: false, errorMessage: err.message }, 500);
  }
});
