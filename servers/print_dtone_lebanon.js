const fs = require('fs');
const path = require('path');

const data = JSON.parse(fs.readFileSync(path.join(__dirname, 'lebanon_catalogs.json'), 'utf8'));

console.log('=== DT ONE PRODUCTS FOR LEBANON ===');
data.dtProducts.forEach(p => {
  console.log({
    id: p.id,
    name: p.name,
    operator: `${p.operator?.id} - ${p.operator?.name}`,
    type: p.type,
    wholesale_price: p.prices?.wholesale,
    destination: p.destination,
    validity: p.validity
  });
});
