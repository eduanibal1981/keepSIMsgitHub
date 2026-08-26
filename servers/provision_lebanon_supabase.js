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
  console.log('=== PROVISIONING LEBANON (LB / LBN) IN SUPABASE ===');
  console.log('====================================================');

  // 1. Enable Country: Lebanon
  console.log('\n1. Updating Lebanon country record to is_supported: true...');
  const countryUpdate = await api('countries?iso_code=eq.LB', 'PATCH', {
    is_supported: true,
    avg_sim_replacement_cost: 15.00
  });
  console.log('Country updated:', countryUpdate);
  const lbCountryId = countryUpdate[0]?.id || 'd6108f9d-7510-407a-8eaf-0b45c5dd1856';

  // 2. Fetch existing carriers
  const existingCarriers = await api(`carriers?country_id=eq.${lbCountryId}`);
  console.log(`Found ${existingCarriers.length} existing carriers for Lebanon:`, existingCarriers.map(c => c.name));

  const carrierMapByName = {};
  existingCarriers.forEach(c => {
    carrierMapByName[c.name.toLowerCase().trim()] = c;
  });

  const targetCarriers = [
    { name: 'Touch Lebanon', canonical: 'Touch Lebanon', default_refill_amount: 4.50 },
    { name: 'Alfa Lebanon', canonical: 'Alfa Lebanon', default_refill_amount: 1.22 }
  ];

  const carrierIdMap = {};

  for (const tc of targetCarriers) {
    let matched = null;
    for (const [key, val] of Object.entries(carrierMapByName)) {
      if (key.includes(tc.canonical.toLowerCase()) || tc.canonical.toLowerCase().includes(key) || (tc.canonical.includes('Touch') && key.includes('touch')) || (tc.canonical.includes('Alfa') && key.includes('alfa'))) {
        matched = val;
        break;
      }
    }

    if (matched) {
      console.log(`Updating existing carrier ${tc.canonical} (ID: ${matched.id}, was: "${matched.name}")...`);
      const updated = await api(`carriers?id=eq.${matched.id}`, 'PATCH', {
        name: tc.canonical,
        is_supported: true,
        country_id: lbCountryId,
        default_refill_amount: tc.default_refill_amount,
        fulfillment_gateway: 'API'
      });
      carrierIdMap[tc.canonical] = updated[0].id;
    } else {
      console.log(`Inserting new carrier ${tc.canonical}...`);
      const inserted = await api('carriers', 'POST', {
        country_id: lbCountryId,
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

  // 3. Upsert Carrier Rules (MoT Lebanon Regulatory & Inactivity Framework)
  console.log('\n3. Upserting carrier rules for Lebanon...');
  for (const [carrierName, carrierId] of Object.entries(carrierIdMap)) {
    const existingRules = await api(`carrier_rules?carrier_id=eq.${carrierId}`);

    let ruleData;
    if (carrierName === 'Touch Lebanon') {
      ruleData = {
        carrier_id: carrierId,
        rule_type: 'prepaid',
        inactivity_limit_days: 35,
        grace_period_days: 60,
        minimum_topup_amount: 3.79,
        recommended_topup_amount: 4.50,
        topup_validity_days: 35,
        activity_requirement: 'min_denomination',
        validity_qualifying_topup_amount: 4.50,
        inapp_pricing: 8.99,
        inapp_pricing_currency: 'usd',
        offer_id: 'TOUCH_LB_REFILL',
        notes: 'Touch Lebanon (MIC2/Zain): Official MoT Sayrafa USD pricing. Recharges grant 15 to 370 days of validity by denomination ($3.79 for 15D, $4.50 for 35D, $7.58 for 35D, $15.15 for 65D, $22.73 for 95D, $77.28 for 370D). Lapsed lines enter 12-day retention then 60-day grace before permanent disconnection and recycling.',
        rule_source_url: 'https://www.touch.com.lb/web/en/prepaid/magic',
        last_verified_at: new Date().toISOString()
      };
    } else {
      ruleData = {
        carrier_id: carrierId,
        rule_type: 'prepaid',
        inactivity_limit_days: 35,
        grace_period_days: 60,
        minimum_topup_amount: 1.22,
        recommended_topup_amount: 4.50,
        topup_validity_days: 35,
        activity_requirement: 'min_denomination',
        validity_qualifying_topup_amount: 4.50,
        inapp_pricing: 7.99,
        inapp_pricing_currency: 'usd',
        offer_id: 'ALFA_LB_REFILL',
        notes: 'Alfa Lebanon (MIC1/Orascom): Official MoT Sayrafa USD pricing. Recharges grant 13 to 365 days of validity by denomination ($1.22 micro-refill, $3.03 for 13D, $4.50 for 35D, $7.58 for 35D, $15.15 for 65D, $22.73 for 95D, $77.28 for 365D). Lapsed lines enter 12-day retention then 60-day grace before recycling.',
        rule_source_url: 'https://www.alfa.com.lb/en/prepaid/lifecycle',
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
    // Touch Lebanon
    {
      carrier: 'Touch Lebanon',
      provider: 'dtone',
      provider_country_code: 'LBN',
      provider_carrier_code: '2794',
      provider_carrier_label: 'Touch Lebanon USD',
      provider_country_label: 'Lebanon',
      is_enabled: true,
      is_primary: true,
      priority: 10,
      notes: 'DT One Primary Direct Rail (Operator 2794, 6 direct top-up products from $3.79 USD @ 2.116 OMR)'
    },
    {
      carrier: 'Touch Lebanon',
      provider: 'zendit',
      provider_country_code: 'LB',
      provider_carrier_code: 'Touch',
      provider_carrier_label: 'Touch',
      provider_country_label: 'Lebanon',
      is_enabled: true,
      is_primary: false,
      priority: 20,
      notes: 'Zendit Secondary Direct Rail (Brand Touch, 6 direct offers TOUCH_LB_001_USD to 006_USD from $3.79 USD send)'
    },
    {
      carrier: 'Touch Lebanon',
      provider: 'reloadly',
      provider_country_code: 'LB',
      provider_carrier_code: '276',
      provider_carrier_label: 'Touch Lebanon PIN',
      provider_country_label: 'Lebanon',
      is_enabled: true,
      is_primary: false,
      priority: 30,
      notes: 'Reloadly Tertiary PIN Rail (Operator 276, $25.40 USD fixed PIN voucher)'
    },
    {
      carrier: 'Touch Lebanon',
      provider: 'ding',
      provider_country_code: 'LB',
      provider_carrier_code: 'TMLB',
      provider_carrier_label: 'Touch Mobile Lebanon',
      provider_country_label: 'Lebanon',
      is_enabled: false,
      is_primary: false,
      priority: 40,
      notes: 'DingConnect Quaternary Rail (Disabled: 0 UAT offers)'
    },

    // Alfa Lebanon
    {
      carrier: 'Alfa Lebanon',
      provider: 'dtone',
      provider_country_code: 'LBN',
      provider_carrier_code: '2793',
      provider_carrier_label: 'Alfa Lebanon USD',
      provider_country_label: 'Lebanon',
      is_enabled: true,
      is_primary: true,
      priority: 10,
      notes: 'DT One Primary Direct Rail (Operator 2793, 7 direct products from $1.22 USD @ 0.751 OMR micro-refill)'
    },
    {
      carrier: 'Alfa Lebanon',
      provider: 'zendit',
      provider_country_code: 'LB',
      provider_carrier_code: 'Alfa',
      provider_carrier_label: 'Alfa',
      provider_country_label: 'Lebanon',
      is_enabled: true,
      is_primary: false,
      priority: 20,
      notes: 'Zendit Secondary Direct Rail (Brand Alfa, 7 direct offers ALFA_LB_001 to 008 from $1.22 USD send)'
    },
    {
      carrier: 'Alfa Lebanon',
      provider: 'reloadly',
      provider_country_code: 'LB',
      provider_carrier_code: '1017',
      provider_carrier_label: 'Alfa Lebanon PIN',
      provider_country_label: 'Lebanon',
      is_enabled: true,
      is_primary: false,
      priority: 30,
      notes: 'Reloadly Tertiary PIN Rail (Operator 1017, $25.40 USD fixed PIN voucher)'
    },
    {
      carrier: 'Alfa Lebanon',
      provider: 'ding',
      provider_country_code: 'LB',
      provider_carrier_code: 'AALB',
      provider_carrier_label: 'Alfa Lebanon',
      provider_country_label: 'Lebanon',
      is_enabled: false,
      is_primary: false,
      priority: 40,
      notes: 'DingConnect Quaternary Rail (Disabled: 0 UAT offers)'
    }
  ];

  for (const m of mappings) {
    const carrierId = carrierIdMap[m.carrier];
    const existing = await api(`carrier_provider_map?carrier_id=eq.${carrierId}&provider=eq.${m.provider}`);

    const payload = {
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

    if (existing && existing.length > 0) {
      console.log(`Updating mapping for ${m.carrier} - ${m.provider}...`);
      await api(`carrier_provider_map?id=eq.${existing[0].id}`, 'PATCH', payload);
    } else {
      console.log(`Inserting mapping for ${m.carrier} - ${m.provider}...`);
      await api('carrier_provider_map', 'POST', payload);
    }
  }

  console.log('\n====================================================');
  console.log('✅ Lebanon Supabase Provisioning Completed Successfully!');
  console.log('====================================================');
}

main().catch(err => {
  console.error('Provisioning failed:', err);
  process.exit(1);
});
