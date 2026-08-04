// ============================================================
// Per-execution offer validation & catalog utilities
// Supporting Zendit and DTone topup providers
// ============================================================

const zenditProvider = require('./providers/zendit');
const dtoneProvider = require('./providers/dtone');
const dingProvider = require('./providers/ding');
const reloadlyProvider = require('./providers/reloadly');

const OFFER_PRICE_TOLERANCE_USD = 0.01;
const OFFER_VALUE_TOLERANCE_RATIO = 0.05; // 5% ratio allowance on interpolated send value rounding

function offerPriceUsd(offer) {
  const divisor = offer.price?.currencyDivisor || 100;
  const priceType = offer.priceType || (offer.price?.fixed != null ? 'FIXED' : (offer.price?.min != null ? 'RANGE' : null));
  if (priceType === 'FIXED') {
    return { fixed: (offer.price?.fixed || 0) / divisor };
  }
  if (priceType === 'RANGE') {
    return {
      min: (offer.price?.min || 0) / divisor,
      max: (offer.price?.max || 0) / divisor,
    };
  }
  throw new Error(`Unsupported priceType '${offer.priceType}' in offer.`);
}

function interpolateSendValue(offer, chargedUsd) {
  const price = offerPriceUsd(offer);
  const priceRange = price.max - price.min;
  if (priceRange <= 0) return offer.send.min;

  const fraction = (chargedUsd - price.min) / priceRange;
  const sendRange = offer.send.max - offer.send.min;
  return Math.round(offer.send.min + fraction * sendRange);
}

function assertOfferMatchesPrice(offer, offerId, chargedUsd, requestedValue) {
  const price = offerPriceUsd(offer);
  const priceType = offer.priceType || (offer.price?.fixed != null ? 'FIXED' : (offer.price?.min != null ? 'RANGE' : null));

  if (priceType === 'FIXED') {
    if (Math.abs(price.fixed - chargedUsd) > OFFER_PRICE_TOLERANCE_USD) {
      throw new Error(
        `Offer price mismatch: ${offerId} costs ${price.fixed} USD but ${chargedUsd} USD was charged.`);
    }
    return null; // FIXED offers take no explicit value
  }

  if (priceType === 'RANGE') {
    if (price.min == null || price.max == null) {
      throw new Error(`Offer ${offerId} is RANGE but has no price bounds.`);
    }
    if (chargedUsd < price.min - OFFER_PRICE_TOLERANCE_USD ||
        chargedUsd > price.max + OFFER_PRICE_TOLERANCE_USD) {
      throw new Error(
        `Offer price mismatch: ${offerId} accepts ${price.min}-${price.max} USD but ${chargedUsd} USD was charged.`);
    }
    if (requestedValue == null) {
      throw new Error(`RANGE offer ${offerId} requires an offer_value.`);
    }
    if (requestedValue < offer.send.min || requestedValue > offer.send.max) {
      throw new Error(
        `Offer value ${requestedValue} is outside ${offer.send.min}-${offer.send.max} for ${offerId}.`);
    }
    const expectedValue = interpolateSendValue(offer, chargedUsd);
    const tolerance = Math.max(1, Math.abs(expectedValue) * OFFER_VALUE_TOLERANCE_RATIO);
    if (Math.abs(requestedValue - expectedValue) > tolerance) {
      throw new Error(
        `Offer value ${requestedValue} does not match ${chargedUsd} USD for ${offerId} (expected ~${expectedValue}).`);
    }
    return requestedValue;
  }

  throw new Error(`Unsupported priceType '${offer.priceType}' for offer ${offerId}.`);
}

function chargedOfferPriceUsd(execution) {
  return execution.base_cost_usd != null
    ? parseFloat(execution.base_cost_usd)
    : parseFloat(execution.amount);
}

// I5: `clientId`/`clientSecret` are here for Reloadly, the only supplier of the
// four that authenticates with OAuth rather than a static key.
function createCatalogFetcher({ provider = 'zendit', baseUrl, apiSecret, apiKey, clientId, clientSecret, ttlMs = 5 * 60 * 1000, fetchImpl = fetch }) {
  const cache = new Map(); // `${country}|${brand}` -> { offers, fetchedAt }

  return async function fetchTopupCatalog(countryCode, carrierCode) {
    const key = `${countryCode}|${carrierCode}`;
    const hit = cache.get(key);
    if (hit && Date.now() - hit.fetchedAt < ttlMs) return hit.offers;

    let offers;
    switch (provider) {
      case 'dtone':
        offers = await dtoneProvider.fetchCatalog({ baseUrl, apiKey, apiSecret, countryCode, carrierCode, fetchImpl });
        break;
      case 'ding':
        offers = await dingProvider.fetchCatalog({ baseUrl, apiKey, countryCode, carrierCode, fetchImpl });
        break;
      case 'reloadly':
        offers = await reloadlyProvider.fetchCatalog({ baseUrl, clientId, clientSecret, countryCode, carrierCode, fetchImpl });
        break;
      default:
        offers = await zenditProvider.fetchCatalog({ baseUrl, apiSecret, countryCode, carrierCode, fetchImpl });
    }

    cache.set(key, { offers, fetchedAt: Date.now() });
    return offers;
  };
}

function resolveVerifiedOffer({ topups, offerId, offerValue, chargedUsd, countryCode, zenCarrier }) {
  if (offerId) {
    const offer = topups.find(o => o.offerId === offerId);
    if (!offer) {
      throw new Error(
        `Offer ${offerId} is not an enabled top-up in the ${countryCode}/${zenCarrier} catalog.`);
    }
    return { offerId, offerValue: assertOfferMatchesPrice(offer, offerId, chargedUsd, offerValue) };
  }

  for (const offer of topups) {
    const pType = offer.priceType || (offer.price?.fixed != null ? 'FIXED' : (offer.price?.min != null ? 'RANGE' : null));
    if (pType !== 'FIXED') continue;
    if (Math.abs(offerPriceUsd(offer).fixed - chargedUsd) < OFFER_PRICE_TOLERANCE_USD) {
      return { offerId: offer.offerId, offerValue: null };
    }
  }
  for (const offer of topups) {
    const pType = offer.priceType || (offer.price?.fixed != null ? 'FIXED' : (offer.price?.min != null ? 'RANGE' : null));
    if (pType !== 'RANGE') continue;
    const price = offerPriceUsd(offer);
    if (chargedUsd >= price.min && chargedUsd <= price.max) {
      return { offerId: offer.offerId, offerValue: interpolateSendValue(offer, chargedUsd) };
    }
  }

  throw new Error(
    `No matching Zendit offer found for value ${chargedUsd} USD (searched ${topups.length} top-up offers for ${countryCode}/${zenCarrier})`);
}

function offerCacheRow(offer, countryCode, carrierCode, apiProvider = 'zendit') {
  const price = offerPriceUsd(offer);
  const pType = offer.priceType || (offer.price?.fixed != null ? 'FIXED' : (offer.price?.min != null ? 'RANGE' : null));
  return {
    api_provider: apiProvider,
    offer_id: offer.offerId,
    country_code: countryCode,
    carrier_code: carrierCode,
    offer_name: offer.name || null,
    price_type: pType,
    price_fixed_usd: pType === 'FIXED' ? price.fixed : null,
    price_min_usd: pType === 'RANGE' ? price.min : null,
    price_max_usd: pType === 'RANGE' ? price.max : null,
    send_min: pType === 'RANGE' && offer.send ? offer.send.min : null,
    send_max: pType === 'RANGE' && offer.send ? offer.send.max : null,
    send_currency: offer.send ? offer.send.currencyCode || offer.send.currency || null : null,
    send_currency_divisor: offer.send ? offer.send.currencyDivisor || 100 : 100,
    refreshed_at: new Date().toISOString(),
  };
}

async function alertOfferTampering(supabase, execution, reason) {
  try {
    await supabase.from('system_alerts').insert({
      kind: 'offer_price_mismatch',
      message: `Refill ${execution.id} (user ${execution.user_id}) rejected: ${reason}`,
      details: {
        execution_id: execution.id,
        user_id: execution.user_id,
        sim_line_id: execution.sim_line_id,
        execution_type: execution.execution_type,
        offer_id: execution.offer_id,
        offer_value: execution.offer_value,
        base_cost_usd: execution.base_cost_usd,
        amount: execution.amount,
        reason,
      },
    });
  } catch (e) {
    console.error(`Failed to raise offer_price_mismatch alert: ${e.message}`);
  }
}

module.exports = {
  OFFER_PRICE_TOLERANCE_USD,
  OFFER_VALUE_TOLERANCE_RATIO,
  offerPriceUsd,
  interpolateSendValue,
  assertOfferMatchesPrice,
  chargedOfferPriceUsd,
  createCatalogFetcher,
  resolveVerifiedOffer,
  offerCacheRow,
  alertOfferTampering,
};
