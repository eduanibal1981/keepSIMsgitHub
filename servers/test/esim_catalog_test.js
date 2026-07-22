const test = require('node:test');
const assert = require('node:assert/strict');
const { esimCatalogRow } = require('../worker_esim_catalog');

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
