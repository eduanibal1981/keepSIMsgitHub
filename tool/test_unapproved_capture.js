const https = require('https');

const SUPABASE_HOST = process.env.SUPABASE_HOST;
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY;
const TEST_EMAIL = process.env.TEST_EMAIL;
const TEST_PASSWORD = process.env.TEST_PASSWORD;
const TARGET_ORDER_ID = process.env.TARGET_ORDER_ID;

if (!SUPABASE_HOST || !SUPABASE_ANON_KEY || !TEST_EMAIL || !TEST_PASSWORD || !TARGET_ORDER_ID) {
  throw new Error("Missing required environment variables: SUPABASE_HOST, SUPABASE_ANON_KEY, TEST_EMAIL, TEST_PASSWORD, TARGET_ORDER_ID");
}

async function run() {
  const postData = JSON.stringify({ email: TEST_EMAIL, password: TEST_PASSWORD });
  const req = https.request({
    hostname: SUPABASE_HOST,
    path: '/auth/v1/token?grant_type=password',
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'apikey': SUPABASE_ANON_KEY, 'Content-Length': Buffer.byteLength(postData) }
  }, (res) => {
    let body = '';
    res.on('data', c => body += c);
    res.on('end', () => {
      const token = JSON.parse(body).access_token;
      const captureBody = JSON.stringify({ order_id: TARGET_ORDER_ID });
      const capReq = https.request({
        hostname: SUPABASE_HOST,
        path: '/functions/v1/capture-paypal-order',
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token, 'Content-Length': Buffer.byteLength(captureBody) }
      }, (cRes) => {
        let cBody = '';
        cRes.on('data', c => cBody += c);
        cRes.on('end', () => {
          console.log(`CAPTURE_UNAPPROVED_RESPONSE (HTTP ${cRes.statusCode}):`, cBody);
        });
      });
      capReq.write(captureBody);
      capReq.end();
    });
  });
  req.write(postData);
  req.end();
}

run();
