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

  // Check all operators in Reloadly for country BH
  const res = await fetch('https://topups-sandbox.reloadly.com/operators/countries/BH', {
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: 'application/com.reloadly.topups-v1+json'
    }
  });
  const data = await res.json();
  console.log('Reloadly Operators for BH:', data.map(o => ({ id: o.operatorId, name: o.name, pin: o.pin, bundle: o.bundle, data: o.data })));

  // Check auto-detect with test numbers
  const testNumbers = [
    { num: '39000101', name: 'Batelco' },
    { num: '36000101', name: 'Zain' },
    { num: '33000101', name: 'STC' },
    { num: '34000101', name: 'Viva/STC' }
  ];

  for (const t of testNumbers) {
    const autoRes = await fetch(`https://topups-sandbox.reloadly.com/operators/auto-detect/phone/${t.num}/countries/BH`, {
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: 'application/com.reloadly.topups-v1+json'
      }
    });
    console.log(`Auto detect for ${t.name} (+973 ${t.num}): status ${autoRes.status}`, await autoRes.json());
  }
}

main();
