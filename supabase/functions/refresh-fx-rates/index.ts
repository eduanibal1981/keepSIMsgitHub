// ============================================================================
// refresh-fx-rates — G11b
//
// Pulls USD-based quotes once a day and hands them to `refresh_fx_rates()`,
// which does all the deciding. This function deliberately knows nothing about
// bands, staleness or which currencies exist: those rules live in SQL next to
// the trigger that enforces them, so nothing can route around them.
//
// Invoked by pg_cron via `kick_fx_refresh()` with the Vault shared secret in
// `x-keep-sims-secret` — the same handshake as dispatch-alert and
// purge-accounts, which is why verify_jwt is off.
// ============================================================================
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-keep-sims-secret",
};

// Keyless, USD-based, and reports when its own quotes were taken — which is
// what `refresh_fx_rates` measures staleness from. If this provider is ever
// swapped, the only contract to preserve is {rates, taken-at}.
const FX_ENDPOINT = "https://open.er-api.com/v6/latest/USD";
const FX_SOURCE = "open.er-api.com";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const adminClient = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // ── Shared-secret handshake ────────────────────────────────────────────
    const incomingSecret = req.headers.get("x-keep-sims-secret");
    const { data: secretData } = await adminClient.rpc("get_internal_secret", {
      p_name: "dispatch_shared_secret",
    });
    const expectedSecret = secretData || "";
    if (!expectedSecret || incomingSecret !== expectedSecret) {
      return json(
        { success: false, error: "UNAUTHORIZED: Invalid secret header" },
        401,
      );
    }

    // ── Fetch ──────────────────────────────────────────────────────────────
    let payload: Record<string, unknown>;
    try {
      const res = await fetch(FX_ENDPOINT, {
        headers: { "Accept": "application/json" },
        signal: AbortSignal.timeout(15000),
      });
      if (!res.ok) {
        return json(
          { success: false, error: `PROVIDER_HTTP_${res.status}` },
          502,
        );
      }
      payload = await res.json();
    } catch (e) {
      // A dead provider is not an emergency: the rates already in the table
      // simply keep ageing, and G11's staleness rule drops every user back to
      // plain USD once they pass FX_MAX_AGE_HOURS. Fail loudly, change nothing.
      return json(
        { success: false, error: `PROVIDER_UNREACHABLE: ${String(e)}` },
        502,
      );
    }

    // ── Validate before trusting a single number ───────────────────────────
    if (payload.result !== "success") {
      return json(
        { success: false, error: `PROVIDER_RESULT: ${String(payload.result)}` },
        502,
      );
    }
    if (payload.base_code !== "USD") {
      // An inverted or rebased payload is the classic way to silently multiply
      // every price in the app. Refuse rather than guess.
      return json(
        { success: false, error: `PROVIDER_BASE: ${String(payload.base_code)}` },
        502,
      );
    }
    const rates = payload.rates;
    if (!rates || typeof rates !== "object") {
      return json({ success: false, error: "PROVIDER_NO_RATES" }, 502);
    }
    const unix = Number(payload.time_last_update_unix);
    if (!Number.isFinite(unix) || unix <= 0) {
      return json({ success: false, error: "PROVIDER_NO_TIMESTAMP" }, 502);
    }
    const asOf = new Date(unix * 1000).toISOString();

    // Sanity anchor: a USD-based payload must quote USD at exactly 1. If it
    // does not, the whole document means something other than what we assume.
    const usdSelf = Number((rates as Record<string, unknown>).USD);
    if (!Number.isFinite(usdSelf) || Math.abs(usdSelf - 1) > 1e-9) {
      return json(
        { success: false, error: `PROVIDER_USD_NOT_UNITY: ${usdSelf}` },
        502,
      );
    }

    // ── Hand off. SQL decides what is acceptable. ──────────────────────────
    const { data, error } = await adminClient.rpc("refresh_fx_rates", {
      p_rates: rates,
      p_as_of: asOf,
      p_source: FX_SOURCE,
    });

    if (error) {
      return json({ success: false, error: error.message }, 500);
    }

    return json({ success: true, report: data });
  } catch (e) {
    return json({ success: false, error: String(e) }, 500);
  }
});
