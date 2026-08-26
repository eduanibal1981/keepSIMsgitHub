const fs = require('fs');
const path = require('path');

const dtone = JSON.parse(fs.readFileSync(path.join(__dirname, 'dtone_ph_products.json'), 'utf8'));
const reloadly = JSON.parse(fs.readFileSync(path.join(__dirname, 'reloadly_ph_operators.json'), 'utf8'));
const zendit = JSON.parse(fs.readFileSync(path.join(__dirname, 'zendit_ph_offers.json'), 'utf8'));

function formatPHPTable(carrierName, dtOpIds, rlOpIds, zenBrand) {
  const dtProds = dtone.filter(p => dtOpIds.includes(p.operator?.id));
  const rlOps = reloadly.filter(o => rlOpIds.includes(o.operatorId));
  const zenOffs = zendit.filter(o => (o.brand || '').toLowerCase() === zenBrand.toLowerCase());

  console.log(`\n================== ${carrierName} ==================`);
  console.log(`DT One Products (${dtProds.length}):`);
  dtProds.sort((a,b) => (a.destination?.amount || 0) - (b.destination?.amount || 0)).forEach(p => {
    const wholesaleUsd = (p.prices?.wholesale?.amount * 2.60).toFixed(2);
    console.log(`| ${p.destination?.amount} PHP | ${p.prices?.wholesale?.amount} OMR ($${wholesaleUsd} USD) (\`${p.id}\` ${p.name}) |`);
  });

  console.log(`\nReloadly Operators:`);
  rlOps.forEach(o => {
    console.log(`Op ${o.operatorId} (${o.name}): Denom ${o.denominationType}, Fixed USD: ${o.fixedAmounts?.join(', ')}, Local: ${o.localFixedAmounts?.join(', ')}`);
  });

  console.log(`\nZendit Offers (${zenOffs.length}):`);
  zenOffs.sort((a,b) => (a.send?.fixed || 0) - (b.send?.fixed || 0)).forEach(o => {
    const costUsd = ((o.cost?.fixed || 0) / (o.cost?.currencyDivisor || 100)).toFixed(2);
    const sendPhp = ((o.send?.fixed || 0) / (o.send?.currencyDivisor || 100)).toFixed(2);
    console.log(`| ${sendPhp} PHP | $${costUsd} USD (\`${o.offerId}\`) |`);
  });
}

formatPHPTable('Globe Telecom', [246], [371, 374, 937], 'Globe');
formatPHPTable('Smart Communications', [570, 1934, 2952], [372, 720, 789, 1207, 376, 976, 1209, 369, 942], 'Smart');
formatPHPTable('DITO Telecommunity', [], [1182, 1183], 'Dito');
formatPHPTable('TM (Touch Mobile)', [3128], [723, 939, 938], 'TouchMobile');
formatPHPTable('TNT (Talk \'N Text)', [2897], [378, 722, 941, 1208], 'TNT');
