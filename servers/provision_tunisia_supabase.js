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
  console.log('=== PROVISIONING TUNISIA (TN / +216) IN SUPABASE ===');
  console.log('====================================================');

  // 1. Check or Insert Country: Tunisia
  console.log('\n1. Checking / Creating Tunisia country record...');
  let countryRecords = await api('countries?iso_code=eq.TN');
  let tnCountryId;

  if (countryRecords && countryRecords.length > 0) {
    console.log('Tunisia country record found, updating is_supported: true...');
    const updated = await api(`countries?id=eq.${countryRecords[0].id}`, 'PATCH', {
      is_supported: true,
      name: 'Tunisia',
      dialing_code: '+216',
      flag_emoji: '🇹🇳',
      currency_code: 'TND',
      avg_sim_replacement_cost: 3.00
    });
    tnCountryId = updated[0].id;
  } else {
    console.log('Inserting Tunisia country record...');
    const inserted = await api('countries', 'POST', {
      name: 'Tunisia',
      iso_code: 'TN',
      dialing_code: '+216',
      flag_emoji: '🇹🇳',
      currency_code: 'TND',
      avg_sim_replacement_cost: 3.00,
      is_supported: true
    });
    tnCountryId = inserted[0].id;
    console.log('Inserted Tunisia country:', inserted[0]);
  }

  console.log(`Tunisia Country ID: ${tnCountryId}`);

  // 2. Carriers Setup
  const targetCarriers = [
    { name: 'Ooredoo Tunisia', canonical: 'Ooredoo Tunisia', default_refill_amount: 0.85 },
    { name: 'Tunisie Telecom', canonical: 'Tunisie Telecom', default_refill_amount: 2.22 },
    { name: 'Orange Tunisia', canonical: 'Orange Tunisia', default_refill_amount: 0.67 }
  ];

  const existingCarriers = await api(`carriers?country_id=eq.${tnCountryId}`);
  console.log(`Found ${existingCarriers.length} existing carriers for Tunisia`);

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
        country_id: tnCountryId,
        default_refill_amount: tc.default_refill_amount,
        fulfillment_gateway: 'API'
      });
      carrierIdMap[tc.canonical] = updated[0].id;
    } else {
      console.log(`Inserting new carrier ${tc.canonical}...`);
      const inserted = await api('carriers', 'POST', {
        country_id: tnCountryId,
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

  // 3. Upsert Carrier Rules (INTT Tunisia Regulatory Framework)
  console.log('\n3. Upserting carrier rules for Tunisia...');
  for (const [carrierName, carrierId] of Object.entries(carrierIdMap)) {
    const existingRules = await api(`carrier_rules?carrier_id=eq.${carrierId}`);
    
    let offerId = 'OOREDOO_TN_001';
    let notes = 'Ooredoo Tunisia (formerly Tunisiana): INTT Tunisia 90 to 180-day active validity from last recharge. 90-day grace/quarantine period before permanent disconnection & number recycling. Mini-refill on Day 60-80 with 2 TND resets the active window.';
    let minTopup = 0.85;

    if (carrierName.includes('Tunisie Telecom')) {
      offerId = 'TUNISIETELECOM_TN_001';
      notes = 'Tunisie Telecom: INTT Tunisia 90 to 180-day active validity from last recharge. 90-day grace/quarantine period before permanent disconnection & number recycling. Mini-refill on Day 60-80 with 5.4 TND resets the active window.';
      minTopup = 2.22;
    } else if (carrierName.includes('Orange')) {
      offerId = 'ORANGE_TN_001';
      notes = 'Orange Tunisia: INTT Tunisia 90 to 180-day active validity from last recharge. 90-day grace/quarantine period before permanent disconnection & number recycling. Mini-refill on Day 60-80 with 1.6 TND resets the active window.';
      minTopup = 0.67;
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
  console.log('\n4. Upserting carrier_provider_map for Tunisia...');

  const providerConfigs = [
    // --- OOREDOO TUNISIA ---
    {
      carrier: 'Ooredoo Tunisia',
      provider: 'dtone',
      provider_country_code: 'TUN',
      provider_carrier_code: '1532',
      provider_carrier_label: 'Ooredoo Tunisia',
      provider_country_label: 'Tunisia',
      is_enabled: true,
      is_primary: true,
      priority: 10,
      notes: 'DT One Primary Direct: Product 6095 (2 TND @ 0.325 OMR / ~$0.845 USD), Product 11905 (Open_Range 2-150 TND), plus 32 fixed denominations (2-60 TND)'
    },
    {
      carrier: 'Ooredoo Tunisia',
      provider: 'reloadly',
      provider_country_code: 'TN',
      provider_carrier_code: '508',
      provider_carrier_label: 'Ooredoo Tunisia',
      provider_country_label: 'Tunisia',
      is_enabled: true,
      is_primary: false,
      priority: 20,
      notes: 'Reloadly Secondary Direct: Operator 508 (Range $0.93-$70.09 USD / 2-150 TND with 5% discount, delivering from 2.14 TND @ $0.95 USD cost)'
    },
    {
      carrier: 'Ooredoo Tunisia',
      provider: 'zendit',
      provider_country_code: 'TN',
      provider_carrier_code: 'Ooredoo',
      provider_carrier_label: 'Ooredoo Tunisia',
      provider_country_label: 'Tunisia',
      is_enabled: true,
      is_primary: false,
      priority: 30,
      notes: 'Zendit Tertiary Direct: 7 Fixed Offers (OOREDOO_TN_001_W to 007_W from 5 TND @ $1.89 USD wholesale up to 75 TND)'
    },
    {
      carrier: 'Ooredoo Tunisia',
      provider: 'ding',
      provider_country_code: 'TN',
      provider_carrier_code: 'TUTN',
      provider_carrier_label: 'Ooredoo (Tunisiana) Tunisia',
      provider_country_label: 'Tunisia',
      is_enabled: false,
      is_primary: false,
      priority: 40,
      notes: 'DingConnect Disabled: 0 active products in UAT catalog'
    },

    // --- TUNISIE TELECOM ---
    {
      carrier: 'Tunisie Telecom',
      provider: 'dtone',
      provider_country_code: 'TUN',
      provider_carrier_code: '678',
      provider_carrier_label: 'Tunisie Telecom Tunisia',
      provider_country_label: 'Tunisia',
      is_enabled: true,
      is_primary: true,
      priority: 10,
      notes: 'DT One Primary Direct: Product 8572 (5.4 TND @ 0.852 OMR / ~$2.215 USD), 8573 (10.8 TND @ 1.703 OMR), 8574 (21.6 TND @ 3.405 OMR)'
    },
    {
      carrier: 'Tunisie Telecom',
      provider: 'reloadly',
      provider_country_code: 'TN',
      provider_carrier_code: '507',
      provider_carrier_label: 'Tunisie Telecom Tunisia',
      provider_country_label: 'Tunisia',
      is_enabled: true,
      is_primary: false,
      priority: 20,
      notes: 'Reloadly Secondary Direct: Operator 507 (Fixed 5.4, 10.8, 21.6 TND from $2.352 USD cost with 2% discount)'
    },
    {
      carrier: 'Tunisie Telecom',
      provider: 'zendit',
      provider_country_code: 'TN',
      provider_carrier_code: 'TunisieTelecom',
      provider_carrier_label: 'Tunisie Telecom',
      provider_country_label: 'Tunisia',
      is_enabled: true,
      is_primary: false,
      priority: 30,
      notes: 'Zendit Tertiary Direct: 3 Fixed Offers (TUNISIETELECOM_TN_001 to 003 from 5.4 TND @ $2.09 USD wholesale cost)'
    },
    {
      carrier: 'Tunisie Telecom',
      provider: 'ding',
      provider_country_code: 'TN',
      provider_carrier_code: 'TWTN',
      provider_carrier_label: 'Tunisie Telecom Tunisia',
      provider_country_label: 'Tunisia',
      is_enabled: false,
      is_primary: false,
      priority: 40,
      notes: 'DingConnect Disabled: 0 active products in UAT catalog'
    },

    // --- ORANGE TUNISIA ---
    {
      carrier: 'Orange Tunisia',
      provider: 'dtone',
      provider_country_code: 'TUN',
      provider_carrier_code: '1530',
      provider_carrier_label: 'Orange Tunisia',
      provider_country_label: 'Tunisia',
      is_enabled: true,
      is_primary: true,
      priority: 10,
      notes: 'DT One Primary Direct: Product 50404 (1.6 TND @ 0.259 OMR / ~$0.673 USD), 54628 (Range 10-102 TND), plus 31 fixed denominations (1.6-200 TND)'
    },
    {
      carrier: 'Orange Tunisia',
      provider: 'reloadly',
      provider_country_code: 'TN',
      provider_carrier_code: '506',
      provider_carrier_label: 'Orange Tunisia',
      provider_country_label: 'Tunisia',
      is_enabled: true,
      is_primary: false,
      priority: 20,
      notes: 'Reloadly Secondary Direct: Operator 506 (Range $4.35-$79.05 USD / 11-200 TND with 10% discount, delivering 12.65 TND @ $4.50 USD cost)'
    },
    {
      carrier: 'Orange Tunisia',
      provider: 'zendit',
      provider_country_code: 'TN',
      provider_carrier_code: 'Orange',
      provider_carrier_label: 'Orange Tunisia',
      provider_country_label: 'Tunisia',
      is_enabled: true,
      is_primary: false,
      priority: 30,
      notes: 'Zendit Tertiary Direct: 35 Fixed Offers (ORANGE_TN_001_W to 035_W from 13.52 TND @ $4.77 USD wholesale) + Range ORANGE_TN_OPEN (9.19-204.35 TND)'
    },
    {
      carrier: 'Orange Tunisia',
      provider: 'ding',
      provider_country_code: 'TN',
      provider_carrier_code: 'ORTN',
      provider_carrier_label: 'Orange Tunisia',
      provider_country_label: 'Tunisia',
      is_enabled: false,
      is_primary: false,
      priority: 40,
      notes: 'DingConnect Disabled: 0 active products in UAT catalog'
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

  console.log('\n=== TUNISIA PROVISIONING COMPLETE ===');
}

main().catch(console.error);
