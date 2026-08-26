const fs = require('fs');
const path = require('path');

const data = JSON.parse(fs.readFileSync(path.join(__dirname, 'morocco_discovery_raw.json'), 'utf8'));

console.log('=== 1. DT ONE MOROCCO ===');
console.log('Operators:', data.dtone.operators);
console.log('Products Count:', data.dtone.products ? data.dtone.products.length : 0);
if (data.dtone.products) {
  const byOp = {};
  data.dtone.products.forEach(p => {
    const opName = p.operator ? `${p.operator.id} - ${p.operator.name}` : 'Unknown';
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

console.log('\n=== 2. RELOADLY MOROCCO ===');
console.log('Operators Count:', data.reloadly.operators ? data.reloadly.operators.length : 0);
if (data.reloadly.operators) {
  data.reloadly.operators.forEach(op => {
    console.log(`\nOperator ID: ${op.operatorId} | Name: ${op.name} | DenomType: ${op.denominationType} | SenderCurr: ${op.senderCurrencyCode} | DestCurr: ${op.destinationCurrencyCode}`);
    console.log(`  Fixed Amounts: ${JSON.stringify(op.fixedAmounts)}`);
    console.log(`  Min/Max: ${op.minAmount} - ${op.maxAmount}`);
    console.log(`  Fixed Amounts Descriptions:`, JSON.stringify(op.fixedAmountsDescriptions));
    console.log(`  Local Fixed Amounts:`, JSON.stringify(op.localFixedAmounts));
    console.log(`  Local Min/Max: ${op.localMinAmount} - ${op.localMaxAmount}`);
    console.log(`  Suggested Amounts:`, JSON.stringify(op.suggestedAmounts));
    console.log(`  FX: Rate=${op.fx?.rate}, Currency=${op.fx?.currencyCode}`);
    console.log(`  Geographical Reload: ${op.geographicalReload}`);
  });
}

console.log('\n=== 3. ZENDIT MOROCCO ===');
console.log('Offers Count:', data.zendit.offers?.list ? data.zendit.offers.list.length : 0);
if (data.zendit.offers?.list) {
  const byBrand = {};
  data.zendit.offers.list.forEach(o => {
    if (!byBrand[o.brand]) byBrand[o.brand] = [];
    byBrand[o.brand].push(o);
  });
  for (const [brand, offers] of Object.entries(byBrand)) {
    console.log(`\nBrand: ${brand} (${offers.length} offers)`);
    offers.forEach(o => {
      console.log(`  OfferID: ${o.offerId} | Name: ${o.name} | PriceType: ${o.priceType} | Price: ${JSON.stringify(o.price)} | Send: ${JSON.stringify(o.send)} | SubTypes: ${JSON.stringify(o.subTypes)}`);
    });
  }
}

console.log('\n=== 4. DINGCONNECT MOROCCO ===');
console.log('Providers Count:', data.ding.providers?.Items ? data.ding.providers.Items.length : 0);
if (data.ding.providers?.Items) {
  data.ding.providers.Items.forEach(p => {
    console.log(`  Code: ${p.ProviderCode} | Name: ${p.Name} | Regex: ${p.ValidationRegex}`);
  });
}
