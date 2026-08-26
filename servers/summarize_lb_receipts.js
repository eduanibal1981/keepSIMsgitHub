const fs = require('fs');
const path = require('path');

const receipts = JSON.parse(fs.readFileSync(path.join(__dirname, 'lebanon_test_receipts.json'), 'utf8'));

console.log('=== DT ONE RECEIPTS ===');
receipts.dtone.forEach(r => {
  console.log({
    carrier: r.carrier,
    name: r.name,
    productId: r.productId,
    httpStatus: r.httpStatus,
    statusMessage: r.response?.status?.message,
    txId: r.response?.id,
    wholesalePrice: r.response?.prices?.wholesale,
    benefits: r.response?.benefits
  });
});

console.log('\n=== RELOADLY RECEIPTS ===');
receipts.reloadly.forEach(r => {
  console.log({
    carrier: r.carrier,
    name: r.name,
    operatorId: r.operatorId,
    httpStatus: r.httpStatus,
    status: r.response?.status,
    txId: r.response?.transactionId,
    deliveredAmount: r.response?.deliveredAmount,
    pin: r.response?.pinDetail
  });
});

console.log('\n=== ZENDIT RECEIPTS ===');
receipts.zendit.forEach(r => {
  console.log({
    carrier: r.carrier,
    name: r.name,
    offerId: r.offerId,
    httpStatus: r.httpStatus,
    txId: r.response?.transactionId,
    status: r.response?.status
  });
});
