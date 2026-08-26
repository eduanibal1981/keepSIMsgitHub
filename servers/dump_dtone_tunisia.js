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

  const opRes = await fetch(`${dtBase}/operators?country_iso_code=TUN&page=1&per_page=50`, {
    headers: { Authorization: `Basic ${dtoneAuth}` }
  });
  const dtOperators = await opRes.json();
  console.log('DT ONE OPERATORS:');
  console.log(JSON.stringify(dtOperators, null, 2));

  let dtProducts = [];
  let page = 1;
  while (true) {
    const prodRes = await fetch(`${dtBase}/products?country_iso_code=TUN&page=${page}&per_page=100`, {
      headers: { Authorization: `Basic ${dtoneAuth}` }
    });
    const products = await prodRes.json();
    if (!Array.isArray(products) || products.length === 0) break;
    dtProducts = dtProducts.concat(products);
    page++;
  }
  console.log(`\nDT ONE ALL PRODUCTS (${dtProducts.length}):`);
  dtProducts.forEach(p => {
    console.log(`Operator: ${p.operator?.id} (${p.operator?.name}) | ID: ${p.id} | Name: ${p.name} | Type: ${p.type} | Wholesale: ${JSON.stringify(p.prices?.wholesale)} | Dest: ${JSON.stringify(p.destination)}`);
  });
}

main().catch(console.error);
