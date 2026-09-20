const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { stripTypeScriptTypes } = require('node:module');
const source = readFileSync('supabase/functions/dispatch-alert/push_delivery.ts', 'utf8');
const code = stripTypeScriptTypes(source).replace(/^export /gm, '');
const { oneSignalOutcome, uniquePushDevices, pushIdempotencyKey, postOneSignal, routePushDevices } =
  new Function(code + ';return {oneSignalOutcome, uniquePushDevices, pushIdempotencyKey, postOneSignal, routePushDevices};')();

test('an accepted ID without recipients must not trigger another provider', () => {
  assert.equal(oneSignalOutcome(200, { id: 'message-1' }), 'accepted');
  assert.equal(oneSignalOutcome(200, { id: 'message-1', errors: { invalid_aliases: {} } }), 'accepted');
  assert.equal(oneSignalOutcome(200, { id: 'message-1', recipients: 0 }), 'accepted');
  assert.equal(oneSignalOutcome(200, { id: '', errors: ['No subscribers'] }), 'rejected');
  assert.equal(oneSignalOutcome(400, { errors: ['invalid app'] }), 'rejected');
  assert.equal(oneSignalOutcome(200, {}), 'unknown');
  assert.equal(oneSignalOutcome(500, {}), 'unknown');
});

const phone = { device_id: 'phone', onesignal_player_id: 'os-phone', fcm_token: 'fcm-phone', platform: 'android' };
const emulator = { device_id: 'emulator', onesignal_player_id: 'os-emulator', fcm_token: 'fcm-emulator', platform: 'android' };
test('keep both Android installs; discard repeated install and shared transport tokens', () => {
  assert.deepEqual(uniquePushDevices([phone, emulator, { ...phone, fcm_token: 'old' },
    { ...phone, device_id: 'duplicate-install' }]), [phone, emulator]);
});

test('fallback targets only the rejected device, never an accepted device', async () => {
  const attempts = [], fallback = [];
  await routePushDevices([phone, emulator], async (d) => {
    attempts.push(d.device_id);
    return d === phone ? 'accepted' : 'rejected';
  }, async (devices) => fallback.push(...devices));
  assert.deepEqual(attempts, ['phone', 'emulator']);
  assert.deepEqual(fallback, [emulator]);
});

test('ambiguous sends do not duplicate via FCM; FCM-only devices still receive', async () => {
  const fcmOnly = { ...emulator, onesignal_player_id: null };
  const fallback = [];
  await routePushDevices([phone, fcmOnly], async () => 'unknown', async (d) => fallback.push(...d));
  assert.deepEqual(fallback, [fcmOnly]);
});

test('retry keys are stable per notification and target, and valid UUIDs', async () => {
  const key = await pushIdempotencyKey('notification', 'phone');
  assert.equal(key, await pushIdempotencyKey('notification', 'phone'));
  assert.notEqual(key, await pushIdempotencyKey('notification', 'emulator'));
  assert.notEqual(key, await pushIdempotencyKey('another-notification', 'phone'));
  assert.match(key, /^[\da-f]{8}-[\da-f]{4}-8[\da-f]{3}-[89ab][\da-f]{3}-[\da-f]{12}$/);
});

test('timeout retry reuses identical payload, then recognizes omitted recipients as success', async () => {
  const requests = [];
  const result = await postOneSignal({ idempotency_key: 'same-key' }, 'test-key', async (_, request) => {
    requests.push(request.body);
    if (requests.length === 1) throw new Error('timeout');
    return new Response(JSON.stringify({ id: 'accepted' }), { status: 200 });
  });
  assert.equal(requests.length, 2);
  assert.equal(requests[0], requests[1]);
  assert.equal(result.outcome, 'accepted');
});

test('empty id permits fallback without sending legacy or alias retries', async () => {
  let calls = 0;
  const result = await postOneSignal({}, 'test-key', async () => {
    calls++;
    return new Response(JSON.stringify({ id: '', errors: ['No subscribers'] }), { status: 200 });
  });
  assert.equal(result.outcome, 'rejected');
  assert.equal(calls, 1);
});

test('two lost responses remain unknown, never a claimed delivery or definite rejection', async () => {
  let calls = 0;
  const result = await postOneSignal({}, 'test-key', async () => { calls++; throw Error('network'); });
  assert.equal(calls, 2);
  assert.equal(result.outcome, 'unknown');
});

test('dispatcher integration: one push per device, targeted fallback, correct Android payload and logs', async () => {
  const edge = stripTypeScriptTypes(readFileSync('supabase/functions/dispatch-alert/index.ts', 'utf8'))
    .replace(/^import .*;\r?\n/gm, '');
  const deliveries = [], sends = [];
  let handler;
  const db = {
    rpc: async () => ({ data: 'test-secret' }),
    from: (table) => {
      if (table === 'notification_deliveries') return { insert: async (rows) => { deliveries.push(...rows); return {}; } };
      assert.equal(table, 'device_push_tokens');
      const builder = { select: () => builder, eq: () => builder,
        order: async () => ({ data: [phone, emulator] }) };
      return builder;
    },
  };
  const fetcher = async (url, request) => {
    const payload = JSON.parse(request.body);
    sends.push({ url, payload });
    if (url.includes('onesignal')) {
      const id = payload.include_subscription_ids[0] === phone.onesignal_player_id ? 'accepted-os-id' : '';
      return new Response(JSON.stringify({ id }), { status: 200 });
    }
    assert.match(url, /fcm.googleapis.com/);
    return new Response(JSON.stringify({ name: 'projects/test/messages/123' }), { status: 200 });
  };
  const env = { SUPABASE_URL: 'test-url', SUPABASE_SERVICE_ROLE_KEY: 'test-key',
    ONESIGNAL_REST_API_KEY: 'test-os-key', FCM_SERVICE_ACCOUNT_JSON: '{"project_id":"test"}' };
  new Function('serve', 'createClient', 'Deno', 'fetch', 'postOneSignal', 'pushIdempotencyKey', 'routePushDevices',
    edge + ';getFcmAccessToken = async () => "test-access";')(
    (fn) => { handler = fn; }, () => db, { env: { get: (key) => env[key] } }, fetcher,
    (payload, key) => postOneSignal(payload, key, fetcher), pushIdempotencyKey, routePushDevices);
  const payload = { notification_id: 'test-event', user_id: 'test-user', channels: ['push'],
    title: 'Test', body: 'Test body', event_type: 'line_added', category: 'system', action_url: '/wallet' };
  const response = await handler(new Request('https://test.invalid', { method: 'POST',
    headers: { 'x-keep-sims-secret': 'test-secret' }, body: JSON.stringify(payload) }));
  assert.equal(response.status, 200);
  assert.equal(sends.length, 3); // phone OS accepted; emulator OS rejected then FCM
  const fcm = sends[2].payload.message;
  assert.equal(fcm.token, emulator.fcm_token);
  assert.equal(fcm.android.notification.channel_id, 'ks_confirmations_v1');
  assert.equal(fcm.android.notification.tag, 'test-event');
  assert.equal(fcm.android.notification.click_action, undefined); // default launcher works
  assert.equal(fcm.android.priority, 'HIGH');
  assert.equal(fcm.data.action_url, '/wallet');
  assert.equal(deliveries.length, 3);
  assert.match(deliveries[0].detail, /display not confirmed/);
  assert.match(deliveries[2].detail, /FCM accepted 1\/1/);
  const unauthorized = await handler(new Request('https://test.invalid', { method: 'POST', body: '{}' }));
  assert.equal(unauthorized.status, 401);
  assert.equal(sends.length, 3);
});
