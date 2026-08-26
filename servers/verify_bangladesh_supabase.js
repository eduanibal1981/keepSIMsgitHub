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
  console.log('=== VERIFYING BANGLADESH (BD) IN SUPABASE ===');
  console.log('====================================================');

  const country = await api('countries?iso_code=eq.BD');
  console.log('Country:', country[0]?.name, '| ISO:', country[0]?.iso_code, '| Supported:', country[0]?.is_supported);

  const bdId = country[0]?.id;
  const carriers = await api(`carriers?country_id=eq.${bdId}`);
  console.log(`\nCarriers (${carriers.length}):`);
  for (const c of carriers) {
    console.log(`\n--- Carrier: ${c.name} (ID: ${c.id}) ---`);
    console.log(`  Supported: ${c.is_supported} | Gateway: ${c.fulfillment_gateway} | Default Refill: $${c.default_refill_amount}`);

    const rules = await api(`carrier_rules?carrier_id=eq.${c.id}`);
    if (rules && rules.length > 0) {
      const r = rules[0];
      console.log(`  Rules -> Inactivity: ${r.inactivity_limit_days}d | Grace: ${r.grace_period_days}d | Min: $${r.minimum_topup_amount} | Offer: ${r.offer_id}`);
    }

    const maps = await api(`carrier_provider_map?carrier_id=eq.${c.id}`);
    console.log(`  Provider Maps (${maps.length}):`);
    maps.sort((a, b) => a.priority - b.priority).forEach(m => {
      console.log(`    [Priority ${m.priority}] ${m.provider.toUpperCase()} (Code: ${m.provider_carrier_code}) | Primary: ${m.is_primary} | Enabled: ${m.is_enabled}`);
    });
  }
}

main().catch(console.error);
