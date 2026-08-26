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
  console.log('--- 1. Testing Zendit with offset & limit ---');
  try {
    const zenSecret = env.ZENDIT_API_SECRET;
    const zenBase = 'https://api.zendit.io/v1';
    const offRes = await fetch(`${zenBase}/topups/offers?country=BH&_offset=0&_limit=100`, {
      headers: { Authorization: `Bearer ${zenSecret}` }
    });
    console.log(`Zendit Offers Status: ${offRes.status}`);
    const offers = await offRes.json();
    console.log('Zendit Result:', JSON.stringify(offers, null, 2));
  } catch (e) {
    console.error('Zendit Error:', e);
  }

  console.log('\n--- 2. Testing Ding Products for BVBH (Batelco) & ZABH (Zain) ---');
  try {
    const dingKey = env.DING_API_KEY;
    const dingBase = 'https://api.dingconnect.com/api/V1';
    
    // Test Batelco products
    const resBatelco = await fetch(`${dingBase}/GetProducts?providerCodes=BVBH`, {
      headers: { api_key: dingKey }
    });
    console.log(`Ding Batelco Status: ${resBatelco.status}`);
    const dataBatelco = await resBatelco.json();
    console.log('Ding Batelco Products:', JSON.stringify(dataBatelco, null, 2));

    await new Promise(r => setTimeout(r, 2000));

    // Test Zain products
    const resZain = await fetch(`${dingBase}/GetProducts?providerCodes=ZABH`, {
      headers: { api_key: dingKey }
    });
    console.log(`Ding Zain Status: ${resZain.status}`);
    const dataZain = await resZain.json();
    console.log('Ding Zain Products:', JSON.stringify(dataZain, null, 2));
  } catch (e) {
    console.error('Ding Error:', e);
  }
}

main();
