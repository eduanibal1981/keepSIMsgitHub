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

// Zendit
const zenditApiSecret = env.ZENDIT_API_SECRET;
const zenditBaseUrl = env.ZENDIT_BASE_URL || 'https://api.zendit.io/v1';

async function runPrecisionTests() {
  console.log('=== RUNNING PRECISION LIVE TESTS FOR ALL 5 PHILIPPINES CARRIERS ===\n');

  const tests = [
    {
      carrier: 'Globe Telecom',
      key: 'globe',
      phone: '+639170000101',
      dtone: { productId: 8142, name: 'Globe 10 PHP' },
      zendit: { offerId: 'GLOBE_PH_8_FEE', name: 'Globe 400 PHP ($7.76 USD)' }
    },
    {
      carrier: 'Smart Communications',
      key: 'smart',
      phone: '+639180000101',
      dtone: { productId: 7684, name: 'Smart 10 PHP' },
      zendit: { offerId: 'SMART_PH_6_FEE', name: 'Smart 300 PHP ($6.57 USD)' }
    },
    {
      carrier: 'DITO Telecommunity',
      key: 'dito',
      phone: '+639910000101',
      dtone: null,
      zendit: { offerId: 'DITO_PH_001', name: 'DITO 99 PHP ($1.69 USD)' }
    },
    {
      carrier: 'TM (Touch Mobile)',
      key: 'tm',
      phone: '+639050000101',
      dtone: { productId: 23309, name: 'Touch Mobile 10 PHP' },
      zendit: { offerId: 'TOUCHMOBILE_PH_0.1_FEE', name: 'Touch Mobile 10 PHP ($0.17 USD)' }
    },
    {
      carrier: 'TNT (Talk \'N Text)',
      key: 'tnt',
      phone: '+639080000101',
      dtone: { productId: 30059, name: 'TNT 20 PHP' },
      zendit: { offerId: 'TNT_PH_001', name: 'TNT 318 PHP ($5.42 USD)' }
    }
  ];

  const results = {};

  for (const t of tests) {
    console.log(`--------------------------------------------------`);
    console.log(`Testing ${t.carrier}...`);
    results[t.key] = {};

    // DT One
    if (t.dtone) {
      try {
        const payload = {
          external_id: `test_ph_dt_${t.key}_${Date.now()}`,
          product_id: t.dtone.productId,
          credit_party_identifier: { mobile_number: t.phone }
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
        console.log(`  [DT One] ${t.dtone.name} -> Status: ${res.status}, ID: ${data.id}, State: ${data.status?.message}, Cost: ${data.prices?.wholesale?.amount} ${data.prices?.wholesale?.unit}`);
        results[t.key].dtone = { status: res.status, id: data.id, state: data.status?.message, cost: data.prices?.wholesale, raw: data };
      } catch (err) {
        console.log(`  [DT One] Error:`, err.message);
        results[t.key].dtone = { error: err.message };
      }
    } else {
      console.log(`  [DT One] Unsupported (0 catalog products)`);
      results[t.key].dtone = { status: 'UNSUPPORTED' };
    }

    // Zendit
    if (t.zendit) {
      try {
        const payload = {
          offerId: t.zendit.offerId,
          recipientPhoneNumber: t.phone,
          transactionId: `test_ph_zen_${t.key}_${Date.now()}`
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
        console.log(`  [Zendit] ${t.zendit.name} -> Status: ${res.status}, Tx: ${data.transactionId}, State: ${data.status}`);
        results[t.key].zendit = { status: res.status, txId: data.transactionId, state: data.status, raw: data };
      } catch (err) {
        console.log(`  [Zendit] Error:`, err.message);
        results[t.key].zendit = { error: err.message };
      }
    }
  }

  fs.writeFileSync(path.join(__dirname, 'ph_verified_test_results.json'), JSON.stringify(results, null, 2));
  console.log('\n=== ALL PRECISION TESTS COMPLETED ===');
}

runPrecisionTests().catch(console.error);
