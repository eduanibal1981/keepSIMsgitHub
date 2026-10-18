import { EndpointError, requireAdmin } from "../_shared/endpoint-auth.ts";
import { ProviderConfigurationError, providerSecretClient, requireProviderSecret } from "../_shared/provider-secrets.ts";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
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

async function fetchSystemConfig(key: string, defaultVal: string = ""): Promise<string> {
  if (key === "TELNYX_API_KEY") {
    return await requireProviderSecret(providerSecretClient(SUPABASE_URL, SERVICE_ROLE_KEY), key);
  }
  const envVal = Deno.env.get(key);
  if (envVal) return envVal;
  try {
    const res = await fetch(
      `${SUPABASE_URL}/rest/v1/system_configs?config_key=eq.${encodeURIComponent(key)}&select=config_value`,
      { headers: serviceHeaders },
    );
    if (!res.ok) return defaultVal;
    const rows = await res.json();
    return rows[0]?.config_value ?? defaultVal;
  } catch (_) {
    return defaultVal;
  }
}

async function telnyxGet(path: string, apiKey: string): Promise<any> {
  const res = await fetch(`https://api.telnyx.com${path}`, {
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
  });
  if (!res.ok) {
    const errText = await res.text();
    console.error(`Telnyx API error [${res.status}] ${path}:`, errText);
    return null;
  }
  return await res.json();
}

async function fetchTelnyxDetailRecords(
  recordType: string,
  apiKey: string,
  dateFilterParam: string,
  startDateIso: string,
  endDateIso: string,
  maxPages: number = 3,
): Promise<any[]> {
  const allRecords: any[] = [];
  let pageNumber = 1;

  while (pageNumber <= maxPages) {
    const query = new URLSearchParams({
      "filter[record_type]": recordType,
      [`filter[${dateFilterParam}][gte]`]: startDateIso,
      [`filter[${dateFilterParam}][lte]`]: endDateIso,
      "page[size]": "50",
      "page[number]": pageNumber.toString(),
    });

    const res = await telnyxGet(`/v2/detail_records?${query.toString()}`, apiKey);
    if (!res || !res.data) break;

    allRecords.push(...res.data);

    const meta = res.meta;
    if (!meta || pageNumber >= (meta.total_pages || 1)) {
      break;
    }
    pageNumber++;
  }

  return allRecords;
}

interface ChargeItem {
  id: string;
  record_type: "voice" | "messaging" | "webrtc" | "did_rental";
  date: string;
  direction: "outbound" | "inbound" | "n/a";
  source: string;
  destination: string;
  description: string;
  units: string;
  rate: number;
  cost: number;
  currency: string;
  status: string;
  meta?: Record<string, unknown>;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. Authorize Admin
    await requireAdmin(req, SUPABASE_URL, SERVICE_ROLE_KEY);

    // 2. Fetch Telnyx API Key
    const apiKey = await fetchSystemConfig("TELNYX_API_KEY");
    if (!apiKey) {
      return jsonResponse({ error: "TELNYX_API_KEY is not configured in system settings." }, 500);
    }

    // 3. Parse Query / Body Parameters
    let startDateParam: string | null = null;
    let endDateParam: string | null = null;
    let serviceFilter: string = "all";

    if (req.method === "POST") {
      try {
        const body = await req.json();
        startDateParam = body.start_date || null;
        endDateParam = body.end_date || null;
        serviceFilter = body.service_type || "all";
      } catch (_) {
        // use query params if body empty
      }
    }

    if (!startDateParam || !endDateParam) {
      const url = new URL(req.url);
      startDateParam = startDateParam || url.searchParams.get("start_date");
      endDateParam = endDateParam || url.searchParams.get("end_date");
      if (url.searchParams.get("service_type")) {
        serviceFilter = url.searchParams.get("service_type")!;
      }
    }

    const now = new Date();
    // Default to last 30 days if not specified
    const defaultStart = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
    const startDate = startDateParam ? new Date(startDateParam) : defaultStart;
    const endDate = endDateParam ? new Date(endDateParam) : now;

    // Ensure valid ISO bounds
    const startDateIso = startDate.toISOString();
    const endDateIso = endDate.toISOString();

    // 4. Parallel fetch from Telnyx APIs
    const [balRes, msgRecords, ccRecords, rtcRecords, sipRes, numbersRes, dbCallsRes] = await Promise.all([
      telnyxGet("/v2/balance", apiKey),
      (serviceFilter === "all" || serviceFilter === "messaging")
        ? fetchTelnyxDetailRecords("messaging", apiKey, "created_at", startDateIso, endDateIso, 3)
        : Promise.resolve([]),
      (serviceFilter === "all" || serviceFilter === "voice")
        ? fetchTelnyxDetailRecords("call-control", apiKey, "started_at", startDateIso, endDateIso, 5)
        : Promise.resolve([]),
      (serviceFilter === "all" || serviceFilter === "webrtc")
        ? fetchTelnyxDetailRecords("webrtc", apiKey, "started_at", startDateIso, endDateIso, 2)
        : Promise.resolve([]),
      (serviceFilter === "all" || serviceFilter === "voice")
        ? telnyxGet(
            `/v2/usage_reports?product=sip-trunking&start_date=${startDateIso}&end_date=${endDateIso}&dimensions=date,country_code&metrics=cost,billed_sec,call_sec,attempted,connected`,
            apiKey,
          )
        : Promise.resolve(null),
      telnyxGet("/v2/phone_numbers", apiKey),
      // Fetch DB call records for the window to enrich call legs with user context & retail margins
      (serviceFilter === "all" || serviceFilter === "voice")
        ? fetch(
            `${SUPABASE_URL}/rest/v1/call_records?started_at=gte.${encodeURIComponent(startDateIso)}&started_at=lte.${encodeURIComponent(endDateIso)}&select=id,destination_number,destination_country_name,caller_number,duration_seconds,total_cost_usd,rate_per_minute_usd,status,telnyx_call_control_id_leg_b,telnyx_call_session_id,created_at`,
            { headers: serviceHeaders },
          ).then((r) => (r.ok ? r.json() : []))
        : Promise.resolve([]),
    ]);

    const balanceData = balRes?.data || {
      balance: "0.00",
      currency: "USD",
      available_credit: "0.00",
      credit_limit: "0.00",
    };

    // 5. Normalize all charge items into a unified list
    const items: ChargeItem[] = [];

    // Process SMS Messages
    for (const m of msgRecords) {
      const cost = parseFloat(m.cost || "0");
      items.push({
        id: m.id || m.uuid || `msg-${Math.random()}`,
        record_type: "messaging",
        date: m.sent_at || m.created_at || startDateIso,
        direction: (m.direction as any) || "outbound",
        source: m.from || "System",
        destination: m.to || "Unknown",
        description: `SMS (${m.parts || 1} part${(m.parts || 1) > 1 ? "s" : ""}) to ${m.to || "Unknown"}`,
        units: `${m.parts || 1} msg`,
        rate: cost,
        cost: cost,
        currency: m.currency || "USD",
        status: m.status || "delivered",
        meta: {
          parts: m.parts,
          carrier: m.carrier,
          country_code: m.country_code,
          type: m.type,
        },
      });
    }

    // Map DB calls by session or leg id for enrichment
    const dbCallMap = new Map<string, any>();
    if (Array.isArray(dbCallsRes)) {
      for (const c of dbCallsRes) {
        if (c.telnyx_call_control_id_leg_b) dbCallMap.set(c.telnyx_call_control_id_leg_b, c);
        if (c.telnyx_call_session_id) dbCallMap.set(c.telnyx_call_session_id, c);
      }
    }

    // Process Call-Control Records
    for (const c of ccRecords) {
      const callCost = parseFloat(c.cost || "0");
      const durationSec = parseInt(c.call_sec || c.billed_sec || "0", 10);
      const dbMatch = dbCallMap.get(c.id) || dbCallMap.get(c.telnyx_session_id) || dbCallMap.get(c.telnyx_leg_id);

      const dest = c.cld || c.dest_number || dbMatch?.destination_number || "Unknown";
      const country = dbMatch?.destination_country_name || (c.country_code ? `+${c.country_code}` : "");
      const isConnected = c.connected === 1 || durationSec > 0 || (dbMatch && dbMatch.status === "completed");

      items.push({
        id: c.id || c.telnyx_leg_id || `cc-${Math.random()}`,
        record_type: "voice",
        date: c.started_at || c.finished_at || startDateIso,
        direction: (c.direction as any) || "outbound",
        source: c.cli || c.caller_number || "+17543180369",
        destination: dest,
        description: `Voice Call ${country ? `(${country})` : ""} - ${durationSec}s`,
        units: durationSec > 0 ? `${durationSec} sec` : "0 sec (No answer)",
        rate: parseFloat(c.rate || "0.002"),
        cost: callCost,
        currency: c.currency || "USD",
        status: isConnected ? "connected" : (c.attempted ? "no_answer" : "completed"),
        meta: {
          call_sec: durationSec,
          billed_sec: parseInt(c.billed_sec || "0", 10),
          country_code: c.country_code,
          db_retail_charge: dbMatch?.total_cost_usd,
          destination_country: country,
          connection_name: c.connection_name,
        },
      });
    }

    // Process WebRTC Records
    for (const w of rtcRecords) {
      const rtcCost = parseFloat(w.cost || "0");
      const durationSec = parseInt(w.call_sec || w.billed_sec || "0", 10);
      items.push({
        id: w.id || `webrtc-${Math.random()}`,
        record_type: "webrtc",
        date: w.started_at || startDateIso,
        direction: "inbound",
        source: "Mobile App WebRTC",
        destination: "KeepSIMs Voice Gateway",
        description: `WebRTC VoIP Audio Leg - ${durationSec}s`,
        units: `${durationSec} sec`,
        rate: parseFloat(w.rate || "0.002"),
        cost: rtcCost,
        currency: "USD",
        status: durationSec > 0 ? "completed" : "ended",
        meta: {
          call_sec: durationSec,
          billed_sec: parseInt(w.billed_sec || "0", 10),
        },
      });
    }

    // Process DID Phone Number Rentals
    const phoneNumbers = numbersRes?.data || [];
    for (const num of phoneNumbers) {
      const purchasedDate = new Date(num.purchased_at || "2026-08-29");
      // If the number was purchased on or before the end of the query window
      if (purchasedDate <= endDate) {
        items.push({
          id: `did-${num.phone_number}`,
          record_type: "did_rental",
          date: num.purchased_at || "2026-08-29T21:57:39Z",
          direction: "n/a",
          source: num.phone_number,
          destination: "KeepSIMs Gateway",
          description: `Gateway Number Monthly Rental (${num.phone_number})`,
          units: "1 Month",
          rate: 1.00,
          cost: 1.00,
          currency: "USD",
          status: num.status || "active",
          meta: {
            phone_number: num.phone_number,
            status: num.status,
            purchased_at: num.purchased_at,
          },
        });
      }
    }

    // Sort items by date descending
    items.sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());

    // 6. Aggregate Summary Totals
    let voiceCostTotal = 0;
    let voiceCount = 0;
    let voiceDurationSeconds = 0;

    let messagingCostTotal = 0;
    let messagingCount = 0;

    let webrtcCostTotal = 0;
    let didCostTotal = 0;

    for (const item of items) {
      if (item.record_type === "voice") {
        voiceCostTotal += item.cost;
        voiceCount++;
        voiceDurationSeconds += (item.meta?.call_sec as number) || 0;
      } else if (item.record_type === "messaging") {
        messagingCostTotal += item.cost;
        messagingCount++;
      } else if (item.record_type === "webrtc") {
        webrtcCostTotal += item.cost;
      } else if (item.record_type === "did_rental") {
        didCostTotal += item.cost;
      }
    }

    // Include SIP trunking termination costs
    const sipUsageRows = (sipRes?.data || []).filter((s: any) => s.cost > 0 || s.connected > 0);
    let sipTerminationCost = 0;
    for (const s of sipUsageRows) {
      sipTerminationCost += parseFloat(s.cost || "0");
    }

    // The total voice cost includes both Call Control sessions + SIP Outbound Termination
    const combinedVoiceCost = voiceCostTotal + sipTerminationCost;
    const grandTotalCost = combinedVoiceCost + messagingCostTotal + webrtcCostTotal + didCostTotal;

    const summary = {
      balance: parseFloat(balanceData.balance || "0"),
      available_credit: parseFloat(balanceData.available_credit || "0"),
      credit_limit: parseFloat(balanceData.credit_limit || "0"),
      currency: balanceData.currency || "USD",
      grand_total_charges: Math.round(grandTotalCost * 10000) / 10000,
      breakdown: {
        voice: {
          total_cost: Math.round(combinedVoiceCost * 10000) / 10000,
          call_control_legs_cost: Math.round(voiceCostTotal * 10000) / 10000,
          sip_termination_cost: Math.round(sipTerminationCost * 10000) / 10000,
          count: voiceCount,
          total_duration_minutes: Math.round((voiceDurationSeconds / 60) * 10) / 10,
        },
        messaging: {
          total_cost: Math.round(messagingCostTotal * 10000) / 10000,
          count: messagingCount,
        },
        webrtc: {
          total_cost: Math.round(webrtcCostTotal * 10000) / 10000,
          count: rtcRecords.length,
        },
        did_rentals: {
          total_cost: Math.round(didCostTotal * 10000) / 10000,
          count: phoneNumbers.length,
        },
      },
      sip_trunking_breakdown: sipUsageRows,
      date_range: {
        start_date: startDateIso,
        end_date: endDateIso,
      },
    };

    return jsonResponse({
      summary,
      items,
      count: items.length,
    }, 200);

  } catch (error: any) {
    if (error instanceof EndpointError) return jsonResponse({ error: error.message }, error.status);
    if (error instanceof ProviderConfigurationError) return jsonResponse({ error: error.message, code: error.code }, 503);
    console.error("admin-telnyx-billing error:", error);
    return jsonResponse({ error: error.message || "Internal server error" }, 500);
  }
});
