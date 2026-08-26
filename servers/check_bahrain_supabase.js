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

async function supabaseApi(endpoint, method = 'GET', body = null) {
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
    throw new Error(`API error ${res.status} on ${method} ${endpoint}: ${text}`);
  }
  const text = await res.text();
  return text ? JSON.parse(text) : null;
}

async function main() {
  console.log('=== CHECKING SUPABASE BAHRAIN CONFIG ===');
  
  // 1. Country
  const countries = await supabaseApi('countries?iso_code=in.(BH,BHR)&select=*');
  console.log('Countries:', countries);

  if (countries.length > 0) {
    const cid = countries[0].id;
    // 2. Carriers
    const carriers = await supabaseApi(`carriers?country_id=eq.${cid}&select=*`);
    console.log(`Carriers for BH (${carriers.length}):`, carriers);

    // 3. Rules & Maps
    for (const c of carriers) {
      const rules = await supabaseApi(`carrier_rules?carrier_id=eq.${c.id}&select=*`);
      const maps = await supabaseApi(`carrier_provider_map?carrier_id=eq.${c.id}&select=*`);
      console.log(`\nCarrier: ${c.name} (ID: ${c.id})`);
      console.log('Rules:', rules);
      console.log('Maps:', maps);
    }
  }
}

main();
