const fs = require('fs');
const path = require('path');

const raw = JSON.parse(fs.readFileSync(path.join(__dirname, 'srilanka_discovery_raw.json'), 'utf8'));

console.log('=====================================================');
console.log('=== SRI LANKA (LK / LKA / +94) PROVIDER ANALYSIS ===');
console.log('=====================================================');

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
  const productsByOp = {};
  raw.dtone.products.forEach(p => {
    const opId = p.operator?.id || 'Unknown';
    if (!productsByOp[opId]) productsByOp[opId] = [];
    productsByOp[opId].push(p);
  });

  for (const [opId, prods] of Object.entries(productsByOp)) {
    const opName = prods[0]?.operator?.name || opId;
    console.log(`\n  Operator ${opId} (${opName}) - ${prods.length} products:`);
    prods.forEach(p => {
      const price = p.prices?.wholesale || p.source;
      console.log(`    [${p.id}] ${p.name} | Type: ${p.type} | Wholesale: ${price?.amount} ${price?.unit} | Dest: ${p.destination?.amount} ${p.destination?.unit}`);
    });
  }
}

// 2. RELOADLY
console.log('\n--- 2. RELOADLY OPERATORS & PRODUCTS ---');
if (raw.reloadly && raw.reloadly.operators) {
  console.log(`Reloadly Operators (${raw.reloadly.operators.length}):`);
  raw.reloadly.operators.forEach(op => {
    console.log(`  Operator ID: ${op.operatorId} | Name: ${op.name} | DenomType: ${op.denominationType} | SenderCurr: ${op.senderCurrencyCode} | DestCurr: ${op.destinationCurrencyCode} | Min: ${op.minAmount} | Max: ${op.maxAmount} | LocalMin: ${op.localMinAmount} | LocalMax: ${op.localMaxAmount} | Fixed: ${JSON.stringify(op.fixedAmounts)} | fxRate: ${op.fx?.rate}`);
    if (op.fixedAmountsDescriptions && Object.keys(op.fixedAmountsDescriptions).length > 0) {
      console.log(`    Descriptions:`, JSON.stringify(op.fixedAmountsDescriptions, null, 2));
    }
  } );
}

// 3. ZENDIT
console.log('\n--- 3. ZENDIT OFFERS ---');
if (raw.zendit && raw.zendit.offers && raw.zendit.offers.list) {
  console.log(`Zendit Offers (${raw.zendit.offers.list.length}):`);
  raw.zendit.offers.list.forEach(o => {
    const costUsd = o.price?.fixed ? (o.price.fixed / (o.price.currencyDivisor || 100)) : 'N/A';
    const sendLkr = o.send?.fixed ? (o.send.fixed / (o.send.currencyDivisor || 100)) : 'N/A';
    console.log(`  OfferId: ${o.offerId} | Brand: ${o.brand} | Name: ${o.name} | PriceType: ${o.priceType} | Wholesale: $${costUsd} USD | Send: ${sendLkr} LKR | SubTypes: ${JSON.stringify(o.subTypes)}`);
  });
}

// 4. DINGCONNECT
console.log('\n--- 4. DINGCONNECT PROVIDERS & PRODUCTS ---');
if (raw.ding && raw.ding.providers && raw.ding.providers.Items) {
  const telecomCodes = ['DGLK', 'MSLK', 'HSLK', 'EB73A6LK'];
  console.log(`Ding Telecom Providers (${raw.ding.providers.Items.length} total in catalog):`);
  raw.ding.providers.Items.forEach(p => {
    console.log(`  ProviderCode: ${p.ProviderCode} | Name: ${p.Name} | Regex: ${p.ValidationRegex} | Care: ${p.CustomerCareNumber}`);
  });
}
if (raw.ding && raw.ding.products && raw.ding.products.Items) {
  console.log(`Ding Products (${raw.ding.products.Items.length}):`);
  raw.ding.products.Items.forEach(p => {
    console.log(`  SkuCode: ${p.SkuCode} | ProviderCode: ${p.ProviderCode} | Name: ${p.LocalizationKey} | Min: ${JSON.stringify(p.Minimum)} | Max: ${JSON.stringify(p.Maximum)} | Validity: ${p.ValidityPeriodIso} | UatNumber: ${p.UatNumber}`);
  });
} else {
  console.log('Ding Products: 0 active in UAT / 503 response');
}
