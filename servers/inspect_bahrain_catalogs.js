const fs = require('fs');
const path = require('path');

const data = JSON.parse(fs.readFileSync(path.join(__dirname, 'bahrain_discovery_raw.json'), 'utf8'));

console.log('==============================================');
console.log('=== DT ONE OPERATORS IN BAHRAIN (BHR) ===');
console.log('==============================================');
console.log(JSON.stringify(data.dtone.operators, null, 2));

console.log('\n==============================================');
console.log('=== DT ONE ALL PRODUCTS IN BAHRAIN (BHR) ===');
console.log('==============================================');
if (Array.isArray(data.dtone.products)) {
  data.dtone.products.forEach(p => {
    console.log(`Product ID: ${p.id}`);
    console.log(`  Name: ${p.name}`);
    console.log(`  Operator: ID ${p.operator?.id} - "${p.operator?.name}"`);
    console.log(`  Type: ${p.type} | SubType: ${p.sub_type}`);
    console.log(`  Service: ID ${p.service?.id} - "${p.service?.name}"`);
    console.log(`  Destination: ${p.destination?.amount} ${p.destination?.unit}`);
    console.log(`  Wholesale: ${p.prices?.wholesale?.amount} ${p.prices?.wholesale?.unit}`);
    console.log(`  Retail: ${p.prices?.retail?.amount} ${p.prices?.retail?.unit}`);
    console.log(`  Source: ${p.source?.amount} ${p.source?.unit}`);
    console.log(`  Validity: ${p.validity ? JSON.stringify(p.validity) : 'N/A'}`);
    console.log('--------------------------------------------------');
  });
}

console.log('\n==============================================');
console.log('=== RELOADLY OPERATORS IN BAHRAIN (BH) ===');
console.log('==============================================');
console.log(JSON.stringify(data.reloadly.operators, null, 2));
