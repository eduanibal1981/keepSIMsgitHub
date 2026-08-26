const fs = require('fs');
const path = require('path');

const data = JSON.parse(fs.readFileSync(path.join(__dirname, 'bahrain_discovery_raw.json'), 'utf8'));

console.log('--- SUPABASE COUNTRIES ---');
console.log(data.supabase.countries);

console.log('--- SUPABASE CARRIERS ---');
console.log(data.supabase.carriers);

console.log('--- DT ONE OPERATORS ---');
console.log(data.dtone.operators);

console.log('--- DT ONE PRODUCTS BY OPERATOR ---');
const prodsByOp = {};
if (Array.isArray(data.dtone.products)) {
  data.dtone.products.forEach(p => {
    const opName = p.operator?.name || 'Unknown';
    if (!prodsByOp[opName]) prodsByOp[opName] = [];
    prodsByOp[opName].push(p);
  });
}
for (const [op, prods] of Object.entries(prodsByOp)) {
  console.log(`\nOperator: ${op} (${prods.length} products):`);
  prods.forEach(p => {
    console.log(`  ID: ${p.id} | ${p.name} | Type: ${p.type} | Dest: ${p.destination?.amount} ${p.destination?.unit} | Wholesale: ${p.prices?.wholesale?.amount} ${p.prices?.wholesale?.unit} | Retail: ${p.prices?.retail?.amount} ${p.prices?.retail?.unit}`);
  });
}

console.log('\n--- RELOADLY OPERATORS ---');
console.log(JSON.stringify(data.reloadly.operators, null, 2));

console.log('\n--- ZENDIT OFFERS ---');
console.log(JSON.stringify(data.zendit.offers, null, 2));

console.log('\n--- DINGCONNECT PROVIDERS (ALL) ---');
if (data.ding.providers?.Items) {
  data.ding.providers.Items.forEach(p => {
    console.log(`Code: ${p.ProviderCode} | Name: ${p.Name} | Regex: ${p.ValidationRegex}`);
  });
}
