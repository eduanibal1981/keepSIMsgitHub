const fs = require('fs');
const path = require('path');

const data = JSON.parse(fs.readFileSync(path.join(__dirname, 'germany_discovery_raw.json'), 'utf8'));

console.log('=== 1. DT ONE OPERATORS & PRODUCTS SUMMARY ===');
console.log('Operators:', data.dtone.operators.map(o => `${o.id}: ${o.name}`));
console.log('\nProducts by Operator:');
const dtoneByOp = {};
data.dtone.products.forEach(p => {
  const opName = p.operator?.name || 'Unknown';
  if (!dtoneByOp[opName]) dtoneByOp[opName] = [];
  dtoneByOp[opName].push({
    id: p.id,
    name: p.name,
    type: p.type,
    wholesale_omr: p.prices?.wholesale?.amount,
    wholesale_cur: p.prices?.wholesale?.unit,
    dest_val: p.destination?.amount,
    dest_cur: p.destination?.unit,
    validity: p.validity
  });
});
for (const [op, prods] of Object.entries(dtoneByOp)) {
  console.log(`\n-- ${op} (${prods.length} products) --`);
  prods.forEach(p => console.log(`   Product ${p.id}: ${p.name} | Type: ${p.type} | Dest: ${p.dest_val} ${p.dest_cur} | Wholesale: ${p.wholesale_omr} ${p.wholesale_cur}`));
}

console.log('\n=== 2. RELOADLY OPERATORS SUMMARY ===');
data.reloadly.operators.forEach(op => {
  console.log(`\nOp ID: ${op.operatorId} | Name: ${op.name} | Bundle: ${op.bundle} | Data: ${op.data} | Pin: ${op.pin}`);
  console.log(`   Denom Type: ${op.denominationType} | Min: ${op.minAmount} | Max: ${op.maxAmount} | Fixed: ${JSON.stringify(op.fixedAmounts)}`);
  console.log(`   FX Rate: ${JSON.stringify(op.fx)} | Local Currency: ${op.destinationCurrencyCode} | Sender: ${op.senderCurrencyCode}`);
  if (op.fixedAmountsDescriptions) {
    console.log(`   Fixed Descriptions:`, JSON.stringify(op.fixedAmountsDescriptions));
  }
});

console.log('\n=== 3. ZENDIT OFFERS SUMMARY ===');
const zenByBrand = {};
data.zendit.offers.forEach(o => {
  if (!zenByBrand[o.brand]) zenByBrand[o.brand] = [];
  zenByBrand[o.brand].push(o);
});
for (const [brand, offers] of Object.entries(zenByBrand)) {
  console.log(`\n-- Brand: ${brand} (${offers.length} offers) --`);
  offers.forEach(o => {
    console.log(`   OfferId: ${o.offerId} | Name: ${o.name} | Price: ${o.price?.cost} ${o.price?.currency} | Send: ${o.send?.value} ${o.send?.currency} | SubTypes: ${JSON.stringify(o.subTypes)}`);
  });
}

console.log('\n=== 4. DINGCONNECT PROVIDERS ===');
if (data.ding.providers?.Items) {
  const telecomCodes = ['TLDE', 'VFDE', 'O2DE', 'C4DE', 'ESDE', 'LYDE', 'AYDE', 'BSDE', 'OTDE', 'OEDE', 'F1DE', 'B6DE', 'E825B8DE', 'EPDE', 'M4DE', 'V6DE', 'O1DE', 'C7DE', 'C8DE', 'A9DE', 'O3DE', 'O4DE', 'FYDE', 'F2DE'];
  data.ding.providers.Items.forEach(p => {
    if (telecomCodes.includes(p.ProviderCode) || p.Name.toLowerCase().includes('telekom') || p.Name.toLowerCase().includes('vodafone') || p.Name.toLowerCase().includes('o2') || p.Name.toLowerCase().includes('lebara') || p.Name.toLowerCase().includes('congstar') || p.Name.toLowerCase().includes('lyca') || p.Name.toLowerCase().includes('fonic') || p.Name.toLowerCase().includes('blau') || p.Name.toLowerCase().includes('ortel') || p.Name.toLowerCase().includes('otelo') || p.Name.toLowerCase().includes('ay yildiz')) {
      console.log(`   Ding Provider: ${p.ProviderCode} | Name: ${p.Name} | ValidationRegex: ${p.ValidationRegex}`);
    }
  });
}
