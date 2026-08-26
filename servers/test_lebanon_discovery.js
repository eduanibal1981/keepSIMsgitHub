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

const SUPABASE_URL = env.SUPABASE_URL;
const SUPABASE_KEY = env.SUPABASE_SERVICE_ROLE_KEY;

async function supabaseApi(endpoint) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${endpoint}`, {
    headers: {
      'apikey': SUPABASE_KEY,
      'Authorization': `Bearer ${SUPABASE_KEY}`,
      'Content-Type': 'application/json'
    }
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Supabase error ${res.status}: ${text}`);
  }
  return await res.json();
}

async function main() {
  console.log('====================================================');
  console.log('=== DISCOVERING LEBANON (LB / LBN / +961) TELECOMS ===');
  console.log('====================================================\n');

  const discoveryOutput = {
    supabase: {},
    dtone: {},
    reloadly: {},
    zendit: {},
    ding: {}
  };

  // 0. Supabase Check
  console.log('--- 0. SUPABASE CURRENT STATUS FOR LEBANON ---');
  try {
    const countries = await supabaseApi('countries?iso_code=in.(LB,LBN)&select=*');
    console.log('Supabase Country record:', JSON.stringify(countries, null, 2));
    discoveryOutput.supabase.countries = countries;
    if (countries.length > 0) {
      const countryId = countries[0].id;
      const carriers = await supabaseApi(`carriers?country_id=eq.${countryId}&select=*`);
      console.log(`Carriers in Supabase (${carriers.length}):`, JSON.stringify(carriers, null, 2));
      discoveryOutput.supabase.carriers = carriers;
      discoveryOutput.supabase.carrier_rules = [];
      discoveryOutput.supabase.carrier_provider_map = [];
      for (const c of carriers) {
        const rules = await supabaseApi(`carrier_rules?carrier_id=eq.${c.id}&select=*`);
        const map = await supabaseApi(`carrier_provider_map?carrier_id=eq.${c.id}&select=*`);
        console.log(`Carrier ${c.name} (ID: ${c.id}): ${rules.length} rules, ${map.length} provider maps`);
        discoveryOutput.supabase.carrier_rules.push(...rules);
        discoveryOutput.supabase.carrier_provider_map.push(...map);
      }
    }
  } catch (err) {
    console.error('Supabase Error:', err.message);
    discoveryOutput.supabase.error = err.message;
  }

  // 1. DT ONE
  console.log('\n--- 1. DT ONE (LBN / LB) ---');
  try {
    const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
    const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

    // Get operators
    const opRes = await fetch(`${dtBase}/operators?country_iso_code=LBN&page=1&per_page=50`, {
      headers: { Authorization: `Basic ${dtoneAuth}` }
    });
    console.log(`DT One Operators Status: ${opRes.status}`);
    const operators = await opRes.json();
    console.log('DT One Operators:', JSON.stringify(operators, null, 2));
    discoveryOutput.dtone.operators = operators;

    // Get products
    const prodRes = await fetch(`${dtBase}/products?country_iso_code=LBN&page=1&per_page=100`, {
      headers: { Authorization: `Basic ${dtoneAuth}` }
    });
    console.log(`DT One Products Status: ${prodRes.status}`);
    const products = await prodRes.json();
    console.log(`DT One Total Products: ${Array.isArray(products) ? products.length : 'N/A'}`);
    discoveryOutput.dtone.products = products;
    if (Array.isArray(products)) {
      products.forEach(p => {
        console.log(`ID: ${p.id} | Name: ${p.name} | Operator: ${p.operator?.id} (${p.operator?.name}) | Type: ${p.type} | Prices: ${JSON.stringify(p.prices?.wholesale || p.source || p.prices)} | Dest: ${JSON.stringify(p.destination)} | Validity: ${p.validity?.quantity} ${p.validity?.unit}`);
      });
    }
  } catch (err) {
    console.error('DT One Error:', err.message);
    discoveryOutput.dtone.error = err.message;
  }

  // 2. RELOADLY
  console.log('\n--- 2. RELOADLY (LB) ---');
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
      discoveryOutput.reloadly.authError = authData;
    } else {
      const token = authData.access_token;
      console.log('Reloadly Auth Success');
      const opRes = await fetch('https://topups-sandbox.reloadly.com/operators/countries/LB', {
        headers: {
          Authorization: `Bearer ${token}`,
          Accept: 'application/com.reloadly.topups-v1+json'
        }
      });
      console.log(`Reloadly Operators Status: ${opRes.status}`);
      const operators = await opRes.json();
      console.log('Reloadly Operators Count:', Array.isArray(operators) ? operators.length : 'N/A');
      discoveryOutput.reloadly.operators = operators;
      if (Array.isArray(operators)) {
        operators.forEach(op => {
          console.log(`[Reloadly] ID: ${op.operatorId} | Name: ${op.name} | Bundle: ${op.bundle} | Data: ${op.data} | Pin: ${op.pin} | DenomType: ${op.denominationType} | SenderCur: ${op.senderCurrencyCode} | DestCur: ${op.destinationCurrencyCode} | Min: ${op.minAmount} | Max: ${op.maxAmount} | FixedAmounts: ${JSON.stringify(op.fixedAmounts)} | FixedDesc: ${JSON.stringify(op.fixedAmountsDescriptions)}`);
        });
      }
    }
  } catch (err) {
    console.error('Reloadly Error:', err.message);
    discoveryOutput.reloadly.error = err.message;
  }

  // 3. ZENDIT
  console.log('\n--- 3. ZENDIT (LB) ---');
  try {
    const zenSecret = env.ZENDIT_API_SECRET;
    const zenBase = 'https://api.zendit.io/v1';

    const offRes = await fetch(`${zenBase}/topups/offers?country=LB&_limit=100`, {
      headers: { Authorization: `Bearer ${zenSecret}` }
    });
    console.log(`Zendit Offers Status: ${offRes.status}`);
    const offers = await offRes.json();
    console.log(`Zendit Total Offers: ${offers.total || (offers.list ? offers.list.length : 0)}`);
    discoveryOutput.zendit.offers = offers;
    if (offers.list) {
      offers.list.forEach(o => {
        console.log(`OfferId: ${o.offerId} | Brand: ${o.brand} | Name: ${o.name} | PriceType: ${o.priceType} | Price: ${JSON.stringify(o.price)} | Send: ${JSON.stringify(o.send)} | SubTypes: ${JSON.stringify(o.subTypes)}`);
      });
    } else {
      console.log('Zendit Response:', JSON.stringify(offers, null, 2));
    }
  } catch (err) {
    console.error('Zendit Error:', err.message);
    discoveryOutput.zendit.error = err.message;
  }

  // 4. DINGCONNECT
  console.log('\n--- 4. DINGCONNECT (LB) ---');
  try {
    const dingKey = env.DING_API_KEY;
    const dingBase = 'https://api.dingconnect.com/api/V1';

    // Providers
    const provRes = await fetch(`${dingBase}/GetProviders?countryIsos=LB`, {
      headers: { api_key: dingKey }
    });
    console.log(`Ding Providers Status: ${provRes.status}`);
    const providers = await provRes.json();
    console.log('Ding Providers:', JSON.stringify(providers, null, 2));
    discoveryOutput.ding.providers = providers;

    // Products
    const prodRes = await fetch(`${dingBase}/GetProducts?countryIsos=LB`, {
      headers: { api_key: dingKey }
    });
    console.log(`Ding Products Status: ${prodRes.status}`);
    const products = await prodRes.json();
    console.log('Ding Products Status:', JSON.stringify(products, null, 2));
    discoveryOutput.ding.products = products;
  } catch (err) {
    console.error('Ding Error:', err.message);
    discoveryOutput.ding.error = err.message;
  }

  // Save raw data
  fs.writeFileSync(path.join(__dirname, 'lebanon_discovery_raw.json'), JSON.stringify(discoveryOutput, null, 2));
  console.log('\nSaved lebanon_discovery_raw.json successfully!');
}

main();
