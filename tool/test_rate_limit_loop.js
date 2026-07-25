const https = require('https');

async function login() {
  const postData = JSON.stringify({
    email: 'a1-wallet-test@example.com',
    password: 'A1TestPass!2026'
  });

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
      res.on('end', () => {
        const parsed = JSON.parse(data);
        resolve(parsed.access_token);
      });
    });
    req.on('error', reject);
    req.write(postData);
    req.end();
  });
}

async function callCreateOrder(token, callIndex) {
  const postData = JSON.stringify({ kind: 'deposit', amount_usd: 1.00 });

  const options = {
    hostname: 'zwxswagokhgbuzrrbnhr.supabase.co',
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
      res.on('end', () => {
        console.log(`Call ${callIndex}: HTTP ${res.statusCode} | ${data}`);
        resolve({ status: res.statusCode, data });
      });
    });
    req.on('error', reject);
    req.write(postData);
    req.end();
  });
}

async function main() {
  try {
    const token = await login();
    console.log('Obtained user JWT successfully.');
    for (let i = 1; i <= 11; i++) {
      await callCreateOrder(token, i);
    }
  } catch (err) {
    console.error('Error:', err);
  }
}

main();
