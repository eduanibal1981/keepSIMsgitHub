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
  console.log('=== RUNNING TUNISIA (TN / TUN / +216) LIVE SIMULATIONS ===');
  console.log('====================================================');

  // ==========================================
  // 1. DT ONE PRE-PROD TRANSACTIONS
  // ==========================================
  console.log('\n--- 1. DT ONE PRE-PROD TRANSACTIONS ---');
  const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
  const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

  const dtTests = [
    { carrier: 'Ooredoo Tunisia', productId: 6095, recipient: '+21620000101', name: 'Ooredoo Tunisia 2 TND Airtime' },
    { carrier: 'Ooredoo Tunisia', productId: 4054, recipient: '+21620000101', name: 'Ooredoo Tunisia 5 TND Airtime' },
    { carrier: 'Tunisie Telecom', productId: 8572, recipient: '+21690000101', name: 'Tunisie Telecom 5.4 TND Airtime' },
    { carrier: 'Tunisie Telecom', productId: 8573, recipient: '+21690000101', name: 'Tunisie Telecom 10.8 TND Airtime' },
    { carrier: 'Orange Tunisia', productId: 50404, recipient: '+21650000101', name: 'Orange Tunisia 1.6 TND Airtime' },
    { carrier: 'Orange Tunisia', productId: 50409, recipient: '+21650000101', name: 'Orange Tunisia 5 TND Airtime' }
  ];

  for (const t of dtTests) {
    const externalId = `dt_tun_test_${Date.now()}_${t.productId}`;
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
      { carrier: 'Ooredoo Tunisia', operatorId: 508, amount: 1.00, recipient: '+21620000101', name: 'Ooredoo Tunisia Range ($1.00 / 2 TND)' },
      { carrier: 'Tunisie Telecom', operatorId: 507, amount: 2.40, recipient: '+21690000101', name: 'Tunisie Telecom Fixed ($2.40 / 5.4 TND)' },
      { carrier: 'Orange Tunisia', operatorId: 506, amount: 5.00, recipient: '+21650000101', name: 'Orange Tunisia Range ($5.00 / 13 TND)' }
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
              countryCode: 'TN',
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

  // ==========================================
  // 3. ZENDIT SANDBOX PURCHASES
  // ==========================================
  console.log('\n--- 3. ZENDIT SANDBOX PURCHASES ---');
  try {
    const zenSecret = env.ZENDIT_API_SECRET;
    const zenBase = 'https://api.zendit.io/v1';

    const zenditTests = [
      { carrier: 'Ooredoo Tunisia', offerId: 'OOREDOO_TN_001_W', recipient: '+21620000101', name: 'Ooredoo 5 TND Topup' },
      { carrier: 'Tunisie Telecom', offerId: 'TUNISIETELECOM_TN_001', recipient: '+21690000101', name: 'Tunisie Telecom 5.4 TND Topup' },
      { carrier: 'Orange Tunisia', offerId: 'ORANGE_TN_001_W', recipient: '+21650000101', name: 'Orange Tunisia 13.52 TND Topup' }
    ];

    for (const t of zenditTests) {
      const transactionId = `zen_tun_${Date.now()}_${t.offerId}`;
      console.log(`\nTesting Zendit ${t.carrier} (${t.name}) to ${t.recipient}...`);
      try {
        const res = await fetch(`${zenBase}/topups/purchases`, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${zenSecret}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            transactionId: transactionId,
            recipientPhoneNumber: t.recipient,
            offerId: t.offerId
          })
        });
        const data = await res.json();
        console.log(`HTTP ${res.status}:`, JSON.stringify(data, null, 2));
        receipts.zendit.push({
          carrier: t.carrier,
          name: t.name,
          offerId: t.offerId,
          recipient: t.recipient,
          httpStatus: res.status,
          response: data
        });
      } catch (e) {
        console.error(`Zendit Error for ${t.carrier}:`, e.message);
      }
      await sleep(1500);
    }
  } catch (e) {
    console.error('Zendit Test Suite Error:', e.message);
  }

  // Write receipts JSON
  const outPath = path.join(__dirname, 'tunisia_test_receipts.json');
  fs.writeFileSync(outPath, JSON.stringify(receipts, null, 2));
  console.log(`\nAll Tunisia simulation receipts saved to ${outPath}`);
}

runTests().catch(console.error);
