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
  console.log('=== RUNNING LEBANON (LB / LBN) LIVE SIMULATIONS ===');
  console.log('====================================================');

  // ==========================================
  // 1. DT ONE PRE-PROD TRANSACTIONS
  // ==========================================
  console.log('\n--- 1. DT ONE PRE-PROD TRANSACTIONS ---');
  const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
  const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

  const dtTests = [
    { carrier: 'Touch Lebanon', productId: 44310, recipient: '+96170000101', name: 'Touch USD 3.79 (15D)' },
    { carrier: 'Touch Lebanon', productId: 44311, recipient: '+96170000101', name: 'Touch USD 4.50 (35D)' },
    { carrier: 'Alfa Lebanon', productId: 44471, recipient: '+96171000101', name: 'Alfa USD 1.22 (Micro-Refill)' },
    { carrier: 'Alfa Lebanon', productId: 44473, recipient: '+96171000101', name: 'Alfa USD 4.50 (35D)' }
  ];

  for (const t of dtTests) {
    const externalId = `dt_lb_test_${Date.now()}_${t.productId}`;
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

    const rlTests = [
      { carrier: 'Touch Lebanon', operatorId: 276, amount: 25.4, recipient: '+96170000101', name: 'Touch Lebanon PIN ($25.40 USD)' },
      { carrier: 'Alfa Lebanon', operatorId: 1017, amount: 25.4, recipient: '+96171000101', name: 'Alfa Lebanon PIN ($25.40 USD)' }
    ];

    for (const t of rlTests) {
      const refId = `rl_lb_test_${Date.now()}_${t.operatorId}`;
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
              countryCode: 'LB',
              number: t.recipient.replace('+961', '')
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

  // ==========================================
  // 3. ZENDIT SIMULATIONS
  // ==========================================
  console.log('\n--- 3. ZENDIT SIMULATIONS ---');
  const zenSecret = env.ZENDIT_API_SECRET;
  const zenBase = 'https://api.zendit.io/v1';

  const zenTests = [
    { carrier: 'Touch Lebanon', offerId: 'TOUCH_LB_001_USD', recipient: '+96170000101', name: 'Touch 3.79 USD ($6.00 USD retail tier)' },
    { carrier: 'Touch Lebanon', offerId: 'TOUCH_LB_002_USD', recipient: '+96170000101', name: 'Touch 4.50 USD ($7.00 USD retail tier)' },
    { carrier: 'Alfa Lebanon', offerId: 'ALFA_LB_001', recipient: '+96171000101', name: 'Alfa 1.22 USD ($2.50 USD retail tier)' },
    { carrier: 'Alfa Lebanon', offerId: 'ALFA_LB_003', recipient: '+96171000101', name: 'Alfa 4.50 USD ($9.50 USD retail tier)' }
  ];

  for (const t of zenTests) {
    const txId = `zen_lb_test_${Date.now()}_${t.offerId.toLowerCase().replace(/[^a-z0-9]/g, '_')}`;
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
    await sleep(2000);
  }

  // ==========================================
  // 4. DINGCONNECT LB PROVIDERS & UAT CHECK
  // ==========================================
  console.log('\n--- 4. DINGCONNECT LB PROVIDERS & PRODUCTS CHECK ---');
  try {
    const dingKey = env.DING_API_KEY;
    const dingBase = 'https://api.dingconnect.com/api/V1';

    const provRes = await fetch(`${dingBase}/GetProviders?countryIsos=LB`, {
      headers: { api_key: dingKey }
    });
    const provData = await provRes.json();
    const lbTelecoms = provData.Items?.filter(p => p.ProviderCode === 'TMLB' || p.ProviderCode === 'AALB');
    console.log('Ding Mapped Telecoms:', JSON.stringify(lbTelecoms, null, 2));
    receipts.ding.push({
      status: 'providers_mapped',
      items: lbTelecoms
    });
  } catch (e) {
    console.error('Ding Error:', e.message);
  }

  // Save all receipts
  fs.writeFileSync(path.join(__dirname, 'lebanon_test_receipts.json'), JSON.stringify(receipts, null, 2));
  console.log('\n====================================================');
  console.log('Saved all test receipts to lebanon_test_receipts.json');
  console.log('====================================================');
}

runTests();
