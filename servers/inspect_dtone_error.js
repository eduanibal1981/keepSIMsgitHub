const fs = require('fs');
const path = require('path');

const receipts = JSON.parse(fs.readFileSync(path.join(__dirname, 'germany_test_receipts.json'), 'utf8'));

receipts.dtone.forEach(r => {
  if (r.httpStatus !== 201) {
    console.log(`Carrier: ${r.carrier} | Product: ${r.productId} | Response:`, JSON.stringify(r.response, null, 2));
  }
});
