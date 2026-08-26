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

async function checkDing() {
  const dingKey = env.DING_API_KEY;
  const dingBase = 'https://api.dingconnect.com/api/V1';

  console.log('=== Checking DingConnect Turkey Providers individually ===');
  const codes = ['TZTR', 'VFTR', 'AVTR'];

  for (const code of codes) {
    console.log(`\nQuerying Ding GetProducts for ${code}...`);
    try {
      const res = await fetch(`${dingBase}/GetProducts?providerCodes=${code}&countryIsos=TR`, {
        headers: { api_key: dingKey }
      });
      console.log(`Status: ${res.status}`);
      const data = await res.json();
      console.log(`ResultCode: ${data.ResultCode}, Total Items: ${data.Items ? data.Items.length : 0}`);
      if (data.Items && data.Items.length > 0) {
        console.log('Sample item:', JSON.stringify(data.Items[0], null, 2));
      } else {
        console.log('Response body:', JSON.stringify(data, null, 2));
      }
    } catch (e) {
      console.error(`Error querying ${code}:`, e.message);
    }
    await sleep(2500);
  }
}

checkDing();
