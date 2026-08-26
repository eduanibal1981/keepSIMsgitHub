const fs = require('fs');
const path = require('path');

const receipts = JSON.parse(fs.readFileSync(path.join(__dirname, 'germany_test_receipts.json'), 'utf8'));

console.log('=== 1. DT ONE RECEIPTS ===');
receipts.dtone.forEach(r => {
  console.log(`Carrier: ${r.carrier} | Name: ${r.name} | HTTP: ${r.httpStatus} | Tx ID: ${r.response?.id} | Status: ${r.response?.status?.message} | Cost: ${r.response?.prices?.wholesale?.amount} ${r.response?.prices?.wholesale?.unit} | PIN: ${r.response?.pin?.code || 'N/A'}`);
});

console.log('\n=== 2. RELOADLY RECEIPTS ===');
receipts.reloadly.forEach(r => {
  console.log(`Carrier: ${r.carrier} | Name: ${r.name} | HTTP: ${r.httpStatus} | Tx ID: ${r.response?.transactionId} | Status: ${r.response?.status} | Cost: $${r.response?.balanceInfo?.cost} ${r.response?.balanceInfo?.currencyCode} | PIN: ${r.response?.pinDetail?.code || 'N/A'}`);
});

console.log('\n=== 3. ZENDIT RECEIPTS ===');
receipts.zendit.forEach(r => {
  console.log(`Carrier: ${r.carrier} | Name: ${r.name} | HTTP: ${r.httpStatus} | Tx ID: ${r.response?.transactionId} | Status: ${r.response?.status}`);
});
