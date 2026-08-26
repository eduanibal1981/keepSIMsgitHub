const fs = require('fs');
const path = require('path');

const raw = JSON.parse(fs.readFileSync(path.join(__dirname, 'turkey_discovery_raw.json'), 'utf8'));

const dtProducts = raw.dtone_products || [];

[679, 662, 46, 1931].forEach(targetOpId => {
  const prods = dtProducts.filter(p => p.operator?.id === targetOpId);
  const opName = prods[0]?.operator?.name || `Op ${targetOpId}`;
  console.log(`\n======================================================`);
  console.log(`DT One Op: ${targetOpId} - ${opName} (${prods.length} products)`);
  console.log(`======================================================`);
  prods.sort((a, b) => (parseFloat(a.destination?.amount) || 0) - (parseFloat(b.destination?.amount) || 0));
  prods.forEach(p => {
    console.log(`Product ID: ${p.id} | Name: "${p.name}" | Type: ${p.type} | Dest: ${p.destination?.amount} ${p.destination?.unit} | Wholesale: ${p.prices?.wholesale?.amount} ${p.prices?.wholesale?.unit} | Retail: ${p.prices?.retail?.amount} ${p.prices?.retail?.unit}`);
  });
});
