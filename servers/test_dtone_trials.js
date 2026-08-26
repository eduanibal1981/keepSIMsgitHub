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

async function testTrials() {
  const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
  const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

  // German numbers typically have 10 or 11 digits after +49 (e.g. +49 170 1234567 or +49 151 12345678)
  const numbersToTry = [
    '+491701234567',
    '+4915112345678',
    '+491700000101',
    '+491710000101',
    '+491720000101',
    '+491721234567',
    '+4915212345678'
  ];

  for (const num of numbersToTry) {
    const extId = `dt_de_${Date.now()}`;
    // Test Telekom (46871)
    const resT = await fetch(`${dtBase}/async/transactions`, {
      method: 'POST',
      headers: {
        Authorization: `Basic ${dtoneAuth}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        external_id: extId + '_t',
        product_id: 46871,
        auto_confirm: true,
        credit_party_identifier: {
          mobile_number: num
        }
      })
    });
    const textT = await resT.text();
    console.log(`Telekom with ${num}: HTTP ${resT.status} -> ${textT.slice(0, 150)}`);

    // Test Vodafone (15313)
    const resV = await fetch(`${dtBase}/async/transactions`, {
      method: 'POST',
      headers: {
        Authorization: `Basic ${dtoneAuth}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        external_id: extId + '_v',
        product_id: 15313,
        auto_confirm: true,
        credit_party_identifier: {
          mobile_number: num
        }
      })
    });
    const textV = await resV.text();
    console.log(`Vodafone with ${num}: HTTP ${resV.status} -> ${textV.slice(0, 150)}`);
  }
}

testTrials();
