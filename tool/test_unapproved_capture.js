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
      const captureBody = JSON.stringify({ order_id: '14C05589R65806517' });
      const capReq = https.request({
        hostname: 'zwxswagokhgbuzrrbnhr.supabase.co',
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
