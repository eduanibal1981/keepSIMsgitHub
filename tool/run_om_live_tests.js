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
  console.log('LIVE TEST SIMULATIONS & TRANSACTIONS: OMAN (OM / +968)');
  console.log('========================================================================\n');

  const rlToken = await getReloadlyToken();

  const carriers = [
    {
      name: 'Omantel',
      key: 'omantel',
      phone: '+96891000101',
      dtone: { productId: 17091, name: 'Omantel PIN 1 OMR' },
      reloadly: { operatorId: 348, amount: 3.00, localAmount: 1, isPin: true },
      zendit: null,
      ding: { providerCode: 'OMOM' }
    },
    {
      name: 'Ooredoo Oman',
      key: 'ooredoo',
      phone: '+96895000101',
      dtone: { productId: 18802, name: 'Ooredoo PIN 1 OMR' },
      reloadly: { operatorId: 1168, amount: 2.95, localAmount: 1, isPin: false },
      zendit: null,
      ding: { providerCode: 'OOOM' }
    },
    {
      name: 'Vodafone Oman',
      key: 'vodafone',
      phone: '+96877000101',
      dtone: null,
      reloadly: null,
      zendit: null,
      ding: { providerCode: 'VFOM' }
    },
    {
      name: 'FRiENDi Mobile Oman',
      key: 'friendi',
      phone: '+96898000101',
      dtone: null,
      reloadly: null,
      zendit: null,
      ding: null
    },
    {
      name: 'Renna Mobile',
      key: 'renna',
      phone: '+96893000101',
      dtone: { productId: 42651, name: 'Renna PIN 0.3 OMR' },
      reloadly: { operatorId: 349, amount: 1.50, localAmount: 0.5, isPin: true },
      zendit: null,
      ding: null
    },
    {
      name: 'Red Bull Mobile Oman',
      key: 'redbull',
      phone: '+96894000101',
      dtone: { productId: 42652, name: 'Red Bull PIN 0.3 OMR' },
      reloadly: null,
      zendit: null,
      ding: null
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
          external_id: `test_om_dt_${c.key}_${Date.now()}`,
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
      console.log(`\n1. DT One: N/A (Unsupported in pre-prod)`);
      results[c.key].dtone = { status: 'UNSUPPORTED' };
    }

    // 2. RELOADLY
    if (c.reloadly) {
      try {
        console.log(`\n2. Testing Reloadly: Operator ${c.reloadly.operatorId} (${c.reloadly.isPin ? 'PIN Voucher' : 'Direct Top-Up'})...`);
        const payload = {
          recipientPhone: {
            countryCode: 'OM',
            number: c.phone.replace('+968', '')
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
    } else {
      console.log(`\n2. Reloadly: N/A (Unsupported in sandbox)`);
      results[c.key].reloadly = { status: 'UNSUPPORTED' };
    }

    // 3. ZENDIT
    console.log(`\n3. Zendit: Unsupported (0 offers in OM catalog)`);
    results[c.key].zendit = { status: 'DISABLED_0_OFFERS' };

    // 4. DINGCONNECT
    if (c.ding) {
      try {
        console.log(`\n4. Testing DingConnect: Provider ${c.ding.providerCode}...`);
        const pRes = await fetch(`${dingBaseUrl}/GetProviders?countryIsos=OM`, {
          headers: { api_key: dingApiKey }
        });
        const pData = await pRes.json();
        const item = (pData.Items || []).find(p => p.ProviderCode === c.ding.providerCode);
        console.log(`   Ding Provider [${c.ding.providerCode}] Info:`, item ? `${item.Name} (${item.ValidationRegex})` : 'Not Found');
        results[c.key].ding = {
          providerCode: c.ding.providerCode,
          providerName: item?.Name || null,
          validationRegex: item?.ValidationRegex || null,
          uatOffers: 0,
          status: 'CATALOG_MAPPED_0_UAT_PRODUCTS'
        };
      } catch (err) {
        console.error(`   Ding Error:`, err.message);
        results[c.key].ding = { error: err.message };
      }
    } else {
      console.log(`\n4. DingConnect: N/A`);
      results[c.key].ding = { status: 'UNSUPPORTED' };
    }
  }

  fs.writeFileSync(path.join(__dirname, 'om_live_test_receipts.json'), JSON.stringify(results, null, 2));
  console.log('\n========================================================================');
  console.log('ALL OM LIVE TEST SIMULATIONS COMPLETED & SAVED TO om_live_test_receipts.json');
  console.log('========================================================================');
}

runLiveTests().catch(console.error);
