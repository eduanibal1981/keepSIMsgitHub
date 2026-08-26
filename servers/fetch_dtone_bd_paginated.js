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

const sleep = ms => new Promise(r => setTimeout(r, ms));

async function main() {
  const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
  const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

  const operators = [
    { id: 249, name: 'GrameenPhone Bangladesh' },
    { id: 1446, name: 'Robi Bangladesh' },
    { id: 1447, name: 'Banglalink Bangladesh' },
    { id: 1448, name: 'Teletalk Bangladesh' },
    { id: 1449, name: 'Airtel Bangladesh' }
  ];

  const results = {};

  for (const op of operators) {
    console.log(`\nFetching DT One products for ${op.name} (${op.id})...`);
    results[op.id] = { operator: op, products: [] };
    let page = 1;
    while (true) {
      try {
        const res = await fetch(`${dtBase}/products?operator_id=${op.id}&page=${page}&per_page=50`, {
          headers: { Authorization: `Basic ${dtoneAuth}` }
        });
        if (!res.ok) {
          console.log(`  Page ${page} status ${res.status}`);
          break;
        }
        const prods = await res.json();
        if (!Array.isArray(prods) || prods.length === 0) break;
        results[op.id].products = results[op.id].products.concat(prods);
        console.log(`  Page ${page}: got ${prods.length} products (total: ${results[op.id].products.length})`);
        if (prods.length < 50) break;
        page++;
        await sleep(500);
      } catch (err) {
        console.error(`  Error on page ${page}:`, err.message);
        break;
      }
    }
  }

  fs.writeFileSync(path.join(__dirname, 'dtone_bd_products.json'), JSON.stringify(results, null, 2));
  console.log('\nSaved all DT One products to dtone_bd_products.json');

  // Print summary per operator
  for (const op of operators) {
    const list = results[op.id].products;
    console.log(`\n=== Operator ${op.id}: ${op.name} (${list.length} products) ===`);
    const openRange = list.find(p => p.type === 'RANGED_VALUE_RECHARGE');
    if (openRange) {
      console.log(`  Open Range Product ID: ${openRange.id} (${openRange.name})`);
      console.log(`    Dest Range: ${JSON.stringify(openRange.destination)}`);
      console.log(`    Wholesale: ${JSON.stringify(openRange.prices?.wholesale || openRange.source)}`);
    }
    const fixedProds = list.filter(p => p.type === 'FIXED_VALUE_RECHARGE');
    console.log(`  Fixed Products: ${fixedProds.length}`);
    fixedProds.slice(0, 10).forEach(p => {
      console.log(`    Prod ${p.id}: ${p.name} | Dest: ${p.destination?.amount} ${p.destination?.unit} | Wholesale: ${p.prices?.wholesale?.amount || p.source?.amount} ${p.prices?.wholesale?.unit || p.source?.unit}`);
    });
  }
}

main().catch(console.error);
