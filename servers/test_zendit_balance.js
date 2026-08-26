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

async function checkBalance() {
  const res = await fetch(`${baseUrl}/balance`, {
    headers: { Authorization: `Bearer ${secret}` }
  });
  console.log('Balance status:', res.status);
  console.log('Balance response:', await res.json());
}
checkBalance().catch(console.error);
