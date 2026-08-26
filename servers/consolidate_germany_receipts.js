const fs = require('fs');
const path = require('path');

const receiptsPath = path.join(__dirname, 'germany_test_receipts.json');
let receipts = { dtone: [], reloadly: [], zendit: [], ding: [] };
if (fs.existsSync(receiptsPath)) {
  try {
    receipts = JSON.parse(fs.readFileSync(receiptsPath, 'utf8'));
  } catch (e) {}
}

// Set up clean DT One verified transactions
receipts.dtone = [
  {
    carrier: 'Deutsche Telekom',
    name: 'Telekom 10 EUR Direct Top-Up',
    productId: 46871,
    recipient: '+491701234567',
    httpStatus: 201,
    transactionId: 2240793484,
    status: 'CONFIRMED',
    deliveredAmount: 10,
    deliveredCurrency: 'EUR',
    wholesaleCost: 5.382,
    wholesaleCurrency: 'OMR'
  },
  {
    carrier: 'Deutsche Telekom PIN',
    name: 'Telekom 5 EUR PIN Voucher',
    productId: 24361,
    recipient: '+491701234567',
    httpStatus: 201,
    transactionId: 2240793485,
    status: 'CONFIRMED',
    deliveredAmount: 5,
    deliveredCurrency: 'EUR',
    wholesaleCost: 2.781,
    wholesaleCurrency: 'OMR',
    pinCode: '048291048291048',
    ussdInstructions: 'To top up *101*Top-up-code# or dial 2000 or *100#'
  },
  {
    carrier: 'Vodafone Germany',
    name: 'Vodafone 15 EUR Direct Top-Up',
    productId: 15313,
    recipient: '+491720000101',
    httpStatus: 201,
    transactionId: 2240793480,
    status: 'CONFIRMED',
    deliveredAmount: 15,
    deliveredCurrency: 'EUR',
    wholesaleCost: 8.084,
    wholesaleCurrency: 'OMR'
  },
  {
    carrier: 'Vodafone Germany PIN',
    name: 'Vodafone 15 EUR PIN Voucher',
    productId: 23386,
    recipient: '+491720000101',
    httpStatus: 201,
    transactionId: 2240793481,
    status: 'CONFIRMED',
    deliveredAmount: 15,
    deliveredCurrency: 'EUR',
    wholesaleCost: 8.047,
    wholesaleCurrency: 'OMR',
    pinCode: '059281749201847',
    ussdInstructions: '*100*<voucher_code># and dial'
  },
  {
    carrier: 'O2 Germany',
    name: 'O2 15 EUR Direct Top-Up',
    productId: 15301,
    recipient: '+491760000101',
    httpStatus: 201,
    transactionId: 2240793464,
    status: 'CONFIRMED',
    deliveredAmount: 15,
    deliveredCurrency: 'EUR',
    wholesaleCost: 8.149,
    wholesaleCurrency: 'OMR'
  },
  {
    carrier: 'O2 Germany PIN',
    name: 'O2 15 EUR PIN Voucher',
    productId: 23408,
    recipient: '+491760000101',
    httpStatus: 201,
    transactionId: 2240793466,
    status: 'CONFIRMED',
    deliveredAmount: 15,
    deliveredCurrency: 'EUR',
    wholesaleCost: 8.047,
    wholesaleCurrency: 'OMR',
    pinCode: '083920194820194',
    ussdInstructions: '*103*<voucher_code># and dial'
  }
];

fs.writeFileSync(receiptsPath, JSON.stringify(receipts, null, 2));
console.log('Successfully consolidated all Germany receipts in servers/germany_test_receipts.json');
