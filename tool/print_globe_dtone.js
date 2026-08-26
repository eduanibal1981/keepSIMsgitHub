const fs = require('fs');
const path = require('path');

const dtoneProducts = JSON.parse(fs.readFileSync(path.join(__dirname, 'dtone_ph_products.json'), 'utf8'));
const globeDtone = dtoneProducts.filter(p => p.operator?.id === 246);
console.log('DT One Globe Products:', globeDtone.map(p => ({ id: p.id, name: p.name, dest: p.destination, wholesale: p.prices?.wholesale })));
