const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { DurableWhatsAppReceipts } = require('../../backend-sync-wt/durable_whatsapp_receipts.js');
function fixture(t) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'keepsims-receipts-'));
  t.after(() => { fs.rmSync(path.join(directory, 'receipts.json'), { force: true });
    fs.rmSync(path.join(directory, 'receipts.json.tmp'), { force: true }); fs.rmdirSync(directory); });
  return path.join(directory, 'receipts.json');
}
test('lost database response retains receipt across worker restart without another message send', async (t) => {
  const file = fixture(t); const q = new DurableWhatsAppReceipts(file, async () => { throw Error('offline'); });
  q.enqueue('attempt?id=eq.fixture', { state: 'sent' }); await q.flush();
  let writes = 0;
  const restored = new DurableWhatsAppReceipts(file, async (_, patch) => { writes++; assert.equal(patch.state, 'sent'); return [{}]; });
  await restored.flush(); assert.equal(writes, 1); assert.equal(restored.jobs.size, 0);
});
test('early receipt with no matching provider ID stays queued until sender synchronization catches up', async (t) => {
  let matched = false; const q = new DurableWhatsAppReceipts(fixture(t), async () => matched ? [{}] : []);
  q.enqueue('attempt?provider_message_id=eq.fixture', { state: 'delivered' });
  await q.flush(); assert.equal(q.jobs.size, 1); matched = true;
  await q.flush(); assert.equal(q.jobs.size, 0);
});
test('delivered receipt outranks a delayed sent update and concurrent flushes do not lose updates', async (t) => {
  let release; const gate = new Promise((resolve) => { release = resolve; });
  const q = new DurableWhatsAppReceipts(fixture(t), async () => { await gate; return [{}]; });
  q.enqueue('attempt', { state: 'sent' }); const flush = q.flush();
  q.enqueue('attempt', { state: 'delivered' }); q.enqueue('attempt', { state: 'sent' });
  release(); await flush; assert.equal(q.jobs.get('attempt').patch.state, 'delivered');
  await q.flush(); assert.equal(q.jobs.size, 0);
});
