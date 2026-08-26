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
  const result = {
    timestamp: new Date().toISOString(),
    dtone: {},
    reloadly: {},
    zendit: {},
    ding: {}
  };

  console.log('====================================================');
  console.log('=== DEEP FETCH: ALGERIA (DZ / DZA / +213) ===');
  console.log('====================================================');

  // ==========================================
  // 1. DT ONE (DZA)
  // ==========================================
  console.log('\n--- 1. DT ONE (DZA) ---');
  try {
    const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
    const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

    // Operators
    const opRes = await fetch(`${dtBase}/operators?country_iso_code=DZA&page=1&per_page=100`, {
      headers: { Authorization: `Basic ${dtoneAuth}` }
    });
    const opData = await opRes.json();
    result.dtone.operators = opData;
    console.log(`DT One Operators:`, JSON.stringify(opData, null, 2));

    // Products (paginated)
    let allProducts = [];
    let page = 1;
    while (true) {
      const prodRes = await fetch(`${dtBase}/products?country_iso_code=DZA&page=${page}&per_page=100`, {
        headers: { Authorization: `Basic ${dtoneAuth}` }
      });
      const prods = await prodRes.json();
      if (!Array.isArray(prods) || prods.length === 0) break;
      allProducts = allProducts.concat(prods);
      console.log(`DT One Page ${page}: ${prods.length} products (Total: ${allProducts.length})`);
      if (prods.length < 100) break;
      page++;
    }
    result.dtone.products = allProducts;
    console.log(`\n=== Total DT One Algeria Products: ${allProducts.length} ===`);
    const byOp = {};
    allProducts.forEach(p => {
      const op = `[${p.operator?.id}] ${p.operator?.name}`;
      if (!byOp[op]) byOp[op] = [];
      byOp[op].push(p);
    });
    for (const [op, list] of Object.entries(byOp)) {
      console.log(`\n--- Operator: ${op} (${list.length} products) ---`);
      list.forEach(p => {
        console.log(`  ID: ${p.id} | Name: ${p.name} | Type: ${p.type} | Service: ${p.service?.name} | SubType: ${p.sub_type} | Src: ${p.source?.amount} ${p.source?.unit} | Dest: ${p.destination?.amount} ${p.destination?.unit} | Wholesale: ${p.prices?.wholesale?.amount} ${p.prices?.wholesale?.unit}`);
      });
    }
  } catch (e) {
    console.error('DT One error:', e.message);
    result.dtone.error = e.message;
  }

  // ==========================================
  // 2. RELOADLY (DZ)
  // ==========================================
  console.log('\n--- 2. RELOADLY (DZ) ---');
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
    result.reloadly.token = !!token;

    const opRes = await fetch('https://topups-sandbox.reloadly.com/operators/countries/DZ', {
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: 'application/com.reloadly.topups-v1+json'
      }
    });
    const operators = await opRes.json();
    result.reloadly.operators = operators;
    console.log(`Reloadly Operators for DZ (${operators.length || 0}):`);
    if (Array.isArray(operators)) {
      operators.forEach(op => {
        console.log(`\n[${op.operatorId}] ${op.name} (Denom: ${op.denominationType}, Bundle: ${op.bundle}, Data: ${op.data}, Pin: ${op.pin})`);
        console.log(`  FX: 1 ${op.senderCurrencyCode} = ${op.fx?.rate} ${op.fx?.currencyCode}`);
        console.log(`  Fixed Amounts (USD):`, op.fixedAmounts);
        console.log(`  Local Fixed Amounts (${op.destinationCurrencyCode}):`, op.localFixedAmounts);
        console.log(`  Descriptions:`, op.fixedAmountsDescriptions);
      });
    }
  } catch (e) {
    console.error('Reloadly error:', e.message);
    result.reloadly.error = e.message;
  }

  // ==========================================
  // 3. ZENDIT (DZ)
  // ==========================================
  console.log('\n--- 3. ZENDIT (DZ) ---');
  try {
    const zenSecret = env.ZENDIT_API_SECRET;
    const zenBase = 'https://api.zendit.io/v1';

    const offRes = await fetch(`${zenBase}/topups/offers?country=DZ&_offset=0&_limit=100`, {
      headers: { Authorization: `Bearer ${zenSecret}` }
    });
    const offers = await offRes.json();
    result.zendit.offers = offers;
    console.log(`Zendit Total Offers for DZ: ${offers.total || (offers.list ? offers.list.length : 0)}`);
    if (offers.list && offers.list.length > 0) {
      offers.list.forEach(o => {
        console.log(`  Offer: ${o.offerId} | Brand: ${o.brand} | Name: ${o.name} | Type: ${o.priceType} | Price: ${JSON.stringify(o.price)} | Send: ${JSON.stringify(o.send)} | SubTypes: ${JSON.stringify(o.subTypes)}`);
      });
    } else {
      console.log('Zendit Response:', JSON.stringify(offers, null, 2));
    }
  } catch (e) {
    console.error('Zendit error:', e.message);
    result.zendit.error = e.message;
  }

  // ==========================================
  // 4. DINGCONNECT (DZ)
  // ==========================================
  console.log('\n--- 4. DINGCONNECT (DZ) ---');
  try {
    const dingKey = env.DING_API_KEY;
    const dingBase = 'https://api.dingconnect.com/api/V1';

    // Query specific providers for Algeria telecom operators: MDDZ (Mobilis), DJDZ (Djezzy), OODZ (Ooredoo)
    const provsToTest = ['MDDZ', 'DJDZ', 'OODZ'];
    result.ding.providerProducts = {};

    for (const pCode of provsToTest) {
      await sleep(1000);
      try {
        const prodRes = await fetch(`${dingBase}/GetProducts?providerCodes=${pCode}`, {
          headers: { api_key: dingKey }
        });
        const prods = await prodRes.json();
        result.ding.providerProducts[pCode] = prods;
        console.log(`Ding Provider ${pCode} Products (${prods.Items ? prods.Items.length : 0}):`);
        if (prods.Items && prods.Items.length > 0) {
          prods.Items.forEach(p => {
            console.log(`  SkuCode: ${p.SkuCode} | ProviderCode: ${p.ProviderCode} | Name: ${p.LocalizationKey} | Min: ${JSON.stringify(p.Minimum)} | Max: ${JSON.stringify(p.Maximum)} | Validity: ${p.ValidityPeriodIso} | UatNumber: ${p.UatNumber}`);
          });
        } else {
          console.log(`  ResultCode: ${prods.ResultCode}, Errors: ${JSON.stringify(prods.ErrorCodes)}`);
        }
      } catch (err) {
        console.error(`Ding error for ${pCode}:`, err.message);
      }
    }
  } catch (e) {
    console.error('Ding error:', e.message);
    result.ding.error = e.message;
  }

  // Save to file
  const outPath = path.join(__dirname, 'algeria_detailed_raw.json');
  fs.writeFileSync(outPath, JSON.stringify(result, null, 2));
  console.log(`\nDetailed catalog saved to ${outPath}`);
}

main().catch(console.error);
