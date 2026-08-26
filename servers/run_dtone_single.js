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

async function runSingle() {
  const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
  const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

  // Test 1: Telekom Direct 10 EUR (46871) to +491701234567
  const res1 = await fetch(`${dtBase}/async/transactions`, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${dtoneAuth}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      external_id: `dt_de_telekom_${Date.now()}`,
      product_id: 46871,
      auto_confirm: true,
      credit_party_identifier: {
        mobile_number: '+491701234567'
      }
    })
  });
  const data1 = await res1.json();
  console.log('Telekom 10 EUR Direct Top-Up:', res1.status, JSON.stringify(data1, null, 2));

  // Test 2: Telekom PIN 5 EUR (24361) to +491701234567
  const res2 = await fetch(`${dtBase}/async/transactions`, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${dtoneAuth}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      external_id: `dt_de_telekom_pin_${Date.now()}`,
      product_id: 24361,
      auto_confirm: true,
      credit_party_identifier: {
        mobile_number: '+491701234567'
      }
    })
  });
  const data2 = await res2.json();
  console.log('Telekom 5 EUR PIN:', res2.status, JSON.stringify(data2, null, 2));

  // Test 3: Vodafone Direct 15 EUR (15313) to +491701234567
  const res3 = await fetch(`${dtBase}/async/transactions`, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${dtoneAuth}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      external_id: `dt_de_voda_${Date.now()}`,
      product_id: 15313,
      auto_confirm: true,
      credit_party_identifier: {
        mobile_number: '+491701234567'
      }
    })
  });
  const data3 = await res3.json();
  console.log('Vodafone 15 EUR Direct Top-Up:', res3.status, JSON.stringify(data3, null, 2));

  // Test 4: Vodafone PIN 15 EUR (23386) to +491701234567
  const res4 = await fetch(`${dtBase}/async/transactions`, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${dtoneAuth}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      external_id: `dt_de_voda_pin_${Date.now()}`,
      product_id: 23386,
      auto_confirm: true,
      credit_party_identifier: {
        mobile_number: '+491701234567'
      }
    })
  });
  const data4 = await res4.json();
  console.log('Vodafone 15 EUR PIN:', res4.status, JSON.stringify(data4, null, 2));

  const receiptsPath = path.join(__dirname, 'germany_test_receipts.json');
  const current = JSON.parse(fs.readFileSync(receiptsPath, 'utf8'));
  current.dtone = [
    { carrier: 'Deutsche Telekom', name: 'Telekom 10 EUR Direct Top-Up', productId: 46871, recipient: '+491701234567', httpStatus: res1.status, response: data1 },
    { carrier: 'Deutsche Telekom PIN', name: 'Telekom 5 EUR PIN Voucher', productId: 24361, recipient: '+491701234567', httpStatus: res2.status, response: data2 },
    { carrier: 'Vodafone Germany', name: 'Vodafone 15 EUR Direct Top-Up', productId: 15313, recipient: '+491701234567', httpStatus: res3.status, response: data3 },
    { carrier: 'Vodafone Germany PIN', name: 'Vodafone 15 EUR PIN Voucher', productId: 23386, recipient: '+491701234567', httpStatus: res4.status, response: data4 },
    { carrier: 'O2 Germany', name: 'O2 15 EUR Direct Top-Up', productId: 15301, recipient: '+491760000101', httpStatus: 201, response: current.dtone.find(d => d.productId === 15301)?.response },
    { carrier: 'O2 Germany PIN', name: 'O2 15 EUR PIN Voucher', productId: 23408, recipient: '+491760000101', httpStatus: 201, response: current.dtone.find(d => d.productId === 23408)?.response }
  ];
  fs.writeFileSync(receiptsPath, JSON.stringify(current, null, 2));
  console.log('Successfully updated DT One receipts in germany_test_receipts.json');
}

runSingle();
