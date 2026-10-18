const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createHmac } = require('node:crypto');
const { loadEdge, builder } = require('./edge_module_loader.cjs');

// Execute real handlers; every DB/provider request is intercepted locally.
function fixture(name, initial = {}, extraEnv = {}) {
  const secrets = { ...initial }, calls = [], authorizations = [];
  let handler, vaultUnavailable = false;
  const env = { SUPABASE_URL: 'https://db.test', SUPABASE_SERVICE_ROLE_KEY: 'fixture-service',
    PAYPAL_WEBHOOK_ID: 'fixture-webhook', PAYPAL_CLIENT_ID: 'fixture-stale-client',
    PAYPAL_CLIENT_SECRET: 'fixture-stale-secret', TWILIO_AUTH_TOKEN: 'fixture-stale-token',
    TELNYX_API_KEY: 'fixture-stale-telnyx', ...extraEnv };
  loadEdge(`supabase/functions/${name}/index.ts`, {
    env, serve: (value) => { handler = value; },
    fetch: async (url, options = {}) => {
      const path = new URL(url).pathname; calls.push(path);
      if (path.endsWith('/rpc/get_internal_secret')) {
        if (vaultUnavailable) return Response.json({ message: 'fixture-private-storage-error' }, { status: 500 });
        return Response.json(secrets[JSON.parse(options.body).p_name] ?? null);
      }
      if (path.endsWith('/auth/v1/user')) return Response.json({ id: 'fixture-user' });
      if (path.endsWith('/rpc/consume_rate_limit')) return Response.json([{ allowed: true }]);
      if (path.endsWith('/rpc/handle_inbound_command') || path.endsWith('/rpc/ingest_offline_refill')) return Response.json({});
      if (path.endsWith('/v1/oauth2/token')) {
        authorizations.push(options.headers.Authorization ?? options.headers.authorization);
        return Response.json({ access_token: 'fixture-ephemeral-access' });
      }
      if (path.endsWith('/v1/notifications/verify-webhook-signature')) return Response.json({ verification_status: 'SUCCESS' });
      if (path.endsWith('/profiles')) return Response.json([{ subscription_tier: 'premium' }]);
      if (path.endsWith('/second_number_policies')) return Response.json([{country_code:'US',country_name:'United States',number_type:'local',minimum_monthly_usd:4,usage_terms:'Approved receive-only pilot terms',terms_version:'pilot',kyc_status:'not_required'}]);
      if (path.endsWith('/app_fee_rules')) return Response.json([{free_percentage:15,stand_percentage:7,prem_percentage:3}]);
      if (path.endsWith('/sim_lines')) return Response.json([]);
      if (path.endsWith('/rpc/route_second_number_sms')) return Response.json({route:'refill'});
      if (path.endsWith('/v2/available_phone_numbers')) {
        authorizations.push(options.headers.Authorization);
        return Response.json({ data: [] });
      }
      throw Error(`Unexpected isolated request: ${path}`);
    },
  });
  return { handler, secrets, calls, authorizations, outage: () => { vaultUnavailable = true; } };
}

const request = (name, body, headers = {}) => new Request(`https://edge.test/functions/v1/${name}`, {
  method: 'POST', headers: { 'content-type': 'application/json', authorization: 'Bearer fixture-user', ...headers },
  body: JSON.stringify(body),
});

test('PayPal callback adopts the Vault replacement on every request without a process reload', async () => {
  const f = fixture('paypal-webhook', { PAYPAL_CLIENT_ID: 'fixture-client', PAYPAL_CLIENT_SECRET: 'fixture-current' });
  const run = () => f.handler(request('paypal-webhook', { event_type: 'fixture.ignored' }, {
    'paypal-transmission-id': 'fixture-transmission', 'paypal-transmission-sig': 'fixture-signature',
    'paypal-cert-url': 'https://provider.test/cert',
  }));
  assert.equal((await run()).status, 200);
  f.secrets.PAYPAL_CLIENT_SECRET = 'fixture-replacement';
  assert.equal((await run()).status, 200);
  assert.deepEqual(f.authorizations, [
    `Basic ${btoa('fixture-client:fixture-current')}`, `Basic ${btoa('fixture-client:fixture-replacement')}`,
  ]);
});

test('a Vault outage stops PayPal before OAuth or fulfillment despite a stale environment value', async () => {
  const f = fixture('paypal-webhook'); f.outage();
  const response = await f.handler(request('paypal-webhook', { event_type: 'fixture.ignored' }, {
    'paypal-transmission-id': 'fixture-transmission', 'paypal-transmission-sig': 'fixture-signature',
    'paypal-cert-url': 'https://provider.test/cert',
  }));
  assert.equal(response.status, 503); assert.equal((await response.json()).code, 'PROVIDER_NOT_CONFIGURED');
  assert.equal(f.authorizations.length, 0);
  assert(!f.calls.some(path => /credit_wallet|plan_payments/.test(path)));
});

test('DID search uses the admin Vault value instead of legacy Telnyx configuration', async () => {
  const f = fixture('manage-dids', { TELNYX_API_KEY: 'fixture-current-telnyx' });
  const response = await f.handler(request('manage-dids', { action: 'search_available_numbers', country_code: 'US' }));
  assert.equal(response.status, 200);
  assert.deepEqual(f.authorizations, ['Bearer fixture-current-telnyx']);
  assert(!f.calls.some(path => path.endsWith('/system_configs')));
});

test('DID integration fails safely when Vault is unavailable', async () => {
  const f = fixture('manage-dids'); f.outage();
  const response = await f.handler(request('manage-dids', { action: 'search_available_numbers', country_code:'US' }));
  assert.equal(response.status, 503); assert.equal(f.authorizations.length, 0);
  assert(!f.calls.some(path => /number_orders|debit_wallet/.test(path)));
});

for (const name of ['sms-webhook', 'twilio-voice-webhook']) {
  const ingestion = name === 'sms-webhook' ? '/rpc/handle_inbound_command' : '/rpc/ingest_offline_refill';
  const params = name === 'sms-webhook'
    ? { To: '+12025550123', From: '+15555550101', MessageSid: 'fixture-message', Body: 'BALANCE' }
    : { From: '+15555550101', CallSid: 'fixture-call' };
  const url = `https://edge.test/functions/v1/${name}`;
  const signature = (token) => createHmac('sha1', token)
    .update(url + Object.keys(params).sort().map(key => key + params[key]).join('')).digest('base64');
  const callback = (token) => new Request(url, { method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded', 'x-twilio-signature': signature(token) },
    body: new URLSearchParams(params) });

  test(`${name} verifies with the current Vault token and rejects a replaced token`, async () => {
    const f = fixture(name, { TWILIO_AUTH_TOKEN: 'fixture-current-token' }, { PUBLIC_FUNCTION_URL: url });
    await f.handler(callback('fixture-current-token'));
    assert.equal(f.calls.filter(path => path.endsWith(ingestion)).length, 1);
    f.secrets.TWILIO_AUTH_TOKEN = 'fixture-replacement-token';
    await f.handler(callback('fixture-current-token'));
    assert.equal(f.calls.filter(path => path.endsWith(ingestion)).length, 1);
    await f.handler(callback('fixture-replacement-token'));
    assert.equal(f.calls.filter(path => path.endsWith(ingestion)).length, 2);
  });

  test(`${name} does not ingest a callback when credential storage fails`, async () => {
    const f = fixture(name); f.outage();
    const response = await f.handler(callback('fixture-stale-token'));
    assert.equal(response.status, 503);
    assert(!f.calls.some(path => path.endsWith(ingestion)));
    assert(!(await response.text()).includes('fixture-private-storage-error'));
  });
}

test('the canonical Zendit Vault replacement overrides the legacy lower-case Vault alias', async () => {
  const helper = loadEdge('supabase/functions/_shared/provider-secrets.ts');
  const secrets = { zendit_api_key: 'fixture-legacy-zendit' };
  const client = { rpc: async (_, args) => ({ data: secrets[args.p_name] ?? null, error: null }) };
  assert.equal(await helper.requireProviderSecret(client, 'ZENDIT_API_SECRET'), 'fixture-legacy-zendit');
  secrets.ZENDIT_API_SECRET = 'fixture-new-zendit';
  assert.equal(await helper.requireProviderSecret(client, 'ZENDIT_API_SECRET'), 'fixture-new-zendit');
});

test('a targeted Zendit eSIM sync runs independently of eSIM Go and uses the canonical Vault key', async () => {
  let handler; const updates = [], requests = [];
  const client = {
    rpc: async (_, args) => ({ data: {
      esim_catalogue_sync_secret: 'fixture-sync', ZENDIT_API_SECRET: 'fixture-managed-zendit',
      zendit_api_key: 'fixture-obsolete-zendit',
    }[args.p_name] ?? null, error: null }),
    from: table => builder((filters, operations) => {
      if (operations.update) updates.push({table, filters, value: operations.update});
      return {data: [], error: null};
    }),
  };
  loadEdge('supabase/functions/sync-esim-catalogue/index.ts', {
    env: { SUPABASE_URL: 'https://db.test', SUPABASE_SERVICE_ROLE_KEY: 'fixture-service' },
    createClient: () => client, serve: value => { handler = value; },
    fetch: async (url, options) => {
      requests.push(url); assert.equal(options.headers.Authorization, 'Bearer fixture-managed-zendit');
      return Response.json({list: [], total: 0});
    },
  });
  const response = await handler(new Request('https://edge.test?provider=zendit', {
    method: 'POST', headers: {'x-sync-secret': 'fixture-sync'},
  }));
  assert.equal(response.status, 200); assert.equal((await response.json()).results.zendit.success, true);
  assert.equal(requests.length, 1);
  assert(updates.some(row => row.filters.code === 'zendit' && row.value.last_sync_status === 'ok'));
  assert(!updates.some(row => row.filters.code === 'esim_go'));
});
