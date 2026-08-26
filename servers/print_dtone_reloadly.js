const fs = require('fs');
const path = require('path');

const data = JSON.parse(fs.readFileSync(path.join(__dirname, 'germany_discovery_raw.json'), 'utf8'));

console.log('=== DT ONE OPERATORS ===');
data.dtone.operators.forEach(o => {
  console.log(`Operator ID: ${o.id} | Name: ${o.name}`);
});

console.log('\n=== DT ONE PRODUCTS ===');
data.dtone.products.forEach(p => {
  console.log(`Product ID: ${p.id} | Operator: ${p.operator?.id} (${p.operator?.name}) | Name: ${p.name} | Type: ${p.type} | Dest: ${p.destination?.amount} ${p.destination?.unit} | Wholesale: ${p.prices?.wholesale?.amount} ${p.prices?.wholesale?.unit}`);
});

console.log('\n=== RELOADLY OPERATORS ===');
data.reloadly.operators.forEach(op => {
  console.log(`Op ID: ${op.operatorId} | Name: ${op.name} | Pin: ${op.pin} | Data: ${op.data} | Fixed USD: ${JSON.stringify(op.fixedAmounts)} | Local EUR: ${JSON.stringify(op.localFixedAmounts)}`);
});
