const fs = require('fs');
const path = require('path');

// Read servers/.env
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

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function main() {
  console.log('=== DEEP DIVE LEBANON CATALOG INSPECTION ===\n');

  // 1. DT ONE
  console.log('--- 1. DT ONE PRODUCTS FOR LEBANON (LBN) ---');
  const dtoneAuth = Buffer.from(`${env.DTONE_API_KEY}:${env.DTONE_API_SECRET}`).toString('base64');
  const dtBase = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

  let dtProducts = [];
  for (let page = 1; page <= 5; page++) {
    try {
      await sleep(1000);
      const res = await fetch(`${dtBase}/products?country_iso_code=LBN&page=${page}&per_page=50`, {
        headers: { Authorization: `Basic ${dtoneAuth}` }
      });
      console.log(`DT One Page ${page} Status: ${res.status}`);
      if (res.ok) {
        const data = await res.json();
        if (Array.isArray(data) && data.length > 0) {
          dtProducts.push(...data);
        } else {
          break;
        }
      } else {
        const txt = await res.text();
        console.log(`DT One error page ${page}:`, txt);
        if (res.status === 429) {
          console.log('Waiting 3s for rate limit...');
          await sleep(3000);
          page--; // retry
        }
      }
    } catch (e) {
      console.error(`DT One fetch error page ${page}:`, e.message);
    }
  }
  console.log(`\nDT One Total Products Found: ${dtProducts.length}`);
  dtProducts.forEach(p => {
    console.log(`[DT One Product] ID: ${p.id} | Name: ${p.name} | Operator: ${p.operator?.id} (${p.operator?.name}) | Type: ${p.type} | Prices: ${JSON.stringify(p.prices?.wholesale || p.source || p.prices)} | Destination: ${JSON.stringify(p.destination)} | Validity: ${JSON.stringify(p.validity)}`);
  });

  // 2. ZENDIT
  console.log('\n--- 2. ZENDIT OFFERS FOR LEBANON (LB) ---');
  const zenSecret = env.ZENDIT_API_SECRET;
  const zenBase = 'https://api.zendit.io/v1';

  try {
    const res = await fetch(`${zenBase}/topups/offers?country=LB&_offset=0&_limit=100`, {
      headers: { Authorization: `Bearer ${zenSecret}` }
    });
    console.log(`Zendit Status: ${res.status}`);
    const data = await res.json();
    console.log(`Zendit Total: ${data.total}`);
    if (data.list) {
      data.list.forEach(o => {
        console.log(`[Zendit Offer] ID: ${o.offerId} | Brand: ${o.brand} | Name: ${o.name} | PriceType: ${o.priceType} | Price: ${JSON.stringify(o.price)} | Send: ${JSON.stringify(o.send)} | SubTypes: ${JSON.stringify(o.subTypes)}`);
      });
    } else {
      console.log('Zendit Response:', JSON.stringify(data, null, 2));
    }
  } catch (e) {
    console.error('Zendit Error:', e.message);
  }

  // 3. RELOADLY
  console.log('\n--- 3. RELOADLY DEEP OPERATORS FOR LEBANON (LB) ---');
  try {
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
    
    // Get operators by ID
    for (const opId of [1017, 276]) {
      const res = await fetch(`https://topups-sandbox.reloadly.com/operators/${opId}`, {
        headers: {
          Authorization: `Bearer ${token}`,
          Accept: 'application/com.reloadly.topups-v1+json'
        }
      });
      const op = await res.json();
      console.log(`\n[Reloadly Operator ${opId}]`, JSON.stringify(op, null, 2));
    }
  } catch (e) {
    console.error('Reloadly Error:', e.message);
  }

  // Save details
  fs.writeFileSync(path.join(__dirname, 'lebanon_catalogs.json'), JSON.stringify({ dtProducts }, null, 2));
}

main();
