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

async function cleanAndSync() {
  console.log('=== CLEANING & PERFECTING PHILIPPINES SUPABASE RECORDS ===');
  const phCountryId = '1ce63c64-05fb-4b37-ad30-369c40896e58';

  // 1. Fetch current PH carriers
  const carriers = await querySupabase(`carriers?country_id=eq.${phCountryId}`);
  console.log('Current carriers:', carriers.map(c => ({ id: c.id, name: c.name })));

  // Canonical IDs to keep:
  // Globe: e1fddfc0-ebdd-4ff2-a1a0-47cbf86737f4
  // Smart: f259b40b-3d06-4fb2-b765-edb0d01df788
  // DITO: 0ca2d774-fca1-4d2f-845a-f38babee4adc
  // TM: dce6f8a2-bdf1-4e37-be40-7db94d97b4de
  // TNT: 8d3b02aa-f69b-4f06-ab39-c6edb703f875

  const duplicateIds = ['cceff85f-eb2a-4660-8ef4-ab3f67467365', 'c6b5fb34-dec9-4d92-9cdb-2980b534fead', 'a06749e8-d2ac-49df-9408-347715edb410'];
  for (const dupId of duplicateIds) {
    await querySupabase(`carrier_provider_map?carrier_id=eq.${dupId}`, { method: 'DELETE' });
    await querySupabase(`carrier_rules?carrier_id=eq.${dupId}`, { method: 'DELETE' });
    await querySupabase(`carriers?id=eq.${dupId}`, { method: 'DELETE' });
    console.log(`Deleted duplicate carrier ${dupId}`);
  }

  // Update canonical names
  await querySupabase(`carriers?id=eq.e1fddfc0-ebdd-4ff2-a1a0-47cbf86737f4`, {
    method: 'PATCH',
    body: JSON.stringify({ name: 'Globe Telecom', is_supported: true, default_refill_amount: 10 })
  });
  await querySupabase(`carriers?id=eq.f259b40b-3d06-4fb2-b765-edb0d01df788`, {
    method: 'PATCH',
    body: JSON.stringify({ name: 'Smart Communications', is_supported: true, default_refill_amount: 10 })
  });
  await querySupabase(`carriers?id=eq.0ca2d774-fca1-4d2f-845a-f38babee4adc`, {
    method: 'PATCH',
    body: JSON.stringify({ name: 'DITO Telecommunity', is_supported: true, default_refill_amount: 99 })
  });
  await querySupabase(`carriers?id=eq.dce6f8a2-bdf1-4e37-be40-7db94d97b4de`, {
    method: 'PATCH',
    body: JSON.stringify({ name: 'TM (Touch Mobile)', is_supported: true, default_refill_amount: 10 })
  });
  await querySupabase(`carriers?id=eq.8d3b02aa-f69b-4f06-ab39-c6edb703f875`, {
    method: 'PATCH',
    body: JSON.stringify({ name: "TNT (Talk 'N Text)", is_supported: true, default_refill_amount: 10 })
  });

  const globeId = 'e1fddfc0-ebdd-4ff2-a1a0-47cbf86737f4';
  const smartId = 'f259b40b-3d06-4fb2-b765-edb0d01df788';
  const ditoId = '0ca2d774-fca1-4d2f-845a-f38babee4adc';
  const tmId = 'dce6f8a2-bdf1-4e37-be40-7db94d97b4de';
  const tntId = '8d3b02aa-f69b-4f06-ab39-c6edb703f875';

  const carrierIds = [globeId, smartId, ditoId, tmId, tntId];

  // Clear is_primary before setting
  await querySupabase(`carrier_provider_map?carrier_id=in.(${carrierIds.join(',')})`, {
    method: 'PATCH',
    body: JSON.stringify({ is_primary: false })
  });

  // 2. Mappings
  const mappings = [
    // Globe Telecom
    { carrier_id: globeId, provider: 'dtone', provider_country_code: 'PHL', provider_carrier_code: '246', provider_carrier_label: 'Globe Telecom Philippines', provider_country_label: 'Philippines', is_enabled: true, is_primary: true, priority: 10, notes: 'DT One Primary: 22 products from 10 PHP (0.076 OMR / $0.198 USD)' },
    { carrier_id: globeId, provider: 'reloadly', provider_country_code: 'PH', provider_carrier_code: '371', provider_carrier_label: 'Globe Telecom Philippines', provider_country_label: 'Philippines', is_enabled: true, is_primary: false, priority: 20, notes: 'Reloadly Secondary: Fixed 10 PHP ($0.18 USD)' },
    { carrier_id: globeId, provider: 'zendit', provider_country_code: 'PH', provider_carrier_code: 'Globe', provider_carrier_label: 'Globe', provider_country_label: 'Philippines', is_enabled: true, is_primary: false, priority: 30, notes: 'Zendit Tertiary: 5 bundle/airtime offers from 400 PHP' },
    { carrier_id: globeId, provider: 'ding', provider_country_code: 'PH', provider_carrier_code: 'GBPH', provider_carrier_label: 'BS_Globe Philippines', provider_country_label: 'Philippines', is_enabled: false, is_primary: false, priority: 40, notes: 'DingConnect: Disabled (0 inventory in UAT)' },

    // Smart Communications
    { carrier_id: smartId, provider: 'dtone', provider_country_code: 'PHL', provider_carrier_code: '570', provider_carrier_label: 'Smart Philippines', provider_country_label: 'Philippines', is_enabled: true, is_primary: true, priority: 10, notes: 'DT One Primary: 38 products from 5/10 PHP (0.074 OMR / $0.192 USD)' },
    { carrier_id: smartId, provider: 'reloadly', provider_country_code: 'PH', provider_carrier_code: '372', provider_carrier_label: 'Smart Philippines', provider_country_label: 'Philippines', is_enabled: true, is_primary: false, priority: 20, notes: 'Reloadly Secondary: Range 0.27-18.3 USD ($0.27 USD / 14.74 PHP)' },
    { carrier_id: smartId, provider: 'zendit', provider_country_code: 'PH', provider_carrier_code: 'Smart', provider_carrier_label: 'Smart', provider_country_label: 'Philippines', is_enabled: true, is_primary: false, priority: 30, notes: 'Zendit Tertiary: 5 bundle/airtime offers from 300 PHP' },
    { carrier_id: smartId, provider: 'ding', provider_country_code: 'PH', provider_carrier_code: 'SMPH', provider_carrier_label: 'Smart (SunCellular) Philippines', provider_country_label: 'Philippines', is_enabled: false, is_primary: false, priority: 40, notes: 'DingConnect: Disabled (0 inventory in UAT)' },

    // DITO Telecommunity
    { carrier_id: ditoId, provider: 'zendit', provider_country_code: 'PH', provider_carrier_code: 'Dito', provider_carrier_label: 'Dito', provider_country_label: 'Philippines', is_enabled: true, is_primary: true, priority: 10, notes: 'Zendit Exclusive Active Primary: 4 offers from 99 PHP ($1.69 USD)' },
    { carrier_id: ditoId, provider: 'reloadly', provider_country_code: 'PH', provider_carrier_code: '1182', provider_carrier_label: 'Dito Philippines', provider_country_label: 'Philippines', is_enabled: false, is_primary: false, priority: 20, notes: 'Reloadly: Disabled (inactivity in sandbox)' },
    { carrier_id: ditoId, provider: 'ding', provider_country_code: 'PH', provider_carrier_code: 'DWPH', provider_carrier_label: 'Dito Philippines', provider_country_label: 'Philippines', is_enabled: false, is_primary: false, priority: 30, notes: 'DingConnect: Disabled (0 inventory in UAT)' },

    // TM (Touch Mobile)
    { carrier_id: tmId, provider: 'dtone', provider_country_code: 'PHL', provider_carrier_code: '3128', provider_carrier_label: 'Touch Mobile Philippines', provider_country_label: 'Philippines', is_enabled: true, is_primary: true, priority: 10, notes: 'DT One Primary: 18 products from 10 PHP (0.076 OMR / $0.198 USD)' },
    { carrier_id: tmId, provider: 'reloadly', provider_country_code: 'PH', provider_carrier_code: '723', provider_carrier_label: 'Touch Mobile Philippines', provider_country_label: 'Philippines', is_enabled: true, is_primary: false, priority: 20, notes: 'Reloadly Secondary: Fixed 10 PHP ($0.18 USD)' },
    { carrier_id: tmId, provider: 'zendit', provider_country_code: 'PH', provider_carrier_code: 'TouchMobile', provider_carrier_label: 'TouchMobile', provider_country_label: 'Philippines', is_enabled: true, is_primary: false, priority: 30, notes: 'Zendit Tertiary: 10 offers from 150 PHP ($3.57 USD)' },
    { carrier_id: tmId, provider: 'ding', provider_country_code: 'PH', provider_carrier_code: 'TMPH', provider_carrier_label: 'Touch Mobile Philippines', provider_country_label: 'Philippines', is_enabled: false, is_primary: false, priority: 40, notes: 'DingConnect: Disabled (0 inventory in UAT)' },

    // TNT (Talk 'N Text)
    { carrier_id: tntId, provider: 'dtone', provider_country_code: 'PHL', provider_carrier_code: '2897', provider_carrier_label: 'TNT Philippines', provider_country_label: 'Philippines', is_enabled: true, is_primary: true, priority: 10, notes: 'DT One Primary: 39 products from 20 PHP (0.147 OMR / $0.382 USD)' },
    { carrier_id: tntId, provider: 'reloadly', provider_country_code: 'PH', provider_carrier_code: '378', provider_carrier_label: 'TNT Philippines', provider_country_label: 'Philippines', is_enabled: true, is_primary: false, priority: 20, notes: 'Reloadly Secondary: Range 0.18-18.3 USD / PIN' },
    { carrier_id: tntId, provider: 'zendit', provider_country_code: 'PH', provider_carrier_code: 'TNT', provider_carrier_label: 'TNT', provider_country_label: 'Philippines', is_enabled: true, is_primary: false, priority: 30, notes: 'Zendit Tertiary: 4 bundle offers from 318 PHP ($5.42 USD)' },
    { carrier_id: tntId, provider: 'ding', provider_country_code: 'PH', provider_carrier_code: 'STPH', provider_carrier_label: 'SmartTalk n Text Philippines', provider_country_label: 'Philippines', is_enabled: false, is_primary: false, priority: 40, notes: 'DingConnect: Disabled (0 inventory in UAT)' },
  ];

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
      console.log(`Updated map: [${m.provider_carrier_label}] -> ${m.provider}`);
    } else {
      await querySupabase('carrier_provider_map', {
        method: 'POST',
        body: JSON.stringify({
          ...m,
          last_verified_at: new Date().toISOString()
        })
      });
      console.log(`Inserted map: [${m.provider_carrier_label}] -> ${m.provider}`);
    }
  }

  // 3. Upsert Carrier Rules without invalid time syntax
  const now = new Date().toISOString();
  const rules = [
    {
      carrier_id: globeId,
      rule_type: 'prepaid',
      inactivity_limit_days: 365,
      grace_period_days: 120,
      minimum_topup_amount: 10,
      topup_validity_days: 365,
      recommended_topup_amount: 10,
      notes: 'NTC-DICT 1-Year Load Validity Rule (MC 05-12-2017). Globe Prepaid: all top-ups are valid for 365 days. If balance reaches zero with no load for 120 consecutive days, the SIM card is permanently deactivated.',
      last_verified_at: now,
      activity_requirement: 'recharge_ok',
      rule_source_url: 'https://www.globe.com.ph/help/prepaid/sim-validity'
    },
    {
      carrier_id: smartId,
      rule_type: 'prepaid',
      inactivity_limit_days: 365,
      grace_period_days: 180,
      minimum_topup_amount: 10,
      topup_validity_days: 365,
      recommended_topup_amount: 10,
      notes: 'NTC-DICT 1-Year Load Validity Rule (MC 05-12-2017). Smart Prepaid: all prepaid loads are valid for 365 days. Subscribers have a 180-day grace period after zero balance to reload before disconnection.',
      last_verified_at: now,
      activity_requirement: 'recharge_ok',
      rule_source_url: 'https://smart.com.ph/prepaid'
    },
    {
      carrier_id: ditoId,
      rule_type: 'prepaid',
      inactivity_limit_days: 365,
      grace_period_days: 90,
      minimum_topup_amount: 99,
      topup_validity_days: 365,
      recommended_topup_amount: 99,
      notes: 'DITO Telecommunity: 1-year load validity per NTC rule. DITO enforces a 90-day non-usage policy if balance is zero / below PHP 1.00 with no active promo pack.',
      last_verified_at: now,
      activity_requirement: 'recharge_ok',
      rule_source_url: 'https://dito.ph'
    },
    {
      carrier_id: tmId,
      rule_type: 'prepaid',
      inactivity_limit_days: 365,
      grace_period_days: 120,
      minimum_topup_amount: 10,
      topup_validity_days: 365,
      recommended_topup_amount: 10,
      notes: 'NTC-DICT 1-Year Load Validity Rule. TM (Touch Mobile) operates under Globe network policies: 365 days load validity, 120 days zero-balance deactivation window.',
      last_verified_at: now,
      activity_requirement: 'recharge_ok',
      rule_source_url: 'https://www.tmtambayan.ph'
    },
    {
      carrier_id: tntId,
      rule_type: 'prepaid',
      inactivity_limit_days: 365,
      grace_period_days: 180,
      minimum_topup_amount: 10,
      topup_validity_days: 365,
      recommended_topup_amount: 10,
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

  console.log('=== VERIFYING FINAL SUPABASE PH STATE ===');
  const finalCarriers = await querySupabase(`carriers?country_id=eq.${phCountryId}`);
  console.log(`Carriers in DB (${finalCarriers.length}):`, finalCarriers.map(c => ({ id: c.id, name: c.name })));
  const finalMaps = await querySupabase(`carrier_provider_map?carrier_id=in.(${carrierIds.join(',')})`);
  console.log(`Carrier Maps in DB (${finalMaps.length})`);
  const finalRules = await querySupabase(`carrier_rules?carrier_id=in.(${carrierIds.join(',')})`);
  console.log(`Carrier Rules in DB (${finalRules.length})`);
}

cleanAndSync().catch(console.error);
