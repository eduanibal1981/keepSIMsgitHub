// worker_voucher_stock.js — buys recharge PINs from DingConnect for the
// offline voucher rail (L phase).
//
// This is the ONLY process in the product that spends money with no subscriber
// in the loop, so its shape is deliberately conservative:
//
//   * It does nothing until an operator queues a job in keep_sims_admin. There
//     is no auto-replenish. `OFFLINE_VOUCHER_DING_ENABLED` gates both the
//     queueing RPC and `claim_voucher_purchase_job()`, so flipping the switch
//     off stops work already sitting in the queue, not just new work.
//   * It buys ONE PIN first and stops if the receipt cannot be parsed. Every
//     Ding PIN arrives inside a "provider specific" ReceiptText whose shape no
//     one here has ever seen; buying fifty against an unproven parser would
//     turn one unreadable receipt into fifty.
//   * A per-job cost ceiling is checked here AND again in
//     `record_voucher_purchase_result`. This file is editable by anyone with
//     shell access on the VM; the row is not.
//
// It lives on the VM because `DING_API_KEY` lives in `servers/.env` and nowhere
// else — not in Vault, not in Edge Function secrets, not in the repo.
//
// Run:  node servers/worker_voucher_stock.js
// Once: node servers/worker_voucher_stock.js --once

const ding = require('./providers/ding');

const POLL_INTERVAL_MS = parseInt(process.env.VOUCHER_STOCK_POLL_MS) || 60 * 1000;
const PURCHASE_DELAY_MS = parseInt(process.env.VOUCHER_STOCK_PURCHASE_DELAY_MS) || 1500;

const dingBaseUrl = process.env.DING_BASE_URL || 'https://api.dingconnect.com/api/V1';

// `dotenv` and `@supabase/supabase-js` are installed on the VM and nowhere else
// — there is no node_modules in this repo. Requiring them at module scope would
// make this file unimportable, and therefore untestable, on a dev workstation.
// Everything above this line is pure; everything that needs the network goes
// through here.
let _supabase = null;
function getSupabase() {
  if (_supabase) return _supabase;

  require('dotenv').config({ path: require('path').join(__dirname, '.env') });
  const { createClient } = require('@supabase/supabase-js');

  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) {
    throw new Error('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in servers/.env');
  }

  _supabase = createClient(url, key);
  return _supabase;
}

const dingApiKey = () => process.env.DING_API_KEY;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ── FX ────────────────────────────────────────────────────────────────────
// Ding quotes SendValue in the ACCOUNT's settlement currency — OMR on the live
// account, verified against a real GetProducts response (see providers/ding.js).
// Treating that as USD understates every cost by ~2.6x, and the cost is what
// the per-job ceiling is checked against, so an unconverted number would sail
// straight through the guard that exists to stop overspending.
//
// `fx_rates_for_costing` has already applied the staleness policy. A currency it
// refuses is a currency we refuse to buy in — not one we price optimistically.
async function loadFxRates() {
  const { data, error } = await getSupabase()
    .from('fx_rates_for_costing')
    .select('currency_code, usd_to_local, unusable_reason');

  if (error) throw new Error(`Failed to read fx_rates_for_costing: ${error.message}`);

  const rates = {};
  for (const row of data || []) {
    if (row.unusable_reason) continue;
    const n = Number(row.usd_to_local);
    if (Number.isFinite(n) && n > 0) rates[String(row.currency_code).toUpperCase()] = n;
  }
  return rates;
}

function toUsd(amount, currency, rates) {
  if (amount == null) return null;
  const ccy = String(currency || 'USD').toUpperCase();
  if (ccy === 'USD') return Number(amount);
  const rate = rates[ccy];
  if (!rate) return null; // unknown or stale ⇒ unpriceable, never assumed
  return Number(amount) / rate;
}

// ── One job ───────────────────────────────────────────────────────────────
async function runJob(job, rates) {
  const {
    id, carrier_id: carrierId, provider_carrier_code: carrierCode,
    country_iso: countryIso, quantity, max_unit_cost_usd: maxUnitCost,
    account_number: accountNumber,
  } = job;

  console.log(`[voucher] job ${id}: ${quantity} PIN(s) for ${carrierCode}/${countryIso}, cap $${maxUnitCost}`);

  if (!dingApiKey()) {
    return report(id, [], 'DING_API_KEY is not set on this VM');
  }
  if (!accountNumber) {
    // Ding requires an AccountNumber even for a PIN SKU. Rather than invent one
    // — which would deliver airtime to a stranger's handset — refuse and say so.
    return report(id, [], 'This job has no account_number, and Ding requires one even for PIN products');
  }

  let products;
  try {
    products = await ding.fetchPinProducts({
      baseUrl: dingBaseUrl, apiKey: dingApiKey(),
      countryCode: countryIso, carrierCode,
    });
  } catch (err) {
    return report(id, [], `GetProducts failed: ${err.message}`);
  }

  if (products.length === 0) {
    return report(id, [],
      `DingConnect lists no PIN (RedemptionMechanism=ReadReceipt) products for ${carrierCode}. `
      + 'This carrier has to be stocked by hand.');
  }

  // Cheapest PIN inside the ceiling. "Minimum recharge PIN" is the product
  // brief; the ceiling is what stops a mis-parsed price being one of them.
  let chosen = null;
  let chosenCostUsd = null;
  for (const p of products) {
    const usd = toUsd(p.sendValue, p.sendCurrency, rates);
    if (usd == null) {
      console.warn(`[voucher] skipping ${p.skuCode}: no usable FX rate for ${p.sendCurrency}`);
      continue;
    }
    if (usd > Number(maxUnitCost)) continue;
    chosen = p;
    chosenCostUsd = usd;
    break;
  }

  if (!chosen) {
    const cheapest = products[0];
    return report(id, [],
      `No PIN product at or under $${maxUnitCost}. Cheapest is ${cheapest.skuCode} `
      + `at ${cheapest.sendValue} ${cheapest.sendCurrency}. Raise the cap or stock by hand.`);
  }

  const faceValueUsd = round2(chosenCostUsd);
  const pins = [];
  let parseFailureRef = null;

  for (let i = 0; i < quantity; i++) {
    const distributorRef = `v_${id}_${i}`;
    let result;
    try {
      result = await ding.purchasePin({
        baseUrl: dingBaseUrl, apiKey: dingApiKey(),
        skuCode: chosen.skuCode,
        sendValue: chosen.sendValue,
        accountNumber,
        distributorRef,
      });
    } catch (err) {
      // Stop on the first failure. Continuing would keep charging an account
      // that has already told us something is wrong.
      return report(id, pins, `SendTransfer failed on PIN ${i + 1}/${quantity}: ${err.message}`);
    }

    if (!result.pin) {
      // Bought, but the receipt did not yield a machine-readable PIN. The money
      // is spent and the PIN exists — it is in Ding's portal. Say exactly where
      // to find it and STOP, so one unreadable receipt does not become fifty.
      //
      // The receipt is deliberately NOT copied into the error text: it contains
      // the PIN, and last_error is an ordinary column the admin app reads.
      parseFailureRef = result.providerRef || distributorRef;
      break;
    }

    // Prefer the price actually charged over the quoted minimum.
    const chargedUsd = toUsd(result.chargedValue, result.chargedCurrency, rates);
    const costUsd = round2(chargedUsd != null ? chargedUsd : chosenCostUsd);

    if (costUsd > Number(maxUnitCost)) {
      return report(id, pins,
        `PIN ${i + 1} was charged $${costUsd}, above the $${maxUnitCost} cap. Stopped.`);
    }

    pins.push({
      pin: result.pin,
      serial: result.serial,
      face_value_usd: faceValueUsd,
      cost_usd: costUsd,
      provider_ref: result.providerRef,
      instructions: result.instructions,
      receipt: result.receipt,
    });

    if (i < quantity - 1) await sleep(PURCHASE_DELAY_MS);
  }

  const error = parseFailureRef
    ? `Purchased, but the receipt carried no machine-readable PIN. Read Ding transfer `
      + `${parseFailureRef} in the DingConnect portal and load the PIN by hand `
      + `(Vouchers → Add stock). Stopped after ${pins.length} usable PIN(s) so the rest were not bought.`
    : null;

  return report(id, pins, error);
}

function round2(n) {
  return n == null ? null : Math.round(Number(n) * 100) / 100;
}

async function report(jobId, pins, error) {
  const { data, error: rpcError } = await getSupabase().rpc('record_voucher_purchase_result', {
    p_job_id: jobId,
    p_pins: pins,
    p_error: error,
  });

  if (rpcError) {
    // The PINs are bought. Losing them to a failed RPC is the worst outcome
    // here, so shout — an operator can still recover them from Ding's portal.
    console.error(`[voucher] CRITICAL: job ${jobId} bought ${pins.length} PIN(s) but recording them failed: ${rpcError.message}`);
    for (const p of pins) {
      console.error(`[voucher]   unrecorded provider_ref=${p.provider_ref} serial=${p.serial ?? '-'}`);
    }
    return;
  }

  console.log(`[voucher] job ${jobId}: recorded ${data?.added ?? 0} PIN(s), spent $${data?.spent_usd ?? 0}`
    + (error ? ` — ${error}` : ''));
}

async function tick() {
  const { data, error } = await getSupabase().rpc('claim_voucher_purchase_job');
  if (error) {
    console.error(`[voucher] claim failed: ${error.message}`);
    return false;
  }

  const job = data?.job;
  if (!job) {
    if (data?.reason) console.log(`[voucher] idle: ${data.reason}`);
    return false;
  }

  const rates = await loadFxRates();
  await runJob(job, rates);
  return true;
}

async function main() {
  const once = process.argv.includes('--once');
  console.log(`[voucher] worker_voucher_stock started (${once ? 'single pass' : `polling every ${POLL_INTERVAL_MS}ms`})`);

  do {
    try {
      // Drain the queue rather than one job per tick: an operator who queues
      // three carriers at once should not wait three minutes.
      while (await tick()) { /* keep going */ }
    } catch (err) {
      console.error(`[voucher] tick threw: ${err.message}`);
    }
    if (!once) await sleep(POLL_INTERVAL_MS);
  } while (!once);
}

if (require.main === module) {
  main().catch((err) => {
    console.error(`[voucher] fatal: ${err.message}`);
    process.exit(1);
  });
}

module.exports = { toUsd, round2, runJob };
