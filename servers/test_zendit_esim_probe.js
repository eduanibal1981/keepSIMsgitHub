const fs = require('fs');
const path = require('path');

const envPath = path.join(__dirname, '.env');
const envContent = fs.readFileSync(envPath, 'utf8');
const env = {};
envContent.split('\n').forEach(line => {
  const trimmed = line.trim();
  if (!trimmed || trimmed.startsWith('#')) return;
  const idx = trimmed.indexOf('=');
  if (idx !== -1) {
    const key = trimmed.slice(0, idx).trim();
    const val = trimmed.slice(idx + 1).trim();
    env[key] = val;
  }
});

const secret = env.ZENDIT_API_SECRET;
const baseUrl = env.ZENDIT_BASE_URL || 'https://api.zendit.io/v1';

async function test() {
  // Let's check Egypt and Saudi Arabia
  for (const country of ['EG', 'SA']) {
    const res = await fetch(`${baseUrl}/esim/offers?country=${country}&_limit=5&_offset=0`, {
      headers: { Authorization: `Bearer ${secret}` }
    });
    const data = await res.json();
    console.log(`\n=== Offers for ${country} (total: ${data.total}) ===`);
    if (data.list) {
      for (const item of data.list.slice(0, 3)) {
        console.log({
          offerId: item.offerId,
          country: item.country,
          regions: item.regions,
          dataGB: item.dataGB,
          dataUnlimited: item.dataUnlimited,
          durationDays: item.durationDays,
          subTypes: item.subTypes,
          costUsd: (item.cost?.fixed || 0) / (item.cost?.currencyDivisor || 100),
          roamingCount: item.roaming?.length,
          roamingCountries: item.roaming?.map(r => r.country),
          shortNotes: item.shortNotes,
        });
      }
    }
  }
}
test().catch(console.error);
