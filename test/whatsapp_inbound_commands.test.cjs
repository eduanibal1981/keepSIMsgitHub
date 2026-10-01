const { test } = require('node:test'), assert = require('node:assert/strict');
const { handleBaileysInbound } = require('../../backend-sync-wt/whatsapp_inbound_commands.js');
const request = { senderJid: '20123456789@s.whatsapp.net', observedSender: '+20999999999', messageId: 'original-message', body: 'status' };
function dbFixture({ ready = true, duplicate = false } = {}) {
  const calls = []; const db = async (path, options) => {
    calls.push({ path, options });
    if (path.startsWith('whatsapp_provider_profiles')) return ready ? [{ expected_sender_number: '+20999999999', observed_sender_number: '+20999999999' }] : [];
    assert.equal(path, 'rpc/handle_inbound_command'); return { status: duplicate ? 'duplicate' : 'handled', reply_text: 'Scoped account reply' };
  }; return { db, calls };
}
test('status uses the scoped command handler and preserves the original provider ID', async () => {
  const f = dbFixture(); assert.equal(await handleBaileysInbound(f.db, request), 'Scoped account reply');
  const payload = JSON.parse(f.calls[1].options.body);
  assert.equal(payload.p_body, 'BAL'); assert.equal(payload.p_sender_phone, '+20123456789'); assert.equal(payload.p_provider_msg_id, 'original-message');
});
test('disabled receiving profile and duplicate commands produce no reply', async () => {
  const f = dbFixture({ ready: false }); assert.equal(await handleBaileysInbound(f.db, request), null); assert.equal(f.calls.length, 1);
  assert.equal(await handleBaileysInbound(dbFixture({ duplicate: true }).db, request), null);
});
test('groups and unverified LIDs cannot query account status or trigger refill', async () => {
  for (const senderJid of ['123@g.us', 'unverified@lid']) {
    const f = dbFixture(); assert.equal(await handleBaileysInbound(f.db, { ...request, senderJid }), null); assert.equal(f.calls.length, 0);
  }
  const f = dbFixture(); assert.equal(await handleBaileysInbound(f.db, { ...request, senderJid: 'verified@lid', alternatePhoneJid: request.senderJid }), 'Scoped account reply');
});
