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

  for (const c of countries) {
    try {
      const res = await fetch(`${dtBase}/operators?country_iso_code=${c.iso3}&page=1&per_page=50`, {
        headers: { Authorization: `Basic ${dtoneAuth}` }
      });
      const data = await res.json();
      const opNames = Array.isArray(data) ? data.map(o => `${o.name} (${o.id})`) : [];
      console.log(`\n${c.name} (${c.iso2}/${c.iso3}) DT One Operators (${opNames.length}):`, opNames.join(', '));
    } catch (e) {
      console.error(`Error for ${c.name}:`, e.message);
    }
  }
}

main().catch(console.error);
