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
  console.log('====================================================');
  console.log('=== DEEP QUERYING BANGLADESH TELECOM PROVIDERS ===');
  console.log('====================================================');

  const detailed = {
    dtone: {},
    reloadly: {},
    zendit: {},
    ding: {}
  };

  // 1. DT ONE
  console.log('\n--- 1. DT ONE DEEP QUERY ---');
  try {
    const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
    const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

    const opRes = await fetch(`${dtBase}/operators?country_iso_code=BGD&page=1&per_page=50`, {
      headers: { Authorization: `Basic ${dtoneAuth}` }
    });
    const operators = await opRes.json();
    detailed.dtone.operators = operators;
    console.log(`DT One Operators Found: ${operators.length}`);
    operators.forEach(op => console.log(`  Op ID: ${op.id}, Name: ${op.name}`));

    let allProducts = [];
    let page = 1;
    while (true) {
      const prodRes = await fetch(`${dtBase}/products?country_iso_code=BGD&page=${page}&per_page=100`, {
        headers: { Authorization: `Basic ${dtoneAuth}` }
      });
      const prods = await prodRes.json();
      if (!Array.isArray(prods) || prods.length === 0) break;
      allProducts = allProducts.concat(prods);
      if (prods.length < 100) break;
      page++;
    }
    detailed.dtone.products = allProducts;
    console.log(`DT One Total Products: ${allProducts.length}`);
    allProducts.forEach(p => {
      console.log(`  Prod ID: ${p.id} | Name: ${p.name} | Operator: ${p.operator?.id} (${p.operator?.name}) | Type: ${p.type} | Prices: ${JSON.stringify(p.prices?.wholesale || p.source)} | Dest: ${JSON.stringify(p.destination)}`);
    });
  } catch (e) {
    console.error('DT One error:', e);
  }

  // 2. RELOADLY
  console.log('\n--- 2. RELOADLY DEEP QUERY ---');
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

    const opRes = await fetch('https://topups-sandbox.reloadly.com/operators/countries/BD?includeBundles=true&includeData=true&includePin=true', {
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: 'application/com.reloadly.topups-v1+json'
      }
    });
    const operators = await opRes.json();
    detailed.reloadly.operators = operators;
    console.log(`Reloadly Operators Found: ${operators.length}`);
    operators.forEach(op => {
      console.log(`  Op ID: ${op.operatorId} | Name: ${op.name} | DenomType: ${op.denominationType} | Min: ${op.minAmount} | Max: ${op.maxAmount} | Fixed: ${JSON.stringify(op.fixedAmounts)}`);
    });
  } catch (e) {
    console.error('Reloadly error:', e);
  }

  // 3. ZENDIT
  console.log('\n--- 3. ZENDIT DEEP QUERY ---');
  try {
    const zenSecret = env.ZENDIT_API_SECRET;
    const zenBase = 'https://api.zendit.io/v1';

    let allOffers = [];
    let offset = 0;
    const limit = 50;
    while (true) {
      const offRes = await fetch(`${zenBase}/topups/offers?country=BD&_limit=${limit}&_offset=${offset}`, {
        headers: { Authorization: `Bearer ${zenSecret}` }
      });
      const data = await offRes.json();
      if (!data.list || data.list.length === 0) {
        if (offset === 0) console.log('Zendit Response:', data);
        break;
      }
      allOffers = allOffers.concat(data.list);
      if (allOffers.length >= data.total || data.list.length < limit) break;
      offset += limit;
    }
    detailed.zendit.offers = allOffers;
    console.log(`Zendit Total Offers: ${allOffers.length}`);
    allOffers.forEach(o => {
      console.log(`  Offer ID: ${o.offerId} | Brand: ${o.brand} | Name: ${o.name} | PriceType: ${o.priceType} | Price: ${JSON.stringify(o.price)} | Send: ${JSON.stringify(o.send)} | SubTypes: ${JSON.stringify(o.subTypes)}`);
    });
  } catch (e) {
    console.error('Zendit error:', e);
  }

  // 4. DINGCONNECT
  console.log('\n--- 4. DINGCONNECT DEEP QUERY ---');
  try {
    const dingKey = env.DING_API_KEY;
    const dingBase = 'https://api.dingconnect.com/api/V1';

    const provCodes = ['GEBD', 'RLBD', 'TQBD', 'BGBD', 'AXBD'];
    detailed.ding.providers = [];
    detailed.ding.products = [];

    for (const code of provCodes) {
      try {
        const pRes = await fetch(`${dingBase}/GetProducts?providerCodes=${code}`, {
          headers: { api_key: dingKey }
        });
        const pData = await pRes.json();
        console.log(`Ding Provider ${code} Products (${pRes.status}):`, pData.Items ? pData.Items.length : JSON.stringify(pData));
        if (pData.Items) {
          detailed.ding.products = detailed.ding.products.concat(pData.Items);
          pData.Items.forEach(p => {
            console.log(`  SkuCode: ${p.SkuCode} | ProviderCode: ${p.ProviderCode} | Name: ${p.LocalizationKey} | Min: ${JSON.stringify(p.Minimum)} | Max: ${JSON.stringify(p.Maximum)} | Validity: ${p.ValidityPeriodIso} | UatNumber: ${p.UatNumber}`);
          });
        }
      } catch (err) {
        console.error(`Ding error for ${code}:`, err.message);
      }
    }
  } catch (e) {
    console.error('Ding error:', e);
  }

  fs.writeFileSync(path.join(__dirname, 'bangladesh_detailed_raw.json'), JSON.stringify(detailed, null, 2));
  console.log('\nDetailed data saved to bangladesh_detailed_raw.json');
}

main().catch(console.error);
