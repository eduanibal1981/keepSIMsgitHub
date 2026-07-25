const https = require('https');

async function login(email, password) {
  const postData = JSON.stringify({ email, password });
  const options = {
    hostname: 'zwxswagokhgbuzrrbnhr.supabase.co',
    path: '/auth/v1/token?grant_type=password',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp3eHN3YWdva2hnYnV6cnJibmhyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkwMDg3MDIsImV4cCI6MjA5NDU4NDcwMn0.JzzxxqQiKEka-VLbmPH1hdBXH4aML0AMhrqXloIZXt0',
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
    hostname: 'zwxswagokhgbuzrrbnhr.supabase.co',
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
  // Login as user2 (c5_user2@test.com)
  const tokenUser2 = await login('c5_user2@test.com', 'A1TestPass!2026');

  // Attempt capture on a1 user's order 1SY147872Y509180F
  const crossRes = await postRequest('/functions/v1/capture-paypal-order', tokenUser2, { order_id: '1SY147872Y509180F' });
  console.log('CROSS_USER_CAPTURE_RES:', crossRes.status, crossRes.data);
}

main();
