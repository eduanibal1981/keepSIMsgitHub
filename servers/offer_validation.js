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

function offerPriceUsd(offer, rates = null) {
  const divisor = offer.price?.currencyDivisor || 100;
  const priceType = offer.priceType || (offer.price?.fixed != null ? 'FIXED' : (offer.price?.min != null ? 'RANGE' : null));
  const costCcy = String(offer.price?.currency || 'USD').toUpperCase();

  if (priceType === 'FIXED') {
    const raw = (offer.price?.fixed || 0) / divisor;
    const val = rates ? convertToUsd(raw, costCcy, rates) : raw;
    return { fixed: val };
  }
  if (priceType === 'RANGE') {
    const rawMin = (offer.price?.min || 0) / divisor;
    const rawMax = (offer.price?.max || 0) / divisor;
    const minVal = rates ? convertToUsd(rawMin, costCcy, rates) : rawMin;
    const maxVal = rates ? convertToUsd(rawMax, costCcy, rates) : rawMax;
    return {
      min: minVal,
      max: maxVal,
    };
  }
  throw new Error(`Unsupported priceType '${offer.priceType}' in offer.`);
}

function interpolateSendValue(offer, chargedUsd, rates = null) {
  const price = offerPriceUsd(offer, rates);
  const priceRange = price.max - price.min;
  if (priceRange <= 0) return offer.send.min;

  const fraction = (chargedUsd - price.min) / priceRange;
  const sendRange = offer.send.max - offer.send.min;
  return Math.round(offer.send.min + fraction * sendRange);
}

function assertOfferMatchesPrice(offer, offerId, chargedUsd, requestedValue, rates = null) {
  const price = offerPriceUsd(offer, rates);
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
    const expectedValue = interpolateSendValue(offer, chargedUsd, rates);
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
function createCatalogFetcher({ provider = 'zendit', baseUrl, apiSecret, apiKey, clientId, clientSecret, ttlMs = 5 * 60 * 1000, fetchImpl = fetch, supabase = null }) {
  const cache = new Map(); // `${country}|${brand}` -> { offers, fetchedAt }

  return async function fetchTopupCatalog(countryCode, carrierCode) {
    const key = `${countryCode}|${carrierCode}`;
    const hit = cache.get(key);
    if (hit && Date.now() - hit.fetchedAt < ttlMs) return hit.offers;

    let offers = null;
    let liveError = null;

    try {
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
    } catch (err) {
      liveError = err;
      console.warn(`[CatalogFetcher] Live catalog fetch failed for ${provider} ${countryCode}/${carrierCode}: ${err.message}`);
    }

    if (offers && offers.length > 0) {
      cache.set(key, { offers, fetchedAt: Date.now() });
      return offers;
    }

    // Fallback 1: Return memory cached offers even if slightly stale
    if (hit && hit.offers && hit.offers.length > 0) {
      console.log(`[CatalogFetcher] Using in-memory cached offers for ${provider} ${countryCode}/${carrierCode}`);
      return hit.offers;
    }

    // Fallback 2: Query provider_offers_cache directly from Supabase
    if (supabase) {
      try {
        const { data: cachedRows } = await supabase
          .from('provider_offers_cache')
          .select('*')
          .eq('api_provider', provider)
          .eq('country_code', countryCode)
          .eq('carrier_code', carrierCode);

        if (cachedRows && cachedRows.length > 0) {
          const parsedOffers = cachedRows.map(r => ({
            offerId: r.offer_id,
            name: r.offer_name,
            priceType: r.price_type,
            enabled: true,
            price: {
              fixed: r.source_amount_native != null ? Math.round(Number(r.source_amount_native) * 100) : Math.round(Number(r.price_fixed_usd) * 100),
              min: r.price_min_usd != null ? Math.round(Number(r.price_min_usd) * 100) : null,
              max: r.price_max_usd != null ? Math.round(Number(r.price_max_usd) * 100) : null,
              currency: r.source_currency || 'USD',
              currencyDivisor: 100,
            },
            send: {
              min: r.send_min,
              max: r.send_max,
              currencyCode: r.send_currency || 'USD',
              currencyDivisor: r.send_currency_divisor || 1,
            },
            dingRaw: null,
          }));

          cache.set(key, { offers: parsedOffers, fetchedAt: Date.now() });
          console.log(`[CatalogFetcher] Loaded ${parsedOffers.length} fallback offers from database for ${provider} ${countryCode}/${carrierCode}`);
          return parsedOffers;
        }
      } catch (dbErr) {
        console.warn(`[CatalogFetcher] Database fallback query failed: ${dbErr.message}`);
      }
    }

    if (liveError) throw liveError;
    return [];
  };
}

function resolveVerifiedOffer({ topups, offerId, offerValue, chargedUsd, countryCode, zenCarrier, rates = null }) {
  if (offerId) {
    const offer = topups.find(o => o.offerId === offerId);
    if (!offer) {
      throw new Error(
        `Offer ${offerId} is not an enabled top-up in the ${countryCode}/${zenCarrier} catalog.`);
    }
    const resolvedValue = assertOfferMatchesPrice(offer, offerId, chargedUsd, offerValue, rates);
    return {
      offerId: offer.offerId,
      offerValue: resolvedValue
    };
  }

  // Fallback / discovery mode (no explicit offerId given)
  for (const offer of topups) {
    const pType = offer.priceType || (offer.price?.fixed != null ? 'FIXED' : (offer.price?.min != null ? 'RANGE' : null));
    if (pType !== 'FIXED') continue;
    const price = offerPriceUsd(offer, rates);
    if (Math.abs(price.fixed - chargedUsd) < OFFER_PRICE_TOLERANCE_USD) {
      return { offerId: offer.offerId, offerValue: null };
    }
  }
  for (const offer of topups) {
    const pType = offer.priceType || (offer.price?.fixed != null ? 'FIXED' : (offer.price?.min != null ? 'RANGE' : null));
    if (pType !== 'RANGE') continue;
    const price = offerPriceUsd(offer, rates);
    if (chargedUsd >= price.min - OFFER_PRICE_TOLERANCE_USD && chargedUsd <= price.max + OFFER_PRICE_TOLERANCE_USD) {
      return { offerId: offer.offerId, offerValue: interpolateSendValue(offer, chargedUsd, rates) };
    }
  }

  throw new Error(
    `No matching offer found for value ${chargedUsd} USD (searched ${topups.length} top-up offers for ${countryCode}/${zenCarrier})`);
}

async function loadFxRates(supabase) {
  const { data, error } = await supabase
    .from('fx_rates_for_costing')
    .select('currency_code, usd_to_local, rate_as_of, unusable_reason');

  if (error) throw new Error(`Failed to read fx_rates_for_costing: ${error.message}`);

  const rates = {};
  for (const row of data || []) {
    if (row.unusable_reason) continue;
    rates[String(row.currency_code).toUpperCase()] = {
      usdToLocal: Number(row.usd_to_local),
      rateAsOf: row.rate_as_of,
    };
  }
  return rates;
}

/// K9: supplier prices are not all in USD.
///
/// Three of the four top-up suppliers settle in **OMR** — proven against live
/// payloads (DTOne: all 16,172 rows `SOURCE CURRENCY = OMR`; Ding:
/// `"SendValue":0.18,"SendCurrencyIso":"OMR"`). Only Zendit quotes USD.
///
/// Storing the native figure in a `*_usd` column understates cost by ~2.6x:
/// Ding's PKR 100 top-up costs OMR 0.18 = $0.47 and was cached as $0.18. A
/// guaranteed loss on every sale, invisible because the number looks plausible.
///
/// `rates` maps CURRENCY -> { usdToLocal, rateAsOf }, built from the
/// `fx_rates_for_costing` view, which has ALREADY applied the staleness policy.
/// Anything it flagged unusable must not be in this map — converting with a
/// stale rate is the mistake G11 exists to prevent, now with money moving.
///
/// Throws rather than guessing. An offer we cannot price is an offer we do not
/// cache, and a mapping with nothing cached is simply not routable — that is
/// the safe, visible outcome.
function convertToUsd(amount, currency, rates) {
  if (amount == null) return null;
  const ccy = String(currency || 'USD').toUpperCase();
  if (ccy === 'USD') return amount;

  const rate = rates ? rates[ccy] : undefined;
  if (!rate || !(rate.usdToLocal > 0)) {
    throw new Error(
      `No usable FX rate for ${ccy}; cannot convert a supplier price to USD. ` +
      `Add ${ccy} to fx_rates (and check fx_rates_for_costing.unusable_reason).`
    );
  }
  // fx_rates stores usd_to_local — how many LOCAL units one USD buys. So the
  // inverse converts a native supplier price back to USD.
  return amount / rate.usdToLocal;
}

function offerCacheRow(offer, countryCode, carrierCode, apiProvider = 'zendit', rates = null) {
  const native = offerPriceUsd(offer); // native units; name predates multi-currency
  const pType = offer.priceType || (offer.price?.fixed != null ? 'FIXED' : (offer.price?.min != null ? 'RANGE' : null));

  // The supplier's own currency. Absent means USD, which is how Zendit and every
  // pre-K9 adapter behaved — so this stays backwards compatible by default.
  const costCcy = String(offer.price?.currency || 'USD').toUpperCase();
  const isConverted = costCcy !== 'USD';

  const fixedUsd = pType === 'FIXED' ? convertToUsd(native.fixed, costCcy, rates) : null;
  const minUsd = pType === 'RANGE' ? convertToUsd(native.min, costCcy, rates) : null;
  const maxUsd = pType === 'RANGE' ? convertToUsd(native.max, costCcy, rates) : null;

  // Round only at the boundary, once. Rounding before the division drifts.
  const r4 = (v) => (v == null ? null : Math.round(v * 10000) / 10000);

  return {
    api_provider: apiProvider,
    offer_id: offer.offerId,
    country_code: countryCode,
    carrier_code: carrierCode,
    offer_name: offer.name || null,
    price_type: pType,
    price_fixed_usd: r4(fixedUsd),
    price_min_usd: r4(minUsd),
    price_max_usd: r4(maxUsd),
    send_min: pType === 'RANGE' && offer.send ? offer.send.min : null,
    send_max: pType === 'RANGE' && offer.send ? offer.send.max : null,
    send_currency: offer.send ? offer.send.currencyCode || offer.send.currency || null : null,
    send_currency_divisor: offer.send ? offer.send.currencyDivisor || 100 : 100,
    // Provenance. With these three the USD figure is reproducible from first
    // principles months later; without them it is an assertion.
    source_currency: isConverted ? costCcy : null,
    source_amount_native: isConverted
      ? (pType === 'FIXED' ? native.fixed : native.min)
      : null,
    fx_usd_to_local: isConverted ? rates[costCcy].usdToLocal : null,
    fx_rate_as_of: isConverted ? rates[costCcy].rateAsOf : null,
    delivery_type: offer.deliveryType || 'direct',
    redeem_instructions: offer.redeemInstructions || null,
    service_type: offer.serviceType || 'airtime',
    benefit_summary: offer.benefitSummary || offer.name || null,
    data_mb: offer.dataMb || null,
    duration_days: offer.durationDays || null,
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
  convertToUsd,
  offerCacheRow,
  alertOfferTampering,
  loadFxRates,
};
