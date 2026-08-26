const fs = require('fs');
const path = require('path');

const rawPath = path.join(__dirname, 'in_analysis_raw.json');
const raw = JSON.parse(fs.readFileSync(rawPath, 'utf8'));

// Carriers
const carriers = [
  { key: 'JIO', name: 'Reliance Jio', dtOpId: 2808, zenBrand: 'Jio', rlOpId: 786, dingCode: 'RJIN' },
  { key: 'AIRTEL', name: 'Bharti Airtel', dtOpId: 1371, zenBrand: 'Airtel', rlOpId: 200, dingCode: 'AIIN' },
  { key: 'VI', name: 'Vodafone Idea (Vi)', dtOpId: 2016, zenBrand: 'VodafoneIdea', rlOpId: 716, dingCode: 'VFIN' },
  { key: 'BSNL', name: 'BSNL', dtOpId: 1420, zenBrand: 'BSNL', rlOpId: 193, dingCode: 'BLIN' },
  { key: 'MTNL', name: 'MTNL (Delhi/Mumbai)', dtOpId: 368, zenBrand: 'MTNL', rlOpId: 194, dingCode: 'MNIN' },
];

for (const c of carriers) {
  console.log(`\n======================================================`);
  console.log(`CARRIER: ${c.name}`);
  console.log(`======================================================`);

  // DT One products
  const dtProds = (raw.dtone.products || []).filter(p => p.operator?.id === c.dtOpId);
  console.log(`DT One Products (${dtProds.length}):`);
  dtProds.sort((a, b) => (a.destination?.amount || 0) - (b.destination?.amount || 0));
  for (const p of dtProds) {
    console.log(`  - [ID ${p.id}] ${p.name} | Dest: ${p.destination?.amount} INR | Wholesale: ${p.prices?.wholesale?.amount} OMR (~$${((p.prices?.wholesale?.amount || 0) * 2.6).toFixed(2)} USD) | Validity: ${p.validity ? p.validity.quantity + ' ' + p.validity.unit : 'None'}`);
  }

  // Zendit offers
  const zenOffers = (raw.zendit.offers || []).filter(o => o.brand === c.zenBrand);
  console.log(`\nZendit Offers (${zenOffers.length}):`);
  zenOffers.sort((a, b) => (a.send?.fixed || 0) - (b.send?.fixed || 0));
  for (const o of zenOffers) {
    console.log(`  - [${o.offerId}] ${o.name || o.shortNotes || 'Bundle'} | Send: ${(o.send?.fixed||0)/100} INR | Cost: $${(o.cost?.fixed||0)/100} USD | Price: $${(o.price?.fixed||0)/100} USD`);
  }
}
