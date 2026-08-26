const fs = require('fs');
const path = require('path');

const data = JSON.parse(fs.readFileSync(path.join(__dirname, 'bahrain_discovery_raw.json'), 'utf8'));

console.log('=== SUPABASE ===');
console.log('Countries:', data.supabase.countries);
console.log('Carriers in DB:', data.supabase.carriers);
console.log('Carrier Rules:', JSON.stringify(data.supabase.carrier_rules, null, 2));
console.log('Carrier Provider Maps:', JSON.stringify(data.supabase.carrier_provider_map, null, 2));

console.log('\n=== DT ONE ===');
console.log('Operators:', JSON.stringify(data.dtone.operators, null, 2));
console.log('Products Count:', Array.isArray(data.dtone.products) ? data.dtone.products.length : data.dtone.products);
if (Array.isArray(data.dtone.products)) {
  data.dtone.products.forEach(p => {
    console.log(`[DT One] ID: ${p.id} | Name: ${p.name} | Operator: ${p.operator?.id} (${p.operator?.name}) | Type: ${p.type} | Prices: ${JSON.stringify(p.prices || p.source)} | Destination: ${JSON.stringify(p.destination)} | Validity: ${p.validity?.quantity} ${p.validity?.unit}`);
  });
}

console.log('\n=== RELOADLY ===');
console.log('Operators Count:', Array.isArray(data.reloadly.operators) ? data.reloadly.operators.length : data.reloadly.operators);
if (Array.isArray(data.reloadly.operators)) {
  data.reloadly.operators.forEach(op => {
    console.log(`[Reloadly] ID: ${op.operatorId} | Name: ${op.name} | Bundle: ${op.bundle} | Data: ${op.data} | Pin: ${op.pin} | DenomType: ${op.denominationType} | SenderCur: ${op.senderCurrencyCode} | DestCur: ${op.destinationCurrencyCode} | Min: ${op.minAmount} | Max: ${op.maxAmount} | FixedAmounts: ${JSON.stringify(op.fixedAmounts)} | FixedDesc: ${JSON.stringify(op.fixedAmountsDescriptions)}`);
  });
}

console.log('\n=== ZENDIT ===');
console.log('Offers Total:', data.zendit.offers?.total);
if (data.zendit.offers?.list) {
  data.zendit.offers.list.forEach(o => {
    console.log(`[Zendit] OfferId: ${o.offerId} | Brand: ${o.brand} | Name: ${o.name} | PriceType: ${o.priceType} | Price: ${JSON.stringify(o.price)} | Send: ${JSON.stringify(o.send)} | SubTypes: ${JSON.stringify(o.subTypes)}`);
  });
}

console.log('\n=== DINGCONNECT ===');
console.log('Providers Count:', data.ding.providers?.Items?.length);
if (data.ding.providers?.Items) {
  data.ding.providers.Items.filter(p => p.Name.toLowerCase().includes('batelco') || p.Name.toLowerCase().includes('zain') || p.Name.toLowerCase().includes('stc') || p.Name.toLowerCase().includes('viva') || p.Name.toLowerCase().includes('telecom')).forEach(p => {
    console.log(`[Ding Provider] Code: ${p.ProviderCode} | Name: ${p.Name} | Regex: ${p.ValidationRegex} | Care: ${p.CustomerCareNumber}`);
  });
}
console.log('Ding Products Status:', JSON.stringify(data.ding.products, null, 2));
