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

async function checkTRDetails() {
  const carrierIds = [
    'fe1eb878-c1d2-4a01-8510-7f938c73712e',
    '8c132d25-bcd4-4764-83ee-15f63924f665',
    'e2530247-64e7-4384-ac22-c26e45dba57c'
  ];

  const resRules = await fetch(`${SUPABASE_URL}/rest/v1/carrier_rules?carrier_id=in.(${carrierIds.join(',')})`, {
    headers: {
      'apikey': SUPABASE_KEY,
      'Authorization': `Bearer ${SUPABASE_KEY}`
    }
  });
  const rules = await resRules.json();
  console.log('Existing Carrier Rules:', JSON.stringify(rules, null, 2));

  const resMap = await fetch(`${SUPABASE_URL}/rest/v1/carrier_provider_map?carrier_id=in.(${carrierIds.join(',')})`, {
    headers: {
      'apikey': SUPABASE_KEY,
      'Authorization': `Bearer ${SUPABASE_KEY}`
    }
  });
  const map = await resMap.json();
  console.log('Existing Carrier Provider Map:', JSON.stringify(map, null, 2));
}

checkTRDetails().catch(console.error);
