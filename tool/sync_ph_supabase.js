const fs = require('fs');
const path = require('path');

const candidatePaths = [
  path.join(__dirname, '..', 'servers', '.env'),
  path.join(__dirname, 'servers', '.env'),
  path.join(__dirname, '.env'),
  '/home/abdal/keepsims_backend/servers/.env'
];
let env = {};
for (const p of candidatePaths) {
  if (fs.existsSync(p)) {
    const content = fs.readFileSync(p, 'utf8');
    content.split('\n').forEach(line => {
      const m = line.match(/^\s*([\w_]+)\s*=\s*(.*)?\s*$/);
      if (m) {
        let v = (m[2] || '').trim();
        if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) {
          v = v.slice(1, -1);
        }
        env[m[1]] = v;
      }
    });
    break;
  }
}

const supabaseUrl = env.SUPABASE_URL || process.env.SUPABASE_URL;
const supabaseKey = env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY;

async function querySupabase(endpoint, options = {}) {
  const url = `${supabaseUrl}/rest/v1/${endpoint}`;
  const res = await fetch(url, {
    ...options,
    headers: {
      'apikey': supabaseKey,
      'Authorization': `Bearer ${supabaseKey}`,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
      ...(options.headers || {})
    }
  });
  if (!res.ok) {
    const text = await res.text();
    console.error(`Supabase error ${res.status} on ${endpoint}:`, text);
    return null;
  }
  return await res.json();
}

async function syncPhilippines() {
  console.log('====================================================');
  console.log('PROVISIONING & SYNCING PHILIPPINES IN SUPABASE');
  console.log('====================================================\n');

  // 1. Get Country
  const phCountries = await querySupabase('countries?select=*&name=ilike.*Philippines*');
  if (!phCountries || phCountries.length === 0) {
    console.error('Philippines country record not found!');
    return;
  }
  const country = phCountries[0];
  console.log('Philippines Country ID:', country.id);

  // 2. Ensure all 5 carriers exist
  const desiredCarriers = [
    { name: 'Globe Telecom', is_supported: true, default_refill_amount: 10, fulfillment_gateway: 'API' },
    { name: 'Smart Communications', is_supported: true, default_refill_amount: 10, fulfillment_gateway: 'API' },
    { name: 'DITO Telecommunity', is_supported: true, default_refill_amount: 99, fulfillment_gateway: 'API' },
    { name: 'TM (Touch Mobile)', is_supported: true, default_refill_amount: 10, fulfillment_gateway: 'API' },
    { name: 'TNT (Talk \'N Text)', is_supported: true, default_refill_amount: 10, fulfillment_gateway: 'API' }
  ];

  let currentCarriers = await querySupabase(`carriers?select=*&country_id=eq.${country.id}`);
  console.log('Initial PH carriers in DB:', currentCarriers.map(c => c.name));

  for (const dc of desiredCarriers) {
    const exists = currentCarriers.find(c => c.name.toLowerCase() === dc.name.toLowerCase() || (dc.name.includes('TM') && c.name.toLowerCase().includes('touch mobile')) || (dc.name.includes('TNT') && c.name.toLowerCase().includes('talk')));
    if (!exists) {
      console.log(`Inserting missing carrier: ${dc.name}...`);
      const inserted = await querySupabase('carriers', {
        method: 'POST',
        body: JSON.stringify({
          country_id: country.id,
          name: dc.name,
          is_supported: dc.is_supported,
          default_refill_amount: dc.default_refill_amount,
          fulfillment_gateway: dc.fulfillment_gateway
        })
      });
      console.log(`Inserted ${dc.name}:`, inserted);
    }
  }

  // Refresh carriers list
  currentCarriers = await querySupabase(`carriers?select=*&country_id=eq.${country.id}`);
  console.log(`Updated PH carriers in DB (${currentCarriers.length}):`, currentCarriers.map(c => ({ id: c.id, name: c.name })));

  const globe = currentCarriers.find(c => c.name.toLowerCase().includes('globe'));
  const smart = currentCarriers.find(c => c.name.toLowerCase().includes('smart'));
  const dito = currentCarriers.find(c => c.name.toLowerCase().includes('dito'));
  const tm = currentCarriers.find(c => c.name.toLowerCase().includes('tm') || c.name.toLowerCase().includes('touch mobile'));
  const tnt = currentCarriers.find(c => c.name.toLowerCase().includes('tnt') || c.name.toLowerCase().includes('talk'));

  const carrierIds = [globe.id, smart.id, dito.id, tm.id, tnt.id];

  // 3. Clear is_primary on existing mappings to avoid unique constraint collisions
  await querySupabase(`carrier_provider_map?carrier_id=in.(${carrierIds.join(',')})`, {
    method: 'PATCH',
    body: JSON.stringify({ is_primary: false })
  });

  // 4. Master Carrier Provider Mappings
  const mappings = [
    // Globe Telecom
    { carrier_id: globe.id, provider: 'dtone', provider_country_code: 'PHL', provider_carrier_code: '246', provider_carrier_label: 'Globe Telecom Philippines', provider_country_label: 'Philippines', is_enabled: true, is_primary: true, priority: 10, notes: 'DT One Primary: 22 products from 10 PHP (0.076 OMR / $0.198 USD)' },
    { carrier_id: globe.id, provider: 'reloadly', provider_country_code: 'PH', provider_carrier_code: '371', provider_carrier_label: 'Globe Telecom Philippines', provider_country_label: 'Philippines', is_enabled: true, is_primary: false, priority: 20, notes: 'Reloadly Secondary: Fixed 10 PHP ($0.18 USD)' },
    { carrier_id: globe.id, provider: 'zendit', provider_country_code: 'PH', provider_carrier_code: 'Globe', provider_carrier_label: 'Globe', provider_country_label: 'Philippines', is_enabled: true, is_primary: false, priority: 30, notes: 'Zendit Tertiary: 5 bundle/airtime offers from 400 PHP' },
    { carrier_id: globe.id, provider: 'ding', provider_country_code: 'PH', provider_carrier_code: 'GBPH', provider_carrier_label: 'BS_Globe Philippines', provider_country_label: 'Philippines', is_enabled: false, is_primary: false, priority: 40, notes: 'DingConnect: Disabled (0 inventory in UAT)' },

    // Smart Communications
    { carrier_id: smart.id, provider: 'dtone', provider_country_code: 'PHL', provider_carrier_code: '570', provider_carrier_label: 'Smart Philippines', provider_country_label: 'Philippines', is_enabled: true, is_primary: true, priority: 10, notes: 'DT One Primary: 38 products from 5/10 PHP (0.074 OMR / $0.192 USD)' },
    { carrier_id: smart.id, provider: 'reloadly', provider_country_code: 'PH', provider_carrier_code: '372', provider_carrier_label: 'Smart Philippines', provider_country_label: 'Philippines', is_enabled: true, is_primary: false, priority: 20, notes: 'Reloadly Secondary: Range 0.27-18.3 USD ($0.27 USD / 14.74 PHP)' },
    { carrier_id: smart.id, provider: 'zendit', provider_country_code: 'PH', provider_carrier_code: 'Smart', provider_carrier_label: 'Smart', provider_country_label: 'Philippines', is_enabled: true, is_primary: false, priority: 30, notes: 'Zendit Tertiary: 5 bundle/airtime offers from 300 PHP' },
    { carrier_id: smart.id, provider: 'ding', provider_country_code: 'PH', provider_carrier_code: 'SMPH', provider_carrier_label: 'Smart (SunCellular) Philippines', provider_country_label: 'Philippines', is_enabled: false, is_primary: false, priority: 40, notes: 'DingConnect: Disabled (0 inventory in UAT)' },

    // DITO Telecommunity
    { carrier_id: dito.id, provider: 'zendit', provider_country_code: 'PH', provider_carrier_code: 'Dito', provider_carrier_label: 'Dito', provider_country_label: 'Philippines', is_enabled: true, is_primary: true, priority: 10, notes: 'Zendit Exclusive Active Primary: 4 offers from 99 PHP ($1.69 USD)' },
    { carrier_id: dito.id, provider: 'reloadly', provider_country_code: 'PH', provider_carrier_code: '1182', provider_carrier_label: 'Dito Philippines', provider_country_label: 'Philippines', is_enabled: false, is_primary: false, priority: 20, notes: 'Reloadly: Disabled (inactivity in sandbox)' },
    { carrier_id: dito.id, provider: 'ding', provider_country_code: 'PH', provider_carrier_code: 'DWPH', provider_carrier_label: 'Dito Philippines', provider_country_label: 'Philippines', is_enabled: false, is_primary: false, priority: 30, notes: 'DingConnect: Disabled (0 inventory in UAT)' },

    // TM (Touch Mobile)
    { carrier_id: tm.id, provider: 'dtone', provider_country_code: 'PHL', provider_carrier_code: '3128', provider_carrier_label: 'Touch Mobile Philippines', provider_country_label: 'Philippines', is_enabled: true, is_primary: true, priority: 10, notes: 'DT One Primary: 18 products from 10 PHP (0.076 OMR / $0.198 USD)' },
    { carrier_id: tm.id, provider: 'reloadly', provider_country_code: 'PH', provider_carrier_code: '723', provider_carrier_label: 'Touch Mobile Philippines', provider_country_label: 'Philippines', is_enabled: true, is_primary: false, priority: 20, notes: 'Reloadly Secondary: Fixed 10 PHP ($0.18 USD)' },
    { carrier_id: tm.id, provider: 'zendit', provider_country_code: 'PH', provider_carrier_code: 'TouchMobile', provider_carrier_label: 'TouchMobile', provider_country_label: 'Philippines', is_enabled: true, is_primary: false, priority: 30, notes: 'Zendit Tertiary: 10 offers from 150 PHP ($3.57 USD)' },
    { carrier_id: tm.id, provider: 'ding', provider_country_code: 'PH', provider_carrier_code: 'TMPH', provider_carrier_label: 'Touch Mobile Philippines', provider_country_label: 'Philippines', is_enabled: false, is_primary: false, priority: 40, notes: 'DingConnect: Disabled (0 inventory in UAT)' },

    // TNT (Talk 'N Text)
    { carrier_id: tnt.id, provider: 'dtone', provider_country_code: 'PHL', provider_carrier_code: '2897', provider_carrier_label: 'TNT Philippines', provider_country_label: 'Philippines', is_enabled: true, is_primary: true, priority: 10, notes: 'DT One Primary: 39 products from 20 PHP (0.147 OMR / $0.382 USD)' },
    { carrier_id: tnt.id, provider: 'reloadly', provider_country_code: 'PH', provider_carrier_code: '378', provider_carrier_label: 'TNT Philippines', provider_country_label: 'Philippines', is_enabled: true, is_primary: false, priority: 20, notes: 'Reloadly Secondary: Range 0.18-18.3 USD / PIN' },
    { carrier_id: tnt.id, provider: 'zendit', provider_country_code: 'PH', provider_carrier_code: 'TNT', provider_carrier_label: 'TNT', provider_country_label: 'Philippines', is_enabled: true, is_primary: false, priority: 30, notes: 'Zendit Tertiary: 4 bundle offers from 318 PHP ($5.42 USD)' },
    { carrier_id: tnt.id, provider: 'ding', provider_country_code: 'PH', provider_carrier_code: 'STPH', provider_carrier_label: 'SmartTalk n Text Philippines', provider_country_label: 'Philippines', is_enabled: false, is_primary: false, priority: 40, notes: 'DingConnect: Disabled (0 inventory in UAT)' },
  ];

  console.log('\n--- Upserting Carrier Provider Mappings ---');
  for (const m of mappings) {
    const existing = await querySupabase(`carrier_provider_map?select=id&carrier_id=eq.${m.carrier_id}&provider=eq.${m.provider}`);
    if (existing && existing.length > 0) {
      await querySupabase(`carrier_provider_map?id=eq.${existing[0].id}`, {
        method: 'PATCH',
        body: JSON.stringify({
          provider_country_code: m.provider_country_code,
          provider_carrier_code: m.provider_carrier_code,
          provider_carrier_label: m.provider_carrier_label,
          provider_country_label: m.provider_country_label,
          is_enabled: m.is_enabled,
          is_primary: m.is_primary,
          priority: m.priority,
          notes: m.notes,
          last_verified_at: new Date().toISOString()
        })
      });
      console.log(`Updated map for [${m.provider_carrier_label}] -> ${m.provider}`);
    } else {
      await querySupabase('carrier_provider_map', {
        method: 'POST',
        body: JSON.stringify({
          ...m,
          last_verified_at: new Date().toISOString()
        })
      });
      console.log(`Inserted map for [${m.provider_carrier_label}] -> ${m.provider}`);
    }
  }

  // 5. Upsert Carrier Rules
  console.log('\n--- Upserting Carrier Rules ---');
  const now = new Date().toISOString();
  const rules = [
    {
      carrier_id: globe.id,
      rule_type: 'prepaid',
      inactivity_limit_days: 365,
      grace_period_days: 120,
      minimum_topup_amount: 10,
      topup_validity_days: 365,
      recommended_topup_amount: 10,
      optimal_topup_window_start: 100,
      optimal_topup_window_end: 110,
      notes: 'NTC-DICT 1-Year Load Validity Rule (MC 05-12-2017). Globe Prepaid: balance is valid for 365 days. 120 consecutive days at zero balance without reloading permanently deactivates the SIM card.',
      last_verified_at: now,
      activity_requirement: 'recharge_ok',
      rule_source_url: 'https://www.globe.com.ph/help/prepaid/sim-validity'
    },
    {
      carrier_id: smart.id,
      rule_type: 'prepaid',
      inactivity_limit_days: 365,
      grace_period_days: 180,
      minimum_topup_amount: 10,
      topup_validity_days: 365,
      recommended_topup_amount: 10,
      optimal_topup_window_start: 150,
      optimal_topup_window_end: 165,
      notes: 'NTC-DICT 1-Year Load Validity Rule (MC 05-12-2017). Smart Prepaid: all reloads are valid for 365 days. Once balance reaches zero, subscribers have 180 days to reload before line termination.',
      last_verified_at: now,
      activity_requirement: 'recharge_ok',
      rule_source_url: 'https://smart.com.ph/prepaid'
    },
    {
      carrier_id: dito.id,
      rule_type: 'prepaid',
      inactivity_limit_days: 365,
      grace_period_days: 90,
      minimum_topup_amount: 99,
      topup_validity_days: 365,
      recommended_topup_amount: 99,
      optimal_topup_window_start: 80,
      optimal_topup_window_end: 85,
      notes: 'DITO Telecommunity: 1-year load validity per NTC rule. However, DITO enforces a 90-day non-usage threshold if balance is zero / below PHP 1.00 with no active promo pack.',
      last_verified_at: now,
      activity_requirement: 'recharge_ok',
      rule_source_url: 'https://dito.ph'
    },
    {
      carrier_id: tm.id,
      rule_type: 'prepaid',
      inactivity_limit_days: 365,
      grace_period_days: 120,
      minimum_topup_amount: 10,
      topup_validity_days: 365,
      recommended_topup_amount: 10,
      optimal_topup_window_start: 100,
      optimal_topup_window_end: 110,
      notes: 'NTC-DICT 1-Year Load Validity Rule. TM (Touch Mobile) operates under Globe network policies: 365 days load validity, 120 days zero-balance deactivation window.',
      last_verified_at: now,
      activity_requirement: 'recharge_ok',
      rule_source_url: 'https://www.tmtambayan.ph'
    },
    {
      carrier_id: tnt.id,
      rule_type: 'prepaid',
      inactivity_limit_days: 365,
      grace_period_days: 180,
      minimum_topup_amount: 10,
      topup_validity_days: 365,
      recommended_topup_amount: 10,
      optimal_topup_window_start: 150,
      optimal_topup_window_end: 165,
      notes: 'NTC-DICT 1-Year Load Validity Rule. TNT (Talk N Text) operates under Smart network policies: 365 days load validity, 180 days zero-balance deactivation window.',
      last_verified_at: now,
      activity_requirement: 'recharge_ok',
      rule_source_url: 'https://tntph.com'
    }
  ];

  for (const r of rules) {
    const existing = await querySupabase(`carrier_rules?select=id&carrier_id=eq.${r.carrier_id}`);
    if (existing && existing.length > 0) {
      await querySupabase(`carrier_rules?id=eq.${existing[0].id}`, {
        method: 'PATCH',
        body: JSON.stringify(r)
      });
      console.log(`Updated rule for carrier [${r.carrier_id}]`);
    } else {
      await querySupabase('carrier_rules', {
        method: 'POST',
        body: JSON.stringify(r)
      });
      console.log(`Inserted rule for carrier [${r.carrier_id}]`);
    }
  }

  console.log('\n====================================================');
  console.log('SUPABASE PHILIPPINES PROVISIONING COMPLETED');
  console.log('====================================================');
}

syncPhilippines().catch(console.error);
