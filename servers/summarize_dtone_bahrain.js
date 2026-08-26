const fs = require('fs');
const path = require('path');

const data = JSON.parse(fs.readFileSync(path.join(__dirname, 'bahrain_discovery_raw.json'), 'utf8'));

console.log('--- ALL DT ONE OPERATORS IN BHR ---');
console.log(data.dtone.operators);

console.log('\n--- DT ONE PRODUCTS GROUPED BY OPERATOR ---');
const grouped = {};
data.dtone.products.forEach(p => {
  const op = `${p.operator?.id} - ${p.operator?.name}`;
  if (!grouped[op]) grouped[op] = [];
  grouped[op].push(p);
});

for (const [op, prods] of Object.entries(grouped)) {
  console.log(`\n================ Operator: ${op} (${prods.length} products) ================`);
  prods.forEach(p => {
    console.log(`  [#${p.id}] ${p.name} | Type: ${p.type} | Dest: ${p.destination?.amount} ${p.destination?.unit} | Wholesale: ${p.prices?.wholesale?.amount} ${p.prices?.wholesale?.unit} | Retail: ${p.prices?.retail?.amount} ${p.prices?.retail?.unit}`);
  });
}
