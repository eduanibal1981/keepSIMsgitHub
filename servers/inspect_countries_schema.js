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
  const text = await res.text();
  if (!res.ok) {
    throw new Error(`API error ${res.status} ${res.statusText} on ${method} ${endpoint}: ${text}`);
  }
  return text ? JSON.parse(text) : null;
}

async function main() {
  const allC = await api('countries');
  console.log(`Total countries in DB: ${allC.length}`);
  console.log('Sample country object keys:', Object.keys(allC[0] || {}));
  const match = allC.filter(c => 
    c.iso_code?.toUpperCase() === 'MA' || 
    c.iso2?.toUpperCase() === 'MA' || 
    c.iso3?.toUpperCase() === 'MAR' || 
    c.name?.toLowerCase().includes('morocco')
  );
  console.log('Morocco matches:', match);
}

main().catch(console.error);
