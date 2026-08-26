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

async function runTests() {
  const receipts = {
    timestamp: new Date().toISOString(),
    dtone: [],
    reloadly: [],
    zendit: [],
    ding: []
  };

  console.log('====================================================');
  console.log('=== RUNNING MOROCCO (MA / MAR / +212) LIVE SIMULATIONS ===');
  console.log('====================================================');

  // ==========================================
  // 1. DT ONE PRE-PROD TRANSACTIONS
  // ==========================================
  console.log('\n--- 1. DT ONE PRE-PROD TRANSACTIONS ---');
  const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
  const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

  const dtTests = [
    { carrier: 'Maroc Telecom', productId: 4073, recipient: '+212660000101', name: 'Maroc Telecom 5 MAD Airtime' },
    { carrier: 'Maroc Telecom', productId: 1914, recipient: '+212660000101', name: 'Maroc Telecom Jawal Internet Pass 500MB (5 MAD)' },
    { carrier: 'Orange Morocco', productId: 50285, recipient: '+212661000101', name: 'Orange Morocco 6 MAD Airtime' },
    { carrier: 'Orange Morocco', productId: 57216, recipient: '+212661000101', name: 'Orange Morocco 100 MB Social Media 1 Day (5 MAD)' },
    { carrier: 'Inwi Morocco', productId: 16801, recipient: '+212620000101', name: 'Inwi Morocco 5 MAD Airtime' },
    { carrier: 'Inwi Morocco', productId: 1927, recipient: '+212620000101', name: 'Inwi Internet Pass 500MB (5 MAD)' }
  ];

  for (const t of dtTests) {
    const externalId = `dt_mar_test_${Date.now()}_${t.productId}`;
    console.log(`\nTesting DT One ${t.carrier} (${t.name}) to ${t.recipient}...`);
    try {
      const res = await fetch(`${dtBase}/async/transactions`, {
        method: 'POST',
        headers: {
          Authorization: `Basic ${dtoneAuth}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          external_id: externalId,
          product_id: t.productId,
          auto_confirm: true,
          credit_party_identifier: {
            mobile_number: t.recipient
          }
        })
      });
      const data = await res.json();
      console.log(`HTTP ${res.status}:`, JSON.stringify(data, null, 2));
      receipts.dtone.push({
        carrier: t.carrier,
        name: t.name,
        productId: t.productId,
        recipient: t.recipient,
        httpStatus: res.status,
        response: data
      });
    } catch (e) {
      console.error(`DT One Error for ${t.carrier}:`, e.message);
    }
    await sleep(1500);
  }

  // ==========================================
  // 2. RELOADLY SANDBOX TRANSACTIONS
  // ==========================================
  console.log('\n--- 2. RELOADLY SANDBOX TRANSACTIONS ---');
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

    const reloadlyTests = [
      { carrier: 'Maroc Telecom', operatorId: 311, amount: 0.63, recipient: '+212660000101', name: 'Maroc Telecom 5 MAD Airtime ($0.63)' },
      { carrier: 'Maroc Telecom Data', operatorId: 310, amount: 0.75, recipient: '+212660000101', name: 'Maroc Telecom 500MB Data 3 Days ($0.75)' },
      { carrier: 'Orange Morocco', operatorId: 313, amount: 5.00, recipient: '+212661000101', name: 'Orange Morocco Range Airtime ($5.00)' },
      { carrier: 'Orange Morocco Bundles', operatorId: 690, amount: 2.38, recipient: '+212661000101', name: 'Orange Morocco 90m + 500MB 7d ($2.38)' },
      { carrier: 'Orange Morocco Data', operatorId: 309, amount: 2.38, recipient: '+212661000101', name: 'Orange Morocco 2GB Data 7d ($2.38)' },
      { carrier: 'Inwi Morocco', operatorId: 312, amount: 0.60, recipient: '+212620000101', name: 'Inwi Morocco Airtime ($0.60)' },
      { carrier: 'Inwi Morocco Data', operatorId: 308, amount: 0.60, recipient: '+212620000101', name: 'Inwi 500MB Data 1 Day ($0.60)' }
    ];

    for (const t of reloadlyTests) {
      console.log(`\nTesting Reloadly ${t.carrier} (${t.name}) to ${t.recipient}...`);
      try {
        const res = await fetch('https://topups-sandbox.reloadly.com/topups', {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${token}`,
            Accept: 'application/com.reloadly.topups-v1+json',
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            operatorId: t.operatorId,
            amount: t.amount,
            useLocalAmount: false,
            recipientPhone: {
              countryCode: 'MA',
              number: t.recipient
            }
          })
        });
        const data = await res.json();
        console.log(`HTTP ${res.status}:`, JSON.stringify(data, null, 2));
        receipts.reloadly.push({
          carrier: t.carrier,
          name: t.name,
          operatorId: t.operatorId,
          amount: t.amount,
          recipient: t.recipient,
          httpStatus: res.status,
          response: data
        });
      } catch (e) {
        console.error(`Reloadly Error for ${t.carrier}:`, e.message);
      }
      await sleep(1500);
    }
  } catch (e) {
    console.error('Reloadly Test Suite Error:', e.message);
  }

  // Write receipts JSON
  const outPath = path.join(__dirname, 'morocco_test_receipts.json');
  fs.writeFileSync(outPath, JSON.stringify(receipts, null, 2));
  console.log(`\nAll Morocco simulation receipts saved to ${outPath}`);
}

runTests().catch(console.error);
