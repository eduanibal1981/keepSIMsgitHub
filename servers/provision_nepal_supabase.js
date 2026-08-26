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
  console.log('=== PROVISIONING NEPAL (NP / NPL) IN SUPABASE ===');
  console.log('====================================================');

  // 1. Update Country
  console.log('\n1. Verifying Nepal country record...');
  const countryUpdate = await api('countries?iso_code=eq.NP', 'PATCH', {
    is_supported: true,
    avg_sim_replacement_cost: 5
  });
  const npCountryId = countryUpdate[0]?.id;
  console.log(`Nepal Country ID: ${npCountryId}`);

  // 2. Fetch existing carriers
  const existingCarriers = await api(`carriers?country_id=eq.${npCountryId}`);
  console.log(`Found ${existingCarriers.length} existing carriers for Nepal:`, existingCarriers.map(c => c.name));

  const carrierMapByName = {};
  existingCarriers.forEach(c => {
    carrierMapByName[c.name.toLowerCase().trim()] = c;
  });

  const targetCarriers = [
    { name: 'Ncell', canonical: 'Ncell', default_refill_amount: 1.00, is_supported: true, gateway: 'API' },
    { name: 'Nepal Telecom', canonical: 'Nepal Telecom', default_refill_amount: 1.00, is_supported: true, gateway: 'API' },
    { name: 'Smart Cell', canonical: 'Smart Cell', default_refill_amount: 1.00, is_supported: false, gateway: 'MANUAL' }
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
      console.log(`Updating existing carrier ${tc.canonical} (ID: ${matched.id})...`);
      const updated = await api(`carriers?id=eq.${matched.id}`, 'PATCH', {
        name: tc.canonical,
        is_supported: tc.is_supported,
        country_id: npCountryId,
        default_refill_amount: tc.default_refill_amount,
        fulfillment_gateway: tc.gateway
      });
      carrierIdMap[tc.canonical] = updated[0].id;
    } else {
      console.log(`Inserting new carrier ${tc.canonical}...`);
      const inserted = await api('carriers', 'POST', {
        country_id: npCountryId,
        name: tc.canonical,
        is_supported: tc.is_supported,
        default_refill_amount: tc.default_refill_amount,
        fulfillment_gateway: tc.gateway
      });
      carrierIdMap[tc.canonical] = inserted[0].id;
    }
  }

  console.log('Carrier IDs:', carrierIdMap);

  // 3. Upsert Carrier Rules
  console.log('\n3. Upserting Carrier Rules...');
  const rules = [
    {
      carrier_id: carrierIdMap['Ncell'],
      rule_type: 'prepaid',
      inactivity_limit_days: 180,
      grace_period_days: 90,
      minimum_topup_amount: 0.25,
      topup_validity_days: 30,
      recommended_topup_amount: 0.50,
      activity_requirement: 'recharge_ok',
      validity_qualifying_topup_amount: 0.25,
      notes: "Ncell Nepal (Axiata/Spectrlite): NTA regulations enforce 180-day dormancy window followed by 90-day grace period. Recharges of 30-50 NPR reset line validity. Dial *901# to check balance.",
      last_verified_at: new Date().toISOString()
    },
    {
      carrier_id: carrierIdMap['Nepal Telecom'],
      rule_type: 'prepaid',
      inactivity_limit_days: 365,
      grace_period_days: 60,
      minimum_topup_amount: 0.10,
      topup_validity_days: 30,
      recommended_topup_amount: 1.00,
      activity_requirement: 'min_denomination',
      validity_qualifying_topup_amount: 0.10,
      notes: "Nepal Telecom (Namaste / NTC): NPR 10 adds 5 days, NPR 50 adds 30 days, NPR 100 adds 60 days, NPR 200 adds 140 days, NPR 500 adds 360 days (1 full year), NPR 1000 adds 730 days. Dial *400# for balance and expiry date.",
      last_verified_at: new Date().toISOString()
    },
    {
      carrier_id: carrierIdMap['Smart Cell'],
      rule_type: 'prepaid',
      inactivity_limit_days: 90,
      grace_period_days: 30,
      minimum_topup_amount: 1.00,
      topup_validity_days: 30,
      recommended_topup_amount: 1.00,
      activity_requirement: 'recharge_ok',
      validity_qualifying_topup_amount: 1.00,
      notes: "Smart Cell (Smart Telecom) license cancelled by NTA in 2023. Non-operational.",
      last_verified_at: new Date().toISOString()
    }
  ];

  for (const r of rules) {
    const existingRule = await api(`carrier_rules?carrier_id=eq.${r.carrier_id}`);
    if (existingRule && existingRule.length > 0) {
      console.log(`Updating rule for carrier ${r.carrier_id}...`);
      await api(`carrier_rules?id=eq.${existingRule[0].id}`, 'PATCH', r);
    } else {
      console.log(`Inserting rule for carrier ${r.carrier_id}...`);
      await api('carrier_rules', 'POST', r);
    }
  }

  // 4. Upsert Carrier Provider Map
  console.log('\n4. Upserting Carrier Provider Mappings...');
  const mappings = [
    // Ncell
    {
      carrier_id: carrierIdMap['Ncell'],
      provider: 'dtone',
      provider_country_code: 'NPL',
      provider_carrier_code: '1442',
      provider_country_label: 'Nepal',
      provider_carrier_label: 'NCell Nepal',
      priority: 10,
      is_primary: true,
      is_enabled: true,
      notes: 'DT One Operator 1442: Direct airtime (50 NPR ID 4658, range 50-3000 NPR ID 11938) and data bundles. Primary route.',
      last_verified_at: new Date().toISOString()
    },
    {
      carrier_id: carrierIdMap['Ncell'],
      provider: 'reloadly',
      provider_country_code: 'NP',
      provider_carrier_code: '328',
      provider_country_label: 'Nepal',
      provider_carrier_label: 'NCell Nepal',
      priority: 20,
      is_primary: false,
      is_enabled: true,
      notes: 'Reloadly Operator 328: Range $0.38 - $37.72 USD + Operator 1121 Data Bundles. Secondary failover.',
      last_verified_at: new Date().toISOString()
    },
    {
      carrier_id: carrierIdMap['Ncell'],
      provider: 'zendit',
      provider_country_code: 'NP',
      provider_carrier_code: 'Ncell',
      provider_country_label: 'Nepal',
      provider_carrier_label: 'Ncell',
      priority: 30,
      is_primary: false,
      is_enabled: true,
      notes: 'Zendit Offers: NCELL_NP_6-I, NCELL_NP_12-I, NCELL_NP_18-I, NCELL_NP_24-I. Tertiary failover.',
      last_verified_at: new Date().toISOString()
    },
    {
      carrier_id: carrierIdMap['Ncell'],
      provider: 'ding',
      provider_country_code: 'NP',
      provider_carrier_code: 'NCNP',
      provider_country_label: 'Nepal',
      provider_carrier_label: 'Ncell Nepal',
      priority: 40,
      is_primary: false,
      is_enabled: false,
      notes: 'DingConnect Provider NCNP. Disabled: 0 active UAT catalog SKUs.',
      last_verified_at: new Date().toISOString()
    },

    // Nepal Telecom (NTC)
    {
      carrier_id: carrierIdMap['Nepal Telecom'],
      provider: 'dtone',
      provider_country_code: 'NPL',
      provider_carrier_code: '1443',
      provider_country_label: 'Nepal',
      provider_carrier_label: 'NTC Nepal',
      priority: 10,
      is_primary: true,
      is_enabled: true,
      notes: 'DT One Operator 1443: Micro-refills (10 NPR ID 6972 = $0.08 USD, 50 NPR ID 6976, range 10-10000 NPR ID 11939, 500 NPR 1-year ID 4571). Primary route.',
      last_verified_at: new Date().toISOString()
    },
    {
      carrier_id: carrierIdMap['Nepal Telecom'],
      provider: 'reloadly',
      provider_country_code: 'NP',
      provider_carrier_code: '326',
      provider_country_label: 'Nepal',
      provider_carrier_label: 'NTC GSM Nepal',
      priority: 20,
      is_primary: false,
      is_enabled: true,
      notes: 'Reloadly Operator 326: Range $0.38 - $150.86 USD + Operator 1123 Data Bundles. Secondary failover.',
      last_verified_at: new Date().toISOString()
    },
    {
      carrier_id: carrierIdMap['Nepal Telecom'],
      provider: 'zendit',
      provider_country_code: 'NP',
      provider_carrier_code: 'NTCGSM',
      provider_country_label: 'Nepal',
      provider_carrier_label: 'NTCGSM',
      priority: 30,
      is_primary: false,
      is_enabled: true,
      notes: 'Zendit Offers: NTCGSM_NP_2.5-I, NTCGSM_NP_6-I, NTCGSM_NP_12-I. Tertiary failover.',
      last_verified_at: new Date().toISOString()
    },
    {
      carrier_id: carrierIdMap['Nepal Telecom'],
      provider: 'ding',
      provider_country_code: 'NP',
      provider_carrier_code: 'NENP',
      provider_country_label: 'Nepal',
      provider_carrier_label: 'Nepal Telecom Nepal',
      priority: 40,
      is_primary: false,
      is_enabled: false,
      notes: 'DingConnect Provider NENP. Disabled: 0 active UAT catalog SKUs.',
      last_verified_at: new Date().toISOString()
    },

    // Smart Cell (Decommissioned)
    {
      carrier_id: carrierIdMap['Smart Cell'],
      provider: 'reloadly',
      provider_country_code: 'NP',
      provider_carrier_code: '805',
      provider_country_label: 'Nepal',
      provider_carrier_label: 'Smartcell Nepal',
      priority: 20,
      is_primary: false,
      is_enabled: false,
      notes: 'Reloadly Operator 805: Decommissioned / Disabled. Smart Telecom license revoked by NTA in 2023.',
      last_verified_at: new Date().toISOString()
    }
  ];

  for (const m of mappings) {
    const existingMap = await api(`carrier_provider_map?carrier_id=eq.${m.carrier_id}&provider=eq.${m.provider}`);
    if (existingMap && existingMap.length > 0) {
      console.log(`Updating mapping for carrier ${m.carrier_id} (${m.provider})...`);
      await api(`carrier_provider_map?id=eq.${existingMap[0].id}`, 'PATCH', m);
    } else {
      console.log(`Inserting mapping for carrier ${m.carrier_id} (${m.provider})...`);
      await api('carrier_provider_map', 'POST', m);
    }
  }

  console.log('\nSupabase provisioning for Nepal complete!');
}

main().catch(console.error);
