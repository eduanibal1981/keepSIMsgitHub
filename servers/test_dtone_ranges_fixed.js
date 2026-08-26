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
const sleep = ms => new Promise(r => setTimeout(r, ms));

async function testDTRange(carrier, productId, phone, amountLKR) {
  const externalId = `dt_lk_range_${Date.now()}_${productId}`;
  console.log(`\nTesting DT One Range [${productId}] ${carrier} (${amountLKR} LKR) to ${phone}...`);
  const body = {
    external_id: externalId,
    product_id: productId,
    auto_confirm: true,
    calculation_mode: 'DESTINATION_AMOUNT',
    destination: {
      amount: amountLKR,
      unit: 'LKR',
      unit_type: 'CURRENCY'
    },
    credit_party_identifier: {
      mobile_number: phone
    }
  };

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
    return data;
  } catch (err) {
    console.error(`Error:`, err.message);
  }
}

async function testDTFixed(carrier, productId, phone, name) {
  const externalId = `dt_lk_fixed_${Date.now()}_${productId}`;
  console.log(`\nTesting DT One Fixed [${productId}] ${carrier} (${name}) to ${phone}...`);
  const body = {
    external_id: externalId,
    product_id: productId,
    auto_confirm: true,
    credit_party_identifier: {
      mobile_number: phone
    }
  };

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
    return data;
  } catch (err) {
    console.error(`Error:`, err.message);
  }
}

async function main() {
  console.log('=== TESTING DT ONE RANGE & FIXED PRODUCTS ===');

  // Dialog Range
  await testDTRange('Dialog Sri Lanka', 11294, '+94770000101', 50);
  await sleep(1500);

  // Dialog Fixed Data / Blasters
  await testDTFixed('Dialog Sri Lanka', 61512, '+94770000101', '2.5 GB 30 Days (265 LKR)');
  await sleep(1500);

  // Mobitel Range
  await testDTRange('Mobitel Sri Lanka', 11296, '+94710000101', 50);
  await sleep(1500);

  // Mobitel Fixed
  await testDTFixed('Mobitel Sri Lanka', 63341, '+94710000101', 'Anytime Plan 512MB 7D (58 LKR)');
  await sleep(1500);

  // Hutchison Range
  await testDTRange('Hutchison Sri Lanka', 11295, '+94780000101', 50);
  await sleep(1500);

  // Hutchison Fixed Data
  await testDTFixed('Hutchison Sri Lanka', 44592, '+94780000101', 'Standard Data Plan 49 LKR');
  await sleep(1500);

  // Airtel on Dialog Range
  await testDTRange('Airtel Sri Lanka', 11294, '+94750000101', 50);
}

main().catch(console.error);
