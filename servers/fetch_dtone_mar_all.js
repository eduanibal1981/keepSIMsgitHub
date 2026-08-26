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

  let allProducts = [];
  let page = 1;
  while (true) {
    const res = await fetch(`${dtBase}/products?country_iso_code=MAR&page=${page}&per_page=100`, {
      headers: { Authorization: `Basic ${dtoneAuth}` }
    });
    const prods = await res.json();
    if (!Array.isArray(prods) || prods.length === 0) break;
    allProducts = allProducts.concat(prods);
    console.log(`Page ${page}: got ${prods.length} products (Total so far: ${allProducts.length})`);
    if (prods.length < 100) break;
    page++;
  }

  console.log(`\n=== Total DT One Morocco Products: ${allProducts.length} ===`);
  const byOp = {};
  allProducts.forEach(p => {
    const op = `[${p.operator?.id}] ${p.operator?.name}`;
    if (!byOp[op]) byOp[op] = [];
    byOp[op].push(p);
  });

  for (const [op, list] of Object.entries(byOp)) {
    console.log(`\n===========================================`);
    console.log(`Operator: ${op} (${list.length} products)`);
    console.log(`===========================================`);
    list.forEach(p => {
      console.log(`ID: ${p.id} | Name: ${p.name} | Type: ${p.type} | Service: ${p.service?.name} | SubType: ${p.sub_type} | Src: ${p.source?.amount} ${p.source?.unit} | Dest: ${p.destination?.amount} ${p.destination?.unit} | Wholesale: ${p.prices?.wholesale?.amount} ${p.prices?.wholesale?.unit}`);
    });
  }

  fs.writeFileSync(path.join(__dirname, 'dtone_mar_products.json'), JSON.stringify(allProducts, null, 2));
}

main().catch(console.error);
