// ============================================================================
// DTOne (DVS) adapter
// ============================================================================
// 2026-08-08: this file previously FABRICATED data at five separate points, and
// they interlocked into a system that reported delivered airtime for purchases
// that never happened. All five are removed. Recording what they were, because
// each one looked reasonable in isolation:
//
//   1. `getPreprodFallbackOffers()` returned invented products whenever the
//      catalogue fetch failed for ANY reason — 401, 403, 404, or any thrown
//      error — and additionally for every carrier whenever countryCode was
//      'SA'. A bad credential was indistinguishable from a healthy catalogue.
//   2. `purchase()` derived the product id as
//      `parseInt(offerId.replace(/\D/g,'')) || 321301`, so an offer id with no
//      digits bought a hardcoded product.
//   3. `purchase()` answered a 400/422/404 by INVENTING a completed
//      transaction `{id: 'dt_tx_…', status: 'COMPLETED'}`.
//   4. `pollStatus()` short-circuited any id starting with `dt_tx_` to
//      `isSuccess: true` without calling the API — i.e. it recognised the
//      fabrication from (3) and rubber-stamped it.
//   5. `pollStatus()` initialised `currentStatus = 'COMPLETED'`, so an
//      unreachable API skipped the poll loop entirely and returned success.
//      (Zendit's equivalent correctly starts at 'PENDING'.)
//
// The observable result: execution dt_tx_b20a2028 was recorded `success` for
// offer `dt_zain_ranged` — a product that does not exist, at a price that was
// invented. And `worker_instant_refill` debits the wallet BEFORE purchasing, so
// on that path a fabricated success takes the customer's money and delivers
// nothing, with no refund and no failure to alert on.
//
// RULE FOR THIS FILE: it may return data or it may throw. It may never invent.
// A supplier that cannot be reached contributes zero offers, and zero offers
// makes a mapping non-routable, which is the correct and visible outcome.
// ============================================================================

const dtoneBaseUrl = process.env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

function getAuthHeader(apiKey, apiSecret) {
  const token = Buffer.from(`${apiKey}:${apiSecret}`).toString('base64');
  return `Basic ${token}`;
}

// DTOne prices an account in ITS OWN settlement currency, not USD. The live
// account settles in OMR — every `WHOLESALE PRICE` column in DTOne's own CSV
// export is headed `(OMR)`. The old normaliser read `source.amount` and stored
// it as USD, which understates cost by ~2.6x and would sell every DTOne refill
// far below what it costs us.
//
// `fx_rates` has no OMR row, so there is nothing to convert with. Until one
// exists, a non-USD price is REFUSED rather than mislabelled: a missing offer
// is a visible gap, a mispriced one is a silent loss on every sale.
// K9 UPDATE: this now REPORTS the currency instead of refusing it.
// `offerCacheRow()` converts through fx_rates and records the exact rate used,
// so the USD figure is reproducible. Refusing was correct only while no
// conversion existed — an unconverted OMR price stored in a `*_usd` column
// understates cost by ~2.6x.
function priceUnit(p) {
  return (
    p?.prices?.wholesale?.unit ||
    p?.prices?.wholesale?.currency ||
    p?.source?.unit ||
    p?.source?.currency ||
    null
  );
}

function normalizeDtoneProduct(p, countryCode, carrierCode) {
  const type = String(p.type || '').toUpperCase();
  const isPin = type.includes('PIN');
  const isRange = type.includes('RANGED') || type.includes('RANGE');
  const priceType = isRange ? 'RANGE' : 'FIXED';
  const deliveryType = isPin ? 'pin' : 'direct';

  const unit = String(priceUnit(p) || 'USD').toUpperCase();

  const sourceAmount = p.source
    ? (p.source.amount || p.prices?.wholesale?.amount || p.prices?.retail?.amount)
    : (p.prices?.wholesale?.amount || p.prices?.retail?.amount);
  const fixedUsd = !isRange ? parseFloat(sourceAmount || 0) : null;

  const minUsd = isRange ? parseFloat(p.source?.amount?.min || p.prices?.wholesale?.amount || 0) : null;
  const maxUsd = isRange ? parseFloat(p.source?.amount?.max || p.prices?.wholesale?.amount || 0) : null;

  const sendMin = isRange ? parseFloat(p.destination?.amount?.min || p.destination?.amount || 0) : (p.destination?.amount ? parseFloat(p.destination.amount) : null);
  const sendMax = isRange ? parseFloat(p.destination?.amount?.max || p.destination?.amount || 0) : (p.destination?.amount ? parseFloat(p.destination.amount) : null);

  const sendCurrency = p.destination?.currency || 'USD';
  const sendCurrencyDivisor = p.destination?.currency_divisor || 1;

  const instructions = p.pin?.usage_info || p.pin_usage_info || (isPin ? (p.description || null) : null);

  return {
    offerId: String(p.id),
    name: p.name || p.description || `Product ${p.id}`,
    productType: 'TOPUP',
    priceType,
    deliveryType,
    redeemInstructions: instructions,
    enabled: true,
    price: {
      fixed: fixedUsd != null ? Math.round(fixedUsd * 100) : null,
      min: minUsd != null ? Math.round(minUsd * 100) : null,
      max: maxUsd != null ? Math.round(maxUsd * 100) : null,
      currencyDivisor: 100,
      // The account's settlement currency — OMR on this account, NOT USD.
      currency: unit
    },
    send: {
      min: sendMin,
      max: sendMax,
      currencyCode: sendCurrency,
      currencyDivisor: sendCurrencyDivisor
    },
    dtoneRaw: p
  };
}

/// A product we can use to top up or maintain a line.
///
/// Supports both direct airtime/data recharges (automated) and digital PIN
/// vouchers (for carriers with no direct recharge rail, e.g. Mobily).
function isUsableTopupOrPin(p) {
  const type = String(p.type || '').toUpperCase();
  const isPin = type.includes('PIN');
  const isRecharge = type.includes('RECHARGE') || type.includes('TOPUP');
  if (!isPin && !isRecharge) return false;

  const service = String(p.service?.name || p.service || '').toLowerCase();
  const sub = String(p.service?.subservice?.name || p.subservice || '').toLowerCase();
  if (service && service !== 'mobile') return false;
  if (sub && !['airtime', 'topup', 'top up', 'data', 'bundle'].includes(sub)) return false;
  return true;
}

function isDirectMobileRecharge(p) {
  return isUsableTopupOrPin(p) && !String(p.type || '').toUpperCase().includes('PIN');
}

/// `countryCode` and `carrierCode` are used VERBATIM — they come from
/// `carrier_provider_map`, which stores each supplier's own dialect. DTOne wants
/// ISO3 (`SAU`) and a numeric operator id (`3221`); Zendit wants ISO2 and a
/// brand string. This adapter used to carry a 14-entry ISO2→ISO3 table that
/// fell through to its input on an unknown key, so a 15th country silently sent
/// ISO2 to an ISO3 endpoint and got nothing back.
async function fetchCatalog({ baseUrl = dtoneBaseUrl, apiKey, apiSecret, countryCode, carrierCode, fetchImpl = fetch }) {
  if (!apiKey || !apiSecret) {
    throw new Error('DTOne credentials (DTONE_API_KEY, DTONE_API_SECRET) are not configured.');
  }
  if (!carrierCode) {
    throw new Error('DTOne requires an operator id; carrier_provider_map.provider_carrier_code is empty.');
  }
  if (isNaN(carrierCode)) {
    // Previously this silently dropped the operator_id filter and fetched the
    // whole country, which is how `dtone:STC = 'STC'` looked like it worked.
    throw new Error(
      `DTOne identifies operators by numeric id, but the mapping holds "${carrierCode}". ` +
      `Set provider_carrier_code to the OPERATOR ID from DTOne (e.g. 3221 for STC Saudi Arabia).`
    );
  }

  const authHeader = getAuthHeader(apiKey, apiSecret);
  const all = [];
  let page = 1;
  let totalPages = 1;

  while (page <= totalPages) {
    const url = `${baseUrl}/products?country_iso_code=${encodeURIComponent(countryCode)}`
      + `&operator_id=${encodeURIComponent(carrierCode)}&per_page=100&page=${page}`;

    const res = await fetchImpl(url, { headers: { Authorization: authHeader } });
    if (!res.ok) {
      throw new Error(`DTOne Products API returned ${res.status}: ${await res.text()}`);
    }

    const data = await res.json();
    const totalCount = parseInt(res.headers.get('x-total') || res.headers.get('X-Total') || '0', 10);
    const perPage = parseInt(res.headers.get('x-per-page') || res.headers.get('X-Per-Page') || '100', 10);
    totalPages = totalCount > 0 ? Math.ceil(totalCount / perPage) : 1;

    const list = Array.isArray(data) ? data : (data.list || []);
    all.push(...list);

    // A truncated read must be loud. Silently keeping page 1 is how the eSIM
    // catalogue sat at 0.9% of itself for four phases.
    if (page >= 50 && page < totalPages) {
      throw new Error(`DTOne catalogue for ${countryCode}/${carrierCode} exceeds 50 pages (${totalPages}); refusing a partial read.`);
    }
    page++;
  }

  return all.filter(isUsableTopupOrPin).map(p => normalizeDtoneProduct(p, countryCode, carrierCode));
}

async function purchase({ baseUrl = dtoneBaseUrl, apiKey, apiSecret, execution, recipientPhone, offerId, offerValue, externalId, fetchImpl = fetch }) {
  const authHeader = getAuthHeader(apiKey, apiSecret);
  const transactionExternalId = externalId || `dt_${execution.id}`;

  // No hardcoded product fallback. Buying an arbitrary product because the
  // offer id did not parse is worse than refusing to buy anything.
  const numericProductId = parseInt(String(offerId).replace(/\D/g, ''), 10);
  if (!Number.isFinite(numericProductId) || numericProductId <= 0) {
    throw new Error(`DTOne product id could not be derived from offer "${offerId}".`);
  }

  // No default recipient. `'+966580000000'` would have topped up a stranger.
  if (!recipientPhone) {
    throw new Error('DTOne purchase requires a recipient phone number.');
  }

  const body = {
    external_id: transactionExternalId,
    product_id: numericProductId,
    auto_confirm: true,
    credit_party_identifier: { mobile_number: recipientPhone }
  };

  if (offerValue != null) {
    body.prices = { unit: 'USD' };
    body.calculation_mode = 'SOURCE_AMOUNT';
  }

  const res = await fetchImpl(`${baseUrl}/async/transactions`, {
    method: 'POST',
    headers: { 'Authorization': authHeader, 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  });

  let purchaseData;
  if (res.ok) {
    purchaseData = await res.json();
  } else {
    const errText = await res.text();
    // Adopt-on-retry is legitimate: it recovers a transaction DTOne already
    // has. It is NOT a licence to invent one when the lookup finds nothing.
    const existingRes = await fetchImpl(
      `${baseUrl}/transactions?external_id=${encodeURIComponent(transactionExternalId)}`,
      { headers: { 'Authorization': authHeader } }
    );
    if (existingRes.ok) {
      const existingData = await existingRes.json();
      const list = Array.isArray(existingData) ? existingData : (existingData.list || []);
      if (list.length > 0) {
        console.log(`[DTone] Transaction ${transactionExternalId} already exists from an earlier attempt. Adopting it.`);
        purchaseData = list[0];
      } else {
        throw new Error(`DTone Transaction API Error: ${res.status} - ${errText}`);
      }
    } else {
      throw new Error(`DTone Transaction API Error: ${res.status} - ${errText}`);
    }
  }

  const statusMsg = purchaseData.status
    ? (purchaseData.status.message || purchaseData.status.name || purchaseData.status)
    : 'SUBMITTED';

  return {
    transactionId: String(purchaseData.id || transactionExternalId),
    externalId: transactionExternalId,
    status: statusMsg,
    raw: purchaseData
  };
}

async function pollStatus({ baseUrl = dtoneBaseUrl, apiKey, apiSecret, transactionId, externalId, maxPolls = 12, pollDelayMs = 2500, fetchImpl = fetch }) {
  const authHeader = getAuthHeader(apiKey, apiSecret);
  let pollCount = 0;
  // Starts UNKNOWN, never 'COMPLETED'. The old default meant an unreachable
  // API skipped the loop and returned success.
  let currentStatus = 'SUBMITTED';
  let txData = null;
  let lastError = null;

  const idToPoll = transactionId || externalId;

  while (['SUBMITTED', 'PENDING', 'ACCEPTED', 'PROCESSING', 'IN_PROGRESS'].includes(currentStatus) && pollCount < maxPolls) {
    await new Promise(resolve => setTimeout(resolve, pollDelayMs));
    try {
      const checkUrl = String(idToPoll).startsWith('dt_')
        ? `${baseUrl}/transactions?external_id=${encodeURIComponent(idToPoll)}`
        : `${baseUrl}/transactions/${encodeURIComponent(idToPoll)}`;

      const checkRes = await fetchImpl(checkUrl, {
        headers: { 'Authorization': authHeader, 'Content-Type': 'application/json' }
      });

      if (checkRes.ok) {
        const resJson = await checkRes.json();
        txData = Array.isArray(resJson) ? resJson[0] : resJson;
        if (txData && txData.status) {
          currentStatus = txData.status.message || txData.status.name || txData.status || currentStatus;
        }
      } else {
        lastError = `status check returned ${checkRes.status}`;
      }
    } catch (err) {
      // Swallowed so one bad poll does not abort the wait — but it is now
      // REMEMBERED, so "we never got an answer" cannot read as success.
      lastError = err.message;
      console.log(`[DTone Polling Warning]: ${err.message}`);
    }
    pollCount++;
  }

  const isSuccess = ['COMPLETED', 'COMPLETED_LOGICALLY', 'SUCCESS'].includes(currentStatus);
  const isFailed = ['CANCELLED', 'REJECTED', 'DECLINED', 'FAILED'].includes(currentStatus);

  return {
    status: currentStatus,
    isSuccess,
    isFailed,
    // Neither success nor failure: we ran out of polls without a verdict. The
    // caller must NOT treat this as delivered.
    isIndeterminate: !isSuccess && !isFailed,
    errorMsg: isFailed
      ? (txData?.status?.message || `DTone transaction failed with status: ${currentStatus}`)
      : (isSuccess ? null : `DTone gave no final status after ${pollCount} polls (last: ${currentStatus}${lastError ? `; ${lastError}` : ''})`),
    transactionId: idToPoll,
    raw: txData
  };
}

module.exports = {
  fetchCatalog,
  normalizeDtoneProduct,
  isDirectMobileRecharge,
  purchase,
  pollStatus,
};
