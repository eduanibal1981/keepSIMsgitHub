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

  console.log('======================================================');
  console.log('=== RUNNING SRI LANKA (LK / LKA) LIVE SIMULATIONS ===');
  console.log('======================================================');

  // Phone numbers: +94 followed by 9 digits (11 digits total):
  // Dialog: +94770000101
  // Mobitel: +94710000101
  // Hutch: +94780000101
  // Airtel: +94750000101

  // ==========================================
  // 1. DT ONE PRE-PROD TRANSACTIONS
  // ==========================================
  console.log('\n--- 1. DT ONE PRE-PROD TRANSACTIONS ---');
  const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
  const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

  const dtTests = [
    { carrier: 'Dialog Sri Lanka', productId: 38279, recipient: '+94770000101', name: 'Dialog 50 LKR' },
    { carrier: 'Mobitel Sri Lanka', productId: 38281, recipient: '+94710000101', name: 'Mobitel 50 LKR' },
    { carrier: 'Hutchison Sri Lanka', productId: 6076, recipient: '+94780000101', name: 'Hutchison 50 LKR' },
    { carrier: 'Airtel Sri Lanka (Dialog Rails)', productId: 38279, recipient: '+94750000101', name: 'Airtel/Dialog 50 LKR' }
  ];

  for (const t of dtTests) {
    const externalId = `dt_lk_test_${Date.now()}_${t.productId}`;
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

    const rlTests = [
      { carrier: 'Dialog Sri Lanka', operatorId: 472, amount: 0.40, recipient: '+94770000101', name: 'Dialog Airtime ($0.40 / 100 LKR)' },
      { carrier: 'Mobitel Sri Lanka', operatorId: 471, amount: 0.37, recipient: '+94710000101', name: 'Mobitel Airtime ($0.37 / 100 LKR)' },
      { carrier: 'Hutchison Sri Lanka', operatorId: 475, amount: 0.63, recipient: '+94780000101', name: 'Hutchison Airtime ($0.63 / 100 LKR)' },
      { carrier: 'Dialog Sri Lanka Data', operatorId: 1180, amount: 0.45, recipient: '+94770000101', name: 'Dialog 1.5GB 14D ($0.45)' },
      { carrier: 'Hutchison Sri Lanka Data', operatorId: 1181, amount: 0.30, recipient: '+94780000101', name: 'Hutchison 1.2GB ($0.30)' },
      { carrier: 'Airtel Sri Lanka', operatorId: 472, amount: 0.40, recipient: '+94750000101', name: 'Airtel on Dialog ($0.40)' }
    ];

    for (const t of rlTests) {
      const refId = `rl_lk_test_${Date.now()}_${t.operatorId}`;
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
            customIdentifier: refId,
            recipientPhone: {
              countryCode: 'LK',
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
  } catch (err) {
    console.error('Reloadly Test Suite Error:', err.message);
  }

  // ==========================================
  // 3. ZENDIT TEST TRANSACTIONS
  // ==========================================
  console.log('\n--- 3. ZENDIT TEST TRANSACTIONS ---');
  try {
    const zenSecret = env.ZENDIT_API_SECRET;
    const zenBase = 'https://api.zendit.io/v1';

    const zenTests = [
      { carrier: 'Dialog Sri Lanka', offerId: 'DIALOG_LK_001', recipient: '+94770000101', name: 'Dialog 1551 LKR ($6.50)' },
      { carrier: 'Mobitel Sri Lanka', offerId: 'MOBITEL_LK_5-I', recipient: '+94710000101', name: 'Mobitel 772 LKR ($5.60)' },
      { carrier: 'Hutchison Sri Lanka', offerId: 'HUTCH_LK_5-I', recipient: '+94780000101', name: 'Hutch 792 LKR ($5.50)' },
      { carrier: 'Airtel Sri Lanka', offerId: 'DIALOG_LK_001', recipient: '+94750000101', name: 'Airtel on Dialog ($6.50)' }
    ];

    for (const t of zenTests) {
      const txId = `zen_lk_test_${Date.now()}_${t.offerId.toLowerCase()}`;
      console.log(`\nTesting Zendit ${t.carrier} (${t.name}) to ${t.recipient}...`);
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
  } catch (err) {
    console.error('Zendit Test Suite Error:', err.message);
  }

  // ==========================================
  // 4. DINGCONNECT VALIDATION & UAT INSPECTION
  // ==========================================
  console.log('\n--- 4. DINGCONNECT UAT VALIDATION ---');
  try {
    const dingKey = env.DING_API_KEY;
    const dingBase = 'https://api.dingconnect.com/api/V1';

    const dingTests = [
      { carrier: 'Dialog Sri Lanka', providerCode: 'DGLK', recipient: '+94770000101' },
      { carrier: 'Mobitel Sri Lanka', providerCode: 'MSLK', recipient: '+94710000101' },
      { carrier: 'Hutchison Sri Lanka', providerCode: 'HSLK', recipient: '+94780000101' }
    ];

    for (const t of dingTests) {
      console.log(`\nTesting DingConnect Provider ${t.providerCode} (${t.carrier})...`);
      try {
        const res = await fetch(`${dingBase}/GetProducts?providerCodes=${t.providerCode}&countryIsos=LK`, {
          headers: { api_key: dingKey }
        });
        const data = await res.json();
        console.log(`HTTP ${res.status}:`, JSON.stringify(data, null, 2));
        receipts.ding.push({
          carrier: t.carrier,
          providerCode: t.providerCode,
          httpStatus: res.status,
          response: data
        });
      } catch (e) {
        console.error(`Ding Error for ${t.carrier}:`, e.message);
      }
      await sleep(1000);
    }
  } catch (err) {
    console.error('DingConnect Test Suite Error:', err.message);
  }

  fs.writeFileSync(path.join(__dirname, 'srilanka_test_receipts.json'), JSON.stringify(receipts, null, 2));
  console.log('\nAll Sri Lanka simulation tests completed! Saved to srilanka_test_receipts.json');
}

runTests().catch(console.error);
