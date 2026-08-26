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

async function check() {
  const h = { 'apikey': env.SUPABASE_SERVICE_ROLE_KEY, 'Authorization': 'Bearer ' + env.SUPABASE_SERVICE_ROLE_KEY };
  const carriers = await (await fetch(env.SUPABASE_URL + '/rest/v1/carriers?country_id=eq.4fb5af9c-e8b8-450d-87d2-c42f0d2ce659', { headers: h })).json();
  console.log('Carriers in DB:', carriers.map(c => ({ id: c.id, name: c.name, is_supported: c.is_supported })));

  const rules = await (await fetch(env.SUPABASE_URL + '/rest/v1/carrier_rules?carrier_id=in.(' + carriers.map(c => c.id).join(',') + ')', { headers: h })).json();
  console.log('Rules in DB count:', rules.length);
  rules.forEach(r => console.log('Rule:', r.carrier_id, '| Type:', r.rule_type, '| Inactivity:', r.inactivity_limit_days, '| Grace:', r.grace_period_days, '| Min:', r.minimum_topup_amount, '| TopupVal:', r.topup_validity_days));

  const maps = await (await fetch(env.SUPABASE_URL + '/rest/v1/carrier_provider_map?carrier_id=in.(' + carriers.map(c => c.id).join(',') + ')', { headers: h })).json();
  console.log('Maps in DB count:', maps.length);
  maps.forEach(m => console.log('Map:', m.carrier_id, '| Prov:', m.provider, '| Code:', m.provider_carrier_code, '| Label:', m.provider_carrier_label, '| Prio:', m.priority, '| Primary:', m.is_primary, '| Enabled:', m.is_enabled));
}

check().catch(console.error);
