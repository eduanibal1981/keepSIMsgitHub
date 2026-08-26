const fs = require('fs');
const path = require('path');

const candidatePaths = [
  path.join(__dirname, '..', 'servers', '.env'),
  path.join(__dirname, 'servers', '.env'),
  path.join(__dirname, '.env'),
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

const supabaseUrl = env.SUPABASE_URL || process.env.SUPABASE_URL;
const supabaseKey = env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY;

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

async function checkPhCarriers() {
  const phCountryId = '1ce63c64-05fb-4b37-ad30-369c40896e58';
  const carriers = await querySupabase(`carriers?select=*&country_id=eq.${phCountryId}`);
  console.log('Existing PH Carriers in DB:', carriers);
  if (carriers && carriers.length > 0) {
    const cIds = carriers.map(c => c.id);
    const maps = await querySupabase(`carrier_provider_map?select=*&carrier_id=in.(${cIds.join(',')})`);
    console.log('Existing PH Maps:', maps);
    const rules = await querySupabase(`carrier_rules?select=*&carrier_id=in.(${cIds.join(',')})`);
    console.log('Existing PH Rules:', rules);
  }
}

checkPhCarriers().catch(console.error);
