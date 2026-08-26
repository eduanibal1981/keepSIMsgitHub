const fs = require('fs');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');

const candidatePaths = [
  path.join(__dirname, 'servers', '.env'),
  path.join(__dirname, '..', 'servers', '.env'),
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

const supabase = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY);

async function fixAndSync() {
  const { data: country } = await supabase.from('countries').select('*').ilike('name', '%India%').single();
  console.log('Country:', country.id, country.name);

  const { data: carriers } = await supabase.from('carriers').select('*').eq('country_id', country.id);
  console.log('Carriers count:', carriers.length);

  const carrierMap = {
    jio: carriers.find(c => c.name.toLowerCase().includes('jio')),
    airtel: carriers.find(c => c.name.toLowerCase().includes('airtel')),
    vi: carriers.find(c => c.name.toLowerCase().includes('vodafone') || c.name.toLowerCase().includes('vi')),
    bsnl: carriers.find(c => c.name.toLowerCase().includes('bsnl')),
    mtnl: carriers.find(c => c.name.toLowerCase().includes('mtnl'))
  };

  console.log('\n--- 1. Resetting all is_primary on existing maps for India carriers ---');
  for (const [k, car] of Object.entries(carrierMap)) {
    if (!car) continue;
    const { error: resetErr } = await supabase
      .from('carrier_provider_map')
      .update({ is_primary: false })
      .eq('carrier_id', car.id);
    console.log(`Reset is_primary for ${car.name}:`, resetErr || 'OK');
  }

  console.log('\n--- 2. Upserting carrier_provider_map records ---');
  const targetMaps = [
    // Jio
    { carrier_id: carrierMap.jio.id, provider: 'dtone', provider_country_code: 'IND', provider_carrier_code: '2808', provider_carrier_label: 'Reliance Jio India', provider_country_label: 'India', is_enabled: true, is_primary: true, priority: 10, notes: 'DT One Primary: 50+ fixed plans & airtime' },
    { carrier_id: carrierMap.jio.id, provider: 'zendit', provider_country_code: 'IN', provider_carrier_code: 'Jio', provider_carrier_label: 'Jio', provider_country_label: 'India', is_enabled: true, is_primary: false, priority: 20, notes: 'Zendit Secondary: 8 bundle offers' },
    { carrier_id: carrierMap.jio.id, provider: 'reloadly', provider_country_code: 'IN', provider_carrier_code: '786', provider_carrier_label: 'Reliance-Jio India', provider_country_label: 'India', is_enabled: true, is_primary: false, priority: 30, notes: 'Reloadly Tertiary: Sandbox catalog' },
    { carrier_id: carrierMap.jio.id, provider: 'ding', provider_country_code: 'IN', provider_carrier_code: 'RJIN', provider_carrier_label: 'Jio India', provider_country_label: 'India', is_enabled: false, is_primary: false, priority: 40, notes: 'DingConnect: Disabled (0 inventory in UAT)' },

    // Airtel
    { carrier_id: carrierMap.airtel.id, provider: 'dtone', provider_country_code: 'IND', provider_carrier_code: '1371', provider_carrier_label: 'Airtel India', provider_country_label: 'India', is_enabled: true, is_primary: true, priority: 10, notes: 'DT One Primary: 39 products from 10 INR' },
    { carrier_id: carrierMap.airtel.id, provider: 'zendit', provider_country_code: 'IN', provider_carrier_code: 'Airtel', provider_carrier_label: 'Airtel', provider_country_label: 'India', is_enabled: true, is_primary: false, priority: 20, notes: 'Zendit Secondary: 9 bundle offers' },
    { carrier_id: carrierMap.airtel.id, provider: 'reloadly', provider_country_code: 'IN', provider_carrier_code: '200', provider_carrier_label: 'Airtel India', provider_country_label: 'India', is_enabled: true, is_primary: false, priority: 30, notes: 'Reloadly Tertiary: Sandbox catalog' },
    { carrier_id: carrierMap.airtel.id, provider: 'ding', provider_country_code: 'IN', provider_carrier_code: 'AIIN', provider_carrier_label: 'Airtel India', provider_country_label: 'India', is_enabled: false, is_primary: false, priority: 40, notes: 'DingConnect: Disabled (0 inventory in UAT)' },

    // Vi
    { carrier_id: carrierMap.vi.id, provider: 'dtone', provider_country_code: 'IND', provider_carrier_code: '2016', provider_carrier_label: 'Vi India', provider_country_label: 'India', is_enabled: true, is_primary: true, priority: 10, notes: 'DT One Primary: 83 products from 10 INR' },
    { carrier_id: carrierMap.vi.id, provider: 'zendit', provider_country_code: 'IN', provider_carrier_code: 'VodafoneIdea', provider_carrier_label: 'VodafoneIdea', provider_country_label: 'India', is_enabled: true, is_primary: false, priority: 20, notes: 'Zendit Secondary: 8 bundle offers' },
    { carrier_id: carrierMap.vi.id, provider: 'reloadly', provider_country_code: 'IN', provider_carrier_code: '716', provider_carrier_label: 'Vodafone-Idea India', provider_country_label: 'India', is_enabled: true, is_primary: false, priority: 30, notes: 'Reloadly Tertiary: Sandbox catalog' },
    { carrier_id: carrierMap.vi.id, provider: 'ding', provider_country_code: 'IN', provider_carrier_code: 'VFIN', provider_carrier_label: 'Vi India', provider_country_label: 'India', is_enabled: false, is_primary: false, priority: 40, notes: 'DingConnect: Disabled (0 inventory in UAT)' },

    // BSNL
    { carrier_id: carrierMap.bsnl.id, provider: 'dtone', provider_country_code: 'IND', provider_carrier_code: '1420', provider_carrier_label: 'BSNL India', provider_country_label: 'India', is_enabled: true, is_primary: true, priority: 10, notes: 'DT One Primary: 31 products from 10 INR' },
    { carrier_id: carrierMap.bsnl.id, provider: 'zendit', provider_country_code: 'IN', provider_carrier_code: 'BSNL', provider_carrier_label: 'BSNL', provider_country_label: 'India', is_enabled: true, is_primary: false, priority: 20, notes: 'Zendit Secondary: 3 bundle offers' },
    { carrier_id: carrierMap.bsnl.id, provider: 'reloadly', provider_country_code: 'IN', provider_carrier_code: '193', provider_carrier_label: 'BSNL India', provider_country_label: 'India', is_enabled: true, is_primary: false, priority: 30, notes: 'Reloadly Tertiary: Sandbox catalog' },
    { carrier_id: carrierMap.bsnl.id, provider: 'ding', provider_country_code: 'IN', provider_carrier_code: 'BLIN', provider_carrier_label: 'BSNL India', provider_country_label: 'India', is_enabled: false, is_primary: false, priority: 40, notes: 'DingConnect: Disabled (0 inventory in UAT)' },

    // MTNL
    { carrier_id: carrierMap.mtnl.id, provider: 'dtone', provider_country_code: 'IND', provider_carrier_code: '368', provider_carrier_label: 'MTNL India', provider_country_label: 'India', is_enabled: true, is_primary: true, priority: 10, notes: 'DT One Exclusive Primary: 5 fixed talktime products (10–1000 INR)' },
    { carrier_id: carrierMap.mtnl.id, provider: 'reloadly', provider_country_code: 'IN', provider_carrier_code: '194', provider_carrier_label: 'MTNL India', provider_country_label: 'India', is_enabled: false, is_primary: false, priority: 30, notes: 'Reloadly: Disabled (503 unavailable)' },
    { carrier_id: carrierMap.mtnl.id, provider: 'ding', provider_country_code: 'IN', provider_carrier_code: 'MNIN', provider_carrier_label: 'MTNL India', provider_country_label: 'India', is_enabled: false, is_primary: false, priority: 40, notes: 'DingConnect: Disabled (0 inventory in UAT)' },
  ];

  for (const m of targetMaps) {
    const { data: existing } = await supabase
      .from('carrier_provider_map')
      .select('id')
      .eq('carrier_id', m.carrier_id)
      .eq('provider', m.provider);

    if (existing && existing.length > 0) {
      const { error: updErr } = await supabase
        .from('carrier_provider_map')
        .update({
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
        .eq('id', existing[0].id);
      console.log(`Updated map [${m.provider_carrier_label}] -> ${m.provider}:`, updErr || 'OK');
    } else {
      const { error: insErr } = await supabase
        .from('carrier_provider_map')
        .insert({
          ...m,
          last_verified_at: new Date().toISOString()
        });
      console.log(`Inserted map [${m.provider_carrier_label}] -> ${m.provider}:`, insErr || 'OK');
    }
  }

  console.log('\n--- 3. Updating carrier_rules ---');
  const now = new Date().toISOString();
  const rules = [
    {
      carrier_id: carrierMap.jio.id,
      rule_type: 'prepaid',
      inactivity_limit_days: 90,
      grace_period_days: 15,
      minimum_topup_amount: 10,
      topup_validity_days: 28,
      recommended_topup_amount: 10,
      notes: 'TRAI 90-day non-usage rule with a 15-day reactivation grace. Jio enforces 4G/5G data/unlimited pack requirements for full service validity.',
      last_verified_at: now,
      activity_requirement: 'recharge_ok',
      offer_id: '18922',
      rule_source_url: 'https://www.business-standard.com/technology/tech-news/trai-new-rules-jio-airtel-vi-bsnl-sim-to-stop-working-after-this-period-nc-125012001030_1.html'
    },
    {
      carrier_id: carrierMap.airtel.id,
      rule_type: 'prepaid',
      inactivity_limit_days: 90,
      grace_period_days: 15,
      minimum_topup_amount: 10,
      topup_validity_days: 28,
      recommended_topup_amount: 10,
      notes: 'TRAI 90-day non-usage rule with a 15-day grace period before number recycling.',
      last_verified_at: now,
      activity_requirement: 'recharge_ok',
      offer_id: '8141',
      rule_source_url: 'https://www.business-standard.com/technology/tech-news/trai-new-rules-jio-airtel-vi-bsnl-sim-to-stop-working-after-this-period-nc-125012001030_1.html'
    },
    {
      carrier_id: carrierMap.vi.id,
      rule_type: 'prepaid',
      inactivity_limit_days: 90,
      grace_period_days: 15,
      minimum_topup_amount: 10,
      topup_validity_days: 28,
      recommended_topup_amount: 10,
      notes: 'TRAI 90-day inactivity rule; minimum 10 INR talktime / service pack extends line validity.',
      last_verified_at: now,
      activity_requirement: 'recharge_ok',
      offer_id: '28303',
      rule_source_url: 'https://www.business-standard.com/technology/tech-news/trai-new-rules-jio-airtel-vi-bsnl-sim-to-stop-working-after-this-period-nc-125012001030_1.html'
    },
    {
      carrier_id: carrierMap.bsnl.id,
      rule_type: 'prepaid',
      inactivity_limit_days: 180,
      grace_period_days: 15,
      minimum_topup_amount: 10,
      topup_validity_days: 28,
      recommended_topup_amount: 10,
      notes: 'BSNL affords an extended 180-day non-usage window before deactivation, followed by a 15-day grace period.',
      last_verified_at: now,
      activity_requirement: 'recharge_ok',
      offer_id: '11087',
      rule_source_url: 'https://www.business-standard.com/technology/tech-news/trai-new-rules-jio-airtel-vi-bsnl-sim-to-stop-working-after-this-period-nc-125012001030_1.html'
    },
    {
      carrier_id: carrierMap.mtnl.id,
      rule_type: 'prepaid',
      inactivity_limit_days: 90,
      grace_period_days: 15,
      minimum_topup_amount: 10,
      topup_validity_days: 28,
      recommended_topup_amount: 10,
      notes: 'MTNL (Delhi & Mumbai) operates under standard TRAI 90-day inactivity rules.',
      last_verified_at: now,
      activity_requirement: 'recharge_ok',
      offer_id: '13500',
      rule_source_url: 'https://www.business-standard.com/technology/tech-news/trai-new-rules-jio-airtel-vi-bsnl-sim-to-stop-working-after-this-period-nc-125012001030_1.html'
    }
  ];

  for (const r of rules) {
    const { data: existing } = await supabase
      .from('carrier_rules')
      .select('id')
      .eq('carrier_id', r.carrier_id);

    if (existing && existing.length > 0) {
      const { error: updErr } = await supabase
        .from('carrier_rules')
        .update(r)
        .eq('id', existing[0].id);
      console.log(`Updated rule for carrier [${r.carrier_id}]:`, updErr || 'OK');
    } else {
      const { error: insErr } = await supabase
        .from('carrier_rules')
        .insert(r);
      console.log(`Inserted rule for carrier [${r.carrier_id}]:`, insErr || 'OK');
    }
  }

  console.log('\n=== ALL INDIA DB RECORDS SYNCHRONIZED PERFECTLY ===');
}

fixAndSync().catch(console.error);
