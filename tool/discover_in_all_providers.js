const fs = require('fs');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');

// Load environment from servers/.env
const candidatePaths = [
  path.join(__dirname, 'servers', '.env'),
  path.join(__dirname, '..', 'servers', '.env'),
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
const supabase = supabaseUrl && supabaseKey ? createClient(supabaseUrl, supabaseKey) : null;

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
  console.log('1. SUPABASE DATABASE INSPECTION (IN / India)');
  console.log('==================================================');
  if (!supabase) {
    console.log('Supabase client not initialized.');
    return;
  }

  // Country
  const { data: countries, error: cErr } = await supabase
    .from('countries')
    .select('*')
    .or('iso_2.eq.IN,iso_3.eq.IND,name.ilike.%India%');
  console.log('Countries in DB:', countries, cErr || '');

  if (countries && countries.length > 0) {
    const countryId = countries[0].id;
    // Carriers
    const { data: carriers, error: carErr } = await supabase
      .from('carriers')
      .select('*')
      .eq('country_id', countryId);
    console.log(`Carriers in DB (${carriers?.length || 0}):`, carriers, carErr || '');

    // Carrier Provider Map
    const carrierIds = (carriers || []).map(c => c.id);
    if (carrierIds.length > 0) {
      const { data: mappings, error: mapErr } = await supabase
        .from('carrier_provider_map')
        .select('*')
        .in('carrier_id', carrierIds);
      console.log(`Carrier Provider Maps (${mappings?.length || 0}):`, mappings, mapErr || '');

      // Carrier Rules
      const { data: rules, error: ruleErr } = await supabase
        .from('carrier_rules')
        .select('*')
        .in('carrier_id', carrierIds);
      console.log(`Carrier Rules (${rules?.length || 0}):`, rules, ruleErr || '');
    }
  }
}

async function discoverDTOne() {
  console.log('\n==================================================');
  console.log('2. DT ONE (IND) OPERATOR & PRODUCT DISCOVERY');
  console.log('==================================================');
  if (!dtoneApiKey || !dtoneApiSecret) {
    console.log('DT One credentials missing.');
    return;
  }
  const authHeader = 'Basic ' + Buffer.from(`${dtoneApiKey}:${dtoneApiSecret}`).toString('base64');
  
  // 1. Operators
  try {
    const opRes = await fetch(`${dtoneBaseUrl}/operators?country_iso_code=IND&per_page=100`, {
      headers: { Authorization: authHeader }
    });
    console.log(`DT One /operators?country_iso_code=IND Status: ${opRes.status}`);
    const opData = await opRes.json();
    console.log(`DT One Operators Count: ${Array.isArray(opData) ? opData.length : (opData?.length || 0)}`);
    console.log(JSON.stringify(opData, null, 2));
  } catch (err) {
    console.error('DT One Operators error:', err.message);
  }

  // 2. Products
  try {
    let allProducts = [];
    let page = 1;
    while (page <= 10) {
      const prodRes = await fetch(`${dtoneBaseUrl}/products?country_iso_code=IND&page=${page}&per_page=100`, {
        headers: { Authorization: authHeader }
      });
      if (!prodRes.ok) break;
      const prods = await prodRes.json();
      if (!Array.isArray(prods) || prods.length === 0) break;
      allProducts.push(...prods);
      if (prods.length < 100) break;
      page++;
    }
    console.log(`DT One Total Products for IND: ${allProducts.length}`);
    // Group by operator
    const byOp = {};
    for (const p of allProducts) {
      const opId = p.operator?.id || 'unknown';
      const opName = p.operator?.name || 'unknown';
      const key = `${opId} - ${opName}`;
      if (!byOp[key]) byOp[key] = [];
      byOp[key].push({
        id: p.id,
        name: p.name,
        type: p.type,
        service: p.service?.name,
        prices: p.prices,
        source: p.source,
        destination: p.destination,
        validity: p.validity
      });
    }
    console.log('DT One Products by Operator:');
    for (const [k, v] of Object.entries(byOp)) {
      console.log(`  Operator [${k}]: ${v.length} products`);
      console.log(`    Sample:`, JSON.stringify(v.slice(0, 3), null, 2));
    }
  } catch (err) {
    console.error('DT One Products error:', err.message);
  }
}

async function discoverReloadly() {
  console.log('\n==================================================');
  console.log('3. RELOADLY (IN) OPERATOR & CATALOG DISCOVERY');
  console.log('==================================================');
  if (!reloadlyClientId || !reloadlyClientSecret) {
    console.log('Reloadly credentials missing.');
    return;
  }
  try {
    const token = await getReloadlyToken();
    const res = await fetch(`${reloadlyBaseUrl}/operators/countries/IN?includeBundles=true&includeData=true&includePin=true`, {
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: 'application/com.reloadly.topups-v1+json',
      }
    });
    console.log(`Reloadly /operators/countries/IN Status: ${res.status}`);
    const data = await res.json();
    console.log(`Reloadly Operators Count: ${Array.isArray(data) ? data.length : 0}`);
    if (Array.isArray(data)) {
      for (const op of data) {
        console.log(`--------------------------------------------------`);
        console.log(`Operator ID: ${op.operatorId} | Name: ${op.name} | Bundle: ${op.bundle} | Data: ${op.data} | Pin: ${op.pin}`);
        console.log(`Denomination Type: ${op.denominationType} | Sender CCY: ${op.senderCurrencyCode} | Dest CCY: ${op.destinationCurrencyCode}`);
        console.log(`Min: ${op.minAmount}, Max: ${op.maxAmount}, LocalMin: ${op.localMinAmount}, LocalMax: ${op.localMaxAmount}`);
        console.log(`Fixed Amounts:`, op.fixedAmounts);
        console.log(`Local Fixed Amounts:`, op.localFixedAmounts);
        console.log(`Fx Rate:`, op.fx);
        console.log(`International Discount:`, op.internationalDiscount, `Local Discount:`, op.localDiscount);
      }
    } else {
      console.log(JSON.stringify(data, null, 2));
    }
  } catch (err) {
    console.error('Reloadly Discovery error:', err.message);
  }
}

async function discoverZendit() {
  console.log('\n==================================================');
  console.log('4. ZENDIT (IN) OFFERS & BRANDS DISCOVERY');
  console.log('==================================================');
  if (!zenditApiSecret) {
    console.log('Zendit credentials missing.');
    return;
  }
  try {
    let allOffers = [];
    let offset = 0;
    let total = Infinity;
    while (offset < total && offset < 1000) {
      const url = `${zenditBaseUrl}/topups/offers?country=IN&_limit=100&_offset=${offset}`;
      const res = await fetch(url, {
        headers: { Authorization: `Bearer ${zenditApiSecret}` }
      });
      if (!res.ok) {
        console.log(`Zendit error ${res.status}: ${await res.text()}`);
        break;
      }
      const data = await res.json();
      total = data.total || 0;
      allOffers.push(...(data.list || []));
      offset += 100;
      if (!data.list || data.list.length === 0) break;
    }
    console.log(`Zendit Total Offers for IN: ${allOffers.length} (Total reported: ${total})`);
    // Group by brand
    const byBrand = {};
    for (const o of allOffers) {
      const brand = o.brand || 'unknown';
      if (!byBrand[brand]) byBrand[brand] = [];
      byBrand[brand].push(o);
    }
    console.log('Zendit Offers by Brand:');
    for (const [brand, list] of Object.entries(byBrand)) {
      console.log(`  Brand: [${brand}] -> ${list.length} offers`);
      const sample = list.slice(0, 3).map(x => ({
        offerId: x.offerId,
        name: x.name,
        productType: x.productType,
        subTypes: x.subTypes,
        priceType: x.priceType,
        cost: x.cost,
        price: x.price,
        send: x.send
      }));
      console.log(`    Sample:`, JSON.stringify(sample, null, 2));
    }
  } catch (err) {
    console.error('Zendit Discovery error:', err.message);
  }
}

async function discoverDingConnect() {
  console.log('\n==================================================');
  console.log('5. DINGCONNECT (IN) PROVIDERS & PRODUCTS DISCOVERY');
  console.log('==================================================');
  if (!dingApiKey) {
    console.log('DingConnect API Key missing.');
    return;
  }
  // 1. GetProviders
  let providerCodes = [];
  try {
    const res = await fetch(`${dingBaseUrl}/GetProviders?countryIsos=IN`, {
      headers: { api_key: dingApiKey }
    });
    console.log(`DingConnect /GetProviders?countryIsos=IN Status: ${res.status}`);
    const data = await res.json();
    console.log(`Ding Providers ResultCode: ${data.ResultCode}, ErrorCodes:`, data.ErrorCodes);
    if (data.Items) {
      console.log(`Ding Providers Count: ${data.Items.length}`);
      for (const item of data.Items) {
        console.log(`  ProviderCode: ${item.ProviderCode} | Name: ${item.Name} | ShortName: ${item.ShortName} | Status: ${item.Status} | ValidationRegex: ${item.ValidationRegex}`);
        providerCodes.push(item.ProviderCode);
      }
    }
  } catch (err) {
    console.error('Ding Providers error:', err.message);
  }

  // 2. GetProducts for each provider
  for (const pCode of providerCodes) {
    try {
      const res = await fetch(`${dingBaseUrl}/GetProducts?providerCodes=${pCode}&countryIsos=IN`, {
        headers: { api_key: dingApiKey }
      });
      const data = await res.json();
      console.log(`\nDing Provider [${pCode}] Products: ResultCode=${data.ResultCode}, Count=${data.Items?.length || 0}`);
      if (data.Items && data.Items.length > 0) {
        const sample = data.Items.slice(0, 3).map(p => ({
          SkuCode: p.SkuCode,
          LocalizationKey: p.LocalizationKey,
          DefaultDisplayText: p.DefaultDisplayText,
          RegionCode: p.RegionCode,
          LookupBillsRequired: p.LookupBillsRequired,
          Maximum: p.Maximum,
          Minimum: p.Minimum,
          Benefits: p.Benefits,
          ValidityPeriodIso: p.ValidityPeriodIso,
          UatNumber: p.UatNumber
        }));
        console.log(`  Sample Products:`, JSON.stringify(sample, null, 2));
      }
    } catch (err) {
      console.error(`Ding Products error for ${pCode}:`, err.message);
    }
  }
}

async function main() {
  await discoverDatabase();
  await discoverDTOne();
  await discoverReloadly();
  await discoverZendit();
  await discoverDingConnect();
}

main().catch(console.error);
