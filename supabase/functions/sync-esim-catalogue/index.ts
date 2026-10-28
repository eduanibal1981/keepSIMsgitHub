import { acquireEsimSlot } from "../_shared/esimaccess-limiter.js";
import { normalizeEsimAccessOffer } from "../_shared/esimaccess-catalog.js";
// sync-esim-catalogue — pulls eSIM Go and Zendit bundle catalogues into
// `esim_offers_cache`.
//
// The implementations MUST agree on the row transform with servers/worker_esim_catalog.js
// — they write to the same table on the same conflict key.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.108.2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-sync-secret",
};

const ESIM_GO_BASE = Deno.env.get("ESIM_GO_BASE_URL") ?? "https://api.esim-go.com/v2.5";
const ZENDIT_BASE = Deno.env.get("ZENDIT_BASE_URL") ?? "https://api.zendit.io/v1";
const ESIM_ACCESS_BASE = Deno.env.get("ESIM_ACCESS_BASE_URL") ?? "https://api.esimaccess.com/api/v1/open";
const PAGE_SIZE = 200;
const MAX_PAGES = 200; // runaway guard

const SPEED_TIER_BY_GROUP: Record<string, string> = {
  "Standard Fixed": "fixed",
  "Standard Unlimited Lite": "lite",
  "Standard Unlimited Essential": "essential",
  "Standard Unlimited Plus": "plus",
  "Standard Long Duration": "long_duration",
};

const ZENDIT_SPEED_TIER_MAP: Record<string, string> = {
  "Standard": "fixed",
  "standard": "fixed",
  "fixed": "fixed",
  "Fast": "lite",
  "fast": "lite",
  "lite": "lite",
  "Faster": "essential",
  "faster": "essential",
  "essential": "essential",
  "Fastest": "plus",
  "fastest": "plus",
  "plus": "plus",
  "Premium": "plus",
  "premium": "plus",
  "Long Duration": "long_duration",
  "long_duration": "long_duration",
};

const ESIMACCESS_SPEED_TIER_MAP: Record<string, string> = {
  "fixed": "fixed",
  "Fixed": "fixed",
  "3G/4G": "fixed",
  "4G": "fixed",
  "4G/5G": "plus",
  "5G": "plus",
  "lite": "lite",
  "Lite": "lite",
  "essential": "essential",
  "Essential": "essential",
  "plus": "plus",
  "Plus": "plus",
  "Standard": "fixed",
  "standard": "fixed",
  "Fast": "lite",
  "fast": "lite",
  "Faster": "essential",
  "faster": "essential",
  "Fastest": "plus",
  "fastest": "plus",
  "long_duration": "long_duration",
  "Long Duration": "long_duration",
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
function esimGoBundleToRow(bundle: any, provider = "esim_go") {
  if (!bundle || !bundle.name) return null;

  const countries = isoList(bundle.countries);
  const roaming = isoList(bundle.roamingEnabled);
  const all = Array.from(new Set([...countries, ...roaming]));

  const rawData = parseInt(bundle.dataAmount);
  const isUnlimited = bundle.unlimited === true ||
    (Number.isFinite(rawData) && rawData < 0);
  const dataMb = isUnlimited
    ? 0
    : (Number.isFinite(rawData) && rawData > 0 ? rawData : 0);

  const groups: string[] = Array.isArray(bundle.groups) ? bundle.groups : [];
  const bundleGroup = groups.length > 0 ? String(groups[0]) : null;
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
    country_count: all.length,
    is_active: true,
    updated_at: new Date().toISOString(),
  };
}

// deno-lint-ignore no-explicit-any
function zenditOfferToRow(o: any) {
  if (!o || !o.offerId) return null;

  const rawCountries: string[] = [];
  if (o.country && typeof o.country === "string") {
    rawCountries.push(o.country.trim().toUpperCase());
  }

  const roamingCountries: string[] = [];
  if (Array.isArray(o.roaming)) {
    for (const r of o.roaming) {
      if (r && r.country && typeof r.country === "string") {
        const iso = r.country.trim().toUpperCase();
        roamingCountries.push(iso);
        rawCountries.push(iso);
      }
    }
  }

  const allCountries = Array.from(new Set(rawCountries.filter(Boolean)));
  const uniqueRoaming = Array.from(new Set(roamingCountries.filter(Boolean)));

  const isUnlimited = o.dataUnlimited === true || o.dataGB === 0 || o.dataAmount === -1;
  let dataAmountMb = 0;
  if (!isUnlimited) {
    if (typeof o.dataGB === "number" && o.dataGB > 0) {
      dataAmountMb = Math.round(o.dataGB * 1024);
    } else if (typeof o.dataMB === "number" && o.dataMB > 0) {
      dataAmountMb = Math.round(o.dataMB);
    } else if (typeof o.dataAmount === "number" && o.dataAmount > 0) {
      dataAmountMb = Math.round(o.dataAmount);
    }
  }

  const divisor = o.cost?.currencyDivisor || 100;
  const rawCost = o.cost?.fixed != null ? o.cost.fixed : 0;
  const wholesaleCostUsd = parseFloat((rawCost / divisor).toFixed(4));

  const subTypes = Array.isArray(o.subTypes) ? o.subTypes : [];
  const primarySubType = subTypes.length > 0 ? String(subTypes[0]).trim() : null;
  const speedTier = primarySubType ? (ZENDIT_SPEED_TIER_MAP[primarySubType] ?? primarySubType.toLowerCase()) : null;

  const regions = Array.isArray(o.regions) ? o.regions : [];
  const region = regions.length > 0 ? String(regions[0]) : null;

  const description = o.shortNotes || o.notes || o.name || (isUnlimited ? `${o.durationDays || 0} Days Unlimited Data` : `${o.dataGB || 0}GB ${o.durationDays || 0} Days`);

  return {
    provider: "zendit",
    bundle_name: String(o.offerId).trim(),
    description: String(description).trim(),
    countries: allCountries,
    roaming_enabled: uniqueRoaming,
    data_amount_mb: dataAmountMb,
    duration_days: parseInt(o.durationDays) || 0,
    wholesale_price_usd: wholesaleCostUsd,
    image_url: null,
    is_unlimited: isUnlimited,
    bundle_group: primarySubType || "Standard",
    speed_tier: speedTier,
    region: region,
    country_count: allCountries.length,
    is_active: o.enabled !== false,
    updated_at: new Date().toISOString(),
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // deno-lint-ignore no-explicit-any
  const supabase: any = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

  try {
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

    let targetProvider: string | null = null;
    const url = new URL(req.url);
    if (url.searchParams.get("provider")) {
      targetProvider = url.searchParams.get("provider")?.toLowerCase().trim() ?? null;
    } else {
      try {
        const body = await req.json();
        if (body && body.provider) {
          targetProvider = String(body.provider).toLowerCase().trim();
        }
      } catch (_) { /* empty body is ok */ }
    }

    const syncStartedIso = new Date().toISOString();
    const results: Record<string, unknown> = {};

    // ── 1. eSIM Go Sync ─────────────────────────────────────────────────────
    if (!targetProvider || targetProvider === "esim_go") {
      try {
        const { data: esimGoApiKey } = await supabase
          .rpc("get_internal_secret", { p_name: "esim_go_api_key" });

        if (esimGoApiKey) {
          // deno-lint-ignore no-explicit-any
          const raw: any[] = [];
          let page = 1;
          let pageCount = 1;
          let complete = true;

        while (page <= pageCount && page <= MAX_PAGES) {
          const res = await fetch(
            `${ESIM_GO_BASE}/catalogue?perPage=${PAGE_SIZE}&page=${page}`,
            { headers: { "X-API-Key": String(esimGoApiKey), Accept: "application/json" } },
          );
          if (!res.ok) {
            throw new Error(`eSIM Go catalogue page ${page}: HTTP ${res.status}`);
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
          .map((b) => esimGoBundleToRow(b))
          .filter((r) => r !== null && r!.bundle_name && r!.wholesale_price_usd > 0);

        let upserted = 0;
        for (let i = 0; i < rows.length; i += 500) {
          const chunk = rows.slice(i, i + 500);
          const { error } = await supabase
            .from("esim_offers_cache")
            .upsert(chunk, { onConflict: "provider,bundle_name" });
          if (error) throw new Error(`esim_go upsert: ${error.message}`);
          upserted += chunk.length;
        }

        let retired = 0;
        if (complete && rows.length > 0) {
          const { data, error } = await supabase
            .from("esim_offers_cache")
            .update({ is_active: false, updated_at: new Date().toISOString() })
            .eq("provider", "esim_go")
            .eq("is_active", true)
            .lt("updated_at", syncStartedIso)
            .select("bundle_name");
          if (error) throw new Error(`esim_go retirement sweep: ${error.message}`);
          retired = data?.length ?? 0;
        }

        const { data: distinctCountries } = await supabase
          .from("esim_offers_cache")
          .select("countries")
          .eq("provider", "esim_go")
          .eq("is_active", true);

        const countrySet = new Set();
        if (Array.isArray(distinctCountries)) {
          for (const row of distinctCountries) {
            if (Array.isArray(row.countries)) {
              for (const c of row.countries) countrySet.add(c);
            }
          }
        }

        await supabase.from("esim_suppliers").update({
          last_sync_at: new Date().toISOString(),
          last_sync_status: complete ? "ok" : "partial",
          last_sync_count: upserted,
          last_sync_error: null,
          countries_supported: Array.from(countrySet).sort(),
        }).eq("code", "esim_go");

        results.esim_go = { success: true, fetched: raw.length, upserted, retired, complete };
      }
    } catch (esimGoErr) {
      const msg = esimGoErr instanceof Error ? esimGoErr.message : String(esimGoErr);
      await supabase.from("esim_suppliers").update({
        last_sync_at: new Date().toISOString(),
        last_sync_status: "error",
        last_sync_error: msg.slice(0, 500),
      }).eq("code", "esim_go");
      results.esim_go = { success: false, error: msg };
    }
  }

  // ── 2. Zendit Sync ──────────────────────────────────────────────────────
  if (!targetProvider || targetProvider === "zendit") {
    try {
      const { data: zenditApiKey } = await supabase
        .rpc("get_internal_secret", { p_name: "zendit_api_key" });
      const apiSecret = zenditApiKey || Deno.env.get("ZENDIT_API_SECRET");

      if (apiSecret) {
        // deno-lint-ignore no-explicit-any
        const rawZendit: any[] = [];
        let offset = 0;
        let total = Infinity;
        let page = 0;

        while (offset < total && page < MAX_PAGES) {
          const res = await fetch(
            `${ZENDIT_BASE}/esim/offers?_limit=100&_offset=${offset}`,
            { headers: { Authorization: `Bearer ${apiSecret}`, Accept: "application/json" } },
          );
          if (!res.ok) {
            throw new Error(`Zendit eSIM offers page ${page}: HTTP ${res.status}`);
          }
          const json = await res.json();
          total = typeof json.total === "number" ? json.total : (json.list?.length || 0);
          const batch = json.list ?? [];
          rawZendit.push(...batch);
          if (batch.length === 0) break;
          offset += batch.length;
          page++;
        }

        const complete = offset >= total || rawZendit.length >= total;
        const rows = rawZendit
          .map((o) => zenditOfferToRow(o))
          .filter((r) => r !== null && r!.bundle_name && r!.wholesale_price_usd > 0);

        let upserted = 0;
        for (let i = 0; i < rows.length; i += 500) {
          const chunk = rows.slice(i, i + 500);
          const { error } = await supabase
            .from("esim_offers_cache")
            .upsert(chunk, { onConflict: "provider,bundle_name" });
          if (error) throw new Error(`zendit upsert: ${error.message}`);
          upserted += chunk.length;
        }

        let retired = 0;
        if (complete && rows.length > 0) {
          const { data, error } = await supabase
            .from("esim_offers_cache")
            .update({ is_active: false, updated_at: new Date().toISOString() })
            .eq("provider", "zendit")
            .eq("is_active", true)
            .lt("updated_at", syncStartedIso)
            .select("bundle_name");
          if (error) throw new Error(`zendit retirement sweep: ${error.message}`);
          retired = data?.length ?? 0;
        }

        const { data: distinctCountries } = await supabase
          .from("esim_offers_cache")
          .select("countries")
          .eq("provider", "zendit")
          .eq("is_active", true);

        const countrySet = new Set();
        if (Array.isArray(distinctCountries)) {
          for (const row of distinctCountries) {
            if (Array.isArray(row.countries)) {
              for (const c of row.countries) countrySet.add(c);
            }
          }
        }

        await supabase.from("esim_suppliers").update({
          last_sync_at: new Date().toISOString(),
          last_sync_status: complete ? "ok" : "partial",
          last_sync_count: upserted,
          last_sync_error: null,
          countries_supported: Array.from(countrySet).sort(),
        }).eq("code", "zendit");

        results.zendit = { success: true, fetched: rawZendit.length, upserted, retired, complete };
      }
    } catch (zenditErr) {
      const msg = zenditErr instanceof Error ? zenditErr.message : String(zenditErr);
      await supabase.from("esim_suppliers").update({
        last_sync_at: new Date().toISOString(),
        last_sync_status: "error",
        last_sync_error: msg.slice(0, 500),
      }).eq("code", "zendit");
      results.zendit = { success: false, error: msg };
    }
  }

  // ── 3. eSIM Access Sync ─────────────────────────────────────────────────
  if (!targetProvider || targetProvider === "esimaccess") {
    try {
      const { data: esimAccessCodeSecret } = await supabase
        .rpc("get_internal_secret", { p_name: "esim_access_access_code" });
      const { data: esimAccessKeySecret } = await supabase
        .rpc("get_internal_secret", { p_name: "esim_access_secret_key" });

      const accessCode = esimAccessCodeSecret || Deno.env.get("ESIM_ACCESS_ACCESS_CODE");
      const secretKey = esimAccessKeySecret || Deno.env.get("ESIM_ACCESS_SECRET_KEY");

      if (accessCode) {
        const headers: Record<string, string> = {
          "RT-AccessCode": String(accessCode),
          "Content-Type": "application/json",
          "Accept": "application/json",
        };
        if (secretKey) {
          headers["secretKey"] = String(secretKey);
        }

        await acquireEsimSlot(supabase);
        const res = await fetch(`${ESIM_ACCESS_BASE}/package/list`, {
          method: "POST",
          headers,
          body: JSON.stringify({ type: "BASE" }),
        });

        if (!res.ok) {
          throw new Error(`eSIM Access package list: HTTP ${res.status}`);
        }

        const json = await res.json();
        // deno-lint-ignore no-explicit-any
        const rawPackages: any[] = (json.obj && Array.isArray(json.obj.packageList)) ? json.obj.packageList : [];

        const rows = rawPackages
          .map((p) => normalizeEsimAccessOffer(p))
          .filter((r) => r !== null && r!.bundle_name && r!.wholesale_price_usd > 0);

        let upserted = 0;
        for (let i = 0; i < rows.length; i += 500) {
          const chunk = rows.slice(i, i + 500);
          const { error } = await supabase
            .from("esim_offers_cache")
            .upsert(chunk, { onConflict: "provider,bundle_name" });
          if (error) throw new Error(`esimaccess upsert: ${error.message}`);
          upserted += chunk.length;
        }

        let retired = 0;
        if (rows.length > 0) {
          const { data, error } = await supabase
            .from("esim_offers_cache")
            .update({ is_active: false, updated_at: new Date().toISOString() })
            .eq("provider", "esimaccess")
            .eq("is_active", true)
            .lt("updated_at", syncStartedIso)
            .select("bundle_name");
          if (error) throw new Error(`esimaccess retirement sweep: ${error.message}`);
          retired = data?.length ?? 0;
        }

        const { data: distinctCountries } = await supabase
          .from("esim_offers_cache")
          .select("countries")
          .eq("provider", "esimaccess")
          .eq("is_active", true);

        const countrySet = new Set();
        if (Array.isArray(distinctCountries)) {
          for (const row of distinctCountries) {
            if (Array.isArray(row.countries)) {
              for (const c of row.countries) countrySet.add(c);
            }
          }
        }

        await supabase.from("esim_suppliers").update({
          last_sync_at: new Date().toISOString(),
          last_sync_status: "ok",
          last_sync_count: upserted,
          last_sync_error: null,
          countries_supported: Array.from(countrySet).sort(),
        }).eq("code", "esimaccess");

        results.esimaccess = { success: true, fetched: rawPackages.length, upserted, retired, complete: true };
      }
    } catch (esimAccessErr) {
      const msg = esimAccessErr instanceof Error ? esimAccessErr.message : String(esimAccessErr);
      await supabase.from("esim_suppliers").update({
        last_sync_at: new Date().toISOString(),
        last_sync_status: "error",
        last_sync_error: msg.slice(0, 500),
      }).eq("code", "esimaccess");
      results.esimaccess = { success: false, error: msg };
    }
  }

  return new Response(
    JSON.stringify({ success: true, results }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
} catch (err) {
  const message = err instanceof Error ? err.message : String(err);
  return new Response(JSON.stringify({ success: false, error: message }), {
    status: 500,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
});
