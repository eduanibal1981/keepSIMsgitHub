const fs = require('fs');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');

const candidatePaths = [
  path.join(__dirname, 'servers', '.env'),
  path.join(__dirname, '..', 'servers', '.env'),
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

const supabase = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY);

async function check() {
  console.log('=== SUPABASE SCHEMA INSPECTION ===');
  
  // 1. Countries
  const { data: sampleCountry, error: cErr } = await supabase.from('countries').select('*').limit(3);
  console.log('Sample Countries:', sampleCountry, cErr || '');

  // 2. Carriers
  const { data: sampleCarrier, error: carErr } = await supabase.from('carriers').select('*').limit(3);
  console.log('Sample Carriers:', sampleCarrier, carErr || '');

  // 3. Carrier Provider Map
  const { data: sampleMap, error: mErr } = await supabase.from('carrier_provider_map').select('*').limit(3);
  console.log('Sample Map:', sampleMap, mErr || '');

  // 4. Carrier Rules
  const { data: sampleRule, error: rErr } = await supabase.from('carrier_rules').select('*').limit(3);
  console.log('Sample Rules:', sampleRule, rErr || '');

  // 5. Query India specifically
  const { data: inCountry } = await supabase.from('countries').select('*').ilike('name', '%India%');
  console.log('India country row:', inCountry);

  if (inCountry && inCountry.length > 0) {
    const { data: inCarriers } = await supabase.from('carriers').select('*').eq('country_id', inCountry[0].id);
    console.log('Existing India Carriers:', inCarriers);
    
    if (inCarriers && inCarriers.length > 0) {
      const ids = inCarriers.map(c => c.id);
      const { data: inMaps } = await supabase.from('carrier_provider_map').select('*').in('carrier_id', ids);
      console.log('Existing India Carrier Provider Maps:', inMaps);

      const { data: inRules } = await supabase.from('carrier_rules').select('*').in('carrier_id', ids);
      console.log('Existing India Carrier Rules:', inRules);
    }
  }
}

check().catch(console.error);
