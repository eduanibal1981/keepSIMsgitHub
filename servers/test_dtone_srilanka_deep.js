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

const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

async function testDTProduct(carrier, productId, phone, name, calculationMode = null, amount = null) {
  const externalId = `dt_lk_deep_${Date.now()}_${productId}`;
  console.log(`\nTesting DT One [${productId}] ${carrier} (${name}) to ${phone}...`);
  const body = {
    external_id: externalId,
    product_id: productId,
    auto_confirm: true,
    credit_party_identifier: {
      mobile_number: phone
    }
  };
  if (calculationMode) {
    body.calculation_mode = calculationMode;
    body.amount = amount;
  }

  try {
    const res = await fetch(`${dtBase}/async/transactions`, {
      method: 'POST',
      headers: {
        Authorization: `Basic ${dtoneAuth}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(body)
    });
    const data = await res.json();
    console.log(`HTTP ${res.status}:`, JSON.stringify(data, null, 2));
    return { carrier, productId, name, phone, status: res.status, data };
  } catch (err) {
    console.error(`Error:`, err.message);
    return { carrier, productId, name, phone, error: err.message };
  }
}

async function main() {
  console.log('=== DT ONE DEEP SRI LANKA TRANSACTIONS ===');

  // Dialog Tests
  await testDTProduct('Dialog Sri Lanka', 2601, '+94770000101', '100 LKR Fixed');
  await testDTProduct('Dialog Sri Lanka', 2602, '+94770000101', '200 LKR Fixed');
  await testDTProduct('Dialog Sri Lanka', 11294, '+94770000101', 'Open Range 50 LKR', 'DESTINATION_AMOUNT', 50);
  await testDTProduct('Dialog Sri Lanka', 61509, '+94770000101', 'Call Blaster 298 LKR');
  await testDTProduct('Dialog Sri Lanka', 61512, '+94770000101', '2.5 GB 30 Days');

  // Mobitel Tests
  await testDTProduct('Mobitel Sri Lanka', 38281, '+94710000101', '50 LKR Fixed');
  await testDTProduct('Mobitel Sri Lanka', 3265, '+94710000101', '100 LKR Fixed');
  await testDTProduct('Mobitel Sri Lanka', 11296, '+94710000101', 'Open Range 50 LKR', 'DESTINATION_AMOUNT', 50);
  await testDTProduct('Mobitel Sri Lanka', 63341, '+94710000101', 'Anytime Plan 512MB 7D');

  // Hutchison Tests
  await testDTProduct('Hutchison Sri Lanka', 6076, '+94780000101', '50 LKR Fixed');
  await testDTProduct('Hutchison Sri Lanka', 6077, '+94780000101', '100 LKR Fixed');
  await testDTProduct('Hutchison Sri Lanka', 11295, '+94780000101', 'Open Range 50 LKR', 'DESTINATION_AMOUNT', 50);
  await testDTProduct('Hutchison Sri Lanka', 44592, '+94780000101', 'Standard Data Plan 49 LKR');

  // Airtel on Dialog Rails
  await testDTProduct('Airtel Sri Lanka', 2601, '+94750000101', 'Airtel on Dialog 100 LKR');
  await testDTProduct('Airtel Sri Lanka', 11294, '+94750000101', 'Airtel Open Range 50 LKR', 'DESTINATION_AMOUNT', 50);
}

main().catch(console.error);
