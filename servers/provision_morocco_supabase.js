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
  console.log('=== PROVISIONING MOROCCO (MA / +212) IN SUPABASE ===');
  console.log('====================================================');

  // 1. Check or Insert Country: Morocco
  console.log('\n1. Checking / Creating Morocco country record...');
  let countryRecords = await api('countries?iso_code=eq.MA');
  let maCountryId;

  if (countryRecords && countryRecords.length > 0) {
    console.log('Morocco country record found, updating is_supported: true...');
    const updated = await api(`countries?id=eq.${countryRecords[0].id}`, 'PATCH', {
      is_supported: true,
      name: 'Morocco',
      dialing_code: '+212',
      flag_emoji: '🇲🇦',
      currency_code: 'MAD',
      avg_sim_replacement_cost: 2.00
    });
    maCountryId = updated[0].id;
  } else {
    console.log('Inserting Morocco country record...');
    const inserted = await api('countries', 'POST', {
      name: 'Morocco',
      iso_code: 'MA',
      dialing_code: '+212',
      flag_emoji: '🇲🇦',
      currency_code: 'MAD',
      avg_sim_replacement_cost: 2.00,
      is_supported: true
    });
    maCountryId = inserted[0].id;
    console.log('Inserted Morocco country:', inserted[0]);
  }

  console.log(`Morocco Country ID: ${maCountryId}`);

  // 2. Carriers Setup
  const targetCarriers = [
    { name: 'Maroc Telecom', canonical: 'Maroc Telecom', default_refill_amount: 0.63 },
    { name: 'Orange Morocco', canonical: 'Orange Morocco', default_refill_amount: 0.79 },
    { name: 'Inwi', canonical: 'Inwi', default_refill_amount: 0.60 }
  ];

  const existingCarriers = await api(`carriers?country_id=eq.${maCountryId}`);
  console.log(`Found ${existingCarriers.length} existing carriers for Morocco`);

  const carrierMapByName = {};
  existingCarriers.forEach(c => {
    carrierMapByName[c.name.toLowerCase().trim()] = c;
  });

  const carrierIdMap = {};

  for (const tc of targetCarriers) {
    let matched = null;
    for (const [key, val] of Object.entries(carrierMapByName)) {
      if (key.includes(tc.canonical.toLowerCase()) || tc.canonical.toLowerCase().includes(key)) {
        matched = val;
        break;
      }
    }

    if (matched) {
      console.log(`Updating existing carrier ${tc.canonical} (ID: ${matched.id})...`);
      const updated = await api(`carriers?id=eq.${matched.id}`, 'PATCH', {
        name: tc.canonical,
        is_supported: true,
        country_id: maCountryId,
        default_refill_amount: tc.default_refill_amount,
        fulfillment_gateway: 'API'
      });
      carrierIdMap[tc.canonical] = updated[0].id;
    } else {
      console.log(`Inserting new carrier ${tc.canonical}...`);
      const inserted = await api('carriers', 'POST', {
        country_id: maCountryId,
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

  // 3. Upsert Carrier Rules (ANRT Morocco Regulatory Framework)
  console.log('\n3. Upserting carrier rules for Morocco...');
  for (const [carrierName, carrierId] of Object.entries(carrierIdMap)) {
    const existingRules = await api(`carrier_rules?carrier_id=eq.${carrierId}`);
    
    let offerId = 'MAROC_TELECOM_MA_001';
    let notes = 'Maroc Telecom (IAM / Jawal): ANRT Morocco 90 to 180-day active validity from last recharge. 90-day grace/suspension period before permanent disconnection & number recycling. Mini-refill on Day 60-80 with 5 MAD resets the 180-day active window.';
    let minTopup = 0.63;

    if (carrierName.includes('Orange')) {
      offerId = 'ORANGE_MA_001';
      notes = 'Orange Morocco (formerly Méditel): ANRT Morocco 90 to 180-day active validity from last recharge. 90-day grace/suspension period before permanent disconnection & number recycling. Mini-refill on Day 60-80 with 6 MAD resets the 180-day active window.';
      minTopup = 0.79;
    } else if (carrierName.includes('Inwi')) {
      offerId = 'INWI_MA_001';
      notes = 'Inwi Morocco (Wana Corporate / Tic Tac): ANRT Morocco 90 to 180-day active validity from last recharge. 90-day grace/suspension period before permanent disconnection & number recycling. Mini-refill on Day 60-80 with 5 MAD resets the 180-day active window.';
      minTopup = 0.60;
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
  console.log('\n4. Upserting carrier_provider_map for Morocco...');

  const providerConfigs = [
    // --- MAROC TELECOM ---
    {
      carrier: 'Maroc Telecom',
      provider: 'dtone',
      provider_country_code: 'MAR',
      provider_carrier_code: '1533',
      provider_carrier_label: 'Maroc Telecom Morocco',
      provider_country_label: 'Morocco',
      is_enabled: true,
      is_primary: true,
      priority: 10,
      notes: 'DT One Primary Direct: Product 4073 (5 MAD @ 0.242 OMR / ~$0.63 USD) up to 300 MAD, plus Jawal Internet Pass (1914-1920) and Social Media Passes'
    },
    {
      carrier: 'Maroc Telecom',
      provider: 'reloadly',
      provider_country_code: 'MA',
      provider_carrier_code: '311',
      provider_carrier_label: 'Maroc Telecom Morocco',
      provider_country_label: 'Morocco',
      is_enabled: true,
      is_primary: false,
      priority: 20,
      notes: 'Reloadly Secondary Direct: Operator 311 (Fixed 5-300 MAD from $0.63 USD) and Operator 310 (Data Bundles from $0.75 USD)'
    },
    {
      carrier: 'Maroc Telecom',
      provider: 'ding',
      provider_country_code: 'MA',
      provider_carrier_code: 'MOMA',
      provider_carrier_label: 'Maroc Telecom Morocco',
      provider_country_label: 'Morocco',
      is_enabled: false,
      is_primary: false,
      priority: 40,
      notes: 'DingConnect Disabled: 0 UAT products'
    },
    {
      carrier: 'Maroc Telecom',
      provider: 'zendit',
      provider_country_code: 'MA',
      provider_carrier_code: 'MarocTelecom',
      provider_carrier_label: 'Maroc Telecom',
      provider_country_label: 'Morocco',
      is_enabled: false,
      is_primary: false,
      priority: 50,
      notes: 'Zendit Disabled: 0 sandbox offers'
    },

    // --- ORANGE MOROCCO ---
    {
      carrier: 'Orange Morocco',
      provider: 'dtone',
      provider_country_code: 'MAR',
      provider_carrier_code: '387',
      provider_carrier_label: 'Orange Morocco',
      provider_country_label: 'Morocco',
      is_enabled: true,
      is_primary: true,
      priority: 10,
      notes: 'DT One Primary Direct: Product 50285 (6 MAD @ 0.302 OMR / ~$0.79 USD) up to 330 MAD, plus Range 54511 (33-330 MAD) and Social Media Passes'
    },
    {
      carrier: 'Orange Morocco',
      provider: 'reloadly',
      provider_country_code: 'MA',
      provider_carrier_code: '313',
      provider_carrier_label: 'Orange Morocco',
      provider_country_label: 'Morocco',
      is_enabled: true,
      is_primary: false,
      priority: 20,
      notes: 'Reloadly Secondary Direct: Operator 313 (Range 36.86-330 MAD from $4.38 USD), Operator 690 (Bundles), Operator 309 (Data)'
    },
    {
      carrier: 'Orange Morocco',
      provider: 'ding',
      provider_country_code: 'MA',
      provider_carrier_code: 'ORMA',
      provider_carrier_label: 'Orange Morocco',
      provider_country_label: 'Morocco',
      is_enabled: false,
      is_primary: false,
      priority: 40,
      notes: 'DingConnect Disabled: 0 UAT products'
    },
    {
      carrier: 'Orange Morocco',
      provider: 'zendit',
      provider_country_code: 'MA',
      provider_carrier_code: 'Orange',
      provider_carrier_label: 'Orange Morocco',
      provider_country_label: 'Morocco',
      is_enabled: false,
      is_primary: false,
      priority: 50,
      notes: 'Zendit Disabled: 0 sandbox offers'
    },

    // --- INWI ---
    {
      carrier: 'Inwi',
      provider: 'dtone',
      provider_country_code: 'MAR',
      provider_carrier_code: '1711',
      provider_carrier_label: 'Inwi Morocco',
      provider_country_label: 'Morocco',
      is_enabled: true,
      is_primary: true,
      priority: 10,
      notes: 'DT One Primary Direct: Product 16801 (5 MAD @ 0.245 OMR / ~$0.64 USD) up to 300 MAD, plus Internet Pass (1927-1934) and Social Media Passes'
    },
    {
      carrier: 'Inwi',
      provider: 'reloadly',
      provider_country_code: 'MA',
      provider_carrier_code: '312',
      provider_carrier_label: 'Inwi Morocco',
      provider_country_label: 'Morocco',
      is_enabled: true,
      is_primary: false,
      priority: 20,
      notes: 'Reloadly Secondary Direct: Operator 312 (Fixed 5-200 MAD from $0.60 USD) and Operator 308 (Data Bundles from $0.60 USD)'
    },
    {
      carrier: 'Inwi',
      provider: 'ding',
      provider_country_code: 'MA',
      provider_carrier_code: 'INMA',
      provider_carrier_label: 'Inwi Morocco',
      provider_country_label: 'Morocco',
      is_enabled: false,
      is_primary: false,
      priority: 40,
      notes: 'DingConnect Disabled: 0 UAT products'
    },
    {
      carrier: 'Inwi',
      provider: 'zendit',
      provider_country_code: 'MA',
      provider_carrier_code: 'Inwi',
      provider_carrier_label: 'Inwi Morocco',
      provider_country_label: 'Morocco',
      is_enabled: false,
      is_primary: false,
      priority: 50,
      notes: 'Zendit Disabled: 0 sandbox offers'
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

  console.log('\n=== MOROCCO PROVISIONING COMPLETE ===');
}

main().catch(console.error);
