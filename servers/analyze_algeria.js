const fs = require('fs');
const path = require('path');

const raw = JSON.parse(fs.readFileSync(path.join(__dirname, 'algeria_discovery_raw.json'), 'utf8'));

console.log('====================================================');
console.log('=== ALGERIA DISCOVERY ANALYSIS & CARRIER BREAKDOWN ===');
console.log('====================================================');

// 1. DT One
console.log('\n--- 1. DT ONE OPERATORS & PRODUCTS ---');
console.log('Operators:', raw.dtone.operators);
if (raw.dtone.products) {
  console.log(`Total Products: ${raw.dtone.products.length}`);
  const byOp = {};
  raw.dtone.products.forEach(p => {
    const opName = p.operator?.name || 'Unknown';
    if (!byOp[opName]) byOp[opName] = [];
    byOp[opName].push(p);
  });
  for (const [op, prods] of Object.entries(byOp)) {
    console.log(`\nOperator: ${op} (${prods.length} products)`);
    prods.forEach(p => {
      console.log(`  ID: ${p.id} | Name: ${p.name} | Type: ${p.type} | Service: ${p.service?.name} | Source: ${JSON.stringify(p.source)} | Dest: ${JSON.stringify(p.destination)} | Wholesale: ${JSON.stringify(p.prices?.wholesale)}`);
    });
  }
}

// 2. Reloadly
console.log('\n--- 2. RELOADLY OPERATORS ---');
if (raw.reloadly.operators) {
  console.log('Reloadly Operators Count:', Array.isArray(raw.reloadly.operators) ? raw.reloadly.operators.length : 'N/A');
  if (Array.isArray(raw.reloadly.operators)) {
    raw.reloadly.operators.forEach(op => {
      console.log(`\nOp ID: ${op.operatorId} | Name: ${op.name} | Bundle: ${op.bundle} | Data: ${op.data} | Pin: ${op.pin} | DenominationType: ${op.denominationType}`);
      console.log(`  Fx: ${JSON.stringify(op.fx)}`);
      console.log(`  FixedAmounts: ${JSON.stringify(op.fixedAmounts)}`);
      console.log(`  FixedAmountsDescriptions: ${JSON.stringify(op.fixedAmountsDescriptions)}`);
      console.log(`  LocalFixedAmounts: ${JSON.stringify(op.localFixedAmounts)}`);
      console.log(`  LocalMin/Max: ${op.localMinAmount} - ${op.localMaxAmount} ${op.destinationCurrencyCode}`);
      console.log(`  Min/Max: ${op.minAmount} - ${op.maxAmount} ${op.senderCurrencyCode}`);
    });
  } else {
    console.log(raw.reloadly.operators);
  }
}

// 3. Zendit
console.log('\n--- 3. ZENDIT OFFERS ---');
if (raw.zendit.offers) {
  console.log(`Total Offers: ${raw.zendit.offers.total || (raw.zendit.offers.list ? raw.zendit.offers.list.length : 0)}`);
  if (raw.zendit.offers.list && raw.zendit.offers.list.length > 0) {
    raw.zendit.offers.list.forEach(o => {
      console.log(`Offer ID: ${o.offerId} | Brand: ${o.brand} | Name: ${o.name} | Type: ${o.priceType} | Price: ${JSON.stringify(o.price)} | Send: ${JSON.stringify(o.send)} | SubTypes: ${JSON.stringify(o.subTypes)}`);
    });
  } else {
    console.log(raw.zendit.offers);
  }
}

// 4. Ding
console.log('\n--- 4. DING PROVIDERS ---');
if (raw.ding.providers) {
  console.log(`Total Providers: ${raw.ding.providers.Items ? raw.ding.providers.Items.length : 0}`);
  if (raw.ding.providers.Items) {
    raw.ding.providers.Items.forEach(p => {
      console.log(`ProviderCode: ${p.ProviderCode} | Name: ${p.Name} | Regex: ${p.ValidationRegex} | Care: ${p.CustomerCareNumber}`);
    });
  }
}
