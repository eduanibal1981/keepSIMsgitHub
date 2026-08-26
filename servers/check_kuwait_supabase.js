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

async function check() {
  console.log('=== CHECKING SUPABASE FOR KUWAIT (KW) ===');

  // Country
  const countries = await api('countries?iso_code=eq.KW');
  console.log('Country record:', countries);

  if (countries && countries.length > 0) {
    const kwId = countries[0].id;
    console.log(`Kuwait Country ID: ${kwId}`);

    // Carriers
    const carriers = await api(`carriers?country_id=eq.${kwId}`);
    console.log('Carriers:', carriers);

    // Carrier Rules
    for (const c of carriers) {
      const rules = await api(`carrier_rules?carrier_id=eq.${c.id}`);
      console.log(`Rules for ${c.name} (${c.id}):`, rules);

      const maps = await api(`carrier_provider_map?carrier_id=eq.${c.id}`);
      console.log(`Provider Maps for ${c.name} (${c.id}):`, maps);
    }
  }
}

check().catch(console.error);
