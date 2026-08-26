const fs = require('fs');
const path = require('path');

const raw = JSON.parse(fs.readFileSync(path.join(__dirname, 'nepal_discovery_raw.json'), 'utf8'));

console.log('==============================================');
console.log('=== NEPAL (NP / NPL / +977) DETAILED ANALYSIS ===');
console.log('==============================================');

// 1. DT ONE
console.log('\n--- 1. DT ONE OPERATORS & PRODUCTS ---');
if (raw.dtone && raw.dtone.operators) {
  console.log(`DT One Operators (${raw.dtone.operators.length}):`);
  raw.dtone.operators.forEach(op => {
    console.log(`  Operator ID: ${op.id} | Name: ${op.name} | Country: ${op.country?.name} (${op.country?.iso_code})`);
  });
}
if (raw.dtone && raw.dtone.products) {
  console.log(`\nDT One Products (${raw.dtone.products.length}):`);
  raw.dtone.products.forEach(p => {
    console.log(`  ID: ${p.id} | Operator: ${p.operator?.id} (${p.operator?.name}) | Name: ${p.name} | Type: ${p.type} | Prices: ${JSON.stringify(p.prices?.wholesale || p.source)} | Dest: ${JSON.stringify(p.destination)}`);
  });
}

// 2. RELOADLY
console.log('\n--- 2. RELOADLY OPERATORS & PRODUCTS ---');
if (raw.reloadly && raw.reloadly.operators) {
  console.log(`Reloadly Operators (${raw.reloadly.operators.length}):`);
  raw.reloadly.operators.forEach(op => {
    console.log(`  Operator ID: ${op.operatorId} | Name: ${op.name} | DenomType: ${op.denominationType} | SenderCurr: ${op.senderCurrencyCode} | DestCurr: ${op.destinationCurrencyCode} | Min: ${op.minAmount} | Max: ${op.maxAmount} | FixedAmounts: ${JSON.stringify(op.fixedAmounts)} | fxRate: ${op.fx?.rate}`);
  });
}

// 3. ZENDIT
console.log('\n--- 3. ZENDIT OFFERS ---');
if (raw.zendit && raw.zendit.offers && raw.zendit.offers.list) {
  console.log(`Zendit Offers (${raw.zendit.offers.list.length}):`);
  raw.zendit.offers.list.forEach(o => {
    console.log(`  OfferId: ${o.offerId} | Brand: ${o.brand} | Name: ${o.name} | PriceType: ${o.priceType} | Price: ${JSON.stringify(o.price)} | Send: ${JSON.stringify(o.send)} | SubTypes: ${JSON.stringify(o.subTypes)}`);
  });
}

// 4. DINGCONNECT
console.log('\n--- 4. DINGCONNECT PROVIDERS & PRODUCTS ---');
if (raw.ding && raw.ding.providers && raw.ding.providers.Items) {
  console.log(`Ding Providers (${raw.ding.providers.Items.length} total):`);
  raw.ding.providers.Items.forEach(p => {
    console.log(`  ProviderCode: ${p.ProviderCode} | Name: ${p.Name} | Regex: ${p.ValidationRegex}`);
  });
}
