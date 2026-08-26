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

async function testGetProductsWithAccount() {
  const baseUrl = 'https://api.dingconnect.com/api/V1';
  const apiKey = env.DING_API_KEY;

  const testNumbers = [
    { name: 'STC (050)', num: '966501234567' },
    { name: 'STC (055)', num: '966551234567' },
    { name: 'Mobily (056)', num: '966561234567' },
    { name: 'Zain (059)', num: '966591234567' },
    { name: 'Virgin (057)', num: '966570123456' },
    { name: 'Lebara (057)', num: '966576123456' },
    { name: 'Salam (051)', num: '966511234567' },
    { name: 'Red Bull (057)', num: '966578123456' }
  ];

  for (const t of testNumbers) {
    console.log(`\n=== Testing GetProducts for ${t.name}: ${t.num} ===`);
    const res = await fetch(`${baseUrl}/GetProducts?accountNumber=${encodeURIComponent(t.num)}`, {
      headers: { api_key: apiKey }
    });
    console.log(`HTTP Status: ${res.status}`);
    const data = await res.json();
    if (res.ok && data.Items && data.Items.length > 0) {
      console.log(`Returned ${data.Items.length} products!`);
      data.Items.slice(0, 3).forEach(p => {
        console.log(`  - SkuCode: ${p.SkuCode.padEnd(14)} | Name: ${p.DefaultDisplayText || p.LocalizationKey} | Send: ${p.Minimum?.SendValue} ${p.Minimum?.SendCurrencyIso} | Recv: ${p.Minimum?.ReceiveValue} ${p.Minimum?.ReceiveCurrencyIso}`);
      });
      // Show full details of first item
      console.log('Sample Product Full JSON:', JSON.stringify(data.Items[0], null, 2));
    } else {
      console.log('Response:', JSON.stringify(data, null, 2));
    }
    await new Promise(r => setTimeout(r, 1200));
  }
}

testGetProductsWithAccount().catch(console.error);
