const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createHmac } = require('node:crypto');
const { loadEdge, builder, targetLedger } = require('./edge_module_loader.cjs');
const routeFile = 'supabase/functions/_shared/whatsapp_route.ts';
const deliveryFile = 'supabase/functions/_shared/notification_delivery.ts';
const profile = (kind = 'baileys', id = 'profile-a') => ({ id, provider_kind: kind,
  is_enabled: true, ready_state: 'ready', version: 2, expected_sender_number: '+20123456789',
  observed_sender_number: '+20123456789', connection_metadata: { phone_number_id: id + '-sender' } });
function routeDB(mode = 'baileys', selected = profile(mode), extra = {}) {
  const calls = [], sends = []; let attempt;
  const db = {
    calls, sends,
    from: (table) => builder(() => ({ data: table === 'whatsapp_country_routes'
      ? { route_mode: mode, profile_id: selected.id, version: 2 } : selected })),
    rpc: async (name, args) => {
      calls.push({ name, args });
      if (extra[name]) return extra[name](args);
      if (name === 'notification_channel_eligible') return { data: true };
      if (name === 'whatsapp_refill_healthy') return { data: false };
      if (name === 'resolve_country_by_phone') return { data: 'country-a' };
      if (name === 'claim_whatsapp_message_attempt') {
        if (attempt) return { data: { claimed: false, state: attempt.state, attempt } };
        attempt = { ...args.p_snapshot, id: crypto.randomUUID(), state: 'pending', request_snapshot: args.p_snapshot.request };
        return { data: { claimed: true, claim_token: 'claim', attempt } };
      }
      if (name === 'finish_whatsapp_message_attempt') { attempt.state = args.p_state; return { data: true }; }
      throw Error(name);
    },
  };
  return db;
}
const alert = { purpose: 'subscription_alert', recipientPhone: '+966555555555',
  notificationId: 'event', simLineId: 'line', userId: 'owner', bodyText: 'Alert' };
function adapters(db) { return Object.fromEntries(['baileys', 'meta'].map((kind) => [kind, async (_, p, phone, request) => {
  db.sends.push({ kind, p, phone, request }); return { success: true, state: 'accepted', detail: kind };
}])); }
for (const mode of ['baileys', 'meta_cloud', 'disabled']) test(`Admin ${mode} selection is authoritative, with no provider fallback`, async () => {
  const db = routeDB(mode); const { durableWhatsAppRoute } = loadEdge(routeFile);
  const result = await durableWhatsAppRoute(db, alert, adapters(db));
  assert.equal(db.sends.length, mode === 'disabled' ? 0 : 1);
  if (mode !== 'disabled') assert.equal(db.sends[0].kind, mode === 'baileys' ? 'baileys' : 'meta');
  else assert.equal(result.errorCategory, 'route_disabled');
});
test('an unpaid originating line cannot borrow another paid line', async () => {
  const db = routeDB('baileys', profile(), { notification_channel_eligible: () => ({ data: false }) });
  const result = await loadEdge(routeFile).durableWhatsAppRoute(db, alert, adapters(db));
  assert.equal(result.errorCategory, 'not_eligible'); assert.equal(db.sends.length, 0);
});
test('sender mismatch and disabled profile prevent any provider request', async () => {
  for (const p of [{ ...profile(), observed_sender_number: '+20111111111' }, { ...profile(), is_enabled: false }]) {
    const db = routeDB('baileys', p);
    assert.equal((await loadEdge(routeFile).durableWhatsAppRoute(db, alert, adapters(db))).errorCategory, 'profile_not_ready');
    assert.equal(db.sends.length, 0);
  }
});
test('parallel dispatches use one durable attempt and one provider request', async () => {
  const db = routeDB(); const fn = loadEdge(routeFile).durableWhatsAppRoute;
  await Promise.all([fn(db, alert, adapters(db)), fn(db, alert, adapters(db))]);
  assert.equal(db.sends.length, 1);
  const keys = db.calls.filter((c) => c.name === 'claim_whatsapp_message_attempt').map((c) => c.args.p_key);
  assert.equal(keys[0], keys[1]);
});
test('receiving Meta conversation determines reply profile despite a disabled country route', async () => {
  const p = profile('meta_cloud', 'receiving'); const db = routeDB('disabled', p);
  const request = { purpose: 'offline_refill_reply', recipientPhone: '+20123456789', commandId: 'cmd',
    replyProfileId: p.id, replyPhoneNumberId: p.connection_metadata.phone_number_id };
  assert.equal((await loadEdge(routeFile).durableWhatsAppRoute(db, request, adapters(db))).state, 'accepted');
  assert.equal(db.sends[0].p.id, 'receiving');
  assert.equal(db.calls.some((c) => c.name === 'notification_channel_eligible'), false);
});
test('a reply cannot substitute a different Meta sender ID', async () => {
  const db = routeDB('meta_cloud', profile('meta_cloud'));
  const result = await loadEdge(routeFile).durableWhatsAppRoute(db, { purpose: 'offline_refill_reply', recipientPhone: alert.recipientPhone,
    replyProfileId: 'profile-a', replyPhoneNumberId: 'wrong', commandId: 'cmd' }, adapters(db));
  assert.equal(result.errorCategory, 'reply_identity_mismatch'); assert.equal(db.sends.length, 0);
});
test('selected profile uses exact Vault name and lookup failure never falls back to environment credentials', async () => {
  const { profileSecret } = loadEdge('supabase/functions/_shared/whatsapp_profile.ts', { env: { WABA_ACCESS_TOKEN: 'wrong-global' } });
  const p = profile('meta_cloud'); p.connection_metadata = { access_token_vault_id: 'ref', use_legacy_env: true };
  const db = { rpc: async (_, args) => { assert.equal(args.p_name, 'wa_meta_token_profile-a'); return { data: 'profile-token' }; } };
  assert.equal(await profileSecret(db, p, 'token'), 'profile-token');
  await assert.rejects(profileSecret({ rpc: async () => ({ error: 'unavailable' }) }, p, 'token'));
});
test('partial channel failure retries only failed targets with their original payload', async () => {
  const ledger = targetLedger(), delivery = loadEdge(deliveryFile); let push = 0, email = 0;
  const run = async (text) => Promise.all([
    delivery.deliverTarget(ledger, 'event', 'push', 'device', { text }, async () => { push++; return { state: 'accepted_by_provider', detail: 'accepted' }; }),
    delivery.deliverTarget(ledger, 'event', 'email', 'primary', { text }, async (saved) => {
      email++; assert.equal(saved.text, 'original'); return email === 1 ? { state: 'failed', retryable: true, detail: '429' }
        : { state: 'accepted_by_provider', detail: 'accepted' };
    }),
  ]);
  assert.equal(delivery.summarizeTargets(await run('original')).retryable, true);
  assert.equal(delivery.summarizeTargets(await run('changed')).success, true);
  assert.equal(push, 1); assert.equal(email, 2);
});
test('a lost provider response stays unknown and is never automatically resent', async () => {
  const ledger = targetLedger(), delivery = loadEdge(deliveryFile); let sends = 0;
  const send = async () => { sends++; throw Error('connection reset after send'); };
  assert.equal((await delivery.deliverTarget(ledger, 'event', 'telegram', 'primary', {}, send)).state, 'unknown');
  assert.equal((await delivery.deliverTarget(ledger, 'event', 'telegram', 'primary', {}, send)).state, 'unknown');
  assert.equal(sends, 1);
});
test('a fast delivered receipt cannot be overwritten by provider acceptance', async () => {
  const ledger = targetLedger(), delivery = loadEdge(deliveryFile);
  const outcome = await delivery.deliverTarget(ledger, 'event', 'whatsapp', 'primary', {}, async () => {
    ledger.rows.get('event:whatsapp:primary').state = 'delivered';
    return { state: 'accepted_by_provider', detail: 'queued' };
  });
  assert.equal(outcome.state, 'delivered');
});
test('HTML alert text is escaped before Email rendering', () => {
  assert.equal(loadEdge(deliveryFile).escapeHtml('<img src="x">&\''), '&lt;img src=&quot;x&quot;&gt;&amp;&#39;');
});
function webhookFixture(options = {}) {
  let handler, mutations = 0;
  const p = profile('meta_cloud'); p.connection_metadata = { phone_number_id: 'sender', app_secret_vault_id: 'ref' };
  const db = { from: (table) => builder((_, op) => {
    if (op.update) { mutations++; return options.receiptError ? { error: 'DB unavailable' } : {}; }
    return { data: table === 'whatsapp_provider_profiles' ? [p, profile('meta_cloud', 'second')] : null };
  }), rpc: async () => ({ data: options.missingSecret ? null : 'app-secret' }) };
  loadEdge('supabase/functions/waba-webhook/index.ts', { serve: (fn) => { handler = fn; }, createClient: () => db });
  const raw = JSON.stringify({ entry: [{ changes: [{ value: { metadata: { phone_number_id: options.sender || 'sender' },
    statuses: [{ id: 'provider-message', status: 'delivered' }] } }] }] });
  const request = (signed = true) => new Request('https://test.invalid', { method: 'POST', body: raw,
    headers: signed ? { 'x-hub-signature-256': 'sha256=' + createHmac('sha256', 'app-secret').update(raw).digest('hex') } : {} });
  return { handler, request, mutations: () => mutations };
}
test('Meta requires a signature and configured secret before any mutation', async () => {
  let f = webhookFixture(); assert.equal((await f.handler(f.request(false))).status, 401); assert.equal(f.mutations(), 0);
  f = webhookFixture({ missingSecret: true }); assert.equal((await f.handler(f.request())).status, 503); assert.equal(f.mutations(), 0);
});
test('Meta receipts map to their receiving profile; unknown sender rejected', async () => {
  let f = webhookFixture(); assert.equal((await f.handler(f.request())).status, 200); assert.equal(f.mutations(), 1);
  f = webhookFixture({ sender: 'unconfigured' }); assert.equal((await f.handler(f.request())).status, 401); assert.equal(f.mutations(), 0);
});
test('Meta receipt persistence failure returns 503 so Meta can retry', async () => {
  const f = webhookFixture({ receiptError: true }); assert.equal((await f.handler(f.request())).status, 503);
});

test('Admin probe saves with verified caller authorization and reads credentials using the privileged client', async () => {
  let handler, recorded = false, fetched = false;
  const p = profile('meta_cloud'); p.connection_metadata.access_token_vault_id = 'vault-reference';
  p.connection_metadata.app_secret_vault_id = 'app-secret-reference';
  const privileged = {
    auth: { getUser: async (jwt) => { assert.equal(jwt, 'owner-jwt'); return { data: { user: { id: 'owner', app_metadata: { is_power_user: true } } } }; } },
    from: (table) => builder(() => ({ data: table === 'profiles' ? { is_suspended: false } : p })),
    rpc: async (name, args) => {
      if (name === 'consume_rate_limit') return { data: [{ allowed: true }] };
      assert.equal(name, 'get_internal_secret'); assert.ok(['wa_meta_token_profile-a', 'wa_meta_app_secret_profile-a'].includes(args.p_name)); return { data: 'profile-token' };
    },
  };
  const caller = { rpc: async (name) => { assert.equal(name, 'admin_record_whatsapp_probe'); recorded = true; return {}; } };
  loadEdge('supabase/functions/send-whatsapp-alert/index.ts', {
    serve: (fn) => { handler = fn; }, env: {}, createClient: (_, __, options) => {
      if (!options) return privileged;
      assert.equal(options.global.headers.Authorization, 'Bearer owner-jwt'); return caller;
    }, fetch: async (url, request) => {
      assert.match(url, /profile-a-sender/); assert.equal(request.headers.Authorization, 'Bearer profile-token'); fetched = true;
      return new Response(JSON.stringify({ display_phone_number: '+20123456789' }), { status: 200 });
    },
  });
  const response = await handler(new Request('https://test.invalid', { method: 'POST', headers: { Authorization: 'Bearer owner-jwt' },
    body: JSON.stringify({ action: 'probe', profile_id: p.id }) }));
  assert.equal(response.status, 200); assert.equal(recorded, true); assert.equal(fetched, true);
});
test('customer and suspended Admin cannot invoke management actions', async () => {
  for (const suspended of [false, true]) {
    let handler; const db = { auth: { getUser: async () => ({ data: { user: { id: 'user', app_metadata: { is_power_user: suspended } } } }) },
      from: () => builder(() => ({ data: { is_suspended: suspended } })), rpc: () => { throw Error('Must not reach management'); } };
    loadEdge('supabase/functions/send-whatsapp-alert/index.ts', { serve: (fn) => { handler = fn; }, createClient: () => db });
    assert.equal((await handler(new Request('https://test.invalid', { method: 'POST', headers: { Authorization: 'Bearer test' }, body: '{}' }))).status, 403);
  }
});
test('Baileys explicit pre-queue rejection is retryable; ambiguous server failure is withheld', async () => {
  for (const safe of [true, false]) {
    const p = profile(); p.connection_metadata = { endpoint_url: 'https://worker.invalid', use_legacy_env: true };
    const db = routeDB('baileys', p);
    const router = loadEdge('supabase/functions/_shared/whatsapp_router.ts', { env: { WHATSAPP_VPS_API_KEY: 'selected-key' },
      fetch: async (_, request) => { assert.equal(request.headers['x-api-key'], 'selected-key');
        return new Response(JSON.stringify({ success: false, safe_to_retry: safe }), { status: 503 }); } });
    const outcome = await router.routeAndSendWhatsApp(db, alert);
    assert.equal(outcome.state, safe ? 'failed' : 'unknown'); assert.equal(outcome.retryable, safe);
  }
});
test('Meta adapter uses selected sender, approved template and attempt correlation', async () => {
  const p = profile('meta_cloud'); p.connection_metadata.use_legacy_env = true;
  p.connection_metadata.template_mappings = { default: { name: 'approved_alert', language: 'en_US', body_parameter_count: 1 } };
  const db = routeDB('meta_cloud', p); let sent;
  p.connection_metadata.legacy_webhook_env = true;
  const router = loadEdge('supabase/functions/_shared/whatsapp_router.ts', { env: { WABA_ACCESS_TOKEN: 'selected-token', WABA_APP_SECRET: 'app-secret' },
    fetch: async (url, options) => { assert.match(url, /v26\.0\/profile-a-sender\/messages$/);
      assert.equal(options.headers.Authorization, 'Bearer selected-token'); sent = JSON.parse(options.body);
      return new Response(JSON.stringify({ messages: [{ id: 'meta-message' }] }), { status: 200 }); } });
  assert.equal((await router.routeAndSendWhatsApp(db, alert)).state, 'accepted');
  assert.equal(sent.template.name, 'approved_alert'); assert.equal(sent.template.components[0].parameters[0].text, 'Alert');
  assert.match(sent.biz_opaque_callback_data, /^[0-9a-f-]{36}$/);
});
