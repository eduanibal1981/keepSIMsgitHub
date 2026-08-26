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
  const res = await fetch(`${env.SUPABASE_URL}/rest/v1/carrier_provider_map?select=carrier_id,provider,provider_carrier_code,is_enabled,is_primary,notes&limit=50`, {
    headers: { apikey: env.SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}` }
  });
  const data = await res.json();
  console.log('Sample maps:');
  data.forEach(d => {
    console.log(`Provider: ${d.provider.padEnd(10)} | Code: ${d.provider_carrier_code.padEnd(12)} | Enabled: ${d.is_enabled} | Primary: ${d.is_primary} | Notes: ${d.notes?.slice(0, 60)}`);
  });
}

main();
