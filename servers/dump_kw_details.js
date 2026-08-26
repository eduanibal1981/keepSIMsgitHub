const fs = require('fs');
const path = require('path');

const data = JSON.parse(fs.readFileSync(path.join(__dirname, 'kuwait_discovery_raw.json'), 'utf8'));

console.log('=== DT ONE OPERATORS & PRODUCTS ===');
console.log('Operators:', JSON.stringify(data.dtone.operators, null, 2));
console.log('Products Count:', data.dtone.products?.length);
if (data.dtone.products) {
  data.dtone.products.forEach(p => {
    console.log(`[DT One] ID: ${p.id} | Name: ${p.name} | Operator: ${p.operator?.id} (${p.operator?.name}) | Type: ${p.type} | Service: ${p.service?.name} | Source: ${JSON.stringify(p.source)} | Prices: ${JSON.stringify(p.prices?.wholesale)} | Dest: ${JSON.stringify(p.destination)}`);
  });
}

console.log('\n=== RELOADLY OPERATORS ===');
console.log(JSON.stringify(data.reloadly.operators, null, 2));

console.log('\n=== ZENDIT OFFERS ===');
console.log(JSON.stringify(data.zendit.offers, null, 2));
