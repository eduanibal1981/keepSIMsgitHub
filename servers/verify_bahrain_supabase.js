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

async function api(endpoint) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${endpoint}`, {
    headers: {
      'apikey': SUPABASE_KEY,
      'Authorization': `Bearer ${SUPABASE_KEY}`,
      'Content-Type': 'application/json'
    }
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`API error ${res.status}: ${text}`);
  }
  return await res.json();
}

async function main() {
  console.log('====================================================');
  console.log('=== VERIFYING SUPABASE STATE FOR BAHRAIN (BH) ===');
  console.log('====================================================');

  const countries = await api('countries?iso_code=eq.BH&select=*');
  console.log('\n--- Country ---');
  console.log(countries);

  const countryId = countries[0].id;
  const carriers = await api(`carriers?country_id=eq.${countryId}&select=*`);
  console.log(`\n--- Carriers (${carriers.length}) ---`);
  console.log(carriers);

  for (const c of carriers) {
    console.log(`\n==============================================`);
    console.log(`Carrier: ${c.name} (ID: ${c.id})`);
    console.log(`Supported: ${c.is_supported} | Gateway: ${c.fulfillment_gateway} | Default Refill: $${c.default_refill_amount}`);
    
    const rules = await api(`carrier_rules?carrier_id=eq.${c.id}&select=*`);
    console.log(`\nRules (${rules.length}):`);
    rules.forEach(r => {
      console.log(`  Rule ID: ${r.id} | Type: ${r.rule_type} | Inactivity: ${r.inactivity_limit_days}d | Grace: ${r.grace_period_days}d | Min: $${r.minimum_topup_amount} | Rec: $${r.recommended_topup_amount} | Validity: ${r.topup_validity_days}d | InApp: $${r.inapp_pricing} | OfferID: ${r.offer_id}`);
      console.log(`  Notes: ${r.notes}`);
    });

    const maps = await api(`carrier_provider_map?carrier_id=eq.${c.id}&select=*&order=priority.asc`);
    console.log(`\nProvider Maps (${maps.length}):`);
    maps.forEach(m => {
      console.log(`  [Priority ${m.priority}] Provider: ${m.provider} | Code: ${m.provider_carrier_code} (${m.provider_country_code}) | Enabled: ${m.is_enabled} | Primary: ${m.is_primary}`);
      console.log(`    Notes: ${m.notes}`);
    });
  }
}

main().catch(console.error);
