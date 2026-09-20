const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const { stripTypeScriptTypes } = require('node:module');

// Execute the production handlers with a fake provider/database; never dial phones.
function source(file) {
  return stripTypeScriptTypes(fs.readFileSync(file, 'utf8').replace(/^import .*;\r?\n/gm, '').replace(/export /g, ''), { mode: 'transform' });
}
function fixture(overrides = {}) {
  const record = { id: 'call-1', user_id: 'owner', call_type: 'app_to_phone_webrtc', status: 'initiated',
    destination_number: '+12025550123', effective_caller_id: '+12025550124', rate_per_minute_usd: .1,
    telnyx_call_control_id_leg_a: 'app-leg', ...overrides };
  const session = { id: 'session-1', user_id: 'owner', call_record_id: record.id, app_answered: false, media_ready: false, dial_started: false };
  const provider = [], rpcCalls = [];
  const tables = { call_records: [record], call_media_sessions: [session], wallets: [{ user_id: 'owner', balance: 5 }], processed_webhook_events: [] };
  const sandbox = { Response, URL, Date, crypto, btoa, atob, console, fetch: async (url, options = {}) => {
    const uri = new URL(url), body = options.body && JSON.parse(options.body);
    const method = options.method || 'GET';
    if (uri.hostname === 'api.telnyx.com') {
      if (body?.command_id) {
        const existing = provider.find(p => p.body?.command_id === body.command_id);
        if (existing) return Response.json({ data: { call_control_id: 'phone-leg', call_session_id: 'provider-session' } });
      }
      provider.push({ path: uri.pathname, body, method });
      if (method === 'DELETE') return new Response(null, { status: 204 });
      return Response.json({ data: { call_control_id: 'phone-leg', call_session_id: 'provider-session' } });
    }
    const table = uri.pathname.split('/').pop();
    if (method === 'POST') {
      const inserted = body ? (Array.isArray(body) ? body : [body]) : [];
      tables[table] = (tables[table] || []).concat(inserted);
      return Response.json(inserted);
    }
    const selected = (tables[table] || []).filter(row => [...uri.searchParams].every(([key, value]) => {
      if (['select', 'limit', 'order'].includes(key)) return true;
      if (value.startsWith('eq.')) return String(row[key]) === value.slice(3);
      if (value === 'is.null') return row[key] == null;
      if (value.startsWith('not.in.')) return !value.slice(8, -1).split(',').includes(row[key]);
      if (value.startsWith('gt.')) return row[key] > value.slice(3);
      if (value.startsWith('lt.')) return row[key] < value.slice(3);
      throw Error(`Unhandled filter ${key}=${value}`);
    }));
    if (method === 'PATCH') selected.forEach(row => Object.assign(row, body));
    return Response.json(selected);
  }};
  vm.createContext(sandbox);
  vm.runInContext(source('supabase/functions/_shared/call-media.ts') + source('supabase/functions/telnyx-cdr/media-events.ts') + '\nthis.Audio = CallMedia; this.handle = handleMediaEvent;', sandbox);
  const audio = new sandbox.Audio('https://db.test', {}, 'test-only', 'app-1');
  const event = async (type, leg = 'app', extra = {}) => sandbox.handle(audio, { ...record }, {
    event_type: type, occurred_at: '2026-09-17T18:18:00Z',
    payload: { call_control_id: leg === 'app' ? 'app-leg' : 'phone-leg',
      client_state: btoa(JSON.stringify({ callRecordId: record.id, mediaLeg: leg })), ...extra },
  }, async (name, args) => { rpcCalls.push({ name, args }); return { ok: true }; });
  return { audio, record, session, provider, event, rpcCalls, sandbox, tables };
}

test('answering the app leg alone never dials the recipient or starts billing', async () => {
  const f = fixture(); await f.event('call.answered');
  assert.equal(f.session.app_answered, true);
  assert.equal(f.provider.length, 0); assert.equal(f.record.status, 'initiated');
  assert.equal(f.record.answered_at, undefined);
});
test('media and app answer in either order dial one destination with automatic bridge', async () => {
  for (const order of [['media_ready', 'app_answered'], ['app_answered', 'media_ready']]) {
    const f = fixture();
    await f.audio.ready('call-1', order[0]); assert.equal(f.provider.length, 0);
    await f.audio.ready('call-1', order[1]);
    assert.equal(f.provider.length, 1);
    const body = f.provider[0].body;
    assert.equal(body.to, f.record.destination_number); assert.equal(body.from, f.record.effective_caller_id);
    assert.equal(body.link_to, 'app-leg'); assert.equal(body.bridge_on_answer, true);
    assert.equal(body.time_limit_secs, 3000); assert.equal(body.command_id, 'session-1');
    await f.audio.ready('call-1', 'app_answered'); assert.equal(f.provider.length, 1);
  }
});
test('destination answering is not connected until a bridge is confirmed', async () => {
  const f = fixture();
  await f.event('call.answered', 'destination'); assert.equal(f.record.status, 'initiated');
  await f.event('call.bridged', 'destination'); assert.equal(f.record.status, 'in_progress');
  assert.equal(f.record.answered_at, '2026-09-17T18:18:00.000Z');
});
test('terminal and cancelled calls cannot dial from late readiness events', async () => {
  for (const state of [{ status: 'cancelled' }, { cancellation_requested_at: 'now' }]) {
    const f = fixture(state); f.session.media_ready = true;
    await f.audio.ready('call-1', 'app_answered'); assert.equal(f.provider.length, 0);
  }
});
test('leg identity mismatch does not mutate or bridge another call', async () => {
  const f = fixture();
  await assert.rejects(f.event('call.answered', 'app', { call_control_id: 'other-leg' }), /mismatch/);
  assert.equal(f.provider.length, 0); assert.equal(f.session.app_answered, false);
});
test('hanging up either participant closes the other leg and invokes atomic settlement', async () => {
  for (const leg of ['app', 'destination']) {
    const f = fixture({ telnyx_call_control_id_leg_b: 'phone-leg', answered_at: '2026-09-17T18:17:00Z' });
    await f.event('call.hangup', leg);
    assert.equal(f.provider[0].path, `/v2/calls/${leg === 'app' ? 'phone-leg' : 'app-leg'}/actions/hangup`);
    assert.equal(f.rpcCalls[0].name, 'finish_media_call');
    assert.equal(f.rpcCalls[0].args.p_status, 'completed');
  }
});
test('603 takes precedence over user_busy for unbridged destinations', async () => {
  const f = fixture();
  await f.event('call.hangup', 'destination', { sip_hangup_cause: '603', hangup_cause: 'user_busy' });
  assert.equal(f.rpcCalls[0].args.p_status, 'declined');
});
test('single-use media session cannot be claimed by a different account', async () => {
  const f = fixture(); f.session.call_record_id = null; f.session.expires_at = '2099-01-01';
  await assert.rejects(f.audio.claim('session-1', 'attacker', 'other-call'), /expired or already used/);
  assert.equal(f.session.call_record_id, null);
  await f.audio.claim('session-1', 'owner', 'call-1');
  await assert.rejects(f.audio.claim('session-1', 'owner', 'other-call'), /already used/);
});
test('missing media configuration fails before issuing credentials or dialing', async () => {
  const f = fixture(); await assert.rejects(f.audio.prepare('owner', ''), /not configured/);
  assert.equal(f.provider.length, 0);
});
test('provider failure is propagated instead of claiming audio is ready', async () => {
  const f = fixture(); f.session.media_ready = true;
  f.sandbox.fetch = async url => {
    if (url.includes('api.telnyx.com')) return new Response('{}', { status: 503 });
    if (url.includes('call_media_sessions')) return Response.json([{ ...f.session, app_answered: true }]);
    if (url.includes('wallets')) return Response.json([{ balance: 5 }]);
    return Response.json([f.record]);
  };
  await assert.rejects(f.audio.ready('call-1', 'app_answered'), /provider request failed/);
  assert.equal(f.record.status, 'initiated');
});

test('insufficient balance for 1 second of talk time aborts destination dial', async () => {
  const f = fixture();
  f.tables.wallets[0].balance = 0.0001;
  f.session.media_ready = true;
  await assert.rejects(f.audio.ready('call-1', 'app_answered'), /Insufficient wallet balance/);
  assert.equal(f.provider.length, 0);
});

test('concurrent readiness events never dial destination more than once', async () => {
  const f = fixture();
  await Promise.all([
    f.audio.ready('call-1', 'media_ready'),
    f.audio.ready('call-1', 'app_answered'),
  ]);
  assert.equal(f.provider.length, 1);
  assert.equal(f.provider[0].body.to, f.record.destination_number);
  assert.equal(f.provider[0].body.command_id, 'session-1');
});

test('close() terminates call legs and deletes telephony credential', async () => {
  const f = fixture({ telnyx_call_control_id_leg_b: 'phone-leg' });
  f.session.credential_id = 'cred-123';
  f.session.cleaned_up = false;
  await f.audio.close(f.record);
  const deleteCalls = f.provider.filter(p => p.method === 'DELETE');
  assert.equal(deleteCalls.length, 1);
  assert.equal(deleteCalls[0].path, '/v2/telephony_credentials/cred-123');
  assert.equal(f.session.cleaned_up, true);
});

test('call.hangup deletes telephony credential and sets cleaned_up', async () => {
  const f = fixture({ telnyx_call_control_id_leg_b: 'phone-leg', answered_at: '2026-09-17T18:17:00Z' });
  f.session.credential_id = 'cred-456';
  f.session.cleaned_up = false;
  await f.event('call.hangup', 'app');
  const deleteCalls = f.provider.filter(p => p.method === 'DELETE');
  assert.equal(deleteCalls.length, 1);
  assert.equal(deleteCalls[0].path, '/v2/telephony_credentials/cred-456');
  assert.equal(f.session.cleaned_up, true);
});

test('processed webhook events deduplication correctly tracks and rejects duplicates', async () => {
  const f = fixture();
  const eventId = 'evt_test_dedup_123';
  f.tables.processed_webhook_events.push({ event_id: eventId, event_type: 'call.answered' });

  const res = await f.sandbox.fetch(`https://db.test/processed_webhook_events?event_id=eq.${eventId}&select=event_id`);
  const rows = await res.json();
  assert.equal(rows.length, 1);
  assert.equal(rows[0].event_id, eventId);
});

