const fs = require('fs');
const path = require('path');

const candidatePaths = [
  path.join(__dirname, '..', 'servers', '.env'),
  path.join(__dirname, 'servers', '.env'),
  '/home/abdal/keepsims_backend/servers/.env'
];
let env = {};
for (const p of candidatePaths) {
  if (fs.existsSync(p)) {
    const content = fs.readFileSync(p, 'utf8');
    content.split('\n').forEach(line => {
      const m = line.match(/^\s*([\w_]+)\s*=\s*(.*)?\s*$/);
      if (m) {
        let v = (m[2] || '').trim();
        if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) {
          v = v.slice(1, -1);
        }
        env[m[1]] = v;
      }
    });
    break;
  }
}

const supabaseUrl = env.SUPABASE_URL;
const supabaseKey = env.SUPABASE_SERVICE_ROLE_KEY;

async function querySupabase(endpoint, options = {}) {
  const url = `${supabaseUrl}/rest/v1/${endpoint}`;
  const res = await fetch(url, {
    ...options,
    headers: {
      'apikey': supabaseKey,
      'Authorization': `Bearer ${supabaseKey}`,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
      ...(options.headers || {})
    }
  });
  if (!res.ok) {
    const text = await res.text();
    console.error(`Supabase error ${res.status} on ${endpoint}:`, text);
    return null;
  }
  return await res.json();
}

async function run() {
  console.log('=== INSPECTING COUNTRIES TABLE ===');
  const sampleCountries = await querySupabase('countries?limit=3');
  console.log('Sample countries in DB:', sampleCountries);

  const omCountry = await querySupabase('countries?name=ilike.*Oman*');
  console.log('Oman country row in DB:', omCountry);

  if (omCountry && omCountry.length > 0) {
    const countryId = omCountry[0].id;
    console.log(`Querying carriers for countryId: ${countryId}`);
    const omCarriers = await querySupabase(`carriers?country_id=eq.${countryId}`);
    console.log('Oman carriers in DB:', omCarriers);

    if (omCarriers && omCarriers.length > 0) {
      const ids = omCarriers.map(c => c.id);
      const maps = await querySupabase(`carrier_provider_map?carrier_id=in.(${ids.join(',')})`);
      console.log('Carrier Provider Map entries:', maps);

      const rules = await querySupabase(`carrier_rules?carrier_id=in.(${ids.join(',')})`);
      console.log('Carrier Rules entries:', rules);
    }
  }

  console.log('\n=== INSPECTING CARRIERS SCHEMA (sample) ===');
  const sampleCarriers = await querySupabase('carriers?limit=1');
  console.log('Sample carrier row:', sampleCarriers);

  console.log('\n=== INSPECTING CARRIER_PROVIDER_MAP SCHEMA (sample) ===');
  const sampleMap = await querySupabase('carrier_provider_map?limit=1');
  console.log('Sample map row:', sampleMap);

  console.log('\n=== INSPECTING CARRIER_RULES SCHEMA (sample) ===');
  const sampleRules = await querySupabase('carrier_rules?limit=1');
  console.log('Sample rule row:', sampleRules);
}

run().catch(console.error);
