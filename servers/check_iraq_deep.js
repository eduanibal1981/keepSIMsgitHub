const fs = require('fs');
const path = require('path');

// Read servers/.env
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

async function main() {
  console.log('--- RE-CHECKING ZENDIT & DING FOR IRAQ ---');

  // 1. ZENDIT
  try {
    const zenSecret = env.ZENDIT_API_SECRET;
    const zenBase = 'https://api.zendit.io/v1';

    const offRes = await fetch(`${zenBase}/topups/offers?country=IQ&_limit=100&_offset=0`, {
      headers: { Authorization: `Bearer ${zenSecret}` }
    });
    console.log(`Zendit Offers Status: ${offRes.status}`);
    const offers = await offRes.json();
    console.log('Zendit Offers:', JSON.stringify(offers, null, 2));
  } catch (err) {
    console.error('Zendit Error:', err.message);
  }

  // 2. DINGCONNECT
  try {
    const dingKey = env.DING_API_KEY;
    const dingBase = 'https://api.dingconnect.com/api/V1';

    console.log('\nFetching Ding Products for IQ...');
    const prodRes = await fetch(`${dingBase}/GetProducts?countryIsos=IQ`, {
      headers: { api_key: dingKey }
    });
    console.log(`Ding Products Status: ${prodRes.status}`);
    const products = await prodRes.json();
    console.log('Ding Products Response:', JSON.stringify(products, null, 2));
  } catch (err) {
    console.error('Ding Error:', err.message);
  }

  // 3. RELOADLY CHECK ALL OPERATORS (including PIN / Data / All)
  try {
    const authRes = await fetch('https://auth.reloadly.com/oauth/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        client_id: env.RELOADLY_CLIENT_ID,
        client_secret: env.RELOADLY_CLIENT_SECRET,
        grant_type: 'client_credentials',
        audience: 'https://topups-sandbox.reloadly.com'
      })
    });
    const authData = await authRes.json();
    const token = authData.access_token;
    
    // Check operators for IQ with includeBundles, includeData, etc.
    const opRes = await fetch('https://topups-sandbox.reloadly.com/operators/countries/IQ?includeBundles=true&includeData=true&includePin=true', {
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: 'application/com.reloadly.topups-v1+json'
      }
    });
    console.log(`Reloadly All Operators Status: ${opRes.status}`);
    const operators = await opRes.json();
    console.log('Reloadly Operators:', JSON.stringify(operators, null, 2));
  } catch (err) {
    console.error('Reloadly Error:', err.message);
  }
}

main();
