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
  const deepDiscovery = {
    timestamp: new Date().toISOString(),
    country: 'Nepal (NP / NPL / +977)',
    dtone: {},
    reloadly: {},
    zendit: {},
    ding: {}
  };

  console.log('===========================================================');
  console.log('=== DEEP DISCOVERY: NEPAL (NP / NPL / +977) ALL PROVIDERS ===');
  console.log('===========================================================');

  // 1. DT ONE
  console.log('\n--- 1. DT ONE (NPL) ---');
  const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
  const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

  try {
    const opRes = await fetch(`${dtBase}/operators?country_iso_code=NPL&page=1&per_page=50`, {
      headers: { Authorization: `Basic ${dtoneAuth}` }
    });
    deepDiscovery.dtone.operators = await opRes.json();
    console.log(`DT One Operators found: ${deepDiscovery.dtone.operators.length}`);

    let allProducts = [];
    let page = 1;
    while (true) {
      const prodRes = await fetch(`${dtBase}/products?country_iso_code=NPL&page=${page}&per_page=100`, {
        headers: { Authorization: `Basic ${dtoneAuth}` }
      });
      const prods = await prodRes.json();
      if (!Array.isArray(prods) || prods.length === 0) break;
      allProducts = allProducts.concat(prods);
      if (prods.length < 100) break;
      page++;
    }
    deepDiscovery.dtone.products = allProducts;
    console.log(`DT One Products total: ${allProducts.length}`);
  } catch (e) {
    console.error('DT One Error:', e.message);
  }

  // 2. RELOADLY
  console.log('\n--- 2. RELOADLY (NP) ---');
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

    const opRes = await fetch('https://topups-sandbox.reloadly.com/operators/countries/NP?includeBundles=true&includeData=true&includePin=true', {
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: 'application/com.reloadly.topups-v1+json'
      }
    });
    const operators = await opRes.json();
    deepDiscovery.reloadly.operators = operators;
    console.log(`Reloadly Operators found: ${Array.isArray(operators) ? operators.length : 0}`);

    // Detailed operator lookup
    if (Array.isArray(operators)) {
      deepDiscovery.reloadly.details = [];
      for (const op of operators) {
        const dRes = await fetch(`https://topups-sandbox.reloadly.com/operators/${op.operatorId}`, {
          headers: {
            Authorization: `Bearer ${token}`,
            Accept: 'application/com.reloadly.topups-v1+json'
          }
        });
        const detail = await dRes.json();
        deepDiscovery.reloadly.details.push(detail);
        await sleep(300);
      }
    }
  } catch (e) {
    console.error('Reloadly Error:', e.message);
  }

  // 3. ZENDIT
  console.log('\n--- 3. ZENDIT (NP) ---');
  try {
    const zenSecret = env.ZENDIT_API_SECRET;
    const zenBase = 'https://api.zendit.io/v1';

    let allOffers = [];
    let offset = 0;
    while (true) {
      const offRes = await fetch(`${zenBase}/topups/offers?country=NP&_limit=50&_offset=${offset}`, {
        headers: { Authorization: `Bearer ${zenSecret}` }
      });
      const data = await offRes.json();
      if (!data.list || data.list.length === 0) break;
      allOffers = allOffers.concat(data.list);
      if (allOffers.length >= data.total || data.list.length < 50) break;
      offset += 50;
    }
    deepDiscovery.zendit.offers = allOffers;
    console.log(`Zendit Offers total: ${allOffers.length}`);
  } catch (e) {
    console.error('Zendit Error:', e.message);
  }

  // 4. DINGCONNECT
  console.log('\n--- 4. DINGCONNECT (NP) ---');
  try {
    const dingKey = env.DING_API_KEY;
    const dingBase = 'https://api.dingconnect.com/api/V1';

    const provRes = await fetch(`${dingBase}/GetProviders?countryIsos=NP`, {
      headers: { api_key: dingKey }
    });
    const providers = await provRes.json();
    deepDiscovery.ding.providers = providers;
    console.log(`Ding Providers total: ${providers.Items ? providers.Items.length : 0}`);

    deepDiscovery.ding.products = {};
    if (providers.Items) {
      for (const prov of providers.Items) {
        console.log(`Fetching Ding products for ${prov.ProviderCode} (${prov.Name})...`);
        const prodRes = await fetch(`${dingBase}/GetProducts?providerCodes=${prov.ProviderCode}&countryIsos=NP`, {
          headers: { api_key: dingKey }
        });
        const prodData = await prodRes.json();
        deepDiscovery.ding.products[prov.ProviderCode] = prodData;
        console.log(`  -> Items: ${prodData.Items ? prodData.Items.length : 0}, ResultCode: ${prodData.ResultCode}`);
        await sleep(500);
      }
    }
  } catch (e) {
    console.error('DingConnect Error:', e.message);
  }

  // Save to file
  const outPath = path.join(__dirname, 'nepal_deep_discovery.json');
  fs.writeFileSync(outPath, JSON.stringify(deepDiscovery, null, 2));
  console.log(`\nDeep discovery complete! Saved to ${outPath}`);
}

main().catch(console.error);
