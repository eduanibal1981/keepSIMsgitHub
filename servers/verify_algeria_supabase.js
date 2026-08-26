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
      'Authorization': `Bearer ${SUPABASE_KEY}`
    }
  });
  return res.json();
}

async function verify() {
  console.log('=== VERIFYING ALGERIA SUPABASE PROVISIONING ===\n');

  // Country
  const countries = await api('countries?iso_code=eq.DZ');
  console.log('1. Country:', countries);

  if (!countries || countries.length === 0) return;
  const countryId = countries[0].id;

  // Carriers
  const carriers = await api(`carriers?country_id=eq.${countryId}`);
  console.log('\n2. Carriers:', carriers);

  // Carrier Rules
  for (const c of carriers) {
    const rules = await api(`carrier_rules?carrier_id=eq.${c.id}`);
    console.log(`\n3. Rules for [${c.name}]:`, rules);

    const maps = await api(`carrier_provider_map?carrier_id=eq.${c.id}&order=priority.asc`);
    console.log(`4. Provider Maps for [${c.name}]:`, maps);
  }
}

verify().catch(console.error);
