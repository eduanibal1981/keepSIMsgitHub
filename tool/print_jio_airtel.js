const fs = require('fs');
const path = require('path');

const rawPath = path.join(__dirname, 'in_analysis_raw.json');
const raw = JSON.parse(fs.readFileSync(rawPath, 'utf8'));

// Jio DT One
console.log('=== JIO DT ONE PRODUCTS ===');
const jioDt = (raw.dtone.products || []).filter(p => p.operator?.id === 2808);
jioDt.sort((a, b) => (a.destination?.amount || 0) - (b.destination?.amount || 0));
for (const p of jioDt) {
  console.log(`- [${p.id}] ${p.name} | Dest: ${p.destination?.amount} INR | Wholesale: ${p.prices?.wholesale?.amount} OMR (~$${((p.prices?.wholesale?.amount || 0) * 2.6).toFixed(2)} USD) | Validity: ${p.validity ? p.validity.quantity + ' ' + p.validity.unit : 'None'}`);
}

console.log('\n=== AIRTEL DT ONE PRODUCTS ===');
const airtelDt = (raw.dtone.products || []).filter(p => p.operator?.id === 1371);
airtelDt.sort((a, b) => (a.destination?.amount || 0) - (b.destination?.amount || 0));
for (const p of airtelDt) {
  console.log(`- [${p.id}] ${p.name} | Dest: ${p.destination?.amount} INR | Wholesale: ${p.prices?.wholesale?.amount} OMR (~$${((p.prices?.wholesale?.amount || 0) * 2.6).toFixed(2)} USD) | Validity: ${p.validity ? p.validity.quantity + ' ' + p.validity.unit : 'None'}`);
}

console.log('\n=== JIO ZENDIT OFFERS ===');
const jioZen = (raw.zendit.offers || []).filter(o => o.brand === 'Jio');
jioZen.sort((a, b) => (a.send?.fixed || 0) - (b.send?.fixed || 0));
for (const o of jioZen) {
  console.log(`- [${o.offerId}] ${o.name || o.shortNotes || 'Bundle'} | Send: ${(o.send?.fixed||0)/100} INR | Cost: $${(o.cost?.fixed||0)/100} USD | Price: $${(o.price?.fixed||0)/100} USD`);
}

console.log('\n=== AIRTEL ZENDIT OFFERS ===');
const airtelZen = (raw.zendit.offers || []).filter(o => o.brand === 'Airtel');
airtelZen.sort((a, b) => (a.send?.fixed || 0) - (b.send?.fixed || 0));
for (const o of airtelZen) {
  console.log(`- [${o.offerId}] ${o.name || o.shortNotes || 'Bundle'} | Send: ${(o.send?.fixed||0)/100} INR | Cost: $${(o.cost?.fixed||0)/100} USD | Price: $${(o.price?.fixed||0)/100} USD`);
}
