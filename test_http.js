const fs = require('fs');
const dotenv = require('dotenv');
const https = require('https');

const envConfig = dotenv.parse(fs.readFileSync('/home/abdal/keepsims_backend/.env'));
const url = envConfig.SUPABASE_URL.replace('https://', '');
const key = envConfig.SUPABASE_SERVICE_ROLE_KEY;

const options = {
  hostname: url,
  port: 443,
  path: '/rest/v1/rpc/check_context',
  method: 'POST',
  headers: {
    'apikey': key,
    'Authorization': `Bearer ${key}`,
    'Content-Type': 'application/json'
  }
};

const req = https.request(options, (res) => {
  console.log('statusCode:', res.statusCode);
  let body = '';
  res.on('data', (d) => { body += d; });
  res.on('end', () => {
    console.log('body:', body);
  });
});

req.on('error', (e) => { console.error(e); });
req.end();
