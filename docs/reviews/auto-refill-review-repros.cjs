// Read-only regression probes for the current production resolver.
// No database, network, wallet, or purchase calls. Assertions express required behavior.
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { resolveIntentOffer, resolveBestSupplierRoute } = require(path.resolve(__dirname, '../../../backend-sync-wt/offer_validation.js'));

const fixed = (id, value, cost, extra = {}) => ({
  offerId: id, enabled: true, priceType: 'FIXED', serviceType: 'airtime', deliveryType: 'direct',
  send: { min: value, max: value, currencyCode: 'OMR', currencyDivisor: 1 },
  price: { fixed: cost * 100, currency: 'USD', currencyDivisor: 100 }, ...extra,
});
const resolve = (topups, intent, historicalChargedUsd = null) => resolveIntentOffer({
  topups, intent, maxAuthorizedUsd: 200, historicalChargedUsd, tier: 'premium',
});

test('Newly queued preferred provider must remain eligible before its first purchase', async () => {
  const result = await resolveBestSupplierRoute({
    mappings: [{ provider: 'dtone', provider_country_code: 'OM', provider_carrier_code: '2695', priority: 1 }],
    preferredProvider: 'dtone',
    // This is exactly what the deployed BEFORE INSERT route trigger initializes.
    attemptedProviders: ['dtone'],
    fetchCatalogFn: async () => [fixed('preferred', 1, 3)],
    intent: { offerId: 'preferred', targetValue: 1, targetCurrency: 'OMR' },
    maxAuthorizedUsd: 4, historicalChargedUsd: 3.1, tier: 'premium',
  });
  assert.equal(result.provider, 'dtone');
});

test('Range maximum must use the cost of the requested value, not the range minimum', () => {
  const range = {
    offerId: 'range', enabled: true, priceType: 'RANGE', serviceType: 'airtime', deliveryType: 'direct',
    send: { min: 1, max: 100, currencyCode: 'OMR', currencyDivisor: 1 },
    price: { min: 100, max: 10000, currency: 'USD', currencyDivisor: 100 },
  };
  const result = resolve([range], { offerId: 'range', targetValue: 100, targetCurrency: 'OMR' });
  assert.equal(result.offerValue, 100);
  assert.equal(result.costUsd, 100, 'The catalog maximum endpoint costs $100; resolver currently prices it at $1');
});

test('Existing SKU whose benefit changed cannot bypass explicit customer intent', () => {
  assert.throws(() => resolve([fixed('same-id', 5, 3)], {
    offerId: 'same-id', targetValue: 1, targetCurrency: 'OMR',
  }), /intent|matching|benefit|eligible/i);
});

test('Missing SKU must not substitute a different destination value solely because price matches', () => {
  assert.throws(() => resolve([fixed('wrong-value', 5, 3)], {
    offerId: 'retired', targetValue: 1, targetCurrency: 'OMR',
  }, 3), /intent|matching|benefit|eligible/i);
});

test('Owner source cost cannot stand in for customer destination benefit', () => {
  assert.throws(() => resolve([fixed('cost-matches-benefit-does-not', 5, 1)], {
    offerId: 'retired', targetValue: 1, targetCurrency: 'OMR',
  }), /intent|matching|benefit|eligible/i);
});

test('Direct airtime intent must not silently become a PIN purchase', () => {
  assert.throws(() => resolve([fixed('pin-only', 1, 3, { deliveryType: 'pin' })], {
    offerId: 'retired', targetValue: 1, targetCurrency: 'OMR', deliveryType: 'direct', serviceType: 'airtime',
  }), /intent|matching|benefit|eligible|delivery/i);
});
