const fs = require('fs');
const path = require('path');

const data = JSON.parse(fs.readFileSync(path.join(__dirname, 'morocco_discovery_raw.json'), 'utf8'));

console.log('=== DT ONE OPERATORS ===');
console.log(JSON.stringify(data.dtone.operators, null, 2));

console.log('\n=== DT ONE PRODUCTS ===');
if (data.dtone.products) {
  data.dtone.products.forEach(p => {
    console.log(`ID: ${p.id} | Name: ${p.name} | Operator: [${p.operator?.id}] ${p.operator?.name} | Type: ${p.type} | Service: ${p.service?.name} | Src: ${p.source?.amount} ${p.source?.unit} | Dest: ${p.destination?.amount} ${p.destination?.unit} | Wholesale: ${p.prices?.wholesale?.amount} ${p.prices?.wholesale?.unit}`);
  });
}
