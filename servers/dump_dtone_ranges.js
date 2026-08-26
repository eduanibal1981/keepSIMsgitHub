const fs = require('fs');
const path = require('path');

const raw = JSON.parse(fs.readFileSync(path.join(__dirname, 'srilanka_discovery_raw.json'), 'utf8'));

const dtProds = raw.dtone?.products || [];

const ranges = dtProds.filter(p => p.type === 'RANGED_VALUE_RECHARGE');
console.log(`RANGED PRODUCTS IN DT ONE (${ranges.length}):`);
ranges.forEach(p => {
  console.log(JSON.stringify(p, null, 2));
});
