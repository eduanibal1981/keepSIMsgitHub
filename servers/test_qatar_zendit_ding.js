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

async function main() {
  console.log('--- TESTING ZENDIT FOR QATAR (QA) ---');
  const zenSecret = env.ZENDIT_API_SECRET;
  const zenBase = 'https://api.zendit.io/v1';

  try {
    const offRes = await fetch(`${zenBase}/topups/offers?country=QA&_limit=100&_offset=0`, {
      headers: { Authorization: `Bearer ${zenSecret}` }
    });
    console.log(`Zendit Offers Status: ${offRes.status}`);
    const offers = await offRes.json();
    console.log(`Zendit Offers:`, JSON.stringify(offers, null, 2));
  } catch (e) {
    console.error('Zendit error:', e);
  }

  console.log('\n--- TESTING DINGCONNECT FOR QATAR (QA) ---');
  const dingKey = env.DING_API_KEY;
  const dingBase = 'https://api.dingconnect.com/api/V1';

  try {
    // Try GetProducts for specific providers: OOQA (Ooredoo) and VFQA (Vodafone)
    const ooredooRes = await fetch(`${dingBase}/GetProducts?countryIsos=QA&providerCodes=OOQA`, {
      headers: { api_key: dingKey }
    });
    console.log(`Ding Ooredoo (OOQA) Products Status: ${ooredooRes.status}`);
    const ooProds = await ooredooRes.json();
    console.log('Ding OOQA Prods:', JSON.stringify(ooProds, null, 2));

    const vodaRes = await fetch(`${dingBase}/GetProducts?countryIsos=QA&providerCodes=VFQA`, {
      headers: { api_key: dingKey }
    });
    console.log(`Ding Vodafone (VFQA) Products Status: ${vodaRes.status}`);
    const vfProds = await vodaRes.json();
    console.log('Ding VFQA Prods:', JSON.stringify(vfProds, null, 2));
  } catch (e) {
    console.error('Ding error:', e);
  }
}

main().catch(console.error);
