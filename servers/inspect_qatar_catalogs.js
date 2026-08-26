const fs = require('fs');
const path = require('path');

const raw = JSON.parse(fs.readFileSync(path.join(__dirname, 'qatar_discovery_raw.json'), 'utf8'));

console.log('======================================================');
console.log('=== QATAR TELECOM PROVIDER CATALOG SUMMARY ===');
console.log('======================================================');

// 1. DT ONE
console.log('\n--- 1. DT ONE OPERATORS & PRODUCTS ---');
console.log('Operators:', raw.dtone.operators);
if (raw.dtone.products) {
  console.log(`Total Products: ${raw.dtone.products.length}`);
  const byOp = {};
  raw.dtone.products.forEach(p => {
    const opName = p.operator?.name || 'Unknown';
    if (!byOp[opName]) byOp[opName] = [];
    byOp[opName].push({
      id: p.id,
      name: p.name,
      type: p.type,
      service: p.service?.name,
      subservice: p.service?.subservice?.name,
      destAmount: p.destination?.amount,
      destUnit: p.destination?.unit,
      wholesale: p.prices?.wholesale?.amount,
      retail: p.prices?.retail?.amount,
      currency: p.prices?.wholesale?.unit,
      pinUsage: p.pin?.usage_info
    });
  });
  for (const [op, prods] of Object.entries(byOp)) {
    console.log(`\nOperator: ${op} (${prods.length} products):`);
    prods.sort((a, b) => (a.destAmount || 0) - (b.destAmount || 0));
    prods.forEach(p => {
      console.log(`  - ID: ${p.id} | Name: ${p.name} | Type: ${p.type} | Subservice: ${p.subservice} | Dest: ${p.destAmount} ${p.destUnit} | Wholesale: ${p.wholesale} ${p.currency} (Retail: ${p.retail})`);
    });
  }
}

// 2. RELOADLY
console.log('\n--- 2. RELOADLY OPERATORS & DENOMINATIONS ---');
if (raw.reloadly.operators) {
  console.log('Operators count:', raw.reloadly.operators.length);
  raw.reloadly.operators.forEach(op => {
    console.log(`\nOperator ID: ${op.operatorId} | Name: ${op.name} | Bundle: ${op.bundle} | Data: ${op.data} | Pin: ${op.pin} | SupportsLocal: ${op.supportsLocalAmounts} | FX: ${op.fx?.rate} ${op.fx?.currencyCode}`);
    console.log(`  Denomination Type: ${op.denominationType}`);
    console.log(`  Fixed Amounts:`, op.fixedAmounts);
    console.log(`  Fixed Amounts Descriptions:`, op.fixedAmountsDescriptions);
    console.log(`  Local Fixed Amounts:`, op.localFixedAmounts);
    console.log(`  Min/Max: ${op.minAmount} - ${op.maxAmount} (Local: ${op.localMinAmount} - ${op.localMaxAmount})`);
    console.log(`  Sender Currencies:`, op.senderCurrencyCode, 'Destination:', op.destinationCurrencyCode);
    console.log(`  Geographical Reload:`, op.geographicalReloadPlans);
  });
}

// 3. ZENDIT
console.log('\n--- 3. ZENDIT OFFERS ---');
if (raw.zendit.offers && raw.zendit.offers.list) {
  console.log(`Total Offers: ${raw.zendit.offers.list.length}`);
  const byBrand = {};
  raw.zendit.offers.list.forEach(o => {
    const b = o.brand || 'Unknown';
    if (!byBrand[b]) byBrand[b] = [];
    byBrand[b].push(o);
  });
  for (const [brand, offers] of Object.entries(byBrand)) {
    console.log(`\nBrand: ${brand} (${offers.length} offers):`);
    offers.forEach(o => {
      console.log(`  - OfferId: ${o.offerId} | Name: ${o.name} | PriceType: ${o.priceType} | Price: ${JSON.stringify(o.price)} | Send: ${JSON.stringify(o.send)} | SubTypes: ${JSON.stringify(o.subTypes)}`);
    });
  }
}

// 4. DINGCONNECT
console.log('\n--- 4. DINGCONNECT PROVIDERS & PRODUCTS ---');
if (raw.ding.providers) {
  console.log('Ding Providers in QA:', raw.ding.providers.Items?.map(p => `${p.ProviderCode}: ${p.Name}`));
}
if (raw.ding.products && raw.ding.products.Items) {
  console.log('Ding Products in QA:', raw.ding.products.Items.length);
}
