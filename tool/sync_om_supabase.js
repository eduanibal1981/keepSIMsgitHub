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

async function syncOman() {
  console.log('====================================================');
  console.log('PROVISIONING & SYNCING OMAN (OM) IN SUPABASE');
  console.log('====================================================\n');

  // 1. Get Country
  const omCountries = await querySupabase('countries?select=*&name=ilike.*Oman*');
  if (!omCountries || omCountries.length === 0) {
    console.error('Oman country record not found!');
    return;
  }
  const country = omCountries[0];
  console.log('Oman Country ID:', country.id);

  // 2. Ensure all 6 carriers exist and are marked is_supported: true
  const desiredCarriers = [
    { name: 'Omantel', is_supported: true, default_refill_amount: 1, fulfillment_gateway: 'API' },
    { name: 'Ooredoo Oman', is_supported: true, default_refill_amount: 1, fulfillment_gateway: 'API' },
    { name: 'Vodafone Oman', is_supported: true, default_refill_amount: 1, fulfillment_gateway: 'API' },
    { name: 'FRiENDi Mobile Oman', is_supported: true, default_refill_amount: 1, fulfillment_gateway: 'API' },
    { name: 'Renna Mobile', is_supported: true, default_refill_amount: 0.3, fulfillment_gateway: 'API' },
    { name: 'Red Bull Mobile Oman', is_supported: true, default_refill_amount: 0.3, fulfillment_gateway: 'API' }
  ];

  let currentCarriers = await querySupabase(`carriers?select=*&country_id=eq.${country.id}`);
  console.log('Initial OM carriers in DB:', currentCarriers.map(c => c.name));

  for (const dc of desiredCarriers) {
    const exists = currentCarriers.find(c => 
      c.name.toLowerCase() === dc.name.toLowerCase() ||
      (dc.name.toLowerCase().includes('omantel') && c.name.toLowerCase().includes('omantel')) ||
      (dc.name.toLowerCase().includes('ooredoo') && c.name.toLowerCase().includes('ooredoo')) ||
      (dc.name.toLowerCase().includes('vodafone') && c.name.toLowerCase().includes('vodafone')) ||
      (dc.name.toLowerCase().includes('friendi') && c.name.toLowerCase().includes('friendi')) ||
      (dc.name.toLowerCase().includes('renna') && c.name.toLowerCase().includes('renna')) ||
      (dc.name.toLowerCase().includes('red bull') && c.name.toLowerCase().includes('red bull'))
    );
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
    } else {
      await querySupabase(`carriers?id=eq.${exists.id}`, {
        method: 'PATCH',
        body: JSON.stringify({
          is_supported: true,
          default_refill_amount: dc.default_refill_amount,
          fulfillment_gateway: 'API'
        })
      });
      console.log(`Updated carrier [${exists.name}] to is_supported: true`);
    }
  }

  // Refresh carriers list
  currentCarriers = await querySupabase(`carriers?select=*&country_id=eq.${country.id}`);
  console.log(`Updated OM carriers in DB (${currentCarriers.length}):`, currentCarriers.map(c => ({ id: c.id, name: c.name })));

  const omantel = currentCarriers.find(c => c.name.toLowerCase().includes('omantel'));
  const ooredoo = currentCarriers.find(c => c.name.toLowerCase().includes('ooredoo'));
  const vodafone = currentCarriers.find(c => c.name.toLowerCase().includes('vodafone'));
  const friendi = currentCarriers.find(c => c.name.toLowerCase().includes('friendi'));
  const renna = currentCarriers.find(c => c.name.toLowerCase().includes('renna'));
  const redbull = currentCarriers.find(c => c.name.toLowerCase().includes('red bull'));

  const carrierIds = [omantel.id, ooredoo.id, vodafone.id, friendi.id, renna.id, redbull.id];

  // 3. Clear is_primary on existing mappings to avoid unique constraint collisions
  await querySupabase(`carrier_provider_map?carrier_id=in.(${carrierIds.join(',')})`, {
    method: 'PATCH',
    body: JSON.stringify({ is_primary: false })
  });

  // 4. Master Carrier Provider Mappings (Valid numeric IDs for DT One and Reloadly)
  const mappings = [
    // Omantel
    { carrier_id: omantel.id, provider: 'reloadly', provider_country_code: 'OM', provider_carrier_code: '348', provider_carrier_label: 'Omantel PIN Oman', provider_country_label: 'Oman', is_enabled: true, is_primary: true, priority: 10, notes: 'Reloadly Primary PIN: 4 denominations from $2.955 USD' },
    { carrier_id: omantel.id, provider: 'dtone', provider_country_code: 'OMN', provider_carrier_code: '2695', provider_carrier_label: 'Omantel PIN Oman', provider_country_label: 'Oman', is_enabled: true, is_primary: false, priority: 20, notes: 'DT One Secondary PIN Failover: 8 products from 1.240 OMR ($3.224 USD)' },
    { carrier_id: omantel.id, provider: 'ding', provider_country_code: 'OM', provider_carrier_code: 'OMOM', provider_carrier_label: 'Omantel Oman', provider_country_label: 'Oman', is_enabled: true, is_primary: false, priority: 30, notes: 'DingConnect Tertiary: Direct / PIN' },
    { carrier_id: omantel.id, provider: 'zendit', provider_country_code: 'OM', provider_carrier_code: 'Omantel', provider_carrier_label: 'Omantel', provider_country_label: 'Oman', is_enabled: false, is_primary: false, priority: 40, notes: 'Zendit Disabled: 0 catalog offers' },

    // Ooredoo Oman
    { carrier_id: ooredoo.id, provider: 'reloadly', provider_country_code: 'OM', provider_carrier_code: '1168', provider_carrier_label: 'Ooredoo Oman', provider_country_label: 'Oman', is_enabled: true, is_primary: true, priority: 10, notes: 'Reloadly Primary Direct: 10 fixed amounts from $2.95 USD (1.14 OMR)' },
    { carrier_id: ooredoo.id, provider: 'dtone', provider_country_code: 'OMN', provider_carrier_code: '2883', provider_carrier_label: 'Ooredoo PIN Oman', provider_country_label: 'Oman', is_enabled: true, is_primary: false, priority: 20, notes: 'DT One Secondary PIN: 4 products from 1.228 OMR ($3.193 USD)' },
    { carrier_id: ooredoo.id, provider: 'ding', provider_country_code: 'OM', provider_carrier_code: 'OOOM', provider_carrier_label: 'Ooredoo Oman', provider_country_label: 'Oman', is_enabled: true, is_primary: false, priority: 30, notes: 'DingConnect Tertiary: Direct Top-Up' },
    { carrier_id: ooredoo.id, provider: 'zendit', provider_country_code: 'OM', provider_carrier_code: 'Ooredoo', provider_carrier_label: 'Ooredoo', provider_country_label: 'Oman', is_enabled: false, is_primary: false, priority: 40, notes: 'Zendit Disabled: 0 catalog offers' },

    // Vodafone Oman
    { carrier_id: vodafone.id, provider: 'ding', provider_country_code: 'OM', provider_carrier_code: 'VFOM', provider_carrier_label: 'Vodafone Oman', provider_country_label: 'Oman', is_enabled: true, is_primary: true, priority: 10, notes: 'DingConnect Primary: Direct provider mapping for Vodafone Oman' },
    { carrier_id: vodafone.id, provider: 'zendit', provider_country_code: 'OM', provider_carrier_code: 'Vodafone', provider_carrier_label: 'Vodafone Oman', provider_country_label: 'Oman', is_enabled: false, is_primary: false, priority: 40, notes: 'Zendit Disabled: 0 catalog offers' },

    // FRiENDi Mobile Oman
    { carrier_id: friendi.id, provider: 'dtone', provider_country_code: 'OMN', provider_carrier_code: '2695', provider_carrier_label: 'Omantel PIN Oman (FRiENDi)', provider_country_label: 'Oman', is_enabled: true, is_primary: true, priority: 10, notes: 'DT One Primary: Serviced via Omantel host PIN rails (1.240 OMR)' },
    { carrier_id: friendi.id, provider: 'reloadly', provider_country_code: 'OM', provider_carrier_code: '348', provider_carrier_label: 'Omantel PIN Oman (FRiENDi)', provider_country_label: 'Oman', is_enabled: true, is_primary: false, priority: 20, notes: 'Reloadly Secondary: Serviced via Omantel PIN rails ($2.955 USD)' },
    { carrier_id: friendi.id, provider: 'ding', provider_country_code: 'OM', provider_carrier_code: 'OMOM', provider_carrier_label: 'Omantel Oman (FRiENDi)', provider_country_label: 'Oman', is_enabled: true, is_primary: false, priority: 30, notes: 'DingConnect Tertiary: Direct / PIN' },
    { carrier_id: friendi.id, provider: 'zendit', provider_country_code: 'OM', provider_carrier_code: 'Friendi', provider_carrier_label: 'Friendi Oman', provider_country_label: 'Oman', is_enabled: false, is_primary: false, priority: 40, notes: 'Zendit Disabled: 0 catalog offers' },

    // Renna Mobile
    { carrier_id: renna.id, provider: 'dtone', provider_country_code: 'OMN', provider_carrier_code: '2697', provider_carrier_label: 'Renna PIN Oman', provider_country_label: 'Oman', is_enabled: true, is_primary: true, priority: 10, notes: 'DT One Primary: 8 products from 0.3 OMR micro-PIN (0.370 OMR / $0.962 USD)' },
    { carrier_id: renna.id, provider: 'reloadly', provider_country_code: 'OM', provider_carrier_code: '349', provider_carrier_label: 'Renna PIN Oman', provider_country_label: 'Oman', is_enabled: true, is_primary: false, priority: 20, notes: 'Reloadly Secondary: 6 PIN amounts from $1.478 USD' },
    { carrier_id: renna.id, provider: 'zendit', provider_country_code: 'OM', provider_carrier_code: 'Renna', provider_carrier_label: 'Renna Oman', provider_country_label: 'Oman', is_enabled: false, is_primary: false, priority: 40, notes: 'Zendit Disabled: 0 catalog offers' },

    // Red Bull Mobile Oman
    { carrier_id: redbull.id, provider: 'dtone', provider_country_code: 'OMN', provider_carrier_code: '3444', provider_carrier_label: 'Red Bull Oman', provider_country_label: 'Oman', is_enabled: true, is_primary: true, priority: 10, notes: 'DT One Exclusive Primary: 6 products from 0.3 OMR micro-PIN (0.369 OMR / $0.959 USD)' },
    { carrier_id: redbull.id, provider: 'zendit', provider_country_code: 'OM', provider_carrier_code: 'RedBull', provider_carrier_label: 'Red Bull Oman', provider_country_label: 'Oman', is_enabled: false, is_primary: false, priority: 40, notes: 'Zendit Disabled: 0 catalog offers' }
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

  // 5. Upsert Carrier Rules (optimal_topup_window set to null or valid time string)
  console.log('\n--- Upserting Carrier Rules ---');
  const now = new Date().toISOString();
  const rules = [
    {
      carrier_id: omantel.id,
      rule_type: 'prepaid',
      inactivity_limit_days: 180,
      grace_period_days: 30,
      minimum_topup_amount: 2.955,
      topup_validity_days: 180,
      recommended_topup_amount: 2.955,
      optimal_topup_window_start: null,
      optimal_topup_window_end: null,
      notes: 'TRA Oman: Omantel Hayyak lines maintain 180-day active validity from the date of the last recharge or qualifying paid transaction, followed by a 30-day grace period before termination.',
      last_verified_at: now,
      activity_requirement: 'recharge_ok',
      rule_source_url: 'https://www.omantel.om'
    },
    {
      carrier_id: ooredoo.id,
      rule_type: 'prepaid',
      inactivity_limit_days: 150,
      grace_period_days: 30,
      minimum_topup_amount: 2.95,
      topup_validity_days: 150,
      recommended_topup_amount: 2.95,
      optimal_topup_window_start: null,
      optimal_topup_window_end: null,
      notes: 'TRA Oman: Ooredoo Oman prepaid lines carry 150 active days from the last recharge date plus a 30-day grace period before line termination and number retrieval.',
      last_verified_at: now,
      activity_requirement: 'recharge_ok',
      rule_source_url: 'https://www.ooredoo.om/en/help-centre/faq/prepaid-service/'
    },
    {
      carrier_id: vodafone.id,
      rule_type: 'prepaid',
      inactivity_limit_days: 90,
      grace_period_days: 30,
      minimum_topup_amount: 2.60,
      topup_validity_days: 90,
      recommended_topup_amount: 2.60,
      optimal_topup_window_start: null,
      optimal_topup_window_end: null,
      notes: 'TRA Oman: Vodafone Oman accounts maintain active validity refreshed through digital subscriptions, flexi-plans, or top-ups with a 30-day grace period.',
      last_verified_at: now,
      activity_requirement: 'recharge_ok',
      rule_source_url: 'https://www.vodafone.om'
    },
    {
      carrier_id: friendi.id,
      rule_type: 'prepaid',
      inactivity_limit_days: 180,
      grace_period_days: 30,
      minimum_topup_amount: 2.955,
      topup_validity_days: 180,
      recommended_topup_amount: 2.955,
      optimal_topup_window_start: null,
      optimal_topup_window_end: null,
      notes: 'TRA Oman: FRiENDi Mobile prepaid SIM cards carry 180 days active line validity from the last recharge event + 30 days suspension grace period.',
      last_verified_at: now,
      activity_requirement: 'recharge_ok',
      rule_source_url: 'https://www.friendimobile.om'
    },
    {
      carrier_id: renna.id,
      rule_type: 'prepaid',
      inactivity_limit_days: 180,
      grace_period_days: 30,
      minimum_topup_amount: 0.962,
      topup_validity_days: 180,
      recommended_topup_amount: 0.962,
      optimal_topup_window_start: null,
      optimal_topup_window_end: null,
      notes: 'TRA Oman: Renna Mobile prepaid vouchers (including 0.3 OMR micro-PIN) extend active validity for 180 days + 30 days suspension grace period.',
      last_verified_at: now,
      activity_requirement: 'recharge_ok',
      rule_source_url: 'https://rennamobile.com'
    },
    {
      carrier_id: redbull.id,
      rule_type: 'prepaid',
      inactivity_limit_days: 180,
      grace_period_days: 30,
      minimum_topup_amount: 0.959,
      topup_validity_days: 180,
      recommended_topup_amount: 0.959,
      optimal_topup_window_start: null,
      optimal_topup_window_end: null,
      notes: 'TRA Oman: Red Bull Mobile Oman recharge vouchers (including 0.3 OMR micro-PIN) extend active validity for 180 days + 30 days suspension grace period.',
      last_verified_at: now,
      activity_requirement: 'recharge_ok',
      rule_source_url: 'https://redbullmobile.om'
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
  console.log('SUPABASE OMAN PROVISIONING COMPLETED SUCCESSFULLY');
  console.log('====================================================');
}

syncOman().catch(console.error);
