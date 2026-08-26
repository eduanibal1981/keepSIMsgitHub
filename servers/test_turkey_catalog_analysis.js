const fs = require('fs');
const path = require('path');

const raw = JSON.parse(fs.readFileSync(path.join(__dirname, 'turkey_discovery_raw.json'), 'utf8'));

console.log('====================================================');
console.log('=== DETAILED CATALOG BREAKDOWN FOR TURKEY (TR) ===');
console.log('====================================================');

// 1. DT ONE PRODUCTS
console.log('\n====================================================');
console.log('--- 1. DT ONE PRODUCTS BY OPERATOR ---');
console.log('====================================================');
const dtProducts = raw.dtone_products || [];
const dtByOp = {};
dtProducts.forEach(p => {
  const opId = p.operator?.id;
  const opName = p.operator?.name;
  if (!dtByOp[opId]) {
    dtByOp[opId] = { name: opName, products: [] };
  }
  dtByOp[opId].products.push(p);
});

for (const [opId, data] of Object.entries(dtByOp)) {
  console.log(`\nOperator ID: ${opId} | Name: ${data.name} | Total Products: ${data.products.length}`);
  data.products.sort((a, b) => (a.destination?.amount || 0) - (b.destination?.amount || 0));
  data.products.forEach(p => {
    console.log(`  ID: ${p.id} | Name: "${p.name}" | Type: ${p.type} | Dest: ${p.destination?.amount} ${p.destination?.unit} | Wholesale: ${p.prices?.wholesale?.amount} ${p.prices?.wholesale?.unit} | Retail: ${p.prices?.retail?.amount} ${p.prices?.retail?.unit}`);
  });
}

// 2. RELOADLY OPERATORS & PRODUCTS
console.log('\n====================================================');
console.log('--- 2. RELOADLY OPERATORS & PRODUCTS ---');
console.log('====================================================');
const rlOperators = raw.reloadly_operators || [];
rlOperators.forEach(op => {
  console.log(`\nOperator ID: ${op.operatorId} | Name: ${op.name} | Bundle: ${op.bundle} | Data: ${op.data} | Pin: ${op.pin}`);
  console.log(`  FX Rate: 1 USD = ${op.fx?.rate} ${op.fx?.currencyCode} | Discount: Local ${op.localDiscount}%, Intl ${op.internationalDiscount}%`);
  console.log(`  Denominations (Total: ${op.fixedAmounts ? op.fixedAmounts.length : 0}):`);
  if (op.fixedAmounts) {
    op.fixedAmounts.forEach((amt, idx) => {
      const localAmt = op.localFixedAmounts ? op.localFixedAmounts[idx] : 'N/A';
      const desc = op.fixedAmountsDescriptions ? op.fixedAmountsDescriptions[amt] : '';
      console.log(`    $${amt} USD -> ${localAmt} TRY | "${desc}"`);
    });
  }
});

// 3. ZENDIT OFFERS
console.log('\n====================================================');
console.log('--- 3. ZENDIT OFFERS ---');
console.log('====================================================');
const zenOffers = raw.zendit_offers?.list || [];
zenOffers.forEach(o => {
  console.log(`Offer ID: ${o.offerId} | Brand: ${o.brand} | Name: "${o.name}" | SubTypes: ${JSON.stringify(o.subTypes)}`);
  console.log(`  Wholesale Price: ${o.price?.fixed / (o.price?.currencyDivisor || 100)} ${o.price?.currency} | Send: ${o.send?.fixed / (o.send?.currencyDivisor || 100)} ${o.send?.currency}`);
});

// 4. DING PROVIDERS & PRODUCTS
console.log('\n====================================================');
console.log('--- 4. DINGCONNECT STATUS ---');
console.log('====================================================');
console.log('Ding Providers for TR:', (raw.ding_providers?.Items || []).map(p => `${p.ProviderCode}: ${p.Name}`));
console.log('Ding Products Status:', JSON.stringify(raw.ding_products, null, 2));
