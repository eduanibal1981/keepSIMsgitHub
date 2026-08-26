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

async function runIraqTests() {
  const receipts = {
    timestamp: new Date().toISOString(),
    dtone: [],
    reloadly: [],
    zendit: [],
    ding: []
  };

  console.log('====================================================');
  console.log('=== RUNNING IRAQ (IQ / IRQ / +964) LIVE SIMULATIONS ===');
  console.log('====================================================\n');

  // ==========================================
  // 1. ZENDIT SIMULATIONS (AsiaCell Direct)
  // ==========================================
  console.log('--- 1. ZENDIT SIMULATIONS ---');
  const zenSecret = env.ZENDIT_API_SECRET;
  const zenBase = 'https://api.zendit.io/v1';

  const zenTests = [
    { carrier: 'AsiaCell', offerId: 'ASIACELL_IQ_001', recipient: '+9647700000101', name: 'AsiaCell 5,000 IQD Direct Top-Up ($4.18 USD Net)' },
    { carrier: 'AsiaCell', offerId: 'ASIACELL_IQ_002', recipient: '+9647700000101', name: 'AsiaCell 10,000 IQD Direct Top-Up ($8.35 USD Net)' }
  ];

  for (const t of zenTests) {
    const txnRef = `test_iq_zen_${Date.now()}_${t.offerId}`;
    console.log(`\nTesting Zendit ${t.carrier} (${t.name}) to ${t.recipient}...`);
    try {
      const res = await fetch(`${zenBase}/topups/purchases`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${zenSecret}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          offerId: t.offerId,
          recipient: {
            phoneNumber: t.recipient
          },
          transactionReference: txnRef
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
    await sleep(2000);
  }

  // ==========================================
  // 2. DT ONE PRE-PROD TRANSACTIONS
  // ==========================================
  console.log('\n--- 2. DT ONE PRE-PROD TRANSACTIONS ---');
  const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
  const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

  const dtTests = [
    { carrier: 'AsiaCell', productId: 4042, recipient: '+9647700000101', name: 'AsiaCell 5,000 IQD Direct Airtime (1.848 OMR)' },
    { carrier: 'AsiaCell', productId: 39018, recipient: '+9647700000101', name: 'AsiaCell 3,000 IQD Digital PIN Voucher (1.235 OMR)' },
    { carrier: 'Zain Iraq', productId: 38999, recipient: '+9647800000101', name: 'Zain Iraq 5,000 IQD Digital PIN Voucher (2.050 OMR)' },
    { carrier: 'Zain Iraq', productId: 39001, recipient: '+9647800000101', name: 'Zain Iraq 15,000 IQD Digital PIN Voucher (5.923 OMR)' },
    { carrier: 'Korek Telecom', productId: 39011, recipient: '+9647500000101', name: 'Korek Iraq 5,000 IQD Digital PIN Voucher (2.050 OMR)' }
  ];

  for (const t of dtTests) {
    const externalId = `dt_iq_test_${Date.now()}_${t.productId}`;
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
    await sleep(2000);
  }

  // ==========================================
  // 3. RELOADLY SANDBOX TRANSACTIONS
  // ==========================================
  console.log('\n--- 3. RELOADLY SANDBOX TRANSACTIONS ---');
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

    const rlTests = [
      { carrier: 'AsiaCell', operatorId: 246, amount: 7.03, recipient: '+9647700000101', name: 'AsiaCell 5,000 IQD Direct ($7.03 USD)' }
    ];

    for (const t of rlTests) {
      const refId = `rl_iq_test_${Date.now()}_${t.operatorId}`;
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
              countryCode: 'IQ',
              number: t.recipient.replace('+964', '')
            },
            customIdentifier: refId
          })
        });
        const data = await res.json();
        console.log(`HTTP ${res.status}:`, JSON.stringify(data, null, 2));
        receipts.reloadly.push({
          carrier: t.carrier,
          name: t.name,
          operatorId: t.operatorId,
          recipient: t.recipient,
          httpStatus: res.status,
          response: data
        });
      } catch (e) {
        console.error(`Reloadly Error for ${t.carrier}:`, e.message);
      }
      await sleep(2000);
    }
  } catch (e) {
    console.error('Reloadly Auth Error:', e.message);
  }

  // Save all test receipts
  fs.writeFileSync(path.join(__dirname, 'iraq_test_receipts.json'), JSON.stringify(receipts, null, 2));
  console.log('\nSaved iraq_test_receipts.json successfully!');
}

runIraqTests().catch(console.error);
