const fs = require('fs');
const path = require('path');

const candidatePaths = [
  path.join(__dirname, 'servers', '.env'),
  path.join(__dirname, '..', 'servers', '.env'),
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

const dtoneApiKey = env.DTONE_API_KEY;
const dtoneApiSecret = env.DTONE_API_SECRET;
const dtoneBaseUrl = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';
const dtoneAuthHeader = 'Basic ' + Buffer.from(`${dtoneApiKey}:${dtoneApiSecret}`).toString('base64');

const reloadlyClientId = env.RELOADLY_CLIENT_ID;
const reloadlyClientSecret = env.RELOADLY_CLIENT_SECRET;
const reloadlyBaseUrl = env.RELOADLY_BASE_URL || 'https://topups-sandbox.reloadly.com';
const reloadlyAuthUrl = env.RELOADLY_AUTH_URL || 'https://auth.reloadly.com/oauth/token';

const zenditApiSecret = env.ZENDIT_API_SECRET;
const zenditBaseUrl = env.ZENDIT_BASE_URL || 'https://api.zendit.io/v1';

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

async function runTests() {
  console.log('=== RUNNING LIVE SIMULATION TESTS FOR INDIA CARRIERS ===\n');
  const rlToken = await getReloadlyToken();

  const carriers = [
    {
      name: 'Reliance Jio',
      key: 'Jio',
      phone: '+919800000101',
      dtone: { productId: 18922, name: 'Unlimited Calls, Daily 2GB, Daily 100SMS, 28 Days (349 INR)' },
      zendit: { offerId: 'JIO_IN_3-I-BUNDLE', name: '239 INR Bundle' },
      reloadly: { operatorId: 786 }
    },
    {
      name: 'Bharti Airtel',
      key: 'Airtel',
      phone: '+919810000101',
      dtone: { productId: 8141, name: 'Topup Plan - 10 INR' },
      zendit: { offerId: 'AIRTEL_IN_11-I-BUNDLE', name: '859 INR Bundle' },
      reloadly: { operatorId: 200 }
    },
    {
      name: 'Vodafone Idea (Vi)',
      key: 'Vi',
      phone: '+919820000101',
      dtone: { productId: 28303, name: 'Vi India - Topup Plan - 10 INR' },
      zendit: { offerId: 'VODAFONEIDEA_IN_4.5-I-BUNDLE', name: '299 INR Bundle' },
      reloadly: { operatorId: 716 }
    },
    {
      name: 'BSNL',
      key: 'BSNL',
      phone: '+919400000101',
      dtone: { productId: 11087, name: 'BSNL India - Topup Plan - 10 INR' },
      zendit: { offerId: 'BSNL_IN_2.7-I-BUNDLE', name: '199 INR Bundle' },
      reloadly: { operatorId: 193 }
    },
    {
      name: 'MTNL',
      key: 'MTNL',
      phone: '+919868000101',
      dtone: { productId: 13500, name: 'MTNL India - Topup Plan INR 10' },
      zendit: null,
      reloadly: { operatorId: 194 }
    }
  ];

  const receipts = {};

  for (const c of carriers) {
    console.log(`=======================================================`);
    console.log(`TESTING: ${c.name}`);
    console.log(`=======================================================`);
    receipts[c.key] = {};

    // 1. DT One Test
    if (c.dtone) {
      console.log(`\n[DT One] Purchasing Product ${c.dtone.productId} (${c.dtone.name})...`);
      const dtPayload = {
        external_id: `test_in_dt_${c.key.toLowerCase()}_${Date.now()}`,
        product_id: c.dtone.productId,
        credit_party_identifier: {
          mobile_number: c.phone
        }
      };
      try {
        const res = await fetch(`${dtoneBaseUrl}/async/transactions`, {
          method: 'POST',
          headers: {
            Authorization: dtoneAuthHeader,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify(dtPayload)
        });
        const data = await res.json();
        console.log(`DT One Response [${res.status}]:`, JSON.stringify(data, null, 2));
        receipts[c.key].dtone = { status: res.status, data };
      } catch (e) {
        console.error(`DT One Error:`, e.message);
        receipts[c.key].dtone = { error: e.message };
      }
    }

    // 2. Zendit Test
    if (c.zendit) {
      console.log(`\n[Zendit] Purchasing Offer ${c.zendit.offerId}...`);
      const zPayload = {
        transactionId: `test_in_zen_${c.key.toLowerCase()}_${Date.now()}`,
        recipientPhoneNumber: c.phone,
        offerId: c.zendit.offerId
      };
      try {
        const res = await fetch(`${zenditBaseUrl}/topups/purchases`, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${zenditApiSecret}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify(zPayload)
        });
        const data = await res.json();
        console.log(`Zendit Response [${res.status}]:`, JSON.stringify(data, null, 2));
        receipts[c.key].zendit = { status: res.status, data };
      } catch (e) {
        console.error(`Zendit Error:`, e.message);
        receipts[c.key].zendit = { error: e.message };
      }
    }

    // 3. Reloadly Test
    if (c.reloadly) {
      console.log(`\n[Reloadly] Querying Operator ${c.reloadly.operatorId}...`);
      try {
        const res = await fetch(`${reloadlyBaseUrl}/operators/${c.reloadly.operatorId}`, {
          headers: { Authorization: `Bearer ${rlToken}`, Accept: 'application/com.reloadly.topups-v1+json' }
        });
        const data = await res.json();
        console.log(`Reloadly Operator Info:`, data.name, data.denominationType, data.fixedAmounts);
        receipts[c.key].reloadly = { status: res.status, operator: data };
      } catch (e) {
        console.error(`Reloadly Error:`, e.message);
        receipts[c.key].reloadly = { error: e.message };
      }
    }
  }

  fs.writeFileSync(path.join(__dirname, 'in_live_receipts.json'), JSON.stringify(receipts, null, 2));
  console.log('\nReceipts saved to in_live_receipts.json');
}

runTests().catch(console.error);
