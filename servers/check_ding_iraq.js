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

async function checkDingIraq() {
  const baseUrl = 'https://api.dingconnect.com/api/V1';
  const apiKey = env.DING_API_KEY;

  console.log('=== Querying Ding GetProducts for Iraq (IQ) ===');
  const providers = ['ACIQ', 'KKIQ', 'KRIQ', '4RIQ', 'PGIQ'];

  for (const prov of providers) {
    console.log(`\n--- Provider: ${prov} ---`);
    try {
      const res = await fetch(`${baseUrl}/GetProducts?providerCodes=${prov}&countryIsos=IQ`, {
        headers: { api_key: apiKey }
      });
      console.log(`HTTP Status: ${res.status}`);
      const data = await res.json();
      console.log('Result:', JSON.stringify(data, null, 2));
    } catch (e) {
      console.error(`Error for ${prov}:`, e.message);
    }
    await new Promise(r => setTimeout(r, 2000));
  }
}

checkDingIraq().catch(console.error);
