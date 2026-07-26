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
      res.on('end', () => {
        const parsed = JSON.parse(data);
        if (!parsed.access_token) {
          reject(new Error('Login failed: ' + data));
        } else {
          resolve(parsed.access_token);
        }
      });
    });
    req.on('error', reject);
    req.write(postData);
    req.end();
  });
}

async function callCreateOrder(token) {
  const postData = JSON.stringify({ kind: 'deposit', amount_usd: 1.00 });
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
  try {
    const token = await login(TEST_EMAIL, TEST_PASSWORD);
    console.log('Obtained user JWT successfully.');

    for (let i = 1; i <= 11; i++) {
      const res = await callCreateOrder(token);
      console.log(`Call ${i}: HTTP ${res.status} | ${res.data}`);
    }
  } catch (err) {
    console.error('Error running test:', err);
  }
}

main();
