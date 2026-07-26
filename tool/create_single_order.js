const https = require('https');

const SUPABASE_HOST = process.env.SUPABASE_HOST;
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY;
const TEST_EMAIL = process.env.TEST_EMAIL;
const TEST_PASSWORD = process.env.TEST_PASSWORD;

if (!SUPABASE_HOST || !SUPABASE_ANON_KEY || !TEST_EMAIL || !TEST_PASSWORD) {
  throw new Error("Missing required environment variables: SUPABASE_HOST, SUPABASE_ANON_KEY, TEST_EMAIL, TEST_PASSWORD");
}

async function login(email, password) {
  const postData = JSON.stringify({ email, password });
  const options = {
    hostname: SUPABASE_HOST,
    path: '/auth/v1/token?grant_type=password',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'apikey': SUPABASE_ANON_KEY,
      'Content-Length': Buffer.byteLength(postData)
    }
  };

  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve(JSON.parse(data).access_token));
    });
    req.on('error', reject);
    req.write(postData);
    req.end();
  });
}

async function createOrder(token, amountUsd) {
  const postData = JSON.stringify({ kind: 'deposit', amount_usd: amountUsd });
  const options = {
    hostname: SUPABASE_HOST,
    path: '/functions/v1/create-paypal-order',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ' + token,
      'Content-Length': Buffer.byteLength(postData)
    }
  };

  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve({ status: res.statusCode, data }));
    });
    req.on('error', reject);
    req.write(postData);
    req.end();
  });
}

async function main() {
  const token = await login(TEST_EMAIL, TEST_PASSWORD);
  const res = await createOrder(token, 1.00);
  console.log(`ORDER_CREATION: HTTP ${res.status} | ${res.data}`);
}

main();
