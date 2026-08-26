const fs = require('fs');
const path = require('path');

const raw = JSON.parse(fs.readFileSync(path.join(__dirname, 'srilanka_discovery_raw.json'), 'utf8'));

console.log('=== SRI LANKA PRODUCTS BY OPERATOR ===');

const dtProds = raw.dtone?.products || [];

const ops = {
  360: 'Dialog Sri Lanka',
  409: 'Mobitel Sri Lanka',
  1609: 'Hutchison Sri Lanka'
};

for (const [opId, opName] of Object.entries(ops)) {
  console.log(`\n========================================`);
  console.log(`OPERATOR: ${opName} (DT One ID: ${opId})`);
  console.log(`========================================`);
  const prods = dtProds.filter(p => p.operator?.id == opId);
  prods.sort((a, b) => {
    const valA = a.destination?.amount || 0;
    const valB = b.destination?.amount || 0;
    return valA - valB;
  });
  console.log(`Total Products: ${prods.length}`);
  prods.forEach(p => {
    const price = p.prices?.wholesale || p.source;
    console.log(`[${p.id}] ${p.name} | Type: ${p.type} | Wholesale: ${price?.amount} ${price?.unit} ($${((price?.amount || 0) * 2.60).toFixed(3)} USD) | Dest: ${p.destination?.amount} ${p.destination?.unit}`);
  });
}
