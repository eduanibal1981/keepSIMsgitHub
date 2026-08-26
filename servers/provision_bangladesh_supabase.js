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
  console.log('=== PROVISIONING BANGLADESH (BD) IN SUPABASE ===');
  console.log('====================================================');

  // 1. Enable Country: Bangladesh
  console.log('\n1. Updating Bangladesh country record to is_supported: true...');
  const countryUpdate = await api('countries?iso_code=eq.BD', 'PATCH', {
    is_supported: true
  });
  console.log('Country updated:', countryUpdate);
  const bdCountryId = countryUpdate[0]?.id;
  if (!bdCountryId) {
    throw new Error('Could not find country record for BD');
  }

  // 2. Fetch existing carriers
  const existingCarriers = await api(`carriers?country_id=eq.${bdCountryId}`);
  console.log(`Found ${existingCarriers.length} existing carriers for Bangladesh:`, existingCarriers.map(c => c.name));

  const carrierMapByName = {};
  existingCarriers.forEach(c => {
    carrierMapByName[c.name.toLowerCase().trim()] = c;
  });

  const targetCarriers = [
    { name: 'Grameenphone', canonical: 'Grameenphone', default_refill_amount: 0.50 },
    { name: 'Robi Axiata', canonical: 'Robi Axiata', default_refill_amount: 0.50 },
    { name: 'Banglalink', canonical: 'Banglalink', default_refill_amount: 0.50 },
    { name: 'Teletalk Bangladesh', canonical: 'Teletalk Bangladesh', default_refill_amount: 0.50 },
    { name: 'Airtel Bangladesh', canonical: 'Airtel Bangladesh', default_refill_amount: 0.50 }
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
        country_id: bdCountryId,
        default_refill_amount: tc.default_refill_amount,
        fulfillment_gateway: 'API'
      });
      carrierIdMap[tc.canonical] = updated[0].id;
    } else {
      console.log(`Inserting new carrier ${tc.canonical}...`);
      const inserted = await api('carriers', 'POST', {
        country_id: bdCountryId,
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

  // 3. Upsert Carrier Rules (BTRC Bangladesh Regulatory & Inactivity Framework)
  console.log('\n3. Upserting carrier rules for Bangladesh...');
  for (const [carrierName, carrierId] of Object.entries(carrierIdMap)) {
    const existingRules = await api(`carrier_rules?carrier_id=eq.${carrierId}`);
    
    let offerId = 'GRAMEENPHONE_BD_001';
    if (carrierName.includes('Robi')) offerId = 'ROBI_BD_001';
    if (carrierName.includes('Banglalink')) offerId = 'BANGLALINK_BD_001';
    if (carrierName.includes('Teletalk')) offerId = 'TELETALK_BD_001';
    if (carrierName.includes('Airtel')) offerId = 'AIRTEL_BD_001';

    const ruleData = {
      carrier_id: carrierId,
      rule_type: 'prepaid',
      inactivity_limit_days: 365,
      grace_period_days: 90,
      minimum_topup_amount: 0.20,
      recommended_topup_amount: 0.50,
      topup_validity_days: 60,
      activity_requirement: 'recharge_ok',
      inapp_pricing: 0.99,
      inapp_pricing_currency: 'usd',
      offer_id: offerId,
      notes: 'BTRC 365-day inactivity rule + 90-day grace/notice period before recycling (total 450 days). 15% VAT + 20% SD + 1% Surcharge tax framework.',
      rule_source_url: 'http://www.btrc.gov.bd/',
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
  console.log('\n4. Resetting primary flags and upserting carrier_provider_map entries...');

  for (const carrierId of Object.values(carrierIdMap)) {
    await api(`carrier_provider_map?carrier_id=eq.${carrierId}`, 'PATCH', {
      is_primary: false
    });
  }

  const mappings = [
    // Grameenphone
    {
      carrier: 'Grameenphone',
      provider: 'dtone',
      provider_country_code: 'BGD',
      provider_carrier_code: '249',
      provider_carrier_label: 'GrameenPhone Bangladesh',
      provider_country_label: 'Bangladesh',
      is_enabled: true,
      is_primary: true,
      priority: 10,
      notes: 'DT One Primary Rail (Operator 249 / Open Range 11747, 20-1000 BDT, 0.078-3.863 OMR)'
    },
    {
      carrier: 'Grameenphone',
      provider: 'reloadly',
      provider_country_code: 'BD',
      provider_carrier_code: '26',
      provider_carrier_label: 'Grameenphone Bangladesh',
      provider_country_label: 'Bangladesh',
      is_enabled: true,
      is_primary: false,
      priority: 20,
      notes: 'Reloadly Secondary Rail (Operator 26, Range 20-5000 BDT, $0.18-$44.98 USD)'
    },
    {
      carrier: 'Grameenphone',
      provider: 'zendit',
      provider_country_code: 'BD',
      provider_carrier_code: 'GrameenPhone',
      provider_carrier_label: 'GrameenPhone',
      provider_country_label: 'Bangladesh',
      is_enabled: true,
      is_primary: false,
      priority: 30,
      notes: 'Zendit Tertiary Rail (GRAMEENPHONE_BD_OPEN / Fixed 001-018)'
    },
    {
      carrier: 'Grameenphone',
      provider: 'ding',
      provider_country_code: 'BD',
      provider_carrier_code: 'GEBD',
      provider_carrier_label: 'Grameenphone Bangladesh',
      provider_country_label: 'Bangladesh',
      is_enabled: false,
      is_primary: false,
      priority: 40,
      notes: 'DingConnect Quaternary Rail (Disabled: 0 UAT Offers)'
    },

    // Robi Axiata
    {
      carrier: 'Robi Axiata',
      provider: 'dtone',
      provider_country_code: 'BGD',
      provider_carrier_code: '1446',
      provider_carrier_label: 'Robi Bangladesh',
      provider_country_label: 'Bangladesh',
      is_enabled: true,
      is_primary: true,
      priority: 10,
      notes: 'DT One Primary Rail (Operator 1446 / Open Range 11748, 20-1000 BDT, 0.078-3.887 OMR)'
    },
    {
      carrier: 'Robi Axiata',
      provider: 'reloadly',
      provider_country_code: 'BD',
      provider_carrier_code: '25',
      provider_carrier_label: 'Robi Bangladesh',
      provider_country_label: 'Bangladesh',
      is_enabled: true,
      is_primary: false,
      priority: 20,
      notes: 'Reloadly Secondary Rail (Operator 25, Range 20-5000 BDT, $0.18-$44.98 USD)'
    },
    {
      carrier: 'Robi Axiata',
      provider: 'zendit',
      provider_country_code: 'BD',
      provider_carrier_code: 'Robi',
      provider_carrier_label: 'Robi',
      provider_country_label: 'Bangladesh',
      is_enabled: true,
      is_primary: false,
      priority: 30,
      notes: 'Zendit Tertiary Rail (ROBI_BD_OPEN / Fixed 001-018)'
    },
    {
      carrier: 'Robi Axiata',
      provider: 'ding',
      provider_country_code: 'BD',
      provider_carrier_code: 'RLBD',
      provider_carrier_label: 'Robi Bangladesh',
      provider_country_label: 'Bangladesh',
      is_enabled: false,
      is_primary: false,
      priority: 40,
      notes: 'DingConnect Quaternary Rail (Disabled: 0 UAT Offers)'
    },

    // Banglalink
    {
      carrier: 'Banglalink',
      provider: 'dtone',
      provider_country_code: 'BGD',
      provider_carrier_code: '1447',
      provider_carrier_label: 'Banglalink Bangladesh',
      provider_country_label: 'Bangladesh',
      is_enabled: true,
      is_primary: true,
      priority: 10,
      notes: 'DT One Primary Rail (Operator 1447 / Open Range 11745, 20-1000 BDT, 0.078-3.881 OMR)'
    },
    {
      carrier: 'Banglalink',
      provider: 'zendit',
      provider_country_code: 'BD',
      provider_carrier_code: 'Banglalink',
      provider_carrier_label: 'Banglalink',
      provider_country_label: 'Bangladesh',
      is_enabled: true,
      is_primary: false,
      priority: 20,
      notes: 'Zendit Secondary Rail (BANGLALINK_BD_OPEN / Fixed 001-018)'
    },
    {
      carrier: 'Banglalink',
      provider: 'reloadly',
      provider_country_code: 'BD',
      provider_carrier_code: '24',
      provider_carrier_label: 'Banglalink Bangladesh',
      provider_country_label: 'Bangladesh',
      is_enabled: true,
      is_primary: false,
      priority: 30,
      notes: 'Reloadly Tertiary Rail (Operator 24 / 28, Range 20-5000 BDT)'
    },
    {
      carrier: 'Banglalink',
      provider: 'ding',
      provider_country_code: 'BD',
      provider_carrier_code: 'BGBD',
      provider_carrier_label: 'Banglalink Bangladesh',
      provider_country_label: 'Bangladesh',
      is_enabled: false,
      is_primary: false,
      priority: 40,
      notes: 'DingConnect Quaternary Rail (Disabled: 0 UAT Offers)'
    },

    // Teletalk Bangladesh
    {
      carrier: 'Teletalk Bangladesh',
      provider: 'dtone',
      provider_country_code: 'BGD',
      provider_carrier_code: '1448',
      provider_carrier_label: 'Teletalk Bangladesh',
      provider_country_label: 'Bangladesh',
      is_enabled: true,
      is_primary: true,
      priority: 10,
      notes: 'DT One Primary Rail (Operator 1448 / Open Range 11749, 10-1000 BDT, 0.039-3.870 OMR, lowest entry cost)'
    },
    {
      carrier: 'Teletalk Bangladesh',
      provider: 'reloadly',
      provider_country_code: 'BD',
      provider_carrier_code: '27',
      provider_carrier_label: 'Teletalk Bangladesh',
      provider_country_label: 'Bangladesh',
      is_enabled: true,
      is_primary: false,
      priority: 20,
      notes: 'Reloadly Secondary Rail (Operator 27, 2% discount, Range 20-5000 BDT, $0.18-$44.98 USD)'
    },
    {
      carrier: 'Teletalk Bangladesh',
      provider: 'zendit',
      provider_country_code: 'BD',
      provider_carrier_code: 'Teletalk',
      provider_carrier_label: 'TeleTalk',
      provider_country_label: 'Bangladesh',
      is_enabled: true,
      is_primary: false,
      priority: 30,
      notes: 'Zendit Tertiary Rail (TELETALK_BD_OPEN / Fixed 001-018)'
    },
    {
      carrier: 'Teletalk Bangladesh',
      provider: 'ding',
      provider_country_code: 'BD',
      provider_carrier_code: 'TQBD',
      provider_carrier_label: 'Teletalk Bangladesh',
      provider_country_label: 'Bangladesh',
      is_enabled: false,
      is_primary: false,
      priority: 40,
      notes: 'DingConnect Quaternary Rail (Disabled: 0 UAT Offers)'
    },

    // Airtel Bangladesh
    {
      carrier: 'Airtel Bangladesh',
      provider: 'dtone',
      provider_country_code: 'BGD',
      provider_carrier_code: '1449',
      provider_carrier_label: 'Airtel Bangladesh',
      provider_country_label: 'Bangladesh',
      is_enabled: true,
      is_primary: true,
      priority: 10,
      notes: 'DT One Primary Rail (Operator 1449 / Open Range 11744, 20-1000 BDT, 0.078-3.887 OMR)'
    },
    {
      carrier: 'Airtel Bangladesh',
      provider: 'reloadly',
      provider_country_code: 'BD',
      provider_carrier_code: '28',
      provider_carrier_label: 'Airtel Bangladesh',
      provider_country_label: 'Bangladesh',
      is_enabled: true,
      is_primary: false,
      priority: 20,
      notes: 'Reloadly Secondary Rail (Operator 28, Range 20-5000 BDT, $0.18-$44.98 USD)'
    },
    {
      carrier: 'Airtel Bangladesh',
      provider: 'zendit',
      provider_country_code: 'BD',
      provider_carrier_code: 'Airtel',
      provider_carrier_label: 'Airtel',
      provider_country_label: 'Bangladesh',
      is_enabled: true,
      is_primary: false,
      priority: 30,
      notes: 'Zendit Tertiary Rail (AIRTEL_BD_OPEN / Fixed 001-018)'
    },
    {
      carrier: 'Airtel Bangladesh',
      provider: 'ding',
      provider_country_code: 'BD',
      provider_carrier_code: 'AXBD',
      provider_carrier_label: 'Airtel Bangladesh / Cirkle',
      provider_country_label: 'Bangladesh',
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
  console.log('=== BANGLADESH SUPABASE PROVISIONING COMPLETE ===');
  console.log('====================================================');
}

main().catch(console.error);
