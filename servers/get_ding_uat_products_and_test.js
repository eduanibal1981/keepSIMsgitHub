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

async function getUatProducts() {
  const baseUrl = 'https://api.dingconnect.com/api/V1';
  const apiKey = env.DING_API_KEY;

  console.log('=== 1. Querying Ding GetProducts for Saudi Arabia (SA) ===');
  const providers = ['XCSA', 'S6SA', 'MLSA', 'ZKSA', 'VRSA', 'ESSA', 'FRSA', 'UQSA', '3HSA'];

  for (const prov of providers) {
    console.log(`\n--- Provider: ${prov} ---`);
    const res = await fetch(`${baseUrl}/GetProducts?providerCodes=${prov}&countryIsos=SA`, {
      headers: { api_key: apiKey }
    });
    console.log(`HTTP Status: ${res.status}`);
    const data = await res.json();
    
    if (res.ok && data.Items && data.Items.length > 0) {
      console.log(`Found ${data.Items.length} products for ${prov}:`);
      // Print first 2 products completely to see all fields (including any UAT fields)
      console.log('Sample Product 0:', JSON.stringify(data.Items[0], null, 2));
      if (data.Items.length > 1) {
        console.log('Sample Product 1:', JSON.stringify(data.Items[1], null, 2));
      }
    } else {
      console.log('Response:', JSON.stringify(data, null, 2));
    }
    // Delay 1 second between requests to respect rate limits
    await new Promise(r => setTimeout(r, 1000));
  }
}

getUatProducts().catch(console.error);
