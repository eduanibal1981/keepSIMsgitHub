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

async function checkDing() {
  const dingKey = env.DING_API_KEY;
  const dingBase = 'https://api.dingconnect.com/api/V1';

  const provCodes = ['TLDE', 'VFDE', 'O2DE', 'C4DE', 'ESDE', 'LYDE', 'AYDE', 'BSDE', 'OTDE', 'OEDE', 'F1DE', 'B6DE', 'E825B8DE', 'EPDE', 'M4DE', 'V6DE', 'O1DE', 'C7DE', 'C8DE', 'A9DE', 'O3DE', 'O4DE', 'FYDE', 'F2DE'];

  const allDingProducts = [];

  for (const pc of provCodes) {
    try {
      console.log(`Checking Ding products for ${pc}...`);
      const res = await fetch(`${dingBase}/GetProducts?providerCodes=${pc}`, {
        headers: { api_key: dingKey }
      });
      console.log(`  Status: ${res.status}`);
      if (res.ok) {
        const data = await res.json();
        console.log(`  Items count: ${data.Items ? data.Items.length : 0}, ResultCode: ${data.ResultCode}`);
        if (data.Items && data.Items.length > 0) {
          data.Items.forEach(p => {
            allDingProducts.push(p);
            console.log(`    Sku: ${p.SkuCode} | Prov: ${p.ProviderCode} | Name: ${p.LocalizationKey} | Send: ${p.Minimum?.SendValue}-${p.Maximum?.SendValue} ${p.Minimum?.SendCurrencyIso} | Rec: ${p.Minimum?.ReceiveValue} ${p.Minimum?.ReceiveCurrencyIso} | Uat: ${p.UatNumber}`);
          });
        }
      }
    } catch (e) {
      console.error(`Error checking ${pc}:`, e.message);
    }
    await new Promise(r => setTimeout(r, 600));
  }

  console.log(`\nTotal Ding products found: ${allDingProducts.length}`);
  fs.writeFileSync(path.join(__dirname, 'ding_deu_products.json'), JSON.stringify(allDingProducts, null, 2));
}

checkDing();
