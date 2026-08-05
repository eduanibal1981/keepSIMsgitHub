// sync-affiliate-network — pulls conversions from affiliate networks into
// `affiliate_conversions` and matches them to our own click log.
//
// Without this, a click is recorded, the user buys on the partner's site, and
// the commission is never reconciled — the rail logs traffic and reports no
// money.
//
// ── Impact ──────────────────────────────────────────────────────────────────
// Uses the READ-ONLY credential pair. Everything here is a read, and the
// read-write pair is deliberately not stored anywhere.
//
// Endpoint is `/Reports/mp_action_listing_fast`, not `/Actions`, for one
// reason: the report's column names were read from its own `/MetaData`
// endpoint and are therefore verified, whereas the `/Actions` object shape was
// not observable (the account has zero actions so far). Verified columns:
//   action_date, action_id, promo_code, Subid1, Subid2, Subid3, Sharedid,
//   Campaign, action_tracker, Status, status_detail, sale_amount, Payout, Tax
//
// ⚠️ THE STATUS AND AMOUNT MAPPING IS UNVERIFIED AGAINST A REAL CONVERSION.
// This account has never had one, so no live row has ever passed through
// `normaliseAction`. Diff a real record against it before trusting the numbers
// — the Zendit fallback shipped broken in four ways at B1 for exactly this
// reason. Every record's raw payload is stored in `affiliate_conversions.raw`
// so nothing is lost if a field name turns out to differ.
//
// Impact enforces a hard 45-day maximum between ActionDateStart and
// ActionDateEnd, so the window is chunked rather than requested in one span.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-sync-secret",
};

const IMPACT_BASE = "https://api.impact.com";
const MAX_WINDOW_DAYS = 45; // Impact's own limit; exceeding it is a hard error.

/** Impact status strings -> our four-state enum. */
function normaliseStatus(raw: unknown): string {
  const s = String(raw ?? "").toUpperCase();
  if (s.includes("REVERS")) return "reversed";
  if (s.includes("REJECT")) return "rejected";
  if (s.includes("APPROV")) return "approved";
  // Anything unrecognised is PENDING, never approved. Guessing "approved"
  // would book revenue we may never receive.
  return "pending";
}

function toNumber(v: unknown): number | null {
  if (v === null || v === undefined || v === "") return null;
  const n = Number(String(v).replace(/[^0-9.\-]/g, ""));
  return Number.isFinite(n) ? n : null;
}

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// deno-lint-ignore no-explicit-any
function normaliseAction(rec: any) {
  // Subid1 is the click id we generated. Anything that is not a uuid did not
  // come from us — a partner's own traffic, or a link someone hand-edited — so
  // it is left unmatched rather than guessed at.
  const sub = String(rec.Subid1 ?? rec.SubId1 ?? "").trim();
  const clickId = UUID_RE.test(sub) ? sub.toLowerCase() : null;

  const actionId = String(rec.action_id ?? rec.ActionId ?? rec.Id ?? "").trim();
  if (!actionId) return null;

  return {
    external_action_id: actionId,
    click_id: clickId,
    status: normaliseStatus(rec.Status ?? rec.State),
    sale_amount_usd: toNumber(rec.sale_amount ?? rec.Amount),
    commission_usd: toNumber(rec.Payout ?? rec.PayoutAmount),
    occurred_at: rec.action_date ?? rec.EventDate ?? null,
    raw: rec,
  };
}

function windows(sinceDays: number): Array<[string, string]> {
  const out: Array<[string, string]> = [];
  const end = new Date();
  let cursor = new Date(end.getTime() - sinceDays * 86400000);
  while (cursor < end) {
    const stop = new Date(
      Math.min(cursor.getTime() + MAX_WINDOW_DAYS * 86400000, end.getTime()),
    );
    out.push([cursor.toISOString().slice(0, 10), stop.toISOString().slice(0, 10)]);
    cursor = new Date(stop.getTime() + 86400000);
  }
  return out;
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
    const { data: expected } = await supabase
      .rpc("get_internal_secret", { p_name: "affiliate_sync_secret" });
    if (!expected || (req.headers.get("x-sync-secret") ?? "") !== expected) {
      return new Response(JSON.stringify({ error: "forbidden" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json().catch(() => ({}));
    const sinceDays = Math.min(Math.max(Number(body.since_days ?? 45), 1), 365);

    // Only networks the owner has switched on. A disabled network is not
    // polled, so enabling one is a single row change.
    const { data: networks, error: netErr } = await supabase
      .from("affiliate_networks")
      .select("code, credential_secret, is_active")
      .eq("is_active", true);
    if (netErr) throw new Error(`networks: ${netErr.message}`);

    const report: Record<string, unknown> = {};

    for (const net of networks ?? []) {
      if (net.code !== "impact") {
        // Affilae is seeded but not wired: app.affilae.com/api/* serves the SPA
        // shell for every path, so no endpoint has been verified. Skipping
        // loudly beats inventing a request that silently 200s with HTML.
        report[net.code] = { skipped: "no verified reader for this network" };
        continue;
      }

      const { data: credRaw } = await supabase
        .rpc("get_internal_secret", { p_name: net.credential_secret });
      if (!credRaw) {
        report[net.code] = { error: `${net.credential_secret} missing from Vault` };
        continue;
      }
      const cred = JSON.parse(String(credRaw));
      const auth = "Basic " + btoa(`${cred.account_sid}:${cred.auth_token}`);

      const { data: partners } = await supabase
        .from("affiliate_partners")
        .select("id, code, external_campaign_id")
        .eq("network_code", net.code);

      const byCampaign = new Map<string, string>();
      for (const p of partners ?? []) {
        if (p.external_campaign_id) byCampaign.set(String(p.external_campaign_id), p.id);
      }
      // Single-partner networks can attribute unambiguously even when the
      // report omits a campaign id.
      const solePartner = (partners ?? []).length === 1 ? partners![0].id : null;

      let fetched = 0, upserted = 0, matched = 0, unmatched = 0;

      for (const [start, end] of windows(sinceDays)) {
        const url =
          `${IMPACT_BASE}/Mediapartners/${cred.account_sid}/Reports/mp_action_listing_fast` +
          `?START_DATE=${start}&END_DATE=${end}`;
        const res = await fetch(url, {
          headers: { Authorization: auth, Accept: "application/json" },
        });
        if (!res.ok) {
          throw new Error(`impact report ${start}..${end}: HTTP ${res.status} ${await res.text()}`);
        }
        const json = await res.json();
        const records = json.Records ?? [];
        fetched += records.length;

        // deno-lint-ignore no-explicit-any
        const rows = records.map((r: any) => {
          const n = normaliseAction(r);
          if (!n) return null;
          const partnerId = byCampaign.get(String(r.Campaign ?? "")) ?? solePartner;
          if (n.click_id) matched++; else unmatched++;
          return { ...n, network_code: net.code, partner_id: partnerId };
        }).filter(Boolean);

        if (rows.length > 0) {
          // Idempotent on (network_code, external_action_id): Impact restates
          // an action as it moves PENDING -> APPROVED -> REVERSED, and each
          // restatement must update the same row, never add another.
          const { error } = await supabase
            .from("affiliate_conversions")
            .upsert(rows, { onConflict: "network_code,external_action_id" });
          if (error) throw new Error(`upsert: ${error.message}`);
          upserted += rows.length;
        }
      }

      report[net.code] = { fetched, upserted, matched_to_click: matched, unmatched };
    }

    return new Response(JSON.stringify({ success: true, since_days: sinceDays, report }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
