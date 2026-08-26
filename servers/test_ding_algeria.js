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
  const dingKey = env.DING_API_KEY;
  const dingBase = 'https://api.dingconnect.com/api/V1';

  console.log('Testing DingConnect for Algeria...');
  
  for (const pCode of ['MDDZ', 'DJDZ', 'OODZ']) {
    console.log(`\nWaiting 3 seconds then checking ${pCode}...`);
    await sleep(3000);
    try {
      const res = await fetch(`${dingBase}/GetProducts?providerCodes=${pCode}`, {
        headers: { api_key: dingKey }
      });
      console.log(`Status: ${res.status}`);
      const data = await res.json();
      console.log(`Result:`, JSON.stringify(data, null, 2).slice(0, 500));
    } catch (e) {
      console.error(`Error:`, e.message);
    }
  }
}

main().catch(console.error);
