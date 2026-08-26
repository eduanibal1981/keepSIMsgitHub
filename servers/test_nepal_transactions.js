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
  console.log('=== RUNNING NEPAL (NP / NPL / +977) LIVE SIMULATIONS ===');
  console.log('====================================================');

  // ==========================================
  // 1. DT ONE PRE-PROD TRANSACTIONS
  // ==========================================
  console.log('\n--- 1. DT ONE PRE-PROD TRANSACTIONS ---');
  const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
  const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

  const dtTests = [
    { carrier: 'Ncell', productId: 4658, recipient: '+9779800000101', name: 'Ncell 50 NPR' },
    { carrier: 'Ncell', productId: 47518, recipient: '+9779800000101', name: 'Ncell RS 30 - 100MB Data' },
    { carrier: 'NTC (Nepal Telecom)', productId: 6972, recipient: '+9779840000101', name: 'NTC 10 NPR' },
    { carrier: 'NTC (Nepal Telecom)', productId: 6976, recipient: '+9779840000101', name: 'NTC 50 NPR' },
    { carrier: 'NTC (Nepal Telecom)', productId: 61849, recipient: '+9779840000101', name: 'NTC 600 MB All Time Data (22.44 NPR)' }
  ];

  for (const t of dtTests) {
    const externalId = `dt_np_test_${Date.now()}_${t.productId}`;
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
    await sleep(1000);
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
      { carrier: 'Ncell', operatorId: 328, amount: 1.00, recipientPhone: '+9779800000101', name: 'Ncell $1.00 Airtime' },
      { carrier: 'Ncell Data', operatorId: 1121, amount: 0.23, recipientPhone: '+9779800000101', name: 'Ncell Data $0.23 Bundle' },
      { carrier: 'NTC GSM', operatorId: 326, amount: 1.00, recipientPhone: '+9779840000101', name: 'NTC $1.00 Airtime' },
      { carrier: 'NTC Data', operatorId: 1123, amount: 0.17, recipientPhone: '+9779840000101', name: 'NTC Data $0.17 Bundle' },
      { carrier: 'Smartcell', operatorId: 805, amount: 0.08, recipientPhone: '+9779610000101', name: 'Smartcell $0.08 Topup' }
    ];

    for (const t of rlTests) {
      const customId = `rl_np_test_${Date.now()}_${t.operatorId}`;
      console.log(`\nTesting Reloadly ${t.carrier} (${t.name}) to ${t.recipientPhone}...`);
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
              countryCode: 'NP',
              number: t.recipientPhone.replace('+977', '')
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
          amount: t.amount,
          recipient: t.recipientPhone,
          httpStatus: res.status,
          response: data
        });
      } catch (e) {
        console.error(`Reloadly Error for ${t.carrier}:`, e.message);
      }
      await sleep(1000);
    }
  } catch (e) {
    console.error('Reloadly Auth Error:', e.message);
  }

  // ==========================================
  // 3. ZENDIT SIMULATION TRANSACTIONS
  // ==========================================
  console.log('\n--- 3. ZENDIT SIMULATION TRANSACTIONS ---');
  try {
    const zenSecret = env.ZENDIT_API_SECRET;
    const zenBase = 'https://api.zendit.io/v1';

    const zenTests = [
      { carrier: 'Ncell', offerId: 'NCELL_NP_6-I', recipient: '+9779800000101', name: 'Ncell 6 USD Offer (668.82 NPR)' },
      { carrier: 'Ncell', offerId: 'NCELL_NP_12-I', recipient: '+9779800000101', name: 'Ncell 12 USD Offer (1337.64 NPR)' },
      { carrier: 'NTC GSM', offerId: 'NTCGSM_NP_2.5-I', recipient: '+9779840000101', name: 'NTC 2.5 USD Offer (236.34 NPR)' },
      { carrier: 'NTC GSM', offerId: 'NTCGSM_NP_6-I', recipient: '+9779840000101', name: 'NTC 6 USD Offer (597.80 NPR)' }
    ];

    for (const t of zenTests) {
      const txId = `zen_np_test_${Date.now()}_${t.offerId.toLowerCase().replace(/[^a-z0-9]/g, '_')}`;
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
      await sleep(1000);
    }
  } catch (e) {
    console.error('Zendit Error:', e.message);
  }

  // ==========================================
  // 4. DINGCONNECT VALIDATION & AUDIT
  // ==========================================
  console.log('\n--- 4. DINGCONNECT AUDIT ---');
  receipts.ding = [
    {
      carrier: 'Ncell',
      providerCode: 'NCNP',
      name: 'Ncell Nepal',
      status: 'Disabled / 0 UAT Catalog SKUs',
      regex: '^977(9(?:80|81|82|70|71|72|73)[0-9]{7})$'
    },
    {
      carrier: 'Ncell Data',
      providerCode: '6NNP',
      name: 'Ncell Nepal Data',
      status: 'Disabled / 0 UAT Catalog SKUs',
      regex: '^977(9(?:80|81|82|70|71|72|73)[0-9]{7})$'
    },
    {
      carrier: 'Nepal Telecom (NTC)',
      providerCode: 'NENP',
      name: 'Nepal Telecom Nepal',
      status: 'Disabled / 0 UAT Catalog SKUs',
      regex: '^977(9(?:84|85|86|74|76|04)[0-9]{7})$'
    },
    {
      carrier: 'Nepal Telecom Data',
      providerCode: '8NNP',
      name: 'Nepal Telecom Nepal Data',
      status: 'Disabled / 0 UAT Catalog SKUs',
      regex: '^977(9(?:84|85|86|74|76|04)[0-9]{7})$'
    }
  ];

  // Save receipts
  const outPath = path.join(__dirname, 'nepal_test_receipts.json');
  fs.writeFileSync(outPath, JSON.stringify(receipts, null, 2));
  console.log(`\nTest simulations complete! Receipts saved to ${outPath}`);
}

runTests().catch(console.error);
