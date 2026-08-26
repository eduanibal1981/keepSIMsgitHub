const fs = require('fs');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');

const candidatePaths = [
  path.join(__dirname, 'servers', '.env'),
  path.join(__dirname, '..', 'servers', '.env'),
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

const supabase = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY);

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

async function getReloadlyToken() {
  const audience = reloadlyBaseUrl.replace(/\/$/, '');
  const res = await fetch(reloadlyAuthUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client_id: reloadlyClientId,
      client_secret: reloadlyClientSecret,
      grant_type: 'client_credentials',
      audience: audience,
    }),
  });
  const data = await res.json();
  return data.access_token;
}

const dtoneAuthHeader = 'Basic ' + Buffer.from(`${dtoneApiKey}:${dtoneApiSecret}`).toString('base64');

async function main() {
  console.log('================================================================');
  console.log('STARTING DEEP-DIVE TESTING FOR ALL INDIAN CARRIERS');
  console.log('================================================================\n');

  const rlToken = await getReloadlyToken();

  // Define the target telecom definitions
  const telecoms = [
    {
      key: 'JIO',
      canonicalName: 'Reliance Jio',
      slug: 'jio-in',
      networkType: 'MNO (Market Leader / 4G-5G Only)',
      ussd: '*333# (Balance), *199# (Main Menu)',
      customerCare: '198 / 199 / +919888898888',
      testPhone: '919800000101',
      providers: {
        dtone: { operatorId: 1850, operatorName: 'Reliance Jio' },
        reloadly: { operatorId: 775, name: 'Jio India' },
        zendit: { brand: 'Jio' },
        ding: { providerCode: 'RJIN', name: 'Reliance Jio India' }
      }
    },
    {
      key: 'AIRTEL',
      canonicalName: 'Bharti Airtel',
      slug: 'airtel-in',
      networkType: 'MNO (National)',
      ussd: '*121# / *123# (Balance)',
      customerCare: '121 / 198 / +919810198101',
      testPhone: '919810000101',
      providers: {
        dtone: { operatorId: 1371, operatorName: 'Airtel India' },
        reloadly: { operatorId: 200, name: 'Airtel India' },
        zendit: { brand: 'Airtel' },
        ding: { providerCode: 'AIIN', name: 'Airtel India' }
      }
    },
    {
      key: 'VI',
      canonicalName: 'Vodafone Idea (Vi)',
      slug: 'vi-in',
      networkType: 'MNO (National)',
      ussd: '*199# (Balance / Menu)',
      customerCare: '199 / 198 / +919820098200',
      testPhone: '919820000101',
      providers: {
        dtone: { operatorId: 1373, operatorName: 'Vodafone India' }, // also 1372 Idea
        reloadly: { operatorId: 716, name: 'Vodafone-Idea India' },
        zendit: { brand: 'VodafoneIdea' },
        ding: { providerCode: 'VFIN', name: 'Vodafone India' }
      }
    },
    {
      key: 'BSNL',
      canonicalName: 'BSNL',
      slug: 'bsnl-in',
      networkType: 'MNO (State-Owned National)',
      ussd: '*123# / *124# (Balance / Validity)',
      customerCare: '1503 / 1800-180-1503',
      testPhone: '919400000101',
      providers: {
        dtone: { operatorId: 1374, operatorName: 'BSNL India' },
        reloadly: { operatorId: 193, name: 'BSNL India' },
        zendit: { brand: 'BSNL' },
        ding: { providerCode: 'BLIN', name: 'BSNL India' }
      }
    },
    {
      key: 'MTNL',
      canonicalName: 'MTNL (Delhi / Mumbai)',
      slug: 'mtnl-in',
      networkType: 'MNO (State-Owned Metro: Delhi & Mumbai)',
      ussd: '*444# / *123# (Balance)',
      customerCare: '1500 / 1800-22-1500',
      testPhone: '919868000101',
      providers: {
        dtone: { operatorId: 368, operatorName: 'MTNL India' },
        reloadly: { operatorId: 194, name: 'MTNL India' },
        zendit: { brand: 'MTNL' },
        ding: { providerCode: 'MNIN', name: 'MTNL India' }
      }
    }
  ];

  const results = {};

  for (const tel of telecoms) {
    console.log(`\n================================================================`);
    console.log(`TESTING TELECOM: ${tel.canonicalName} (${tel.key})`);
    console.log(`================================================================`);
    
    results[tel.key] = {
      info: tel,
      dtone: {},
      reloadly: {},
      zendit: {},
      ding: {}
    };

    // -------------------------------------------------------------
    // 1. DT ONE
    // -------------------------------------------------------------
    console.log(`\n--- 1. DT One Testing (${tel.providers.dtone.operatorName} / ID: ${tel.providers.dtone.operatorId}) ---`);
    try {
      const pRes = await fetch(`${dtoneBaseUrl}/products?operator_id=${tel.providers.dtone.operatorId}&per_page=100`, {
        headers: { Authorization: dtoneAuthHeader }
      });
      const prods = await pRes.json();
      results[tel.key].dtone.productsCount = prods.length;
      console.log(`DT One Products Count: ${prods.length}`);
      
      // Separate airtime and data/bundles
      const airtime = prods.filter(p => p.type.includes('FIXED') || p.type.includes('RANGED'));
      console.log(`DT One Samples:`);
      const sampleList = prods.slice(0, 8).map(p => ({
        id: p.id,
        name: p.name,
        type: p.type,
        destAmount: p.destination?.amount,
        destUnit: p.destination?.unit,
        wholesaleOMR: p.prices?.wholesale?.amount,
        wholesaleUnit: p.prices?.wholesale?.unit,
        validity: p.validity
      }));
      console.log(sampleList);
      results[tel.key].dtone.samples = sampleList;
      results[tel.key].dtone.allProducts = prods.map(p => ({
        id: p.id,
        name: p.name,
        type: p.type,
        destAmount: p.destination?.amount,
        destUnit: p.destination?.unit,
        wholesaleOMR: p.prices?.wholesale?.amount,
        wholesaleUnit: p.prices?.wholesale?.unit,
        validity: p.validity
      }));

      // Execute Test Purchase Simulation on DT One
      if (prods.length > 0) {
        const testProd = prods[0];
        console.log(`Attempting DT One Pre-Prod Transaction with Product ${testProd.id} (${testProd.name})...`);
        const txPayload = {
          external_id: `test_in_${tel.key.toLowerCase()}_${Date.now()}`,
          product_id: testProd.id,
          recipient: {
            account: tel.testPhone
          }
        };
        const txRes = await fetch(`${dtoneBaseUrl}/async/transactions`, {
          method: 'POST',
          headers: {
            Authorization: dtoneAuthHeader,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify(txPayload)
        });
        const txData = await txRes.json();
        console.log(`DT One Test Transaction Status: ${txRes.status}`, txData);
        results[tel.key].dtone.testTx = {
          httpStatus: txRes.status,
          response: txData,
          productId: testProd.id,
          productName: testProd.name
        };
      }
    } catch (err) {
      console.error(`DT One Error for ${tel.key}:`, err.message);
      results[tel.key].dtone.error = err.message;
    }

    // -------------------------------------------------------------
    // 2. RELOADLY
    // -------------------------------------------------------------
    console.log(`\n--- 2. Reloadly Testing (${tel.providers.reloadly.name} / ID: ${tel.providers.reloadly.operatorId}) ---`);
    try {
      const opRes = await fetch(`${reloadlyBaseUrl}/operators/${tel.providers.reloadly.operatorId}`, {
        headers: {
          Authorization: `Bearer ${rlToken}`,
          Accept: 'application/com.reloadly.topups-v1+json'
        }
      });
      const opData = await opRes.json();
      console.log(`Reloadly Operator Details: ID=${opData.operatorId}, Name="${opData.name}", Denom=${opData.denominationType}`);
      console.log(`Range: ${opData.minAmount}-${opData.maxAmount} ${opData.senderCurrencyCode} (Local: ${opData.localMinAmount}-${opData.localMaxAmount} ${opData.destinationCurrencyCode})`);
      console.log(`Fixed Amounts:`, opData.fixedAmounts);
      console.log(`Discount: ${opData.internationalDiscount}%`);
      results[tel.key].reloadly.operator = opData;

      // Execute Test Purchase Simulation on Reloadly
      const topupPayload = {
        recipientPhone: {
          countryCode: 'IN',
          number: tel.testPhone
        },
        operatorId: tel.providers.reloadly.operatorId,
        amount: opData.denominationType === 'RANGE' ? (opData.minAmount || 1) : (opData.fixedAmounts?.[0] || 1),
        useLocalAmount: false
      };
      console.log(`Attempting Reloadly Sandbox Topup...`, topupPayload);
      const topupRes = await fetch(`${reloadlyBaseUrl}/topups`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${rlToken}`,
          Accept: 'application/com.reloadly.topups-v1+json',
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(topupPayload)
      });
      const topupData = await topupRes.json();
      console.log(`Reloadly Test Topup Status: ${topupRes.status}`, topupData);
      results[tel.key].reloadly.testTx = {
        httpStatus: topupRes.status,
        response: topupData
      };
    } catch (err) {
      console.error(`Reloadly Error for ${tel.key}:`, err.message);
      results[tel.key].reloadly.error = err.message;
    }

    // -------------------------------------------------------------
    // 3. ZENDIT
    // -------------------------------------------------------------
    console.log(`\n--- 3. Zendit Testing (Brand: ${tel.providers.zendit.brand}) ---`);
    try {
      const zRes = await fetch(`${zenditBaseUrl}/topups/offers?country=IN&brand=${tel.providers.zendit.brand}&_limit=100`, {
        headers: { Authorization: `Bearer ${zenditApiSecret}` }
      });
      const zData = await zRes.json();
      const offers = zData.list || [];
      console.log(`Zendit Offers Count for ${tel.providers.zendit.brand}: ${offers.length}`);
      results[tel.key].zendit.offersCount = offers.length;
      results[tel.key].zendit.offers = offers.map(o => ({
        offerId: o.offerId,
        name: o.name,
        priceType: o.priceType,
        costUSD: (o.cost?.fixed || 0) / (o.cost?.currencyDivisor || 100),
        priceUSD: (o.price?.fixed || 0) / (o.price?.currencyDivisor || 100),
        sendAmountINR: (o.send?.fixed || 0) / (o.send?.currencyDivisor || 100),
        sendRangeINR: o.priceType === 'RANGE' ? `${(o.send?.min||0)/100} - ${(o.send?.max||0)/100}` : null
      }));
      console.log(`Zendit Sample Offers:`, results[tel.key].zendit.offers.slice(0, 5));

      // Execute Test Purchase on Zendit
      if (offers.length > 0) {
        const testOffer = offers[0];
        console.log(`Attempting Zendit Test Purchase with Offer ${testOffer.offerId}...`);
        const pPayload = {
          transactionId: `test_in_zen_${tel.key.toLowerCase()}_${Date.now()}`,
          recipientPhoneNumber: `+${tel.testPhone}`,
          offerId: testOffer.offerId
        };
        if (testOffer.priceType === 'RANGE') {
          pPayload.value = {
            type: 'SEND',
            value: testOffer.send?.min || 1000
          };
        }
        const pRes = await fetch(`${zenditBaseUrl}/topups/purchases`, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${zenditApiSecret}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify(pPayload)
        });
        const pData = await pRes.json();
        console.log(`Zendit Test Purchase Status: ${pRes.status}`, pData);
        results[tel.key].zendit.testTx = {
          httpStatus: pRes.status,
          response: pData,
          offerId: testOffer.offerId
        };
      }
    } catch (err) {
      console.error(`Zendit Error for ${tel.key}:`, err.message);
      results[tel.key].zendit.error = err.message;
    }

    // -------------------------------------------------------------
    // 4. DINGCONNECT
    // -------------------------------------------------------------
    console.log(`\n--- 4. DingConnect Testing (Provider: ${tel.providers.ding.providerCode}) ---`);
    try {
      const dRes = await fetch(`${dingBaseUrl}/GetProducts?providerCodes=${tel.providers.ding.providerCode}&countryIsos=IN`, {
        headers: { api_key: dingApiKey }
      });
      const dData = await dRes.json();
      console.log(`Ding ResultCode: ${dData.ResultCode}, Products: ${dData.Items?.length || 0}`);
      results[tel.key].ding.resultCode = dData.ResultCode;
      results[tel.key].ding.productsCount = dData.Items?.length || 0;
      results[tel.key].ding.items = dData.Items || [];

      if (dData.Items && dData.Items.length > 0) {
        const testSku = dData.Items[0];
        console.log(`Attempting DingConnect UAT Dry-Run with SKU ${testSku.SkuCode}...`);
        const dryRunPayload = {
          SkuCode: testSku.SkuCode,
          SendValue: testSku.Minimum.SendValue,
          SendCurrencyIso: testSku.Minimum.SendCurrencyIso,
          AccountNumber: testSku.UatNumber || tel.testPhone,
          DistributorRef: `test_in_ding_${tel.key.toLowerCase()}_${Date.now()}`,
          ValidateOnly: true
        };
        const trRes = await fetch(`${dingBaseUrl}/SendTransfer`, {
          method: 'POST',
          headers: {
            api_key: dingApiKey,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify(dryRunPayload)
        });
        const trData = await trRes.json();
        console.log(`DingConnect Dry-Run Status: ${trRes.status}`, trData);
        results[tel.key].ding.dryRun = {
          httpStatus: trRes.status,
          response: trData
        };
      }
    } catch (err) {
      console.error(`Ding Error for ${tel.key}:`, err.message);
      results[tel.key].ding.error = err.message;
    }
  }

  // Save all test results
  fs.writeFileSync(path.join(__dirname, 'in_telecoms_test_results.json'), JSON.stringify(results, null, 2));
  console.log('\n================================================================');
  console.log('ALL TESTS FINISHED. Saved to in_telecoms_test_results.json');
  console.log('================================================================');
}

main().catch(console.error);
