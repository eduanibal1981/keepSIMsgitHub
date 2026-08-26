const fs = require('fs');
const path = require('path');

const data = JSON.parse(fs.readFileSync(path.join(__dirname, 'morocco_discovery_raw.json'), 'utf8'));

console.log('=== RELOADLY OPERATORS DETAIL ===');
data.reloadly.operators.forEach(op => {
  console.log(`\nID: ${op.operatorId} | Name: ${op.name} | DenomType: ${op.denominationType}`);
  console.log(`  Min: ${op.minAmount}, Max: ${op.maxAmount}, SenderCurr: ${op.senderCurrencyCode}`);
  console.log(`  LocalMin: ${op.localMinAmount}, LocalMax: ${op.localMaxAmount}, DestCurr: ${op.destinationCurrencyCode}`);
  console.log(`  FixedAmounts: ${JSON.stringify(op.fixedAmounts)}`);
  console.log(`  LocalFixedAmounts: ${JSON.stringify(op.localFixedAmounts)}`);
  console.log(`  SuggestedAmounts: ${JSON.stringify(op.suggestedAmounts)}`);
  console.log(`  FixedAmountsDesc: ${JSON.stringify(op.fixedAmountsDescriptions)}`);
});
