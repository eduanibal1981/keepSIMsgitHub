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

async function runZenditIraq() {
  const receiptsPath = path.join(__dirname, 'iraq_test_receipts.json');
  const receipts = JSON.parse(fs.readFileSync(receiptsPath, 'utf8'));

  console.log('--- RUNNING ZENDIT IRAQ SIMULATIONS ---');
  const zenSecret = env.ZENDIT_API_SECRET;
  const zenBase = 'https://api.zendit.io/v1';

  const zenTests = [
    { carrier: 'AsiaCell', offerId: 'ASIACELL_IQ_001', recipient: '+9647700000101', name: 'AsiaCell 5,000 IQD Direct Top-Up ($4.18 USD Net)' },
    { carrier: 'AsiaCell', offerId: 'ASIACELL_IQ_002', recipient: '+9647700000101', name: 'AsiaCell 10,000 IQD Direct Top-Up ($8.35 USD Net)' }
  ];

  receipts.zendit = [];

  for (const t of zenTests) {
    const txId = `zen_iq_test_${Date.now()}_${t.offerId.toLowerCase()}`;
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
    await sleep(2000);
  }

  fs.writeFileSync(receiptsPath, JSON.stringify(receipts, null, 2));
  console.log('\nUpdated iraq_test_receipts.json with Zendit results!');
}

runZenditIraq().catch(console.error);
