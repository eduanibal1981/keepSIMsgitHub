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

const sleep = ms => new Promise(r => setTimeout(r, ms));

async function main() {
  const report = {};

  // ==========================================
  // 1. DT ONE DISCOVERY
  // ==========================================
  console.log('=== 1. DT ONE DISCOVERY ===');
  try {
    const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
    const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

    const opRes = await fetch(`${dtBase}/operators?country_iso_code=TUR&page=1&per_page=50`, {
      headers: { Authorization: `Basic ${dtoneAuth}` }
    });
    const operators = await opRes.json();
    report.dtone_operators = operators;

    const prodRes = await fetch(`${dtBase}/products?country_iso_code=TUR&page=1&per_page=100`, {
      headers: { Authorization: `Basic ${dtoneAuth}` }
    });
    const products = await prodRes.json();
    report.dtone_products = products;

    console.log(`DT One found ${operators.length} operators and ${products.length} products for TUR.`);
    operators.forEach(op => console.log(`  Op ID: ${op.id} | Name: ${op.name}`));
  } catch (e) {
    console.error('DT One Error:', e.message);
  }

  // ==========================================
  // 2. RELOADLY DISCOVERY
  // ==========================================
  console.log('\n=== 2. RELOADLY DISCOVERY ===');
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
    report.reloadly_token = !!token;

    const opRes = await fetch('https://topups-sandbox.reloadly.com/operators/countries/TR', {
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: 'application/com.reloadly.topups-v1+json'
      }
    });
    const operators = await opRes.json();
    report.reloadly_operators = operators;
    console.log(`Reloadly found ${operators.length} operators for TR.`);
    operators.forEach(op => {
      console.log(`  Op ID: ${op.operatorId} | Name: ${op.name} | Bundles: ${op.bundle} | Data: ${op.data} | Pin: ${op.pin} | Denoms: ${op.fixedAmounts ? op.fixedAmounts.length : (op.minAmount + '-' + op.maxAmount)}`);
    });
  } catch (e) {
    console.error('Reloadly Error:', e.message);
  }

  // ==========================================
  // 3. ZENDIT DISCOVERY
  // ==========================================
  console.log('\n=== 3. ZENDIT DISCOVERY ===');
  try {
    const zenSecret = env.ZENDIT_API_SECRET;
    const zenBase = 'https://api.zendit.io/v1';

    const offRes = await fetch(`${zenBase}/topups/offers?country=TR&_limit=100&_offset=0`, {
      headers: { Authorization: `Bearer ${zenSecret}` }
    });
    const offers = await offRes.json();
    report.zendit_offers = offers;
    console.log(`Zendit found ${offers.total || (offers.list ? offers.list.length : 0)} offers for TR.`);
    if (offers.list) {
      offers.list.forEach(o => {
        console.log(`  OfferId: ${o.offerId} | Brand: ${o.brand} | Name: ${o.name} | Type: ${o.priceType} | Price: ${o.price?.fixed || (o.price?.min + '-' + o.price?.max)} ${o.price?.currency} | Send: ${o.send?.fixed || (o.send?.min + '-' + o.send?.max)} ${o.send?.currency}`);
      });
    }
  } catch (e) {
    console.error('Zendit Error:', e.message);
  }

  // ==========================================
  // 4. DINGCONNECT DISCOVERY
  // ==========================================
  console.log('\n=== 4. DINGCONNECT DISCOVERY ===');
  try {
    const dingKey = env.DING_API_KEY;
    const dingBase = 'https://api.dingconnect.com/api/V1';

    const provRes = await fetch(`${dingBase}/GetProviders?countryIsos=TR`, {
      headers: { api_key: dingKey }
    });
    const providers = await provRes.json();
    report.ding_providers = providers;
    console.log(`Ding found ${providers.Items ? providers.Items.length : 0} providers for TR.`);

    const telecomProviders = (providers.Items || []).filter(p => ['TZTR', 'VFTR', 'AVTR'].includes(p.ProviderCode));
    report.ding_products = {};

    for (const p of telecomProviders) {
      await sleep(1200);
      const prodRes = await fetch(`${dingBase}/GetProducts?providerCodes=${p.ProviderCode}&countryIsos=TR`, {
        headers: { api_key: dingKey }
      });
      const prodData = await prodRes.json();
      report.ding_products[p.ProviderCode] = prodData;
      console.log(`  Provider ${p.ProviderCode} (${p.Name}): ResultCode: ${prodData.ResultCode}, Products: ${prodData.Items ? prodData.Items.length : 0}`);
    }
  } catch (e) {
    console.error('Ding Error:', e.message);
  }

  fs.writeFileSync(path.join(__dirname, 'turkey_discovery_raw.json'), JSON.stringify(report, null, 2));
  console.log('\nSaved full discovery raw data to servers/turkey_discovery_raw.json');
}

main();
