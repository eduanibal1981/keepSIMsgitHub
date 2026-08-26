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

async function testGlobeAndTM() {
  console.log('=== TESTING GLOBE & TM FIXES ===');
  // DT One Globe Product 12824 (10 PHP)
  const dtRes = await fetch(`${dtoneBaseUrl}/async/transactions`, {
    method: 'POST',
    headers: {
      Authorization: dtoneAuthHeader,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      external_id: `test_ph_dt_globe_${Date.now()}`,
      product_id: 12824,
      credit_party_identifier: { mobile_number: '+639170000101' }
    })
  });
  const dtData = await dtRes.json();
  console.log(`DT One Globe (12824): Status ${dtRes.status}`, JSON.stringify(dtData, null, 2));

  // Zendit TM Offer TOUCHMOBILE_PH_001 (150 PHP)
  const zenRes = await fetch(`${zenditBaseUrl}/topups/purchases`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${zenditApiSecret}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      offerId: 'TOUCHMOBILE_PH_001',
      recipientPhoneNumber: '+639050000101',
      transactionId: `test_ph_zen_tm_${Date.now()}`
    })
  });
  const zenData = await zenRes.json();
  console.log(`Zendit TM (TOUCHMOBILE_PH_001): Status ${zenRes.status}`, JSON.stringify(zenData, null, 2));
}

testGlobeAndTM().catch(console.error);
