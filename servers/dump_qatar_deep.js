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
  console.log('======================================================');
  console.log('=== DEEP INSPECTION OF QATAR OPERATORS & PRODUCTS ===');
  console.log('======================================================');

  // 1. DT ONE full product dumps
  const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
  const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

  console.log('\n--- DT ONE DETAILED PRODUCTS ---');
  for (const pid of [33349, 1738, 17355, 17356, 17361, 17362]) {
    try {
      const res = await fetch(`${dtBase}/products/${pid}`, {
        headers: { Authorization: `Basic ${dtoneAuth}` }
      });
      const p = await res.json();
      console.log(`\nProduct ${pid} (${p.name}):`);
      console.log(`  Operator: ${p.operator?.id} - ${p.operator?.name}`);
      console.log(`  Type: ${p.type} | Service: ${p.service?.name} / ${p.service?.subservice?.name}`);
      console.log(`  Destination: ${JSON.stringify(p.destination)}`);
      console.log(`  Prices: Wholesale ${p.prices?.wholesale?.amount} ${p.prices?.wholesale?.unit} | Retail ${p.prices?.retail?.amount} ${p.prices?.retail?.unit}`);
      console.log(`  PIN info:`, JSON.stringify(p.pin));
      console.log(`  Benefits:`, JSON.stringify(p.benefits));
    } catch (e) {
      console.error(`Error fetching DT One product ${pid}:`, e.message);
    }
  }

  // 2. RELOADLY full operator details & promotions / discounts
  console.log('\n--- RELOADLY OPERATOR DETAILS & COMMISSIONS ---');
  const authRes = await fetch('https://auth.reloadly.com/oauth/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client_id: env.RELOADLY_CLIENT_ID,
      client_secret: env.RELOADLY_CLIENT_SECRET,
      grant_type: 'client_credentials',
      audience: 'https://topups-sandbox.reloadly.com'
    })
  });
  const authData = await authRes.json();
  const token = authData.access_token;

  for (const opId of [396, 395]) {
    try {
      const opRes = await fetch(`https://topups-sandbox.reloadly.com/operators/${opId}`, {
        headers: {
          Authorization: `Bearer ${token}`,
          Accept: 'application/com.reloadly.topups-v1+json'
        }
      });
      const op = await opRes.json();
      console.log(`\nReloadly Operator ${opId} (${op.name}):`);
      console.log(JSON.stringify(op, null, 2));

      // Check commissions / discounts
      const commRes = await fetch(`https://topups-sandbox.reloadly.com/operators/${opId}/commissions`, {
        headers: {
          Authorization: `Bearer ${token}`,
          Accept: 'application/com.reloadly.topups-v1+json'
        }
      });
      if (commRes.ok) {
        const comm = await commRes.json();
        console.log(`  Commission / Discount:`, JSON.stringify(comm));
      }
    } catch (e) {
      console.error(`Error fetching Reloadly operator ${opId}:`, e.message);
    }
  }
}

main().catch(console.error);
