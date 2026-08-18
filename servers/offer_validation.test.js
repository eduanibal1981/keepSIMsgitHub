const test = require('node:test');
const assert = require('node:assert');
const {
  offerPriceUsd,
  interpolateSendValue,
  assertOfferMatchesPrice,
  chargedOfferPriceUsd,
  createCatalogFetcher,
  resolveVerifiedOffer,
  offerCacheRow,
} = require('./offer_validation');

const dtoneProvider = require('./providers/dtone');

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------
const fixed5usd = {
  offerId: 'ETISALAT_EG_001',
  name: '5 USD Refill',
  productType: 'TOPUP',
  priceType: 'FIXED',
  enabled: true,
  price: { fixed: 500, currencyDivisor: 100 },
};

const fixed100usd = {
  offerId: 'ETISALAT_EG_100',
  name: '100 USD Refill',
  productType: 'TOPUP',
  priceType: 'FIXED',
  enabled: true,
  price: { fixed: 10000, currencyDivisor: 100 },
};

const range = {
  offerId: 'ETISALAT_EG_RANGED',
  name: 'Custom Refill',
  productType: 'TOPUP',
  priceType: 'RANGE',
  enabled: true,
  price: { min: 100, max: 5000, currencyDivisor: 100 },
  send: { min: 800, max: 20000, currencyCode: 'EGP' },
};

// ---------------------------------------------------------------------------
// assertOfferMatchesPrice
// ---------------------------------------------------------------------------
test('an honest FIXED purchase passes', () => {
  assert.strictEqual(
    assertOfferMatchesPrice(fixed5usd, fixed5usd.offerId, 5.00, null), null);
});

test('FIXED rejects a price mismatch (e.g. C3b-1 cheap-price exploit)', () => {
  assert.throws(() => assertOfferMatchesPrice(fixed5usd, fixed5usd.offerId, 0.01, null),
    /Offer price mismatch/);
  assert.throws(() => assertOfferMatchesPrice(fixed5usd, fixed5usd.offerId, 5.10, null),
    /Offer price mismatch/);
});

test('an honest RANGE purchase passes and returns the requested value', () => {
  const expected = interpolateSendValue(range, 25.50);
  assert.strictEqual(expected, 10400);
  assert.strictEqual(
    assertOfferMatchesPrice(range, range.offerId, 25.50, 10400), 10400);
});

test('RANGE rejects a price outside the range', () => {
  assert.throws(() => assertOfferMatchesPrice(range, range.offerId, 0.50, 800),
    /accepts 1-50 USD/);
  assert.throws(() => assertOfferMatchesPrice(range, range.offerId, 75, 20000),
    /accepts 1-50 USD/);
});

test('RANGE rejects a send value outside the offer bounds', () => {
  assert.throws(() => assertOfferMatchesPrice(range, range.offerId, 25.50, 999999),
    /is outside 800-20000/);
});

test('RANGE requires a value at all', () => {
  assert.throws(() => assertOfferMatchesPrice(range, range.offerId, 25.50, null),
    /requires an offer_value/);
});

test('RANGE allows the rounding slack the interpolation actually produces', () => {
  const expected = interpolateSendValue(range, 12.34);
  assert.doesNotThrow(
    () => assertOfferMatchesPrice(range, range.offerId, 12.34, expected + 1));
  assert.throws(
    () => assertOfferMatchesPrice(range, range.offerId, 12.34, expected * 2),
    /does not match/);
});

test('an unknown priceType is refused rather than assumed safe', () => {
  assert.throws(
    () => assertOfferMatchesPrice(
      { ...fixed5usd, priceType: 'MYSTERY' }, 'x', 5.00, null),
    /Unsupported priceType/);
});

test('offerPriceUsd scales by the offer currency divisor, defaulting to 100', () => {
  assert.strictEqual(offerPriceUsd(fixed5usd).fixed, 5);
  assert.strictEqual(
    offerPriceUsd({ price: { fixed: 5000, currencyDivisor: 1000 } }).fixed, 5);
  assert.strictEqual(offerPriceUsd({ price: { fixed: 500 } }).fixed, 5);
});

test('chargedOfferPriceUsd uses base_cost_usd, not the fee-inclusive amount', () => {
  assert.strictEqual(
    chargedOfferPriceUsd({ base_cost_usd: '5.00', amount: '5.15' }), 5.00);
});

test('chargedOfferPriceUsd falls back to amount when base_cost_usd is absent', () => {
  assert.strictEqual(
    chargedOfferPriceUsd({ base_cost_usd: null, amount: '3.59' }), 3.59);
});

// ---------------------------------------------------------------------------
// resolveVerifiedOffer
// ---------------------------------------------------------------------------
const catalog = [fixed5usd, fixed100usd, range];
const ctx = { topups: catalog, countryCode: 'EG', zenCarrier: 'Etisalat' };

test('resolveVerifiedOffer passes an honest named offer through', () => {
  assert.deepStrictEqual(
    resolveVerifiedOffer({ ...ctx, offerId: fixed5usd.offerId, offerValue: null, chargedUsd: 5.00 }),
    { offerId: fixed5usd.offerId, offerValue: null });
});

test('resolveVerifiedOffer rejects an offer that is not in THIS carrier catalog', () => {
  assert.throws(
    () => resolveVerifiedOffer({ ...ctx, offerId: 'VODAFONE_EG_999', offerValue: null, chargedUsd: 5.00 }),
    /is not an enabled top-up in the EG\/Etisalat catalog/);
});

test('resolveVerifiedOffer rejects the cheap-price exploit through the shared path', () => {
  assert.throws(
    () => resolveVerifiedOffer({ ...ctx, offerId: fixed100usd.offerId, offerValue: null, chargedUsd: 0.01 }),
    /Offer price mismatch/);
});

test('resolveVerifiedOffer picks a FIXED offer by price when none is named', () => {
  assert.deepStrictEqual(
    resolveVerifiedOffer({ ...ctx, offerId: null, offerValue: null, chargedUsd: 5.00 }),
    { offerId: fixed5usd.offerId, offerValue: null });
});

test('resolveVerifiedOffer falls back to a RANGE offer when no FIXED price matches', () => {
  const got = resolveVerifiedOffer({ ...ctx, offerId: null, offerValue: null, chargedUsd: 25.50 });
  assert.strictEqual(got.offerId, range.offerId);
  assert.strictEqual(got.offerValue, 10400);
});

test('resolveVerifiedOffer throws when nothing in the catalog matches the price', () => {
  assert.throws(
    () => resolveVerifiedOffer({ topups: catalog, chargedUsd: 999, countryCode: 'EG', zenCarrier: 'Etisalat' }),
    /No matching offer found/);
});

test('createCatalogFetcher caches per country+brand and refetches after the TTL', async () => {
  let calls = 0;
  const page = {
    ok: true,
    json: async () => ({ total: 1, list: [{ ...fixed5usd, enabled: true, productType: 'TOPUP', subTypes: ['Mobile Top Up'] }] }),
  };
  const fetchImpl = async () => { calls++; return page; };

  const load = createCatalogFetcher({ baseUrl: 'x', apiSecret: 'k', ttlMs: 50, fetchImpl });
  await load('EG', 'Etisalat');
  await load('EG', 'Etisalat');
  assert.strictEqual(calls, 1, 'second call within the TTL should be served from cache');

  await load('EG', 'Vodafone');
  assert.strictEqual(calls, 2, 'a different brand is a different catalog');

  await new Promise(r => setTimeout(r, 60));
  await load('EG', 'Etisalat');
  assert.strictEqual(calls, 3, 'a stale entry should be refetched');
});

test('createCatalogFetcher filters out disabled and non-topup entries', async () => {
  const fetchImpl = async () => ({
    ok: true,
    json: async () => ({ total: 3, list: [
      { offerId: 'good', enabled: true,  productType: 'TOPUP', subTypes: ['Mobile Top Up'] },
      { offerId: 'off',  enabled: false, productType: 'TOPUP', subTypes: ['Mobile Top Up'] },
      { offerId: 'data', enabled: true,  productType: 'TOPUP', subTypes: ['Data Bundle'] },
    ] }),
  });
  const load = createCatalogFetcher({ baseUrl: 'x', apiSecret: 'k', fetchImpl });
  const offers = await load('EG', 'Etisalat');
  assert.deepStrictEqual(offers.map(o => o.offerId), ['good']);
});

test('createCatalogFetcher surfaces a Zendit error instead of returning an empty catalog', async () => {
  const fetchImpl = async () => ({ ok: false, status: 503, text: async () => 'upstream down' });
  const load = createCatalogFetcher({ baseUrl: 'x', apiSecret: 'k', fetchImpl });
  await assert.rejects(() => load('EG', 'Etisalat'), /status 503/);
});

test('offerCacheRow normalises a FIXED offer to USD for the cache table', () => {
  const row = offerCacheRow({ ...fixed5usd, name: 'Etisalat 5 USD' }, 'EG', 'Etisalat', 'zendit');
  assert.strictEqual(row.api_provider, 'zendit');
  assert.strictEqual(row.offer_id, fixed5usd.offerId);
  assert.strictEqual(row.country_code, 'EG');
  assert.strictEqual(row.carrier_code, 'Etisalat');
  assert.strictEqual(row.price_type, 'FIXED');
  assert.strictEqual(row.price_fixed_usd, 5);
  assert.strictEqual(row.price_min_usd, null);
  assert.strictEqual(row.send_min, null, 'FIXED offers carry no send bounds');
});

test('offerCacheRow keeps RANGE send values in Zendit units, prices in USD', () => {
  const row = offerCacheRow(range, 'EG', 'Etisalat', 'zendit');
  assert.strictEqual(row.api_provider, 'zendit');
  assert.strictEqual(row.price_type, 'RANGE');
  assert.strictEqual(row.price_fixed_usd, null);
  assert.strictEqual(row.price_min_usd, 1);
  assert.strictEqual(row.price_max_usd, 50);
  assert.strictEqual(row.send_min, 800);
  assert.strictEqual(row.send_max, 20000);
});

// ---------------------------------------------------------------------------
// DTone Provider Unit Tests
// ---------------------------------------------------------------------------
test('dtoneProvider normalizeDtoneProduct correctly maps FIXED and RANGE products', () => {
  const rawFixed = {
    id: 101,
    name: '$10 Topup',
    type: 'FIXED_VALUE_RECHARGE',
    source: { amount: 10.00, currency: 'USD' },
    destination: { amount: 10.00, currency: 'USD' }
  };
  const normalizedFixed = dtoneProvider.normalizeDtoneProduct(rawFixed, 'US', 'mint');
  assert.strictEqual(normalizedFixed.offerId, '101');
  assert.strictEqual(normalizedFixed.priceType, 'FIXED');
  assert.strictEqual(normalizedFixed.price.fixed, 10000);

  const rawRange = {
    id: 202,
    name: 'Flexi Topup',
    type: 'RANGED_VALUE_RECHARGE',
    source: { amount: { min: 5.00, max: 50.00 }, currency: 'USD' },
    destination: { amount: { min: 500, max: 5000 }, currency: 'EGP' }
  };
  const normalizedRange = dtoneProvider.normalizeDtoneProduct(rawRange, 'EG', 'vodafone');
  assert.strictEqual(normalizedRange.offerId, '202');
  assert.strictEqual(normalizedRange.priceType, 'RANGE');
  assert.strictEqual(normalizedRange.price.min, 5000);
  assert.strictEqual(normalizedRange.price.max, 50000);
  assert.strictEqual(normalizedRange.send.min, 500);
  assert.strictEqual(normalizedRange.send.max, 5000);
});

// ---------------------------------------------------------------------------
// K9 — supplier-currency conversion.
//
// Every fixture below is a REAL payload shape, not an invention: the Ding rows
// come from a live GetProducts response for ZNPK (Zong Pakistan). Three of the
// four top-up suppliers settle in OMR, and storing that native figure in a
// `*_usd` column understated cost by ~2.6x on every Ding and DTOne offer.
// ---------------------------------------------------------------------------
const dingProvider = require('./providers/ding');

// 1 USD = 0.3845 OMR (pegged since 1986).
const OMR_RATES = { OMR: { usdToLocal: 0.3845, rateAsOf: '2026-08-09T00:00:00Z' } };

const DING_FIXED_100 = {
  SkuCode: 'PK_ZN_TopUp_100.00', DefaultDisplayText: 'PKR 100.00',
  ValidityPeriodIso: '', Benefits: ['Mobile', 'Minutes'],
  Minimum: { SendValue: 0.18, SendCurrencyIso: 'OMR', ReceiveValue: 100, ReceiveCurrencyIso: 'PKR' },
  Maximum: { SendValue: 0.18, SendCurrencyIso: 'OMR', ReceiveValue: 100, ReceiveCurrencyIso: 'PKR' },
};

const DING_RANGED = {
  SkuCode: 'PK_ZN_TopUp', DefaultDisplayText: 'PKR 279.00-4967.00',
  ValidityPeriodIso: '', Benefits: ['Mobile', 'Minutes'],
  Minimum: { SendValue: 0.5, SendCurrencyIso: 'OMR', ReceiveValue: 279, ReceiveCurrencyIso: 'PKR' },
  Maximum: { SendValue: 8.9, SendCurrencyIso: 'OMR', ReceiveValue: 4967, ReceiveCurrencyIso: 'PKR' },
};

const DING_BUNDLE = {
  SkuCode: 'ZNPK3878', DefaultDisplayText: 'Weekly Mega TikTOk',
  ValidityPeriodIso: 'P7D', Benefits: ['Mobile', 'Minutes', 'Data'],
  Minimum: { SendValue: 0.11, SendCurrencyIso: 'OMR', ReceiveValue: 60, ReceiveCurrencyIso: 'PKR' },
  Maximum: { SendValue: 0.11, SendCurrencyIso: 'OMR', ReceiveValue: 60, ReceiveCurrencyIso: 'PKR' },
};

test('offerCacheRow converts an OMR supplier price to USD', () => {
  const row = offerCacheRow(
    dingProvider.normalizeDingProduct(DING_FIXED_100), 'PK', 'ZNPK', 'ding', OMR_RATES);
  // 0.18 OMR / 0.3845 = $0.4681, NOT $0.18.
  assert.strictEqual(row.price_fixed_usd, 0.4681);
});

test('offerCacheRow records how the conversion was made, so it can be audited', () => {
  const row = offerCacheRow(
    dingProvider.normalizeDingProduct(DING_FIXED_100), 'PK', 'ZNPK', 'ding', OMR_RATES);
  assert.strictEqual(row.source_currency, 'OMR');
  assert.strictEqual(row.source_amount_native, 0.18);
  assert.strictEqual(row.fx_usd_to_local, 0.3845);
  assert.ok(row.fx_rate_as_of, 'the rate age must be recorded, not just the rate');
});

test('offerCacheRow converts both ends of a RANGE offer', () => {
  const row = offerCacheRow(
    dingProvider.normalizeDingProduct(DING_RANGED), 'PK', 'ZNPK', 'ding', OMR_RATES);
  assert.strictEqual(row.price_type, 'RANGE');
  assert.strictEqual(row.price_min_usd, 1.3004);
  assert.strictEqual(row.price_max_usd, 23.1469);
});

test('a USD supplier is untouched and carries no conversion provenance', () => {
  // Zendit quotes USD, so nothing converts and no rates are even required.
  const zendit = {
    offerId: 'STC_SA_001_USD', name: 'STC 25 SAR', priceType: 'FIXED',
    price: { fixed: 710, currencyDivisor: 100 }, send: { currencyCode: 'SAR' },
  };
  const row = offerCacheRow(zendit, 'SA', 'STC', 'zendit');
  assert.strictEqual(row.price_fixed_usd, 7.1);
  assert.strictEqual(row.source_currency, null);
  assert.strictEqual(row.fx_usd_to_local, null);
});

test('a missing FX rate REFUSES rather than caching a native figure as USD', () => {
  assert.throws(
    () => offerCacheRow(
      dingProvider.normalizeDingProduct(DING_FIXED_100), 'PK', 'ZNPK', 'ding', {}),
    /No usable FX rate for OMR/,
    'an unpriceable offer must not be cached — that is how a 2.6x understatement ships',
  );
});

test('Ding bundles are excluded: they are cheaper than top-ups and would win the ranking', () => {
  // "Weekly Mega TikTOk" is OMR 0.11 against OMR 0.18 for plain PKR 100 credit,
  // so a cheapest-first ranker would buy a data bundle to keep a line alive.
  assert.strictEqual(dingProvider.isPlainTopUp(DING_BUNDLE), false);
  assert.strictEqual(dingProvider.isPlainTopUp(DING_FIXED_100), true);
  assert.strictEqual(dingProvider.isPlainTopUp(DING_RANGED), true);
});

test('convertToUsd divides by usd_to_local and leaves USD alone', () => {
  const { convertToUsd } = require('./offer_validation');
  assert.strictEqual(convertToUsd(10, 'USD', {}), 10);
  assert.strictEqual(Number(convertToUsd(0.3845, 'OMR', OMR_RATES).toFixed(6)), 1);
});

test('zenditProvider purchase formats range value as { type: "ZEND", value } object', async () => {
  const zenditProvider = require('./providers/zendit');
  let capturedBody = null;
  const mockFetch = async (url, opts) => {
    capturedBody = JSON.parse(opts.body);
    return {
      ok: true,
      json: async () => ({ transactionId: 'z_test', status: 'ACCEPTED' })
    };
  };

  const res = await zenditProvider.purchase({
    baseUrl: 'https://mock.zendit.io',
    apiSecret: 'test_sec',
    execution: { id: 'test_1' },
    recipientPhone: '+201095351020',
    offerId: 'VODAFONE_EG_OPEN',
    offerValue: 800,
    externalId: 'z_test_1',
    fetchImpl: mockFetch
  });

  assert.strictEqual(res.status, 'ACCEPTED');
  assert.deepStrictEqual(capturedBody.value, { type: 'ZEND', value: 800 });
});

test('zenditProvider pollStatus accepts DONE as a successful terminal status', async () => {
  const zenditProvider = require('./providers/zendit');
  const mockFetch = async () => ({
    ok: true,
    json: async () => ({ transactionId: 'z_test_2', status: 'DONE' })
  });

  const pollRes = await zenditProvider.pollStatus({
    baseUrl: 'https://mock.zendit.io',
    apiSecret: 'test_sec',
    transactionId: 'z_test_2',
    maxPolls: 2,
    pollDelayMs: 5,
    fetchImpl: mockFetch
  });

  assert.strictEqual(pollRes.isSuccess, true);
  assert.strictEqual(pollRes.isFailed, false);
  assert.strictEqual(pollRes.status, 'DONE');
});

