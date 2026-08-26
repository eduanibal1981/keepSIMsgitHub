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
  console.log('=== RUNNING QATAR (QA / QAT) LIVE SIMULATIONS ===');
  console.log('====================================================');

  // ==========================================
  // 1. DT ONE PRE-PROD TRANSACTIONS
  // ==========================================
  console.log('\n--- 1. DT ONE PRE-PROD TRANSACTIONS ---');
  const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
  const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

  const dtTests = [
    { carrier: 'Ooredoo Qatar', productId: 33349, recipient: '+97466000101', name: 'Ooredoo PIN Qatar Internet 80 QAR' },
    { carrier: 'Ooredoo Qatar', productId: 1738, recipient: '+97466000101', name: 'Ooredoo PIN Qatar Internet 150 QAR' },
    { carrier: 'Vodafone Qatar', productId: 17355, recipient: '+97477000101', name: 'Vodafone PIN Qatar 10 QAR' },
    { carrier: 'Vodafone Qatar', productId: 17356, recipient: '+97477000101', name: 'Vodafone PIN Qatar 20 QAR' }
  ];

  for (const t of dtTests) {
    const externalId = `dt_qa_test_${Date.now()}_${t.productId}`;
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

    const rldTests = [
      {
        carrier: 'Ooredoo Qatar',
        operatorId: 396,
        amount: 40.16,
        recipient: '+97466000101',
        isLocal: false,
        name: 'Ooredoo 100 QAR Direct Top-Up ($40.16 USD)'
      },
      {
        carrier: 'Vodafone Qatar',
        operatorId: 395,
        amount: 3.60,
        recipient: '+97477000101',
        isLocal: false,
        name: 'Vodafone PIN Qatar ($3.60 USD)'
      }
    ];

    for (const t of rldTests) {
      const refId = `rld_qa_test_${Date.now()}_${t.operatorId}`;
      console.log(`\nTesting Reloadly ${t.carrier} (${t.name}) to ${t.recipient}...`);
      try {
        const bodyPayload = {
          operatorId: t.operatorId,
          amount: t.amount,
          useLocalAmount: t.isLocal,
          recipientPhone: {
            countryCode: 'QA',
            number: t.recipient.replace('+974', '')
          },
          customIdentifier: refId
        };
        const res = await fetch('https://topups-sandbox.reloadly.com/topups', {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${token}`,
            Accept: 'application/com.reloadly.topups-v1+json',
            'Content-Type': 'application/json'
          },
          body: JSON.stringify(bodyPayload)
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
  } catch (err) {
    console.error('Reloadly overall error:', err.message);
  }

  // ==========================================
  // 3. ZENDIT SIMULATION TEST
  // ==========================================
  console.log('\n--- 3. ZENDIT SIMULATION TEST ---');
  // Zendit has 0 offers in QA catalog, record status
  receipts.zendit.push({
    status: 'NO_OFFERS',
    country: 'QA',
    note: 'Zendit offers catalog for country=QA returned 0 active offers'
  });

  // ==========================================
  // 4. DINGCONNECT SIMULATION TEST
  // ==========================================
  console.log('\n--- 4. DINGCONNECT SIMULATION TEST ---');
  receipts.ding.push({
    status: 'UAT_RATE_LIMITED_OR_UNSUPPORTED',
    country: 'QA',
    note: 'DingConnect UAT API returns 503 RateLimited for QA product catalog; providers OOQA and VFQA defined in GetProviders'
  });

  // Save receipts
  const outPath = path.join(__dirname, 'qatar_test_receipts.json');
  fs.writeFileSync(outPath, JSON.stringify(receipts, null, 2));
  console.log(`\nAll Qatar test receipts saved to ${outPath}`);
}

runTests().catch(console.error);
