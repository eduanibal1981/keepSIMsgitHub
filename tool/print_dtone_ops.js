const fs = require('fs');
const path = require('path');

const dtoneProducts = JSON.parse(fs.readFileSync(path.join(__dirname, 'dtone_ph_products.json'), 'utf8'));
const ops = {};
dtoneProducts.forEach(p => {
  const op = p.operator;
  if (op) {
    ops[op.id] = { id: op.id, name: op.name, count: (ops[op.id]?.count || 0) + 1 };
  }
});
console.log('DT One Operators with products in PHL:', Object.values(ops));
