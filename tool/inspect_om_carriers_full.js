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

async function querySupabase(endpoint) {
  const url = `${supabaseUrl}/rest/v1/${endpoint}`;
  const res = await fetch(url, {
    headers: {
      'apikey': supabaseKey,
      'Authorization': `Bearer ${supabaseKey}`,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation'
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
  const omCountry = await querySupabase('countries?name=ilike.*Oman*');
  console.log('Oman Country:', omCountry);
  const countryId = omCountry[0].id;
  const carriers = await querySupabase(`carriers?country_id=eq.${countryId}`);
  console.log('Carriers count:', carriers.length);
  console.log('Carriers in DB:', JSON.stringify(carriers, null, 2));

  const carrierIds = carriers.map(c => c.id);
  const maps = await querySupabase(`carrier_provider_map?carrier_id=in.(${carrierIds.join(',')})`);
  console.log('\nCarrier Provider Map Count:', maps.length);
  console.log('Carrier Provider Maps:', JSON.stringify(maps, null, 2));

  const rules = await querySupabase(`carrier_rules?carrier_id=in.(${carrierIds.join(',')})`);
  console.log('\nCarrier Rules Count:', rules.length);
  console.log('Carrier Rules:', JSON.stringify(rules, null, 2));
}

run().catch(console.error);
