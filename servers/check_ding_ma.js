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
  const dingKey = env.DING_API_KEY;
  const dingBase = 'https://api.dingconnect.com/api/V1';

  for (const prov of ['MOMA', 'ORMA', 'INMA', '0MMA', 'I0MA']) {
    console.log(`\nTesting Ding GetProducts for providerCode: ${prov}...`);
    try {
      const res = await fetch(`${dingBase}/GetProducts?providerCodes=${prov}`, {
        headers: { api_key: dingKey }
      });
      console.log(`Status: ${res.status}`);
      const data = await res.json();
      console.log(`Items: ${data.Items ? data.Items.length : 0}`, JSON.stringify(data).slice(0, 300));
    } catch (e) {
      console.error(`Error: ${e.message}`);
    }
  }
}

main().catch(console.error);
