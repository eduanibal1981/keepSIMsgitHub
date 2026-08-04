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

function normalizeDingProduct(p) {
  // Ding calls a denomination a SKU. A SKU with distinct Minimum/Maximum
  // SendValue is a range product; equal values mean a fixed denomination.
  const minSend = p?.Minimum?.SendValue ?? null;
  const maxSend = p?.Maximum?.SendValue ?? null;
  const minRecv = p?.Minimum?.ReceiveValue ?? null;
  const maxRecv = p?.Maximum?.ReceiveValue ?? null;

  const isRange = minSend != null && maxSend != null && Number(minSend) !== Number(maxSend);
  const priceType = isRange ? 'RANGE' : 'FIXED';

  return {
    offerId: String(p.SkuCode),
    name: p.LocalizationKey || p.DefaultDisplayText || `Ding ${p.SkuCode}`,
    productType: 'TOPUP',
    priceType,
    enabled: true,
    price: {
      fixed: isRange ? null : toMinor(minSend),
      min: isRange ? toMinor(minSend) : null,
      max: isRange ? toMinor(maxSend) : null,
      currencyDivisor: 100,
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

  // `carrierCode` is Ding's ProviderCode, stored in carriers.ding_carrier.
  const url = `${baseUrl}/GetProducts?providerCodes=${encodeURIComponent(carrierCode)}`
    + `&countryIsos=${encodeURIComponent(countryCode)}&pageSize=200`;

  const res = await fetchImpl(url, { headers: authHeaders(apiKey) });
  if (!res.ok) {
    throw new Error(`Ding GetProducts returned ${res.status}: ${await res.text()}`);
  }

  const data = await res.json();
  const items = Array.isArray(data) ? data : (data.Items || data.items || []);

  // Deliberately NO fallback catalogue. DTOne has one because it is on a preprod
  // endpoint that returns nothing useful; inventing Ding prices would put
  // fictional money in front of a user. An empty list is the honest answer and
  // request_instant_refill already refuses an offer it cannot find.
  return items
    .filter(p => p && p.SkuCode)
    .map(normalizeDingProduct);
}

async function purchase({ baseUrl = dingBaseUrl, apiKey, execution, recipientPhone, offerId, offerValue, externalId, fetchImpl = fetch }) {
  if (!apiKey) throw new Error('DING_API_KEY is not set');

  // `DistributorRef` is Ding's idempotency key — the same role z_<id> plays for
  // Zendit and external_id for DTOne. Keep the d_<execution_id> shape so a
  // retry adopts the original transaction instead of buying twice.
  const distributorRef = externalId || `d_${execution.id}`;

  const body = {
    SkuCode: offerId,
    SendValue: offerValue != null ? Number(offerValue) : undefined,
    SendCurrencyIso: 'USD',
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
          transactionId: String(list[0].TransferId || distributorRef),
          externalId: distributorRef,
          status: list[0].TransferRecordStatus || 'Completed',
          raw: list[0],
        };
      }
    }
    throw new Error(`Ding SendTransfer failed: ${res.status} ${JSON.stringify(payload.ErrorCodes || payload)}`);
  }

  return {
    transactionId: String(payload.TransferRecord?.TransferId || distributorRef),
    externalId: distributorRef,
    status: payload.TransferRecord?.TransferRecordStatus || 'Completed',
    raw: payload,
  };
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
          status = raw.TransferRecordStatus || status;
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

module.exports = {
  fetchCatalog,
  normalizeDingProduct,
  purchase,
  pollStatus,
};
