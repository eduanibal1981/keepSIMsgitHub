const fs = require('fs');
const path = require('path');

const candidatePaths = [
  path.join(__dirname, '..', 'servers', '.env'),
  path.join(__dirname, 'servers', '.env'),
  '/home/abdal/keepsims_backend/servers/.env'
];
let env = {};
for (const p of candidatePaths) {
  if (fs.existsSync(p)) {
    const content = fs.readFileSync(p, 'utf8');
    content.split('\n').forEach(line => {
      const m = line.match(/^\s*([\w_]+)\s*=\s*(.*)?\s*$/);
      if (m) {
        let v = (m[2] || '').trim();
        if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) {
          v = v.slice(1, -1);
        }
        env[m[1]] = v;
      }
    });
    break;
  }
}

const dtoneApiKey = env.DTONE_API_KEY;
const dtoneApiSecret = env.DTONE_API_SECRET;
const dtoneBaseUrl = env.DTONE_BASE_URL || 'https://preprod-dvs-api.dtone.com/v1';

const reloadlyClientId = env.RELOADLY_CLIENT_ID;
const reloadlyClientSecret = env.RELOADLY_CLIENT_SECRET;
const reloadlyBaseUrl = env.RELOADLY_BASE_URL || 'https://topups-sandbox.reloadly.com';
const reloadlyAuthUrl = env.RELOADLY_AUTH_URL || 'https://auth.reloadly.com/oauth/token';

const zenditApiSecret = env.ZENDIT_API_SECRET;
const zenditBaseUrl = env.ZENDIT_BASE_URL || 'https://api.zendit.io/v1';

const dingApiKey = env.DING_API_KEY;
const dingBaseUrl = env.DING_BASE_URL || 'https://api.dingconnect.com/api/V1';

async function searchGlobal() {
  console.log('=== 1. SEARCHING DT ONE FOR FRIENDI / VODAFONE / OMAN ===');
  const authHeader = 'Basic ' + Buffer.from(`${dtoneApiKey}:${dtoneApiSecret}`).toString('base64');
  
  // Search DT One operators matching friendi, vodafone, renna, red bull
  try {
    const res = await fetch(`${dtoneBaseUrl}/operators?per_page=100&page=1`, { headers: { Authorization: authHeader } });
    // Let's search all DT One operators
    let allDtoneOps = [];
    let page = 1;
    while (page <= 20) {
      const pRes = await fetch(`${dtoneBaseUrl}/operators?page=${page}&per_page=100`, { headers: { Authorization: authHeader } });
      if (!pRes.ok) break;
      const data = await pRes.json();
      if (!Array.isArray(data) || data.length === 0) break;
      allDtoneOps.push(...data);
      if (data.length < 100) break;
      page++;
    }
    console.log(`Fetched ${allDtoneOps.length} DT One operators.`);
    const omDtoneOps = allDtoneOps.filter(o => 
      o.country?.iso_code === 'OMN' || 
      (o.name && o.name.toLowerCase().includes('oman')) ||
      (o.name && o.name.toLowerCase().includes('friendi'))
    );
    console.log('DT One Oman-related operators:', JSON.stringify(omDtoneOps, null, 2));
  } catch (e) {
    console.error('DT One search error:', e.message);
  }

  console.log('\n=== 2. SEARCHING RELOADLY FOR ALL OPERATORS IN OM & REGION ===');
  try {
    const aRes = await fetch(reloadlyAuthUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        client_id: reloadlyClientId,
        client_secret: reloadlyClientSecret,
        grant_type: 'client_credentials',
        audience: reloadlyBaseUrl.replace(/\/$/, '')
      })
    });
    const { access_token } = await aRes.json();
    
    // Search Reloadly operators for OM
    const omOpsRes = await fetch(`${reloadlyBaseUrl}/operators/countries/OM?includeBundles=true&includeData=true&includePin=true`, {
      headers: { Authorization: `Bearer ${access_token}`, Accept: 'application/com.reloadly.topups-v1+json' }
    });
    const omOps = await omOpsRes.json();
    console.log('Reloadly OM Operators:', JSON.stringify(omOps, null, 2));

    // Also check auto-detect endpoint for test numbers in Oman (+968)
    const testNums = ['+96891000101', '+96892000101', '+96871000101', '+96898000101'];
    for (const tn of testNums) {
      const detRes = await fetch(`${reloadlyBaseUrl}/operators/auto-detect/phone/${encodeURIComponent(tn)}/countries/OM`, {
        headers: { Authorization: `Bearer ${access_token}`, Accept: 'application/com.reloadly.topups-v1+json' }
      });
      console.log(`Reloadly auto-detect for ${tn}: ${detRes.status}`);
      if (detRes.ok) {
        const detData = await detRes.json();
        console.log(`  -> Operator: ${detData.operatorId} - ${detData.name}`);
      }
    }
  } catch (e) {
    console.error('Reloadly error:', e.message);
  }

  console.log('\n=== 3. SEARCHING ZENDIT FOR ALL OFFERS / BRANDS ===');
  try {
    // Check if Zendit has any brands endpoint or all offers
    const bRes = await fetch(`${zenditBaseUrl}/topups/brands`, {
      headers: { Authorization: `Bearer ${zenditApiSecret}` }
    });
    console.log(`Zendit /topups/brands Status: ${bRes.status}`);
    if (bRes.ok) {
      const bData = await bRes.json();
      console.log('Zendit Brands sample:', (bData.list || bData || []).slice(0, 10));
    }
  } catch (e) {
    console.error('Zendit error:', e.message);
  }

  console.log('\n=== 4. TESTING DINGCONNECT DETAILED ENDPOINTS FOR OM ===');
  try {
    // Check /GetCurrencies, /GetErrorCodeDescriptions, /GetBalance
    const balRes = await fetch(`${dingBaseUrl}/GetBalance`, { headers: { api_key: dingApiKey } });
    console.log(`Ding /GetBalance Status: ${balRes.status}`);
    if (balRes.ok) {
      console.log('Ding Balance:', await balRes.json());
    }

    // Test /GetProducts with Account lookup for Oman test numbers (+968 91000101, +968 92000101, +968 71000101)
    const testAccounts = ['96891000101', '96892000101', '96871000101', '96898000101'];
    for (const acc of testAccounts) {
      const accRes = await fetch(`${dingBaseUrl}/GetProductsByAccount?accountNumber=${acc}`, {
        headers: { api_key: dingApiKey }
      });
      console.log(`Ding /GetProductsByAccount?accountNumber=${acc} Status: ${accRes.status}`);
      if (accRes.ok) {
        const accData = await accRes.json();
        console.log(`  ResultCode: ${accData.ResultCode}, Products: ${accData.Items?.length || 0}`);
        if (accData.Items && accData.Items.length > 0) {
          console.log(`  Sample:`, accData.Items[0]);
        }
      }
    }

    // Also test GetProducts for individual ProviderCodes
    for (const pCode of ['OMOM', 'OOOM', 'VFOM']) {
      const pRes = await fetch(`${dingBaseUrl}/GetProducts?providerCodes=${pCode}`, {
        headers: { api_key: dingApiKey }
      });
      console.log(`Ding /GetProducts?providerCodes=${pCode} Status: ${pRes.status}`);
      if (pRes.ok) {
        const pData = await pRes.json();
        console.log(`  ResultCode: ${pData.ResultCode}, Count: ${pData.Items?.length || 0}`);
        if (pData.Items && pData.Items.length > 0) {
          console.log(`  Sample product:`, pData.Items[0]);
        }
      } else {
        console.log(`  Error:`, await pRes.text());
      }
    }
  } catch (e) {
    console.error('Ding error:', e.message);
  }
}

searchGlobal().catch(console.error);
