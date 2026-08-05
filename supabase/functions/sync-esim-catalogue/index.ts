// sync-esim-catalogue — pulls the whole eSIM Go bundle catalogue into
// `esim_offers_cache`.
//
// Why this exists when `servers/worker_esim_catalog.js` already does the job:
// that worker lives on the owner-gated VM, so a catalogue fix could not reach
// production without a manual deploy. The same fetch here is reachable from the
// admin app (via `admin_sync_esim_catalogue()`) and from pg_cron. This is the
// fifth feature in the project to route around the VM for the same reason.
//
// The two implementations MUST agree on the row transform. If you change
// `bundleToRow` below, change `esimCatalogRow` in the worker to match — they
// write to the same table on the same conflict key.
//
// Credentials: the eSIM Go token is read from Vault, never from an Edge
// Function secret or a request body. A function that accepts a supplier API key
// from its caller is an open proxy to that supplier.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-sync-secret",
};

const ESIM_GO_BASE = Deno.env.get("ESIM_GO_BASE_URL") ?? "https://api.esim-go.com/v2.5";
const PAGE_SIZE = 200;
const MAX_PAGES = 200; // runaway guard

// eSIM Go grades unlimited bundles by throughput and sells the same
// country/duration at three prices because of it.
const SPEED_TIER_BY_GROUP: Record<string, string> = {
  "Standard Fixed": "fixed",
  "Standard Unlimited Lite": "lite",
  "Standard Unlimited Essential": "essential",
  "Standard Unlimited Plus": "plus",
  "Standard Long Duration": "long_duration",
};

// deno-lint-ignore no-explicit-any
function isoList(arr: any): string[] {
  if (!Array.isArray(arr)) return [];
  return arr
    .map((item) => {
      if (typeof item === "string") return item.toUpperCase();
      if (item && item.iso) return String(item.iso).toUpperCase();
      return null;
    })
    .filter((x): x is string => Boolean(x));
}

// deno-lint-ignore no-explicit-any
function bundleToRow(bundle: any, provider = "esim_go") {
  if (!bundle || !bundle.name) return null;

  const countries = isoList(bundle.countries);
  const roaming = isoList(bundle.roamingEnabled);
  const all = Array.from(new Set([...countries, ...roaming]));

  // `unlimited: true` arrives with `dataAmount: -1`. The flag carries the
  // meaning; the number is normalised to 0 so nothing downstream has to know
  // about one supplier's sentinel value.
  const rawData = parseInt(bundle.dataAmount);
  const isUnlimited = bundle.unlimited === true ||
    (Number.isFinite(rawData) && rawData < 0);
  const dataMb = isUnlimited
    ? 0
    : (Number.isFinite(rawData) && rawData > 0 ? rawData : 0);

  const groups: string[] = Array.isArray(bundle.groups) ? bundle.groups : [];
  const bundleGroup = groups.length > 0 ? String(groups[0]) : null;
  // Unknown group -> null, never a guessed tier. A wrong tier is a false claim
  // about the speed someone paid for, and the column CHECK would reject it.
  const speedTier = bundleGroup ? (SPEED_TIER_BY_GROUP[bundleGroup] ?? null) : null;

  // deno-lint-ignore no-explicit-any
  const withRegion = (Array.isArray(bundle.countries) ? bundle.countries : [])
    .find((c: any) => c && c.region);

  return {
    provider,
    bundle_name: String(bundle.name).trim(),
    description: bundle.description || "",
    countries: all,
    roaming_enabled: roaming,
    data_amount_mb: dataMb,
    duration_days: parseInt(bundle.duration) || 0,
    wholesale_price_usd: parseFloat(bundle.price) || 0.0,
    image_url: bundle.imageUrl || bundle.image_url || null,
    is_unlimited: isUnlimited,
    bundle_group: bundleGroup,
    speed_tier: speedTier,
    region: withRegion ? String(withRegion.region) : null,
    is_active: true,
    updated_at: new Date().toISOString(),
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

  try {
    // ── Auth ────────────────────────────────────────────────────────────────
    // verify_jwt lets any anon-key holder in, and the anon key ships inside the
    // APK, so the shared secret is the real gate. Compared against Vault, not
    // an env var, so rotating it is one UPDATE with no redeploy.
    const { data: expected, error: secretErr } = await supabase
      .rpc("get_internal_secret", { p_name: "esim_catalogue_sync_secret" });
    if (secretErr) throw new Error(`secret read failed: ${secretErr.message}`);

    const presented = req.headers.get("x-sync-secret") ?? "";
    if (!expected || presented !== expected) {
      return new Response(JSON.stringify({ error: "forbidden" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: apiKey, error: keyErr } = await supabase
      .rpc("get_internal_secret", { p_name: "esim_go_api_key" });
    if (keyErr) throw new Error(`api key read failed: ${keyErr.message}`);
    if (!apiKey) throw new Error("esim_go_api_key is not present in Vault");

    const syncStartedIso = new Date().toISOString();

    // ── Walk every page ─────────────────────────────────────────────────────
    // deno-lint-ignore no-explicit-any
    const raw: any[] = [];
    let page = 1;
    let pageCount = 1;
    let complete = true;

    while (page <= pageCount && page <= MAX_PAGES) {
      const res = await fetch(
        `${ESIM_GO_BASE}/catalogue?perPage=${PAGE_SIZE}&page=${page}`,
        { headers: { "X-API-Key": String(apiKey), Accept: "application/json" } },
      );
      if (!res.ok) {
        throw new Error(`catalogue page ${page}: HTTP ${res.status} ${await res.text()}`);
      }
      const json = await res.json();
      const batch = json.bundles ?? [];
      raw.push(...batch);
      pageCount = parseInt(json.pageCount) || 1;
      if (batch.length === 0) break;
      page++;
    }
    if (page > MAX_PAGES && page <= pageCount) complete = false;

    const rows = raw
      .map((b) => bundleToRow(b))
      .filter((r) => r !== null && r!.bundle_name && r!.wholesale_price_usd > 0);

    // ── Upsert ──────────────────────────────────────────────────────────────
    let upserted = 0;
    for (let i = 0; i < rows.length; i += 500) {
      const chunk = rows.slice(i, i + 500);
      const { error } = await supabase
        .from("esim_offers_cache")
        .upsert(chunk, { onConflict: "provider,bundle_name" });
      if (error) throw new Error(`upsert at offset ${i}: ${error.message}`);
      upserted += chunk.length;
    }

    // ── Retirement sweep ────────────────────────────────────────────────────
    // Upsert can only add. A withdrawn bundle would stay purchasable, and the
    // buyer would find out only when fulfilment failed after their wallet was
    // debited.
    //
    // Gated on BOTH a complete walk and a non-empty result. Either alone is
    // insufficient: `complete` is also true for a successful fetch that
    // returned nothing, which would retire the entire catalogue.
    let retired = 0;
    if (complete && rows.length > 0) {
      const { data, error } = await supabase
        .from("esim_offers_cache")
        .update({ is_active: false, updated_at: new Date().toISOString() })
        .eq("provider", "esim_go")
        .eq("is_active", true)
        .lt("updated_at", syncStartedIso)
        .select("bundle_name");
      if (error) throw new Error(`retirement sweep: ${error.message}`);
      retired = data?.length ?? 0;
    }

    await supabase.from("esim_suppliers").update({
      last_sync_at: new Date().toISOString(),
      last_sync_status: complete ? "ok" : "partial",
      last_sync_count: upserted,
      last_sync_error: null,
    }).eq("code", "esim_go");

    return new Response(
      JSON.stringify({
        success: true,
        pages: page - 1,
        page_count: pageCount,
        complete,
        fetched: raw.length,
        upserted,
        retired,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    await supabase.from("esim_suppliers").update({
      last_sync_at: new Date().toISOString(),
      last_sync_status: "error",
      last_sync_error: message.slice(0, 500),
    }).eq("code", "esim_go");

    return new Response(JSON.stringify({ success: false, error: message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
