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

async function updateCarrierRulesOffer() {
  const supabaseUrl = env.SUPABASE_URL;
  const supabaseKey = env.SUPABASE_SERVICE_ROLE_KEY;

  const carrierId = 'da1c57b4-5276-4814-ade4-1d5a421bc29e'; // STC

  console.log('Updating carrier_rules.offer_id to STC_SA_001_USD...');
  const res = await fetch(`${supabaseUrl}/rest/v1/carrier_rules?carrier_id=eq.${carrierId}`, {
    method: 'PATCH',
    headers: {
      apikey: supabaseKey,
      Authorization: `Bearer ${supabaseKey}`,
      'Content-Type': 'application/json',
      Prefer: 'return=representation'
    },
    body: JSON.stringify({
      offer_id: 'STC_SA_001_USD'
    })
  });
  console.log('Update result:', await res.json());
}

updateCarrierRulesOffer().catch(console.error);
