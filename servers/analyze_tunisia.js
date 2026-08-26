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
  const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
  const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

  // 1. Fetch DT One operators & products
  const opRes = await fetch(`${dtBase}/operators?country_iso_code=TUN&page=1&per_page=50`, {
    headers: { Authorization: `Basic ${dtoneAuth}` }
  });
  const dtOperators = await opRes.json();

  let dtProducts = [];
  let page = 1;
  while (true) {
    const prodRes = await fetch(`${dtBase}/products?country_iso_code=TUN&page=${page}&per_page=100`, {
      headers: { Authorization: `Basic ${dtoneAuth}` }
    });
    const products = await prodRes.json();
    if (!Array.isArray(products) || products.length === 0) break;
    dtProducts = dtProducts.concat(products);
    page++;
  }

  // 2. Fetch Reloadly
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
  const rOpRes = await fetch('https://topups-sandbox.reloadly.com/operators/countries/TN?suggestedAmounts=true&suggestedAmountsMap=true', {
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: 'application/com.reloadly.topups-v1+json'
    }
  });
  const reloadlyOperators = await rOpRes.json();

  // 3. Fetch Zendit
  const zenSecret = env.ZENDIT_API_SECRET;
  const zenBase = 'https://api.zendit.io/v1';
  let zenditOffers = [];
  let offset = 0;
  while (true) {
    const offRes = await fetch(`${zenBase}/topups/offers?country=TN&_offset=${offset}&_limit=100`, {
      headers: { Authorization: `Bearer ${zenSecret}` }
    });
    const data = await offRes.json();
    if (!data.list || data.list.length === 0) break;
    zenditOffers = zenditOffers.concat(data.list);
    offset += data.list.length;
    if (offset >= data.total) break;
  }

  // 4. Fetch DingConnect
  const dingKey = env.DING_API_KEY;
  const dingBase = 'https://api.dingconnect.com/api/V1';
  const dProvRes = await fetch(`${dingBase}/GetProviders?countryIsos=TN`, {
    headers: { api_key: dingKey }
  });
  const dingProviders = await dProvRes.json();

  console.log('======================================================');
  console.log('=== TUNISIA TELECOM SUMMARY ACROSS ALL 4 PROVIDERS ===');
  console.log('======================================================');

  console.log('\n--- 1. DT ONE (ISO-3: TUN) ---');
  console.log(`Operators found: ${dtOperators.length}`);
  dtOperators.forEach(o => console.log(`  Op ID: ${o.id} | Name: ${o.name}`));
  console.log(`Products total: ${dtProducts.length}`);
  dtOperators.forEach(o => {
    const prods = dtProducts.filter(p => p.operator?.id === o.id);
    console.log(`\n  * Operator: ${o.name} (ID: ${o.id}) -> ${prods.length} products:`);
    prods.forEach(p => {
      console.log(`    - Product ID: ${p.id} | Name: ${p.name} | Type: ${p.type} | Wholesale: ${p.prices?.wholesale?.amount} ${p.prices?.wholesale?.unit} | Retail: ${p.prices?.retail?.amount} ${p.prices?.retail?.unit} | Dest: ${p.destination?.amount} ${p.destination?.unit}`);
    });
  });

  console.log('\n--- 2. RELOADLY (ISO-2: TN) ---');
  console.log(`Operators found: ${reloadlyOperators.length}`);
  reloadlyOperators.forEach(o => {
    console.log(`\n  * Operator: ${o.name} (ID: ${o.operatorId}) | Type: ${o.denominationType} | Commission: ${o.commission}% | Sender: ${o.senderCurrencyCode} | Dest: ${o.destinationCurrencyCode} | FX: ${o.fx?.rate}`);
    if (o.denominationType === 'FIXED') {
      console.log(`    Fixed Amounts (USD):`, o.fixedAmounts);
      console.log(`    Local Fixed Amounts (TND):`, o.localFixedAmounts);
    } else {
      console.log(`    Range (USD): min ${o.minAmount}, max ${o.maxAmount} | Local (TND): min ${o.localMinAmount}, max ${o.localMaxAmount}`);
      console.log(`    Suggested Amounts (USD):`, o.suggestedAmounts);
      console.log(`    Suggested Amounts Map (USD -> TND):`, o.suggestedAmountsMap);
    }
  });

  console.log('\n--- 3. ZENDIT (country: TN) ---');
  console.log(`Total Offers found: ${zenditOffers.length}`);
  const brands = [...new Set(zenditOffers.map(o => o.brand))];
  brands.forEach(b => {
    const list = zenditOffers.filter(o => o.brand === b);
    console.log(`\n  * Brand: ${b} -> ${list.length} offers:`);
    list.forEach(o => {
      console.log(`    - Offer ID: ${o.offerId} | Name: ${o.name} | Type: ${o.priceType} | Send: ${o.send.fixed ? o.send.fixed / o.send.currencyDivisor : `${o.send.min / o.send.currencyDivisor}-${o.send.max / o.send.currencyDivisor}`} ${o.send.currency} | Wholesale Cost: $${(o.cost.fixed || o.cost.min) / o.cost.currencyDivisor} | Price: $${(o.price.fixed || o.price.min) / o.price.currencyDivisor} USD`);
    });
  });

  console.log('\n--- 4. DINGCONNECT (country: TN) ---');
  console.log(`Providers found: ${dingProviders.Items?.length || 0}`);
  if (dingProviders.Items) {
    dingProviders.Items.forEach(p => {
      console.log(`  * ProviderCode: ${p.ProviderCode} | Name: ${p.Name} | Regex: ${p.ValidationRegex}`);
    });
  }
}

main().catch(console.error);
