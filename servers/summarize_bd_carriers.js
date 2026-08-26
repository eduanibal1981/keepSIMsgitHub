const fs = require('fs');
const path = require('path');

const data = JSON.parse(fs.readFileSync(path.join(__dirname, 'bangladesh_detailed_raw.json'), 'utf8'));

console.log('====================================================');
console.log('=== BANGLADESH CARRIERS SUMMARY ACROSS ALL PROVIDERS ===');
console.log('====================================================');

// DT ONE
console.log('\n--- DT ONE ---');
console.log('Operators:', data.dtone.operators.map(o => ({ id: o.id, name: o.name })));
const dtoneByOp = {};
data.dtone.products.forEach(p => {
  const opId = p.operator?.id;
  if (!dtoneByOp[opId]) dtoneByOp[opId] = [];
  dtoneByOp[opId].push({
    id: p.id,
    name: p.name,
    type: p.type,
    min: p.destination?.amount ? p.destination.amount : (p.destination?.min ? `${p.destination.min} - ${p.destination.max} ${p.destination.unit}` : 'N/A'),
    unit: p.destination?.unit,
    wholesale: p.prices?.wholesale || p.source
  });
});
for (const [opId, prods] of Object.entries(dtoneByOp)) {
  const opName = data.dtone.operators.find(o => o.id == opId)?.name || opId;
  console.log(`\nDT One Operator ${opId} (${opName}) - ${prods.length} products:`);
  prods.forEach(pr => console.log(`  Prod ${pr.id}: ${pr.name} | Type: ${pr.type} | Dest: ${pr.min} | Wholesale: ${JSON.stringify(pr.wholesale)}`));
}

// RELOADLY
console.log('\n--- RELOADLY ---');
data.reloadly.operators.forEach(o => {
  console.log(`\nReloadly Operator ${o.operatorId} (${o.name}):`);
  console.log(`  Type: ${o.denominationType} | Data: ${o.data} | Bundle: ${o.bundle} | Pin: ${o.pin}`);
  console.log(`  Min/Max USD: ${o.minAmount} - ${o.maxAmount} | Local: ${o.localMinAmount} - ${o.localMaxAmount} ${o.destinationCurrencyCode}`);
  console.log(`  FX Rate: ${o.fx?.rate} | Discount: ${o.internationalDiscount}%`);
  if (o.fixedAmounts && o.fixedAmounts.length > 0) {
    console.log(`  Fixed Amounts (${o.fixedAmounts.length}):`, o.fixedAmounts.map(f => `${f} USD (${o.fixedAmountsDescriptions[f] || ''})`));
  }
});

// ZENDIT
console.log('\n--- ZENDIT ---');
const zenditByBrand = {};
data.zendit.offers.forEach(o => {
  const b = o.brand;
  if (!zenditByBrand[b]) zenditByBrand[b] = [];
  zenditByBrand[b].push(o);
});
for (const [brand, offers] of Object.entries(zenditByBrand)) {
  console.log(`\nZendit Brand: ${brand} (${offers.length} offers):`);
  offers.forEach(o => {
    if (o.priceType === 'RANGE') {
      console.log(`  [RANGE] ${o.offerId}: Send ${o.send.min/100} - ${o.send.max/100} ${o.send.currency} | Cost: $${o.price.min/100} - $${o.price.max/100} USD (FX: ${o.price.fx})`);
    } else {
      console.log(`  [FIXED] ${o.offerId}: Send ${o.send.fixed/100} ${o.send.currency} | Cost: $${o.price.fixed/100} USD`);
    }
  });
}

// DINGCONNECT
console.log('\n--- DINGCONNECT ---');
console.log(`Providers in BD: ${data.ding.providers.length}`);
console.log(`Products in BD: ${data.ding.products.length} (UAT Status: 503 / 0 active offers)`);
