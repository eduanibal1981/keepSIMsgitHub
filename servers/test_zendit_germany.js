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

async function runZenditTests() {
  console.log('====================================================');
  console.log('=== RUNNING ZENDIT GERMANY TRANSACTIONS ===');
  console.log('====================================================');

  const zenSecret = env.ZENDIT_API_SECRET;
  const zenBase = 'https://api.zendit.io/v1';

  const zenTests = [
    { carrier: 'Deutsche Telekom', offerId: 'TELEKOM_DE_001-ROW', recipient: '+491510000101', name: 'Telekom 15 EUR ($16.84 USD)' },
    { carrier: 'Vodafone Germany', offerId: 'VODAFONE_DE_001-ROW', recipient: '+491520000101', name: 'Vodafone 15 EUR ($18.59 USD)' },
    { carrier: 'O2 Germany', offerId: 'O2_DE_001-ROW', recipient: '+491760000101', name: 'O2 15 EUR ($18.75 USD)' },
    { carrier: 'Congstar', offerId: 'CONGSTAR_DE_001-ROW', recipient: '+491510000101', name: 'Congstar 15 EUR ($18.52 USD)' },
    { carrier: 'Blau', offerId: 'BLAU_DE_001-ROW', recipient: '+491760000101', name: 'Blau 15 EUR ($18.99 USD)' },
    { carrier: 'Ortel', offerId: 'ORTEL_DE_001-ROW', recipient: '+491760000101', name: 'Ortel 15 EUR ($18.75 USD)' },
    { carrier: 'Ay Yildiz', offerId: 'AYYILDIZ_DE_001-ROW', recipient: '+491760000101', name: 'Ay Yildiz 15 EUR ($18.73 USD)' },
    { carrier: 'Otelo', offerId: 'OTELO_DE_001-ROW', recipient: '+491520000101', name: 'Otelo 9 EUR ($11.25 USD)' }
  ];

  const zenditReceipts = [];

  for (const t of zenTests) {
    const txId = `zen_de_test_${Date.now()}_${t.offerId.toLowerCase().replace(/[^a-z0-9]/g, '_')}`;
    console.log(`\nTesting Zendit ${t.carrier} (${t.name}) to ${t.recipient}...`);
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
      zenditReceipts.push({
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

  const receiptsPath = path.join(__dirname, 'germany_test_receipts.json');
  let current = {};
  if (fs.existsSync(receiptsPath)) {
    try {
      current = JSON.parse(fs.readFileSync(receiptsPath, 'utf8'));
    } catch (e) {}
  }
  current.zendit = zenditReceipts;
  fs.writeFileSync(receiptsPath, JSON.stringify(current, null, 2));
  console.log('\nUpdated servers/germany_test_receipts.json with Zendit receipts.');
}

runZenditTests();
