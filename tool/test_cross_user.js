const https = require('https');

const SUPABASE_HOST = process.env.SUPABASE_HOST;
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY;
const TEST_EMAIL_USER2 = process.env.TEST_EMAIL_USER2;
const TEST_PASSWORD_USER2 = process.env.TEST_PASSWORD_USER2;
const TARGET_ORDER_ID = process.env.TARGET_ORDER_ID;

if (!SUPABASE_HOST || !SUPABASE_ANON_KEY || !TEST_EMAIL_USER2 || !TEST_PASSWORD_USER2 || !TARGET_ORDER_ID) {
  throw new Error("Missing required environment variables: SUPABASE_HOST, SUPABASE_ANON_KEY, TEST_EMAIL_USER2, TEST_PASSWORD_USER2, TARGET_ORDER_ID");
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

async function postRequest(path, token, bodyObj) {
  const postData = JSON.stringify(bodyObj);
  const options = {
    hostname: SUPABASE_HOST,
    path,
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
  const tokenUser2 = await login(TEST_EMAIL_USER2, TEST_PASSWORD_USER2);

  const crossRes = await postRequest('/functions/v1/capture-paypal-order', tokenUser2, { order_id: TARGET_ORDER_ID });
  console.log('CROSS_USER_CAPTURE_RES:', crossRes.status, crossRes.data);
}

main();
