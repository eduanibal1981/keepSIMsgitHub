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
  console.log('=== CHECKING MOROCCO IN SUPABASE ===');
  
  // 1. Country
  const countries = await api('countries?iso_code=eq.MA');
  console.log('\n1. Country Record (MA):', countries);

  if (countries.length === 0) {
    console.log('Country MA not found, checking all countries...');
    const allC = await api('countries?select=id,name,iso_code,phone_code,is_supported');
    console.log('All countries:', allC.filter(c => c.iso_code === 'MA' || c.name.toLowerCase().includes('morocco')));
    return;
  }

  const maCountryId = countries[0].id;

  // 2. Carriers
  const carriers = await api(`carriers?country_id=eq.${maCountryId}`);
  console.log(`\n2. Existing Carriers for Morocco (${carriers.length}):`, JSON.stringify(carriers, null, 2));

  // 3. Carrier Rules & Provider Maps for each carrier
  for (const c of carriers) {
    console.log(`\n--- Carrier: ${c.name} (${c.id}) ---`);
    const rules = await api(`carrier_rules?carrier_id=eq.${c.id}`);
    console.log(`Rules (${rules.length}):`, JSON.stringify(rules, null, 2));

    const maps = await api(`carrier_provider_map?carrier_id=eq.${c.id}`);
    console.log(`Provider Maps (${maps.length}):`, JSON.stringify(maps, null, 2));
  }
}

main().catch(console.error);
