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

async function catalogPairs() {
    const { data, error } = await supabase
        .from('carriers')
        .select('zen_carrier, dt_carrier, api_provider, countries!inner(iso_code)')
        .eq('is_supported', true);

    if (error) throw new Error(`Failed to list carriers: ${error.message}`);

    const seen = new Set();
    const pairs = [];

    for (const row of data) {
        const iso = row.countries.iso_code;
        const provider = (row.api_provider || 'zendit').toLowerCase();
        
        if (provider === 'dtone' && row.dt_carrier && iso) {
            const key = `dtone|${iso}|${row.dt_carrier}`;
            if (!seen.has(key)) {
                seen.add(key);
                pairs.push({ apiProvider: 'dtone', countryCode: iso, carrierCode: row.dt_carrier });
            }
        } else if (provider === 'zendit' && row.zen_carrier && iso) {
            const key = `zendit|${iso}|${row.zen_carrier}`;
            if (!seen.has(key)) {
                seen.add(key);
                pairs.push({ apiProvider: 'zendit', countryCode: iso, carrierCode: row.zen_carrier });
            }
        }
    }
    return pairs;
}

async function refreshPair({ apiProvider, countryCode, carrierCode }) {
    let offers = [];
    if (apiProvider === 'dtone') {
        if (!dtoneApiKey || !dtoneApiSecret) return 0;
        offers = await fetchDtoneCatalog(countryCode, carrierCode);
    } else {
        if (!zenditApiSecret) return 0;
        offers = await fetchZenditCatalog(countryCode, carrierCode);
    }

    const rows = offers
        .map(o => offerCacheRow(o, countryCode, carrierCode, apiProvider))
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
        const pairs = await catalogPairs();
        console.log(`[refreshAll] Refreshing ${pairs.length} country/carrier catalogs...`);

        for (const pair of pairs) {
            try {
                const n = await refreshPair(pair);
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
