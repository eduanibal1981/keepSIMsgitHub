require('dotenv').config({ path: require('path').join(__dirname, '.env') });

const REFRESH_INTERVAL_MS = parseInt(process.env.ESIM_CATALOG_REFRESH_MS) || 6 * 60 * 60 * 1000; // 6 hours

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const esimGoApiKey = process.env.ESIM_GO_API_KEY;
const esimGoBaseUrl = process.env.ESIM_GO_BASE_URL || 'https://api.esim-go.com/v2.4';

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

    return {
        provider: provider,
        bundle_name: String(bundle.name).trim(),
        description: bundle.description || '',
        countries: allCountries,
        roaming_enabled: roamingEnabled,
        data_amount_mb: parseInt(bundle.dataAmount) || 0,
        duration_days: parseInt(bundle.duration) || 0,
        wholesale_price_usd: parseFloat(bundle.price) || 0.0,
        image_url: bundle.imageUrl || bundle.image_url || null,
        is_active: true,
        updated_at: new Date().toISOString(),
    };
}

async function fetchEsimGoCatalogue() {
    if (!esimGoApiKey) {
        console.warn('[worker_esim_catalog] ESIM_GO_API_KEY is not set in servers/.env. Skipping catalogue fetch.');
        return [];
    }

    const url = `${esimGoBaseUrl}/catalogue`;
    const res = await fetch(url, {
        headers: {
            'X-API-Key': esimGoApiKey,
            'Accept': 'application/json',
            'Content-Type': 'application/json',
        },
    });

    if (!res.ok) {
        throw new Error(`eSIM Go API catalogue returned status ${res.status}: ${await res.text()}`);
    }

    const json = await res.json();
    return json.bundles || [];
}

let isRefreshing = false;

async function refreshEsimCatalog() {
    if (isRefreshing) return;
    if (!supabaseUrl || !supabaseKey) {
        console.error('[worker_esim_catalog] Error: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in servers/.env');
        return;
    }

    isRefreshing = true;
    const startedAt = Date.now();
    console.log('[worker_esim_catalog] Starting eSIM catalog refresh...');

    try {
        const { createClient } = require('@supabase/supabase-js');
        const supabase = createClient(supabaseUrl, supabaseKey);
        const rawBundles = await fetchEsimGoCatalogue();
        console.log(`[worker_esim_catalog] Fetched ${rawBundles.length} raw bundles from eSIM Go.`);

        const rows = rawBundles
            .map(b => esimCatalogRow(b, 'esim_go'))
            .filter(r => r !== null && r.bundle_name && r.wholesale_price_usd > 0);

        if (rows.length > 0) {
            // Batch upsert in chunks of 500
            const chunkSize = 500;
            for (let i = 0; i < rows.length; i += chunkSize) {
                const chunk = rows.slice(i, i + chunkSize);
                const { error: upsertError } = await supabase
                    .from('esim_offers_cache')
                    .upsert(chunk, { onConflict: 'provider, bundle_name' });

                if (upsertError) {
                    throw new Error(`Upsert chunk failed: ${upsertError.message}`);
                }
            }
            console.log(`[worker_esim_catalog] Successfully upserted ${rows.length} eSIM offers.`);
        }

        console.log(`[worker_esim_catalog] Refresh cycle complete in ${Date.now() - startedAt}ms.`);
    } catch (err) {
        console.error(`[worker_esim_catalog] Refresh failed: ${err.message}`);
    } finally {
        isRefreshing = false;
    }
}

if (require.main === module) {
    console.log(`Worker (eSIM Catalog) started. URL: ${supabaseUrl}`);
    console.log(`Config: REFRESH=${REFRESH_INTERVAL_MS}ms`);
    refreshEsimCatalog();
    setInterval(refreshEsimCatalog, REFRESH_INTERVAL_MS);
}

module.exports = {
    esimCatalogRow,
    fetchEsimGoCatalogue,
    refreshEsimCatalog,
};
