const fs = require('fs');
const path = require('path');

// 1. DT One
const dtoneProducts = JSON.parse(fs.readFileSync(path.join(__dirname, 'dtone_om_products.json'), 'utf8'));
const dtoneOps = JSON.parse(fs.readFileSync(path.join(__dirname, 'dtone_om_operators.json'), 'utf8'));

console.log('==================================================');
console.log('1. DT ONE OMAN FULL CATALOG');
console.log('==================================================');
console.log(`Total Products: ${dtoneProducts.length}`);
const dtoneByOp = {};
for (const p of dtoneProducts) {
  const op = p.operator?.name || 'Unknown';
  if (!dtoneByOp[op]) dtoneByOp[op] = [];
  dtoneByOp[op].push(p);
}

for (const [op, prods] of Object.entries(dtoneByOp)) {
  console.log(`\n--- Operator: ${op} (${prods.length} products) ---`);
  prods.forEach(p => {
    console.log(`  ID: ${p.id} | Name: ${p.name} | Type: ${p.type} | Service: ${p.service?.name}`);
    console.log(`    Destination: ${p.destination?.amount} ${p.destination?.unit} | Source: ${p.source?.amount} ${p.source?.unit}`);
    console.log(`    Prices: Retail=${p.prices?.retail?.amount} ${p.prices?.retail?.unit} | Wholesale=${p.prices?.wholesale?.amount} ${p.prices?.wholesale?.unit}`);
  });
}

// 2. Reloadly
console.log('\n==================================================');
console.log('2. RELOADLY OMAN FULL CATALOG');
console.log('==================================================');
const reloadlyOps = JSON.parse(fs.readFileSync(path.join(__dirname, 'reloadly_om_operators.json'), 'utf8'));
console.log(`Total Reloadly Operators: ${reloadlyOps.length}`);
for (const op of reloadlyOps) {
  console.log(`\n--- Operator ID: ${op.operatorId} - ${op.name} ---`);
  console.log(`  DenominationType: ${op.denominationType}, Bundle: ${op.bundle}, Data: ${op.data}, Pin: ${op.pin}`);
  console.log(`  Fixed Amounts (USD): ${JSON.stringify(op.fixedAmounts)}`);
  console.log(`  Local Fixed Amounts: ${JSON.stringify(op.localFixedAmounts)}`);
  console.log(`  Min/Max Amount: ${op.minAmount} - ${op.maxAmount}`);
  console.log(`  FX Rate: ${op.fx?.rate} (Currency: ${op.fx?.currencyCode} -> ${op.destinationCurrencyCode})`);
  console.log(`  Sender Currency: ${op.senderCurrencyCode}, Dest Currency: ${op.destinationCurrencyCode}`);
}

// 3. DingConnect
console.log('\n==================================================');
console.log('3. DINGCONNECT OMAN FULL CATALOG');
console.log('==================================================');
const dingProviders = JSON.parse(fs.readFileSync(path.join(__dirname, 'ding_om_providers.json'), 'utf8'));
console.log(`Ding Providers count: ${dingProviders.Items?.length || 0}`);
const omProviders = (dingProviders.Items || []).filter(p => ['OMOM', 'OOOM', 'VFOM'].includes(p.ProviderCode));
console.log('Mobile Providers in Ding:', omProviders);

// 4. Zendit
console.log('\n==================================================');
console.log('4. ZENDIT OMAN FULL CATALOG');
console.log('==================================================');
const zenditOffers = JSON.parse(fs.readFileSync(path.join(__dirname, 'zendit_om_offers.json'), 'utf8'));
console.log(`Zendit Offers count: ${zenditOffers.length}`);
