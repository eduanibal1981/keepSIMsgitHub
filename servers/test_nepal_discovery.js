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
  const discovery = {
    timestamp: new Date().toISOString(),
    country: { iso2: 'NP', iso3: 'NPL', code: '+977', name: 'Nepal' },
    dtone: {},
    reloadly: {},
    zendit: {},
    ding: {},
    supabase: {}
  };

  console.log('====================================================');
  console.log('=== DISCOVERING NEPAL (NP / NPL / +977) TELECOMS ===');
  console.log('====================================================');

  // 1. DT ONE (ISO: NPL)
  console.log('\n--- 1. DT ONE (NPL) ---');
  try {
    const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
    const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

    // Get operators
    const opRes = await fetch(`${dtBase}/operators?country_iso_code=NPL&page=1&per_page=50`, {
      headers: { Authorization: `Basic ${dtoneAuth}` }
    });
    console.log(`DT One Operators Status: ${opRes.status}`);
    const operators = await opRes.json();
    discovery.dtone.operators = operators;
    console.log('DT One Operators:', JSON.stringify(operators, null, 2));

    // Get products
    const prodRes = await fetch(`${dtBase}/products?country_iso_code=NPL&page=1&per_page=100`, {
      headers: { Authorization: `Basic ${dtoneAuth}` }
    });
    console.log(`DT One Products Status: ${prodRes.status}`);
    const products = await prodRes.json();
    discovery.dtone.products = products;
    console.log(`DT One Total Products: ${Array.isArray(products) ? products.length : 'N/A'}`);
    if (Array.isArray(products)) {
      products.forEach(p => {
        console.log(`ID: ${p.id} | Name: ${p.name} | Operator: ${p.operator?.id} (${p.operator?.name}) | Type: ${p.type} | Prices: ${JSON.stringify(p.prices?.wholesale || p.source)} | Dest: ${JSON.stringify(p.destination)}`);
      });
    }
  } catch (err) {
    console.error('DT One Error:', err.message);
    discovery.dtone.error = err.message;
  }

  // 2. RELOADLY (ISO: NP)
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
    if (!authRes.ok) {
      console.error('Reloadly auth failed:', authData);
      discovery.reloadly.error = authData;
    } else {
      const token = authData.access_token;
      console.log('Reloadly Auth Success');
      const opRes = await fetch('https://topups-sandbox.reloadly.com/operators/countries/NP', {
        headers: {
          Authorization: `Bearer ${token}`,
          Accept: 'application/com.reloadly.topups-v1+json'
        }
      });
      console.log(`Reloadly Operators Status: ${opRes.status}`);
      const operators = await opRes.json();
      discovery.reloadly.operators = operators;
      console.log('Reloadly Operators:', JSON.stringify(operators, null, 2));
    }
  } catch (err) {
    console.error('Reloadly Error:', err.message);
    discovery.reloadly.error = err.message;
  }

  // 3. ZENDIT (country: NP)
  console.log('\n--- 3. ZENDIT (NP) ---');
  try {
    const zenSecret = env.ZENDIT_API_SECRET;
    const zenBase = 'https://api.zendit.io/v1';

    const offRes = await fetch(`${zenBase}/topups/offers?country=NP&_limit=100`, {
      headers: { Authorization: `Bearer ${zenSecret}` }
    });
    console.log(`Zendit Offers Status: ${offRes.status}`);
    const offers = await offRes.json();
    discovery.zendit.offers = offers;
    console.log(`Zendit Total Offers: ${offers.total || (offers.list ? offers.list.length : 0)}`);
    if (offers.list) {
      offers.list.forEach(o => {
        console.log(`OfferId: ${o.offerId} | Brand: ${o.brand} | Name: ${o.name} | PriceType: ${o.priceType} | Price: ${JSON.stringify(o.price)} | Send: ${JSON.stringify(o.send)} | SubTypes: ${JSON.stringify(o.subTypes)}`);
      });
    } else {
      console.log('Zendit Response:', JSON.stringify(offers, null, 2));
    }
  } catch (err) {
    console.error('Zendit Error:', err.message);
    discovery.zendit.error = err.message;
  }

  // 4. DINGCONNECT (countryIsos: NP)
  console.log('\n--- 4. DINGCONNECT (NP) ---');
  try {
    const dingKey = env.DING_API_KEY;
    const dingBase = 'https://api.dingconnect.com/api/V1';

    const provRes = await fetch(`${dingBase}/GetProviders?countryIsos=NP`, {
      headers: { api_key: dingKey }
    });
    console.log(`Ding Providers Status: ${provRes.status}`);
    const providers = await provRes.json();
    discovery.ding.providers = providers;
    console.log('Ding Providers:', JSON.stringify(providers, null, 2));

    const prodRes = await fetch(`${dingBase}/GetProducts?countryIsos=NP`, {
      headers: { api_key: dingKey }
    });
    console.log(`Ding Products Status: ${prodRes.status}`);
    const products = await prodRes.json();
    discovery.ding.products = products;
    console.log(`Ding Total Products: ${products.Items ? products.Items.length : 0}`);
    if (products.Items) {
      products.Items.forEach(p => {
        console.log(`SkuCode: ${p.SkuCode} | ProviderCode: ${p.ProviderCode} | Name: ${p.LocalizationKey} | Min: ${JSON.stringify(p.Minimum)} | Max: ${JSON.stringify(p.Maximum)} | Validity: ${p.ValidityPeriodIso} | UatNumber: ${p.UatNumber}`);
      });
    }
  } catch (err) {
    console.error('DingConnect Error:', err.message);
    discovery.ding.error = err.message;
  }

  // 5. SUPABASE CHECK
  console.log('\n--- 5. SUPABASE CHECK (NP) ---');
  try {
    const SUPABASE_URL = env.SUPABASE_URL;
    const SUPABASE_KEY = env.SUPABASE_SERVICE_ROLE_KEY;
    const sbHeaders = {
      'apikey': SUPABASE_KEY,
      'Authorization': `Bearer ${SUPABASE_KEY}`,
      'Content-Type': 'application/json'
    };

    const cRes = await fetch(`${SUPABASE_URL}/rest/v1/countries?iso_code=eq.NP`, { headers: sbHeaders });
    const countries = await cRes.json();
    discovery.supabase.countries = countries;
    console.log('Supabase Country:', JSON.stringify(countries, null, 2));

    if (countries && countries.length > 0) {
      const countryId = countries[0].id;
      const carRes = await fetch(`${SUPABASE_URL}/rest/v1/carriers?country_id=eq.${countryId}`, { headers: sbHeaders });
      const carriers = await carRes.json();
      discovery.supabase.carriers = carriers;
      console.log('Supabase Carriers:', JSON.stringify(carriers, null, 2));

      const carrierIds = carriers.map(c => c.id);
      if (carrierIds.length > 0) {
        const idList = `in.(${carrierIds.join(',')})`;
        const rulesRes = await fetch(`${SUPABASE_URL}/rest/v1/carrier_rules?carrier_id=${idList}`, { headers: sbHeaders });
        discovery.supabase.carrier_rules = await rulesRes.json();
        console.log('Supabase Carrier Rules:', JSON.stringify(discovery.supabase.carrier_rules, null, 2));

        const mapRes = await fetch(`${SUPABASE_URL}/rest/v1/carrier_provider_map?carrier_id=${idList}`, { headers: sbHeaders });
        discovery.supabase.carrier_provider_map = await mapRes.json();
        console.log('Supabase Carrier Provider Map:', JSON.stringify(discovery.supabase.carrier_provider_map, null, 2));
      }
    }
  } catch (err) {
    console.error('Supabase Error:', err.message);
    discovery.supabase.error = err.message;
  }

  // Write raw discovery JSON
  const outPath = path.join(__dirname, 'nepal_discovery_raw.json');
  fs.writeFileSync(outPath, JSON.stringify(discovery, null, 2));
  console.log(`\nDiscovery saved to ${outPath}`);
}

main().catch(console.error);
