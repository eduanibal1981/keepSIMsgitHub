const fs = require('fs');
const path = require('path');

const data = JSON.parse(fs.readFileSync(path.join(__dirname, 'kuwait_discovery_raw.json'), 'utf8'));

console.log('==============================================');
console.log('=== KUWAIT DISCOVERY SUMMARY ===');
console.log('==============================================');

console.log('\n--- 1. DT ONE (KWT) ---');
console.log('Operators:', data.dtone.operators);
console.log(`Total Products: ${data.dtone.products ? data.dtone.products.length : 0}`);
if (data.dtone.products) {
  data.dtone.products.forEach(p => {
    console.log(`ID: ${p.id} | Name: ${p.name} | Operator: ${p.operator?.id} (${p.operator?.name}) | Type: ${p.type} | Service: ${p.service?.name} | Source: ${JSON.stringify(p.source)} | Prices: ${JSON.stringify(p.prices?.wholesale)} | Dest: ${JSON.stringify(p.destination)}`);
  });
}

console.log('\n--- 2. RELOADLY (KW) ---');
console.log('Operators:', JSON.stringify(data.reloadly.operators, null, 2));

console.log('\n--- 3. ZENDIT (KW) ---');
console.log(`Total Offers: ${data.zendit.offers?.total || data.zendit.offers?.list?.length || 0}`);
if (data.zendit.offers?.list) {
  data.zendit.offers.list.forEach(o => {
    console.log(`OfferId: ${o.offerId} | Brand: ${o.brand} | Name: ${o.name} | Type: ${o.priceType} | Price: ${JSON.stringify(o.price)} | Send: ${JSON.stringify(o.send)} | SubTypes: ${JSON.stringify(o.subTypes)}`);
  });
}

console.log('\n--- 4. DINGCONNECT (KW) ---');
console.log('Providers:', data.ding.providers);
console.log('Products Status/Count:', data.ding.products);
