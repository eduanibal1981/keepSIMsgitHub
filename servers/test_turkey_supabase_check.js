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

async function querySupabase(endpoint, options = {}) {
  const url = `${SUPABASE_URL}/rest/v1/${endpoint}`;
  const res = await fetch(url, {
    ...options,
    headers: {
      'apikey': SUPABASE_KEY,
      'Authorization': `Bearer ${SUPABASE_KEY}`,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
      ...(options.headers || {})
    }
  });
  if (!res.ok) {
    const txt = await res.text();
    throw new Error(`Supabase error ${res.status} ${res.statusText}: ${txt}`);
  }
  return await res.json();
}

async function checkSupabase() {
  console.log('=== Checking Supabase for Turkey ===');

  // 1. Check countries table
  try {
    const countries = await querySupabase('countries?or=(iso2.eq.TR,iso3.eq.TUR,dial_code.eq.+90,name.ilike.*Turkey*)');
    console.log('Countries:', JSON.stringify(countries, null, 2));

    let trCountryId = countries && countries[0] ? countries[0].id : null;
    console.log('TR Country ID:', trCountryId);

    // 2. Check carriers table
    const carriers = await querySupabase(`carriers?or=(country_code.eq.TR,country_id.eq.${trCountryId || '00000000-0000-0000-0000-000000000000'})`);
    console.log('Carriers for TR:', JSON.stringify(carriers, null, 2));

    if (carriers && carriers.length > 0) {
      const ids = carriers.map(c => c.id).join(',');
      const rules = await querySupabase(`carrier_rules?carrier_id=in.(${ids})`);
      console.log('Carrier Rules:', JSON.stringify(rules, null, 2));

      const map = await querySupabase(`carrier_provider_map?carrier_id=in.(${ids})`);
      console.log('Carrier Provider Map:', JSON.stringify(map, null, 2));
    }
  } catch (e) {
    console.error('Supabase Query Error:', e.message);
  }
}

checkSupabase();
