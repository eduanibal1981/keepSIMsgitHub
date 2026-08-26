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

async function main() {
  // Check Vodafone Oman and Red Bull Oman carriers
  const carriers = await (await fetch(`${env.SUPABASE_URL}/rest/v1/carriers?name=ilike.%25Vodafone%25&select=*`, {
    headers: { apikey: env.SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}` }
  })).json();
  console.log('Vodafone carriers:', carriers);

  for (const c of carriers) {
    const maps = await (await fetch(`${env.SUPABASE_URL}/rest/v1/carrier_provider_map?carrier_id=eq.${c.id}&select=*`, {
      headers: { apikey: env.SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}` }
    })).json();
    console.log(`Maps for ${c.name}:`, maps);
  }
}

main();
