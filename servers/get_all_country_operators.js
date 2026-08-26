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

const countries = [
  { name: 'Bahrain', iso2: 'BH', iso3: 'BHR', code: '+973', folder: 'BHR' },
  { name: 'Kuwait', iso2: 'KW', iso3: 'KWT', code: '+965', folder: 'KW' },
  { name: 'Qatar', iso2: 'QA', iso3: 'QAT', code: '+974', folder: 'QAT' },
  { name: 'Jordan', iso2: 'JO', iso3: 'JOR', code: '+962', folder: 'JOR' },
  { name: 'Iraq', iso2: 'IQ', iso3: 'IRQ', code: '+964', folder: 'IRQ' },
  { name: 'Lebanon', iso2: 'LB', iso3: 'LBN', code: '+961', folder: 'LBN' },
  { name: 'Sri Lanka', iso2: 'LK', iso3: 'LKA', code: '+94', folder: 'LKA' },
  { name: 'Nepal', iso2: 'NP', iso3: 'NPL', code: '+977', folder: 'NPL' },
  { name: 'Morocco', iso2: 'MA', iso3: 'MAR', code: '+212', folder: 'MAR' },
  { name: 'Algeria', iso2: 'DZ', iso3: 'DZA', code: '+213', folder: 'DZA' },
  { name: 'Tunisia', iso2: 'TN', iso3: 'TUN', code: '+216', folder: 'TUN' },
  { name: 'Germany', iso2: 'DE', iso3: 'DEU', code: '+49', folder: 'DEU' }
];

async function main() {
  const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
  const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

  // Reloadly token
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
  const rlToken = authData.access_token;

  const zenSecret = env.ZENDIT_API_SECRET;
  const zenBase = 'https://api.zendit.io/v1';

  const overview = {};

  for (const c of countries) {
    console.log(`\n========================================`);
    console.log(`Querying ${c.name} (${c.iso2} / ${c.iso3})...`);
    overview[c.iso2] = { name: c.name, iso2: c.iso2, iso3: c.iso3, code: c.code, folder: c.folder };

    // DT One
    try {
      const res = await fetch(`${dtBase}/operators?country_iso_code=${c.iso3}&page=1&per_page=50`, {
        headers: { Authorization: `Basic ${dtoneAuth}` }
      });
      const data = await res.json();
      overview[c.iso2].dtone = Array.isArray(data) ? data.map(o => `${o.name} (${o.id})`) : [];
    } catch (e) {
      overview[c.iso2].dtone = ['Error: ' + e.message];
    }
    await sleep(600);

    // Reloadly
    try {
      const res = await fetch(`https://topups-sandbox.reloadly.com/operators/countries/${c.iso2}`, {
        headers: {
          Authorization: `Bearer ${rlToken}`,
          Accept: 'application/com.reloadly.topups-v1+json'
        }
      });
      const data = await res.json();
      overview[c.iso2].reloadly = Array.isArray(data) ? data.map(o => `${o.name} (${o.operatorId}) [${o.denominationType}]`) : [];
    } catch (e) {
      overview[c.iso2].reloadly = ['Error: ' + e.message];
    }
    await sleep(600);

    // Zendit
    try {
      const res = await fetch(`${zenBase}/topups/offers?country=${c.iso2}&_limit=50&_offset=0`, {
        headers: { Authorization: `Bearer ${zenSecret}` }
      });
      const data = await res.json();
      const brands = new Set();
      if (data.list) {
        data.list.forEach(o => brands.add(o.brand));
      }
      overview[c.iso2].zendit = Array.from(brands);
    } catch (e) {
      overview[c.iso2].zendit = ['Error: ' + e.message];
    }
    await sleep(600);

    console.log(`DT One:`, overview[c.iso2].dtone);
    console.log(`Reloadly:`, overview[c.iso2].reloadly);
    console.log(`Zendit:`, overview[c.iso2].zendit);
  }

  fs.writeFileSync(path.join(__dirname, 'empty_countries_overview.json'), JSON.stringify(overview, null, 2));
}

main().catch(console.error);
