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

async function main() {
  const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
  const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

  const dtTests = [
    { carrier: 'Orange Morocco', productId: 50285, recipient: '+212661000101', name: 'Orange Morocco 6 MAD Airtime' },
    { carrier: 'Inwi Morocco', productId: 16801, recipient: '+212620000101', name: 'Inwi Morocco 5 MAD Airtime' }
  ];

  const receiptsPath = path.join(__dirname, 'morocco_test_receipts.json');
  const receipts = JSON.parse(fs.readFileSync(receiptsPath, 'utf8'));

  for (const t of dtTests) {
    const externalId = `dt_mar_verify_${Date.now()}_${t.productId}`;
    console.log(`Verifying DT One ${t.carrier} (${t.name})...`);
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
    console.log(`Status ${res.status}:`, JSON.stringify(data, null, 2));
    receipts.dtone.push({
      carrier: t.carrier,
      name: t.name,
      productId: t.productId,
      recipient: t.recipient,
      httpStatus: res.status,
      response: data
    });
  }

  fs.writeFileSync(receiptsPath, JSON.stringify(receipts, null, 2));
  console.log('Updated morocco_test_receipts.json');
}

main().catch(console.error);
