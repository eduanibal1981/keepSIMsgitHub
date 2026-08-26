const fs = require('fs');
const path = require('path');

const raw = JSON.parse(fs.readFileSync(path.join(__dirname, 'srilanka_discovery_raw.json'), 'utf8'));

const dtProds = raw.dtone?.products || [];

['360', '409'].forEach(opId => {
  const prods = dtProds.filter(p => p.operator?.id == opId);
  prods.sort((a, b) => (a.destination?.amount || 0) - (b.destination?.amount || 0));
  console.log(`\n========================================`);
  console.log(`OPERATOR ID: ${opId} (${prods[0]?.operator?.name}) - Total: ${prods.length}`);
  console.log(`========================================`);
  prods.forEach(p => {
    const price = p.prices?.wholesale || p.source;
    console.log(`[${p.id}] ${p.name} | Type: ${p.type} | Wholesale: ${price?.amount} ${price?.unit} ($${((price?.amount || 0) * 2.60).toFixed(3)} USD) | Dest: ${p.destination?.amount} ${p.destination?.unit}`);
  });
});
