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
  const receipts = {};

  console.log('====================================================');
  console.log('=== RUNNING TURKEY LIVE SIMULATIONS / TRANSACTIONS ===');
  console.log('====================================================');

  // ==========================================
  // 1. DT ONE PRE-PROD TRANSACTIONS
  // ==========================================
  console.log('\n--- 1. DT ONE PRE-PROD TRANSACTIONS ---');
  const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
  const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

  const dtTests = [
    { carrier: 'Turkcell', productId: 67167, recipient: '+905320000101', name: 'Turkcell 200 TRY' },
    { carrier: 'Vodafone Turkey', productId: 50568, recipient: '+905420000101', name: 'Vodafone TR 250 TRY' },
    { carrier: 'Turk Telekom', productId: 48513, recipient: '+905550000101', name: 'Turk Telekom 300 TRY' },
    { carrier: 'Vodafone Cyprus', productId: 11581, recipient: '+905420000101', name: 'Vodafone Cyprus 12 TRY' }
  ];

  receipts.dtone = [];

  for (const t of dtTests) {
    const externalId = `dt_tr_test_${Date.now()}_${t.productId}`;
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
      { carrier: 'Turkcell', operatorId: 509, amount: 1.82, recipient: '+905320000101', name: 'Turkcell Airtime 65 TRY ($1.82)' },
      { carrier: 'Turkcell Data', operatorId: 1177, amount: 2.52, recipient: '+905320000101', name: 'Turkcell Oyna Paketi 90 TRY ($2.52)' },
      { carrier: 'Vodafone Turkey', operatorId: 512, amount: 7.01, recipient: '+905420000101', name: 'Vodafone TR Airtime 250 TRY ($7.01)' },
      { carrier: 'Vodafone Turkey Data', operatorId: 1178, amount: 2.52, recipient: '+905420000101', name: 'Vodafone TR Haftalik Iletisim 90 TRY ($2.52)' },
      { carrier: 'Turk Telekom', operatorId: 510, amount: 8.41, recipient: '+905550000101', name: 'Turk Telekom Airtime 300 TRY ($8.41)' }
    ];

    receipts.reloadly = [];

    for (const t of rlTests) {
      const customId = `rl_tr_test_${Date.now()}_${t.operatorId}`;
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
              countryCode: 'TR',
              number: t.recipient
            },
            customIdentifier: customId
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
      await sleep(1500);
    }
  } catch (e) {
    console.error('Reloadly Auth Error:', e.message);
  }

  // ==========================================
  // 3. ZENDIT TEST TRANSACTIONS
  // ==========================================
  console.log('\n--- 3. ZENDIT TEST TRANSACTIONS ---');
  const zenSecret = env.ZENDIT_API_SECRET;
  const zenBase = 'https://api.zendit.io/v1';

  const zenTests = [
    { carrier: 'Turkcell', offerId: 'TURKCELL_TR_10-I', recipient: '+905320000101', name: 'Turkcell 200 TRY ($10 USD)' },
    { carrier: 'Vodafone Turkey', offerId: 'VODAFONE_TR_001', recipient: '+905420000101', name: 'Vodafone TR 100 TRY ($5 USD)' },
    { carrier: 'Turk Telekom', offerId: 'TURKTELECOM_TR_004_USD', recipient: '+905550000101', name: 'Turk Telekom 300 TRY ($15 USD)' }
  ];

  receipts.zendit = [];

  for (const t of zenTests) {
    const txId = `test_tr_zen_${Date.now()}_${t.offerId.toLowerCase().replace(/[^a-z0-9]/g, '_')}`;
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

  fs.writeFileSync(path.join(__dirname, 'turkey_test_receipts.json'), JSON.stringify(receipts, null, 2));
  console.log('\nSaved all test receipts to servers/turkey_test_receipts.json');
}

runTests();
