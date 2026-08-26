const fs = require('fs');
const path = require('path');

const data = JSON.parse(fs.readFileSync(path.join(__dirname, 'germany_discovery_raw.json'), 'utf8'));

console.log('====================================================');
console.log('=== DT ONE GERMANY OPERATORS & PRODUCTS ===');
console.log('====================================================');
const dtoneByOp = {};
data.dtone.products.forEach(p => {
  const opName = p.operator?.name || 'Unknown';
  const opId = p.operator?.id;
  const key = `${opId}: ${opName}`;
  if (!dtoneByOp[key]) dtoneByOp[key] = [];
  dtoneByOp[key].push(p);
});

for (const [op, prods] of Object.entries(dtoneByOp)) {
  console.log(`\n### Operator: ${op} (${prods.length} products)`);
  prods.forEach(p => {
    console.log(`  Product ${p.id}: ${p.name} | Type: ${p.type} | Dest: ${p.destination?.amount} ${p.destination?.unit} | Wholesale: ${p.prices?.wholesale?.amount} ${p.prices?.wholesale?.unit} | Retail: ${p.prices?.retail?.amount} ${p.prices?.retail?.unit}`);
  });
}

console.log('\n====================================================');
console.log('=== RELOADLY GERMANY OPERATORS ===');
console.log('====================================================');
data.reloadly.operators.forEach(op => {
  console.log(`\nOperator ID ${op.operatorId}: ${op.name}`);
  console.log(`  Denom Type: ${op.denominationType} | Pin: ${op.pin} | Data: ${op.data} | Bundle: ${op.bundle}`);
  console.log(`  Fixed Amounts (USD): ${JSON.stringify(op.fixedAmounts)}`);
  console.log(`  Local Fixed Amounts (EUR): ${JSON.stringify(op.localFixedAmounts)}`);
  console.log(`  FX: ${JSON.stringify(op.fx)} | Discounts: ${JSON.stringify(op.internationalDiscount || op.discount)}`);
});

console.log('\n====================================================');
console.log('=== ZENDIT GERMANY OFFERS ===');
console.log('====================================================');
data.zendit.offers.forEach(o => {
  console.log(`Offer ID: ${o.offerId} | Brand: ${o.brand} | Name: ${o.name} | Cost: ${JSON.stringify(o.cost)} | Price: ${JSON.stringify(o.price)} | Value: ${JSON.stringify(o.value)} | Send: ${JSON.stringify(o.send)} | Recipient: ${JSON.stringify(o.recipient)}`);
});
