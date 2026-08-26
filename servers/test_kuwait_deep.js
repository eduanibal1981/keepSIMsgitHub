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

const sleep = ms => new Promise(r => setTimeout(r, ms));

async function main() {
  console.log('=== 1. ZENDIT WITH OFFSET ===');
  const zenSecret = env.ZENDIT_API_SECRET;
  const zenBase = 'https://api.zendit.io/v1';

  try {
    const res = await fetch(`${zenBase}/topups/offers?country=KW&_limit=100&_offset=0`, {
      headers: { Authorization: `Bearer ${zenSecret}` }
    });
    console.log(`Zendit Status: ${res.status}`);
    const offers = await res.json();
    console.log(`Zendit Total: ${offers.total || (offers.list ? offers.list.length : 0)}`);
    if (offers.list) {
      offers.list.forEach(o => {
        console.log(`Offer: ${o.offerId} | Brand: ${o.brand} | Name: ${o.name} | Type: ${o.priceType} | Price: ${JSON.stringify(o.price)} | Send: ${JSON.stringify(o.send)}`);
      });
    } else {
      console.log('Zendit Response:', JSON.stringify(offers, null, 2));
    }
  } catch (e) {
    console.error('Zendit error:', e.message);
  }

  console.log('\n=== 2. DINGCONNECT WITH PROPER DELAYS ===');
  const dingKey = env.DING_API_KEY;
  const dingBase = 'https://api.dingconnect.com/api/V1';

  await sleep(1000);
  try {
    const prodRes = await fetch(`${dingBase}/GetProducts?countryIsos=KW`, {
      headers: { api_key: dingKey }
    });
    console.log(`Ding Products Status: ${prodRes.status}`);
    const products = await prodRes.json();
    console.log(`Ding ResultCode: ${products.ResultCode}, Total Items: ${products.Items ? products.Items.length : 0}`);
    if (products.Items && products.Items.length > 0) {
      products.Items.forEach(p => {
        console.log(`Sku: ${p.SkuCode} | Prov: ${p.ProviderCode} | Name: ${p.LocalizationKey} | Min: ${JSON.stringify(p.Minimum)} | Max: ${JSON.stringify(p.Maximum)} | Validity: ${p.ValidityPeriodIso} | UAT: ${p.UatNumber}`);
      });
    } else if (products.ErrorCodes) {
      console.log('Ding ErrorCodes:', JSON.stringify(products.ErrorCodes));
      // Let's try querying provider by provider if rate limited
      const providers = ['ZAKW', 'WTKW', 'VIKW', 'WKKW', 'V8KW'];
      for (const prov of providers) {
        await sleep(1500);
        console.log(`Querying Ding provider ${prov}...`);
        const pRes = await fetch(`${dingBase}/GetProducts?providerCodes=${prov}`, {
          headers: { api_key: dingKey }
        });
        const pData = await pRes.json();
        console.log(`Provider ${prov} status: ${pRes.status}, Items: ${pData.Items ? pData.Items.length : 0}, Err: ${JSON.stringify(pData.ErrorCodes || [])}`);
        if (pData.Items) {
          pData.Items.forEach(p => {
            console.log(`  Sku: ${p.SkuCode} | Name: ${p.LocalizationKey} | Min: ${JSON.stringify(p.Minimum)} | Max: ${JSON.stringify(p.Maximum)} | UAT: ${p.UatNumber}`);
          });
        }
      }
    }
  } catch (e) {
    console.error('Ding error:', e.message);
  }

  console.log('\n=== 3. DT ONE TELECOM PRODUCTS SUMMARY ===');
  const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
  const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

  const opRes = await fetch(`${dtBase}/operators?country_iso_code=KWT&page=1&per_page=50`, {
    headers: { Authorization: `Basic ${dtoneAuth}` }
  });
  const operators = await opRes.json();
  console.log('DT One KWT Operators:');
  operators.forEach(op => {
    console.log(`Op ID: ${op.id} | Name: ${op.name}`);
  });

  // Get all mobile products
  const prodRes = await fetch(`${dtBase}/products?country_iso_code=KWT&service_id=1&page=1&per_page=100`, {
    headers: { Authorization: `Basic ${dtoneAuth}` }
  });
  const mobileProds = await prodRes.json();
  console.log(`\nDT One Mobile Products (${mobileProds.length}):`);
  mobileProds.forEach(p => {
    console.log(`Prod ID: ${p.id} | Op ID: ${p.operator?.id} (${p.operator?.name}) | Name: ${p.name} | Type: ${p.type} | Wholesale: ${JSON.stringify(p.prices?.wholesale)} | Dest: ${JSON.stringify(p.destination)}`);
  });
}

main().catch(console.error);
