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
    () => resolveVerifiedOffer({ ...ctx, offerId: null, offerValue: null, chargedUsd: 999 }),
    /No matching Zendit offer found/);
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
  assert.strictEqual(normalizedFixed.price.fixed, 1000);

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
  assert.strictEqual(normalizedRange.price.min, 500);
  assert.strictEqual(normalizedRange.price.max, 5000);
  assert.strictEqual(normalizedRange.send.min, 500);
  assert.strictEqual(normalizedRange.send.max, 5000);
});
