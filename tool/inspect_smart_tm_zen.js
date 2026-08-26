const fs = require('fs');
const path = require('path');

const dtoneProducts = JSON.parse(fs.readFileSync(path.join(__dirname, 'dtone_ph_products.json'), 'utf8'));
const zenditOffers = JSON.parse(fs.readFileSync(path.join(__dirname, 'zendit_ph_offers.json'), 'utf8'));

console.log('=== DT ONE SMART PHILIPPINES (Operator 570) ===');
const smartDtone = dtoneProducts.filter(p => p.operator?.id === 570);
smartDtone.forEach(p => console.log(`  ID: ${p.id} | Name: ${p.name} | Dest: ${p.destination?.amount} ${p.destination?.unit} | Wholesale: ${p.prices?.wholesale?.amount} ${p.prices?.wholesale?.unit}`));

console.log('\n=== DT ONE TOUCH MOBILE PHILIPPINES (Operator 3128) ===');
const tmDtone = dtoneProducts.filter(p => p.operator?.id === 3128);
tmDtone.forEach(p => console.log(`  ID: ${p.id} | Name: ${p.name} | Dest: ${p.destination?.amount} ${p.destination?.unit} | Wholesale: ${p.prices?.wholesale?.amount} ${p.prices?.wholesale?.unit}`));

console.log('\n=== ZENDIT OFFERS FOR SMART ===');
const smartZen = zenditOffers.filter(o => (o.brand || '').toLowerCase() === 'smart');
smartZen.forEach(o => console.log(`  Offer ID: ${o.offerId} | Name: ${o.name} | Price: ${o.price?.fixed} ${o.price?.currency} | Send: ${o.send?.fixed} ${o.send?.currency}`));

console.log('\n=== ZENDIT OFFERS FOR GLOBE ===');
const globeZen = zenditOffers.filter(o => (o.brand || '').toLowerCase() === 'globe');
globeZen.forEach(o => console.log(`  Offer ID: ${o.offerId} | Name: ${o.name} | Price: ${o.price?.fixed} ${o.price?.currency} | Send: ${o.send?.fixed} ${o.send?.currency}`));
