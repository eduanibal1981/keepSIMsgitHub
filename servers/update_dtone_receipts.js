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

async function runDtone() {
  const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
  const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

  const dtTests = [
    { carrier: 'Deutsche Telekom', productId: 46871, recipient: '+491700000101', name: 'Telekom 10 EUR Direct Top-Up' },
    { carrier: 'Deutsche Telekom PIN', productId: 24361, recipient: '+491700000101', name: 'Telekom 5 EUR PIN Voucher' },
    { carrier: 'Deutsche Telekom', productId: 15304, recipient: '+491700000101', name: 'Telekom 15 EUR Direct Top-Up' },
    { carrier: 'Vodafone Germany', productId: 15313, recipient: '+491720000101', name: 'Vodafone 15 EUR Direct Top-Up' },
    { carrier: 'Vodafone Germany PIN', productId: 23386, recipient: '+491720000101', name: 'Vodafone 15 EUR PIN Voucher' },
    { carrier: 'O2 Germany', productId: 15301, recipient: '+491760000101', name: 'O2 15 EUR Direct Top-Up' },
    { carrier: 'O2 Germany PIN', productId: 23408, recipient: '+491760000101', name: 'O2 15 EUR PIN Voucher' }
  ];

  const receipts = [];

  for (const t of dtTests) {
    const extId = `dt_de_test_${Date.now()}_${t.productId}`;
    console.log(`Testing DT One ${t.carrier} (${t.name}) to ${t.recipient}...`);
    try {
      const res = await fetch(`${dtBase}/async/transactions`, {
        method: 'POST',
        headers: {
          Authorization: `Basic ${dtoneAuth}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          external_id: extId,
          product_id: t.productId,
          auto_confirm: true,
          credit_party_identifier: {
            mobile_number: t.recipient
          }
        })
      });
      const data = await res.json();
      console.log(`HTTP ${res.status}:`, JSON.stringify(data, null, 2));
      receipts.push({
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
    await sleep(2500);
  }

  const receiptsPath = path.join(__dirname, 'germany_test_receipts.json');
  let current = {};
  if (fs.existsSync(receiptsPath)) {
    try {
      current = JSON.parse(fs.readFileSync(receiptsPath, 'utf8'));
    } catch (e) {}
  }
  current.dtone = receipts;
  fs.writeFileSync(receiptsPath, JSON.stringify(current, null, 2));
  console.log('\nUpdated servers/germany_test_receipts.json with complete DT One receipts.');
}

runDtone();
