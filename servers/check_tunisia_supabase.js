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
  if (!res.ok) {
    throw new Error(`API error ${res.status}: ${await res.text()}`);
  }
  return await res.json();
}

async function main() {
  console.log('=== CHECKING SUPABASE FOR TUNISIA (TN) ===');
  
  // 1. Countries
  const countries = await api('countries?iso_code=eq.TN');
  console.log('\nCountry Record:');
  console.log(JSON.stringify(countries, null, 2));

  if (countries.length > 0) {
    const countryId = countries[0].id;
    
    // 2. Carriers
    const carriers = await api(`carriers?country_id=eq.${countryId}`);
    console.log(`\nCarriers (${carriers.length}):`);
    console.log(JSON.stringify(carriers, null, 2));

    // 3. Carrier Rules & Provider Maps for each carrier
    for (const c of carriers) {
      console.log(`\n--- Carrier: ${c.name} (${c.id}) ---`);
      const rules = await api(`carrier_rules?carrier_id=eq.${c.id}`);
      console.log('Carrier Rules:', JSON.stringify(rules, null, 2));

      const maps = await api(`carrier_provider_map?carrier_id=eq.${c.id}`);
      console.log('Provider Maps:', JSON.stringify(maps, null, 2));
    }
  }
}

main().catch(console.error);
