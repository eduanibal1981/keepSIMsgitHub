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

  console.log('--- Ding Account Balance & Status ---');
  try {
    const balRes = await fetch(`${dingBase}/GetBalance`, {
      headers: { api_key: dingKey }
    });
    console.log('Ding Balance Status:', balRes.status, await balRes.json());
  } catch (e) {
    console.error('Ding Balance error:', e);
  }

  console.log('\n--- Ding GetProviders for BH ---');
  try {
    const provRes = await fetch(`${dingBase}/GetProviders?countryIsos=BH`, {
      headers: { api_key: dingKey }
    });
    const provData = await provRes.json();
    console.log('Ding Providers BH Items:', provData.Items?.filter(p => p.ProviderCode === 'BVBH' || p.ProviderCode === 'ZABH'));
  } catch (e) {
    console.error('Ding Provider error:', e);
  }
}

main();
