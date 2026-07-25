const https = require('https');

async function run() {
  const postData = JSON.stringify({ email: 'a1-wallet-test@example.com', password: 'A1TestPass!2026' });
  const req = https.request({
    hostname: 'zwxswagokhgbuzrrbnhr.supabase.co',
    path: '/auth/v1/token?grant_type=password',
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp3eHN3YWdva2hnYnV6cnJibmhyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkwMDg3MDIsImV4cCI6MjA5NDU4NDcwMn0.JzzxxqQiKEka-VLbmPH1hdBXH4aML0AMhrqXloIZXt0', 'Content-Length': Buffer.byteLength(postData) }
  }, (res) => {
    let body = '';
    res.on('data', c => body += c);
    res.on('end', () => {
      const token = JSON.parse(body).access_token;
      const orderBody = JSON.stringify({ kind: 'deposit', amount_usd: 1.00 });
      const orderReq = https.request({
        hostname: 'zwxswagokhgbuzrrbnhr.supabase.co',
        path: '/functions/v1/create-paypal-order',
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token, 'Content-Length': Buffer.byteLength(orderBody) }
      }, (oRes) => {
        let oBody = '';
        oRes.on('data', c => oBody += c);
        oRes.on('end', () => {
          console.log('SINGLE_ORDER_RESPONSE:', oBody);
        });
      });
      orderReq.write(orderBody);
      orderReq.end();
    });
  });
  req.write(postData);
  req.end();
}

run();
