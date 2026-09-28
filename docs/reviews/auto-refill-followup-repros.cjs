// Follow-up review probes. Calls the real resolver with synthetic catalogs only.
// No network, database, wallet, or supplier requests.
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { resolveIntentOffer, resolveBestSupplierRoute } = require(path.resolve(__dirname, '../../../backend-sync-wt/offer_validation.js'));
const range = {
  offerId: 'range', enabled: true, priceType: 'RANGE', serviceType: 'airtime', deliveryType: 'direct',
  send: { min: 1, max: 100, currencyCode: 'OMR', currencyDivisor: 1 },
  price: { min: 100, max: 10000, currency: 'USD', currencyDivisor: 100 },
};
test('Quoted destination value and dispatched range value must agree', () => {
  const r = resolveIntentOffer({ topups: [range],
    intent: { offerId: 'range', targetValue: 1, targetCurrency: 'OMR', offerValue: 100 },
    maxAuthorizedUsd: 5, tier: 'premium' });
  assert.equal(r.offerValue, 1, 'The resolver prices 1 OMR but keeps 100 as the provider purchase amount');
});
test('Retired SKU without verified benefit must require review, not pick cheapest offer', () => {
  const candidate = { offerId: 'unrelated', enabled: true, priceType: 'FIXED',
    serviceType: 'airtime', deliveryType: 'direct',
    send: { min: 5, max: 5, currencyCode: 'OMR', currencyDivisor: 1 },
    price: { fixed: 100, currency: 'USD', currencyDivisor: 100 } };
  assert.throws(() => resolveIntentOffer({ topups: [candidate],
    intent: { offerId: 'retired' }, maxAuthorizedUsd: 10, tier: 'premium' }), /intent|benefit|matching|eligible/i);
});
test('Route resolver must preserve requested airtime service when evaluating offers', async () => {
  await assert.rejects(() => resolveBestSupplierRoute({
    mappings: [{ provider: 'dtone', provider_country_code: 'OM', provider_carrier_code: '2695' }],
    preferredProvider: 'dtone', attemptedProviders: [],
    fetchCatalogFn: async () => [{ ...range, serviceType: 'data' }],
    intent: { offerId: 'range', targetValue: 1, targetCurrency: 'OMR', serviceType: 'airtime', deliveryType: 'direct' },
    maxAuthorizedUsd: 5, tier: 'premium',
  }), /intent|matching|benefit|eligible/i);
});
test('Legacy range value outside catalog bounds must be rejected', () => {
  assert.throws(() => resolveIntentOffer({ topups: [range],
    intent: { offerId: 'range', offerValue: 1000 }, maxAuthorizedUsd: 200, tier: 'premium' }), /range|bounds|intent|eligible/i);
});
