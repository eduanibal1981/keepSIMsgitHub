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
  console.log('=== RUNNING ALGERIA (DZ / DZA / +213) LIVE SIMULATIONS ===');
  console.log('====================================================');

  // ==========================================
  // 1. DT ONE PRE-PROD TRANSACTIONS
  // ==========================================
  console.log('\n--- 1. DT ONE PRE-PROD TRANSACTIONS ---');
  const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
  const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

  const dtTests = [
    { carrier: 'Mobilis', productId: 14299, recipient: '+213660000101', name: 'Mobilis Algeria 100 DZD Airtime' },
    { carrier: 'Djezzy', productId: 14308, recipient: '+213770000101', name: 'Djezzy Algeria 100 DZD Airtime' },
    { carrier: 'Ooredoo', productId: 14317, recipient: '+213550000101', name: 'Ooredoo Algeria 100 DZD Airtime' },
    { carrier: 'Ooredoo Data', productId: 56642, recipient: '+213550000101', name: 'Ooredoo 700 MB 1 Day (100 DZD)' }
  ];

  for (const t of dtTests) {
    const externalId = `dt_dza_test_${Date.now()}_${t.productId}`;
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
      { carrier: 'Mobilis', operatorId: 6, amount: 0.97, recipient: '+213660000101', name: 'Mobilis 100 DZD Airtime ($0.97)' },
      { carrier: 'Djezzy', operatorId: 8, amount: 4.84, recipient: '+213770000101', name: 'Djezzy 500 DZD Airtime ($4.84)' },
      { carrier: 'Ooredoo', operatorId: 7, amount: 0.97, recipient: '+213550000101', name: 'Ooredoo 100 DZD Airtime ($0.97)' }
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
              countryCode: 'DZ',
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
  // 3. ZENDIT SANDBOX TRANSACTIONS
  // ==========================================
  console.log('\n--- 3. ZENDIT SANDBOX TRANSACTIONS ---');
  try {
    const zenSecret = env.ZENDIT_API_SECRET;
    const zenBase = 'https://api.zendit.io/v1';

    const zenditTests = [
      { carrier: 'Mobilis', offerId: 'MOBILIS_DZ_01', recipient: '+213660000101', name: 'Mobilis 100 DZD Airtime ($0.71)' },
      { carrier: 'Djezzy', offerId: 'DJEZZY_DZ_01', recipient: '+213770000101', name: 'Djezzy 100 DZD Airtime ($0.71)' },
      { carrier: 'Ooredoo', offerId: 'OOREDOO_DZ_01', recipient: '+213550000101', name: 'Ooredoo 100 DZD Airtime ($0.73)' }
    ];

    for (const t of zenditTests) {
      const txId = `zen_dz_test_${Date.now()}_${t.carrier.toLowerCase()}`;
      console.log(`\nTesting Zendit ${t.carrier} (${t.offerId}) to ${t.recipient}...`);
      try {
        const res = await fetch(`${zenBase}/topups/purchases`, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${zenSecret}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            transactionId: txId,
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

  // ==========================================
  // 4. DINGCONNECT STATUS RECORD
  // ==========================================
  console.log('\n--- 4. DINGCONNECT STATUS RECORD ---');
  receipts.ding.push({
    country: 'DZ',
    providers: ['MDDZ', 'DJDZ', 'OODZ'],
    status: '503 RateLimited / 0 UAT Offers',
    decision: 'Disabled in UAT'
  });

  // Write receipts JSON
  const outPath = path.join(__dirname, 'algeria_test_receipts.json');
  fs.writeFileSync(outPath, JSON.stringify(receipts, null, 2));
  console.log(`\nAll Algeria simulation receipts saved to ${outPath}`);
}

runTests().catch(console.error);
