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

  const opIds = [249, 1446, 1447, 1448, 1449];
  for (const opId of opIds) {
    const pRes = await fetch(`${dtBase}/products?operator_id=${opId}&page=1&per_page=50`, {
      headers: { Authorization: `Basic ${dtoneAuth}` }
    });
    const prods = await pRes.json();
    console.log(`\nDT One Operator ${opId} Products (${pRes.status}):`, Array.isArray(prods) ? prods.length : prods);
    if (Array.isArray(prods)) {
      prods.forEach(p => {
        console.log(`  ID: ${p.id} | Name: ${p.name} | Type: ${p.type} | Dest: ${JSON.stringify(p.destination)} | Wholesale: ${JSON.stringify(p.prices?.wholesale || p.source)}`);
      });
    }
  }
}

main().catch(console.error);
