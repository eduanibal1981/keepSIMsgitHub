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
  console.log('=== PROVISIONING BAHRAIN (BH) IN SUPABASE ===');
  console.log('====================================================');

  // 1. Ensure Country is_supported = true
  console.log('\n1. Updating Bahrain country record...');
  const countryUpdate = await api('countries?iso_code=eq.BH', 'PATCH', {
    is_supported: true
  });
  console.log('Country updated:', countryUpdate);
  const countryId = countryUpdate[0]?.id;
  if (!countryId) throw new Error('Country BH not found');

  // 2. Carriers
  console.log('\n2. Updating Carriers for Bahrain...');
  const carriers = await api(`carriers?country_id=eq.${countryId}`);
  console.log('Existing carriers:', carriers.map(c => ({ id: c.id, name: c.name, is_supported: c.is_supported })));

  const carrierIdMap = {};
  for (const c of carriers) {
    const nameLower = c.name.toLowerCase();
    let canonical = c.name;
    let defaultRefill = 3.05;
    if (nameLower.includes('batelco')) {
      canonical = 'Batelco';
      defaultRefill = 3.05;
    } else if (nameLower.includes('zain')) {
      canonical = 'Zain Bahrain';
      defaultRefill = 1.55;
    } else if (nameLower.includes('stc') || nameLower.includes('viva')) {
      canonical = 'STC Bahrain';
      defaultRefill = 3.50;
    }

    const updated = await api(`carriers?id=eq.${c.id}`, 'PATCH', {
      name: canonical,
      is_supported: true,
      fulfillment_gateway: 'API',
      default_refill_amount: defaultRefill
    });
    console.log(`Updated carrier ${canonical} (ID: ${c.id}): is_supported = true, default_refill = ${defaultRefill}`);
    carrierIdMap[canonical] = c.id;
  }

  // 3. Carrier Rules (TRA Bahrain Framework)
  console.log('\n3. Upserting carrier rules for Bahrain...');
  const rulesConfig = [
    {
      carrier: 'Batelco',
      rule_type: 'prepaid',
      inactivity_limit_days: 90,
      grace_period_days: 90,
      minimum_topup_amount: 3.00,
      recommended_topup_amount: 3.05,
      topup_validity_days: 90,
      activity_requirement: 'recharge_ok',
      inapp_pricing: 4.99,
      inapp_pricing_currency: 'usd',
      offer_id: 'BATELCO_BH_001',
      notes: 'TRA Bahrain 90-day inactivity lifecycle. Batelco recharge vouchers extend line validity 90-365 days. 90-day incoming-only grace before deactivation. 10% VAT applies.',
      rule_source_url: 'https://www.batelco.com/prepaid/',
      last_verified_at: new Date().toISOString()
    },
    {
      carrier: 'Zain Bahrain',
      rule_type: 'prepaid',
      inactivity_limit_days: 90,
      grace_period_days: 90,
      minimum_topup_amount: 1.50,
      recommended_topup_amount: 1.55,
      topup_validity_days: 60,
      activity_requirement: 'recharge_ok',
      inapp_pricing: 2.99,
      inapp_pricing_currency: 'usd',
      offer_id: 'ZAIN_BH_001',
      notes: 'TRA Bahrain 90-day inactivity lifecycle. Zain direct airtime refills extend line validity 60-100 days. 90-day incoming-only grace before deactivation. 10% VAT applies.',
      rule_source_url: 'https://bahraineportal.com/en/zain-prepaid-packages/',
      last_verified_at: new Date().toISOString()
    },
    {
      carrier: 'STC Bahrain',
      rule_type: 'prepaid',
      inactivity_limit_days: 90,
      grace_period_days: 90,
      minimum_topup_amount: 3.00,
      recommended_topup_amount: 3.50,
      topup_validity_days: 60,
      activity_requirement: 'recharge_ok',
      inapp_pricing: 4.99,
      inapp_pricing_currency: 'usd',
      offer_id: 'STC_BH_001',
      notes: 'TRA Bahrain 90-day inactivity lifecycle. STC Bahrain prepaid validity vouchers extend line validity 30-90 days. 90-day grace before deactivation. 10% VAT applies.',
      rule_source_url: 'https://www.stc.com.bh/mobile/mobile-services-prepaid',
      last_verified_at: new Date().toISOString()
    }
  ];

  for (const rc of rulesConfig) {
    const carrierId = carrierIdMap[rc.carrier];
    if (!carrierId) continue;
    const existingRules = await api(`carrier_rules?carrier_id=eq.${carrierId}`);
    const ruleData = {
      carrier_id: carrierId,
      rule_type: rc.rule_type,
      inactivity_limit_days: rc.inactivity_limit_days,
      grace_period_days: rc.grace_period_days,
      minimum_topup_amount: rc.minimum_topup_amount,
      recommended_topup_amount: rc.recommended_topup_amount,
      topup_validity_days: rc.topup_validity_days,
      activity_requirement: rc.activity_requirement,
      inapp_pricing: rc.inapp_pricing,
      inapp_pricing_currency: rc.inapp_pricing_currency,
      offer_id: rc.offer_id,
      notes: rc.notes,
      rule_source_url: rc.rule_source_url,
      last_verified_at: rc.last_verified_at
    };

    if (existingRules && existingRules.length > 0) {
      console.log(`Updating rule for ${rc.carrier} (Rule ID: ${existingRules[0].id})...`);
      await api(`carrier_rules?id=eq.${existingRules[0].id}`, 'PATCH', ruleData);
    } else {
      console.log(`Inserting rule for ${rc.carrier}...`);
      await api('carrier_rules', 'POST', ruleData);
    }
  }

  // 4. Carrier Provider Maps
  console.log('\n4. Upserting carrier_provider_map entries...');

  const providerMaps = [
    // Batelco
    {
      carrier: 'Batelco',
      provider: 'reloadly',
      provider_country_code: 'BH',
      provider_carrier_code: '22',
      provider_country_label: 'Bahrain',
      provider_carrier_label: 'Batelco PIN Bahrain',
      is_enabled: true,
      is_primary: true,
      priority: 10,
      notes: 'Reloadly operator 22 Batelco PIN Bahrain. $3.05 USD Fixed amounts, 2% discount ($2.989 USD net). Verified Sandbox purchase.'
    },
    {
      carrier: 'Batelco',
      provider: 'dtone',
      provider_country_code: 'BHR',
      provider_carrier_code: '1828',
      provider_country_label: 'Bahrain',
      provider_carrier_label: 'Batelco PIN Bahrain',
      is_enabled: true,
      is_primary: false,
      priority: 20,
      notes: 'DT One operator 1828 Batelco PIN Bahrain, 10 fixed PIN denominations from 2.25 BHD (2.866 OMR). Verified pre-prod transaction.'
    },
    {
      carrier: 'Batelco',
      provider: 'ding',
      provider_country_code: 'BH',
      provider_carrier_code: 'BVBH',
      provider_country_label: 'Bahrain',
      provider_carrier_label: 'Batelco Bahrain',
      is_enabled: true,
      is_primary: false,
      priority: 30,
      notes: 'DingConnect provider BVBH Batelco Bahrain.'
    },
    {
      carrier: 'Batelco',
      provider: 'zendit',
      provider_country_code: 'BH',
      provider_carrier_code: 'Batelco',
      provider_country_label: 'Bahrain',
      provider_carrier_label: 'Batelco',
      is_enabled: false,
      is_primary: false,
      priority: 40,
      notes: 'Zendit 0 offers in BH catalog.'
    },

    // Zain Bahrain
    {
      carrier: 'Zain Bahrain',
      provider: 'reloadly',
      provider_country_code: 'BH',
      provider_carrier_code: '1165',
      provider_country_label: 'Bahrain',
      provider_carrier_label: 'Zain Bahrain',
      is_enabled: true,
      is_primary: true,
      priority: 10,
      notes: 'Reloadly operator 1165 Zain Bahrain. $1.55 USD micro direct topup (0.58 BHD). Verified Sandbox purchase.'
    },
    {
      carrier: 'Zain Bahrain',
      provider: 'dtone',
      provider_country_code: 'BHR',
      provider_carrier_code: '1829',
      provider_country_label: 'Bahrain',
      provider_carrier_label: 'Zain Bahrain',
      is_enabled: true,
      is_primary: false,
      priority: 20,
      notes: 'DT One operator 1829 Zain Bahrain, 20 direct recharge products from 1 BHD (1.274 OMR). Verified pre-prod transaction.'
    },
    {
      carrier: 'Zain Bahrain',
      provider: 'ding',
      provider_country_code: 'BH',
      provider_carrier_code: 'ZABH',
      provider_country_label: 'Bahrain',
      provider_carrier_label: 'Zain Bahrain',
      is_enabled: true,
      is_primary: false,
      priority: 30,
      notes: 'DingConnect provider ZABH Zain Bahrain.'
    },
    {
      carrier: 'Zain Bahrain',
      provider: 'zendit',
      provider_country_code: 'BH',
      provider_carrier_code: 'Zain',
      provider_country_label: 'Bahrain',
      provider_carrier_label: 'Zain',
      is_enabled: false,
      is_primary: false,
      priority: 40,
      notes: 'Zendit 0 offers in BH catalog.'
    },

    // STC Bahrain (Zendit entry)
    {
      carrier: 'STC Bahrain',
      provider: 'zendit',
      provider_country_code: 'BH',
      provider_carrier_code: 'STC',
      provider_country_label: 'Bahrain',
      provider_carrier_label: 'STC Bahrain',
      is_enabled: false,
      is_primary: false,
      priority: 40,
      notes: 'Zendit 0 catalog items in BH.'
    }
  ];

  for (const pm of providerMaps) {
    const carrierId = carrierIdMap[pm.carrier];
    if (!carrierId) continue;

    const existingMap = await api(`carrier_provider_map?carrier_id=eq.${carrierId}&provider=eq.${pm.provider}`);
    const mapData = {
      carrier_id: carrierId,
      provider: pm.provider,
      provider_country_code: pm.provider_country_code,
      provider_carrier_code: pm.provider_carrier_code,
      provider_country_label: pm.provider_country_label,
      provider_carrier_label: pm.provider_carrier_label,
      is_enabled: pm.is_enabled,
      is_primary: pm.is_primary,
      priority: pm.priority,
      notes: pm.notes,
      last_verified_at: new Date().toISOString()
    };

    if (existingMap && existingMap.length > 0) {
      console.log(`Updating map for ${pm.carrier} -> ${pm.provider} (ID: ${existingMap[0].id})...`);
      await api(`carrier_provider_map?id=eq.${existingMap[0].id}`, 'PATCH', mapData);
    } else {
      console.log(`Inserting map for ${pm.carrier} -> ${pm.provider}...`);
      await api('carrier_provider_map', 'POST', mapData);
    }
  }

  console.log('\n====================================================');
  console.log('=== BAHRAIN PROVISIONING COMPLETE ===');
  console.log('====================================================');
}

main().catch(err => {
  console.error('Provisioning failed:', err);
  process.exit(1);
});
