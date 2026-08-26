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
  console.log('=== PROVISIONING ALGERIA (DZ / DZA / +213) IN SUPABASE ===');
  console.log('====================================================');

  // 1. Check or Insert Country: Algeria
  console.log('\n1. Checking / Creating Algeria country record...');
  let countryRecords = await api('countries?iso_code=eq.DZ');
  let dzCountryId;

  if (countryRecords && countryRecords.length > 0) {
    console.log('Algeria country record found, updating is_supported: true...');
    const updated = await api(`countries?id=eq.${countryRecords[0].id}`, 'PATCH', {
      is_supported: true,
      name: 'Algeria',
      dialing_code: '+213',
      flag_emoji: '🇩🇿',
      currency_code: 'DZD',
      avg_sim_replacement_cost: 2.50
    });
    dzCountryId = updated[0].id;
  } else {
    console.log('Inserting Algeria country record...');
    const inserted = await api('countries', 'POST', {
      name: 'Algeria',
      iso_code: 'DZ',
      dialing_code: '+213',
      flag_emoji: '🇩🇿',
      currency_code: 'DZD',
      avg_sim_replacement_cost: 2.50,
      is_supported: true
    });
    dzCountryId = inserted[0].id;
    console.log('Inserted Algeria country:', inserted[0]);
  }

  console.log(`Algeria Country ID: ${dzCountryId}`);

  // 2. Carriers Setup
  const targetCarriers = [
    { name: 'Mobilis', canonical: 'Mobilis', default_refill_amount: 0.71 },
    { name: 'Djezzy', canonical: 'Djezzy', default_refill_amount: 0.71 },
    { name: 'Ooredoo Algeria', canonical: 'Ooredoo Algeria', default_refill_amount: 0.73 }
  ];

  const existingCarriers = await api(`carriers?country_id=eq.${dzCountryId}`);
  console.log(`Found ${existingCarriers.length} existing carriers for Algeria`);

  const carrierMapByName = {};
  existingCarriers.forEach(c => {
    carrierMapByName[c.name.toLowerCase().trim()] = c;
  });

  const carrierIdMap = {};

  for (const tc of targetCarriers) {
    let matched = null;
    for (const [key, val] of Object.entries(carrierMapByName)) {
      if (key.includes(tc.canonical.toLowerCase()) || tc.canonical.toLowerCase().includes(key) ||
          (tc.canonical.includes('Ooredoo') && key.includes('ooredoo'))) {
        matched = val;
        break;
      }
    }

    if (matched) {
      console.log(`Updating existing carrier ${tc.canonical} (ID: ${matched.id})...`);
      const updated = await api(`carriers?id=eq.${matched.id}`, 'PATCH', {
        name: tc.canonical,
        is_supported: true,
        country_id: dzCountryId,
        default_refill_amount: tc.default_refill_amount,
        fulfillment_gateway: 'API'
      });
      carrierIdMap[tc.canonical] = updated[0].id;
    } else {
      console.log(`Inserting new carrier ${tc.canonical}...`);
      const inserted = await api('carriers', 'POST', {
        country_id: dzCountryId,
        name: tc.canonical,
        is_supported: true,
        fulfillment_gateway: 'API',
        default_refill_amount: tc.default_refill_amount
      });
      carrierIdMap[tc.canonical] = inserted[0].id;
      console.log(`Inserted carrier ${tc.canonical}:`, inserted[0].id);
    }
  }

  console.log('\nCarrier IDs mapped:', carrierIdMap);

  // 3. Upsert Carrier Rules (ARPCE Algeria Regulatory Framework)
  console.log('\n3. Upserting carrier rules for Algeria...');
  for (const [carrierName, carrierId] of Object.entries(carrierIdMap)) {
    const existingRules = await api(`carrier_rules?carrier_id=eq.${carrierId}`);
    
    let offerId = 'MOBILIS_DZ_01';
    let notes = 'Mobilis (ATM Mobilis / Algérie Télécom): ARPCE Algeria 60 to 90-day active validity from last recharge. 90-day grace/suspension period before permanent disconnection & number recycling. 19% VAT included. Mini-refill on Day 50-75 with 100 DZD resets the active validity window.';
    let minTopup = 0.71;

    if (carrierName.includes('Djezzy')) {
      offerId = 'DJEZZY_DZ_01';
      notes = 'Djezzy (Optimum Telecom Algeria / FNI): ARPCE Algeria 60 to 90-day active validity from last recharge. 90-day grace/suspension period before permanent disconnection & number recycling. 19% VAT included. Mini-refill on Day 50-75 with 100 DZD resets the active validity window.';
      minTopup = 0.71;
    } else if (carrierName.includes('Ooredoo')) {
      offerId = 'OOREDOO_DZ_01';
      notes = 'Ooredoo Algeria (Wataniya Télécom Algérie / Nedjma): ARPCE Algeria 60 to 90-day active validity from last recharge. 90-day grace/suspension period before permanent disconnection & number recycling. 19% VAT included. Mini-refill on Day 50-75 with 100 DZD resets the active validity window.';
      minTopup = 0.73;
    }

    const ruleData = {
      carrier_id: carrierId,
      rule_type: 'prepaid',
      inactivity_limit_days: 90,
      grace_period_days: 90,
      minimum_topup_amount: minTopup,
      topup_validity_days: 90,
      recommended_topup_amount: minTopup,
      inapp_pricing: parseFloat((minTopup * 1.25).toFixed(4)),
      inapp_pricing_currency: 'usd',
      offer_id: offerId,
      activity_requirement: 'recharge_ok',
      balance_validity_days: 180,
      notes: notes,
      sms_language: 'auto',
      last_verified_at: new Date().toISOString()
    };

    if (existingRules && existingRules.length > 0) {
      console.log(`Updating carrier_rules for ${carrierName}...`);
      await api(`carrier_rules?id=eq.${existingRules[0].id}`, 'PATCH', ruleData);
    } else {
      console.log(`Inserting carrier_rules for ${carrierName}...`);
      await api('carrier_rules', 'POST', ruleData);
    }
  }

  // 4. Upsert Carrier Provider Maps
  console.log('\n4. Upserting carrier_provider_map for Algeria...');

  const providerConfigs = [
    // --- MOBILIS ---
    {
      carrier: 'Mobilis',
      provider: 'zendit',
      provider_country_code: 'DZ',
      provider_carrier_code: 'MOBILIS',
      provider_carrier_label: 'Mobilis Algeria',
      provider_country_label: 'Algeria',
      is_enabled: true,
      is_primary: true,
      priority: 10,
      notes: 'Zendit Primary Direct Top-Up: Offers MOBILIS_DZ_01 (100 DZD @ $0.71 USD) up to MOBILIS_DZ_10 (2000 DZD @ $14.17 USD)'
    },
    {
      carrier: 'Mobilis',
      provider: 'dtone',
      provider_country_code: 'DZA',
      provider_carrier_code: '4',
      provider_carrier_label: 'Mobilis Algeria',
      provider_country_label: 'Algeria',
      is_enabled: true,
      is_primary: false,
      priority: 20,
      notes: 'DT One Secondary Direct: Product 14299 (100 DZD @ 0.296 OMR / ~$0.77 USD) up to 2000 DZD (14307)'
    },
    {
      carrier: 'Mobilis',
      provider: 'reloadly',
      provider_country_code: 'DZ',
      provider_carrier_code: '6',
      provider_carrier_label: 'Mobilis Algeria',
      provider_country_label: 'Algeria',
      is_enabled: true,
      is_primary: false,
      priority: 30,
      notes: 'Reloadly Tertiary Direct: Operator 6 (100 to 2000 DZD, 100 DZD from $0.97 USD fixed / $0.9215 net)'
    },
    {
      carrier: 'Mobilis',
      provider: 'ding',
      provider_country_code: 'DZ',
      provider_carrier_code: 'MDDZ',
      provider_carrier_label: 'Mobilis Algeria',
      provider_country_label: 'Algeria',
      is_enabled: false,
      is_primary: false,
      priority: 40,
      notes: 'DingConnect Disabled: 0 UAT products (503 RateLimited)'
    },

    // --- DJEZZY ---
    {
      carrier: 'Djezzy',
      provider: 'zendit',
      provider_country_code: 'DZ',
      provider_carrier_code: 'DJEZZY',
      provider_carrier_label: 'Djezzy Algeria',
      provider_country_label: 'Algeria',
      is_enabled: true,
      is_primary: true,
      priority: 10,
      notes: 'Zendit Primary Direct Top-Up: Offers DJEZZY_DZ_01 (100 DZD @ $0.71 USD) up to DJEZZY_DZ_10 (2000 DZD @ $14.17 USD)'
    },
    {
      carrier: 'Djezzy',
      provider: 'dtone',
      provider_country_code: 'DZA',
      provider_carrier_code: '2074',
      provider_carrier_label: 'Djezzy Algeria',
      provider_country_label: 'Algeria',
      is_enabled: true,
      is_primary: false,
      priority: 20,
      notes: 'DT One Secondary Direct: Product 14308 (100 DZD @ 0.296 OMR / ~$0.77 USD) up to 2000 DZD (14316)'
    },
    {
      carrier: 'Djezzy',
      provider: 'reloadly',
      provider_country_code: 'DZ',
      provider_carrier_code: '8',
      provider_carrier_label: 'Djezzy Algeria',
      provider_country_label: 'Algeria',
      is_enabled: true,
      is_primary: false,
      priority: 30,
      notes: 'Reloadly Tertiary Direct: Operator 8 (500 to 2000 DZD, 500 DZD from $4.84 USD fixed / $4.598 net)'
    },
    {
      carrier: 'Djezzy',
      provider: 'ding',
      provider_country_code: 'DZ',
      provider_carrier_code: 'DJDZ',
      provider_carrier_label: 'Djezzy Algeria',
      provider_country_label: 'Algeria',
      is_enabled: false,
      is_primary: false,
      priority: 40,
      notes: 'DingConnect Disabled: 0 UAT products (503 RateLimited)'
    },

    // --- OOREDOO ALGERIA ---
    {
      carrier: 'Ooredoo Algeria',
      provider: 'zendit',
      provider_country_code: 'DZ',
      provider_carrier_code: 'OOREDOO',
      provider_carrier_label: 'Ooredoo Algeria',
      provider_country_label: 'Algeria',
      is_enabled: true,
      is_primary: true,
      priority: 10,
      notes: 'Zendit Primary Direct Top-Up: Offers OOREDOO_DZ_01 (100 DZD @ $0.73 USD) up to OOREDOO_DZ_10 (2000 DZD @ $14.60 USD)'
    },
    {
      carrier: 'Ooredoo Algeria',
      provider: 'dtone',
      provider_country_code: 'DZA',
      provider_carrier_code: '2075',
      provider_carrier_label: 'Ooredoo Algeria',
      provider_country_label: 'Algeria',
      is_enabled: true,
      is_primary: false,
      priority: 20,
      notes: 'DT One Secondary Direct & Bundles: Product 14317 (100 DZD @ 0.296 OMR / ~$0.77 USD) up to 2000 DZD, MAXY 1000 (2304) and Data bundles (56642-56656)'
    },
    {
      carrier: 'Ooredoo Algeria',
      provider: 'reloadly',
      provider_country_code: 'DZ',
      provider_carrier_code: '7',
      provider_carrier_label: 'Ooredoo Algeria',
      provider_country_label: 'Algeria',
      is_enabled: true,
      is_primary: false,
      priority: 30,
      notes: 'Reloadly Tertiary Direct: Operator 7 (100 to 2000 DZD, 100 DZD from $0.97 USD fixed / $0.9215 net)'
    },
    {
      carrier: 'Ooredoo Algeria',
      provider: 'ding',
      provider_country_code: 'DZ',
      provider_carrier_code: 'OODZ',
      provider_carrier_label: 'Ooredoo Algeria',
      provider_country_label: 'Algeria',
      is_enabled: false,
      is_primary: false,
      priority: 40,
      notes: 'DingConnect Disabled: 0 UAT products (503 RateLimited)'
    }
  ];

  for (const cfg of providerConfigs) {
    const carrierId = carrierIdMap[cfg.carrier];
    if (!carrierId) {
      console.warn(`Carrier ID not found for ${cfg.carrier}`);
      continue;
    }

    const existingMap = await api(`carrier_provider_map?carrier_id=eq.${carrierId}&provider=eq.${cfg.provider}`);
    const mapData = {
      carrier_id: carrierId,
      provider: cfg.provider,
      provider_country_code: cfg.provider_country_code,
      provider_carrier_code: cfg.provider_carrier_code,
      provider_carrier_label: cfg.provider_carrier_label,
      provider_country_label: cfg.provider_country_label,
      is_enabled: cfg.is_enabled,
      is_primary: cfg.is_primary,
      priority: cfg.priority,
      notes: cfg.notes,
      last_verified_at: new Date().toISOString()
    };

    if (existingMap && existingMap.length > 0) {
      console.log(`Updating map for ${cfg.carrier} -> ${cfg.provider}...`);
      await api(`carrier_provider_map?id=eq.${existingMap[0].id}`, 'PATCH', mapData);
    } else {
      console.log(`Inserting map for ${cfg.carrier} -> ${cfg.provider}...`);
      await api('carrier_provider_map', 'POST', mapData);
    }
  }

  console.log('\n=== ALGERIA PROVISIONING COMPLETE ===');
}

main().catch(console.error);
