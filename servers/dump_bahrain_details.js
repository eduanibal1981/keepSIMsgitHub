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
  const report = {
    timestamp: new Date().toISOString(),
    supabase: {},
    dtone: {},
    reloadly: {},
    zendit: {},
    ding: {}
  };

  // 0. Supabase
  try {
    const countries = await supabaseApi('countries?iso_code=in.(BH,BHR)&select=*');
    report.supabase.countries = countries;
    if (countries.length > 0) {
      const countryId = countries[0].id;
      report.supabase.carriers = await supabaseApi(`carriers?country_id=eq.${countryId}&select=*`);
      report.supabase.carrier_rules = [];
      report.supabase.carrier_provider_map = [];
      for (const c of report.supabase.carriers) {
        const rules = await supabaseApi(`carrier_rules?carrier_id=eq.${c.id}&select=*`);
        const map = await supabaseApi(`carrier_provider_map?carrier_id=eq.${c.id}&select=*`);
        report.supabase.carrier_rules.push({ carrier: c.name, carrier_id: c.id, rules });
        report.supabase.carrier_provider_map.push({ carrier: c.name, carrier_id: c.id, map });
      }
    }
  } catch (err) {
    report.supabase.error = err.message;
  }

  // 1. DT One
  try {
    const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
    const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

    const opRes = await fetch(`${dtBase}/operators?country_iso_code=BHR&page=1&per_page=50`, {
      headers: { Authorization: `Basic ${dtoneAuth}` }
    });
    report.dtone.operators = await opRes.json();

    const prodRes = await fetch(`${dtBase}/products?country_iso_code=BHR&page=1&per_page=100`, {
      headers: { Authorization: `Basic ${dtoneAuth}` }
    });
    report.dtone.products = await prodRes.json();
  } catch (err) {
    report.dtone.error = err.message;
  }

  // 2. Reloadly
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
    if (authRes.ok) {
      const token = authData.access_token;
      const opRes = await fetch('https://topups-sandbox.reloadly.com/operators/countries/BH', {
        headers: {
          Authorization: `Bearer ${token}`,
          Accept: 'application/com.reloadly.topups-v1+json'
        }
      });
      report.reloadly.operators = await opRes.json();
    } else {
      report.reloadly.authError = authData;
    }
  } catch (err) {
    report.reloadly.error = err.message;
  }

  // 3. Zendit
  try {
    const zenSecret = env.ZENDIT_API_SECRET;
    const zenBase = 'https://api.zendit.io/v1';
    const offRes = await fetch(`${zenBase}/topups/offers?country=BH&_limit=100`, {
      headers: { Authorization: `Bearer ${zenSecret}` }
    });
    report.zendit.offers = await offRes.json();
  } catch (err) {
    report.zendit.error = err.message;
  }

  // 4. DingConnect
  try {
    const dingKey = env.DING_API_KEY;
    const dingBase = 'https://api.dingconnect.com/api/V1';
    const provRes = await fetch(`${dingBase}/GetProviders?countryIsos=BH`, {
      headers: { api_key: dingKey }
    });
    report.ding.providers = await provRes.json();

    const prodRes = await fetch(`${dingBase}/GetProducts?countryIsos=BH`, {
      headers: { api_key: dingKey }
    });
    report.ding.products = await prodRes.json();
  } catch (err) {
    report.ding.error = err.message;
  }

  fs.writeFileSync(path.join(__dirname, 'bahrain_discovery_raw.json'), JSON.stringify(report, null, 2));
  console.log('Saved discovery details to bahrain_discovery_raw.json');
}

main();
