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
  console.log('=== CHECKING SUPABASE FOR BANGLADESH ===');
  
  const countries = await api('countries?iso_code=eq.BD');
  console.log('BD Country record:', countries);

  if (countries && countries.length > 0) {
    const bdId = countries[0].id;
    const carriers = await api(`carriers?country_id=eq.${bdId}`);
    console.log(`BD Carriers in DB (${carriers.length}):`, carriers);

    for (const c of carriers) {
      const rules = await api(`carrier_rules?carrier_id=eq.${c.id}`);
      console.log(`Rules for ${c.name}:`, rules);

      const map = await api(`carrier_provider_map?carrier_id=eq.${c.id}`);
      console.log(`Provider Map for ${c.name}:`, map);
    }
  }
}

main().catch(console.error);
