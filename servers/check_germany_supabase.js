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

async function checkDb() {
  console.log('=== CHECKING SUPABASE FOR GERMANY ===');
  const country = await api('countries?iso_code=eq.DE');
  console.log('Country DE:', country);

  if (country && country.length > 0) {
    const countryId = country[0].id;
    const carriers = await api(`carriers?country_id=eq.${countryId}`);
    console.log(`\nFound ${carriers.length} carriers for Germany:`);
    for (const c of carriers) {
      console.log(`- Carrier: ${c.name} (ID: ${c.id}, is_supported: ${c.is_supported})`);
      const rules = await api(`carrier_rules?carrier_id=eq.${c.id}`);
      console.log(`  Rules: ${rules.length} entries`);
      const maps = await api(`carrier_provider_map?carrier_id=eq.${c.id}`);
      console.log(`  Provider Maps: ${maps.length} entries:`);
      maps.forEach(m => console.log(`    Provider: ${m.provider_name} | Code: ${m.provider_carrier_code} | Primary: ${m.is_primary} | Enabled: ${m.is_enabled} | Priority: ${m.priority}`));
    }
  }
}

checkDb();
