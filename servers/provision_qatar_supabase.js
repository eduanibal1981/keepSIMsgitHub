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
  console.log('=== PROVISIONING QATAR (QA) IN SUPABASE ===');
  console.log('====================================================');

  // 1. Enable Country: Qatar
  console.log('\n1. Updating Qatar country record to is_supported: true...');
  const countryUpdate = await api('countries?iso_code=eq.QA', 'PATCH', {
    is_supported: true
  });
  console.log('Country updated:', countryUpdate);
  const qaCountryId = countryUpdate[0]?.id;
  if (!qaCountryId) {
    throw new Error('Could not find country record for QA');
  }

  // 2. Fetch existing carriers
  const existingCarriers = await api(`carriers?country_id=eq.${qaCountryId}`);
  console.log(`Found ${existingCarriers.length} existing carriers for Qatar:`, existingCarriers.map(c => c.name));

  const carrierMapByName = {};
  existingCarriers.forEach(c => {
    carrierMapByName[c.name.toLowerCase().trim()] = c;
  });

  const targetCarriers = [
    { name: 'Ooredoo Qatar', canonical: 'Ooredoo Qatar', default_refill_amount: 5.00 },
    { name: 'Vodafone Qatar', canonical: 'Vodafone Qatar', default_refill_amount: 5.00 }
  ];

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
      console.log(`Updating existing carrier ${tc.canonical} (ID: ${matched.id}, was: "${matched.name}")...`);
      const updated = await api(`carriers?id=eq.${matched.id}`, 'PATCH', {
        name: tc.canonical,
        is_supported: true,
        country_id: qaCountryId,
        default_refill_amount: tc.default_refill_amount,
        fulfillment_gateway: 'API'
      });
      carrierIdMap[tc.canonical] = updated[0].id;
    } else {
      console.log(`Inserting new carrier ${tc.canonical}...`);
      const inserted = await api('carriers', 'POST', {
        country_id: qaCountryId,
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

  // 3. Upsert Carrier Rules (CRA Qatar Regulatory & Inactivity Framework)
  console.log('\n3. Upserting carrier rules for Qatar...');
  for (const [carrierName, carrierId] of Object.entries(carrierIdMap)) {
    const existingRules = await api(`carrier_rules?carrier_id=eq.${carrierId}`);

    let ruleData;
    if (carrierName === 'Ooredoo Qatar') {
      ruleData = {
        carrier_id: carrierId,
        rule_type: 'prepaid',
        inactivity_limit_days: 120,
        grace_period_days: 60,
        minimum_topup_amount: 5.00,
        recommended_topup_amount: 10.00,
        topup_validity_days: 30,
        activity_requirement: 'recharge_ok',
        inapp_pricing: 14.99,
        inapp_pricing_currency: 'usd',
        offer_id: 'OOREDOO_QA_REFILL',
        notes: 'Ooredoo Hala: credit validity runs 30-90 days by denomination, then the line is receive-only in grace. Topping up within 120 days of expiry restores it and returns unused credit; past 120 days it is deactivated and permanently recycled.',
        rule_source_url: 'https://www.ooredoo.qa/web/en/prepaid-plans/',
        last_verified_at: new Date().toISOString()
      };
    } else {
      ruleData = {
        carrier_id: carrierId,
        rule_type: 'prepaid',
        inactivity_limit_days: 180,
        grace_period_days: 180,
        minimum_topup_amount: 2.75,
        recommended_topup_amount: 5.00,
        topup_validity_days: 30,
        activity_requirement: 'recharge_ok',
        inapp_pricing: 9.99,
        inapp_pricing_currency: 'usd',
        offer_id: 'VODAFONE_QA_REFILL',
        notes: 'Vodafone Qatar: credit from a QR 10-80 recharge lasts 30 days, but line validity runs 180 days from the recharge date. Inactivity past 180 days expires the SIM, with 180 days grace before recycling.',
        rule_source_url: 'https://www.vodafone.qa/en/about-us/legal-and-regulatory/terms-and-conditions',
        last_verified_at: new Date().toISOString()
      };
    }

    if (existingRules && existingRules.length > 0) {
      console.log(`Updating rule for ${carrierName} (ID: ${existingRules[0].id})...`);
      await api(`carrier_rules?id=eq.${existingRules[0].id}`, 'PATCH', ruleData);
    } else {
      console.log(`Inserting rule for ${carrierName}...`);
      await api('carrier_rules', 'POST', ruleData);
    }
  }

  // 4. Upsert Carrier Provider Maps
  console.log('\n4. Resetting primary flags and upserting carrier_provider_map entries...');

  for (const carrierId of Object.values(carrierIdMap)) {
    await api(`carrier_provider_map?carrier_id=eq.${carrierId}`, 'PATCH', {
      is_primary: false
    });
  }

  const mappings = [
    // Ooredoo Qatar
    {
      carrier: 'Ooredoo Qatar',
      provider: 'reloadly',
      provider_country_code: 'QA',
      provider_carrier_code: '396',
      provider_carrier_label: 'Ooredoo Qatar',
      provider_country_label: 'Qatar',
      is_enabled: true,
      is_primary: true,
      priority: 10,
      notes: 'Reloadly Primary Direct Rail (Operator 396, Direct Top-Up 100-200 QAR @ $40.16-$80.32 USD, 1% discount)'
    },
    {
      carrier: 'Ooredoo Qatar',
      provider: 'dtone',
      provider_country_code: 'QAT',
      provider_carrier_code: '511',
      provider_carrier_label: 'Ooredoo Qatar',
      provider_country_label: 'Qatar',
      is_enabled: true,
      is_primary: false,
      priority: 20,
      notes: 'DT One Secondary PIN Rail (Operator 511, Data PIN Vouchers 80 QAR 12GB @ 10.258 OMR / 150 QAR 25GB @ 19.233 OMR)'
    },
    {
      carrier: 'Ooredoo Qatar',
      provider: 'zendit',
      provider_country_code: 'QA',
      provider_carrier_code: 'Ooredoo',
      provider_carrier_label: 'Ooredoo',
      provider_country_label: 'Qatar',
      is_enabled: false,
      is_primary: false,
      priority: 30,
      notes: 'Zendit Tertiary Rail (Disabled: 0 active offers in catalog)'
    },
    {
      carrier: 'Ooredoo Qatar',
      provider: 'ding',
      provider_country_code: 'QA',
      provider_carrier_code: 'OOQA',
      provider_carrier_label: 'Ooredoo Qatar',
      provider_country_label: 'Qatar',
      is_enabled: false,
      is_primary: false,
      priority: 40,
      notes: 'DingConnect Quaternary Rail (Disabled: 0 active UAT inventory)'
    },

    // Vodafone Qatar
    {
      carrier: 'Vodafone Qatar',
      provider: 'dtone',
      provider_country_code: 'QAT',
      provider_carrier_code: '2722',
      provider_carrier_label: 'Vodafone PIN Qatar',
      provider_country_label: 'Qatar',
      is_enabled: true,
      is_primary: true,
      priority: 10,
      notes: 'DT One Primary PIN Rail (Operator 2722, Digital PIN Vouchers from 10 QAR @ 1.288 OMR / ~$3.35 USD)'
    },
    {
      carrier: 'Vodafone Qatar',
      provider: 'reloadly',
      provider_country_code: 'QA',
      provider_carrier_code: '395',
      provider_carrier_label: 'Vodafone PIN Qatar',
      provider_country_label: 'Qatar',
      is_enabled: true,
      is_primary: false,
      priority: 20,
      notes: 'Reloadly Secondary PIN Rail (Operator 395, Digital PIN Vouchers from $3.60 USD / 1% discount)'
    },
    {
      carrier: 'Vodafone Qatar',
      provider: 'zendit',
      provider_country_code: 'QA',
      provider_carrier_code: 'Vodafone',
      provider_carrier_label: 'Vodafone',
      provider_country_label: 'Qatar',
      is_enabled: false,
      is_primary: false,
      priority: 30,
      notes: 'Zendit Tertiary Rail (Disabled: 0 active offers in catalog)'
    },
    {
      carrier: 'Vodafone Qatar',
      provider: 'ding',
      provider_country_code: 'QA',
      provider_carrier_code: 'VFQA',
      provider_carrier_label: 'Vodafone Qatar',
      provider_country_label: 'Qatar',
      is_enabled: false,
      is_primary: false,
      priority: 40,
      notes: 'DingConnect Quaternary Rail (Disabled: 0 active UAT inventory)'
    }
  ];

  for (const m of mappings) {
    const carrierId = carrierIdMap[m.carrier];
    if (!carrierId) {
      console.warn(`Carrier ID not found for ${m.carrier}`);
      continue;
    }

    const existingMap = await api(`carrier_provider_map?carrier_id=eq.${carrierId}&provider=eq.${m.provider}`);
    const mapPayload = {
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
    };

    if (existingMap && existingMap.length > 0) {
      console.log(`Updating mapping for ${m.carrier} -> ${m.provider} (${existingMap[0].id})...`);
      await api(`carrier_provider_map?id=eq.${existingMap[0].id}`, 'PATCH', mapPayload);
    } else {
      console.log(`Inserting mapping for ${m.carrier} -> ${m.provider}...`);
      await api('carrier_provider_map', 'POST', mapPayload);
    }
  }

  console.log('\n====================================================');
  console.log('=== VERIFYING FINAL PROVISIONED STATE ===');
  console.log('====================================================');

  for (const [carrierName, carrierId] of Object.entries(carrierIdMap)) {
    const car = await api(`carriers?id=eq.${carrierId}`);
    const rules = await api(`carrier_rules?carrier_id=eq.${carrierId}`);
    const maps = await api(`carrier_provider_map?carrier_id=eq.${carrierId}`);
    console.log(`\nCarrier: ${carrierName} (ID: ${carrierId})`);
    console.log('  Carrier Status:', car[0]?.is_supported ? '🟢 SUPPORTED' : '🔴 UNSUPPORTED');
    console.log('  Rule Status:', rules.length > 0 ? `🟢 Set (Inactivity: ${rules[0].inactivity_limit_days}d, Grace: ${rules[0].grace_period_days}d)` : '🔴 None');
    console.log(`  Provider Mappings (${maps.length}):`);
    maps.forEach(mp => {
      console.log(`    - [${mp.priority}] ${mp.provider.toUpperCase()} (${mp.provider_carrier_code}) | Primary: ${mp.is_primary} | Enabled: ${mp.is_enabled} | Notes: ${mp.notes}`);
    });
  }

  console.log('\nQatar provisioning complete!');
}

main().catch(console.error);
