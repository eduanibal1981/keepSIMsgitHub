const fs = require('fs');
const path = require('path');

const envPath = path.join(__dirname, '.env');
const envContent = fs.readFileSync(envPath, 'utf8');
const env = {};
envContent.split('\n').forEach(line => {
  const match = line.match(/^\s*([\w_]+)\s*=\s*(.*)?\s*$/);
  if (match) {
    let val = (match[2] || '').trim();
    if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
      val = val.slice(1, -1);
    }
    env[match[1]] = val;
  }
});

async function main() {
  const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
  const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

  // Check DT One operators
  const opRes = await fetch(`${dtBase}/operators?country_iso_code=TUN&page=1&per_page=50`, {
    headers: { Authorization: `Basic ${dtoneAuth}` }
  });
  const operators = await opRes.json();
  console.log('=== DT ONE OPERATORS (TUN) ===');
  console.log(JSON.stringify(operators, null, 2));

  // Check all DT One products with pagination
  let allProducts = [];
  let page = 1;
  while (true) {
    const prodRes = await fetch(`${dtBase}/products?country_iso_code=TUN&page=${page}&per_page=100`, {
      headers: { Authorization: `Basic ${dtoneAuth}` }
    });
    const products = await prodRes.json();
    if (!Array.isArray(products) || products.length === 0) break;
    allProducts = allProducts.concat(products);
    page++;
  }
  console.log(`\n=== DT ONE PRODUCTS TOTAL: ${allProducts.length} ===`);
  allProducts.forEach(p => {
    console.log(`ID: ${p.id} | Name: ${p.name} | Operator: ${p.operator?.id} (${p.operator?.name}) | Type: ${p.type} | Prices: ${JSON.stringify(p.prices?.wholesale || p.source)} | Dest: ${JSON.stringify(p.destination)}`);
  });

  // Query Zendit with _offset=0&_limit=100
  console.log('\n=== ZENDIT OFFERS (TN) ===');
  const zenSecret = env.ZENDIT_API_SECRET;
  const zenBase = 'https://api.zendit.io/v1';
  try {
    const offRes = await fetch(`${zenBase}/topups/offers?country=TN&_offset=0&_limit=100`, {
      headers: { Authorization: `Bearer ${zenSecret}` }
    });
    const offers = await offRes.json();
    console.log('Zendit Status:', offRes.status);
    console.log('Zendit Offers:', JSON.stringify(offers, null, 2));
  } catch (e) {
    console.error('Zendit error:', e.message);
  }

  // Also query DingConnect for TN again
  console.log('\n=== DINGCONNECT PRODUCTS (TN) ===');
  const dingKey = env.DING_API_KEY;
  const dingBase = 'https://api.dingconnect.com/api/V1';
  try {
    const prodRes = await fetch(`${dingBase}/GetProducts?countryIsos=TN`, {
      headers: { api_key: dingKey }
    });
    console.log(`Ding Products Status: ${prodRes.status}`);
    const dingProd = await prodRes.json();
    console.log(JSON.stringify(dingProd, null, 2));
  } catch (e) {
    console.error('Ding error:', e.message);
  }
}

main().catch(console.error);
