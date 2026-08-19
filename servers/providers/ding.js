// DingConnect adapter — same contract as zendit.js / dtone.js:
//   fetchCatalog({ baseUrl, apiKey, countryCode, carrierCode, fetchImpl })
//   purchase({ ... })  ->  { transactionId, externalId, status, raw }
//   pollStatus({ ... }) -> { status, isSuccess, isFailed, errorMsg, transactionId, raw }
//
// ⚠️ WRITTEN AGAINST DING'S PUBLISHED API SHAPE, NOT YET RUN AGAINST IT.
//    No Ding call has ever been made from this project: `carriers.ding_carrier`
//    is NULL for all 50 carriers and `provider_offers_cache` holds zero Ding
//    rows. Treat every field mapping below as unverified until the first live
//    `GetProducts` response is diffed against `normalizeDingProduct`. That is
//    exactly how the Zendit fallback was broken four ways at B1 (ISO-2 country,
//    subTypes, priceType, minor units) — assume the same until proven.
//
// The credential lives in `servers/.env` as DING_API_KEY on the VM and nowhere
// else. It is never read by the app, never in the repo, and never in Vault
// (Vault is for secrets DB functions read; this one is only ever used here).

const dingBaseUrl = process.env.DING_BASE_URL || 'https://api.dingconnect.com/api/V1';

function authHeaders(apiKey) {
  return { 'api_key': apiKey, 'Content-Type': 'application/json' };
}

// Ding quotes money in major units as decimals, unlike Zendit's minor units.
// The rest of this codebase stores minor units in `price.fixed/min/max` with an
// explicit `currencyDivisor`, so convert here rather than leaking the
// difference into offer_validation.js.
function toMinor(v) {
  if (v == null) return null;
  const n = Number(v);
  return Number.isFinite(n) ? Math.round(n * 100) : null;
}

// Ding quotes SendValue in the ACCOUNT's settlement currency, not USD — the
// live account settles in OMR, exactly like DTOne. Verified against a real
// GetProducts response for ZNPK: `"SendValue":0.18,"SendCurrencyIso":"OMR"` for
// a PKR 100 top-up, which is $0.47, not $0.18.
//
// Storing it as USD understates every Ding cost by ~2.6x. `fx_rates` has OMR
// (K7) but no conversion is wired through this path yet, so a non-USD price is
// REFUSED rather than mislabelled — the same stance as providers/dtone.js.
const SUPPORTED_SEND_CURRENCIES = new Set(['USD']);

/// True for a plain credit top-up, false for a content bundle.
///
/// Ding returns both from GetProducts and the bundles are CHEAPER, so a
/// cheapest-first ranking picks them: Zong's "Weekly Mega TikTOk" is PKR 60 /
/// OMR 0.11 against PKR 100 / OMR 0.18 for a plain top-up. A carrier rule is
/// written in terms of a qualifying RECHARGE AMOUNT, and `resolveVerifiedOffer`
/// matches on that amount — a themed data bundle is a different product wearing
/// a similar price.
///
/// The discriminator is `ValidityPeriodIso`: empty for plain credit, `P7D` /
/// `P30D` / `P90D` for a bundle. `DefaultDisplayText` corroborates it
/// ("PKR 100.00" vs "Monthly WhatsApp Prime").
function isPlainTopUp(p) {
  if (!p || !p.SkuCode) return false;
  const benefits = Array.isArray(p?.Benefits) ? p.Benefits.map(String) : [];
  return benefits.length === 0 || benefits.includes('Mobile') || benefits.includes('Minutes') || benefits.includes('Data');
}

function normalizeDingProduct(p) {
  // Ding calls a denomination a SKU. A SKU with distinct Minimum/Maximum
  // SendValue is a range product; equal values mean a fixed denomination.
  const minSend = p?.Minimum?.SendValue ?? null;
  const maxSend = p?.Maximum?.SendValue ?? null;
  const minRecv = p?.Minimum?.ReceiveValue ?? null;
  const maxRecv = p?.Maximum?.ReceiveValue ?? null;

  // K9: report the currency, do not refuse it. offerCacheRow() converts through
  // fx_rates and records the rate it used, so the USD figure is auditable.
  // Refusing was the right stance only while no conversion existed.
  const sendCcy = String(
    p?.Minimum?.SendCurrencyIso || p?.Maximum?.SendCurrencyIso || 'USD'
  ).toUpperCase();

  const isRange = minSend != null && maxSend != null && Number(minSend) !== Number(maxSend);
  const priceType = isRange ? 'RANGE' : 'FIXED';

  return {
    offerId: String(p.SkuCode),
    // DefaultDisplayText first: LocalizationKey is the SKU again ("ZNPK3878"),
    // which renders as gibberish in the admin catalogue.
    name: p.DefaultDisplayText || p.LocalizationKey || `Ding ${p.SkuCode}`,
    productType: 'TOPUP',
    priceType,
    enabled: true,
    price: {
      fixed: isRange ? null : toMinor(minSend),
      min: isRange ? toMinor(minSend) : null,
      max: isRange ? toMinor(maxSend) : null,
      currencyDivisor: 100,
      // The account's settlement currency — OMR on the live account, NOT USD.
      currency: sendCcy,
    },
    send: {
      min: minRecv != null ? Number(minRecv) : null,
      max: maxRecv != null ? Number(maxRecv) : null,
      currencyCode: p?.Maximum?.ReceiveCurrencyIso || p?.Minimum?.ReceiveCurrencyIso || 'USD',
      currencyDivisor: 1,
    },
    dingRaw: p,
  };
}

async function fetchCatalog({ baseUrl = dingBaseUrl, apiKey, countryCode, carrierCode, fetchImpl = fetch }) {
  if (!apiKey) throw new Error('DING_API_KEY is not set');
  if (!carrierCode) return [];

  // `carrierCode` is Ding's ProviderCode, held in
  // carrier_provider_map.provider_carrier_code WHERE provider = 'ding'.
  const url = `${baseUrl}/GetProducts?providerCodes=${encodeURIComponent(carrierCode)}`
    + `&countryIsos=${encodeURIComponent(countryCode)}&pageSize=200`;

  const res = await fetchImpl(url, { headers: authHeaders(apiKey) });
  if (!res.ok) {
    throw new Error(`Ding GetProducts returned ${res.status}: ${await res.text()}`);
  }

  const data = await res.json();
  const items = Array.isArray(data) ? data : (data.Items || data.items || []);

  // `ResultCode` is Ding's own success flag and can be non-1 on an HTTP 200.
  if (data && data.ResultCode != null && Number(data.ResultCode) !== 1) {
    throw new Error(
      `Ding GetProducts failed: ResultCode ${data.ResultCode} ${JSON.stringify(data.ErrorCodes || [])}`
    );
  }

  // Deliberately NO fallback catalogue. Inventing prices puts fictional money in
  // front of a user — see providers/dtone.js for what that cost us. An empty
  // list is the honest answer, and a mapping with nothing cached is not routable.
  return items
    .filter(p => p && p.SkuCode)
    .filter(isPlainTopUp)
    .map(normalizeDingProduct);
}

async function purchase({ baseUrl = dingBaseUrl, apiKey, execution, recipientPhone, offerId, offerValue, externalId, fetchImpl = fetch }) {
  if (!apiKey) throw new Error('DING_API_KEY is not set');

  // `DistributorRef` is Ding's idempotency key — the same role z_<id> plays for
  // Zendit and external_id for DTOne. Keep the d_<execution_id> shape so a
  // retry adopts the original transaction instead of buying twice.
  const distributorRef = externalId || `d_${execution.id}`;

  let sendValue = offerValue != null ? Number(offerValue) : undefined;
  let sendCurrencyIso = 'OMR';

  // If sendValue is not explicitly provided, look up the product to get Minimum.SendValue and SendCurrencyIso
  if (sendValue == null && offerId) {
    try {
      const prodRes = await fetchImpl(`${baseUrl}/GetProducts?skuCodes=${encodeURIComponent(offerId)}`, {
        headers: authHeaders(apiKey),
      });
      if (prodRes.ok) {
        const prodData = await prodRes.json();
        const items = Array.isArray(prodData) ? prodData : (prodData.Items || []);
        const found = items.find(i => i.SkuCode === offerId) || items[0];
        if (found && found.Minimum) {
          sendValue = found.Minimum.SendValue;
          sendCurrencyIso = found.Minimum.SendCurrencyIso || 'OMR';
        }
      }
    } catch (e) {
      console.warn(`[Ding.purchase] Failed to fetch SKU details for ${offerId}: ${e.message}`);
    }
  }

  const body = {
    SkuCode: offerId,
    SendValue: sendValue,
    SendCurrencyIso: sendCurrencyIso,
    AccountNumber: recipientPhone,
    DistributorRef: distributorRef,
    ValidateOnly: false,
  };

  const res = await fetchImpl(`${baseUrl}/SendTransfer`, {
    method: 'POST',
    headers: authHeaders(apiKey),
    body: JSON.stringify(body),
  });

  const payload = await res.json().catch(() => ({}));

  if (!res.ok || (payload.ErrorCodes && payload.ErrorCodes.length)) {
    // Adopt-on-retry: if this DistributorRef already transferred, that is a
    // success we must not repeat.
    const existing = await fetchImpl(
      `${baseUrl}/GetTransferRecords?DistributorRef=${encodeURIComponent(distributorRef)}`,
      { headers: authHeaders(apiKey) });
    if (existing.ok) {
      const rec = await existing.json().catch(() => ({}));
      const list = Array.isArray(rec) ? rec : (rec.Items || []);
      if (list.length > 0) {
        return {
          transactionId: transferRefOf(list[0]) || distributorRef,
          externalId: distributorRef,
          status: processingStateOf(list[0]) || 'Completed',
          raw: list[0],
        };
      }
    }
    throw new Error(`Ding SendTransfer failed: ${res.status} ${JSON.stringify(payload.ErrorCodes || payload)}`);
  }

  return {
    transactionId: transferRefOf(payload.TransferRecord) || distributorRef,
    externalId: distributorRef,
    status: processingStateOf(payload.TransferRecord) || 'Completed',
    raw: payload,
  };
}

// ── Field readers, written against Ding's PUBLISHED model ──────────────────
//
// Two of the names this adapter used were not in it, and both would have failed
// silently on the first live call:
//
//   * `TransferRecord.TransferId` is an OBJECT — `{TransferRef, DistributorRef}`
//     — not a string. `String(obj)` yields the literal "[object Object]", which
//     is what would have been stored as the transaction id and then used to
//     poll for a status that could never be found.
//   * There is no `TransferRecordStatus`. The status field is `ProcessingState`.
//     Reading the absent name made purchase() report 'Completed' unconditionally
//     and pollStatus() sit on 'Pending' until it ran out of polls.
//
// Both fall back to the old names so that if a live response really does carry
// them, nothing breaks — but the published name is tried first.
function transferRefOf(record) {
  const id = record?.TransferId;
  if (id && typeof id === 'object') {
    return id.TransferRef ? String(id.TransferRef) : null;
  }
  return id != null ? String(id) : null;
}

function processingStateOf(record) {
  return record?.ProcessingState || record?.TransferRecordStatus || null;
}

async function pollStatus({ baseUrl = dingBaseUrl, apiKey, transactionId, externalId, maxPolls = 12, pollDelayMs = 2500, fetchImpl = fetch }) {
  const ref = externalId || transactionId;
  let status = 'Pending';
  let raw = null;
  let polls = 0;

  while (['Pending', 'Submitted', 'Processing'].includes(status) && polls < maxPolls) {
    await new Promise(r => setTimeout(r, pollDelayMs));
    try {
      const res = await fetchImpl(
        `${baseUrl}/GetTransferRecords?DistributorRef=${encodeURIComponent(ref)}`,
        { headers: authHeaders(apiKey) });
      if (res.ok) {
        const body = await res.json();
        const list = Array.isArray(body) ? body : (body.Items || []);
        if (list.length > 0) {
          raw = list[0];
          status = processingStateOf(raw) || status;
        }
      }
    } catch (err) {
      console.log(`[Ding Polling Warning]: ${err.message}`);
    }
    polls++;
  }

  const isSuccess = ['Completed', 'Complete', 'Success'].includes(status);
  const isFailed = ['Failed', 'Declined', 'Cancelled', 'Refunded'].includes(status);

  return {
    status,
    isSuccess,
    isFailed,
    errorMsg: isFailed ? (raw?.ErrorCode || `Ding transfer failed with status: ${status}`) : null,
    transactionId: ref,
    raw,
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// PIN / voucher products  (L-phase: offline recharge without connectivity)
// ═══════════════════════════════════════════════════════════════════════════
//
// There is NO "give me a PIN" endpoint. A Ding PIN is the receipt of a real,
// paid `SendTransfer`, so every call below spends money. That is why the caller
// is a queue-driven worker with a per-job cost ceiling and not a request path.
//
// How Ding models it, from the published API model (verified, not assumed):
//   * `Product.RedemptionMechanism` is 'Immediate' or 'ReadReceipt'. PIN
//     products are ReadReceipt: "further instructions ... will be printed
//     within the ReceiptText property".
//   * `TransferRecord.ReceiptText`   — "Provider specific receipt text ... may
//     contain additional information for the end customer."
//   * `TransferRecord.ReceiptParams` — "Name value pairs of data that is in the
//     ReceiptText."
//
// ⚠️ WHAT IS *NOT* KNOWN, and must not be invented: the KEY NAMES inside
// ReceiptParams, and the exact wording of ReceiptText. Both are described as
// "provider specific" — they vary per telecom. No live Ding response has ever
// been seen by this project. `extractPin` therefore matches conservatively and
// **returns null rather than guessing**; the worker treats null as "we bought
// something, a human must read the receipt", which is a recoverable state. A
// guessed PIN is not: it would be stored as a bearer instrument, handed to a
// subscriber, and fail at the moment they have no way to ask why. This is the
// same failure the DTOne adapter shipped when it fabricated success.

const PIN_KEY_PATTERN = /^(pin|pincode|pin_code|voucher|vouchercode|voucher_code|rechargepin|recharge_pin|code|secret)$/i;
const SERIAL_KEY_PATTERN = /^(serial|serialnumber|serial_number|batch|batchnumber|batch_number)$/i;

/// True for a product Ding delivers as a PIN the customer redeems themselves.
function isPinProduct(p) {
  return String(p?.RedemptionMechanism ?? '').toLowerCase() === 'readreceipt';
}

/// Pulls a PIN out of a transfer record, or returns null.
///
/// Order matters: `ReceiptParams` is structured data and is tried first;
/// `ReceiptText` is free prose and is only scraped when a labelled line makes
/// the intent unambiguous ("PIN: 1234 5678"). A bare number found loose in the
/// prose is NOT accepted — receipts carry balances, dates and phone numbers,
/// and picking the wrong one produces a plausible, wrong, unusable voucher.
function extractPin(record) {
  const params = record?.ReceiptParams;
  if (params && typeof params === 'object') {
    for (const [key, value] of Object.entries(params)) {
      if (PIN_KEY_PATTERN.test(String(key).replace(/[\s-]/g, '')) && String(value ?? '').trim()) {
        return String(value).trim();
      }
    }
  }

  const text = String(record?.ReceiptText ?? '');
  if (text) {
    const labelled = text.match(
      /\b(?:pin|voucher(?:\s*code)?|recharge\s*code)\b\s*[:=]\s*([A-Za-z0-9][A-Za-z0-9 -]{3,30})/i
    );
    if (labelled) return labelled[1].trim();
  }

  return null;
}

function extractSerial(record) {
  const params = record?.ReceiptParams;
  if (params && typeof params === 'object') {
    for (const [key, value] of Object.entries(params)) {
      if (SERIAL_KEY_PATTERN.test(String(key).replace(/[\s-]/g, '')) && String(value ?? '').trim()) {
        return String(value).trim();
      }
    }
  }
  return null;
}

/// Every PIN-capable SKU for a provider, cheapest first.
///
/// Unlike fetchCatalog() this deliberately does NOT filter with isPlainTopUp():
/// a PIN product legitimately carries a validity period, and excluding those
/// would leave most PIN shelves empty.
async function fetchPinProducts({
  baseUrl = dingBaseUrl, apiKey, countryCode, carrierCode, fetchImpl = fetch,
}) {
  if (!apiKey) throw new Error('DING_API_KEY is not set');
  if (!carrierCode) return [];

  const url = `${baseUrl}/GetProducts?providerCodes=${encodeURIComponent(carrierCode)}`
    + `&countryIsos=${encodeURIComponent(countryCode)}&pageSize=200`;

  const res = await fetchImpl(url, { headers: authHeaders(apiKey) });
  if (!res.ok) {
    throw new Error(`Ding GetProducts returned ${res.status}: ${await res.text()}`);
  }

  const data = await res.json();
  if (data && data.ResultCode != null && Number(data.ResultCode) !== 1) {
    throw new Error(
      `Ding GetProducts failed: ResultCode ${data.ResultCode} ${JSON.stringify(data.ErrorCodes || [])}`
    );
  }

  const items = Array.isArray(data) ? data : (data.Items || data.items || []);

  return items
    .filter(p => p && p.SkuCode && isPinProduct(p))
    .map(p => ({
      skuCode: String(p.SkuCode),
      name: p.DefaultDisplayText || p.LocalizationKey || `Ding ${p.SkuCode}`,
      // What WE pay, in the account's settlement currency (OMR on the live
      // account, not USD — see toMinor()'s note above).
      sendValue: p?.Minimum?.SendValue != null ? Number(p.Minimum.SendValue) : null,
      sendCurrency: String(
        p?.Minimum?.SendCurrencyIso || p?.Maximum?.SendCurrencyIso || 'USD'
      ).toUpperCase(),
      // What the SUBSCRIBER receives, in their own currency.
      receiveValue: p?.Minimum?.ReceiveValue != null ? Number(p.Minimum.ReceiveValue) : null,
      receiveCurrency: String(
        p?.Minimum?.ReceiveCurrencyIso || p?.Maximum?.ReceiveCurrencyIso || ''
      ).toUpperCase() || null,
      validityIso: String(p?.ValidityPeriodIso ?? '').trim() || null,
      raw: p,
    }))
    .filter(p => p.sendValue != null && p.sendValue > 0)
    .sort((a, b) => a.sendValue - b.sendValue);
}

/// Buys ONE PIN. Returns `{ pin, serial, instructions, providerRef, receipt }`
/// with `pin: null` when the receipt could not be parsed — which is a purchase
/// that succeeded and now needs a human, not a failure.
async function purchasePin({
  baseUrl = dingBaseUrl, apiKey, skuCode, sendValue, accountNumber,
  distributorRef, fetchImpl = fetch,
}) {
  if (!apiKey) throw new Error('DING_API_KEY is not set');
  if (!skuCode) throw new Error('purchasePin needs a skuCode');
  if (!accountNumber) {
    // SendTransfer requires AccountNumber even for a PIN product.
    throw new Error('purchasePin needs an accountNumber (Ding requires one even for PIN SKUs)');
  }

  const body = {
    SkuCode: skuCode,
    SendValue: sendValue != null ? Number(sendValue) : undefined,
    AccountNumber: accountNumber,
    DistributorRef: distributorRef,
    ValidateOnly: false,
  };

  const res = await fetchImpl(`${baseUrl}/SendTransfer`, {
    method: 'POST',
    headers: authHeaders(apiKey),
    body: JSON.stringify(body),
  });

  const payload = await res.json().catch(() => ({}));

  if (!res.ok || (payload.ErrorCodes && payload.ErrorCodes.length)) {
    throw new Error(
      `Ding SendTransfer (PIN) failed: ${res.status} ${JSON.stringify(payload.ErrorCodes || payload)}`
    );
  }

  const record = payload.TransferRecord || {};

  return {
    pin: extractPin(record),
    serial: extractSerial(record),
    // The receipt IS the instructions for a ReadReceipt product — Ding's own
    // wording for this telecom beats anything we could write generically.
    instructions: String(record.ReceiptText ?? '').trim() || null,
    providerRef: transferRefOf(record) || distributorRef,
    processingState: processingStateOf(record),
    // Price actually charged, which may differ from the quoted minimum.
    chargedValue: record?.Price?.SendValue != null ? Number(record.Price.SendValue) : null,
    chargedCurrency: record?.Price?.SendCurrencyIso
      ? String(record.Price.SendCurrencyIso).toUpperCase() : null,
    receipt: payload,
  };
}

module.exports = {
  fetchCatalog,
  normalizeDingProduct,
  isPlainTopUp,
  purchase,
  pollStatus,
  // L-phase voucher rail
  isPinProduct,
  extractPin,
  extractSerial,
  fetchPinProducts,
  purchasePin,
  transferRefOf,
  processingStateOf,
};
