import { ProviderConfigurationError, providerSecretClient, requireProviderSecret } from "../_shared/provider-secrets.ts";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { EndpointError } from "../_shared/endpoint-auth.ts";
import { verifyTelnyx } from "../_shared/webhook-auth.ts";
import { trustedDatabase, withWebhookEvent } from "../_shared/webhook-events.ts";
import { handleLivenessCallback } from "../_shared/liveness-callback.ts";
import { CallMedia } from "./call-media.ts";
import { handleMediaEvent } from "./media-events.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, telnyx-signature-ed25519, telnyx-timestamp",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const TELNYX_PUBLIC_KEY = Deno.env.get("TELNYX_PUBLIC_KEY") || "";

const serviceHeaders = {
  "apikey": SERVICE_ROLE_KEY,
  "Authorization": `Bearer ${SERVICE_ROLE_KEY}`,
  "Content-Type": "application/json",
};

async function checkedWrite(url: string, options: RequestInit): Promise<Response> {
  const response = await fetch(url, options);
  if (!response.ok) throw new EndpointError(503, "Call persistence unavailable");
  return response;
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
  if (!res.ok || body?.success === false) throw new EndpointError(503, "Call settlement unavailable");
  return { ok: res.ok, body };
}

async function fetchSystemConfig(key: string, defaultVal: string = ""): Promise<string> {
  if (key === "TELNYX_API_KEY") {
    return await requireProviderSecret(providerSecretClient(SUPABASE_URL, SERVICE_ROLE_KEY), key);
  }
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

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 405,
    });
  }

  try {
    const rawBody = await req.text();
    const effectivePublicKey = TELNYX_PUBLIC_KEY || (await fetchSystemConfig("TELNYX_PUBLIC_KEY"));
    await verifyTelnyx(req, rawBody, effectivePublicKey);

    let parsedBody: any;
    try {
      parsedBody = JSON.parse(rawBody);
    } catch (_) {
      return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      });
    }

    const event = parsedBody?.data;
    if (!event) {
      return new Response(JSON.stringify({ status: "ignored" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      });
    }

    const eventId = event.id;
    const eventType = event.event_type;
    const payload = event.payload;
    const callControlId = payload?.call_control_id || payload?.call_session_id;
    const clientState = decodeClientState(payload?.client_state);

    if (!eventId || !eventType || !callControlId) throw new EndpointError(400, "Missing callback correlation");
    const db = trustedDatabase(SUPABASE_URL, SERVICE_ROLE_KEY);
    const clientCallRecordId = clientState?.callRecordId;
    if (clientState?.attemptId) {
      return await withWebhookEvent(db, "telnyx", eventId, payload.call_control_id, event, () =>
        handleLivenessCallback(db, "telnyx", payload.call_control_id, eventType, payload,
          async () => ({ apiKey: await fetchSystemConfig("TELNYX_API_KEY") }), clientState.attemptId));
    }

    // ── 2. Look up the verified Call Record from Database (SOURCE OF TRUTH) ──
    let dbRecord: any = null;
    if (clientCallRecordId) {
      const recRes = await checkedWrite(`${SUPABASE_URL}/rest/v1/call_records?id=eq.${encodeURIComponent(clientCallRecordId)}`, {
        headers: serviceHeaders,
      });
      if (recRes.ok) {
        const records = await recRes.json();
        dbRecord = records[0] ?? null;
      }
    }

    if (!dbRecord && callControlId) {
      const recRes = await checkedWrite(
        `${SUPABASE_URL}/rest/v1/call_records?or=(telnyx_call_session_id.eq.${encodeURIComponent(callControlId)},telnyx_call_control_id_leg_a.eq.${encodeURIComponent(callControlId)},telnyx_call_control_id_leg_b.eq.${encodeURIComponent(callControlId)})`,
        { headers: serviceHeaders },
      );
      if (recRes.ok) {
        const records = await recRes.json();
        dbRecord = records[0] ?? null;
      }
    }

    const callRecordId = dbRecord?.id;
    if (!callRecordId) {
      if (clientCallRecordId) throw new EndpointError(503, "Call correlation pending");
      console.warn(`[telnyx-cdr] No call record matched for callControlId ${callControlId}`);
      return new Response(JSON.stringify({ received: true, matched: false }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      });
    }

    return await withWebhookEvent(db, "telnyx", eventId, callRecordId, event, async () => {
      // Re-read after acquiring the claim: an earlier event may have just completed.
      dbRecord = (await db(`call_records?id=eq.${encodeURIComponent(callRecordId)}`))[0];
      if (!dbRecord) throw new EndpointError(503, "Call correlation pending");
      if (dbRecord?.call_type === "app_to_phone_webrtc") {
        const appId = await fetchSystemConfig("TELNYX_CALL_CONTROL_APP_ID");
        if (String(payload?.connection_id) !== appId) {
          return new Response(JSON.stringify({ error: "Call application mismatch" }), { status: 403 });
        }
        await handleMediaEvent(new CallMedia(SUPABASE_URL, serviceHeaders,
          await fetchSystemConfig("TELNYX_API_KEY"), appId), dbRecord, event, rpc);
        return new Response(JSON.stringify({ received: true }), { status: 200 });
      }

      // Old callback/direct calls have no accepted reservation contract. Keep
      // their authenticated evidence for reconciliation; a CDR cannot authorize
      // spending funds reserved for another operation.
      await checkedWrite(`${SUPABASE_URL}/rest/v1/call_records?id=eq.${encodeURIComponent(callRecordId)}`, {
        method: "PATCH", headers: serviceHeaders,
        body: JSON.stringify({ billing_state: "reconciliation_required",
          reconciliation_reason: "legacy_call_budget", raw_cdr: payload }),
      });
      return new Response(JSON.stringify({ received: true, reconciliationRequired: true }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200,
      });
    });
  } catch (err: any) {
    if (err instanceof EndpointError) return new Response(JSON.stringify({ error: err.message }), { status: err.status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    if (err instanceof ProviderConfigurationError) return new Response(JSON.stringify({ error: err.message, code: err.code }), { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    console.error("[telnyx-cdr] error:", err);
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500,
    });
  }
});
