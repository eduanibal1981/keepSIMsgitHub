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
  console.log('====================================================');
  console.log('=== DISCOVERING GERMANY (DE / DEU / +49) TELECOMS ===');
  console.log('====================================================');

  const results = {
    dtone: { operators: [], products: [] },
    reloadly: { operators: [] },
    zendit: { offers: [] },
    ding: { providers: [], products: [] }
  };

  // 1. DT ONE (DEU)
  console.log('\n--- 1. DT ONE (DEU) ---');
  try {
    const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
    const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

    // Get operators
    const opRes = await fetch(`${dtBase}/operators?country_iso_code=DEU&page=1&per_page=100`, {
      headers: { Authorization: `Basic ${dtoneAuth}` }
    });
    console.log(`DT One Operators Status: ${opRes.status}`);
    const operators = await opRes.json();
    results.dtone.operators = operators;
    console.log('DT One Operators count:', Array.isArray(operators) ? operators.length : 0);
    if (Array.isArray(operators)) {
      operators.forEach(op => console.log(`  DT One Operator ID: ${op.id} | Name: ${op.name}`));
    }

    // Get products (all pages)
    let page = 1;
    let allProducts = [];
    while (true) {
      const prodRes = await fetch(`${dtBase}/products?country_iso_code=DEU&page=${page}&per_page=100`, {
        headers: { Authorization: `Basic ${dtoneAuth}` }
      });
      if (!prodRes.ok) break;
      const prods = await prodRes.json();
      if (!Array.isArray(prods) || prods.length === 0) break;
      allProducts = allProducts.concat(prods);
      if (prods.length < 100) break;
      page++;
    }
    results.dtone.products = allProducts;
    console.log(`DT One Total Products: ${allProducts.length}`);
    allProducts.forEach(p => {
      console.log(`  ID: ${p.id} | Name: ${p.name} | Operator: ${p.operator?.id} (${p.operator?.name}) | Type: ${p.type} | Prices: ${JSON.stringify(p.prices?.wholesale || p.source)} | Dest: ${JSON.stringify(p.destination)}`);
    });
  } catch (err) {
    console.error('DT One Error:', err.message);
  }

  // 2. RELOADLY (DE)
  console.log('\n--- 2. RELOADLY (DE) ---');
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
    } else {
      const token = authData.access_token;
      console.log('Reloadly Auth Success');
      const opRes = await fetch('https://topups-sandbox.reloadly.com/operators/countries/DE?includeBundles=true&includeData=true&includePin=true', {
        headers: {
          Authorization: `Bearer ${token}`,
          Accept: 'application/com.reloadly.topups-v1+json'
        }
      });
      console.log(`Reloadly Operators Status: ${opRes.status}`);
      const operators = await opRes.json();
      results.reloadly.operators = operators;
      console.log(`Reloadly Total Operators: ${Array.isArray(operators) ? operators.length : 0}`);
      if (Array.isArray(operators)) {
        operators.forEach(op => {
          console.log(`  Op ID: ${op.operatorId} | Name: ${op.name} | Bundle: ${op.bundle} | Data: ${op.data} | Pin: ${op.pin} | Denoms: ${JSON.stringify(op.fixedAmounts)} | Range: ${op.minAmount}-${op.maxAmount} ${op.denominationType}`);
        });
      }
    }
  } catch (err) {
    console.error('Reloadly Error:', err.message);
  }

  // 3. ZENDIT (DE)
  console.log('\n--- 3. ZENDIT (DE) ---');
  try {
    const zenSecret = env.ZENDIT_API_SECRET;
    const zenBase = 'https://api.zendit.io/v1';

    let zenditOffers = [];
    let offset = 0;
    while (true) {
      const offRes = await fetch(`${zenBase}/topups/offers?country=DE&_limit=100&_offset=${offset}`, {
        headers: { Authorization: `Bearer ${zenSecret}` }
      });
      console.log(`Zendit Offers Status (offset ${offset}): ${offRes.status}`);
      if (!offRes.ok) break;
      const offersData = await offRes.json();
      const list = offersData.list || [];
      zenditOffers = zenditOffers.concat(list);
      if (list.length < 100 || zenditOffers.length >= (offersData.total || 0)) break;
      offset += 100;
    }
    results.zendit.offers = zenditOffers;
    console.log(`Zendit Total Offers: ${zenditOffers.length}`);
    zenditOffers.forEach(o => {
      console.log(`  OfferId: ${o.offerId} | Brand: ${o.brand} | Name: ${o.name} | PriceType: ${o.priceType} | Price: ${JSON.stringify(o.price)} | Send: ${JSON.stringify(o.send)} | SubTypes: ${JSON.stringify(o.subTypes)}`);
    });
  } catch (err) {
    console.error('Zendit Error:', err.message);
  }

  // 4. DINGCONNECT (DE)
  console.log('\n--- 4. DINGCONNECT (DE) ---');
  try {
    const dingKey = env.DING_API_KEY;
    const dingBase = 'https://api.dingconnect.com/api/V1';

    // Providers
    const provRes = await fetch(`${dingBase}/GetProviders?countryIsos=DE`, {
      headers: { api_key: dingKey }
    });
    console.log(`Ding Providers Status: ${provRes.status}`);
    const providers = await provRes.json();
    results.ding.providers = providers;
    console.log(`Ding Total Providers: ${providers.Items ? providers.Items.length : 0}`);
    if (providers.Items) {
      providers.Items.forEach(p => {
        console.log(`  Ding Prov Code: ${p.ProviderCode} | Name: ${p.Name} | ValidationRegex: ${p.ValidationRegex} | PaymentTypes: ${JSON.stringify(p.PaymentTypes)}`);
      });
    }

    // Products
    const prodRes = await fetch(`${dingBase}/GetProducts?countryIsos=DE`, {
      headers: { api_key: dingKey }
    });
    console.log(`Ding Products Status: ${prodRes.status}`);
    const products = await prodRes.json();
    results.ding.products = products;
    console.log(`Ding Total Products: ${products.Items ? products.Items.length : 0}`);
    if (products.Items) {
      products.Items.forEach(p => {
        console.log(`  SkuCode: ${p.SkuCode} | ProviderCode: ${p.ProviderCode} | Name: ${p.LocalizationKey} | Min/Max Send: ${p.Minimum?.SendValue}-${p.Maximum?.SendValue} ${p.Minimum?.SendCurrencyIso} | Rec: ${p.Minimum?.ReceiveValue} ${p.Minimum?.ReceiveCurrencyIso} | UatNumber: ${p.UatNumber}`);
      });
    }
  } catch (err) {
    console.error('Ding Error:', err.message);
  }

  fs.writeFileSync(path.join(__dirname, 'germany_discovery_raw.json'), JSON.stringify(results, null, 2));
  console.log('\nWrote discovery results to servers/germany_discovery_raw.json');
}

main();
