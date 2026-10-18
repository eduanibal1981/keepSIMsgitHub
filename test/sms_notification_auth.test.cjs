const { test } = require('node:test'), assert = require('node:assert/strict');
const { createHmac } = require('node:crypto');
const { loadEdge } = require('./edge_module_loader.cjs');
function fixture({ secret = 'twilio-secret', dbFailure = false } = {}) {
  let handler, commands = 0;
  loadEdge('supabase/functions/sms-webhook/index.ts', { serve: (fn) => { handler = fn; },
    env: { SUPABASE_URL: 'https://db.invalid', SUPABASE_SERVICE_ROLE_KEY: 'service', TWILIO_AUTH_TOKEN: secret,
      PUBLIC_FUNCTION_URL: 'https://test.invalid/sms' }, fetch: async (url) => {
      if (url.endsWith('get_internal_secret')) return new Response('null', { status: 200 });
      if (url.endsWith('route_second_number_sms')) return Response.json({route:'refill'});
      if (url.endsWith('consume_rate_limit')) return new Response(JSON.stringify([{ allowed: true }]), { status: 200 });
      commands++; assert.match(url, /handle_inbound_command$/);
      return new Response(JSON.stringify(dbFailure ? { error: 'temporarily unavailable' } : { reply_text: '<safe & scoped>' }), { status: dbFailure ? 500 : 200 });
    },
  });
  const params = { To: '+12025550123', From: '+20123456789', Body: 'BAL', MessageSid: 'signed-fixture' };
  const signature = createHmac('sha1', secret || 'missing').update('https://test.invalid/sms' + Object.keys(params).sort().map((k) => k + params[k]).join('')).digest('base64');
  const request = (valid = true) => new Request('https://test.invalid/sms', { method: 'POST',
    body: new URLSearchParams(params), headers: { 'x-twilio-signature': valid ? signature : 'invalid' } });
  return { handler, request, commands: () => commands };
}
test('SMS missing authentication configuration and forged signatures cannot execute commands', async () => {
  let f = fixture({ secret: '' }); assert.equal((await f.handler(f.request())).status, 503); assert.equal(f.commands(), 0);
  f = fixture(); assert.equal((await f.handler(f.request(false))).status, 403); assert.equal(f.commands(), 0);
});
test('verified SMS replies escape XML and failed persistence returns a retryable server response', async () => {
  let f = fixture(); const response = await f.handler(f.request()); assert.equal(response.status, 200);
  assert.match(await response.text(), /&lt;safe &amp; scoped&gt;/); assert.equal(f.commands(), 1);
  f = fixture({ dbFailure: true }); assert.equal((await f.handler(f.request())).status, 503);
});
