import { ProviderConfigurationError, requireProviderSecret } from "../_shared/provider-secrets.ts";
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

  if (req.method !== "POST") return new Response("Method not allowed", { status: 405, headers: corsHeaders });

  try {
    // 1. Authenticate the caller
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 401,
      });
    }

    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) throw new ProviderConfigurationError();
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

    if (action === "start") {
      const { simLineId } = body;
      const method = ["missed_call", "call"].includes(body.method) ? "voice" : body.method;
      const key = body.idempotencyKey;
      if (!simLineId || !["sms", "voice"].includes(method) || typeof key !== "string" || !key.trim() || key.length > 200) {
        return new Response(JSON.stringify({ error: "Line, method and idempotency key required" }), { status: 400, headers: corsHeaders });
      }
      // Validate configuration before atomically reserving and creating an attempt.
      const apiKey = await requireProviderSecret(supabase, "TELNYX_API_KEY");
      const appId = method === "voice" ? await fetchConfig(supabase, "TELNYX_CALL_CONTROL_APP_ID") : "";
      const caller = method === "voice" ? await fetchConfig(supabase, "TELNYX_DEFAULT_CALLER_ID") : "";
      const profile = method === "sms" ? await fetchConfig(supabase, "TELNYX_MESSAGING_PROFILE_ID") : "";
      if (method === "voice" ? (!appId || !caller) : !profile) throw new ProviderConfigurationError();
      const { data: reservation, error } = await supabase.rpc("begin_line_verification", {
        p_user_id: user.id, p_sim_line_id: simLineId, p_method: method, p_idempotency_key: key,
      });
      if (error || !reservation?.attempt) {
        return new Response(JSON.stringify({ error: "Unable to reserve verification" }), { status: 409, headers: corsHeaders });
      }
      const attempt = reservation.attempt;
      const result = () => new Response(JSON.stringify({ success: true, attemptId: attempt.id,
        status: attempt.status, outcome: attempt.outcome, settlementStatus: attempt.settlement_status,
        method: attempt.method, resourceId: attempt.provider_resource_id }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      if (!reservation.dispatch) return result();
      const callback = `${SUPABASE_URL}/functions/v1/liveness-verification-webhook`;
      const destination = attempt.destination_phone.replace(/\s+/g, "");
      const payload = method === "voice" ? {
        connection_id: appId, to: destination, from: caller,
        client_state: btoa(JSON.stringify({ attemptId: attempt.id })), webhook_url: callback,
        timeout_secs: 30, send_ringing_webhook: true,
      } : {
        from: "KeepSIMs", to: destination, text: "KeepSIMs line verification check.",
        messaging_profile_id: profile, webhook_url: callback,
      };
      // An unknown dispatch outcome never releases money or permits resubmission.
      // Only a definitive provider rejection can release an undispatched attempt.
      try {
        const response = await fetch(`https://api.telnyx.com/v2/${method === "voice" ? "calls" : "messages"}`, {
          method: "POST", headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
          body: JSON.stringify(payload), signal: AbortSignal.timeout(15000),
        });
        if (!response.ok) {
          if ([400, 401, 403, 404, 422].includes(response.status)) {
            const { data, error: settlementError } = await supabase.rpc("settle_line_verification_event", {
              p_attempt_id: attempt.id, p_provider: null, p_resource_id: null,
              p_event_type: "dispatch.rejected", p_outcome: "failed", p_error_message: "Provider rejected dispatch",
            });
            if (settlementError || data?.success !== true) throw Error("Settlement unavailable");
            return new Response(JSON.stringify({ error: "Provider rejected verification", attemptId: attempt.id }), { status: 502, headers: corsHeaders });
          }
          throw Error("Dispatch outcome unknown");
        }
        const data = await response.json();
        const resource = method === "voice" ? data?.data?.call_control_id : data?.data?.id;
        if (typeof resource !== "string" || !resource) throw Error("Provider identity unavailable");
        const { data: bound, error: bindError } = await supabase.rpc("bind_line_verification_resource", {
          p_attempt_id: attempt.id, p_resource_id: resource,
        });
        if (bindError || bound?.success !== true) throw Error("Provider binding unavailable");
        attempt.status = "pending"; attempt.provider_resource_id = resource;
        return result();
      } catch (_) {
        const { error: persistenceError } = await supabase.from("line_verification_attempts")
          .update({ status: "reconciliation_required", settlement_status: "reconciliation_required",
            error_message: "Dispatch outcome requires provider reconciliation" })
          .eq("id", attempt.id).eq("status", "dispatching");
        return new Response(JSON.stringify({ error: persistenceError ? "Verification tracking unavailable" : "Verification awaiting provider reconciliation",
          attemptId: attempt.id, status: "reconciliation_required" }), { status: 503, headers: corsHeaders });
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
        isSuccess: attempt.evidence_version === 1 && attempt.status === "terminal" && attempt.outcome === "succeeded",
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
      const suppliedResource = body.callSid || body.callControlId || body.resourceId;
      if (!body.attemptId && !suppliedResource) {
        return new Response(JSON.stringify({ error: "Missing attempt identifier" }), { status: 400, headers: corsHeaders });
      }
      let query = supabase.from("line_verification_attempts").select("*").eq("user_id", user.id).eq("method", "voice");
      query = body.attemptId ? query.eq("id", body.attemptId) : query.eq("provider_resource_id", suppliedResource);
      const { data: attempt, error } = await query.maybeSingle();
      if (error || !attempt || !attempt.provider_resource_id ||
          (suppliedResource && suppliedResource !== attempt.provider_resource_id)) {
        return new Response(JSON.stringify({ error: "Attempt not found" }), { status: 404, headers: corsHeaders });
      }
      if (attempt.status === "terminal") return new Response(JSON.stringify({ success: true, alreadyTerminal: true }), { headers: corsHeaders });
      // Use exactly the stored provider and resource. Never try another provider.
      let response: Response;
      const resource = encodeURIComponent(attempt.provider_resource_id);
      if (attempt.provider === "telnyx") {
        const key = await requireProviderSecret(supabase, "TELNYX_API_KEY");
        response = await fetch(`https://api.telnyx.com/v2/calls/${resource}/actions/hangup`, {
          method: "POST", headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
          body: JSON.stringify({ command_id: attempt.id }),
        });
      } else if (attempt.provider === "twilio") {
        const sid = await requireProviderSecret(supabase, "TWILIO_ACCOUNT_SID");
        const token = await requireProviderSecret(supabase, "TWILIO_AUTH_TOKEN");
        response = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${encodeURIComponent(sid)}/Calls/${resource}.json`, {
          method: "POST", headers: { Authorization: `Basic ${btoa(`${sid}:${token}`)}`,
            "Content-Type": "application/x-www-form-urlencoded" }, body: new URLSearchParams({ Status: "completed" }).toString(),
        });
      } else {
        return new Response(JSON.stringify({ error: "Unsupported attempt provider" }), { status: 409, headers: corsHeaders });
      }
      return new Response(JSON.stringify({ success: response.ok, provider: attempt.provider }), {
        status: response.ok ? 200 : 503, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ error: `Unknown action: ${action}` }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err instanceof ProviderConfigurationError ? err.message : "Verification request failed", code: err instanceof ProviderConfigurationError ? err.code : "INTERNAL_ERROR" }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: err instanceof ProviderConfigurationError ? 503 : 500,
    });
  }
});
