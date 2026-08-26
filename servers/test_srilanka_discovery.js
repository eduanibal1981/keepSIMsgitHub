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
  const discovery = {
    timestamp: new Date().toISOString(),
    dtone: {},
    reloadly: {},
    zendit: {},
    ding: {}
  };

  console.log('====================================================');
  console.log('=== DISCOVERING SRI LANKA (LK / LKA / +94) TELECOMS ===');
  console.log('====================================================');

  // 1. DT ONE (ISO: LKA)
  console.log('\n--- 1. DT ONE (LKA) ---');
  try {
    const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
    const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

    // Get operators
    let allOperators = [];
    let page = 1;
    while (true) {
      const opRes = await fetch(`${dtBase}/operators?country_iso_code=LKA&page=${page}&per_page=50`, {
        headers: { Authorization: `Basic ${dtoneAuth}` }
      });
      const ops = await opRes.json();
      if (!Array.isArray(ops) || ops.length === 0) break;
      allOperators.push(...ops);
      if (ops.length < 50) break;
      page++;
    }
    discovery.dtone.operators = allOperators;
    console.log(`DT One Total Operators: ${allOperators.length}`);
    allOperators.forEach(op => {
      console.log(`  Op ID: ${op.id} | Name: ${op.name} | Country: ${op.country?.name} (${op.country?.iso_code})`);
    });

    // Get products
    let allProducts = [];
    page = 1;
    while (true) {
      const prodRes = await fetch(`${dtBase}/products?country_iso_code=LKA&page=${page}&per_page=100`, {
        headers: { Authorization: `Basic ${dtoneAuth}` }
      });
      const prods = await prodRes.json();
      if (!Array.isArray(prods) || prods.length === 0) break;
      allProducts.push(...prods);
      if (prods.length < 100) break;
      page++;
    }
    discovery.dtone.products = allProducts;
    console.log(`DT One Total Products: ${allProducts.length}`);
    allProducts.forEach(p => {
      console.log(`  ID: ${p.id} | Op: ${p.operator?.id} (${p.operator?.name}) | Name: ${p.name} | Type: ${p.type} | Prices: ${JSON.stringify(p.prices?.wholesale || p.source)} | Dest: ${JSON.stringify(p.destination)}`);
    });
  } catch (err) {
    console.error('DT One Error:', err.message);
    discovery.dtone.error = err.message;
  }

  // 2. RELOADLY (ISO: LK)
  console.log('\n--- 2. RELOADLY (LK) ---');
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
    if (!authRes.ok) {
      console.error('Reloadly auth failed:', authData);
      discovery.reloadly.error = authData;
    } else {
      const token = authData.access_token;
      console.log('Reloadly Auth Success');
      const opRes = await fetch('https://topups-sandbox.reloadly.com/operators/countries/LK', {
        headers: {
          Authorization: `Bearer ${token}`,
          Accept: 'application/com.reloadly.topups-v1+json'
        }
      });
      console.log(`Reloadly Operators Status: ${opRes.status}`);
      const operators = await opRes.json();
      discovery.reloadly.operators = operators;
      console.log(`Reloadly Total Operators: ${operators.length}`);
      operators.forEach(op => {
        console.log(`  Op ID: ${op.operatorId} | Name: ${op.name} | DenomType: ${op.denominationType} | SenderCurr: ${op.senderCurrencyCode} | DestCurr: ${op.destinationCurrencyCode} | Min: ${op.minAmount} | Max: ${op.maxAmount} | FixedAmounts: ${JSON.stringify(op.fixedAmounts)} | fxRate: ${op.fx?.rate}`);
      });
    }
  } catch (err) {
    console.error('Reloadly Error:', err.message);
    discovery.reloadly.error = err.message;
  }

  // 3. ZENDIT (country: LK)
  console.log('\n--- 3. ZENDIT (LK) ---');
  try {
    const zenSecret = env.ZENDIT_API_SECRET;
    const zenBase = 'https://api.zendit.io/v1';

    let allOffers = [];
    let offset = 0;
    let total = Infinity;
    while (offset < total) {
      const offRes = await fetch(`${zenBase}/topups/offers?country=LK&_limit=100&_offset=${offset}`, {
        headers: { Authorization: `Bearer ${zenSecret}` }
      });
      console.log(`Zendit Offers Status: ${offRes.status} (offset=${offset})`);
      const offers = await offRes.json();
      if (!offers.list) {
        console.log('Zendit Response error/empty:', offers);
        break;
      }
      total = offers.total || offers.list.length;
      allOffers.push(...offers.list);
      offset += 100;
      if (allOffers.length >= total) break;
    }
    discovery.zendit.offers = { total: allOffers.length, list: allOffers };
    console.log(`Zendit Total Offers: ${allOffers.length}`);
    allOffers.forEach(o => {
      console.log(`  OfferId: ${o.offerId} | Brand: ${o.brand} | Name: ${o.name} | PriceType: ${o.priceType} | Price: ${JSON.stringify(o.price)} | Send: ${JSON.stringify(o.send)} | SubTypes: ${JSON.stringify(o.subTypes)}`);
    });
  } catch (err) {
    console.error('Zendit Error:', err.message);
    discovery.zendit.error = err.message;
  }

  // 4. DINGCONNECT (countryIsos: LK)
  console.log('\n--- 4. DINGCONNECT (LK) ---');
  try {
    const dingKey = env.DING_API_KEY;
    const dingBase = 'https://api.dingconnect.com/api/V1';

    const provRes = await fetch(`${dingBase}/GetProviders?countryIsos=LK`, {
      headers: { api_key: dingKey }
    });
    console.log(`Ding Providers Status: ${provRes.status}`);
    const providers = await provRes.json();
    discovery.ding.providers = providers;
    if (providers.Items) {
      console.log(`Ding Total Providers: ${providers.Items.length}`);
      providers.Items.forEach(p => {
        console.log(`  ProviderCode: ${p.ProviderCode} | Name: ${p.Name} | Regex: ${p.ValidationRegex} | Care: ${p.CustomerCareNumber}`);
      });
    }

    const prodRes = await fetch(`${dingBase}/GetProducts?countryIsos=LK`, {
      headers: { api_key: dingKey }
    });
    console.log(`Ding Products Status: ${prodRes.status}`);
    const products = await prodRes.json();
    discovery.ding.products = products;
    if (products.Items) {
      console.log(`Ding Total Products: ${products.Items.length}`);
      products.Items.forEach(p => {
        console.log(`  SkuCode: ${p.SkuCode} | ProviderCode: ${p.ProviderCode} | Name: ${p.LocalizationKey} | Min: ${JSON.stringify(p.Minimum)} | Max: ${JSON.stringify(p.Maximum)} | Validity: ${p.ValidityPeriodIso} | UatNumber: ${p.UatNumber}`);
      });
    } else {
      console.log('Ding Products response:', JSON.stringify(products));
    }
  } catch (err) {
    console.error('DingConnect Error:', err.message);
    discovery.ding.error = err.message;
  }

  fs.writeFileSync(path.join(__dirname, 'srilanka_discovery_raw.json'), JSON.stringify(discovery, null, 2));
  console.log('\nDiscovery completed and saved to srilanka_discovery_raw.json');
}

main().catch(console.error);
