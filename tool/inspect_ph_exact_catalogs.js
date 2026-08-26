const fs = require('fs');
const path = require('path');

// Load saved files
const dtoneProducts = JSON.parse(fs.readFileSync(path.join(__dirname, 'dtone_ph_products.json'), 'utf8'));
const reloadlyOperators = JSON.parse(fs.readFileSync(path.join(__dirname, 'reloadly_ph_operators.json'), 'utf8'));
const zenditOffers = JSON.parse(fs.readFileSync(path.join(__dirname, 'zendit_ph_offers.json'), 'utf8'));

console.log('========================================================================');
console.log('EXACT CATALOG INSPECTION FOR PHILIPPINES OPERATORS');
console.log('========================================================================\n');

// 1. GLOBE TELECOM
console.log('========================================');
console.log('1. GLOBE TELECOM (Globe)');
console.log('========================================');
console.log('--- DT ONE (Operator 246) ---');
const dtGlobe = dtoneProducts.filter(p => p.operator?.id === 246);
console.log(`DT One Globe Products (${dtGlobe.length}):`);
dtGlobe.forEach(p => {
  console.log(`  ID: ${p.id} | Name: ${p.name} | Type: ${p.type} | Service: ${p.service?.name} | Prices: ${JSON.stringify(p.prices)} | Dest: ${JSON.stringify(p.destination)}`);
});

console.log('\n--- RELOADLY (Operators 371, 374, 937) ---');
const rlGlobe = reloadlyOperators.filter(o => [371, 374, 937].includes(o.operatorId));
rlGlobe.forEach(o => {
  console.log(`  Op ID: ${o.operatorId} | Name: ${o.name} | Denom: ${o.denominationType} | Min: ${o.minAmount}, Max: ${o.maxAmount} | Fixed: ${JSON.stringify(o.fixedAmounts)} | LocalFixed: ${JSON.stringify(o.localFixedAmounts)} | Fx: ${JSON.stringify(o.fx)}`);
});

console.log('\n--- ZENDIT (Brand Globe) ---');
const zenGlobe = zenditOffers.filter(o => (o.brand || '').toLowerCase() === 'globe');
zenGlobe.forEach(o => {
  console.log(`  Offer ID: ${o.offerId} | Name: ${o.name} | Cost: ${JSON.stringify(o.cost)} | Price: ${JSON.stringify(o.price)} | Send: ${JSON.stringify(o.send)}`);
});

// 2. SMART COMMUNICATIONS
console.log('\n========================================');
console.log('2. SMART COMMUNICATIONS (Smart / SmartBro / Sun)');
console.log('========================================');
console.log('--- DT ONE (Operators 570, 1934, 2952) ---');
const dtSmart = dtoneProducts.filter(p => [570, 1934, 2952].includes(p.operator?.id));
console.log(`DT One Smart Products (${dtSmart.length}):`);
dtSmart.forEach(p => {
  console.log(`  Op: ${p.operator?.id} (${p.operator?.name}) | ID: ${p.id} | Name: ${p.name} | Type: ${p.type} | Prices: ${JSON.stringify(p.prices)} | Dest: ${JSON.stringify(p.destination)}`);
});

console.log('\n--- RELOADLY (Operators 372, 720, 789, 1207, 376, 976, 1209, 369, 942) ---');
const rlSmart = reloadlyOperators.filter(o => [372, 720, 789, 1207, 376, 976, 1209, 369, 942].includes(o.operatorId));
rlSmart.forEach(o => {
  console.log(`  Op ID: ${o.operatorId} | Name: ${o.name} | Denom: ${o.denominationType} | Min: ${o.minAmount}, Max: ${o.maxAmount} | Fixed: ${JSON.stringify(o.fixedAmounts)} | Fx: ${JSON.stringify(o.fx)}`);
});

console.log('\n--- ZENDIT (Brand Smart) ---');
const zenSmart = zenditOffers.filter(o => (o.brand || '').toLowerCase() === 'smart');
zenSmart.forEach(o => {
  console.log(`  Offer ID: ${o.offerId} | Name: ${o.name} | Cost: ${JSON.stringify(o.cost)} | Price: ${JSON.stringify(o.price)} | Send: ${JSON.stringify(o.send)}`);
});

// 3. DITO TELECOMMUNITY
console.log('\n========================================');
console.log('3. DITO TELECOMMUNITY (DITO)');
console.log('========================================');
console.log('--- DT ONE ---');
const dtDito = dtoneProducts.filter(p => (p.operator?.name || '').toLowerCase().includes('dito') || (p.name || '').toLowerCase().includes('dito'));
console.log(`DT One DITO Products (${dtDito.length}):`);
dtDito.forEach(p => {
  console.log(`  Op: ${p.operator?.id} (${p.operator?.name}) | ID: ${p.id} | Name: ${p.name} | Prices: ${JSON.stringify(p.prices)} | Dest: ${JSON.stringify(p.destination)}`);
});

console.log('\n--- RELOADLY (Operators 1182, 1183) ---');
const rlDito = reloadlyOperators.filter(o => [1182, 1183].includes(o.operatorId));
rlDito.forEach(o => {
  console.log(`  Op ID: ${o.operatorId} | Name: ${o.name} | Denom: ${o.denominationType} | Min: ${o.minAmount}, Max: ${o.maxAmount} | Fixed: ${JSON.stringify(o.fixedAmounts)} | LocalFixed: ${JSON.stringify(o.localFixedAmounts)} | Fx: ${JSON.stringify(o.fx)}`);
});

console.log('\n--- ZENDIT (Brand Dito) ---');
const zenDito = zenditOffers.filter(o => (o.brand || '').toLowerCase() === 'dito');
zenDito.forEach(o => {
  console.log(`  Offer ID: ${o.offerId} | Name: ${o.name} | Cost: ${JSON.stringify(o.cost)} | Price: ${JSON.stringify(o.price)} | Send: ${JSON.stringify(o.send)}`);
});

// 4. TM (TOUCH MOBILE)
console.log('\n========================================');
console.log('4. TM (TOUCH MOBILE / Touch Mobile)');
console.log('========================================');
console.log('--- DT ONE (Operator 3128) ---');
const dtTM = dtoneProducts.filter(p => p.operator?.id === 3128);
console.log(`DT One TM Products (${dtTM.length}):`);
dtTM.forEach(p => {
  console.log(`  ID: ${p.id} | Name: ${p.name} | Type: ${p.type} | Prices: ${JSON.stringify(p.prices)} | Dest: ${JSON.stringify(p.destination)}`);
});

console.log('\n--- RELOADLY (Operators 723, 939, 938) ---');
const rlTM = reloadlyOperators.filter(o => [723, 939, 938].includes(o.operatorId));
rlTM.forEach(o => {
  console.log(`  Op ID: ${o.operatorId} | Name: ${o.name} | Denom: ${o.denominationType} | Min: ${o.minAmount}, Max: ${o.maxAmount} | Fixed: ${JSON.stringify(o.fixedAmounts)} | LocalFixed: ${JSON.stringify(o.localFixedAmounts)} | Fx: ${JSON.stringify(o.fx)}`);
});

console.log('\n--- ZENDIT (Brand TouchMobile) ---');
const zenTM = zenditOffers.filter(o => (o.brand || '').toLowerCase() === 'touchmobile');
zenTM.forEach(o => {
  console.log(`  Offer ID: ${o.offerId} | Name: ${o.name} | Cost: ${JSON.stringify(o.cost)} | Price: ${JSON.stringify(o.price)} | Send: ${JSON.stringify(o.send)}`);
});

// 5. TNT (TALK 'N TEXT)
console.log('\n========================================');
console.log('5. TNT (TALK \'N TEXT / TNT)');
console.log('========================================');
console.log('--- DT ONE (Operator 2897) ---');
const dtTNT = dtoneProducts.filter(p => p.operator?.id === 2897);
console.log(`DT One TNT Products (${dtTNT.length}):`);
dtTNT.forEach(p => {
  console.log(`  ID: ${p.id} | Name: ${p.name} | Type: ${p.type} | Prices: ${JSON.stringify(p.prices)} | Dest: ${JSON.stringify(p.destination)}`);
});

console.log('\n--- RELOADLY (Operators 378, 722, 941, 1208) ---');
const rlTNT = reloadlyOperators.filter(o => [378, 722, 941, 1208].includes(o.operatorId));
rlTNT.forEach(o => {
  console.log(`  Op ID: ${o.operatorId} | Name: ${o.name} | Denom: ${o.denominationType} | Min: ${o.minAmount}, Max: ${o.maxAmount} | Fixed: ${JSON.stringify(o.fixedAmounts)} | LocalFixed: ${JSON.stringify(o.localFixedAmounts)} | Fx: ${JSON.stringify(o.fx)}`);
});

console.log('\n--- ZENDIT (Brand TNT) ---');
const zenTNT = zenditOffers.filter(o => (o.brand || '').toLowerCase() === 'tnt');
zenTNT.forEach(o => {
  console.log(`  Offer ID: ${o.offerId} | Name: ${o.name} | Cost: ${JSON.stringify(o.cost)} | Price: ${JSON.stringify(o.price)} | Send: ${JSON.stringify(o.send)}`);
});
