require('dotenv').config({ path: require('path').join(__dirname, '.env') });
const { createClient } = require('@supabase/supabase-js');
const { createCatalogFetcher, offerCacheRow } = require('./offer_validation');

const REFRESH_INTERVAL_MS = parseInt(process.env.OFFERS_CACHE_REFRESH_MS) || 10 * 60 * 1000;
const PAIR_DELAY_MS = parseInt(process.env.OFFERS_CACHE_PAIR_DELAY_MS) || 500;

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const zenditApiSecret = process.env.ZENDIT_API_SECRET;
const zenditBaseUrl = process.env.ZENDIT_BASE_URL || 'https://api.zendit.io/v1';

const dtoneApiKey = process.env.DTONE_API_KEY;
const dtoneApiSecret = process.env.DTONE_API_SECRET;
const dtoneBaseUrl = process.env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

// I5: suppliers three and four. Both are absent from .env until the owner adds
// them, and refreshPair() returns 0 rather than throwing when a key is missing —
// so this worker keeps refreshing Zendit and DTOne exactly as before.
const dingApiKey = process.env.DING_API_KEY;
const dingBaseUrl = process.env.DING_BASE_URL || 'https://api.dingconnect.com/api/V1';

const reloadlyClientId = process.env.RELOADLY_CLIENT_ID;
const reloadlyClientSecret = process.env.RELOADLY_CLIENT_SECRET;
const reloadlyBaseUrl = process.env.RELOADLY_BASE_URL || 'https://topups.reloadly.com';

if (!supabaseUrl || !supabaseKey) {
    console.error('Error: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in servers/.env');
    process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

const fetchZenditCatalog = createCatalogFetcher({
    provider: 'zendit',
    baseUrl: zenditBaseUrl,
    apiSecret: zenditApiSecret,
    ttlMs: 1,
});

const fetchDtoneCatalog = createCatalogFetcher({
    provider: 'dtone',
    baseUrl: dtoneBaseUrl,
    apiKey: dtoneApiKey,
    apiSecret: dtoneApiSecret,
    ttlMs: 1,
});

const fetchDingCatalog = createCatalogFetcher({
    provider: 'ding',
    baseUrl: dingBaseUrl,
    apiKey: dingApiKey,
    ttlMs: 1,
});

const fetchReloadlyCatalog = createCatalogFetcher({
    provider: 'reloadly',
    baseUrl: reloadlyBaseUrl,
    clientId: reloadlyClientId,
    clientSecret: reloadlyClientSecret,
    ttlMs: 1,
});

// I5: the pair list now comes from `carrier_provider_map`, not from the
// single-valued `carriers.api_provider`.
//
// That column can only ever name ONE supplier per carrier, so this worker could
// only ever cache one — which is why enabling a second supplier used to be
// impossible no matter what credentials existed. The map holds one row per
// (carrier, supplier) and `is_enabled` is the switch; `supplier_policy` adds a
// global kill switch on top, and BOTH must be on for a pair to be refreshed.
//
// Consequence worth knowing: a supplier that is enabled but whose credentials
// are missing contributes zero rows (refreshPair returns 0), so the cache simply
// stays empty for it rather than the worker dying.
async function catalogPairs() {
    const { data: policy, error: policyError } = await supabase
        .from('supplier_policy')
        .select('provider')
        .eq('is_globally_enabled', true);

    if (policyError) throw new Error(`Failed to read supplier_policy: ${policyError.message}`);
    const liveProviders = new Set((policy || []).map(p => p.provider));

    const { data, error } = await supabase
        .from('carrier_provider_map')
        .select('provider, provider_country_code, provider_carrier_code, carriers!inner(is_supported)')
        .eq('is_enabled', true);

    if (error) throw new Error(`Failed to list carrier_provider_map: ${error.message}`);

    const seen = new Set();
    const pairs = [];

    for (const row of data) {
        if (!row.carriers?.is_supported) continue;
        if (!liveProviders.has(row.provider)) continue;
        if (!row.provider_country_code || !row.provider_carrier_code) continue;

        const key = `${row.provider}|${row.provider_country_code}|${row.provider_carrier_code}`;
        if (seen.has(key)) continue;
        seen.add(key);
        pairs.push({
            apiProvider: row.provider,
            countryCode: row.provider_country_code,
            carrierCode: row.provider_carrier_code,
        });
    }
    return pairs;
}

// K9: supplier prices are not all in USD. DTOne and Ding both settle in OMR on
// the live accounts — proven against real payloads, not assumed. Converting is
// therefore mandatory, and converting with a STALE rate is worse than not
// converting at all, so the policy lives in the database.
//
// `fx_rates_for_costing` has already applied it: pegs age in days (the rial has
// been fixed at 2.6008 USD since 1986 — expiring it after 72h would take two
// suppliers offline for a rate that cannot drift), floating rates in hours.
// Anything it flags is EXCLUDED from the map, so offerCacheRow() throws rather
// than silently pricing off a bad number.
async function loadFxRates() {
    const { data, error } = await supabase
        .from('fx_rates_for_costing')
        .select('currency_code, usd_to_local, rate_as_of, unusable_reason');

    if (error) throw new Error(`Failed to read fx_rates_for_costing: ${error.message}`);

    const rates = {};
    const rejected = [];
    for (const row of data || []) {
        if (row.unusable_reason) {
            rejected.push(`${row.currency_code} (${row.unusable_reason})`);
            continue;
        }
        rates[String(row.currency_code).toUpperCase()] = {
            usdToLocal: Number(row.usd_to_local),
            rateAsOf: row.rate_as_of,
        };
    }
    if (rejected.length > 0) {
        console.warn(`[fx] unusable rates skipped: ${rejected.join(', ')}`);
    }
    return rates;
}

async function refreshPair({ apiProvider, countryCode, carrierCode }, rates) {
    let offers = [];
    // A missing credential returns 0, never throws: one unconfigured supplier
    // must not stop the others refreshing.
    switch (apiProvider) {
        case 'dtone':
            if (!dtoneApiKey || !dtoneApiSecret) return 0;
            offers = await fetchDtoneCatalog(countryCode, carrierCode);
            break;
        case 'ding':
            if (!dingApiKey) return 0;
            offers = await fetchDingCatalog(countryCode, carrierCode);
            break;
        case 'reloadly':
            if (!reloadlyClientId || !reloadlyClientSecret) return 0;
            offers = await fetchReloadlyCatalog(countryCode, carrierCode);
            break;
        default:
            if (!zenditApiSecret) return 0;
            offers = await fetchZenditCatalog(countryCode, carrierCode);
    }

    const rows = offers
        .map(o => offerCacheRow(o, countryCode, carrierCode, apiProvider, rates))
        .filter(r => (r.price_type === 'FIXED' && r.price_fixed_usd > 0)
                  || (r.price_type === 'RANGE' && r.price_min_usd != null && r.price_max_usd != null
                      && r.send_min != null && r.send_max != null));

    if (rows.length > 0) {
        const { error: upsertError } = await supabase
            .from('provider_offers_cache')
            .upsert(rows, { onConflict: 'api_provider, offer_id' });
        if (upsertError) throw new Error(`Upsert failed: ${upsertError.message}`);
    }

    if (rows.length > 0) {
        const keptIds = rows.map(r => r.offer_id);
        const { error: deleteError } = await supabase
            .from('provider_offers_cache')
            .delete()
            .eq('api_provider', apiProvider)
            .eq('country_code', countryCode)
            .eq('carrier_code', carrierCode)
            .not('offer_id', 'in', `(${keptIds.map(id => `"${id}"`).join(',')})`);
        if (deleteError) throw new Error(`Prune failed: ${deleteError.message}`);
    }

    return rows.length;
}

let isRefreshing = false;

async function refreshAll() {
    if (isRefreshing) return;
    isRefreshing = true;
    const startedAt = Date.now();
    let ok = 0;
    let failed = 0;
    let totalRows = 0;

    try {
        // Loaded ONCE per cycle, not per pair: a rate that changed mid-run would
        // price two halves of the same catalogue differently.
        const rates = await loadFxRates();
        const pairs = await catalogPairs();
        console.log(`[refreshAll] Refreshing ${pairs.length} country/carrier catalogs `
            + `with ${Object.keys(rates).length} usable FX rates...`);

        for (const pair of pairs) {
            try {
                const n = await refreshPair(pair, rates);
                totalRows += n;
                ok++;
                console.log(`[refreshAll] ${pair.apiProvider} ${pair.countryCode}/${pair.carrierCode}: ${n} offers`);
            } catch (err) {
                failed++;
                console.error(`[refreshAll] ${pair.apiProvider} ${pair.countryCode}/${pair.carrierCode} FAILED: ${err.message}`);
            }
            await new Promise(r => setTimeout(r, PAIR_DELAY_MS));
        }

        console.log(`[refreshAll] Done in ${Date.now() - startedAt}ms: ${ok} ok, ${failed} failed, ${totalRows} offers cached.`);
    } catch (err) {
        console.error(`[refreshAll] Cycle failed: ${err.message}`);
    } finally {
        isRefreshing = false;
    }
}

console.log(`Worker (Offers Cache) started. URL: ${supabaseUrl}`);
console.log(`Config: REFRESH=${REFRESH_INTERVAL_MS}ms PAIR_DELAY=${PAIR_DELAY_MS}ms`);
refreshAll();
setInterval(refreshAll, REFRESH_INTERVAL_MS);
