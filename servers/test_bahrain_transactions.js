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
  console.log('=== RUNNING BAHRAIN (BH / BHR) LIVE SIMULATIONS ===');
  console.log('====================================================');

  // ==========================================
  // 1. DT ONE PRE-PROD TRANSACTIONS
  // ==========================================
  console.log('\n--- 1. DT ONE PRE-PROD TRANSACTIONS ---');
  const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
  const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

  const dtTests = [
    { carrier: 'Batelco', productId: 56728, recipient: '+97339000101', name: 'Batelco 2.25 BHD PIN' },
    { carrier: 'Zain Bahrain', productId: 58111, recipient: '+97336000101', name: 'Zain 1 BHD Airtime' }
  ];

  for (const t of dtTests) {
    const externalId = `dt_bh_test_${Date.now()}_${t.productId}`;
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
      { carrier: 'Batelco', operatorId: 22, amount: 3.05, recipient: '+97339000101', name: 'Batelco PIN ($3.05 USD)' },
      { carrier: 'Zain Bahrain', operatorId: 1165, amount: 1.55, recipient: '+97336000101', name: 'Zain Direct Airtime ($1.55 USD)' }
    ];

    for (const t of rlTests) {
      const refId = `rl_bh_test_${Date.now()}_${t.operatorId}`;
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
              countryCode: 'BH',
              number: t.recipient.replace('+973', '')
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
  // 3. ZENDIT OFFERS & ATTEMPT
  // ==========================================
  console.log('\n--- 3. ZENDIT BH OFFERS CHECK ---');
  try {
    const zenSecret = env.ZENDIT_API_SECRET;
    const zenBase = 'https://api.zendit.io/v1';

    const offRes = await fetch(`${zenBase}/topups/offers?country=BH&_offset=0&_limit=100`, {
      headers: { Authorization: `Bearer ${zenSecret}` }
    });
    const offers = await offRes.json();
    console.log('Zendit BH Offers count:', offers.total);
    receipts.zendit.push({
      status: 'checked',
      total: offers.total,
      data: offers
    });
  } catch (e) {
    console.error('Zendit Error:', e.message);
  }

  // ==========================================
  // 4. DINGCONNECT BH VALIDATION / PROVIDER STATUS
  // ==========================================
  console.log('\n--- 4. DINGCONNECT BH PROVIDERS CHECK ---');
  try {
    const dingKey = env.DING_API_KEY;
    const dingBase = 'https://api.dingconnect.com/api/V1';

    const provRes = await fetch(`${dingBase}/GetProviders?countryIsos=BH`, {
      headers: { api_key: dingKey }
    });
    const provData = await provRes.json();
    const bhTelecoms = provData.Items?.filter(p => p.ProviderCode === 'BVBH' || p.ProviderCode === 'ZABH');
    console.log('Ding Mapped Telecoms:', JSON.stringify(bhTelecoms, null, 2));
    receipts.ding.push({
      status: 'providers_mapped',
      items: bhTelecoms
    });
  } catch (e) {
    console.error('Ding Error:', e.message);
  }

  // Save all receipts
  fs.writeFileSync(path.join(__dirname, 'bahrain_test_receipts.json'), JSON.stringify(receipts, null, 2));
  console.log('\n====================================================');
  console.log('Saved all test receipts to bahrain_test_receipts.json');
  console.log('====================================================');
}

runTests();
