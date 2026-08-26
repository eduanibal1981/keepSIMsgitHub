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

async function runAnalysis() {
  console.log('====================================================');
  console.log('PHILIPPINES (PH / +63) ALL-PROVIDER COMPREHENSIVE SCAN');
  console.log('====================================================\n');

  // 1. SUPABASE
  console.log('--- 1. SUPABASE DATABASE ---');
  const sampleCountry = await querySupabase('countries?select=*&limit=1');
  console.log('Country table sample columns:', sampleCountry ? Object.keys(sampleCountry[0]) : 'None');
  
  const phCountries = await querySupabase('countries?select=*&name=ilike.*Philippines*');
  console.log('Philippines Country in DB:', phCountries);

  let phCountryId = phCountries && phCountries.length > 0 ? phCountries[0].id : null;
  if (phCountryId) {
    const carriers = await querySupabase(`carriers?select=*&country_id=eq.${phCountryId}`);
    console.log(`Current PH Carriers (${carriers?.length || 0}):`, carriers);
    
    if (carriers && carriers.length > 0) {
      const cIds = carriers.map(c => c.id);
      const maps = await querySupabase(`carrier_provider_map?select=*&carrier_id=in.(${cIds.join(',')})`);
      console.log(`Current Mappings (${maps?.length || 0}):`, maps);
      const rules = await querySupabase(`carrier_rules?select=*&carrier_id=in.(${cIds.join(',')})`);
      console.log(`Current Rules (${rules?.length || 0}):`, rules);
    }
  }

  // 2. DT ONE
  console.log('\n--- 2. DT ONE (PHL) ---');
  const dtAuth = 'Basic ' + Buffer.from(`${dtoneApiKey}:${dtoneApiSecret}`).toString('base64');
  const dtOpRes = await fetch(`${dtoneBaseUrl}/operators?country_iso_code=PHL&per_page=100`, {
    headers: { Authorization: dtAuth }
  });
  const dtOps = await dtOpRes.json();
  console.log(`DT One Operators (${dtOps?.length || 0}):`);
  dtOps.forEach(op => console.log(`  ID: ${op.id} | Name: ${op.name}`));

  let dtProducts = [];
  let page = 1;
  while (page <= 20) {
    const pRes = await fetch(`${dtoneBaseUrl}/products?country_iso_code=PHL&page=${page}&per_page=100`, {
      headers: { Authorization: dtAuth }
    });
    if (!pRes.ok) break;
    const prods = await pRes.json();
    if (!Array.isArray(prods) || prods.length === 0) break;
    dtProducts.push(...prods);
    if (prods.length < 100) break;
    page++;
  }
  console.log(`DT One Total Products: ${dtProducts.length}`);
  fs.writeFileSync(path.join(__dirname, 'dtone_ph_products.json'), JSON.stringify(dtProducts, null, 2));

  // Breakdown DT One telecom products
  const telecomOpIds = [246, 570, 1934, 2897, 2952, 3128]; // Globe, Smart, SmartBro, TNT, Smart Home Wifi, Touch Mobile, plus check DITO if any
  const dtTelecomProds = dtProducts.filter(p => telecomOpIds.includes(p.operator?.id) || p.name?.toLowerCase().includes('dito') || p.name?.toLowerCase().includes('globe') || p.name?.toLowerCase().includes('smart') || p.name?.toLowerCase().includes('tnt') || p.name?.toLowerCase().includes('touch mobile') || p.name?.toLowerCase().includes('tm'));
  console.log(`DT One Telecom Products Count: ${dtTelecomProds.length}`);

  // 3. RELOADLY
  console.log('\n--- 3. RELOADLY (PH) ---');
  const rlToken = await getReloadlyToken();
  const rlRes = await fetch(`${reloadlyBaseUrl}/operators/countries/PH?includeBundles=true&includeData=true&includePin=true`, {
    headers: {
      Authorization: `Bearer ${rlToken}`,
      Accept: 'application/com.reloadly.topups-v1+json',
    }
  });
  const rlOps = await rlRes.json();
  console.log(`Reloadly Operators Count: ${Array.isArray(rlOps) ? rlOps.length : 0}`);
  fs.writeFileSync(path.join(__dirname, 'reloadly_ph_operators.json'), JSON.stringify(rlOps, null, 2));
  if (Array.isArray(rlOps)) {
    rlOps.forEach(op => {
      console.log(`  ID: ${op.operatorId} | Name: ${op.name} | Bundle: ${op.bundle} | Data: ${op.data} | Pin: ${op.pin} | Denom: ${op.denominationType} (${op.minAmount}-${op.maxAmount} ${op.senderCurrencyCode}) | Fixed: ${JSON.stringify(op.fixedAmounts)}`);
    });
  }

  // 4. ZENDIT
  console.log('\n--- 4. ZENDIT (PH) ---');
  let zenOffers = [];
  let offset = 0;
  while (offset < 1000) {
    const zRes = await fetch(`${zenditBaseUrl}/topups/offers?country=PH&_limit=100&_offset=${offset}`, {
      headers: { Authorization: `Bearer ${zenditApiSecret}` }
    });
    if (!zRes.ok) break;
    const zData = await zRes.json();
    zenOffers.push(...(zData.list || []));
    if (!zData.list || zData.list.length === 0 || zenOffers.length >= zData.total) break;
    offset += 100;
  }
  console.log(`Zendit Total Offers for PH: ${zenOffers.length}`);
  fs.writeFileSync(path.join(__dirname, 'zendit_ph_offers.json'), JSON.stringify(zenOffers, null, 2));
  const zenByBrand = {};
  zenOffers.forEach(o => {
    const b = o.brand || 'unknown';
    if (!zenByBrand[b]) zenByBrand[b] = [];
    zenByBrand[b].push(o);
  });
  console.log('Zendit Offers by Brand:');
  for (const [b, list] of Object.entries(zenByBrand)) {
    console.log(`  Brand [${b}]: ${list.length} offers | Types: ${[...new Set(list.map(x => x.productType))].join(', ')}`);
  }

  // 5. DINGCONNECT
  console.log('\n--- 5. DINGCONNECT (PH) ---');
  const dingRes = await fetch(`${dingBaseUrl}/GetProviders?countryIsos=PH`, {
    headers: { api_key: dingApiKey }
  });
  const dingData = await dingRes.json();
  const allDingProviders = dingData.Items || [];
  console.log(`DingConnect Total Providers in PH: ${allDingProviders.length}`);
  
  // Filter telecom / major operators
  const targetKeywords = ['globe', 'smart', 'dito', 'touch mobile', 'tm', 'talk', 'tnt', 'sun', 'pldt', 'cherry', 'gomo'];
  const telecomDingProviders = allDingProviders.filter(p => {
    const name = (p.Name || '').toLowerCase();
    const short = (p.ShortName || '').toLowerCase();
    return targetKeywords.some(k => name.includes(k) || short.includes(k));
  });
  console.log(`DingConnect Telecom Providers matched: ${telecomDingProviders.length}`);
  telecomDingProviders.forEach(p => {
    console.log(`  ProviderCode: ${p.ProviderCode} | Name: ${p.Name} | ShortName: ${p.ShortName} | Status: ${p.Status} | Regex: ${p.ValidationRegex}`);
  });

  // Query products for matched telecom providers and a few additional
  const dingTelecomProducts = {};
  for (const p of telecomDingProviders) {
    const pRes = await fetch(`${dingBaseUrl}/GetProducts?providerCodes=${p.ProviderCode}&countryIsos=PH`, {
      headers: { api_key: dingApiKey }
    });
    const pData = await pRes.json();
    console.log(`  Ding [${p.ProviderCode} - ${p.Name}]: ResultCode=${pData.ResultCode}, Products=${pData.Items?.length || 0}`);
    if (pData.Items && pData.Items.length > 0) {
      dingTelecomProducts[p.ProviderCode] = pData.Items;
    }
  }
  fs.writeFileSync(path.join(__dirname, 'ding_ph_telecom_products.json'), JSON.stringify({ providers: telecomDingProviders, products: dingTelecomProducts }, null, 2));

  console.log('\n--- SCAN COMPLETED ---');
}

runAnalysis().catch(console.error);
