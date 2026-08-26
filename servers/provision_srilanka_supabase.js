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
  console.log('=== PROVISIONING SRI LANKA (LK) IN SUPABASE ===');
  console.log('====================================================');

  // 1. Enable Country: Sri Lanka
  console.log('\n1. Updating Sri Lanka country record to is_supported: true...');
  const countryUpdate = await api('countries?iso_code=eq.LK', 'PATCH', {
    is_supported: true
  });
  console.log('Country updated:', countryUpdate);
  const lkCountryId = countryUpdate[0]?.id;
  if (!lkCountryId) {
    throw new Error('Could not find country record for LK');
  }

  // 2. Fetch & update existing carriers
  const existingCarriers = await api(`carriers?country_id=eq.${lkCountryId}`);
  console.log(`Found ${existingCarriers.length} existing carriers for Sri Lanka:`, existingCarriers.map(c => c.name));

  const carrierMapByName = {};
  existingCarriers.forEach(c => {
    carrierMapByName[c.name.toLowerCase().trim()] = c;
  });

  const targetCarriers = [
    { canonical: 'Dialog Axiata', aliases: ['dialog', 'dialog axiata', 'dialog sri lanka'], default_refill_amount: 0.50 },
    { canonical: 'Mobitel Sri Lanka', aliases: ['mobitel', 'mobitel sri lanka', 'slt-mobitel'], default_refill_amount: 0.50 },
    { canonical: 'Hutchison Sri Lanka', aliases: ['hutch', 'hutch sl', 'hutchison', 'hutchison sri lanka'], default_refill_amount: 0.50 },
    { canonical: 'Airtel Sri Lanka', aliases: ['airtel', 'airtel sri lanka'], default_refill_amount: 0.50 }
  ];

  const carrierIdMap = {};

  for (const tc of targetCarriers) {
    let matched = null;
    for (const [key, val] of Object.entries(carrierMapByName)) {
      if (tc.aliases.some(alias => key.includes(alias) || alias.includes(key))) {
        matched = val;
        break;
      }
    }

    if (matched) {
      console.log(`Updating existing carrier ${tc.canonical} (ID: ${matched.id}, was: "${matched.name}")...`);
      const updated = await api(`carriers?id=eq.${matched.id}`, 'PATCH', {
        name: tc.canonical,
        is_supported: true,
        country_id: lkCountryId,
        default_refill_amount: tc.default_refill_amount,
        fulfillment_gateway: 'API'
      });
      carrierIdMap[tc.canonical] = updated[0].id;
    } else {
      console.log(`Inserting new carrier ${tc.canonical}...`);
      const inserted = await api('carriers', 'POST', {
        country_id: lkCountryId,
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

  // 3. Upsert Carrier Rules (TRCSL Regulatory & Inactivity Framework)
  console.log('\n3. Upserting carrier rules for Sri Lanka...');
  for (const [carrierName, carrierId] of Object.entries(carrierIdMap)) {
    const existingRules = await api(`carrier_rules?carrier_id=eq.${carrierId}`);
    
    let offerId = 'DIALOG_LK_001';
    let minTopup = 0.20;
    if (carrierName.includes('Mobitel')) {
      offerId = 'MOBITEL_LK_5-I';
      minTopup = 0.15;
    } else if (carrierName.includes('Hutchison')) {
      offerId = 'HUTCH_LK_5-I';
      minTopup = 0.20;
    } else if (carrierName.includes('Airtel')) {
      offerId = 'DIALOG_LK_001';
      minTopup = 0.20;
    }

    const ruleData = {
      carrier_id: carrierId,
      rule_type: 'prepaid',
      inactivity_limit_days: 180,
      grace_period_days: 90,
      minimum_topup_amount: minTopup,
      recommended_topup_amount: 0.50,
      topup_validity_days: 60,
      activity_requirement: 'recharge_ok',
      inapp_pricing: 0.99,
      inapp_pricing_currency: 'usd',
      offer_id: offerId,
      notes: 'TRCSL 180-day inactivity rule + 90-day grace period before recycling. Subject to 18% VAT + 2.5% SSCL + Telecommunications Levy statutory taxes.',
      rule_source_url: 'http://www.trc.gov.lk/',
      last_verified_at: new Date().toISOString()
    };

    if (existingRules && existingRules.length > 0) {
      console.log(`Updating rule for ${carrierName} (ID: ${existingRules[0].id})...`);
      await api(`carrier_rules?id=eq.${existingRules[0].id}`, 'PATCH', ruleData);
    } else {
      console.log(`Inserting rule for ${carrierName}...`);
      await api('carrier_rules', 'POST', ruleData);
    }
  }

  // 4. Upsert Carrier Provider Maps
  console.log('\n4. Upserting carrier_provider_map entries...');

  for (const carrierId of Object.values(carrierIdMap)) {
    // Delete or reset existing mappings
    const existingMaps = await api(`carrier_provider_map?carrier_id=eq.${carrierId}`);
    for (const m of existingMaps) {
      await api(`carrier_provider_map?id=eq.${m.id}`, 'DELETE');
    }
  }

  const mappings = [
    // Dialog Axiata
    {
      carrier: 'Dialog Axiata',
      provider: 'dtone',
      provider_country_code: 'LKA',
      provider_carrier_code: '360',
      provider_carrier_label: 'Dialog Sri Lanka',
      provider_country_label: 'Sri Lanka',
      is_enabled: true,
      is_primary: true,
      priority: 10,
      notes: 'DT One Primary Rail (Operator 360 / Open Range 11294, 50-10000 LKR, wholesale from 0.066 OMR / ~$0.17 USD)'
    },
    {
      carrier: 'Dialog Axiata',
      provider: 'reloadly',
      provider_country_code: 'LK',
      provider_carrier_code: '472',
      provider_carrier_label: 'Dialog Sri Lanka',
      provider_country_label: 'Sri Lanka',
      is_enabled: true,
      is_primary: false,
      priority: 20,
      notes: 'Reloadly Secondary Rail (Operator 472 / Fixed $0.40-$12 USD + Data Bundles 1180)'
    },
    {
      carrier: 'Dialog Axiata',
      provider: 'zendit',
      provider_country_code: 'LK',
      provider_carrier_code: 'Dialog',
      provider_carrier_label: 'Dialog',
      provider_country_label: 'Sri Lanka',
      is_enabled: true,
      is_primary: false,
      priority: 30,
      notes: 'Zendit Tertiary Rail (DIALOG_LK_001 / Fixed 1551 LKR $6.50 USD)'
    },
    {
      carrier: 'Dialog Axiata',
      provider: 'ding',
      provider_country_code: 'LK',
      provider_carrier_code: 'DGLK',
      provider_carrier_label: 'Dialog Sri Lanka',
      provider_country_label: 'Sri Lanka',
      is_enabled: false,
      is_primary: false,
      priority: 40,
      notes: 'DingConnect Quaternary Rail (Disabled: 0 UAT Offers)'
    },

    // Mobitel Sri Lanka
    {
      carrier: 'Mobitel Sri Lanka',
      provider: 'dtone',
      provider_country_code: 'LKA',
      provider_carrier_code: '409',
      provider_carrier_label: 'Mobitel Sri Lanka',
      provider_country_label: 'Sri Lanka',
      is_enabled: true,
      is_primary: true,
      priority: 10,
      notes: 'DT One Primary Rail (Operator 409 / Open Range 11296, 20-10000 LKR, wholesale from 0.028 OMR / ~$0.072 USD)'
    },
    {
      carrier: 'Mobitel Sri Lanka',
      provider: 'reloadly',
      provider_country_code: 'LK',
      provider_carrier_code: '471',
      provider_carrier_label: 'Mobitel Sri Lanka',
      provider_country_label: 'Sri Lanka',
      is_enabled: true,
      is_primary: false,
      priority: 20,
      notes: 'Reloadly Secondary Rail (Operator 471, Range 100-3000 LKR / $0.37-$11.11 USD)'
    },
    {
      carrier: 'Mobitel Sri Lanka',
      provider: 'zendit',
      provider_country_code: 'LK',
      provider_carrier_code: 'Mobitel',
      provider_carrier_label: 'Mobitel',
      provider_country_label: 'Sri Lanka',
      is_enabled: true,
      is_primary: false,
      priority: 30,
      notes: 'Zendit Tertiary Rail (MOBITEL_LK_5-I / Fixed 772 LKR $5.60 USD)'
    },
    {
      carrier: 'Mobitel Sri Lanka',
      provider: 'ding',
      provider_country_code: 'LK',
      provider_carrier_code: 'MSLK',
      provider_carrier_label: 'Mobitel Sri Lanka',
      provider_country_label: 'Sri Lanka',
      is_enabled: false,
      is_primary: false,
      priority: 40,
      notes: 'DingConnect Quaternary Rail (Disabled: 0 UAT Offers)'
    },

    // Hutchison Sri Lanka
    {
      carrier: 'Hutchison Sri Lanka',
      provider: 'dtone',
      provider_country_code: 'LKA',
      provider_carrier_code: '1609',
      provider_carrier_label: 'Hutchison Sri Lanka',
      provider_country_label: 'Sri Lanka',
      is_enabled: true,
      is_primary: true,
      priority: 10,
      notes: 'DT One Primary Rail (Operator 1609 / Open Range 11295, 50-3000 LKR, wholesale from 0.068 OMR / ~$0.177 USD)'
    },
    {
      carrier: 'Hutchison Sri Lanka',
      provider: 'reloadly',
      provider_country_code: 'LK',
      provider_carrier_code: '475',
      provider_carrier_label: 'Hutchison Sri Lanka',
      provider_country_label: 'Sri Lanka',
      is_enabled: true,
      is_primary: false,
      priority: 20,
      notes: 'Reloadly Secondary Rail (Operator 475 / Range 100-3000 LKR $0.63-$18.94 USD + Data Bundles 1181)'
    },
    {
      carrier: 'Hutchison Sri Lanka',
      provider: 'zendit',
      provider_country_code: 'LK',
      provider_carrier_code: 'Hutch',
      provider_carrier_label: 'Hutch',
      provider_country_label: 'Sri Lanka',
      is_enabled: true,
      is_primary: false,
      priority: 30,
      notes: 'Zendit Tertiary Rail (HUTCH_LK_5-I / Fixed 792 LKR $5.50 USD)'
    },
    {
      carrier: 'Hutchison Sri Lanka',
      provider: 'ding',
      provider_country_code: 'LK',
      provider_carrier_code: 'HSLK',
      provider_carrier_label: 'Hutch (Etisalat) Sri Lanka',
      provider_country_label: 'Sri Lanka',
      is_enabled: false,
      is_primary: false,
      priority: 40,
      notes: 'DingConnect Quaternary Rail (Disabled: 0 UAT Offers)'
    },

    // Airtel Sri Lanka (Merged into Dialog Axiata rails)
    {
      carrier: 'Airtel Sri Lanka',
      provider: 'dtone',
      provider_country_code: 'LKA',
      provider_carrier_code: '360',
      provider_carrier_label: 'Dialog Sri Lanka (Airtel Rails)',
      provider_country_label: 'Sri Lanka',
      is_enabled: true,
      is_primary: true,
      priority: 10,
      notes: 'DT One Primary Rail (Merged Dialog Axiata Operator 360 / Open Range 11294, 50-10000 LKR)'
    },
    {
      carrier: 'Airtel Sri Lanka',
      provider: 'reloadly',
      provider_country_code: 'LK',
      provider_carrier_code: '472',
      provider_carrier_label: 'Dialog Sri Lanka (Airtel Rails)',
      provider_country_label: 'Sri Lanka',
      is_enabled: true,
      is_primary: false,
      priority: 20,
      notes: 'Reloadly Secondary Rail (Dialog Operator 472, Fixed $0.40-$12 USD)'
    },
    {
      carrier: 'Airtel Sri Lanka',
      provider: 'zendit',
      provider_country_code: 'LK',
      provider_carrier_code: 'Dialog',
      provider_carrier_label: 'Dialog (Airtel Rails)',
      provider_country_label: 'Sri Lanka',
      is_enabled: true,
      is_primary: false,
      priority: 30,
      notes: 'Zendit Tertiary Rail (DIALOG_LK_001, Fixed 1551 LKR $6.50 USD)'
    },
    {
      carrier: 'Airtel Sri Lanka',
      provider: 'ding',
      provider_country_code: 'LK',
      provider_carrier_code: 'DGLK',
      provider_carrier_label: 'Dialog Sri Lanka (Airtel Rails)',
      provider_country_label: 'Sri Lanka',
      is_enabled: false,
      is_primary: false,
      priority: 40,
      notes: 'DingConnect Quaternary Rail (Disabled: 0 UAT Offers)'
    }
  ];

  for (const m of mappings) {
    const carrierId = carrierIdMap[m.carrier];
    if (!carrierId) {
      console.warn(`Carrier ID not found for ${m.carrier}`);
      continue;
    }

    console.log(`Inserting mapping for ${m.carrier} -> ${m.provider} (${m.provider_carrier_code})...`);
    await api('carrier_provider_map', 'POST', {
      carrier_id: carrierId,
      provider: m.provider,
      provider_country_code: m.provider_country_code,
      provider_carrier_code: m.provider_carrier_code,
      provider_carrier_label: m.provider_carrier_label,
      provider_country_label: m.provider_country_label,
      is_enabled: m.is_enabled,
      is_primary: m.is_primary,
      priority: m.priority,
      notes: m.notes,
      last_verified_at: new Date().toISOString()
    });
  }

  console.log('\nAll Sri Lanka records provisioned successfully in Supabase!');
}

main().catch(console.error);
