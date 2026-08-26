const fs = require('fs');
const path = require('path');

const candidatePaths = [
  path.join(__dirname, '..', 'servers', '.env'),
  path.join(__dirname, 'servers', '.env'),
  path.join(__dirname, '.env'),
  '/home/abdal/keepsims_backend/servers/.env'
];
let env = {};
for (const p of candidatePaths) {
  if (fs.existsSync(p)) {
    const content = fs.readFileSync(p, 'utf8');
    content.split('\n').forEach(line => {
      const m = line.match(/^\s*([\w_]+)\s*=\s*(.*)?\s*$/);
      if (m) {
        let v = (m[2] || '').trim();
        if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) {
          v = v.slice(1, -1);
        }
        env[m[1]] = v;
      }
    });
    break;
  }
}

// DT One
const dtoneApiKey = env.DTONE_API_KEY;
const dtoneApiSecret = env.DTONE_API_SECRET;
const dtoneBaseUrl = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';
const dtoneAuthHeader = 'Basic ' + Buffer.from(`${dtoneApiKey}:${dtoneApiSecret}`).toString('base64');

// Reloadly
const reloadlyClientId = env.RELOADLY_CLIENT_ID;
const reloadlyClientSecret = env.RELOADLY_CLIENT_SECRET;
const reloadlyBaseUrl = env.RELOADLY_BASE_URL || 'https://topups-sandbox.reloadly.com';
const reloadlyAuthUrl = env.RELOADLY_AUTH_URL || 'https://auth.reloadly.com/oauth/token';

// Zendit
const zenditApiSecret = env.ZENDIT_API_SECRET;
const zenditBaseUrl = env.ZENDIT_BASE_URL || 'https://api.zendit.io/v1';

// DingConnect
const dingApiKey = env.DING_API_KEY;
const dingBaseUrl = env.DING_BASE_URL || 'https://api.dingconnect.com/api/V1';

async function getReloadlyToken() {
  const audience = reloadlyBaseUrl.replace(/\/$/, '');
  const res = await fetch(reloadlyAuthUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client_id: reloadlyClientId,
      client_secret: reloadlyClientSecret,
      grant_type: 'client_credentials',
      audience: audience,
    }),
  });
  const data = await res.json();
  return data.access_token;
}

async function runLiveTests() {
  console.log('========================================================================');
  console.log('LIVE TEST SIMULATIONS & TRANSACTIONS: PHILIPPINES (PH / +63)');
  console.log('========================================================================\n');

  const rlToken = await getReloadlyToken();

  const carriers = [
    {
      name: 'Globe Telecom',
      key: 'globe',
      phone: '+639170000101',
      dtone: { productId: 8142, name: 'Globe Telecom Philippines 10 PHP' },
      zendit: { offerId: 'GLOBE_PH_001', name: 'Globe 300 PHP ($5.42 USD)' },
      reloadly: { operatorId: 371, amount: 0.18, localAmount: 10 },
      ding: { providerCode: 'GBPH', skuCode: 'PH_GB_TopUp' }
    },
    {
      name: 'Smart Communications',
      key: 'smart',
      phone: '+639180000101',
      dtone: { productId: 23473, name: 'Smart Philippines 10 PHP' },
      zendit: { offerId: 'SMART_PH_001', name: 'Smart 300 PHP ($5.42 USD)' },
      reloadly: { operatorId: 372, amount: 0.27, localAmount: 15 },
      ding: { providerCode: 'SMPH', skuCode: 'PH_SM_TopUp' }
    },
    {
      name: 'DITO Telecommunity',
      key: 'dito',
      phone: '+639910000101',
      dtone: null,
      zendit: { offerId: 'DITO_PH_001', name: 'DITO 99 PHP ($1.69 USD)' },
      reloadly: { operatorId: 1182, amount: 0.18, localAmount: 10 },
      ding: { providerCode: 'DWPH', skuCode: 'PH_DW_TopUp' }
    },
    {
      name: 'TM (Touch Mobile)',
      key: 'tm',
      phone: '+639050000101',
      dtone: { productId: 23482, name: 'Touch Mobile Philippines 10 PHP' },
      zendit: { offerId: 'TOUCHMOBILE_PH_001', name: 'Touch Mobile 10 PHP ($0.17 USD)' },
      reloadly: { operatorId: 723, amount: 0.18, localAmount: 10 },
      ding: { providerCode: 'TMPH', skuCode: 'PH_TM_TopUp' }
    },
    {
      name: 'TNT (Talk \'N Text)',
      key: 'tnt',
      phone: '+639080000101',
      dtone: { productId: 23475, name: 'TNT Philippines 10 PHP' },
      zendit: { offerId: 'TNT_PH_001', name: 'TNT 318 PHP ($5.42 USD)' },
      reloadly: { operatorId: 378, amount: 0.18, localAmount: 10 },
      ding: { providerCode: 'STPH', skuCode: 'PH_ST_TopUp' }
    }
  ];

  const results = {};

  for (const c of carriers) {
    console.log(`\n========================================================`);
    console.log(`TESTING CARRIER: ${c.name} (${c.key.toUpperCase()})`);
    console.log(`========================================================`);
    results[c.key] = { name: c.name };

    // 1. DT ONE
    if (c.dtone) {
      try {
        console.log(`\n1. Testing DT One: Product ${c.dtone.productId} (${c.dtone.name})...`);
        const payload = {
          external_id: `test_ph_dt_${c.key}_${Date.now()}`,
          product_id: c.dtone.productId,
          credit_party_identifier: {
            mobile_number: c.phone
          }
        };
        const res = await fetch(`${dtoneBaseUrl}/async/transactions`, {
          method: 'POST',
          headers: {
            Authorization: dtoneAuthHeader,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify(payload)
        });
        const data = await res.json();
        console.log(`   DT One Status: ${res.status}`);
        console.log(`   DT One Response:`, JSON.stringify(data, null, 2));
        results[c.key].dtone = {
          status: res.status,
          txId: data.id,
          state: data.status?.message || data.status?.class?.message,
          cost: data.prices?.wholesale,
          raw: data
        };
      } catch (err) {
        console.error(`   DT One Error:`, err.message);
        results[c.key].dtone = { error: err.message };
      }
    } else {
      console.log(`\n1. DT One: N/A (Not cataloged in DT One)`);
      results[c.key].dtone = { status: 'UNSUPPORTED' };
    }

    // 2. ZENDIT
    if (c.zendit) {
      try {
        console.log(`\n2. Testing Zendit: Offer ${c.zendit.offerId}...`);
        const payload = {
          offerId: c.zendit.offerId,
          recipientPhoneNumber: c.phone,
          transactionId: `test_ph_zen_${c.key}_${Date.now()}`
        };
        const res = await fetch(`${zenditBaseUrl}/topups/purchases`, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${zenditApiSecret}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify(payload)
        });
        const data = await res.json();
        console.log(`   Zendit Status: ${res.status}`);
        console.log(`   Zendit Response:`, JSON.stringify(data, null, 2));
        results[c.key].zendit = {
          status: res.status,
          txStatus: data.status,
          txId: data.transactionId,
          cost: data.cost,
          price: data.price,
          raw: data
        };
      } catch (err) {
        console.error(`   Zendit Error:`, err.message);
        results[c.key].zendit = { error: err.message };
      }
    } else {
      console.log(`\n2. Zendit: N/A`);
      results[c.key].zendit = { status: 'UNSUPPORTED' };
    }

    // 3. RELOADLY
    if (c.reloadly) {
      try {
        console.log(`\n3. Testing Reloadly: Operator ${c.reloadly.operatorId}...`);
        const payload = {
          recipientPhone: {
            countryCode: 'PH',
            number: c.phone.replace('+63', '')
          },
          operatorId: c.reloadly.operatorId,
          amount: c.reloadly.amount,
          useLocalAmount: false
        };
        const res = await fetch(`${reloadlyBaseUrl}/topups`, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${rlToken}`,
            'Content-Type': 'application/json',
            Accept: 'application/com.reloadly.topups-v1+json'
          },
          body: JSON.stringify(payload)
        });
        const data = await res.json();
        console.log(`   Reloadly Status: ${res.status}`);
        console.log(`   Reloadly Response:`, JSON.stringify(data, null, 2));
        results[c.key].reloadly = {
          status: res.status,
          txId: data.transactionId,
          txStatus: data.status,
          cost: data.balanceInfo?.cost,
          pinDetail: data.pinDetail,
          raw: data
        };
      } catch (err) {
        console.error(`   Reloadly Error:`, err.message);
        results[c.key].reloadly = { error: err.message };
      }
    }

    // 4. DINGCONNECT
    try {
      console.log(`\n4. Testing DingConnect (Querying provider / catalog in UAT)...`);
      const pRes = await fetch(`${dingBaseUrl}/GetProducts?providerCodes=${c.ding.providerCode}&countryIsos=PH`, {
        headers: { api_key: dingApiKey }
      });
      const pData = await pRes.json();
      console.log(`   Ding Provider [${c.ding.providerCode}] ResultCode: ${pData.ResultCode}, Count: ${pData.Items?.length || 0}`);
      results[c.key].ding = {
        providerCode: c.ding.providerCode,
        resultCode: pData.ResultCode,
        itemsCount: pData.Items?.length || 0
      };
    } catch (err) {
      console.error(`   Ding Error:`, err.message);
      results[c.key].ding = { error: err.message };
    }
  }

  fs.writeFileSync(path.join(__dirname, 'ph_live_test_receipts.json'), JSON.stringify(results, null, 2));
  console.log('\n========================================================================');
  console.log('ALL PH LIVE TEST SIMULATIONS COMPLETED & SAVED TO ph_live_test_receipts.json');
  console.log('========================================================================');
}

runLiveTests().catch(console.error);
