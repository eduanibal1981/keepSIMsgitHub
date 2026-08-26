const test = require('node:test');
const assert = require('node:assert/strict');
const { esimCatalogRow } = require('../worker_esim_catalog');
const { normalizeZenditEsimOffer } = require('../providers/zendit');
const { normalizeEsimAccessOffer } = require('../providers/esimaccess');

test('esimCatalogRow — transforms raw eSIM Go bundle object correctly', () => {
    const rawBundle = {
        name: 'esim_10GB_30D_FR_v2',
        description: '10GB Data in France for 30 Days',
        dataAmount: 10240,
        duration: 30,
        price: 12.50,
        imageUrl: 'https://cms.esim-go.com/fr.png',
        countries: [{ iso: 'FR', name: 'France' }],
        roamingEnabled: [{ iso: 'FR', name: 'France' }, { iso: 'DE', name: 'Germany' }]
    };

    const row = esimCatalogRow(rawBundle, 'esim_go');

    assert.equal(row.provider, 'esim_go');
    assert.equal(row.bundle_name, 'esim_10GB_30D_FR_v2');
    assert.equal(row.description, '10GB Data in France for 30 Days');
    assert.equal(row.data_amount_mb, 10240);
    assert.equal(row.duration_days, 30);
    assert.equal(row.wholesale_price_usd, 12.50);
    assert.equal(row.image_url, 'https://cms.esim-go.com/fr.png');
    assert.deepEqual(row.countries.sort(), ['DE', 'FR']);
    assert.deepEqual(row.roaming_enabled, ['FR', 'DE']);
    assert.equal(row.is_active, true);
});

test('esimCatalogRow — handles missing or string-array country formats', () => {
    const rawBundle = {
        name: 'esim_1GB_7D_Global',
        description: 'Global 1GB 7 Days',
        dataAmount: 1024,
        duration: 7,
        price: 4.00,
        countries: ['us', 'ca', 'gb'],
        roamingEnabled: []
    };

    const row = esimCatalogRow(rawBundle, 'esim_go');

    assert.equal(row.bundle_name, 'esim_1GB_7D_Global');
    assert.deepEqual(row.countries, ['US', 'CA', 'GB']);
});

test('esimCatalogRow — returns null for invalid bundle input', () => {
    assert.equal(esimCatalogRow(null), null);
    assert.equal(esimCatalogRow({}), null);
});

test('normalizeZenditEsimOffer — maps fixed data Zendit offer correctly', () => {
    const rawOffer = {
        offerId: 'ESIM-EG-15D-2GB-NOROAM',
        name: 'Egypt 2GB 15 Days',
        country: 'EG',
        regions: ['Middle East and North Africa'],
        subTypes: ['Standard'],
        durationDays: 15,
        dataGB: 2,
        dataUnlimited: false,
        shortNotes: '2GB High Speed Data for 15 Days',
        cost: {
            currency: 'USD',
            currencyDivisor: 100,
            fixed: 1241,
        },
        roaming: [{ country: 'EG' }],
        enabled: true,
    };

    const row = normalizeZenditEsimOffer(rawOffer);

    assert.equal(row.provider, 'zendit');
    assert.equal(row.bundle_name, 'ESIM-EG-15D-2GB-NOROAM');
    assert.equal(row.description, '2GB High Speed Data for 15 Days');
    assert.equal(row.data_amount_mb, 2048);
    assert.equal(row.duration_days, 15);
    assert.equal(row.wholesale_price_usd, 12.41);
    assert.equal(row.is_unlimited, false);
    assert.equal(row.speed_tier, 'fixed');
    assert.equal(row.bundle_group, 'Standard');
    assert.deepEqual(row.countries, ['EG']);
    assert.equal(row.is_active, true);
});

test('normalizeZenditEsimOffer — maps unlimited Zendit offer and speed tier correctly', () => {
    const rawOffer = {
        offerId: 'ESIM-SA-10D-ULE-NOROAM',
        country: 'SA',
        regions: ['Middle East and North Africa'],
        subTypes: ['Faster'],
        durationDays: 10,
        dataGB: 0,
        dataUnlimited: true,
        shortNotes: '1GB unthrottled Daily (1.25mbps throttled)',
        cost: {
            currency: 'USD',
            currencyDivisor: 100,
            fixed: 1976,
        },
        roaming: [{ country: 'SA' }],
        enabled: true,
    };

    const row = normalizeZenditEsimOffer(rawOffer);

    assert.equal(row.provider, 'zendit');
    assert.equal(row.bundle_name, 'ESIM-SA-10D-ULE-NOROAM');
    assert.equal(row.data_amount_mb, 0);
    assert.equal(row.is_unlimited, true);
    assert.equal(row.speed_tier, 'essential');
    assert.equal(row.bundle_group, 'Faster');
    assert.equal(row.wholesale_price_usd, 19.76);
    assert.deepEqual(row.countries, ['SA']);
});

test('normalizeZenditEsimOffer — handles multi-country roaming packages', () => {
    const rawOffer = {
        offerId: 'ESIM-EU-30D-5GB',
        country: 'FR',
        regions: ['Western Europe'],
        subTypes: ['Standard'],
        durationDays: 30,
        dataGB: 5,
        cost: { currency: 'USD', currencyDivisor: 100, fixed: 1500 },
        roaming: [
            { country: 'FR' },
            { country: 'DE' },
            { country: 'IT' },
            { country: 'ES' },
        ],
        enabled: true,
    };

    const row = normalizeZenditEsimOffer(rawOffer);

    assert.equal(row.provider, 'zendit');
    assert.deepEqual(row.countries.sort(), ['DE', 'ES', 'FR', 'IT']);
    assert.equal(row.country_count, 4);
    assert.equal(row.wholesale_price_usd, 15.00);
});

// ─────────────────────────────────────────────────────────────────────────────
// eSIM Access Tests
// ─────────────────────────────────────────────────────────────────────────────

test('normalizeEsimAccessOffer — maps fixed data package with byte volume and 10000 price divisor', () => {
    const rawPackage = {
        packageCode: 'CKH139',
        name: 'Slovenia 5GB 30Days',
        price: 112500,
        currencyCode: 'USD',
        volume: 5368709120, // 5 GB in bytes
        duration: 30,
        durationUnit: 'DAY',
        location: 'SI',
        description: 'Slovenia 5GB 30Days High Speed',
        speed: '3G/4G',
        status: 'ACTIVE',
    };

    const row = normalizeEsimAccessOffer(rawPackage);

    assert.equal(row.provider, 'esimaccess');
    assert.equal(row.bundle_name, 'CKH139');
    assert.equal(row.description, 'Slovenia 5GB 30Days High Speed');
    assert.equal(row.data_amount_mb, 5120);
    assert.equal(row.duration_days, 30);
    assert.equal(row.wholesale_price_usd, 11.25);
    assert.equal(row.is_unlimited, false);
    assert.equal(row.bundle_group, 'Fixed Bundle');
    assert.equal(row.speed_tier, 'fixed');
    assert.deepEqual(row.countries, ['SI']);
    assert.deepEqual(row.roaming_enabled, []);
    assert.equal(row.is_active, true);
});

test('normalizeEsimAccessOffer — handles multi-country comma-separated location string with FUP1Mbps', () => {
    const rawPackage = {
        packageCode: 'PMRXJQDH7',
        name: 'GCC 2GB/Day FUP1Mbps',
        price: 78000,
        currencyCode: 'USD',
        volume: 2147483648, // 2 GB
        duration: 1,
        durationUnit: 'DAY',
        location: 'QA,AE,BH,KW,SA,OM',
        description: 'GCC Daily Roaming 2GB High Speed FUP1Mbps',
        speed: '4G',
        status: 'ACTIVE',
    };

    const row = normalizeEsimAccessOffer(rawPackage);

    assert.equal(row.provider, 'esimaccess');
    assert.equal(row.bundle_name, 'PMRXJQDH7');
    assert.equal(row.data_amount_mb, 2048);
    assert.equal(row.duration_days, 1);
    assert.equal(row.wholesale_price_usd, 7.80);
    assert.equal(row.country_count, 6);
    assert.deepEqual(row.countries.sort(), ['AE', 'BH', 'KW', 'OM', 'QA', 'SA']);
    assert.deepEqual(row.roaming_enabled.sort(), ['AE', 'BH', 'KW', 'OM', 'QA', 'SA']);
    assert.equal(row.is_unlimited, true);
    assert.equal(row.bundle_group, 'DayPass');
    assert.equal(row.speed_tier, 'high-1 Mbps');
    assert.equal(row.region, 'Middle East');
});

test('normalizeEsimAccessOffer — handles DayPass with default 384kbps FUP policy', () => {
    const rawPackage = {
        packageCode: 'EG_10_Daily',
        name: 'Egypt 10GB/Day',
        price: 107000,
        currencyCode: 'USD',
        volume: 10737418240, // 10 GB
        duration: 1,
        durationUnit: 'DAY',
        location: 'EG',
        description: 'Egypt 10GB Daily Unlimited',
        speed: '4G',
        status: 'ACTIVE',
    };

    const row = normalizeEsimAccessOffer(rawPackage);

    assert.equal(row.provider, 'esimaccess');
    assert.equal(row.bundle_name, 'EG_10_Daily');
    assert.equal(row.is_unlimited, true);
    assert.equal(row.bundle_group, 'DayPass');
    assert.equal(row.speed_tier, 'high-384 kbps');
});

test('normalizeEsimAccessOffer — handles unlimited package and duration unit conversion', () => {
    const rawPackage = {
        packageCode: 'UNL_US_7D',
        name: 'United States Unlimited Data 7 Days',
        price: 250000,
        volume: 0,
        isUnlimited: true,
        duration: 168,
        durationUnit: 'HOUR',
        location: 'US',
        speed: '5G',
    };

    const row = normalizeEsimAccessOffer(rawPackage);

    assert.equal(row.provider, 'esimaccess');
    assert.equal(row.bundle_name, 'UNL_US_7D');
    assert.equal(row.is_unlimited, true);
    assert.equal(row.data_amount_mb, 0);
    assert.equal(row.duration_days, 7); // 168 hours / 24 = 7 days
    assert.equal(row.wholesale_price_usd, 25.00);
    assert.equal(row.bundle_group, 'Fixed Bundle');
    assert.equal(row.speed_tier, 'fixed');
    assert.deepEqual(row.countries, ['US']);
});

test('normalizeEsimAccessOffer — returns null for invalid input', () => {
    assert.equal(normalizeEsimAccessOffer(null), null);
    assert.equal(normalizeEsimAccessOffer({}), null);
});

test('fetchEsimCatalog — passes correct headers and payload to eSIM Access endpoint', async () => {
    const { fetchEsimCatalog } = require('../providers/esimaccess');
    let capturedUrl, capturedHeaders, capturedBody;

    const mockFetch = async (url, options) => {
        capturedUrl = url;
        capturedHeaders = options.headers;
        capturedBody = JSON.parse(options.body);
        return {
            ok: true,
            status: 200,
            json: async () => ({
                success: true,
                errorCode: '0',
                obj: {
                    packageList: [
                        { packageCode: 'CKH139', name: 'Slovenia 5GB', price: 112500, volume: 5368709120, duration: 30, location: 'SI' }
                    ]
                }
            })
        };
    };

    const { offers, complete } = await fetchEsimCatalog({
        baseUrl: 'https://api.esimaccess.com/api/v1/open',
        accessCode: 'test-access-code',
        secretKey: 'test-secret-key',
        locationCode: 'SI',
        fetchImpl: mockFetch,
    });

    assert.equal(capturedUrl, 'https://api.esimaccess.com/api/v1/open/package/list');
    assert.equal(capturedHeaders['RT-AccessCode'], 'test-access-code');
    assert.equal(capturedHeaders['secretKey'], 'test-secret-key');
    assert.equal(capturedBody.locationCode, 'SI');
    assert.equal(complete, true);
    assert.equal(offers.length, 1);
    assert.equal(offers[0].packageCode, 'CKH139');
});
