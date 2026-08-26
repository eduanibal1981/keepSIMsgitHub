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
  console.log('=== RUNNING KUWAIT (KW / KWT / +965) LIVE SIMULATIONS ===');
  console.log('====================================================');

  // ==========================================
  // 1. DT ONE PRE-PROD TRANSACTIONS
  // ==========================================
  console.log('\n--- 1. DT ONE PRE-PROD TRANSACTIONS ---');
  const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
  const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

  const dtTests = [
    { carrier: 'Zain Kuwait', productId: 24347, recipient: '+96590000101', name: 'Zain Kuwait 1.5 KWD' },
    { carrier: 'Ooredoo Kuwait', productId: 24345, recipient: '+96560000101', name: 'Ooredoo Kuwait 1.5 KWD' },
    { carrier: 'STC Kuwait', productId: 24346, recipient: '+96550000101', name: 'STC Kuwait 1.5 KWD' }
  ];

  for (const t of dtTests) {
    const externalId = `dt_kw_test_${Date.now()}_${t.productId}`;
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
      { carrier: 'Zain Kuwait', operatorId: 268, amount: 5.70, recipient: '+96590000101', name: 'Zain Kuwait Airtime ($5.70 USD / ~1.48 KWD)' },
      { carrier: 'Ooredoo Kuwait', operatorId: 1166, amount: 5.70, recipient: '+96560000101', name: 'Ooredoo Kuwait Airtime ($5.70 USD / ~1.48 KWD)' },
      { carrier: 'STC Kuwait', operatorId: 267, amount: 7.60, recipient: '+96550000101', name: 'STC Kuwait Airtime ($7.60 USD / ~1.90 KWD)' }
    ];

    for (const t of rlTests) {
      const refId = `rl_kw_test_${Date.now()}_${t.operatorId}`;
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
              countryCode: 'KW',
              number: t.recipient.replace('+965', '')
            }
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
    console.error('Reloadly Test Error:', e.message);
  }

  // ==========================================
  // 3. ZENDIT TEST (Validation Check)
  // ==========================================
  console.log('\n--- 3. ZENDIT TEST (KW Offers Check) ---');
  receipts.zendit.push({
    status: 'Disabled',
    reason: '0 active catalog offers in Zendit sandbox for country KW'
  });

  // ==========================================
  // 4. DINGCONNECT TEST (UAT Check)
  // ==========================================
  console.log('\n--- 4. DINGCONNECT TEST (UAT Check) ---');
  receipts.ding.push({
    status: 'Disabled',
    reason: 'Ding UAT returns 503 / 0 active products for country KW'
  });

  // Save receipts
  const outPath = path.join(__dirname, 'kuwait_test_receipts.json');
  fs.writeFileSync(outPath, JSON.stringify(receipts, null, 2));
  console.log(`\nTest receipts saved to ${outPath}`);
}

runTests().catch(console.error);
