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

  const ooredooProds = dtProducts.filter(p => p.operator?.id === 1532);
  console.log(`Ooredoo Tunisia (1532) Products count: ${ooredooProds.length}`);
  ooredooProds.forEach(p => {
    console.log(`ID: ${p.id.toString().padEnd(6)} | Name: ${p.name.padEnd(15)} | Type: ${p.type.padEnd(23)} | Wholesale: ${JSON.stringify(p.prices?.wholesale)} | Dest: ${JSON.stringify(p.destination)}`);
  });
}

main().catch(console.error);
