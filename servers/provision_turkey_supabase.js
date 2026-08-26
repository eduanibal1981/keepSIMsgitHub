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
  console.log('=== PROVISIONING TURKEY IN SUPABASE ===');
  console.log('====================================================');

  // 1. Enable Country: Turkey
  console.log('\n1. Updating Turkey country record to is_supported: true...');
  const countryUpdate = await api('countries?iso_code=eq.TR', 'PATCH', {
    is_supported: true
  });
  console.log('Country updated:', countryUpdate);
  const trCountryId = countryUpdate[0]?.id || '438455df-0966-4641-807e-58e7e4b0b880';

  // 2. Fetch existing carriers
  const existingCarriers = await api(`carriers?country_id=eq.${trCountryId}`);
  console.log(`Found ${existingCarriers.length} existing carriers for Turkey:`, existingCarriers.map(c => c.name));

  const carrierMapByName = {};
  existingCarriers.forEach(c => {
    carrierMapByName[c.name.toLowerCase().trim()] = c;
  });

  const targetCarriers = [
    { name: 'Turkcell', default_refill_amount: 1.82 },
    { name: 'Vodafone Turkey', default_refill_amount: 2.52 },
    { name: 'Turk Telekom', default_refill_amount: 8.00 },
    { name: 'Bimcell', default_refill_amount: 8.00 },
    { name: 'Pttcell', default_refill_amount: 8.00 },
    { name: 'Vodafone Cyprus', default_refill_amount: 0.35 }
  ];

  for (const tc of targetCarriers) {
    const norm = tc.name.toLowerCase().trim();
    if (carrierMapByName[norm]) {
      console.log(`Updating existing carrier ${tc.name} (${carrierMapByName[norm].id})...`);
      const updated = await api(`carriers?id=eq.${carrierMapByName[norm].id}`, 'PATCH', {
        is_supported: true,
        country_id: trCountryId,
        default_refill_amount: tc.default_refill_amount,
        fulfillment_gateway: 'API'
      });
      carrierMapByName[norm] = updated[0];
    } else {
      console.log(`Inserting new carrier ${tc.name}...`);
      const inserted = await api('carriers', 'POST', {
        country_id: trCountryId,
        name: tc.name,
        is_supported: true,
        fulfillment_gateway: 'API',
        default_refill_amount: tc.default_refill_amount
      });
      carrierMapByName[norm] = inserted[0];
      console.log(`Inserted carrier ${tc.name}:`, inserted[0].id);
    }
  }

  const turkcellId = carrierMapByName['turkcell'].id;
  const vodafoneId = carrierMapByName['vodafone turkey'].id;
  const turkTelekomId = carrierMapByName['turk telekom'].id;
  const bimcellId = carrierMapByName['bimcell'].id;
  const pttcellId = carrierMapByName['pttcell'].id;
  const vfCyprusId = carrierMapByName['vodafone cyprus'].id;

  const allCarrierIds = [turkcellId, vodafoneId, turkTelekomId, bimcellId, pttcellId, vfCyprusId];

  // 3. Upsert carrier_rules
  console.log('\n3. Provisioning carrier_rules...');
  const rules = [
    {
      carrier_id: turkcellId,
      rule_type: 'prepaid',
      inactivity_limit_days: 180,
      grace_period_days: 365,
      minimum_topup_amount: 1.82,
      topup_validity_days: 180,
      recommended_topup_amount: 1.82,
      inapp_pricing: 2.50,
      inapp_pricing_currency: 'usd',
      offer_id: '509',
      activity_requirement: 'recharge_ok',
      notes: 'BTK Turkey: 180-day active period from last top-up, then 365-day passive period before line cancellation and recycling. Subject to 10% ÖİV and monthly Wireless Usage Fee (TKÜ).'
    },
    {
      carrier_id: vodafoneId,
      rule_type: 'prepaid',
      inactivity_limit_days: 180,
      grace_period_days: 90,
      minimum_topup_amount: 2.52,
      topup_validity_days: 180,
      recommended_topup_amount: 2.52,
      inapp_pricing: 3.20,
      inapp_pricing_currency: 'usd',
      offer_id: '1178',
      activity_requirement: 'recharge_ok',
      notes: 'BTK Turkey: 180-day active period from last top-up, followed by 90-day passive period (Dondurma Süreci) before permanent disconnection. Subject to 10% ÖİV and monthly TKÜ.'
    },
    {
      carrier_id: turkTelekomId,
      rule_type: 'prepaid',
      inactivity_limit_days: 184,
      grace_period_days: 92,
      minimum_topup_amount: 8.00,
      topup_validity_days: 184,
      recommended_topup_amount: 8.00,
      inapp_pricing: 9.50,
      inapp_pricing_currency: 'usd',
      offer_id: '48513',
      activity_requirement: 'recharge_ok',
      notes: 'BTK Turkey: 184-day active period from last top-up, followed by 92-day passive period (Kısıtlı Süreç / Total 276 days) before contract cancellation. Subject to 10% ÖİV and monthly TKÜ.'
    },
    {
      carrier_id: bimcellId,
      rule_type: 'prepaid',
      inactivity_limit_days: 184,
      grace_period_days: 92,
      minimum_topup_amount: 8.00,
      topup_validity_days: 184,
      recommended_topup_amount: 8.00,
      inapp_pricing: 9.50,
      inapp_pricing_currency: 'usd',
      offer_id: '48513',
      activity_requirement: 'recharge_ok',
      notes: 'BİMcell MVNO (Türk Telekom Core): 184-day active period + 92-day passive period. Accepts standard Türk Telekom airtime top-ups.'
    },
    {
      carrier_id: pttcellId,
      rule_type: 'prepaid',
      inactivity_limit_days: 184,
      grace_period_days: 92,
      minimum_topup_amount: 8.00,
      topup_validity_days: 184,
      recommended_topup_amount: 8.00,
      inapp_pricing: 9.50,
      inapp_pricing_currency: 'usd',
      offer_id: '48513',
      activity_requirement: 'recharge_ok',
      notes: 'Pttcell MVNO (Türk Telekom Core): 184-day active period + 92-day passive period. Accepts standard Türk Telekom airtime top-ups.'
    },
    {
      carrier_id: vfCyprusId,
      rule_type: 'prepaid',
      inactivity_limit_days: 180,
      grace_period_days: 90,
      minimum_topup_amount: 0.35,
      topup_validity_days: 180,
      recommended_topup_amount: 0.35,
      inapp_pricing: 1.00,
      inapp_pricing_currency: 'usd',
      offer_id: '11581',
      activity_requirement: 'recharge_ok',
      notes: 'Northern Cyprus Vodafone (KKTC Vodafone): 180-day active validity from recharge. Micro-recharges of 12 TRY (0.121 OMR) keep lines active.'
    }
  ];

  for (const r of rules) {
    const existing = await api(`carrier_rules?carrier_id=eq.${r.carrier_id}`);
    if (existing && existing.length > 0) {
      console.log(`Updating rule for carrier ${r.carrier_id}...`);
      await api(`carrier_rules?id=eq.${existing[0].id}`, 'PATCH', {
        ...r,
        updated_at: new Date().toISOString(),
        last_verified_at: new Date().toISOString()
      });
    } else {
      console.log(`Inserting new rule for carrier ${r.carrier_id}...`);
      await api('carrier_rules', 'POST', {
        ...r,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        last_verified_at: new Date().toISOString()
      });
    }
  }

  // 4. Reset is_primary = false on all existing carrier_provider_map entries for TR carriers
  console.log('\n4. Resetting is_primary = false on existing carrier_provider_map records...');
  await api(`carrier_provider_map?carrier_id=in.(${allCarrierIds.join(',')})`, 'PATCH', {
    is_primary: false
  });

  // 5. Upsert carrier_provider_map entries
  console.log('\n5. Provisioning carrier_provider_map entries...');

  const mappings = [
    // Turkcell
    { carrier_id: turkcellId, provider: 'reloadly', provider_country_code: 'TR', provider_carrier_code: '509', priority: 10, is_primary: true, is_enabled: true, provider_carrier_label: 'Turkcell Turkey (Airtime 65 TRY)', provider_country_label: 'Turkey' },
    { carrier_id: turkcellId, provider: 'dtone', provider_country_code: 'TUR', provider_carrier_code: '679', priority: 20, is_primary: false, is_enabled: true, provider_carrier_label: 'Turkcell Turkey (200 TRY)', provider_country_label: 'Turkey' },
    { carrier_id: turkcellId, provider: 'zendit', provider_country_code: 'TR', provider_carrier_code: 'Turkcell', priority: 30, is_primary: false, is_enabled: true, provider_carrier_label: 'Turkcell (TURKCELL_TR_10-I)', provider_country_label: 'Turkey' },
    { carrier_id: turkcellId, provider: 'ding', provider_country_code: 'TR', provider_carrier_code: 'TZTR', priority: 40, is_primary: false, is_enabled: false, provider_carrier_label: 'Turkcell Turkey', provider_country_label: 'Turkey' },

    // Vodafone Turkey
    { carrier_id: vodafoneId, provider: 'reloadly', provider_country_code: 'TR', provider_carrier_code: '1178', priority: 10, is_primary: true, is_enabled: true, provider_carrier_label: 'Vodafone Turkey Data (90 TRY)', provider_country_label: 'Turkey' },
    { carrier_id: vodafoneId, provider: 'zendit', provider_country_code: 'TR', provider_carrier_code: 'Vodafone', priority: 20, is_primary: false, is_enabled: true, provider_carrier_label: 'Vodafone Turkey (100 TRY)', provider_country_label: 'Turkey' },
    { carrier_id: vodafoneId, provider: 'dtone', provider_country_code: 'TUR', provider_carrier_code: '662', priority: 30, is_primary: false, is_enabled: true, provider_carrier_label: 'Vodafone Turkey (250 TRY)', provider_country_label: 'Turkey' },
    { carrier_id: vodafoneId, provider: 'ding', provider_country_code: 'TR', provider_carrier_code: 'VFTR', priority: 40, is_primary: false, is_enabled: false, provider_carrier_label: 'Vodafone Turkey', provider_country_label: 'Turkey' },

    // Türk Telekom
    { carrier_id: turkTelekomId, provider: 'dtone', provider_country_code: 'TUR', provider_carrier_code: '46', priority: 10, is_primary: true, is_enabled: true, provider_carrier_label: 'Turk Telecom Turkey (300 TRY)', provider_country_label: 'Turkey' },
    { carrier_id: turkTelekomId, provider: 'reloadly', provider_country_code: 'TR', provider_carrier_code: '510', priority: 20, is_primary: false, is_enabled: true, provider_carrier_label: 'Turk Telecom Turkey (300 TRY)', provider_country_label: 'Turkey' },
    { carrier_id: turkTelekomId, provider: 'zendit', provider_country_code: 'TR', provider_carrier_code: 'TurkTelekom', priority: 30, is_primary: false, is_enabled: true, provider_carrier_label: 'TurkTelekom (300 TRY)', provider_country_label: 'Turkey' },
    { carrier_id: turkTelekomId, provider: 'ding', provider_country_code: 'TR', provider_carrier_code: 'AVTR', priority: 40, is_primary: false, is_enabled: false, provider_carrier_label: 'Avea (Turk Telekom) Turkey', provider_country_label: 'Turkey' },

    // Bimcell
    { carrier_id: bimcellId, provider: 'dtone', provider_country_code: 'TUR', provider_carrier_code: '46', priority: 10, is_primary: true, is_enabled: true, provider_carrier_label: 'Bimcell via Turk Telecom (300 TRY)', provider_country_label: 'Turkey' },
    { carrier_id: bimcellId, provider: 'reloadly', provider_country_code: 'TR', provider_carrier_code: '510', priority: 20, is_primary: false, is_enabled: true, provider_carrier_label: 'Bimcell via Turk Telecom', provider_country_label: 'Turkey' },
    { carrier_id: bimcellId, provider: 'zendit', provider_country_code: 'TR', provider_carrier_code: 'TurkTelekom', priority: 30, is_primary: false, is_enabled: true, provider_carrier_label: 'Bimcell via TurkTelekom', provider_country_label: 'Turkey' },
    { carrier_id: bimcellId, provider: 'ding', provider_country_code: 'TR', provider_carrier_code: 'AVTR', priority: 40, is_primary: false, is_enabled: false, provider_carrier_label: 'Avea Turkey (Bimcell)', provider_country_label: 'Turkey' },

    // Pttcell
    { carrier_id: pttcellId, provider: 'dtone', provider_country_code: 'TUR', provider_carrier_code: '46', priority: 10, is_primary: true, is_enabled: true, provider_carrier_label: 'Pttcell via Turk Telecom (300 TRY)', provider_country_label: 'Turkey' },
    { carrier_id: pttcellId, provider: 'reloadly', provider_country_code: 'TR', provider_carrier_code: '510', priority: 20, is_primary: false, is_enabled: true, provider_carrier_label: 'Pttcell via Turk Telecom', provider_country_label: 'Turkey' },
    { carrier_id: pttcellId, provider: 'zendit', provider_country_code: 'TR', provider_carrier_code: 'TurkTelekom', priority: 30, is_primary: false, is_enabled: true, provider_carrier_label: 'Pttcell via TurkTelekom', provider_country_label: 'Turkey' },
    { carrier_id: pttcellId, provider: 'ding', provider_country_code: 'TR', provider_carrier_code: 'AVTR', priority: 40, is_primary: false, is_enabled: false, provider_carrier_label: 'Avea Turkey (Pttcell)', provider_country_label: 'Turkey' },

    // Vodafone Cyprus
    { carrier_id: vfCyprusId, provider: 'dtone', provider_country_code: 'TUR', provider_carrier_code: '1931', priority: 10, is_primary: true, is_enabled: true, provider_carrier_label: 'Vodafone Cyprus Turkey (12 TRY)', provider_country_label: 'Turkey' },
    { carrier_id: vfCyprusId, provider: 'reloadly', provider_country_code: 'TR', provider_carrier_code: '511', priority: 20, is_primary: false, is_enabled: false, provider_carrier_label: 'Vodafone Cyprus Turkey', provider_country_label: 'Turkey' }
  ];

  for (const m of mappings) {
    const existing = await api(`carrier_provider_map?carrier_id=eq.${m.carrier_id}&provider=eq.${m.provider}`);
    if (existing && existing.length > 0) {
      console.log(`Updating mapping for ${m.provider} -> carrier ${m.carrier_id}...`);
      await api(`carrier_provider_map?id=eq.${existing[0].id}`, 'PATCH', {
        ...m,
        updated_at: new Date().toISOString(),
        last_verified_at: new Date().toISOString()
      });
    } else {
      console.log(`Inserting mapping for ${m.provider} -> carrier ${m.carrier_id}...`);
      await api('carrier_provider_map', 'POST', {
        ...m,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        last_verified_at: new Date().toISOString()
      });
    }
  }

  console.log('\n=== SUPABASE PROVISIONING COMPLETED SUCCESSFULLY ===');
}

main().catch(console.error);
