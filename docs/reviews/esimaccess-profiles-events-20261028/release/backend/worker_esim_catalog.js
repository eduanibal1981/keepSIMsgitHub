try { require('dotenv').config({ path: require('path').join(__dirname, '.env') }); } catch (_) {}

const {
    normalizeZenditEsimOffer,
    fetchEsimCatalog: fetchZenditEsimApi,
} = require('./providers/zendit');

const {
    normalizeEsimAccessOffer,
    fetchEsimCatalog: fetchEsimAccessApi,
} = require('./providers/esimaccess');

const REFRESH_INTERVAL_MS = parseInt(process.env.ESIM_CATALOG_REFRESH_MS) || 6 * 60 * 60 * 1000; // 6 hours

const CATALOG_PAGE_SIZE = parseInt(process.env.ESIM_CATALOG_PAGE_SIZE) || 200;
const CATALOG_MAX_PAGES = parseInt(process.env.ESIM_CATALOG_MAX_PAGES) || 200; // runaway guard

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const esimGoApiKey = process.env.ESIM_GO_API_KEY;
const esimGoBaseUrl = process.env.ESIM_GO_BASE_URL || 'https://api.esim-go.com/v2.5';

const zenditApiSecret = process.env.ZENDIT_API_SECRET;
const zenditBaseUrl = process.env.ZENDIT_BASE_URL || 'https://api.zendit.io/v1';

const esimAccessAccessCode = process.env.ESIM_ACCESS_ACCESS_CODE;
const esimAccessSecretKey = process.env.ESIM_ACCESS_SECRET_KEY;
const esimAccessBaseUrl = process.env.ESIM_ACCESS_BASE_URL || 'https://api.esimaccess.com/api/v1/open';

const SPEED_TIER_BY_GROUP = {
    'Standard Fixed': 'fixed',
    'Standard Unlimited Lite': 'lite',
    'Standard Unlimited Essential': 'essential',
    'Standard Unlimited Plus': 'plus',
    'Standard Long Duration': 'long_duration',
};

function esimCatalogRow(bundle, provider = 'esim_go') {
    if (!bundle || !bundle.name) return null;

    const extractCountries = (arr) => {
        if (!Array.isArray(arr)) return [];
        return arr.map(item => {
            if (typeof item === 'string') return item.toUpperCase();
            if (item && item.iso) return String(item.iso).toUpperCase();
            return null;
        }).filter(Boolean);
    };

    const countries = extractCountries(bundle.countries);
    const roamingEnabled = extractCountries(bundle.roamingEnabled);
    const allCountries = Array.from(new Set([...countries, ...roamingEnabled]));

    const rawData = parseInt(bundle.dataAmount);
    const isUnlimited = bundle.unlimited === true || (Number.isFinite(rawData) && rawData < 0);
    const dataAmountMb = isUnlimited ? 0 : (Number.isFinite(rawData) && rawData > 0 ? rawData : 0);

    const groups = Array.isArray(bundle.groups) ? bundle.groups : [];
    const bundleGroup = groups.length > 0 ? String(groups[0]) : null;
    const speedTier = bundleGroup ? (SPEED_TIER_BY_GROUP[bundleGroup] || null) : null;

    const firstWithRegion = (Array.isArray(bundle.countries) ? bundle.countries : [])
        .find(c => c && c.region);
    const region = firstWithRegion ? String(firstWithRegion.region) : null;

    return {
        provider: provider,
        bundle_name: String(bundle.name).trim(),
        description: bundle.description || '',
        countries: allCountries,
        roaming_enabled: roamingEnabled,
        data_amount_mb: dataAmountMb,
        duration_days: parseInt(bundle.duration) || 0,
        wholesale_price_usd: parseFloat(bundle.price) || 0.0,
        image_url: bundle.imageUrl || bundle.image_url || null,
        is_unlimited: isUnlimited,
        bundle_group: bundleGroup,
        speed_tier: speedTier,
        region: region,
        country_count: allCountries.length,
        is_active: true,
        updated_at: new Date().toISOString(),
    };
}

/**
 * Walks every page of the eSIM Go catalogue.
 */
async function fetchEsimGoCatalogue() {
    if (!esimGoApiKey) {
        console.warn('[worker_esim_catalog] ESIM_GO_API_KEY is not set in servers/.env. Skipping eSIM Go catalogue fetch.');
        return { bundles: [], complete: false };
    }

    const bundles = [];
    let page = 1;
    let pageCount = 1;

    while (page <= pageCount && page <= CATALOG_MAX_PAGES) {
        const url = `${esimGoBaseUrl}/catalogue?perPage=${CATALOG_PAGE_SIZE}&page=${page}`;
        const res = await fetch(url, {
            headers: {
                'X-API-Key': esimGoApiKey,
                'Accept': 'application/json',
                'Content-Type': 'application/json',
            },
        });

        if (!res.ok) {
            throw new Error(`eSIM Go API catalogue page ${page} returned status ${res.status}: ${await res.text()}`);
        }

        const json = await res.json();
        const batch = json.bundles || [];
        bundles.push(...batch);

        pageCount = parseInt(json.pageCount) || 1;
        if (batch.length === 0) break;
        page++;
    }

    if (page > CATALOG_MAX_PAGES && page <= pageCount) {
        console.warn(`[worker_esim_catalog] Stopped at the ${CATALOG_MAX_PAGES}-page guard with more pages advertised. Treating this sync as incomplete.`);
        return { bundles, complete: false };
    }

    return { bundles, complete: true };
}

/**
 * Walks every page of the Zendit eSIM catalogue.
 */
async function fetchZenditCatalogue() {
    if (!zenditApiSecret) {
        console.warn('[worker_esim_catalog] ZENDIT_API_SECRET is not set in servers/.env. Skipping Zendit catalogue fetch.');
        return { offers: [], complete: false };
    }

    const { offers, complete } = await fetchZenditEsimApi({
        baseUrl: zenditBaseUrl,
        apiSecret: zenditApiSecret,
        limit: 100,
        maxPages: CATALOG_MAX_PAGES,
    });

    return { offers, complete };
}

/**
 * Fetches every package from the eSIM Access catalogue.
 */
async function resolveEsimAccessCatalogueCredentials(supabase, {
    envAccessCode = esimAccessAccessCode,
    envSecretKey = esimAccessSecretKey,
} = {}) {
    return require('./providers/esimaccess_credentials').resolveEsimAccessCredentials(supabase,{envAccessCode,envSecretKey});
}

async function fetchEsimAccessCatalogue(supabase, fetchImpl) {
    const { accessCode, secretKey } = await resolveEsimAccessCatalogueCredentials(supabase);
    if (!accessCode) {
        console.warn('[worker_esim_catalog] ESIM_ACCESS_ACCESS_CODE is not set in servers/.env. Skipping eSIM Access catalogue fetch.');
        return { offers: [], complete: false };
    }

    const { offers, complete } = await fetchEsimAccessApi({
        baseUrl: esimAccessBaseUrl,
        accessCode,
        secretKey,
        fetchImpl: supabase ? require('./esim_supplier_limiter').limitedFetch(supabase,'primary',fetchImpl || fetch) : fetchImpl,
    });

    return { offers, complete };
}

let isRefreshing = false;

async function syncSupplierCatalog(supabase, {
    providerCode,
    fetchFn,
    mapRowFn,
    syncStartedIso,
}) {
    const startedAt = Date.now();
    console.log(`[worker_esim_catalog] Starting ${providerCode} catalog sync...`);

    try {
        if (providerCode === 'esimaccess') {
            const { error } = await supabase.rpc('prune_esim_catalogue_source');
            if (error) throw new Error('ESIM-02 schema prerequisite missing or retention failed');
        }
        const { items, complete } = await fetchFn();
        console.log(`[worker_esim_catalog] Fetched ${items.length} raw offers from ${providerCode} (complete=${complete}).`);

        const rows = items
            .map(item => mapRowFn(item))
            .filter(r => r !== null && r.bundle_name && r.wholesale_price_usd > 0);

        if (rows.length > 0) {
            const chunkSize = 500;
            for (let i = 0; i < rows.length; i += chunkSize) {
                const chunk = rows.slice(i, i + chunkSize);
                const { error: upsertError } = await supabase
                    .from('esim_offers_cache')
                    .upsert(chunk, { onConflict: 'provider, bundle_name' });

                if (upsertError) {
                    throw new Error(`Upsert chunk failed for ${providerCode}: ${upsertError.message}`);
                }
            }
            console.log(`[worker_esim_catalog] Upserted ${rows.length} ${providerCode} eSIM offers.`);
        }

        // Retirement sweep
        if (complete && rows.length > 0) {
            const { data: retired, error: retireError } = await supabase
                .from('esim_offers_cache')
                .update({ is_active: false, updated_at: new Date().toISOString() })
                .eq('provider', providerCode)
                .eq('is_active', true)
                .lt('updated_at', syncStartedIso)
                .select('bundle_name');

            if (retireError) {
                console.error(`[worker_esim_catalog] Retirement sweep failed for ${providerCode}: ${retireError.message}`);
            } else if (retired && retired.length > 0) {
                console.log(`[worker_esim_catalog] Retired ${retired.length} bundles no longer offered by ${providerCode}.`);
            }
        } else if (!complete) {
            console.warn(`[worker_esim_catalog] Incomplete fetch for ${providerCode} — skipping retirement sweep.`);
        }

        // Derive supported countries list for the supplier
        const { data: distinctCountries } = await supabase
            .from('esim_offers_cache')
            .select('countries')
            .eq('provider', providerCode)
            .eq('is_active', true);

        const countrySet = new Set();
        if (Array.isArray(distinctCountries)) {
            for (const row of distinctCountries) {
                if (Array.isArray(row.countries)) {
                    for (const c of row.countries) countrySet.add(c);
                }
            }
        }

        await supabase.from('esim_suppliers').update({
            last_sync_at: new Date().toISOString(),
            last_sync_status: complete ? 'ok' : 'partial',
            last_sync_count: rows.length,
            last_sync_error: null,
            countries_supported: Array.from(countrySet).sort(),
        }).eq('code', providerCode);

        console.log(`[worker_esim_catalog] ${providerCode} sync complete in ${Date.now() - startedAt}ms.`);
    } catch (err) {
        console.error(`[worker_esim_catalog] ${providerCode} sync failed: ${err.message}`);
        try {
            await supabase.from('esim_suppliers').update({
                last_sync_at: new Date().toISOString(),
                last_sync_status: 'error',
                last_sync_error: String(err.message).slice(0, 500),
            }).eq('code', providerCode);
        } catch (_) { /* ignore */ }
    }
}

async function refreshEsimCatalog() {
    if (isRefreshing) return;
    if (!supabaseUrl || !supabaseKey) {
        console.error('[worker_esim_catalog] Error: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in servers/.env');
        return;
    }

    isRefreshing = true;
    const startedAt = Date.now();
    const syncStartedIso = new Date().toISOString();
    console.log('[worker_esim_catalog] Starting unified eSIM catalog refresh...');

    const { createClient } = require('@supabase/supabase-js');
    const supabase = createClient(supabaseUrl, supabaseKey);

    try {
        // 1. Sync eSIM Go
        await syncSupplierCatalog(supabase, {
            providerCode: 'esim_go',
            fetchFn: async () => {
                const { bundles, complete } = await fetchEsimGoCatalogue();
                return { items: bundles, complete };
            },
            mapRowFn: (b) => esimCatalogRow(b, 'esim_go'),
            syncStartedIso,
        });

        // 2. Sync Zendit
        await syncSupplierCatalog(supabase, {
            providerCode: 'zendit',
            fetchFn: async () => {
                const { offers, complete } = await fetchZenditCatalogue();
                return { items: offers, complete };
            },
            mapRowFn: (o) => normalizeZenditEsimOffer(o),
            syncStartedIso,
        });

        // 3. Sync eSIM Access
        await syncSupplierCatalog(supabase, {
            providerCode: 'esimaccess',
            fetchFn: async () => {
                const { offers, complete } = await fetchEsimAccessCatalogue(supabase);
                return { items: offers, complete };
            },
            mapRowFn: (pkg) => normalizeEsimAccessOffer(pkg),
            syncStartedIso,
        });

        console.log(`[worker_esim_catalog] Unified refresh cycle complete in ${Date.now() - startedAt}ms.`);
    } catch (err) {
        console.error(`[worker_esim_catalog] Unified refresh cycle exception: ${err.message}`);
    } finally {
        isRefreshing = false;
    }
}

if (require.main === module) {
    console.log(`Worker (eSIM Catalog) started. URL: ${supabaseUrl}`);
    console.log(`Config: REFRESH=${REFRESH_INTERVAL_MS}ms PAGE_SIZE=${CATALOG_PAGE_SIZE}`);
    refreshEsimCatalog();
    setInterval(refreshEsimCatalog, REFRESH_INTERVAL_MS);
}

module.exports = {
    esimCatalogRow,
    fetchEsimGoCatalogue,
    fetchZenditCatalogue,
    resolveEsimAccessCatalogueCredentials,
    fetchEsimAccessCatalogue,
    refreshEsimCatalog,
    syncSupplierCatalog,
};
