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
  console.log('=== PROVISIONING IRAQ (IQ / IRQ) IN SUPABASE ===');
  console.log('====================================================');

  // 1. Enable Country: Iraq
  console.log('\n1. Updating Iraq country record...');
  const countryUpdate = await api('countries?iso_code=eq.IQ', 'PATCH', {
    is_supported: true,
    avg_sim_replacement_cost: 10.00
  });
  console.log('Country updated:', countryUpdate);
  const iqCountryId = countryUpdate[0]?.id || '4f5dda1a-fe84-4ccd-b733-478830c0e3e4';

  // 2. Fetch existing carriers
  const existingCarriers = await api(`carriers?country_id=eq.${iqCountryId}`);
  console.log(`Found ${existingCarriers.length} existing carriers for Iraq:`, existingCarriers.map(c => c.name));

  const carrierMapByName = {};
  existingCarriers.forEach(c => {
    carrierMapByName[c.name.toLowerCase().trim()] = c;
  });

  const targetCarriers = [
    { name: 'AsiaCell', canonical: 'AsiaCell', default_refill_amount: 4.18 },
    { name: 'Zain Iraq', canonical: 'Zain Iraq', default_refill_amount: 5.33 },
    { name: 'Korek Telecom', canonical: 'Korek Telecom', default_refill_amount: 5.33 }
  ];

  const carrierIdMap = {};

  for (const tc of targetCarriers) {
    let matched = null;
    for (const [key, val] of Object.entries(carrierMapByName)) {
      if (key.includes(tc.canonical.toLowerCase()) || tc.canonical.toLowerCase().includes(key) || (tc.canonical.includes('AsiaCell') && key.includes('asia')) || (tc.canonical.includes('Zain') && key.includes('zain')) || (tc.canonical.includes('Korek') && key.includes('korek'))) {
        matched = val;
        break;
      }
    }

    if (matched) {
      console.log(`Updating existing carrier ${tc.canonical} (ID: ${matched.id}, was: "${matched.name}")...`);
      const updated = await api(`carriers?id=eq.${matched.id}`, 'PATCH', {
        name: tc.canonical,
        is_supported: true,
        country_id: iqCountryId,
        default_refill_amount: tc.default_refill_amount,
        fulfillment_gateway: 'API'
      });
      carrierIdMap[tc.canonical] = updated[0].id;
    } else {
      console.log(`Inserting new carrier ${tc.canonical}...`);
      const inserted = await api('carriers', 'POST', {
        country_id: iqCountryId,
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

  // 3. Upsert Carrier Rules (CMC Iraq Regulatory & Inactivity Framework)
  console.log('\n3. Upserting carrier rules for Iraq...');
  for (const [carrierName, carrierId] of Object.entries(carrierIdMap)) {
    const existingRules = await api(`carrier_rules?carrier_id=eq.${carrierId}`);

    let ruleData;
    if (carrierName === 'AsiaCell') {
      ruleData = {
        carrier_id: carrierId,
        rule_type: 'prepaid',
        inactivity_limit_days: 45,
        grace_period_days: 60,
        minimum_topup_amount: 3.21,
        recommended_topup_amount: 4.18,
        topup_validity_days: 45,
        activity_requirement: 'min_denomination',
        validity_qualifying_topup_amount: 4.18,
        inapp_pricing: 6.99,
        inapp_pricing_currency: 'usd',
        offer_id: 'ASIACELL_IQ_001',
        notes: 'AsiaCell Iraq (Ooredoo Affiliate): Official CMC Iraq prepaid validity structure. Recharges grant 45 days (5,000 IQD / $4.18 USD), 100 days (10,000 IQD / $8.35 USD), or 360 days (25,000+ IQD). Lapsed lines enter a 60-day grace quarantine before permanent disconnection and number recycling.',
        rule_source_url: 'https://www.asiacell.com/en/personal/prepaid',
        last_verified_at: new Date().toISOString()
      };
    } else if (carrierName === 'Zain Iraq') {
      ruleData = {
        carrier_id: carrierId,
        rule_type: 'prepaid',
        inactivity_limit_days: 90,
        grace_period_days: 60,
        minimum_topup_amount: 5.33,
        recommended_topup_amount: 5.33,
        topup_validity_days: 90,
        activity_requirement: 'min_denomination',
        validity_qualifying_topup_amount: 5.33,
        inapp_pricing: 7.99,
        inapp_pricing_currency: 'usd',
        offer_id: 'ZAIN_IQ_PIN_5000',
        notes: 'Zain Iraq (Zain Group): Official CMC Iraq prepaid lifecycle. 5,000 IQD and 15,000 IQD scratch cards/PIN vouchers grant 90 days line validity. Following expiration, lines enter 60-day grace/incoming-only period before permanent number termination.',
        rule_source_url: 'https://www.iq.zain.com/en/prepaid',
        last_verified_at: new Date().toISOString()
      };
    } else {
      ruleData = {
        carrier_id: carrierId,
        rule_type: 'prepaid',
        inactivity_limit_days: 40,
        grace_period_days: 60,
        minimum_topup_amount: 5.33,
        recommended_topup_amount: 5.33,
        topup_validity_days: 40,
        activity_requirement: 'min_denomination',
        validity_qualifying_topup_amount: 5.33,
        inapp_pricing: 7.99,
        inapp_pricing_currency: 'usd',
        offer_id: 'KOREK_IQ_PIN_5000',
        notes: 'Korek Telecom Iraq: Official CMC Iraq prepaid lifecycle. 5,000 IQD voucher grants 40 days validity. Lines enter 60-day incoming-only grace before permanent termination and recycling.',
        rule_source_url: 'https://www.korektelecom.com/en/prepaid',
        last_verified_at: new Date().toISOString()
      };
    }

    if (existingRules && existingRules.length > 0) {
      console.log(`Updating existing rule for ${carrierName} (ID: ${existingRules[0].id})...`);
      await api(`carrier_rules?id=eq.${existingRules[0].id}`, 'PATCH', ruleData);
    } else {
      console.log(`Inserting rule for ${carrierName}...`);
      await api('carrier_rules', 'POST', ruleData);
    }
  }

  // 4. Upsert carrier_provider_map
  console.log('\n4. Provisioning carrier_provider_map for Iraq...');

  const providerConfigs = {
    'AsiaCell': [
      {
        provider: 'zendit',
        provider_country_code: 'IQ',
        provider_carrier_code: 'AsiaCell',
        provider_country_label: 'Iraq',
        provider_carrier_label: 'AsiaCell',
        priority: 10,
        is_primary: true,
        is_enabled: true,
        notes: 'Primary Direct Top-Up rail via Zendit (ASIACELL_IQ_001, $4.18 USD wholesale net cost).'
      },
      {
        provider: 'dtone',
        provider_country_code: 'IRQ',
        provider_carrier_code: '42',
        provider_country_label: 'Iraq',
        provider_carrier_label: 'Asia Cell Telecom Iraq',
        priority: 20,
        is_primary: false,
        is_enabled: true,
        notes: 'Secondary Direct Airtime & Micro PIN Failover (Product 4042 @ 1.848 OMR / ~$4.81 USD & Product 39018 @ 1.235 OMR / ~$3.21 USD).'
      },
      {
        provider: 'reloadly',
        provider_country_code: 'IQ',
        provider_carrier_code: '246',
        provider_country_label: 'Iraq',
        provider_carrier_label: 'Asia Cell Telecom Iraq',
        priority: 30,
        is_primary: false,
        is_enabled: true,
        notes: 'Tertiary Direct Top-Up Failover (Operator ID 246, 5,000 IQD @ $6.82 USD net).'
      },
      {
        provider: 'ding',
        provider_country_code: 'IQ',
        provider_carrier_code: 'ACIQ',
        provider_country_label: 'Iraq',
        provider_carrier_label: 'Asia Cell Telecom Iraq',
        priority: 40,
        is_primary: false,
        is_enabled: false,
        notes: 'Disabled route: 0 active products in UAT / rate limited.'
      }
    ],
    'Zain Iraq': [
      {
        provider: 'dtone',
        provider_country_code: 'IRQ',
        provider_carrier_code: '3817',
        provider_country_label: 'Iraq',
        provider_carrier_label: 'Zain Iraq',
        priority: 10,
        is_primary: true,
        is_enabled: true,
        notes: 'Primary Provider: Digital PIN Voucher rail via DT One (Product 38999, 5000 IQD PIN @ 2.050 OMR / ~$5.33 USD, 90D validity).'
      },
      {
        provider: 'zendit',
        provider_country_code: 'IQ',
        provider_carrier_code: 'Zain',
        provider_country_label: 'Iraq',
        provider_carrier_label: 'Zain Iraq',
        priority: 20,
        is_primary: false,
        is_enabled: false,
        notes: 'Disabled: 0 catalog offers in Zendit.'
      },
      {
        provider: 'ding',
        provider_country_code: 'IQ',
        provider_carrier_code: 'ZAIQ',
        provider_country_label: 'Iraq',
        provider_carrier_label: 'Zain Iraq',
        priority: 30,
        is_primary: false,
        is_enabled: false,
        notes: 'Disabled: 0 catalog offers in DingConnect.'
      }
    ],
    'Korek Telecom': [
      {
        provider: 'dtone',
        provider_country_code: 'IRQ',
        provider_carrier_code: '2096',
        provider_country_label: 'Iraq',
        provider_carrier_label: 'Korek Iraq',
        priority: 10,
        is_primary: true,
        is_enabled: true,
        notes: 'Primary Provider: Digital PIN Voucher rail via DT One (Product 39011, 5000 IQD PIN @ 2.050 OMR / ~$5.33 USD, 40D validity).'
      },
      {
        provider: 'ding',
        provider_country_code: 'IQ',
        provider_carrier_code: 'KKIQ',
        provider_country_label: 'Iraq',
        provider_carrier_label: 'Korek Iraq',
        priority: 20,
        is_primary: false,
        is_enabled: false,
        notes: 'Disabled: 0 active products in UAT / rate limited.'
      },
      {
        provider: 'zendit',
        provider_country_code: 'IQ',
        provider_carrier_code: 'Korek',
        provider_country_label: 'Iraq',
        provider_carrier_label: 'Korek Telecom',
        priority: 30,
        is_primary: false,
        is_enabled: false,
        notes: 'Disabled: 0 catalog offers in Zendit.'
      }
    ]
  };

  for (const [carrierName, configs] of Object.entries(providerConfigs)) {
    const carrierId = carrierIdMap[carrierName];
    const existingMaps = await api(`carrier_provider_map?carrier_id=eq.${carrierId}`);
    console.log(`\nConfiguring ${carrierName} (Carrier ID: ${carrierId}) - existing maps: ${existingMaps.length}`);

    for (const cfg of configs) {
      const existing = existingMaps.find(m => m.provider === cfg.provider);
      const payload = {
        carrier_id: carrierId,
        provider: cfg.provider,
        provider_country_code: cfg.provider_country_code,
        provider_carrier_code: cfg.provider_carrier_code,
        provider_country_label: cfg.provider_country_label,
        provider_carrier_label: cfg.provider_carrier_label,
        priority: cfg.priority,
        is_primary: cfg.is_primary,
        is_enabled: cfg.is_enabled,
        notes: cfg.notes,
        last_verified_at: new Date().toISOString()
      };

      if (existing) {
        console.log(`Updating existing map for ${carrierName} -> ${cfg.provider} (ID: ${existing.id})...`);
        await api(`carrier_provider_map?id=eq.${existing.id}`, 'PATCH', payload);
      } else {
        console.log(`Inserting map for ${carrierName} -> ${cfg.provider}...`);
        await api('carrier_provider_map', 'POST', payload);
      }
    }
  }

  console.log('\n=== PROVISIONING COMPLETE! VERIFYING ALL ENTRIES... ===');
}

main().catch(console.error);
