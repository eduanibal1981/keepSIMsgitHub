const fs = require('fs');
const path = require('path');

const zenditOffers = JSON.parse(fs.readFileSync(path.join(__dirname, 'zendit_ph_offers.json'), 'utf8'));
const tmZen = zenditOffers.filter(o => (o.brand || '').toLowerCase() === 'touchmobile');
console.log('Zendit TM Offers:', tmZen.map(o => ({ offerId: o.offerId, name: o.name, price: o.price, send: o.send })));
