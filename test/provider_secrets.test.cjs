const { test } = require('node:test');
const assert = require('node:assert/strict');
const { loadEdge, builder } = require('./edge_module_loader.cjs');
const helper = 'supabase/functions/_shared/provider-secrets.ts';
const env = { SUPABASE_URL: 'https://example.invalid', SUPABASE_SERVICE_ROLE_KEY: 'fixture-service' };
const secret = 'fixture-private-replacement';

function fixture(slug, { secrets = {}, extraEnv = {}, tableData = {}, rpcData = {}, vaultError = false, providerFetch } = {}) {
  let handler; const writes = [], network = [], reads = [];
  const client = {
    auth: { getUser: async () => ({ data: { user: { id: 'fixture-user' } }, error: null }) },
    rpc: async (name, args) => {
      if (name === 'get_internal_secret') {
        reads.push(args.p_name);
        return { data: secrets[args.p_name] ?? null, error: vaultError ? { message: secret } : null };
      }
      if (name === 'quote_line_verification') return { data: { phone_number: '+15555550101', sms_verify_cost_usd: 1, call_verify_cost_usd: 1, wallet_available_usd: 10 }, error: null };
      if (name === 'consume_rate_limit') return { data: true, error: null };
      if (name === 'begin_line_verification') {
        writes.push(name);
        return {data: rpcData[name] ?? {dispatch:true,attempt:{id:'fixture-attempt',method:args.p_method,
          destination_phone:'+15555550101',status:'dispatching',outcome:'pending',settlement_status:'reserved'}},error:null};
      }
      if (name === 'bind_line_verification_resource' || name === 'settle_line_verification_event') {
        writes.push(name); return {data:{success:true},error:null};
      }
      writes.push(name); return { data: rpcData[name] ?? 'fixture-id', error: null };
    },
    from: (table) => builder((filters, operations) => {
      if (operations.insert || operations.update) writes.push(table);
      const data = tableData[table] ?? null;
      return { data: typeof data === 'function' ? data(filters, operations) : data, error: null };
    }),
  };
  loadEdge(`supabase/functions/${slug}/index.ts`, {
    env: { ...env, ...extraEnv }, createClient: () => client,
    serve: (fn) => { handler = fn; },
    fetch: async (...args) => {
      if (String(args[0]).endsWith('/rpc/get_internal_secret')) {
        const name = JSON.parse(args[1].body).p_name; reads.push(name);
        return new Response(JSON.stringify(secrets[name] ?? null), { status: vaultError ? 500 : 200 });
      }
      if (String(args[0]).includes('/rest/v1/system_configs?')) {
        reads.push('public verification key'); return new Response('[]', { status: 200 });
      }
      network.push(args); if (providerFetch) return providerFetch(...args); throw Error('Unexpected provider request');
    },
  });
  return { handler, writes, network, reads };
}
function request(body, contentType = 'application/json') {
  return new Request('https://example.invalid/functions/v1/test', { method: 'POST',
    headers: { authorization: 'Bearer fixture-user', 'content-type': contentType },
    body: contentType.includes('json') ? JSON.stringify(body) : body });
}

test('Vault replacement takes precedence over a stale environment value on each read', async () => {
  const h = loadEdge(helper, { env: { TELNYX_API_KEY: 'fixture-stale' } });
  let current = secret;
  const client = { rpc: async () => ({ data: current, error: null }) };
  assert.equal(await h.requireProviderSecret(client, 'TELNYX_API_KEY'), secret);
  current = 'fixture-newer';
  assert.equal(await h.requireProviderSecret(client, 'TELNYX_API_KEY'), current);
});

test('null Vault permits explicit environment/alias configuration; empty placeholders do not', async () => {
  const h = loadEdge(helper, { env: { ZENDIT_API_KEY: secret, TELNYX_API_KEY: '<TELNYX_API_KEY>' } });
  const client = { rpc: async () => ({ data: null, error: null }) };
  assert.equal(await h.requireProviderSecret(client, 'ZENDIT_API_SECRET', ['ZENDIT_API_KEY']), secret);
  await assert.rejects(h.requireProviderSecret(client, 'TELNYX_API_KEY'), { code: 'PROVIDER_NOT_CONFIGURED' });
});

test('Vault errors never resurrect stale environment credentials or echo storage errors', async () => {
  const h = loadEdge(helper, { env: { TELNYX_API_KEY: secret } });
  for (const client of [
    { rpc: async () => ({ data: null, error: { message: secret } }) },
    { rpc: async () => { throw Error(secret); } },
  ]) await assert.rejects(h.requireProviderSecret(client, 'TELNYX_API_KEY'), e => e.code === 'PROVIDER_NOT_CONFIGURED' && !e.message.includes(secret));
});

for (const method of ['sms', 'voice']) test(`liveness ${method}: missing secret causes no reservation, attempt or provider action`, async () => {
  const f = fixture('liveness-verification');
  const response = await f.handler(request({ action: 'start', simLineId: 'fixture-line', idempotencyKey: 'fixture-key', method }));
  assert.equal(response.status, 503); assert.deepEqual(f.writes, []); assert.deepEqual(f.network, []);
  assert.equal((await response.json()).code, 'PROVIDER_NOT_CONFIGURED');
});

test('liveness non-secret gateway configuration is also required before reservation', async () => {
  const f = fixture('liveness-verification', { secrets: { TELNYX_API_KEY: secret } });
  const response = await f.handler(request({ action: 'start', simLineId: 'fixture-line', idempotencyKey: 'fixture-key', method: 'voice' }));
  assert.equal(response.status, 503); assert.deepEqual(f.writes, []); assert.deepEqual(f.network, []);
});

for (const type of ['twilio', 'telnyx']) test(`${type} callback: missing configuration cannot settle an attempt`, async () => {
  const f = fixture('liveness-verification-webhook', { tableData: { line_verification_attempts: { id: 'fixture-attempt', status: 'pending' } } });
  const req = type === 'twilio' ? request('CallSid=fixture-call&CallStatus=ringing', 'application/x-www-form-urlencoded')
    : request({ data: { event_type: 'message.finalized', payload: { id: 'fixture-message', to: [{ status: 'delivered' }] } } });
  const response = await f.handler(req);
  assert.equal(response.status, 503); assert.deepEqual(f.writes, []); assert.deepEqual(f.network, []);
});

test('liveness lookup without any provider credentials returns configuration error, not active format fallback', async () => {
  const f = fixture('validate-sim-liveness');
  const response = await f.handler(request({ phoneNumber: '+96879000000', countryCode: 'OM' }));
  assert.equal(response.status, 503); assert.equal((await response.json()).reason, 'PROVIDER_NOT_CONFIGURED');
  assert.deepEqual(f.writes, []); assert.deepEqual(f.network, []);
});

test('partial DT One credentials never reach providers', async () => {
  const f = fixture('validate-sim-liveness', { secrets: { DTONE_API_KEY: secret } });
  const response = await f.handler(request({ phoneNumber: '+15555550101' }));
  assert.equal(response.status, 503); assert.deepEqual(f.network, []);
});

test('Firsty defaults disabled even when credentials have been stored', async () => {
  const f = fixture('recovery-service', { secrets: { FIRSTY_CLIENT_ID: 'fixture-client', FIRSTY_CLIENT_SECRET: secret } });
  const response = await f.handler(request({ action: 'prepare_profile' }));
  assert.equal(response.status, 403); assert.deepEqual(f.writes, []); assert.deepEqual(f.network, []); assert.deepEqual(f.reads, []);
});

test('explicit Firsty sandbox without credentials fails before provider or profile writes', async () => {
  const f = fixture('recovery-service', { extraEnv: { FIRSTY_PROVIDER_MODE: 'firsty_sandbox' } });
  const response = await f.handler(request({ action: 'prepare_profile' }));
  assert.equal(response.status, 503); assert.deepEqual(f.writes, []); assert.deepEqual(f.network, []);
});

test('Vault failures produce sanitized endpoint responses and no provider actions', async () => {
  const f = fixture('liveness-verification', { vaultError: true, extraEnv: { TELNYX_API_KEY: secret } });
  const response = await f.handler(request({ action: 'start', simLineId: 'fixture-line', idempotencyKey: 'fixture-key', method: 'sms' }));
  assert.equal(response.status, 503); assert.ok(!(await response.text()).includes(secret));
  assert.deepEqual(f.writes, []); assert.deepEqual(f.network, []);
});

for (const method of ['sms', 'voice']) test(`configured liveness ${method} dispatches using Vault and preserves existing attempt contract`, async () => {
  const f = fixture('liveness-verification', {
    secrets: { TELNYX_API_KEY: secret },
    extraEnv: { TELNYX_API_KEY: 'fixture-stale', TELNYX_CALL_CONTROL_APP_ID: 'fixture-app', TELNYX_DEFAULT_CALLER_ID: '+15555550100', TELNYX_MESSAGING_PROFILE_ID: 'fixture-profile' },
    providerFetch: async (url, options) => {
      assert.equal(options.headers.Authorization, `Bearer ${secret}`);
      return Response.json({ data: { id: 'fixture-message', call_control_id: 'fixture-call' } });
    },
  });
  const response = await f.handler(request({ action: 'start', simLineId: 'fixture-line', idempotencyKey: 'fixture-key', method }));
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.status, 'pending'); assert.ok(!JSON.stringify(body).includes(secret));
  assert.deepEqual(f.writes, ['begin_line_verification', 'bind_line_verification_resource']);
  assert.equal(f.network.length, 1);
});

test('explicit Firsty sandbox provider failure never creates a synthetic profile', async () => {
  const f = fixture('recovery-service', {
    secrets: { FIRSTY_CLIENT_ID: 'fixture-client', FIRSTY_CLIENT_SECRET: secret },
    extraEnv: { FIRSTY_PROVIDER_MODE: 'firsty_sandbox' },
    providerFetch: async () => new Response(secret, { status: 401 }),
  });
  const response = await f.handler(request({ action: 'prepare_profile' }));
  assert.equal(response.status, 500); assert.deepEqual(f.writes, []);
  assert.equal(f.network.length, 1); assert.ok(!(await response.text()).includes(secret));
});

test('explicit mock recovery needs no provider credentials and makes no provider request', async () => {
  const f = fixture('recovery-service', { extraEnv: { FIRSTY_PROVIDER_MODE: 'mock' } });
  const response = await f.handler(request({ action: 'prepare_profile' }));
  assert.equal(response.status, 200); assert.deepEqual(f.writes, ['recovery_esim_profiles']);
  assert.deepEqual(f.network, []); assert.deepEqual(f.reads, []);
});

test('numbering-plan and allocation-only lookups remain pending rather than asserting subscriber liveness',async()=>{
 const f=fixture('validate-sim-liveness',{secrets:{TELNYX_API_KEY:secret},providerFetch:async()=>Response.json({data:{valid_number:true,carrier:{name:'Fixture'}}})});
 const result=await f.handler(request({phoneNumber:'+96879000000',countryCode:'OM'}));
 assert.equal(result.status,200);const body=await result.json();assert.equal(body.is_active,false);assert.equal(body.carrier_status,'pending');assert.equal(body.reason,'FORMAT_ONLY');
});
