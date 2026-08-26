const fs = require('fs');
const path = require('path');

const raw = JSON.parse(fs.readFileSync(path.join(__dirname, 'bangladesh_discovery_raw.json'), 'utf8'));

console.log('=== 1. DT ONE OPERATORS ===');
console.log(JSON.stringify(raw.dtone.operators, null, 2));

console.log('=== 1. DT ONE PRODUCTS ===');
console.log(JSON.stringify(raw.dtone.products, null, 2));

console.log('=== 2. RELOADLY OPERATORS ===');
console.log(JSON.stringify(raw.reloadly.operators, null, 2));

console.log('=== 3. ZENDIT OFFERS ===');
console.log(JSON.stringify(raw.zendit.offers, null, 2));
