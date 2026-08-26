const fs = require('fs');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: '/home/abdal/keepsims_backend/servers/.env' });

const env = process.env;

const supabaseUrl = env.SUPABASE_URL;
const supabaseKey = env.SUPABASE_SERVICE_ROLE_KEY;
const supabase = supabaseUrl && supabaseKey ? createClient(supabaseUrl, supabaseKey) : null;

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

const rawResults = {};

async function discoverDatabase() {
  if (!supabase) return;
  const { data: countries } = await supabase.from('countries').select('*').or('iso_code.eq.PK,iso3.eq.PAK');
  rawResults.country = countries;
  if (countries?.length > 0) {
    const { data: carriers } = await supabase.from('carriers').select('*').eq('country_id', countries[0].id);
    rawResults.carriers = carriers;
    const carrierIds = (carriers || []).map(c => c.id);
    if (carrierIds.length > 0) {
      const { data: map } = await supabase.from('carrier_provider_map').select('*').in('carrier_id', carrierIds);
      rawResults.carrier_provider_map = map;
      const { data: rules } = await supabase.from('carrier_rules').select('*').in('carrier_id', carrierIds);
      rawResults.carrier_rules = rules;
    }
  }
}

async function discoverDTOne() {
  if (!dtoneApiKey || !dtoneApiSecret) return;
  const authHeader = 'Basic ' + Buffer.from(`${dtoneApiKey}:${dtoneApiSecret}`).toString('base64');
  try {
    const opRes = await fetch(`${dtoneBaseUrl}/operators?country_iso_code=PAK&per_page=100`, {
      headers: { Authorization: authHeader }
    });
    rawResults.dtone_operators = await opRes.json();
  } catch (err) {
    console.error('DT One Operators error:', err.message);
  }

  try {
    let allProducts = [];
    let page = 1;
    while (page <= 10) {
      const prodRes = await fetch(`${dtoneBaseUrl}/products?country_iso_code=PAK&page=${page}&per_page=100`, {
        headers: { Authorization: authHeader }
      });
      if (!prodRes.ok) break;
      const prods = await prodRes.json();
      if (!Array.isArray(prods) || prods.length === 0) break;
      allProducts.push(...prods);
      if (prods.length < 100) break;
      page++;
    }
    rawResults.dtone_products = allProducts;
  } catch (err) {
    console.error('DT One Products error:', err.message);
  }
}

async function discoverReloadly() {
  if (!reloadlyClientId || !reloadlyClientSecret) return;
  try {
    const token = await getReloadlyToken();
    const res = await fetch(`${reloadlyBaseUrl}/operators/countries/PK?includeBundles=true&includeData=true&includePin=true`, {
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: 'application/com.reloadly.topups-v1+json',
      }
    });
    rawResults.reloadly_operators = await res.json();
  } catch (err) {
    console.error('Reloadly Discovery error:', err.message);
  }
}

async function discoverZendit() {
  if (!zenditApiSecret) return;
  try {
    let allOffers = [];
    let offset = 0;
    let total = Infinity;
    while (offset < total && offset < 1000) {
      const url = `${zenditBaseUrl}/topups/offers?country=PK&_limit=100&_offset=${offset}`;
      const res = await fetch(url, { headers: { Authorization: `Bearer ${zenditApiSecret}` } });
      if (!res.ok) break;
      const data = await res.json();
      total = data.total || 0;
      allOffers.push(...(data.list || []));
      offset += 100;
      if (!data.list || data.list.length === 0) break;
    }
    rawResults.zendit_offers = allOffers;
  } catch (err) {
    console.error('Zendit Discovery error:', err.message);
  }
}

async function discoverDingConnect() {
  if (!dingApiKey) return;
  try {
    const res = await fetch(`${dingBaseUrl}/GetProviders?countryIsos=PK`, { headers: { api_key: dingApiKey } });
    const data = await res.json();
    rawResults.ding_providers = data;
  } catch (err) {
    console.error('Ding Providers error:', err.message);
  }
}

async function main() {
  await discoverDatabase();
  await discoverDTOne();
  await discoverReloadly();
  await discoverZendit();
  await discoverDingConnect();
  fs.writeFileSync(path.join(__dirname, 'pk_raw_discovery.json'), JSON.stringify(rawResults, null, 2));
}

main().catch(console.error);