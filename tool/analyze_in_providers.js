const fs = require('fs');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');

const candidatePaths = [
  path.join(__dirname, 'servers', '.env'),
  path.join(__dirname, '..', 'servers', '.env'),
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

const supabase = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY);

const dtoneApiKey = env.DTONE_API_KEY;
const dtoneApiSecret = env.DTONE_API_SECRET;
const dtoneBaseUrl = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

const reloadlyClientId = env.RELOADLY_CLIENT_ID;
const reloadlyClientSecret = env.RELOADLY_CLIENT_SECRET;
const reloadlyBaseUrl = env.RELOADLY_BASE_URL || 'https://topups-sandbox.reloadly.com';
const reloadlyAuthUrl = env.RELOADLY_AUTH_URL || 'https://auth.reloadly.com/oauth/token';

const zenditApiSecret = env.ZENDIT_API_SECRET;
const zenditBaseUrl = env.ZENDIT_BASE_URL || 'https://api.zendit.io/v1';

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
  const data = await res.json();
  return data.access_token;
}

async function analyzeAll() {
  console.log('=== 1. SUPABASE CARRIERS & COUNTRY ===');
  const { data: countries } = await supabase.from('countries').select('*').ilike('name', '%India%');
  console.log('Country:', countries);
  const countryId = countries[0].id;
  const { data: carriers } = await supabase.from('carriers').select('*').eq('country_id', countryId);
  console.log('Carriers in DB:');
  for (const c of carriers) {
    console.log(` - [${c.id}] name: "${c.name}", slug: "${c.slug}", is_supported: ${c.is_supported}`);
  }

  console.log('\n=== 2. DT ONE OPERATORS & PRODUCTS ===');
  const authHeader = 'Basic ' + Buffer.from(`${dtoneApiKey}:${dtoneApiSecret}`).toString('base64');
  const opRes = await fetch(`${dtoneBaseUrl}/operators?country_iso_code=IND&per_page=100`, { headers: { Authorization: authHeader } });
  const dtOperators = await opRes.json();
  console.log(`DT One Operators (${dtOperators.length}):`);
  for (const op of dtOperators) {
    console.log(`  ID: ${op.id} | Name: "${op.name}" | Regions: ${op.regions?.length || 0}`);
  }

  let dtProducts = [];
  let page = 1;
  while (page <= 10) {
    const pRes = await fetch(`${dtoneBaseUrl}/products?country_iso_code=IND&page=${page}&per_page=100`, { headers: { Authorization: authHeader } });
    if (!pRes.ok) break;
    const prods = await pRes.json();
    if (!Array.isArray(prods) || prods.length === 0) break;
    dtProducts.push(...prods);
    if (prods.length < 100) break;
    page++;
  }
  console.log(`Total DT One Products for IND: ${dtProducts.length}`);
  
  // Group DT products by operator ID
  const dtByOp = {};
  for (const p of dtProducts) {
    const opId = p.operator?.id;
    if (!dtByOp[opId]) dtByOp[opId] = [];
    dtByOp[opId].push(p);
  }
  for (const [opId, prods] of Object.entries(dtByOp)) {
    const opName = prods[0].operator?.name;
    console.log(`  Operator ${opId} ("${opName}"): ${prods.length} products`);
    // List unique product types and prices
    const samplePrices = prods.slice(0, 5).map(p => ({
      id: p.id,
      name: p.name,
      type: p.type,
      destAmount: p.destination?.amount,
      destUnit: p.destination?.unit,
      sourceAmount: p.source?.amount,
      sourceUnit: p.source?.unit,
      wholesale: p.prices?.wholesale
    }));
    console.log(`    Sample:`, samplePrices);
  }

  console.log('\n=== 3. RELOADLY OPERATORS & DETAILS ===');
  const rlToken = await getReloadlyToken();
  const rlRes = await fetch(`${reloadlyBaseUrl}/operators/countries/IN?includeBundles=true&includeData=true&includePin=true`, {
    headers: { Authorization: `Bearer ${rlToken}`, Accept: 'application/com.reloadly.topups-v1+json' }
  });
  const rlOperators = await rlRes.json();
  console.log(`Reloadly Operators (${rlOperators.length}):`);
  for (const op of rlOperators) {
    console.log(`  ID: ${op.operatorId} | Name: "${op.name}" | Denom: ${op.denominationType} | Range: ${op.minAmount}-${op.maxAmount} ${op.senderCurrencyCode} (Local: ${op.localMinAmount}-${op.localMaxAmount} ${op.destinationCurrencyCode}) | Fixed: ${op.fixedAmounts?.length || 0} | Discount: ${op.internationalDiscount}%`);
    if (op.fixedAmounts && op.fixedAmounts.length > 0) {
      console.log(`    Fixed:`, op.fixedAmounts);
      console.log(`    Local Fixed:`, op.localFixedAmounts);
    }
  }

  console.log('\n=== 4. ZENDIT OFFERS & BRANDS ===');
  let zenditOffers = [];
  let zOffset = 0;
  let zTotal = Infinity;
  while (zOffset < zTotal && zOffset < 1000) {
    const zRes = await fetch(`${zenditBaseUrl}/topups/offers?country=IN&_limit=100&_offset=${zOffset}`, {
      headers: { Authorization: `Bearer ${zenditApiSecret}` }
    });
    if (!zRes.ok) break;
    const zData = await zRes.json();
    zTotal = zData.total || 0;
    zenditOffers.push(...(zData.list || []));
    zOffset += 100;
    if (!zData.list || zData.list.length === 0) break;
  }
  console.log(`Zendit Total Offers for IN: ${zenditOffers.length}`);
  const zByBrand = {};
  for (const o of zenditOffers) {
    const b = o.brand || 'unknown';
    if (!zByBrand[b]) zByBrand[b] = [];
    zByBrand[b].push(o);
  }
  for (const [brand, list] of Object.entries(zByBrand)) {
    console.log(`  Brand "${brand}": ${list.length} offers`);
    const ranged = list.filter(x => x.priceType === 'RANGE');
    const fixed = list.filter(x => x.priceType === 'FIXED');
    console.log(`    Ranged: ${ranged.length}, Fixed: ${fixed.length}`);
    const sample = list.slice(0, 4).map(x => ({
      offerId: x.offerId,
      name: x.name,
      cost: x.cost,
      price: x.price,
      send: x.send
    }));
    console.log(`    Sample:`, sample);
  }

  console.log('\n=== 5. DINGCONNECT PROVIDERS & PRODUCTS ===');
  const dingRes = await fetch(`${dingBaseUrl}/GetProviders?countryIsos=IN`, {
    headers: { api_key: dingApiKey }
  });
  const dingProv = await dingRes.json();
  console.log(`Ding Providers for IN: ${dingProv.Items?.length || 0}`);
  
  // For each provider, fetch products
  let dingActive = [];
  for (const p of (dingProv.Items || [])) {
    const prRes = await fetch(`${dingBaseUrl}/GetProducts?providerCodes=${p.ProviderCode}&countryIsos=IN`, {
      headers: { api_key: dingApiKey }
    });
    const prData = await prRes.json();
    if (prData.ResultCode === 1 && prData.Items && prData.Items.length > 0) {
      console.log(`  🟢 Active Provider ${p.ProviderCode} ("${p.Name}"): ${prData.Items.length} products`);
      dingActive.push({ provider: p, products: prData.Items });
      const sample = prData.Items.slice(0, 3).map(x => ({
        SkuCode: x.SkuCode,
        DefaultDisplayText: x.DefaultDisplayText,
        SendValue: x.Maximum?.SendValue,
        SendCcy: x.Maximum?.SendCurrencyIso,
        RecvValue: x.Maximum?.ReceiveValue,
        RecvCcy: x.Maximum?.ReceiveCurrencyIso,
        UatNumber: x.UatNumber,
        Validity: x.ValidityPeriodIso
      }));
      console.log(`    Sample:`, sample);
    } else {
      console.log(`  🔴 Inactive Provider ${p.ProviderCode} ("${p.Name}"): ResultCode=${prData.ResultCode}, Items=${prData.Items?.length || 0}`);
    }
  }

  fs.writeFileSync(path.join(__dirname, 'in_analysis_raw.json'), JSON.stringify({
    supabase: { carriers },
    dtone: { operators: dtOperators, products: dtProducts },
    reloadly: { operators: rlOperators },
    zendit: { offers: zenditOffers },
    ding: { active: dingActive, allProviders: dingProv.Items }
  }, null, 2));
  console.log('\nWrote full raw data to in_analysis_raw.json');
}

analyzeAll().catch(console.error);
