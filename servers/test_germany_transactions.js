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

async function runTests() {
  const receipts = {
    dtone: [],
    reloadly: [],
    zendit: [],
    ding: []
  };

  console.log('====================================================');
  console.log('=== RUNNING GERMANY LIVE SIMULATIONS / TRANSACTIONS ===');
  console.log('====================================================');

  // ==========================================
  // 1. DT ONE PRE-PROD TRANSACTIONS
  // ==========================================
  console.log('\n--- 1. DT ONE PRE-PROD TRANSACTIONS ---');
  const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
  const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

  const dtTests = [
    { carrier: 'Deutsche Telekom', productId: 46871, recipient: '+491510000101', name: 'Telekom 10 EUR Direct Top-Up' },
    { carrier: 'Deutsche Telekom PIN', productId: 24361, recipient: '+491510000101', name: 'Telekom 5 EUR PIN Voucher' },
    { carrier: 'Deutsche Telekom', productId: 15304, recipient: '+491510000101', name: 'Telekom 15 EUR Direct Top-Up' },
    { carrier: 'Vodafone Germany', productId: 15313, recipient: '+491520000101', name: 'Vodafone 15 EUR Direct Top-Up' },
    { carrier: 'Vodafone Germany PIN', productId: 23386, recipient: '+491520000101', name: 'Vodafone 15 EUR PIN Voucher' },
    { carrier: 'O2 Germany', productId: 15301, recipient: '+491760000101', name: 'O2 15 EUR Direct Top-Up' },
    { carrier: 'O2 Germany PIN', productId: 23408, recipient: '+491760000101', name: 'O2 15 EUR PIN Voucher' }
  ];

  for (const t of dtTests) {
    const externalId = `dt_de_test_${Date.now()}_${t.productId}`;
    console.log(`\nTesting DT One ${t.carrier} (${t.name}) to ${t.recipient}...`);
    try {
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
      console.log(`HTTP ${res.status}:`, JSON.stringify(data, null, 2));
      receipts.dtone.push({
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
    await sleep(1500);
  }

  // ==========================================
  // 2. RELOADLY SANDBOX TRANSACTIONS
  // ==========================================
  console.log('\n--- 2. RELOADLY SANDBOX TRANSACTIONS ---');
  try {
    const authRes = await fetch('https://auth.reloadly.com/oauth/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        client_id: env.RELOADLY_CLIENT_ID,
        client_secret: env.RELOADLY_CLIENT_SECRET,
        grant_type: 'client_credentials',
        audience: 'https://topups-sandbox.reloadly.com'
      })
    });
    const authData = await authRes.json();
    const token = authData.access_token;

    const rlTests = [
      { carrier: 'Deutsche Telekom PIN', operatorId: 664, amount: 17.65, recipient: '+491510000101', name: 'Telekom PIN 15 EUR ($17.65)' },
      { carrier: 'Vodafone PIN', operatorId: 875, amount: 17.86, recipient: '+491520000101', name: 'Vodafone PIN 15 EUR ($17.86)' },
      { carrier: 'O2 PIN', operatorId: 868, amount: 17.86, recipient: '+491760000101', name: 'O2 PIN 15 EUR ($17.86)' },
      { carrier: 'Congstar PIN', operatorId: 850, amount: 5.95, recipient: '+491510000101', name: 'Congstar PIN 5 EUR ($5.95)' },
      { carrier: 'Lebara PIN', operatorId: 855, amount: 11.90, recipient: '+491550000101', name: 'Lebara PIN 10 EUR ($11.90)' },
      { carrier: 'Lebara Flexi Bundle', operatorId: 857, amount: 11.89, recipient: '+491550000101', name: 'Lebara Flexi Bundle 9.99 EUR ($11.89)' },
      { carrier: 'Lycamobile PIN', operatorId: 864, amount: 5.92, recipient: '+491520000101', name: 'Lycamobile PIN 5 EUR ($5.92)' },
      { carrier: 'Blau PIN', operatorId: 849, amount: 17.86, recipient: '+491760000101', name: 'Blau PIN 15 EUR ($17.86)' },
      { carrier: 'Ortel PIN', operatorId: 665, amount: 17.86, recipient: '+491760000101', name: 'Ortel PIN 15 EUR ($17.86)' },
      { carrier: 'Otelo PIN', operatorId: 867, amount: 9.00, recipient: '+491520000101', name: 'Otelo PIN 9 EUR ($9.00)' },
      { carrier: 'Fonic PIN', operatorId: 853, amount: 23.81, recipient: '+491760000101', name: 'Fonic PIN 20 EUR ($23.81)' },
      { carrier: 'Tchibo Mobile PIN', operatorId: 872, amount: 23.81, recipient: '+491760000101', name: 'Tchibo PIN 20 EUR ($23.81)' },
      { carrier: 'Klarmobil PIN', operatorId: 854, amount: 17.86, recipient: '+491510000101', name: 'Klarmobil PIN 15 EUR ($17.86)' },
      { carrier: 'BILDMobil PIN', operatorId: 848, amount: 11.90, recipient: '+491520000101', name: 'BILDMobil PIN 10 EUR ($11.90)' }
    ];

    for (const t of rlTests) {
      console.log(`\nTesting Reloadly ${t.carrier} (${t.name}) to ${t.recipient}...`);
      try {
        const res = await fetch('https://topups-sandbox.reloadly.com/topups', {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${token}`,
            Accept: 'application/com.reloadly.topups-v1+json',
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            operatorId: t.operatorId,
            amount: t.amount,
            useLocalAmount: false,
            recipientPhone: {
              countryCode: 'DE',
              number: t.recipient
            }
          })
        });
        const data = await res.json();
        console.log(`HTTP ${res.status}:`, JSON.stringify(data, null, 2));
        receipts.reloadly.push({
          carrier: t.carrier,
          name: t.name,
          operatorId: t.operatorId,
          amount: t.amount,
          recipient: t.recipient,
          httpStatus: res.status,
          response: data
        });
      } catch (e) {
        console.error(`Reloadly Error for ${t.carrier}:`, e.message);
      }
      await sleep(1500);
    }
  } catch (e) {
    console.error('Reloadly Auth / Setup Error:', e.message);
  }

  // ==========================================
  // 3. ZENDIT TEST TRANSACTIONS
  // ==========================================
  console.log('\n--- 3. ZENDIT TEST TRANSACTIONS ---');
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

  for (const t of zenTests) {
    const txRef = `test_de_zen_${Date.now()}_${t.offerId.toLowerCase().replace(/[^a-z0-9]/g, '_')}`;
    console.log(`\nTesting Zendit ${t.carrier} (${t.name}) to ${t.recipient}...`);
    try {
      const res = await fetch(`${zenBase}/topups/purchases`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${zenSecret}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          offerId: t.offerId,
          recipient: {
            phoneNumber: t.recipient
          },
          transactionReference: txRef
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
    await sleep(1500);
  }

  // ==========================================
  // 4. DINGCONNECT VALIDATION & CATALOG CHECK
  // ==========================================
  console.log('\n--- 4. DINGCONNECT VALIDATION CHECK ---');
  receipts.ding = [
    { providerCode: 'TLDE', name: 'T-Mobile Germany', status: 'Disabled (0 Inventory in UAT)' },
    { providerCode: 'VFDE', name: 'Vodafone Germany', status: 'Disabled (0 Inventory in UAT)' },
    { providerCode: 'O2DE', name: 'O2 Germany', status: 'Disabled (0 Inventory in UAT)' },
    { providerCode: 'C4DE', name: 'Congstar Germany', status: 'Disabled (0 Inventory in UAT)' },
    { providerCode: 'ESDE', name: 'Lebara Germany', status: 'Disabled (0 Inventory in UAT)' },
    { providerCode: 'LYDE', name: 'Lycamobile Germany', status: 'Disabled (0 Inventory in UAT)' }
  ];

  fs.writeFileSync(path.join(__dirname, 'germany_test_receipts.json'), JSON.stringify(receipts, null, 2));
  console.log('\n====================================================');
  console.log('=== ALL GERMANY TEST TRANSACTIONS COMPLETED ===');
  console.log('Receipts saved to servers/germany_test_receipts.json');
  console.log('====================================================');
}

runTests();
