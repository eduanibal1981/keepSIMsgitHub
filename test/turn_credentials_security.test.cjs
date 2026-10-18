const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createHmac } = require('node:crypto');
const { loadEdge } = require('./edge_module_loader.cjs');

function fixture({ env = {}, secrets = {}, vaultError = false } = {}) {
  const requests = [];
  const context = {
    env: { SUPABASE_URL: 'https://db.test', SUPABASE_SERVICE_ROLE_KEY: 'test-only-service-role', ...env },
    createClient: () => ({
      auth: { getUser: async () => ({ data: { user: { id: 'caller' } } }) },
      rpc: async (name, args) => name === 'get_internal_secret'
        ? { data: secrets[args.p_name] ?? null, error: vaultError ? { message: 'private diagnostic' } : null }
        : { data: null, error: null },
    }),
    fetch: async (url, options = {}) => {
      requests.push({ url, method: options.method || 'GET' });
      if (url.endsWith('/auth/v1/user')) return Response.json({ id: 'caller' });
      if (url.includes('/voip_call_sessions?')) {
        return Response.json([{ id: 'call-1', caller_id: 'caller', callee_id: 'callee' }]);
      }
      throw Error('Unexpected external request in isolated test');
    },
  };
  function handler(name) {
    let callback;
    loadEdge(`supabase/functions/${name}/index.ts`, {
      ...context,
      serve: (value) => { callback = value; },
    });
    return callback;
  }
  return { context, requests, handler };
}

test('missing TURN configuration returns controlled 503 and never creates a call', async () => {
  const f = fixture();
  const response = await f.handler('initiate-voip-call')(new Request('https://edge.test', {
    method: 'POST', headers: { Authorization: 'Bearer test-only-token' },
    body: JSON.stringify({ callee_id: 'callee' }),
  }));
  assert.equal(response.status, 503);
  assert.equal((await response.json()).code, 'PROVIDER_NOT_CONFIGURED');
  assert.equal(f.requests.some((request) => request.method === 'POST'), false);
  assert.equal(f.requests.some((request) => request.url.includes('/rest/')), false);
});

test('call participants cannot fall back to public TURN when credentials are absent', async () => {
  const f = fixture();
  const response = await f.handler('get-turn-credentials')(new Request('https://edge.test', {
    method: 'POST', headers: { Authorization: 'Bearer test-only-token' },
    body: JSON.stringify({ call_id: 'call-1' }),
  }));
  assert.equal(response.status, 503);
  const result = await response.json();
  assert.equal(result.code, 'PROVIDER_NOT_CONFIGURED');
  assert.equal(result.ice_servers, undefined);
});

test('Vault TURN replacements immediately override stale environment credentials', async () => {
  const f = fixture({
    env: { TURN_SHARED_SECRET: 'test-only-stale-key' },
    secrets: { TURN_SHARED_SECRET: 'test-only-replacement-key' },
  });
  const { generateIceServers } = loadEdge('supabase/functions/_shared/turn-credentials.ts', f.context);
  const result = await generateIceServers(f.context.createClient(), 'caller');
  const relay = result.iceServers.find((server) => server.username);
  assert.equal(result.hasTurn, true);
  assert.match(relay.username, /^\d+:caller$/);
  assert.equal(relay.credential,
    createHmac('sha1', 'test-only-replacement-key').update(relay.username).digest('base64'));
  assert.notEqual(relay.credential, 'test-only-replacement-key');
});

test('a Vault outage never silently restores stale environment TURN credentials', async () => {
  const f = fixture({ vaultError: true, env: { TURN_SHARED_SECRET: 'test-only-stale-key' } });
  const { generateIceServers } = loadEdge('supabase/functions/_shared/turn-credentials.ts', f.context);
  await assert.rejects(generateIceServers(f.context.createClient(), 'caller'), { code: 'PROVIDER_NOT_CONFIGURED' });
});

test('legacy Coturn environment alias works only when no Vault secret exists', async () => {
  const f = fixture({ env: { COTURN_SHARED_SECRET: 'test-only-legacy-key', COTURN_HOST: 'relay.test' } });
  const { generateIceServers } = loadEdge('supabase/functions/_shared/turn-credentials.ts', f.context);
  const result = await generateIceServers(f.context.createClient(), 'caller');
  assert.match(result.iceServers[1].urls[0], /^turn:relay\.test:/);
});

test('static TURN requires provisioned URLs, username and credential together', async () => {
  const f = fixture({
    env: { TURN_URLS: 'turn:relay.test:3478,turns:relay.test:443' },
    secrets: { TURN_USERNAME: 'test-only-user', TURN_CREDENTIAL: 'test-only-password' },
  });
  const { generateIceServers } = loadEdge('supabase/functions/_shared/turn-credentials.ts', f.context);
  const result = await generateIceServers(f.context.createClient(), 'caller');
  assert.equal(result.iceServers[1].username, 'test-only-user');
  assert.equal(result.iceServers[1].urls.length, 2);
  f.context.env.TURN_URLS = 'https://not-a-relay.test';
  await assert.rejects(generateIceServers(f.context.createClient(), 'caller'), { code: 'PROVIDER_NOT_CONFIGURED' });
});

for (const name of ['send-sim-otp', 'verify-sim-otp']) {
  test(`${name} fails before provider access when Telnyx credentials are missing`, async () => {
    const f = fixture({ env: { TELNYX_VERIFY_PROFILE_ID: 'test-only-profile' } });
    const response = await f.handler(name)(new Request('https://edge.test', {
      method: 'POST', body: JSON.stringify({ phoneNumber: '+12025550123', code: '000000' }),
    }));
    assert.equal(response.status, 503);
    assert.equal((await response.json()).code, 'PROVIDER_NOT_CONFIGURED');
    assert.equal(f.requests.length, 0);
  });
  test(`${name} requires the matching provisioned Telnyx verification profile`, async () => {
    const f = fixture({ secrets: { TELNYX_API_KEY: 'test-only-provider-key' } });
    const response = await f.handler(name)(new Request('https://edge.test', {
      method: 'POST', body: JSON.stringify({ phoneNumber: '+12025550123', code: '000000' }),
    }));
    assert.equal(response.status, 503);
    assert.equal((await response.json()).code, 'PROVIDER_NOT_CONFIGURED');
    assert.equal(f.requests.length, 0);
  });
}
