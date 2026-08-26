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

async function inspectSchema() {
  console.log('=== INSPECTING SUPABASE SCHEMAS ===');
  const countries = await querySupabase('countries?select=*&limit=1');
  console.log('Countries table columns & sample:', countries);

  const phCountries = await querySupabase('countries?select=*&name=ilike.*Philippines*');
  console.log('PH Country:', phCountries);

  const carriers = await querySupabase('carriers?select=*&limit=1');
  console.log('Carriers table columns & sample:', carriers);

  const maps = await querySupabase('carrier_provider_map?select=*&limit=1');
  console.log('Carrier Provider Map columns & sample:', maps);

  const rules = await querySupabase('carrier_rules?select=*&limit=1');
  console.log('Carrier Rules columns & sample:', rules);
}

inspectSchema().catch(console.error);
