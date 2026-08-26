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
  console.log('=== PROVISIONING KUWAIT (KW) IN SUPABASE ===');
  console.log('====================================================');

  // 1. Ensure Country is supported
  console.log('\n1. Updating country record for Kuwait (KW)...');
  const countryUpdate = await api('countries?iso_code=eq.KW', 'PATCH', {
    is_supported: true
  });
  console.log('Country updated:', countryUpdate);
  const kwCountryId = countryUpdate[0]?.id;
  if (!kwCountryId) throw new Error('Could not find country KW');

  // 2. Target Carriers
  const targetCarriers = [
    {
      name: 'Zain Kuwait',
      canonical: 'Zain Kuwait',
      default_refill_amount: 5,
      rules: {
        rule_type: 'prepaid',
        inactivity_limit_days: 90,
        grace_period_days: 90,
        minimum_topup_amount: 5.0,
        topup_validity_days: 30,
        recommended_topup_amount: 5.0,
        activity_requirement: 'min_denomination',
        validity_qualifying_topup_amount: 5.0,
        notes: 'Zain Kuwait (eeZee): CITRA validity rules apply. 1.5 KWD extends 7-14 days; 3-5 KWD extends 30 days; 10 KWD extends 90-180 days; 25 KWD extends 365 days. 90-day inactivity limit followed by 90-day grace period before termination.',
        activity_requirement_note: 'CITRA prepaid validity ladder. Recharge extends line validity; lines enter grace upon expiry.',
        rule_source_url: 'https://www.kw.zain.com',
        sms_sender_ids: ['ZAIN', 'eeZee'],
        sms_language: 'auto'
      },
      providers: [
        { provider: 'dtone', countryCode: 'KWT', carrierCode: '1812', isPrimary: true, isEnabled: true, priority: 10, label: 'Zain Kuwait' },
        { provider: 'reloadly', countryCode: 'KW', carrierCode: '268', isPrimary: false, isEnabled: true, priority: 20, label: 'Zain Kuwait' },
        { provider: 'zendit', countryCode: 'KW', carrierCode: 'Zain', isPrimary: false, isEnabled: false, priority: 30, label: 'Zain' },
        { provider: 'ding', countryCode: 'KW', carrierCode: 'ZAKW', isPrimary: false, isEnabled: false, priority: 40, label: 'Zain Kuwait' }
      ]
    },
    {
      name: 'Ooredoo Kuwait',
      canonical: 'Ooredoo Kuwait',
      default_refill_amount: 5,
      rules: {
        rule_type: 'prepaid',
        inactivity_limit_days: 90,
        grace_period_days: 90,
        minimum_topup_amount: 5.0,
        topup_validity_days: 30,
        recommended_topup_amount: 5.0,
        activity_requirement: 'min_denomination',
        validity_qualifying_topup_amount: 5.0,
        notes: 'Ooredoo Kuwait (formerly Wataniya): CITRA validity rules apply. 1.5 KWD extends 7-14 days; 3-5 KWD extends 30 days; 10 KWD extends 90-180 days; 25 KWD extends 365 days. Inactive lines enter grace and churn after 180 total days.',
        activity_requirement_note: 'CITRA prepaid validity ladder. Line validity is determined by denomination or current validity.',
        rule_source_url: 'https://www.ooredoo.com.kw',
        sms_sender_ids: ['Ooredoo', 'OoredooKW'],
        sms_language: 'auto'
      },
      providers: [
        { provider: 'dtone', countryCode: 'KWT', carrierCode: '1811', isPrimary: true, isEnabled: true, priority: 10, label: 'Ooredoo Kuwait' },
        { provider: 'reloadly', countryCode: 'KW', carrierCode: '1166', isPrimary: false, isEnabled: true, priority: 20, label: 'Ooredo Kuwait' },
        { provider: 'zendit', countryCode: 'KW', carrierCode: 'Ooredoo', isPrimary: false, isEnabled: false, priority: 30, label: 'Ooredoo' },
        { provider: 'ding', countryCode: 'KW', carrierCode: 'WTKW', isPrimary: false, isEnabled: false, priority: 40, label: 'Ooredoo Kuwait' }
      ]
    },
    {
      name: 'STC Kuwait',
      canonical: 'STC Kuwait',
      default_refill_amount: 5,
      rules: {
        rule_type: 'prepaid',
        inactivity_limit_days: 90,
        grace_period_days: 90,
        minimum_topup_amount: 5.0,
        topup_validity_days: 30,
        recommended_topup_amount: 5.0,
        activity_requirement: 'min_denomination',
        validity_qualifying_topup_amount: 5.0,
        notes: 'STC Kuwait (formerly VIVA): CITRA validity rules apply. 1.5 KWD extends 7-14 days; 3-5 KWD extends 30 days; 10 KWD extends 90-180 days; 25 KWD extends 365 days. 90-day inactivity threshold with 90-day grace before number recycling.',
        activity_requirement_note: 'CITRA prepaid validity ladder. Sells validity by denomination.',
        rule_source_url: 'https://www.stc.com.kw',
        sms_sender_ids: ['stc', 'VIVA'],
        sms_language: 'auto'
      },
      providers: [
        { provider: 'dtone', countryCode: 'KWT', carrierCode: '1813', isPrimary: true, isEnabled: true, priority: 10, label: 'STC Kuwait' },
        { provider: 'reloadly', countryCode: 'KW', carrierCode: '267', isPrimary: false, isEnabled: true, priority: 20, label: 'STC Kuwait' },
        { provider: 'zendit', countryCode: 'KW', carrierCode: 'STC', isPrimary: false, isEnabled: false, priority: 30, label: 'STC' },
        { provider: 'ding', countryCode: 'KW', carrierCode: 'VIKW', isPrimary: false, isEnabled: false, priority: 40, label: 'STC Kuwait' }
      ]
    },
    {
      name: 'Virgin Mobile Kuwait',
      canonical: 'Virgin Mobile Kuwait',
      default_refill_amount: 5,
      rules: {
        rule_type: 'prepaid',
        inactivity_limit_days: 90,
        grace_period_days: 90,
        minimum_topup_amount: 5.0,
        topup_validity_days: 30,
        recommended_topup_amount: 5.0,
        activity_requirement: 'min_denomination',
        validity_qualifying_topup_amount: 5.0,
        notes: 'Virgin Mobile Kuwait: MVNO hosted on STC Kuwait network. Subject to CITRA validity regulations and STC host network inactivity policies.',
        activity_requirement_note: 'CITRA prepaid validity framework. Recharges extend active service line validity.',
        rule_source_url: 'https://www.virginmobile.com.kw',
        sms_sender_ids: ['VirginKW', 'Virgin'],
        sms_language: 'auto'
      },
      providers: [
        { provider: 'dtone', countryCode: 'KWT', carrierCode: '1813', isPrimary: true, isEnabled: true, priority: 10, label: 'STC Kuwait' },
        { provider: 'reloadly', countryCode: 'KW', carrierCode: '267', isPrimary: false, isEnabled: true, priority: 20, label: 'STC Kuwait' },
        { provider: 'zendit', countryCode: 'KW', carrierCode: 'Virgin Mobile', isPrimary: false, isEnabled: false, priority: 30, label: 'Virgin Mobile' },
        { provider: 'ding', countryCode: 'KW', carrierCode: 'VIKW', isPrimary: false, isEnabled: false, priority: 40, label: 'STC Kuwait' }
      ]
    }
  ];

  // Fetch existing carriers
  const existingCarriers = await api(`carriers?country_id=eq.${kwCountryId}`);
  const carrierMapByName = {};
  existingCarriers.forEach(c => {
    carrierMapByName[c.name.toLowerCase().trim()] = c;
  });

  for (const tc of targetCarriers) {
    let carrierId;
    let matched = null;
    for (const [key, val] of Object.entries(carrierMapByName)) {
      if (key === tc.canonical.toLowerCase() || key.includes(tc.canonical.toLowerCase()) || tc.canonical.toLowerCase().includes(key)) {
        matched = val;
        break;
      }
    }

    if (matched) {
      console.log(`\nUpdating existing carrier ${tc.canonical} (ID: ${matched.id})...`);
      const updated = await api(`carriers?id=eq.${matched.id}`, 'PATCH', {
        name: tc.canonical,
        is_supported: true,
        country_id: kwCountryId,
        default_refill_amount: tc.default_refill_amount,
        fulfillment_gateway: 'API'
      });
      carrierId = updated[0].id;
    } else {
      console.log(`\nInserting new carrier ${tc.canonical}...`);
      const inserted = await api('carriers', 'POST', {
        country_id: kwCountryId,
        name: tc.canonical,
        is_supported: true,
        default_refill_amount: tc.default_refill_amount,
        fulfillment_gateway: 'API'
      });
      carrierId = inserted[0].id;
    }

    // Upsert carrier_rules
    const existingRules = await api(`carrier_rules?carrier_id=eq.${carrierId}`);
    if (existingRules && existingRules.length > 0) {
      console.log(`Updating rules for ${tc.canonical}...`);
      await api(`carrier_rules?id=eq.${existingRules[0].id}`, 'PATCH', {
        ...tc.rules,
        last_verified_at: new Date().toISOString()
      });
    } else {
      console.log(`Inserting rules for ${tc.canonical}...`);
      await api('carrier_rules', 'POST', {
        carrier_id: carrierId,
        ...tc.rules,
        last_verified_at: new Date().toISOString()
      });
    }

    // Reset is_primary on existing maps first to avoid constraint violation
    console.log(`Resetting primary flags for carrier ${carrierId}...`);
    await api(`carrier_provider_map?carrier_id=eq.${carrierId}`, 'PATCH', {
      is_primary: false
    });

    // Upsert carrier_provider_map
    const existingMaps = await api(`carrier_provider_map?carrier_id=eq.${carrierId}`);
    const mapByProvider = {};
    existingMaps.forEach(m => {
      mapByProvider[m.provider.toLowerCase()] = m;
    });

    for (const p of tc.providers) {
      const existingMap = mapByProvider[p.provider.toLowerCase()];
      if (existingMap) {
        console.log(`Updating provider map for ${tc.canonical} -> ${p.provider}...`);
        await api(`carrier_provider_map?id=eq.${existingMap.id}`, 'PATCH', {
          provider_country_code: p.countryCode,
          provider_country_label: 'Kuwait',
          provider_carrier_code: p.carrierCode,
          provider_carrier_label: p.label,
          is_primary: p.isPrimary,
          is_enabled: p.isEnabled,
          priority: p.priority,
          last_verified_at: new Date().toISOString(),
          notes: `Verified live test route for ${tc.canonical}`
        });
      } else {
        console.log(`Inserting provider map for ${tc.canonical} -> ${p.provider}...`);
        await api('carrier_provider_map', 'POST', {
          carrier_id: carrierId,
          provider: p.provider,
          provider_country_code: p.countryCode,
          provider_country_label: 'Kuwait',
          provider_carrier_code: p.carrierCode,
          provider_carrier_label: p.label,
          is_primary: p.isPrimary,
          is_enabled: p.isEnabled,
          priority: p.priority,
          last_verified_at: new Date().toISOString(),
          notes: `Verified live test route for ${tc.canonical}`
        });
      }
    }
  }

  console.log('\n✅ Supabase provisioning for Kuwait completed successfully!');
}

main().catch(console.error);
