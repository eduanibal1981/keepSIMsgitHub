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

async function supabaseApi(endpoint) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${endpoint}`, {
    headers: {
      'apikey': SUPABASE_KEY,
      'Authorization': `Bearer ${SUPABASE_KEY}`,
      'Content-Type': 'application/json'
    }
  });
  return await res.json();
}

async function main() {
  const carriers = await supabaseApi('carriers?country_id=eq.d6108f9d-7510-407a-8eaf-0b45c5dd1856&select=*');
  console.log('Carriers in DB:', JSON.stringify(carriers, null, 2));

  for (const c of carriers) {
    const rules = await supabaseApi(`carrier_rules?carrier_id=eq.${c.id}&select=*`);
    console.log(`\nRules for ${c.name} (${c.id}):`, JSON.stringify(rules, null, 2));
    const maps = await supabaseApi(`carrier_provider_map?carrier_id=eq.${c.id}&select=*`);
    console.log(`Maps for ${c.name} (${c.id}):`, JSON.stringify(maps, null, 2));
  }
}

main();
