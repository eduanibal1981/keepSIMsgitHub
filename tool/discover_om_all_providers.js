const fs = require('fs');
const path = require('path');

// Load environment from servers/.env
const candidatePaths = [
  path.join(__dirname, '..', 'servers', '.env'),
  path.join(__dirname, 'servers', '.env'),
  path.join(__dirname, '.env'),
  '/home/abdal/keepsims_backend/servers/.env'
];
let env = {};
for (const p of candidatePaths) {
  if (fs.existsSync(p)) {
    const content = fs.readFileSync(p, 'utf8');
    content.split('\n').forEach(line => {
      const m = line.match(/^\s*([\w_]+)\s*=\s*(.*)?\s*$/);
      if (m) {
        let v = (m[2] || '').trim();
        if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) {
          v = v.slice(1, -1);
        }
        env[m[1]] = v;
      }
    });
    break;
  }
}

const supabaseUrl = env.SUPABASE_URL || process.env.SUPABASE_URL;
const supabaseKey = env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY;

// Supabase REST helper
async function querySupabase(endpoint, options = {}) {
  if (!supabaseUrl || !supabaseKey) {
    console.log('Supabase credentials missing.');
    return null;
  }
  const url = `${supabaseUrl}/rest/v1/${endpoint}`;
  const res = await fetch(url, {
    ...options,
    headers: {
      'apikey': supabaseKey,
      'Authorization': `Bearer ${supabaseKey}`,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
      ...(options.headers || {})
    }
  });
  if (!res.ok) {
    const text = await res.text();
    console.error(`Supabase error ${res.status} on ${endpoint}:`, text);
    return null;
  }
  return await res.json();
}

// DT One
const dtoneApiKey = env.DTONE_API_KEY;
const dtoneApiSecret = env.DTONE_API_SECRET;
const dtoneBaseUrl = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

// Reloadly
const reloadlyClientId = env.RELOADLY_CLIENT_ID;
const reloadlyClientSecret = env.RELOADLY_CLIENT_SECRET;
const reloadlyBaseUrl = env.RELOADLY_BASE_URL || 'https://topups-sandbox.reloadly.com';
const reloadlyAuthUrl = env.RELOADLY_AUTH_URL || 'https://auth.reloadly.com/oauth/token';

// Zendit
const zenditApiSecret = env.ZENDIT_API_SECRET;
const zenditBaseUrl = env.ZENDIT_BASE_URL || 'https://api.zendit.io/v1';

// DingConnect
const dingApiKey = env.DING_API_KEY;
const dingBaseUrl = env.DING_BASE_URL || 'https://api.dingconnect.com/api/V1';

async function getReloadlyToken() {
  const audience = reloadlyBaseUrl.replace(/\/$/, '');
  const res = await fetch(reloadlyAuthUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client_id: reloadlyClientId,
      client_secret: reloadlyClientSecret,
      grant_type: 'client_credentials',
      audience: audience,
    }),
  });
  if (!res.ok) {
    throw new Error(`Reloadly Auth Failed ${res.status}: ${await res.text()}`);
  }
  const data = await res.json();
  return data.access_token;
}

async function discoverDatabase() {
  console.log('\n==================================================');
  console.log('1. SUPABASE DATABASE INSPECTION (OM / Oman)');
  console.log('==================================================');
  
  // Country
  const countries = await querySupabase('countries?select=*&or=(iso_2.eq.OM,iso_3.eq.OMN,name.ilike.*Oman*)');
  console.log('Countries in DB:', countries);

  if (countries && countries.length > 0) {
    const countryId = countries[0].id;
    // Carriers
    const carriers = await querySupabase(`carriers?select=*&country_id=eq.${countryId}`);
    console.log(`Carriers in DB (${carriers?.length || 0}):`, JSON.stringify(carriers, null, 2));

    // Carrier Provider Map
    const carrierIds = (carriers || []).map(c => c.id);
    if (carrierIds.length > 0) {
      const mappings = await querySupabase(`carrier_provider_map?select=*&carrier_id=in.(${carrierIds.join(',')})`);
      console.log(`Carrier Provider Maps (${mappings?.length || 0}):`, JSON.stringify(mappings, null, 2));

      // Carrier Rules
      const rules = await querySupabase(`carrier_rules?select=*&carrier_id=in.(${carrierIds.join(',')})`);
      console.log(`Carrier Rules (${rules?.length || 0}):`, JSON.stringify(rules, null, 2));
    }
  }
}

async function discoverDTOne() {
  console.log('\n==================================================');
  console.log('2. DT ONE (OMN) OPERATOR & PRODUCT DISCOVERY');
  console.log('==================================================');
  if (!dtoneApiKey || !dtoneApiSecret) {
    console.log('DT One credentials missing.');
    return;
  }
  const authHeader = 'Basic ' + Buffer.from(`${dtoneApiKey}:${dtoneApiSecret}`).toString('base64');
  
  // 1. Operators
  try {
    const opRes = await fetch(`${dtoneBaseUrl}/operators?country_iso_code=OMN&per_page=100`, {
      headers: { Authorization: authHeader }
    });
    console.log(`DT One /operators?country_iso_code=OMN Status: ${opRes.status}`);
    const opData = await opRes.json();
    console.log(`DT One Operators Count: ${Array.isArray(opData) ? opData.length : 0}`);
    console.log(JSON.stringify(opData, null, 2));
    fs.writeFileSync(path.join(__dirname, 'dtone_om_operators.json'), JSON.stringify(opData, null, 2));
  } catch (err) {
    console.error('DT One Operators error:', err.message);
  }

  // 2. Products
  try {
    let allProducts = [];
    let page = 1;
    while (page <= 20) {
      const prodRes = await fetch(`${dtoneBaseUrl}/products?country_iso_code=OMN&page=${page}&per_page=100`, {
        headers: { Authorization: authHeader }
      });
      if (!prodRes.ok) break;
      const data = await prodRes.json();
      if (!Array.isArray(data) || data.length === 0) break;
      allProducts.push(...data);
      if (data.length < 100) break;
      page++;
    }
    console.log(`DT One Products Total Count: ${allProducts.length}`);
    fs.writeFileSync(path.join(__dirname, 'dtone_om_products.json'), JSON.stringify(allProducts, null, 2));
    
    // Group products by operator
    const byOp = {};
    for (const p of allProducts) {
      const opName = p.operator?.name || 'Unknown';
      if (!byOp[opName]) byOp[opName] = [];
      byOp[opName].push({
        id: p.id,
        name: p.name,
        type: p.type,
        service: p.service?.name,
        destination: p.destination,
        source: p.source,
        prices: p.prices
      });
    }
    console.log('DT One Products by Operator:');
    for (const [op, prods] of Object.entries(byOp)) {
      console.log(`  - ${op}: ${prods.length} products`);
      console.log(`    Sample:`, prods.slice(0, 3));
    }
  } catch (err) {
    console.error('DT One Products error:', err.message);
  }
}

async function discoverReloadly() {
  console.log('\n==================================================');
  console.log('3. RELOADLY (OM) OPERATOR & PRODUCT DISCOVERY');
  console.log('==================================================');
  if (!reloadlyClientId || !reloadlyClientSecret) {
    console.log('Reloadly credentials missing.');
    return;
  }
  try {
    const token = await getReloadlyToken();
    const res = await fetch(`${reloadlyBaseUrl}/operators/countries/OM?includeBundles=true&includeData=true&includePin=true`, {
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: 'application/com.reloadly.topups-v1+json'
      }
    });
    console.log(`Reloadly /operators/countries/OM Status: ${res.status}`);
    const data = await res.json();
    console.log(`Reloadly Operators Count: ${Array.isArray(data) ? data.length : 0}`);
    fs.writeFileSync(path.join(__dirname, 'reloadly_om_operators.json'), JSON.stringify(data, null, 2));
    if (Array.isArray(data)) {
      for (const op of data) {
        console.log(`  - Operator ID: ${op.operatorId}, Name: ${op.name}, Bundle: ${op.bundle}, Data: ${op.data}, Pin: ${op.pin}, DenomType: ${op.denominationType}`);
        console.log(`    Fixed Amounts: ${JSON.stringify(op.fixedAmounts)}, Local Fixed Amounts: ${JSON.stringify(op.localFixedAmounts)}`);
        console.log(`    Min/Max Amount: ${op.minAmount} - ${op.maxAmount}, FX Rate: ${op.fx?.rate}, Currency: ${op.destinationCurrencyCode}`);
      }
    }
  } catch (err) {
    console.error('Reloadly error:', err.message);
  }
}

async function discoverZendit() {
  console.log('\n==================================================');
  console.log('4. ZENDIT (OM) OFFERS & BRANDS DISCOVERY');
  console.log('==================================================');
  if (!zenditApiSecret) {
    console.log('Zendit credentials missing.');
    return;
  }
  try {
    let allOffers = [];
    let pageOffset = 0;
    while (pageOffset < 500) {
      const res = await fetch(`${zenditBaseUrl}/topups/offers?country=OM&_limit=100&_offset=${pageOffset}`, {
        headers: {
          'Authorization': `Bearer ${zenditApiSecret}`,
          'Content-Type': 'application/json'
        }
      });
      console.log(`Zendit /topups/offers?country=OM (offset ${pageOffset}) Status: ${res.status}`);
      if (!res.ok) {
        const txt = await res.text();
        console.log('Zendit error body:', txt);
        break;
      }
      const data = await res.json();
      const list = data.list || [];
      if (list.length === 0) break;
      allOffers.push(...list);
      if (list.length < 100) break;
      pageOffset += 100;
    }
    console.log(`Zendit OM Offers Total Count: ${allOffers.length}`);
    fs.writeFileSync(path.join(__dirname, 'zendit_om_offers.json'), JSON.stringify(allOffers, null, 2));
    
    // Group offers by brand
    const byBrand = {};
    for (const off of allOffers) {
      const brand = off.brand || 'Unknown';
      if (!byBrand[brand]) byBrand[brand] = [];
      byBrand[brand].push({
        offerId: off._id || off.id || off.offerId,
        brand: off.brand,
        cost: off.cost,
        price: off.price,
        sendValue: off.sendValue,
        sendCurrency: off.sendCurrency,
        receiveValue: off.receiveValue,
        receiveCurrency: off.receiveCurrency,
        type: off.type,
        subtype: off.subtype,
        description: off.description
      });
    }
    console.log('Zendit Offers by Brand:');
    for (const [b, offs] of Object.entries(byBrand)) {
      console.log(`  - ${b}: ${offs.length} offers`);
      console.log(`    Sample:`, offs.slice(0, 3));
    }
  } catch (err) {
    console.error('Zendit error:', err.message);
  }
}

async function discoverDingConnect() {
  console.log('\n==================================================');
  console.log('5. DINGCONNECT (OM) PROVIDER & PRODUCT DISCOVERY');
  console.log('==================================================');
  if (!dingApiKey) {
    console.log('DingConnect credentials missing.');
    return;
  }
  try {
    // 1. Providers
    const provRes = await fetch(`${dingBaseUrl}/GetProviders?countryIsos=OM`, {
      headers: {
        'api_key': dingApiKey,
        'Content-Type': 'application/json'
      }
    });
    console.log(`DingConnect /GetProviders?countryIsos=OM Status: ${provRes.status}`);
    const provData = await provRes.json();
    console.log(`DingConnect Providers ResultCode: ${provData.ResultCode}, Count: ${provData.Items?.length || 0}`);
    fs.writeFileSync(path.join(__dirname, 'ding_om_providers.json'), JSON.stringify(provData, null, 2));
    
    const telecomCodes = ['OMOM', 'OOOM', 'VFOM'];
    let allProducts = [];
    for (const provCode of telecomCodes) {
      console.log(`\n--- Fetching Ding products for ${provCode} ---`);
      const prodRes = await fetch(`${dingBaseUrl}/GetProducts?providerCodes=${provCode}&countryIsos=OM`, {
        headers: {
          'api_key': dingApiKey,
          'Content-Type': 'application/json'
        }
      });
      console.log(`DingConnect /GetProducts?providerCodes=${provCode} Status: ${prodRes.status}`);
      if (prodRes.ok) {
        const prodData = await prodRes.json();
        console.log(`DingConnect ${provCode} ResultCode: ${prodData.ResultCode}, Items: ${prodData.Items?.length || 0}`);
        if (prodData.Items && prodData.Items.length > 0) {
          allProducts.push(...prodData.Items);
          console.log(`Sample product for ${provCode}:`, JSON.stringify(prodData.Items[0], null, 2));
        }
      }
      await new Promise(r => setTimeout(r, 800));
    }
    fs.writeFileSync(path.join(__dirname, 'ding_om_products.json'), JSON.stringify(allProducts, null, 2));
    console.log(`DingConnect Total Mobile Products: ${allProducts.length}`);
  } catch (err) {
    console.error('DingConnect error:', err.message);
  }
}

async function run() {
  await discoverDatabase();
  await discoverDTOne();
  await discoverReloadly();
  await discoverZendit();
  await discoverDingConnect();
  console.log('\n==================================================');
  console.log('DISCOVERY COMPLETE');
  console.log('==================================================');
}

run().catch(console.error);
