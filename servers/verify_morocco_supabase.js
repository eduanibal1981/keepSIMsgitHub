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
  return text ? JSON.parse(text) : null;
}

async function main() {
  console.log('=== VERIFYING MOROCCO IN SUPABASE ===');
  const country = await api('countries?iso_code=eq.MA');
  console.log('Country:', country[0]);

  const carriers = await api(`carriers?country_id=eq.${country[0].id}`);
  console.log(`\nCarriers (${carriers.length}):`);
  for (const c of carriers) {
    console.log(`\nCarrier: ${c.name} (${c.id}) | is_supported: ${c.is_supported} | default_refill_amount: ${c.default_refill_amount}`);
    const rules = await api(`carrier_rules?carrier_id=eq.${c.id}`);
    console.log(`  Rule: inactive_limit: ${rules[0]?.inactivity_limit_days}d, grace: ${rules[0]?.grace_period_days}d, min_topup: ${rules[0]?.minimum_topup_amount}, inapp: ${rules[0]?.inapp_pricing}`);
    const maps = await api(`carrier_provider_map?carrier_id=eq.${c.id}`);
    console.log(`  Provider Maps (${maps.length}):`);
    maps.forEach(m => {
      console.log(`    [P${m.priority}] ${m.provider}: code=${m.provider_carrier_code}, enabled=${m.is_enabled}, primary=${m.is_primary} | notes=${m.notes}`);
    });
  }
}

main().catch(console.error);
