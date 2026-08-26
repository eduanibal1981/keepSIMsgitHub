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

async function main() {
  console.log('=== SEARCHING FOR STC / VIVA BAHRAIN ACROSS PROVIDERS ===');

  // 1. DT One Operator Search
  try {
    const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
    const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

    console.log('\n--- Searching DT One operators for "Bahrain" or "Viva" or "STC" ---');
    const res = await fetch(`${dtBase}/operators?page=1&per_page=100`, {
      headers: { Authorization: `Basic ${dtoneAuth}` }
    });
    // Also search with country_iso_code
    const resBH = await fetch(`${dtBase}/operators?country_iso_code=BHR`, {
      headers: { Authorization: `Basic ${dtoneAuth}` }
    });
    console.log('DT One BHR operators:', await resBH.json());
  } catch (e) {
    console.error('DT One error:', e);
  }

  // 2. Reloadly Search
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

    console.log('\n--- Reloadly searching operators with name viva or stc or bahrain ---');
    const resOps = await fetch('https://topups-sandbox.reloadly.com/operators?includeBundles=true&includeData=true&includePin=true&size=200&page=1', {
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: 'application/com.reloadly.topups-v1+json'
      }
    });
    const opsData = await resOps.json();
    const bhOps = opsData.content?.filter(o => o.country?.isoName === 'BH' || o.name?.toLowerCase().includes('bahrain') || o.name?.toLowerCase().includes('batelco') || o.name?.toLowerCase().includes('viva'));
    console.log('Reloadly BH matching operators:', bhOps);
  } catch (e) {
    console.error('Reloadly error:', e);
  }

  // 3. Ding Search
  try {
    const dingKey = env.DING_API_KEY;
    const dingBase = 'https://api.dingconnect.com/api/V1';
    const provRes = await fetch(`${dingBase}/GetProviders?countryIsos=BH`, {
      headers: { api_key: dingKey }
    });
    const providers = await provRes.json();
    const telecoms = providers.Items?.filter(p => 
      p.Name.toLowerCase().includes('batelco') || 
      p.Name.toLowerCase().includes('zain') || 
      p.Name.toLowerCase().includes('stc') || 
      p.Name.toLowerCase().includes('viva')
    );
    console.log('\n--- Ding BH Telecom Providers ---', telecoms);
  } catch (e) {
    console.error('Ding error:', e);
  }
}

main();
