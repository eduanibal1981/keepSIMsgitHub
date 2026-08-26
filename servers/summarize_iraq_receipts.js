const fs = require('fs');
const path = require('path');

const receipts = JSON.parse(fs.readFileSync(path.join(__dirname, 'iraq_test_receipts.json'), 'utf8'));

console.log('=== SUMMARY OF IRAQ TEST RECEIPTS ===\n');

console.log('--- 1. ZENDIT RECEIPTS ---');
receipts.zendit.forEach(r => {
  console.log(`[${r.carrier}] ${r.name} -> HTTP ${r.httpStatus} | status: ${r.response?.status} | TxnRef: ${r.response?.transactionReference} | Cost: $${r.response?.cost?.fixed/100} USD | Price: $${r.response?.price?.fixed/100} USD`);
});

console.log('\n--- 2. DT ONE RECEIPTS ---');
receipts.dtone.forEach(r => {
  console.log(`[${r.carrier}] ${r.name} -> HTTP ${r.httpStatus} | Txn ID: ${r.response?.id} | status: ${r.response?.status?.message} | Product: ${r.response?.product?.id} (${r.response?.product?.name}) | Type: ${r.response?.product?.type} | PIN: ${JSON.stringify(r.response?.pin?.usage_info || r.response?.pin)} | Wholesale: ${JSON.stringify(r.response?.prices?.wholesale)}`);
});

console.log('\n--- 3. RELOADLY RECEIPTS ---');
receipts.reloadly.forEach(r => {
  console.log(`[${r.carrier}] ${r.name} -> HTTP ${r.httpStatus} | Txn ID: ${r.response?.transactionId} | status: ${r.response?.status} | Delivered: ${r.response?.deliveredAmount} ${r.response?.deliveredAmountCurrencyCode} | Cost: $${r.response?.balanceInfo?.cost} USD`);
});
