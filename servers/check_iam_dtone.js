const fs = require('fs');
const path = require('path');

const prods = JSON.parse(fs.readFileSync(path.join(__dirname, 'dtone_mar_products.json'), 'utf8'));

const iamProds = prods.filter(p => p.operator?.id === 1533 || p.operator?.name?.toLowerCase().includes('maroc telecom'));
console.log(`Maroc Telecom products in DT One (${iamProds.length}):`);
iamProds.forEach(p => {
  console.log(`ID: ${p.id} | Name: ${p.name} | Type: ${p.type} | Dest: ${JSON.stringify(p.destination)} | Src: ${JSON.stringify(p.source)} | Wholesale: ${JSON.stringify(p.prices?.wholesale)}`);
});
