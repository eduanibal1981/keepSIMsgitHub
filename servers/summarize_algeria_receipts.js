const fs = require('fs');
const path = require('path');

const data = JSON.parse(fs.readFileSync(path.join(__dirname, 'algeria_test_receipts.json'), 'utf8'));

console.log('=== ALGERIA TEST RECEIPTS SUMMARY ===\n');

console.log('--- DT ONE PRE-PROD RECEIPTS ---');
data.dtone.forEach(r => {
  console.log(`[${r.carrier}] ${r.name} -> ${r.recipient} | HTTP ${r.httpStatus} | TxID: ${r.response.id} | Status: ${r.response.status?.message} | Cost: ${r.response.prices?.wholesale?.amount} ${r.response.prices?.wholesale?.unit} | Delivered: ${r.response.benefits?.[0]?.amount?.total_including_tax} ${r.response.benefits?.[0]?.unit}`);
});

console.log('\n--- RELOADLY SANDBOX RECEIPTS ---');
data.reloadly.forEach(r => {
  console.log(`[${r.carrier}] ${r.name} -> ${r.recipient} | HTTP ${r.httpStatus} | TxID: ${r.response.transactionId} | Status: ${r.response.status} | Cost: $${r.response.balanceInfo?.cost} ${r.response.balanceInfo?.currencyCode} (Discount: $${r.response.discount}) | Delivered: ${r.response.deliveredAmount} ${r.response.deliveredAmountCurrencyCode}`);
});

console.log('\n--- ZENDIT SANDBOX RECEIPTS ---');
data.zendit.forEach(r => {
  console.log(`[${r.carrier}] ${r.name} -> ${r.recipient} | HTTP ${r.httpStatus} | TxID: ${r.response.transactionId} | Status: ${r.response.status}`);
});

console.log('\n--- DINGCONNECT STATUS ---');
data.ding.forEach(r => {
  console.log(`[${r.country}] Providers: ${r.providers.join(', ')} | Status: ${r.status}`);
});
