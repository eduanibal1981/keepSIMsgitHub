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

async function checkSchema() {
  const resC = await fetch(`${SUPABASE_URL}/rest/v1/countries?limit=5`, {
    headers: {
      'apikey': SUPABASE_KEY,
      'Authorization': `Bearer ${SUPABASE_KEY}`
    }
  });
  const countries = await resC.json();
  console.log('Sample countries:', JSON.stringify(countries, null, 2));

  const resAllC = await fetch(`${SUPABASE_URL}/rest/v1/countries?select=*`, {
    headers: {
      'apikey': SUPABASE_KEY,
      'Authorization': `Bearer ${SUPABASE_KEY}`
    }
  });
  const allCountries = await resAllC.json();
  const trCountry = allCountries.find(c => c.iso_code === 'TR' || c.code === 'TR' || c.name === 'Turkey' || c.name === 'Türkiye' || c.dial_code === '+90');
  console.log('Turkey Country record in DB:', JSON.stringify(trCountry, null, 2));

  const resCar = await fetch(`${SUPABASE_URL}/rest/v1/carriers?limit=5`, {
    headers: {
      'apikey': SUPABASE_KEY,
      'Authorization': `Bearer ${SUPABASE_KEY}`
    }
  });
  const carriers = await resCar.json();
  console.log('Sample carriers:', JSON.stringify(carriers, null, 2));

  if (trCountry) {
    const resTrCar = await fetch(`${SUPABASE_URL}/rest/v1/carriers?country_id=eq.${trCountry.id}`, {
      headers: {
        'apikey': SUPABASE_KEY,
        'Authorization': `Bearer ${SUPABASE_KEY}`
      }
    });
    const trCarriers = await resTrCar.json();
    console.log('Carriers for Turkey in DB:', JSON.stringify(trCarriers, null, 2));
  }
}

checkSchema().catch(console.error);
