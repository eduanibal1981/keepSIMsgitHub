// Reloadly adapter — same contract as zendit.js / dtone.js / ding.js.
//
// ⚠️ WRITTEN AGAINST RELOADLY'S PUBLISHED API SHAPE, NOT YET RUN AGAINST IT.
//    `carriers.reloadly_operator_id` is NULL for all 50 carriers and
//    `provider_offers_cache` holds zero Reloadly rows, so nothing here has ever
//    executed. Diff a real `/operators/countries/{iso}` response against
//    `normalizeReloadlyOperator` before enabling the supplier.
//
// RELOADLY IS THE ODD ONE OUT: it is the only supplier of the four that does
// **not** take a static key. It issues a short-lived OAuth bearer token from a
// client id + secret, so this module carries a token cache that the other three
// do not need. Getting that wrong shows up as a 401 storm on every catalogue
// refresh rather than as an obvious failure.
//
// Credentials live in servers/.env on the VM as RELOADLY_CLIENT_ID and
// RELOADLY_CLIENT_SECRET. Never in the repo, never in the app.

const RELOADLY_AUTH_URL = process.env.RELOADLY_AUTH_URL || 'https://auth.reloadly.com/oauth/token';
const reloadlyBaseUrl = process.env.RELOADLY_BASE_URL || 'https://topups.reloadly.com';

// Reloadly's sandbox is a DIFFERENT host, not a flag — `topups-sandbox.reloadly.com`
// — and the audience in the token request must match the host you then call.
// Mismatching them returns a token that 401s on every request, which reads like
// a bad credential and is not.
const RELOADLY_AUDIENCE = process.env.RELOADLY_AUDIENCE || reloadlyBaseUrl;

let _token = null;
let _tokenExpiresAt = 0;

async function getToken({ baseUrl = reloadlyBaseUrl, audience, clientId, clientSecret, fetchImpl = fetch }) {
  if (!clientId || !clientSecret) {
    throw new Error('RELOADLY_CLIENT_ID / RELOADLY_CLIENT_SECRET are not set');
  }
  // 60s of slack so a token cannot expire between the check and the call.
  if (_token && Date.now() < _tokenExpiresAt - 60_000) return _token;

  const effectiveAudience = audience || process.env.RELOADLY_AUDIENCE || (baseUrl ? baseUrl.replace(/\/$/, '') : reloadlyBaseUrl);

  const res = await fetchImpl(RELOADLY_AUTH_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client_id: clientId,
      client_secret: clientSecret,
      grant_type: 'client_credentials',
      audience: effectiveAudience,
    }),
  });

  if (!res.ok) {
    throw new Error(`Reloadly auth failed: ${res.status} ${await res.text()}`);
  }
  const body = await res.json();
  _token = body.access_token;
  _tokenExpiresAt = Date.now() + (Number(body.expires_in || 3600) * 1000);
  return _token;
}

function apiHeaders(token) {
  return {
    Authorization: `Bearer ${token}`,
    Accept: 'application/com.reloadly.topups-v1+json',
    'Content-Type': 'application/json',
  };
}

function toMinor(v) {
  if (v == null) return null;
  const n = Number(v);
  return Number.isFinite(n) ? Math.round(n * 100) : null;
}

// Reloadly models an operator, not a product list: one operator carries either a
// set of `fixedAmounts` or a min/max range. So ONE operator expands into several
// cache rows — unlike Zendit/Ding/DTOne where one product is one row. The offer
// id is synthesised as `rl_<operatorId>_<amount>` so it stays stable across
// refreshes and can be parsed back at purchase time.
function normalizeReloadlyOperator(op) {
  const out = [];
  const sendCurrency = op.destinationCurrencyCode || op.senderCurrencyCode || 'USD';
  const costCurrency = op.senderCurrencyCode || 'USD';
  const fx = Number(op.fx?.rate || 1);
  const isPin = Boolean(op.pin);
  const serviceType = op.data ? 'data' : (op.bundle ? 'bundle' : 'airtime');
  const deliveryType = isPin ? 'pin' : 'direct';

  if (Array.isArray(op.fixedAmounts) && op.fixedAmounts.length > 0) {
    for (let i = 0; i < op.fixedAmounts.length; i++) {
      const amt = op.fixedAmounts[i];
      const desc = op.fixedAmountsDescriptions?.[amt] 
        || op.fixedAmountsDescriptions?.[Number(amt).toFixed(2)] 
        || `${op.name} ${amt} ${costCurrency}`;

      out.push({
        offerId: `rl_${op.operatorId}_${amt}`,
        name: desc,
        productType: 'TOPUP',
        priceType: 'FIXED',
        enabled: true,
        deliveryType,
        serviceType,
        price: { fixed: toMinor(amt), currency: costCurrency, currencyDivisor: 100 },
        send: {
          min: op.localFixedAmounts?.[i] ?? Number(amt) * fx,
          max: op.localFixedAmounts?.[i] ?? Number(amt) * fx,
          currencyCode: sendCurrency,
          currencyDivisor: 1,
        },
        reloadlyRaw: op,
      });
    }
    return out;
  }

  if (op.minAmount != null && op.maxAmount != null) {
    out.push({
      offerId: `rl_${op.operatorId}_range`,
      name: `${op.name} custom amount`,
      productType: 'TOPUP',
      priceType: 'RANGE',
      enabled: true,
      deliveryType,
      serviceType,
      price: { min: toMinor(op.minAmount), max: toMinor(op.maxAmount), currency: costCurrency, currencyDivisor: 100 },
      send: {
        min: Number(op.localMinAmount ?? Number(op.minAmount) * fx),
        max: Number(op.localMaxAmount ?? Number(op.maxAmount) * fx),
        currencyCode: sendCurrency,
        currencyDivisor: 1,
      },
      reloadlyRaw: op,
    });
  }

  return out;
}

function operatorIdFromOfferId(offerId) {
  const m = /^rl_(\d+)_/.exec(String(offerId || ''));
  return m ? Number(m[1]) : null;
}

async function fetchCatalog({ baseUrl = reloadlyBaseUrl, clientId, clientSecret, countryCode, carrierCode, fetchImpl = fetch }) {
  const token = await getToken({ baseUrl, clientId, clientSecret, fetchImpl });

  const res = await fetchImpl(
    `${baseUrl}/operators/countries/${encodeURIComponent(countryCode)}`,
    { headers: apiHeaders(token) });

  if (!res.ok) {
    throw new Error(`Reloadly operators lookup returned ${res.status}: ${await res.text()}`);
  }

  const list = await res.json();
  const ops = Array.isArray(list) ? list : (list.content || []);

  // `carrierCode` is the numeric Reloadly operator id, held in
  // carrier_provider_map.provider_carrier_code WHERE provider = 'reloadly'.
  // service_providers.carrier_label_style = 'numeric_id' records that this
  // supplier identifies operators by id rather than by brand string.
  const wanted = carrierCode ? ops.filter(o => String(o.operatorId) === String(carrierCode)) : ops;

  // No invented fallback, for the same reason as ding.js.
  return wanted.flatMap(normalizeReloadlyOperator);
}

async function purchase({ baseUrl = reloadlyBaseUrl, clientId, clientSecret, execution, recipientPhone, offerId, offerValue, externalId, countryCode, fetchImpl = fetch }) {
  const token = await getToken({ baseUrl, clientId, clientSecret, fetchImpl });
  const customIdentifier = externalId || `r_${execution.id}`;
  const operatorId = operatorIdFromOfferId(offerId);
  if (!operatorId) throw new Error(`Cannot derive a Reloadly operatorId from offer ${offerId}`);

  // For a FIXED offer the amount is encoded in the offer id; for a RANGE offer
  // the caller supplies it. Never trust a client-supplied amount here — the
  // value arrives from topup_executions, which is server-written only.
  const suffix = String(offerId).split('_').pop();
  const amount = suffix === 'range' ? Number(offerValue) : Number(suffix);
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new Error(`Reloadly purchase has no usable amount for offer ${offerId}`);
  }

  const res = await fetchImpl(`${baseUrl}/topups`, {
    method: 'POST',
    headers: apiHeaders(token),
    body: JSON.stringify({
      operatorId,
      amount,
      useLocalAmount: false,
      customIdentifier,
      recipientPhone: { countryCode, number: recipientPhone },
    }),
  });

  const payload = await res.json().catch(() => ({}));

  if (!res.ok) {
    // Adopt-on-retry via customIdentifier, same idempotency contract as the
    // other three adapters.
    const existing = await fetchImpl(
      `${baseUrl}/topups/reports/transactions?customIdentifier=${encodeURIComponent(customIdentifier)}`,
      { headers: apiHeaders(token) });
    if (existing.ok) {
      const rep = await existing.json().catch(() => ({}));
      const items = Array.isArray(rep) ? rep : (rep.content || []);
      if (items.length > 0) {
        return {
          transactionId: String(items[0].transactionId || customIdentifier),
          externalId: customIdentifier,
          status: items[0].status || 'SUCCESSFUL',
          raw: items[0],
        };
      }
    }
    throw new Error(`Reloadly topup failed: ${res.status} ${JSON.stringify(payload)}`);
  }

  return {
    transactionId: String(payload.transactionId || customIdentifier),
    externalId: customIdentifier,
    status: payload.status || 'SUCCESSFUL',
    raw: payload,
  };
}

async function pollStatus({ baseUrl = reloadlyBaseUrl, clientId, clientSecret, transactionId, externalId, maxPolls = 12, pollDelayMs = 2500, fetchImpl = fetch }) {
  const token = await getToken({ baseUrl, clientId, clientSecret, fetchImpl });
  const ref = externalId || transactionId;
  let status = 'PROCESSING';
  let raw = null;
  let polls = 0;

  while (['PROCESSING', 'PENDING'].includes(status) && polls < maxPolls) {
    await new Promise(r => setTimeout(r, pollDelayMs));
    try {
      const res = await fetchImpl(
        `${baseUrl}/topups/reports/transactions?customIdentifier=${encodeURIComponent(ref)}`,
        { headers: apiHeaders(token) });
      if (res.ok) {
        const body = await res.json();
        const items = Array.isArray(body) ? body : (body.content || []);
        if (items.length > 0) {
          raw = items[0];
          status = raw.status || status;
        }
      }
    } catch (err) {
      console.log(`[Reloadly Polling Warning]: ${err.message}`);
    }
    polls++;
  }

  const isSuccess = ['SUCCESSFUL', 'SUCCESS', 'COMPLETED'].includes(status);
  const isFailed = ['FAILED', 'REFUNDED', 'DECLINED'].includes(status);

  return {
    status,
    isSuccess,
    isFailed,
    errorMsg: isFailed ? (raw?.message || `Reloadly topup failed with status: ${status}`) : null,
    transactionId: ref,
    raw,
  };
}

module.exports = {
  fetchCatalog,
  normalizeReloadlyOperator,
  operatorIdFromOfferId,
  getToken,
  purchase,
  pollStatus,
  // Exposed for tests: lets a suite reset the module-level token cache.
  _resetTokenCache: () => { _token = null; _tokenExpiresAt = 0; },
};
