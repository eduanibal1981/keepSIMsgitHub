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

async function checkDtone() {
  const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
  const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

  const opIds = [451, 602, 718, 2121, 2135, 2139, 2140, 2144, 2146, 2148, 2159, 2728, 2751, 2754, 2768, 2874, 3111, 3117, 6016];

  const allFoundProducts = [];

  for (const opId of opIds) {
    try {
      const res = await fetch(`${dtBase}/products?operator_id=${opId}&per_page=50`, {
        headers: { Authorization: `Basic ${dtoneAuth}` }
      });
      const text = await res.text();
      if (!text) {
        console.log(`Operator ID ${opId}: empty response`);
        continue;
      }
      const prods = JSON.parse(text);
      console.log(`Operator ID ${opId}: status ${res.status}, prods count: ${Array.isArray(prods) ? prods.length : 0}`);
      if (Array.isArray(prods) && prods.length > 0) {
        prods.forEach(p => {
          allFoundProducts.push(p);
          console.log(`   Prod ${p.id}: ${p.name} | Type: ${p.type} | Dest: ${p.destination?.amount} ${p.destination?.unit} | Wholesale: ${p.prices?.wholesale?.amount} ${p.prices?.wholesale?.unit}`);
        });
      }
    } catch (e) {
      console.error(`Operator ID ${opId} error:`, e.message);
    }
  }

  console.log(`\nTotal DT One products found: ${allFoundProducts.length}`);
  fs.writeFileSync(path.join(__dirname, 'dtone_deu_products.json'), JSON.stringify(allFoundProducts, null, 2));
}

checkDtone();
