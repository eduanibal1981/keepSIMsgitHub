const fs = require('fs');
const path = require('path');

const envPath = path.join(__dirname, '.env');
const envContent = fs.readFileSync(envPath, 'utf8');
const env = {};
envContent.split('\n').forEach(line => {
  const match = line.match(/^\s*([\w_]+)\s*=\s*(.*)?\s*$/);
  if (match) {
    let val = (match[2] || '').trim();
    if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
      val = val.slice(1, -1);
    }
    env[match[1]] = val;
  }
});

const SUPABASE_URL = env.SUPABASE_URL;
const SUPABASE_KEY = env.SUPABASE_SERVICE_ROLE_KEY;

async function api(endpoint, method = 'GET', body = null) {
  const options = {
    method,
    headers: {
      'apikey': SUPABASE_KEY,
      'Authorization': `Bearer ${SUPABASE_KEY}`,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation'
    }
  };
  if (body) options.body = JSON.stringify(body);
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${endpoint}`, options);
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`API error ${res.status} ${res.statusText} on ${method} ${endpoint}: ${text}`);
  }
  const text = await res.text();
  return text ? JSON.parse(text) : null;
}

async function main() {
  console.log('====================================================');
  console.log('=== PROVISIONING GERMANY IN SUPABASE ===');
  console.log('====================================================');

  // 1. Enable Country: Germany
  console.log('\n1. Updating Germany country record to is_supported: true...');
  const countryUpdate = await api('countries?iso_code=eq.DE', 'PATCH', {
    is_supported: true
  });
  console.log('Country updated:', countryUpdate);
  const deCountryId = countryUpdate[0]?.id || '68f3c4c7-e950-4d6e-a9df-4d96a8f0d0ed';

  // 2. Fetch existing carriers
  const existingCarriers = await api(`carriers?country_id=eq.${deCountryId}`);
  console.log(`Found ${existingCarriers.length} carriers for Germany in DB.`);

  const carrierMapByName = {};
  existingCarriers.forEach(c => {
    carrierMapByName[c.name.toLowerCase().trim()] = c;
  });

  const nowIso = new Date().toISOString();

  // Reset all existing carrier_provider_map entries for these carriers to is_primary = false first
  for (const c of existingCarriers) {
    await api(`carrier_provider_map?carrier_id=eq.${c.id}`, 'PATCH', {
      is_primary: false
    });
  }

  const providerMaps = [
    // Deutsche Telekom
    { carrier: 'Deutsche Telekom', provider: 'dtone', code: '602', is_primary: true, is_enabled: true, priority: 10, notes: 'DT One Primary: Direct 10-100 EUR & PIN 5-30 EUR (16 SKUs)' },
    { carrier: 'Deutsche Telekom', provider: 'reloadly', code: '664', is_primary: false, is_enabled: true, priority: 20, notes: 'Reloadly Secondary: Telekom PIN 15-50 EUR' },
    { carrier: 'Deutsche Telekom', provider: 'zendit', code: 'Telekom', is_primary: false, is_enabled: true, priority: 30, notes: 'Zendit Tertiary: TELEKOM_DE_001-ROW (15 EUR)' },
    { carrier: 'Deutsche Telekom', provider: 'ding', code: 'TLDE', is_primary: false, is_enabled: false, priority: 40, notes: 'DingConnect Disabled: 0 UAT inventory' },

    // Vodafone Germany
    { carrier: 'Vodafone Germany', provider: 'dtone', code: '718', is_primary: true, is_enabled: true, priority: 10, notes: 'DT One Primary: Direct 15-50 EUR & PIN 15-25 EUR (5 SKUs)' },
    { carrier: 'Vodafone Germany', provider: 'reloadly', code: '875', is_primary: false, is_enabled: true, priority: 20, notes: 'Reloadly Secondary: Vodafone PIN 15, 25 EUR' },
    { carrier: 'Vodafone Germany', provider: 'zendit', code: 'Vodafone', is_primary: false, is_enabled: true, priority: 30, notes: 'Zendit Tertiary: VODAFONE_DE_001-ROW (15 EUR)' },
    { carrier: 'Vodafone Germany', provider: 'ding', code: 'VFDE', is_primary: false, is_enabled: false, priority: 40, notes: 'DingConnect Disabled: 0 UAT inventory' },

    // O2 Germany
    { carrier: 'O2 Germany', provider: 'dtone', code: '451', is_primary: true, is_enabled: true, priority: 10, notes: 'DT One Primary: Direct 15-50 EUR & PIN 15-30 EUR (7 SKUs)' },
    { carrier: 'O2 Germany', provider: 'reloadly', code: '868', is_primary: false, is_enabled: true, priority: 20, notes: 'Reloadly Secondary: O2 PIN 15-30 EUR' },
    { carrier: 'O2 Germany', provider: 'zendit', code: 'O2', is_primary: false, is_enabled: true, priority: 30, notes: 'Zendit Tertiary: O2_DE_001-ROW (15 EUR)' },
    { carrier: 'O2 Germany', provider: 'ding', code: 'O2DE', is_primary: false, is_enabled: false, priority: 40, notes: 'DingConnect Disabled: 0 UAT inventory' },

    // Congstar
    { carrier: 'Congstar', provider: 'reloadly', code: '850', is_primary: true, is_enabled: true, priority: 10, notes: 'Reloadly Primary: Micro-Refill Congstar 5 EUR PIN ($5.89 USD)' },
    { carrier: 'Congstar', provider: 'zendit', code: 'Congstar', is_primary: false, is_enabled: true, priority: 20, notes: 'Zendit Secondary: CONGSTAR_DE_001-ROW (15 EUR)' },
    { carrier: 'Congstar', provider: 'dtone', code: '2139', is_primary: false, is_enabled: false, priority: 30, notes: 'DT One Disabled: 0 pre-prod products' },
    { carrier: 'Congstar', provider: 'ding', code: 'C4DE', is_primary: false, is_enabled: false, priority: 40, notes: 'DingConnect Disabled: 0 UAT inventory' },

    // Lebara Germany
    { carrier: 'Lebara Germany', provider: 'reloadly', code: '855', is_primary: true, is_enabled: true, priority: 10, notes: 'Reloadly Primary: PIN 10-100 EUR & Flexi/Komplett Bundles from 9.99 EUR' },
    { carrier: 'Lebara Germany', provider: 'dtone', code: '2728', is_primary: false, is_enabled: false, priority: 20, notes: 'DT One Disabled: 0 pre-prod products' },
    { carrier: 'Lebara Germany', provider: 'ding', code: 'ESDE', is_primary: false, is_enabled: false, priority: 30, notes: 'DingConnect Disabled: 0 UAT inventory' },

    // Lycamobile Germany
    { carrier: 'Lycamobile Germany', provider: 'reloadly', code: '864', is_primary: true, is_enabled: true, priority: 10, notes: 'Reloadly Primary: Micro-Refill Lycamobile 5 EUR PIN ($5.92 USD)' },
    { carrier: 'Lycamobile Germany', provider: 'dtone', code: '2121', is_primary: false, is_enabled: false, priority: 20, notes: 'DT One Disabled: 0 pre-prod products' },
    { carrier: 'Lycamobile Germany', provider: 'ding', code: 'LYDE', is_primary: false, is_enabled: false, priority: 30, notes: 'DingConnect Disabled: 0 UAT inventory' },

    // Blau
    { carrier: 'Blau', provider: 'reloadly', code: '849', is_primary: true, is_enabled: true, priority: 10, notes: 'Reloadly Primary: Blau PIN 15, 25, 30 EUR' },
    { carrier: 'Blau', provider: 'zendit', code: 'Blau', is_primary: false, is_enabled: true, priority: 20, notes: 'Zendit Secondary: BLAU_DE_001-ROW (15 EUR)' },
    { carrier: 'Blau', provider: 'dtone', code: '2754', is_primary: false, is_enabled: false, priority: 30, notes: 'DT One Disabled: 0 pre-prod products' },
    { carrier: 'Blau', provider: 'ding', code: 'BSDE', is_primary: false, is_enabled: false, priority: 40, notes: 'DingConnect Disabled: 0 UAT inventory' },

    // Ortel Mobile
    { carrier: 'Ortel Mobile', provider: 'reloadly', code: '665', is_primary: true, is_enabled: true, priority: 10, notes: 'Reloadly Primary: Ortel PIN 15, 20, 30 EUR' },
    { carrier: 'Ortel Mobile', provider: 'zendit', code: 'Ortel', is_primary: false, is_enabled: true, priority: 20, notes: 'Zendit Secondary: ORTEL_DE_001-ROW (15 EUR)' },
    { carrier: 'Ortel Mobile', provider: 'dtone', code: '2146', is_primary: false, is_enabled: false, priority: 30, notes: 'DT One Disabled: 0 pre-prod products' },
    { carrier: 'Ortel Mobile', provider: 'ding', code: 'OTDE', is_primary: false, is_enabled: false, priority: 40, notes: 'DingConnect Disabled: 0 UAT inventory' },

    // Ay Yildiz
    { carrier: 'Ay Yildiz', provider: 'zendit', code: 'AyYildiz', is_primary: true, is_enabled: true, priority: 10, notes: 'Zendit Primary: AYYILDIZ_DE_001-ROW (15 EUR)' },
    { carrier: 'Ay Yildiz', provider: 'dtone', code: '2135', is_primary: false, is_enabled: false, priority: 20, notes: 'DT One Disabled: 0 pre-prod products' },
    { carrier: 'Ay Yildiz', provider: 'ding', code: 'AYDE', is_primary: false, is_enabled: false, priority: 30, notes: 'DingConnect Disabled: 0 UAT inventory' },

    // Otelo
    { carrier: 'Otelo', provider: 'reloadly', code: '867', is_primary: true, is_enabled: true, priority: 10, notes: 'Reloadly Primary: Otelo PIN 9, 19, 29 EUR ($9.00 USD for 9 EUR)' },
    { carrier: 'Otelo', provider: 'zendit', code: 'OTELO', is_primary: false, is_enabled: true, priority: 20, notes: 'Zendit Secondary: OTELO_DE_001-ROW (9 EUR)' },
    { carrier: 'Otelo', provider: 'dtone', code: '2148', is_primary: false, is_enabled: false, priority: 30, notes: 'DT One Disabled: 0 pre-prod products' },
    { carrier: 'Otelo', provider: 'ding', code: 'OEDE', is_primary: false, is_enabled: false, priority: 40, notes: 'DingConnect Disabled: 0 UAT inventory' },

    // Fonic
    { carrier: 'Fonic', provider: 'reloadly', code: '853', is_primary: true, is_enabled: true, priority: 10, notes: 'Reloadly Primary: Fonic PIN 20, 30 EUR' },
    { carrier: 'Fonic', provider: 'dtone', code: '2768', is_primary: false, is_enabled: false, priority: 20, notes: 'DT One Disabled: 0 pre-prod products' },
    { carrier: 'Fonic', provider: 'ding', code: 'F1DE', is_primary: false, is_enabled: false, priority: 30, notes: 'DingConnect Disabled: 0 UAT inventory' },

    // Tchibo Mobil
    { carrier: 'Tchibo Mobil', provider: 'reloadly', code: '872', is_primary: true, is_enabled: true, priority: 10, notes: 'Reloadly Primary: Tchibo PIN 20 EUR' },
    { carrier: 'Tchibo Mobil', provider: 'ding', code: 'E825B8DE', is_primary: false, is_enabled: false, priority: 20, notes: 'DingConnect Disabled: 0 UAT inventory' },

    // Klarmobil
    { carrier: 'Klarmobil', provider: 'reloadly', code: '854', is_primary: true, is_enabled: true, priority: 10, notes: 'Reloadly Primary: Klarmobil PIN 15, 30, 50 EUR' },
    { carrier: 'Klarmobil', provider: 'dtone', code: '3117', is_primary: false, is_enabled: false, priority: 20, notes: 'DT One Disabled: 0 pre-prod products' },

    // BILDmobil
    { carrier: 'BILDmobil', provider: 'reloadly', code: '848', is_primary: true, is_enabled: true, priority: 10, notes: 'Reloadly Primary: BILDmobil PIN 10, 20 EUR' },
    { carrier: 'BILDmobil', provider: 'dtone', code: '3111', is_primary: false, is_enabled: false, priority: 20, notes: 'DT One Disabled: 0 pre-prod products' },
    { carrier: 'BILDmobil', provider: 'ding', code: 'B6DE', is_primary: false, is_enabled: false, priority: 30, notes: 'DingConnect Disabled: 0 UAT inventory' }
  ];

  for (const pm of providerMaps) {
    const norm = pm.carrier.toLowerCase().trim();
    const carrier = carrierMapByName[norm];
    if (!carrier) {
      console.log(`Carrier not found for ${pm.carrier}`);
      continue;
    }

    const existingMap = await api(`carrier_provider_map?carrier_id=eq.${carrier.id}&provider=eq.${pm.provider}`);
    const payload = {
      carrier_id: carrier.id,
      provider: pm.provider,
      provider_carrier_code: pm.code,
      provider_country_code: pm.provider === 'dtone' ? 'DEU' : 'DE',
      provider_carrier_label: pm.carrier,
      provider_country_label: 'Germany',
      is_enabled: pm.is_enabled,
      is_primary: pm.is_primary,
      priority: pm.priority,
      notes: pm.notes,
      last_verified_at: nowIso
    };

    if (existingMap && existingMap.length > 0) {
      console.log(`Updating mapping for ${pm.carrier} (${pm.provider})...`);
      await api(`carrier_provider_map?id=eq.${existingMap[0].id}`, 'PATCH', payload);
    } else {
      console.log(`Inserting mapping for ${pm.carrier} (${pm.provider})...`);
      await api('carrier_provider_map', 'POST', payload);
    }
  }

  console.log('\n====================================================');
  console.log('=== SUPABASE GERMANY PROVISIONING COMPLETE ===');
  console.log('====================================================');
}

main();
