require('dotenv').config({ path: require('path').join(__dirname, '.env') });

const REFRESH_INTERVAL_MS = parseInt(process.env.ESIM_CATALOG_REFRESH_MS) || 6 * 60 * 60 * 1000; // 6 hours

// eSIM Go pages the catalogue. The previous version of this worker issued one
// unparameterised GET and kept whatever came back, which was page 1 of 28 —
// 50 bundles out of 5,412, alphabetically truncated at DK. That is why the app
// offered eSIMs in four countries when the supplier sells in 220.
const CATALOG_PAGE_SIZE = parseInt(process.env.ESIM_CATALOG_PAGE_SIZE) || 200;
const CATALOG_MAX_PAGES = parseInt(process.env.ESIM_CATALOG_MAX_PAGES) || 200; // runaway guard

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const esimGoApiKey = process.env.ESIM_GO_API_KEY;
const esimGoBaseUrl = process.env.ESIM_GO_BASE_URL || 'https://api.esim-go.com/v2.5';

// eSIM Go grades unlimited bundles by throughput and sells the same
// country/duration at three prices because of it. Comparing them on price
// alone ranks a throttled plan above a full-speed one and calls it better.
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

    // `unlimited: true` arrives with `dataAmount: -1`. Storing -1 would leave
    // every $/GB and "how much data" calculation downstream to remember that
    // one supplier's sentinel, so the flag carries the meaning and the number
    // is normalised to 0.
    const rawData = parseInt(bundle.dataAmount);
    const isUnlimited = bundle.unlimited === true || (Number.isFinite(rawData) && rawData < 0);
    const dataAmountMb = isUnlimited ? 0 : (Number.isFinite(rawData) && rawData > 0 ? rawData : 0);

    const groups = Array.isArray(bundle.groups) ? bundle.groups : [];
    const bundleGroup = groups.length > 0 ? String(groups[0]) : null;
    // Unknown group -> NULL, never a guessed tier. The column's CHECK would
    // reject an invented value anyway, and a wrong tier is a false claim about
    // speed the user paid for.
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
        is_active: true,
        updated_at: new Date().toISOString(),
    };
}

/**
 * Walks every page of the catalogue.
 *
 * Returns `{ bundles, complete }`. `complete` is false if any page failed, and
 * the caller MUST NOT treat an incomplete result as the full catalogue — the
 * retirement sweep below deactivates anything it did not see, so a half-read
 * catalogue would take most of the shop offline.
 */
async function fetchEsimGoCatalogue() {
    if (!esimGoApiKey) {
        console.warn('[worker_esim_catalog] ESIM_GO_API_KEY is not set in servers/.env. Skipping catalogue fetch.');
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

        // Trust the server's page count, but stop early on an empty page so a
        // wrong pageCount cannot spin us to CATALOG_MAX_PAGES.
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

let isRefreshing = false;

async function refreshEsimCatalog() {
    if (isRefreshing) return;
    if (!supabaseUrl || !supabaseKey) {
        console.error('[worker_esim_catalog] Error: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in servers/.env');
        return;
    }

    isRefreshing = true;
    const startedAt = Date.now();
    const syncStartedIso = new Date().toISOString();
    console.log('[worker_esim_catalog] Starting eSIM catalog refresh...');

    const { createClient } = require('@supabase/supabase-js');
    const supabase = createClient(supabaseUrl, supabaseKey);

    try {
        const { bundles: rawBundles, complete } = await fetchEsimGoCatalogue();
        console.log(`[worker_esim_catalog] Fetched ${rawBundles.length} raw bundles from eSIM Go (complete=${complete}).`);

        const rows = rawBundles
            .map(b => esimCatalogRow(b, 'esim_go'))
            .filter(r => r !== null && r.bundle_name && r.wholesale_price_usd > 0);

        if (rows.length > 0) {
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
            console.log(`[worker_esim_catalog] Upserted ${rows.length} eSIM offers.`);
        }

        // ── Retirement sweep ────────────────────────────────────────────────
        // Upsert alone can only ever add. A bundle eSIM Go withdraws would stay
        // purchasable forever, and the first the buyer hears of it is a failed
        // fulfilment after their wallet was debited.
        //
        // Gated on BOTH a complete walk and a non-empty result. Either alone is
        // not enough: `complete` is true for a successful fetch that happens to
        // return nothing, and that would retire the entire catalogue.
        if (complete && rows.length > 0) {
            const { data: retired, error: retireError } = await supabase
                .from('esim_offers_cache')
                .update({ is_active: false, updated_at: new Date().toISOString() })
                .eq('provider', 'esim_go')
                .eq('is_active', true)
                .lt('updated_at', syncStartedIso)
                .select('bundle_name');

            if (retireError) {
                console.error(`[worker_esim_catalog] Retirement sweep failed: ${retireError.message}`);
            } else if (retired && retired.length > 0) {
                console.log(`[worker_esim_catalog] Retired ${retired.length} bundles no longer offered by eSIM Go.`);
            }
        } else if (!complete) {
            console.warn('[worker_esim_catalog] Incomplete fetch — skipping retirement sweep so a partial read cannot take the catalogue offline.');
        }

        await supabase.from('esim_suppliers').update({
            last_sync_at: new Date().toISOString(),
            last_sync_status: complete ? 'ok' : 'partial',
            last_sync_count: rows.length,
            last_sync_error: null,
        }).eq('code', 'esim_go');

        console.log(`[worker_esim_catalog] Refresh cycle complete in ${Date.now() - startedAt}ms.`);
    } catch (err) {
        console.error(`[worker_esim_catalog] Refresh failed: ${err.message}`);
        try {
            await supabase.from('esim_suppliers').update({
                last_sync_at: new Date().toISOString(),
                last_sync_status: 'error',
                last_sync_error: String(err.message).slice(0, 500),
            }).eq('code', 'esim_go');
        } catch (_) { /* status reporting must never mask the original failure */ }
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
    refreshEsimCatalog,
};
