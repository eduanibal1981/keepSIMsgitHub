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
  console.log('=== RUNNING BANGLADESH (BD / BGD) LIVE SIMULATIONS ===');
  console.log('====================================================');

  // ==========================================
  // 1. DT ONE PRE-PROD TRANSACTIONS
  // ==========================================
  console.log('\n--- 1. DT ONE PRE-PROD TRANSACTIONS ---');
  const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
  const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

  const dtTests = [
    { carrier: 'Grameenphone', productId: 3428, recipient: '+8801700000101', name: 'Grameenphone 50 BDT' },
    { carrier: 'Robi Axiata', productId: 3424, recipient: '+8801800000101', name: 'Robi 50 BDT' },
    { carrier: 'Banglalink', productId: 3432, recipient: '+8801900000101', name: 'Banglalink 50 BDT' },
    { carrier: 'Teletalk Bangladesh', productId: 3466, recipient: '+8801500000101', name: 'Teletalk 50 BDT' },
    { carrier: 'Airtel Bangladesh', productId: 3470, recipient: '+8801600000101', name: 'Airtel 50 BDT' }
  ];

  for (const t of dtTests) {
    const externalId = `dt_bd_test_${Date.now()}_${t.productId}`;
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
      { carrier: 'Grameenphone', operatorId: 26, amount: 0.50, recipient: '+8801700000101', name: 'Grameenphone Airtime ($0.50 / ~55.5 BDT)' },
      { carrier: 'Robi Axiata', operatorId: 25, amount: 0.50, recipient: '+8801800000101', name: 'Robi Airtime ($0.50 / ~55.5 BDT)' },
      { carrier: 'Banglalink', operatorId: 24, amount: 0.50, recipient: '+8801900000101', name: 'Banglalink Airtime ($0.50 / ~55.5 BDT)' },
      { carrier: 'Teletalk Bangladesh', operatorId: 27, amount: 0.50, recipient: '+8801500000101', name: 'Teletalk Airtime ($0.50 / ~55.5 BDT)' },
      { carrier: 'Airtel Bangladesh', operatorId: 28, amount: 0.50, recipient: '+8801600000101', name: 'Airtel Airtime ($0.50 / ~55.5 BDT)' }
    ];

    for (const t of rlTests) {
      const refId = `rl_bd_test_${Date.now()}_${t.operatorId}`;
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
              countryCode: 'BD',
              number: t.recipient.replace('+880', '')
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
      await sleep(1500);
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
    { carrier: 'Grameenphone', offerId: 'GRAMEENPHONE_BD_001', recipient: '+8801700000101', name: 'Grameenphone 50 BDT ($0.60 USD)' },
    { carrier: 'Robi Axiata', offerId: 'ROBI_BD_001', recipient: '+8801800000101', name: 'Robi 50 BDT ($0.60 USD)' },
    { carrier: 'Banglalink', offerId: 'BANGLALINK_BD_001', recipient: '+8801900000101', name: 'Banglalink 50 BDT ($0.60 USD)' },
    { carrier: 'Teletalk Bangladesh', offerId: 'TELETALK_BD_001', recipient: '+8801500000101', name: 'Teletalk 56.24 BDT ($0.60 USD)' },
    { carrier: 'Airtel Bangladesh', offerId: 'AIRTEL_BD_001', recipient: '+8801600000101', name: 'Airtel 50 BDT ($0.60 USD)' }
  ];

  for (const t of zenTests) {
    const txId = `zen_bd_test_${Date.now()}_${t.offerId.toLowerCase().replace(/[^a-z0-9]/g, '_')}`;
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

  // ==========================================
  // 4. DINGCONNECT DRY RUN / VALIDATE ONLY
  // ==========================================
  console.log('\n--- 4. DINGCONNECT DRY RUN / VALIDATE ONLY ---');
  const dingKey = env.DING_API_KEY;
  const dingBase = 'https://api.dingconnect.com/api/V1';

  try {
    const dingProviders = [
      { code: 'GEBD', name: 'Grameenphone Bangladesh' },
      { code: 'RLBD', name: 'Robi Bangladesh' },
      { code: 'TQBD', name: 'Teletalk Bangladesh' },
      { code: 'BGBD', name: 'Banglalink Bangladesh' },
      { code: 'AXBD', name: 'Airtel / Cirkle Bangladesh' }
    ];
    for (const item of dingProviders) {
      console.log(`\nChecking DingConnect provider for ${item.name} (${item.code})...`);
      const valRes = await fetch(`${dingBase}/GetProviders?providerCodes=${item.code}`, {
        headers: { api_key: dingKey }
      });
      const valData = await valRes.json();
      console.log(`Ding Provider Check ${item.code}:`, valData.Items && valData.Items.length > 0 ? `Found (${valData.Items[0].Name})` : 'Not found');
      receipts.ding.push({
        providerCode: item.code,
        name: item.name,
        status: valData.Items && valData.Items.length > 0 ? 'Provider Active / Products 503' : 'Inactive',
        details: valData
      });
    }
  } catch (e) {
    console.error('DingConnect Error:', e.message);
  }

  fs.writeFileSync(path.join(__dirname, 'bangladesh_test_receipts.json'), JSON.stringify(receipts, null, 2));
  console.log('\nAll test receipts saved to servers/bangladesh_test_receipts.json');
}

runTests().catch(console.error);
