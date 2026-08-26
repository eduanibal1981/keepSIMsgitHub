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

async function verify() {
  const resC = await fetch(`${SUPABASE_URL}/rest/v1/countries?iso_code=eq.TR`, {
    headers: { 'apikey': SUPABASE_KEY, 'Authorization': `Bearer ${SUPABASE_KEY}` }
  });
  const country = await resC.json();
  console.log('Country:', country);

  const resCar = await fetch(`${SUPABASE_URL}/rest/v1/carriers?country_id=eq.${country[0].id}&order=name.asc`, {
    headers: { 'apikey': SUPABASE_KEY, 'Authorization': `Bearer ${SUPABASE_KEY}` }
  });
  const carriers = await resCar.json();
  console.log('\nCarriers (', carriers.length, '):');
  carriers.forEach(c => console.log(`- ${c.name} (${c.id}) | supported: ${c.is_supported} | default: ${c.default_refill_amount}`));

  const carrierIds = carriers.map(c => c.id);

  const resRules = await fetch(`${SUPABASE_URL}/rest/v1/carrier_rules?carrier_id=in.(${carrierIds.join(',')})`, {
    headers: { 'apikey': SUPABASE_KEY, 'Authorization': `Bearer ${SUPABASE_KEY}` }
  });
  const rules = await resRules.json();
  console.log('\nCarrier Rules (', rules.length, '):');
  rules.forEach(r => {
    const c = carriers.find(x => x.id === r.carrier_id);
    console.log(`- ${c?.name}: Inact ${r.inactivity_limit_days}d | Grace ${r.grace_period_days}d | Min ${r.minimum_topup_amount} | Rec ${r.recommended_topup_amount} | InApp $${r.inapp_pricing} | Offer ${r.offer_id}`);
  });

  const resMap = await fetch(`${SUPABASE_URL}/rest/v1/carrier_provider_map?carrier_id=in.(${carrierIds.join(',')})&order=priority.asc`, {
    headers: { 'apikey': SUPABASE_KEY, 'Authorization': `Bearer ${SUPABASE_KEY}` }
  });
  const map = await resMap.json();
  console.log('\nCarrier Provider Map (', map.length, '):');
  map.forEach(m => {
    const c = carriers.find(x => x.id === m.carrier_id);
    console.log(`- ${c?.name} -> ${m.provider.toUpperCase()} (${m.provider_country_code}/${m.provider_carrier_code}) | Prio ${m.priority} | Primary: ${m.is_primary} | Enabled: ${m.is_enabled} | Label: ${m.provider_carrier_label}`);
  });
}

verify().catch(console.error);
