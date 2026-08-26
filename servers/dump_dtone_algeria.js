const fs = require('fs');
const path = require('path');

const data = JSON.parse(fs.readFileSync(path.join(__dirname, 'algeria_detailed_raw.json'), 'utf8'));

console.log('DT One Operators:', data.dtone.operators);
console.log('DT One Products Count:', data.dtone.products?.length);
if (data.dtone.products) {
  data.dtone.products.forEach(p => {
    console.log(`ID: ${p.id} | Name: ${p.name} | Operator: [${p.operator?.id}] ${p.operator?.name} | Type: ${p.type} | Service: ${p.service?.name} | SubType: ${p.sub_type} | Source: ${p.source?.amount} ${p.source?.unit} | Dest: ${p.destination?.amount} ${p.destination?.unit} | Wholesale: ${p.prices?.wholesale?.amount} ${p.prices?.wholesale?.unit}`);
  });
}
