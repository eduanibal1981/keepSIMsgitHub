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

async function testNumbers() {
  const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
  const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

  const testNums = [
    '+491701234101', '+491711234101', '+491601234101', '+491511234101',
    '+491721234101', '+491731234101', '+491741234101', '+491521234101',
    '+491761234101', '+491791234101'
  ];

  for (const num of testNums) {
    // try lookup
    const lookRes = await fetch(`${dtBase}/lookup/mobile-number/${encodeURIComponent(num)}`, {
      headers: { Authorization: `Basic ${dtoneAuth}` }
    });
    const lookData = await lookRes.json();
    console.log(`Lookup ${num}: status ${lookRes.status}, op: ${lookData.operator?.name || 'N/A'}`);
  }

  // Try DT One async transaction for Telekom with +491701234101 and Vodafone with +491721234101
  const trials = [
    { name: 'Telekom 10 EUR', productId: 46871, num: '+491701234101' },
    { name: 'Telekom 5 EUR PIN', productId: 24361, num: '+491701234101' },
    { name: 'Vodafone 15 EUR', productId: 15313, num: '+491721234101' },
    { name: 'Vodafone 15 EUR PIN', productId: 23386, num: '+491721234101' }
  ];

  for (const tr of trials) {
    const extId = `dt_de_test_${Date.now()}_${tr.productId}`;
    const res = await fetch(`${dtBase}/async/transactions`, {
      method: 'POST',
      headers: {
        Authorization: `Basic ${dtoneAuth}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        external_id: extId,
        product_id: tr.productId,
        auto_confirm: true,
        credit_party_identifier: {
          mobile_number: tr.num
        }
      })
    });
    const data = await res.json();
    console.log(`Test ${tr.name} (${tr.num}): status ${res.status}, status_msg: ${data.status?.message || JSON.stringify(data.errors)}`);
    if (res.status === 201) {
      console.log('Success response:', JSON.stringify(data, null, 2));
    }
  }
}

testNumbers();
