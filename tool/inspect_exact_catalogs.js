const fs = require('fs');
const path = require('path');

// Read raw analysis if exists
const rawPath = path.join(__dirname, 'in_analysis_raw.json');
let raw = {};
if (fs.existsSync(rawPath)) {
  raw = JSON.parse(fs.readFileSync(rawPath, 'utf8'));
}

console.log('=== 1. ZENDIT BRANDS & OFFERS FOR IN ===');
if (raw.zendit && raw.zendit.offers) {
  const byBrand = {};
  for (const o of raw.zendit.offers) {
    const b = o.brand;
    if (!byBrand[b]) byBrand[b] = [];
    byBrand[b].push(o);
  }
  for (const [b, list] of Object.entries(byBrand)) {
    console.log(`Brand: "${b}" -> ${list.length} offers`);
    for (const o of list.slice(0, 3)) {
      console.log(`   - Offer: ${o.offerId} | Name: ${o.name} | Type: ${o.priceType} | Cost: $${(o.cost?.fixed||0)/100} USD | Send: ${(o.send?.fixed||0)/100} INR`);
    }
  }
}

console.log('\n=== 2. RELOADLY OPERATORS FOR IN ===');
if (raw.reloadly && raw.reloadly.operators) {
  for (const op of raw.reloadly.operators) {
    console.log(`OpID: ${op.operatorId} | Name: "${op.name}" | Denom: ${op.denominationType} | Fixed: ${JSON.stringify(op.fixedAmounts)} | LocalFixed: ${JSON.stringify(op.localFixedAmounts)} | Min/Max: ${op.minAmount}-${op.maxAmount}`);
  }
}

console.log('\n=== 3. DT ONE OPERATORS & PRODUCTS FOR IND ===');
if (raw.dtone) {
  console.log('DT One Operators:');
  for (const op of (raw.dtone.operators || [])) {
    console.log(`  OpID: ${op.id} | Name: "${op.name}"`);
  }
  if (raw.dtone.products) {
    const byOp = {};
    for (const p of raw.dtone.products) {
      const opId = p.operator?.id;
      if (!byOp[opId]) byOp[opId] = [];
      byOp[opId].push(p);
    }
    for (const [opId, prods] of Object.entries(byOp)) {
      console.log(`Operator ${opId} (${prods[0]?.operator?.name}): ${prods.length} products`);
      for (const p of prods.slice(0, 4)) {
        console.log(`   - Prod ${p.id}: "${p.name}" | Dest: ${p.destination?.amount} ${p.destination?.unit} | Wholesale: ${p.prices?.wholesale?.amount} ${p.prices?.wholesale?.unit}`);
      }
    }
  }
}
