const https = require('https');

const SUPABASE_HOST = process.env.SUPABASE_HOST || 'zwxswagokhgbuzrrbnhr.supabase.co';
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp3eHN3YWdva2hnYnV6cnJibmhyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkwMDg3MDIsImV4cCI6MjA5NDU4NDcwMn0.JzzxxqQiKEka-VLbmPH1hdBXH4aML0AMhrqXloIZXt0';
const TEST_EMAIL = process.env.TEST_EMAIL || 'a1-wallet-test@example.com';
const TEST_PASSWORD = process.env.TEST_PASSWORD || 'A1TestPass!2026';

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
  const token = await login(TEST_EMAIL, TEST_PASSWORD);

  const createRes = await postRequest('/functions/v1/create-paypal-order', token, { kind: 'deposit', amount_usd: 1.00 });
  console.log('CREATED_ORDER_RES:', createRes.status, createRes.data);

  const orderData = JSON.parse(createRes.data);
  const orderId = orderData.order_id;

  const unappCaptureRes = await postRequest('/functions/v1/capture-paypal-order', token, { order_id: orderId });
  console.log('UNAPPROVED_CAPTURE_RES:', unappCaptureRes.status, unappCaptureRes.data);

  const unknownRes = await postRequest('/functions/v1/capture-paypal-order', token, { order_id: 'UNKNOWN_ORDER_99999' });
  console.log('UNKNOWN_ORDER_RES:', unknownRes.status, unknownRes.data);
}

main();
