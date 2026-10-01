// Offline defect reproductions, not acceptance tests. A passing assertion here
// confirms the reviewed defect still exists. No real database or provider calls.
// Run from the customer repository: node --test docs/reviews/notification-rereview-repros-20261001.cjs
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { stripTypeScriptTypes } = require('node:module');

function source(path) {
  return stripTypeScriptTypes(readFileSync(path, 'utf8'))
    .replace(/^import .*;\r?\n/gm, '').replace(/^export /gm, '');
}
const env = { SUPABASE_URL: 'https://database.invalid',
  SUPABASE_SERVICE_ROLE_KEY: 'mock-service-key', TELEGRAM_BOT_TOKEN: 'mock-bot',
  WABA_ACCESS_TOKEN: 'mock-meta-token' };
const deno = { env: { get: (name) => env[name] } };
const unused = () => { throw Error('Unexpected dependency'); };

function query(result, updates) {
  const q = { select: () => q, eq: () => q, neq: () => q,
    update: (row) => { updates?.push(row); return q; },
    insert: () => q, maybeSingle: async () => result, single: async () => result,
    then: (resolve, reject) => Promise.resolve(result).then(resolve, reject) };
  return q;
}

test('REPRO: Telegram HTTP 503 still completes the durable dispatch job', async () => {
  let handler;
  const deliveries = [];
  const dispatcherDb = { from: (table) => {
    if (table === 'notification_deliveries') return { insert: async (rows) => {
      deliveries.push(...rows); return { error: null }; } };
    assert.equal(table, 'notification_channels');
    return query({ data: { config: { chat_id: 'mock-chat' } }, error: null });
  } };
  new Function('serve', 'createClient', 'Deno', 'fetch', 'postOneSignal',
    'pushIdempotencyKey', 'routePushDevices', 'routeAndSendWhatsApp',
    source('supabase/functions/dispatch-alert/index.ts'))(
    (fn) => { handler = fn; }, () => dispatcherDb, deno,
    async () => new Response('{}', { status: 503 }), unused, unused, unused, unused);
  const payload = { notification_id: 'mock-notification', user_id: 'mock-user',
    category: 'system', title: 'Test', body: 'Test', channels: ['telegram'] };
  const response = await handler(new Request('https://dispatcher.invalid', {
    method: 'POST', headers: { Authorization: 'Bearer mock-service-key' },
    body: JSON.stringify(payload) }));
  const result = await response.json();
  assert.equal(deliveries[0].status, 'failed');
  assert.equal(response.status, 200);
  assert.equal(result.success, true);

  const finishes = [];
  const rows = {
    notifications: { id: payload.notification_id, user_id: payload.user_id,
      category: payload.category, sim_line_id: null },
    alert_settings: { is_enabled: true, channels: ['telegram'] },
    notification_channels: [{ channel_type: 'telegram', is_enabled: true }],
    notification_channel_catalog: [{ channel_key: 'telegram', min_tier: 'basic',
      is_globally_enabled: true }],
    profiles: { subscription_tier: 'basic' }, user_preferences: null,
  };
  const outboxDb = { from: (table) => query({ data: rows[table], error: null }),
    rpc: async (name, params) => {
      assert.equal(name, 'finish_notification_dispatch_job');
      finishes.push(params); return { data: true, error: null };
    } };
  const processJob = new Function('serve', 'createClient', 'Deno', 'fetch',
    'quietHoursReleaseTime', source('supabase/functions/process-alert-outbox/index.ts')
      + ';return processJob;')(() => {}, () => outboxDb, deno,
      async () => new Response(JSON.stringify(result), { status: response.status }), unused);
  assert.equal(await processJob({ id: 'mock-job', notification_id: payload.notification_id,
    payload, attempt_count: 1 }), 'complete');
  assert.equal(finishes[0].p_state, 'complete');
});

test('REPRO: missing Meta app secret accepts an unsigned inbound command', async () => {
  let handler;
  const commands = [];
  const db = { from: () => query({ data: { id: 'mock-meta', connection_metadata: {} } }),
    rpc: async (name, params) => {
      if (name === 'consume_rate_limit') return { data: [{ allowed: true }] };
      assert.equal(name, 'handle_inbound_command');
      commands.push(params); return { data: {} };
    } };
  new Function('serve', 'createClient', 'Deno', 'routeAndSendWhatsApp',
    source('supabase/functions/waba-webhook/index.ts'))(
    (fn) => { handler = fn; }, () => db, deno, unused);
  const response = await handler(new Request('https://webhook.invalid', {
    method: 'POST', body: JSON.stringify({ entry: [{ changes: [{ value: {
      metadata: { phone_number_id: 'mock-inbound-sender' }, messages: [{
        type: 'text', from: '201000000000', id: 'mock-message', text: { body: 'HELP' },
      }],
    } }] }] }) }));
  assert.equal(response.status, 200);
  assert.equal(commands.length, 1);
});

function loadRouter(db, fetcher) {
  return new Function('Deno', 'fetch', source('supabase/functions/_shared/whatsapp_router.ts')
    + ';return routeAndSendWhatsApp;')(deno, fetcher).bind(null, db);
}

test('REPRO: Meta inbound reply is blocked by recipient country route', async () => {
  const db = { rpc: async () => ({ data: 'mock-country' }),
    from: (table) => {
      assert.equal(table, 'whatsapp_country_routes');
      return query({ data: { route_mode: 'disabled' } });
    } };
  const outcome = await loadRouter(db, unused)({ purpose: 'offline_refill_reply',
    recipientPhone: '+201000000000', commandId: 'mock-command', bodyText: 'Help',
    replyPhoneNumberId: 'mock-inbound-meta-sender' });
  assert.equal(outcome.errorCategory, 'route_disabled');
});

test('REPRO: simultaneous failed retries both send and overwrite provider snapshot', async () => {
  const updates = [], sends = [];
  const profile = { id: 'new-meta-profile', provider_kind: 'meta_cloud', is_enabled: true,
    ready_state: 'ready', version: 2, connection_metadata: {
      phone_number_id: 'mock-meta-sender', template_mappings: {
        admin_test: { name: 'mock-approved-template', language: 'en_US' },
      },
    } };
  const db = { rpc: async () => ({ data: 'mock-country' }), from: (table) => {
    if (table === 'whatsapp_country_routes') return query({ data: {
      route_mode: 'meta_cloud', profile_id: profile.id, version: 2 } });
    if (table === 'whatsapp_provider_profiles') return query({ data: profile });
    assert.equal(table, 'whatsapp_message_attempts');
    return query({ data: { id: 'old-attempt', state: 'failed', route_mode: 'baileys',
      profile_id: 'old-baileys-profile' }, error: null }, updates);
  } };
  const router = loadRouter(db, async (url, request) => {
    sends.push({ url, body: JSON.parse(request.body) });
    return new Response(JSON.stringify({ messages: [{ id: `mock-${sends.length}` }] }));
  });
  const req = { purpose: 'admin_test', recipientPhone: '+201000000000',
    bodyText: 'Test', idempotencyKey: 'same-failed-attempt' };
  const outcomes = await Promise.all([router(req), router(req)]);
  assert.equal(sends.length, 2);
  assert.ok(outcomes.every((o) => o.success));
  assert.equal(updates.filter((u) => u.profile_id === 'new-meta-profile').length, 2);
});

test('REPRO: enabled but degraded profile with mismatched sender still dispatches', async () => {
  let sends = 0;
  const profile = { id: 'mock-profile', provider_kind: 'meta_cloud', is_enabled: true,
    ready_state: 'degraded', expected_sender_number: '+11111111111',
    observed_sender_number: '+22222222222', version: 1, connection_metadata: {
      phone_number_id: 'mock-sender', template_mappings: { admin_test: { name: 'mock-template' } },
    } };
  const db = { rpc: async () => ({ data: 'mock-country' }), from: (table) => {
    if (table === 'whatsapp_country_routes') return query({ data: {
      route_mode: 'meta_cloud', profile_id: profile.id } });
    if (table === 'whatsapp_provider_profiles') return query({ data: profile });
    assert.equal(table, 'whatsapp_message_attempts');
    const q = query({ data: null, error: null });
    q.single = async () => ({ data: { id: 'mock-attempt' }, error: null });
    return q;
  } };
  const outcome = await loadRouter(db, async () => {
    sends++; return new Response(JSON.stringify({ messages: [{ id: 'mock-message' }] }));
  })({ purpose: 'admin_test', recipientPhone: '+201000000000', bodyText: 'Test',
    idempotencyKey: 'mock-readiness-check' });
  assert.equal(sends, 1);
  assert.equal(outcome.success, true);
});

test('REPRO: verified administrator is checked using service-role RPC claims', async () => {
  let handler;
  // Mirrors the live is_power_user function: it checks the RPC caller's JWT
  // app_metadata and deliberately ignores the user_id argument.
  const create = (url, key, options) => {
    assert.equal(key, 'mock-service-key');
    assert.equal(options?.global?.headers?.Authorization, undefined);
    const rpcClaims = { role: 'service_role' };
    return { auth: { getUser: async (jwt) => {
      assert.equal(jwt, 'mock-admin-jwt');
      return { data: { user: { id: 'mock-admin', app_metadata: { is_power_user: true } } },
        error: null };
    } }, rpc: async (name) => {
      assert.equal(name, 'is_power_user');
      return { data: rpcClaims.app_metadata?.is_power_user ?? false };
    } };
  };
  new Function('serve', 'createClient', 'Deno', 'routeAndSendWhatsApp',
    source('supabase/functions/send-whatsapp-alert/index.ts'))(
    (fn) => { handler = fn; }, create, deno, unused);
  const response = await handler(new Request('https://management.invalid', {
    method: 'POST', headers: { Authorization: 'Bearer mock-admin-jwt' },
    body: JSON.stringify({ action: 'probe', profile_id: 'mock-profile' }) }));
  assert.equal(response.status, 403);
});
