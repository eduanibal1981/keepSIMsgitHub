const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createHmac, generateKeyPairSync, sign, timingSafeEqual } = require('node:crypto');
const { loadEdge, builder } = require('./edge_module_loader.cjs');
const url = 'https://project.invalid';
const owner = '10000000-0000-4000-8000-000000000001';
const other = '10000000-0000-4000-8000-000000000002';
const callId = '20000000-0000-4000-8000-000000000001';
const didId = '30000000-0000-4000-8000-000000000001';
const attemptId = '40000000-0000-4000-8000-000000000001';
const keys = generateKeyPairSync('ed25519');
const publicKey = keys.publicKey.export({ format: 'der', type: 'spki' }).subarray(-32).toString('base64');
const token = (extra = {}, expired = false) => {
  const data = [Buffer.from(JSON.stringify({ alg: 'HS256' })).toString('base64url'),
    Buffer.from(JSON.stringify({ sub: owner, exp: Math.floor(Date.now()/1000) + (expired ? -60 : 3600), app_metadata: {}, ...extra })).toString('base64url')].join('.');
  return data + '.' + createHmac('sha256', 'local-auth-signing-key').update(data).digest('base64url');
};
function validateToken(value) {
  try {
    const [a,b,c] = value.split('.');
    const expected = createHmac('sha256', 'local-auth-signing-key').update(a+'.'+b).digest();
    const signature = Buffer.from(c, 'base64url');
    if (signature.length !== expected.length || !timingSafeEqual(signature, expected)) return null;
    const claims = JSON.parse(Buffer.from(b, 'base64url'));
    return claims.exp > Date.now()/1000 ? { id: claims.sub, ...claims } : null;
  } catch { return null; }
}
const json = (body, status = 200) => new Response(JSON.stringify(body), { status });
const request = (slug, body, auth = 'service', headers = {}) => new Request(`${url}/functions/v1/${slug}`, {
  method: 'POST', body: JSON.stringify(body), headers: { Authorization: `Bearer ${auth}`, 'content-type': 'application/json', ...headers },
});
function fixture(slug, options = {}) {
  let handler; const calls = [], receipts = new Map(), messages = [];
  const call = { id:callId,user_id:owner,caller_number:'+100',destination_number:'+200',call_type:'callback',status:'in_progress',answered_at:new Date().toISOString(),rate_per_minute_usd:0.08,...options.record };
  let attempt = { id: attemptId, user_id: owner, provider: 'telnyx', provider_resource_id: 'resource-1', method: 'voice', status: 'dispatched', ...options.attempt };
  const fetch = async (address, init = {}) => {
    const path = String(address).replace(url, '');
    const body = init.body ? JSON.parse(init.body.toString().startsWith('{') ? init.body : '{}') : null;
    calls.push({ path, ...init, body });
    if (path === '/auth/v1/user') {
      const user = validateToken(init.headers.Authorization.slice(7));
      return json(user || {}, user ? 200 : 401);
    }
    if (path.endsWith('/assert_admin')) return json({}, options.suspended ? 403 : 200);
    if (path.endsWith('/get_internal_secret')) return json(options.missingSecret ? null : ({ TWILIO_AUTH_TOKEN: 'twilio-secret', TWILIO_ACCOUNT_SID: 'ACfixture', TELNYX_API_KEY: 'provider-secret' }[body.p_name] || null));
    if (path.includes('/system_configs?')) return json([]);
    if (path.endsWith('/claim_verified_webhook')) {
      const key = body.p_scope + ':' + body.p_event_id;
      let row = receipts.get(key);
      if (row && (row.hash !== body.p_payload_hash || row.resource !== body.p_resource_id)) return json({ state: 'conflict' });
      if (row && row.state !== 'failed') return json({ state: row.state === 'completed' ? 'completed' : 'busy' });
      if ([...receipts.values()].some(r => r.scope === body.p_scope && r.resource === body.p_resource_id && r.state === 'processing')) return json({ state: 'busy' });
      row = { scope: body.p_scope, state: 'processing', hash: body.p_payload_hash, resource: body.p_resource_id, token: crypto.randomUUID() };
      receipts.set(key, row); return json({ state: 'claimed', token: row.token });
    }
    if (path.endsWith('/finish_verified_webhook')) {
      const row = receipts.get(body.p_scope + ':' + body.p_event_id);
      assert.equal(row.token, body.p_token); row.state = body.p_success ? 'completed' : 'failed'; return json(null);
    }
    if (path.includes('/line_verification_attempts?')) {
      if (options.correlationPending) return json([]);
      const u = new URL(address);
      return json(u.searchParams.get('provider') === 'eq.'+attempt.provider &&
        u.searchParams.get('provider_resource_id') === 'eq.'+attempt.provider_resource_id ? [attempt] : []);
    }
    if (path.endsWith('/settle_line_verification_event')) {
      if (options.settlementFailure) return json({ message: 'failed' }, 500);
      attempt.status = 'terminal'; return json({ success: true });
    }
    if (path.includes('/call_records?')) {
      if (init.method === 'PATCH') { if(options.patchFailure)return json({},500);Object.assign(call,body); }
      return json(options.noTarget ? [] : [call]);
    }
    if(path.endsWith('/debit_wallet_for_call'))return json({success:!options.debitFailure},options.debitFailure?500:200);
    if (path.includes('/virtual_did_numbers?')) return json([{ id: didId, user_id: options.foreignDid ? other : owner, phone_number: '+200' }]);
    if (path.includes('/voicemail_messages?')) return json(messages);
    if (path === '/rest/v1/voicemail_messages') { messages.push({ id: 'message', ...body }); return json(messages); }
    if (path.includes('/functions/v1/dispatch-alert')) return json({});
    if (path.endsWith('/consume_rate_limit')) return json([{ allowed: true }]);
    if (path.endsWith('/ingest_offline_refill')) return json({}, options.ingestFailure ? 500 : 200);
    if (String(address).startsWith('https://api.telnyx.com') || String(address).startsWith('https://api.twilio.com')) {
      if (options.providerGate) await options.providerGate;
      return json({ data: [] }, options.providerFailure ? 503 : 200);
    }
    if (options.extraFetch) return options.extraFetch(address, init);
    throw Error('Unexpected request '+path);
  };
  const client = {
    auth: { getUser: async jwt => { const user = validateToken(jwt); return { data: { user }, error: user ? null : Error('invalid') }; } },
    rpc: async (name, args) => {
      if (name === 'get_internal_secret') return { data: options.missingSecret ? null : 'provider-secret', error: null };
      throw Error(name);
    },
    from: table => builder(filters => {
      assert.equal(table, 'line_verification_attempts');
      const match = filters.user_id === attempt.user_id && filters.method === 'voice' &&
        (filters.id ? filters.id === attempt.id : filters.provider_resource_id === attempt.provider_resource_id);
      return { data: match ? attempt : null, error: null };
    }),
  };
  loadEdge(`supabase/functions/${slug}/index.ts`, { serve: fn => handler = fn, fetch, createClient: () => client,
    env: { SUPABASE_URL: url, SUPABASE_SERVICE_ROLE_KEY: 'service',
      TELNYX_PUBLIC_KEY: publicKey, ...options.env } });
  return { handler, calls, receipts, messages, mutations: () => calls.filter(c =>
    (c.method && c.method !== 'GET') && !/get_internal_secret|claim_verified_webhook|finish_verified_webhook|assert_admin/.test(c.path)) };
}
function telnyx(slug, { id = 'event-1', event_type = 'call.ringing', payload = {}, meta, ...extra } = {}, headers = {}) {
  const body = JSON.stringify({ data: { id, event_type, payload: { call_control_id: 'resource-1', ...payload }, ...extra }, ...(meta ? {meta} : {}) });
  const timestamp = String(Math.floor(Date.now()/1000));
  return new Request(`${url}/functions/v1/${slug}`, { method: 'POST', body,
    headers: { 'content-type': 'application/json', 'telnyx-timestamp': timestamp,
      'telnyx-signature-ed25519': sign(null, Buffer.from(timestamp+'|'+body), keys.privateKey).toString('base64'), ...headers } });
}
function twilio(slug, params, { forged = false, query = '', headers = {} } = {}) {
  const address = `${url}/functions/v1/${slug}`+query;
  const input = address + Object.keys(params).sort().map(k => k + params[k]).join('');
  return new Request(address, { method: 'POST', body: new URLSearchParams(params), headers: {
    'content-type': 'application/x-www-form-urlencoded', 'x-twilio-signature': forged ? 'forged' : createHmac('sha1', 'twilio-secret').update(input).digest('base64'), ...headers,
  } });
}

test('admin rejects forged and expired JWTs, ordinary users and user_metadata promotions before provider access', async () => {
  for (const jwt of ['eyJhbGciOiJub25lIn0.eyJyb2xlIjoic2VydmljZV9yb2xlIn0.forged', token({}, true), token(), token({ user_metadata: { is_power_user: true } })]) {
    const f = fixture('admin-telnyx-billing'); const r = await f.handler(request('admin-telnyx-billing', {}, jwt));
    assert.ok([401,403].includes(r.status)); assert.equal(f.mutations().length, 0);
    assert.equal(f.calls.some(c => c.path.includes('get_internal_secret')), false);
  }
});
test('verified admin and exact internal credential work; suspended admins are denied', async () => {
  for (const jwt of [token({ app_metadata: { is_power_user: true } }), 'service']) {
    const f = fixture('admin-telnyx-billing'); assert.equal((await f.handler(request('admin-telnyx-billing', {}, jwt))).status, 200);
    assert.ok(f.calls.some(c => c.path.startsWith('https://api.telnyx.com')));
    assert.equal(f.calls.some(c => c.path === '/auth/v1/user'), jwt !== 'service');
  }
  const f = fixture('admin-telnyx-billing', { suspended: true });
  assert.equal((await f.handler(request('admin-telnyx-billing', {}, token({ app_metadata: { is_power_user: true } })))).status, 403);
  assert.equal(f.mutations().length, 0);
});
test('voicemail rejects arbitrary headers and user tokens without writes', async () => {
  for (const auth of ['forged', token(), token({ role: 'service_role' })]) {
    const f = fixture('process-voicemail'); assert.equal((await f.handler(request('process-voicemail', {}, auth))).status, 401); assert.equal(f.calls.length, 0);
  }
});
const voicemail = { recording_id: 'recording-1', call_record_id: callId, audio_url: 'https://audio.invalid/file' };
test('voicemail derives owner/caller from a trusted record; replay and concurrent delivery insert and notify once', async () => {
  const f = fixture('process-voicemail');
  const results = await Promise.all([f.handler(request('process-voicemail', voicemail)), f.handler(request('process-voicemail', voicemail))]);
  assert.ok(results.some(r => r.status === 200)); assert.ok(results.every(r => [200,503].includes(r.status)));
  assert.equal((await f.handler(request('process-voicemail', voicemail))).status, 200);
  assert.equal(f.messages.length, 1); assert.equal(f.messages[0].user_id, owner); assert.equal(f.messages[0].caller_number, '+100');
  assert.equal(f.calls.filter(c => c.path.includes('/dispatch-alert')).length, 1);
});
test('voicemail refuses foreign ownership, mismatched DID, missing records and missing target', async () => {
  for (const [options, body, status] of [[{}, { ...voicemail, user_id: other },403], [{ foreignDid:true },{ ...voicemail,did_id:didId },403], [{ noTarget:true },voicemail,404], [{},{ recording_id:'r',audio_url:'https://audio.invalid' },400]]) {
    const f = fixture('process-voicemail', options); assert.equal((await f.handler(request('process-voicemail',body))).status,status); assert.equal(f.mutations().length,0);
  }
});
test('liveness cancellation rejects invalid JWTs and foreign or mismatched provider resources', async () => {
  for (const [auth,body,status] of [['forged',{ action:'cancel_call',attemptId },401], [token({},true),{ action:'cancel_call',attemptId },401], [token({sub:other}),{action:'cancel_call',attemptId},404], [token(),{action:'cancel_call',attemptId,callSid:'foreign'},404]]) {
    const f = fixture('liveness-verification'); assert.equal((await f.handler(request('liveness-verification',body,auth))).status,status); assert.equal(f.calls.length,0);
  }
});
test('liveness cancellation uses only the stored provider; legacy SID input is scoped to owner', async () => {
  for (const provider of ['telnyx','twilio']) {
    const f = fixture('liveness-verification', {attempt:{provider}});
    assert.equal((await f.handler(request('liveness-verification',{action:'twilio_cancel_call',callSid:'resource-1'},token()))).status,200);
    assert.equal(f.calls.length,1); assert.ok(f.calls[0].path.startsWith('https://api.'+provider+'.com'));
  }
  const f = fixture('liveness-verification',{providerFailure:true});
  assert.equal((await f.handler(request('liveness-verification',{action:'cancel_call',attemptId},token()))).status,503); assert.equal(f.calls.length,1);
});
test('Telnyx callbacks reject absent/malformed keys, bad signatures and stale/future timestamps before mutations', async () => {
  for (const slug of ['telnyx-cdr','liveness-verification-webhook']) {
    for (const [env,headers,status] of [[{TELNYX_PUBLIC_KEY:''},{},503], [{TELNYX_PUBLIC_KEY:'invalid'},{},503], [{},{'telnyx-signature-ed25519':'invalid'},401], [{},{'telnyx-timestamp':String(Math.floor(Date.now()/1000)-301)},401], [{},{'telnyx-timestamp':String(Math.floor(Date.now()/1000)+301)},401], [{},{'telnyx-timestamp':'123junk'},401]]) {
      const f = fixture(slug,{env}); assert.equal((await f.handler(telnyx(slug,{},headers))).status,status); assert.equal(f.mutations().length,0); assert.equal(f.receipts.size,0);
    }
  }
});
test('signed Telnyx callbacks settle once; duplicate delivery and concurrent callbacks do not repeat actions', async () => {
  for (const slug of ['liveness-verification-webhook','telnyx-cdr']) {
    const f = fixture(slug); const event = slug === 'telnyx-cdr' ? {payload:{client_state:btoa(JSON.stringify({attemptId}))}} : {};
    const results = await Promise.all([f.handler(telnyx(slug,event)),f.handler(telnyx(slug,event))]);
    assert.ok(results.some(r => r.status === 200)); assert.ok(results.every(r => [200,503].includes(r.status)));
    assert.equal((await f.handler(telnyx(slug,event))).status,200);
    assert.equal(f.calls.filter(c => c.path.endsWith('/settle_line_verification_event')).length,1);
    assert.equal(f.calls.filter(c => c.path.startsWith('https://api.telnyx.com')).length,1);
  }
});
test('Telnyx client_state cannot settle another attempt and failed settlement remains retryable', async () => {
  let f = fixture('telnyx-cdr');
  assert.equal((await f.handler(telnyx('telnyx-cdr',{payload:{client_state:btoa(JSON.stringify({attemptId:'foreign'}))}}))).status,403); assert.equal(f.mutations().length,0);
  f = fixture('liveness-verification-webhook',{settlementFailure:true});
  assert.equal((await f.handler(telnyx('liveness-verification-webhook'))).status,503);
  assert.equal([...f.receipts.values()][0].state,'failed');
});
test('Telnyx SMS delivery and terminal retry use the stored provider message identity', async () => {
  const f = fixture('liveness-verification-webhook',{attempt:{method:'sms'}});
  const event = { event_type:'message.finalized',payload:{id:'resource-1',to:[{status:'delivered',carrier:'Fixture'}]} };
  assert.equal((await f.handler(telnyx('liveness-verification-webhook',event))).status,200);
  assert.equal((await f.handler(telnyx('liveness-verification-webhook',{...event,id:'event-2'}))).status,200);
  assert.equal(f.calls.filter(c => c.path.endsWith('/settle_line_verification_event')).length,1);
});
test('Twilio voice and liveness callbacks fail closed and verify the canonical URL including its query', async () => {
  for (const slug of ['twilio-voice-webhook','liveness-verification-webhook']) {
    const params = {CallSid:'resource-1',From:'+100',CallStatus:'ringing',SequenceNumber:'1'};
    let f = fixture(slug,{missingSecret:true}); assert.equal((await f.handler(twilio(slug,params))).status,503); assert.equal(f.mutations().length,0);
    f = fixture(slug); assert.equal((await f.handler(twilio(slug,params,{forged:true}))).status,403); assert.equal(f.mutations().length,0);
    f = fixture(slug,{attempt:{provider:'twilio'}});
    assert.equal((await f.handler(twilio(slug,params,{query:'?target=a%2Fb',headers:{'x-forwarded-host':'attacker.invalid'}}))).status,200);
    assert.equal((await f.handler(twilio(slug,params,{query:'?target=a%2Fb'}))).status,200);
    assert.equal(f.calls.filter(c => /ingest_offline_refill|settle_line_verification_event/.test(c.path)).length,1);
  }
});
test('Twilio failed ingestion returns a retryable error; duplicate IDs with altered signed payloads are rejected', async () => {
  let f = fixture('twilio-voice-webhook',{ingestFailure:true});
  const params={CallSid:'resource-1',From:'+100'};
  assert.equal((await f.handler(twilio('twilio-voice-webhook',params))).status,503);
  f=fixture('twilio-voice-webhook'); assert.equal((await f.handler(twilio('twilio-voice-webhook',params))).status,200);
  assert.equal((await f.handler(twilio('twilio-voice-webhook',{...params,From:'+foreign'}))).status,409);
});

function wabaFixture({ secret='meta-secret', failPersistence=false }={}) {
  let handler, mutations=0, commands=0; const seen=new Set();
  const profile={id:'profile',provider_kind:'meta_cloud',is_enabled:true,ready_state:'ready',expected_sender_number:'+10000000',observed_sender_number:'+10000000',connection_metadata:{phone_number_id:'sender',waba_account_id:'account',app_secret_vault_id:'vault-secret'}};
  const db={from: table=>builder(()=>{
    if(table==='whatsapp_provider_profiles')return {data:[profile],error:null};
    mutations++; return {data:[],error:failPersistence?Error('failed'):null};
  }),rpc:async(name,args)=>{
    if(name==='get_internal_secret')return {data:secret,error:null};
    if(name==='handle_inbound_command'){
      mutations++; if(failPersistence)return {error:Error('failed')};
      if(!seen.has(args.p_provider_msg_id)){seen.add(args.p_provider_msg_id);commands++;}
      return {data:{status:'handled'},error:null};
    }
    throw Error(name);
  }};
  loadEdge('supabase/functions/waba-webhook/index.ts',{serve:fn=>handler=fn,createClient:()=>db,
    env:{SUPABASE_URL:url,SUPABASE_SERVICE_ROLE_KEY:'service'},fetch:async()=>{throw Error('Unexpected outbound send');}});
  const raw=JSON.stringify({entry:[{id:'account',changes:[{value:{metadata:{phone_number_id:'sender'},messages:[{id:'message',from:'10000000',type:'text',text:{body:'BAL'}}],statuses:[{id:'receipt',status:'delivered'}]}}]}]});
  const request=(valid=true)=>new Request(url+'/functions/v1/waba-webhook',{method:'POST',body:raw,headers:{'x-hub-signature-256':valid?'sha256='+createHmac('sha256',secret||'missing').update(raw).digest('hex'):'sha256='+'0'.repeat(64)}});
  return {handler,request,mutations:()=>mutations,commands:()=>commands};
}
test('WhatsApp missing signing secrets and invalid signatures cause no commands or receipt writes',async()=>{
  let f=wabaFixture({secret:null});assert.equal((await f.handler(f.request())).status,503);assert.equal(f.mutations(),0);
  f=wabaFixture();assert.equal((await f.handler(f.request(false))).status,401);assert.equal(f.mutations(),0);
});
test('verified WhatsApp retains command identity on replay and failed persistence remains retryable',async()=>{
  let f=wabaFixture();assert.equal((await f.handler(f.request())).status,200);assert.equal((await f.handler(f.request())).status,200);assert.equal(f.commands(),1);
  f=wabaFixture({failPersistence:true});assert.equal((await f.handler(f.request())).status,503);
});

test('signed unbudgeted legacy calls retain evidence without an unreserved debit; failed writes retry',async()=>{
  let f=fixture('telnyx-cdr');
  const event={event_type:'call.hangup',payload:{call_duration_secs:60,hangup_cause:'normal_clearing'}};
  assert.equal((await f.handler(telnyx('telnyx-cdr',event))).status,200);
  assert.equal((await f.handler(telnyx('telnyx-cdr',event))).status,200);
  assert.equal(f.calls.filter(c=>c.path.endsWith('/debit_wallet_for_call')).length,0);
  assert.equal(f.calls.find(c=>c.body?.reconciliation_reason==='legacy_call_budget').body.billing_state,'reconciliation_required');
  for(const options of [{patchFailure:true}]){
    f=fixture('telnyx-cdr',options);assert.equal((await f.handler(telnyx('telnyx-cdr',event))).status,503);
    assert.equal([...f.receipts.values()][0].state,'failed');
  }
});
test('Twilio canonical documentation vector validates and configured query tampering fails',async()=>{
  const h=loadEdge('supabase/functions/_shared/webhook-auth.ts');
  const params={CallSid:'CA1234567890ABCDE',Caller:'+14158675310',Digits:'1234',From:'+14158675310',To:'+18005551212'};
  const req=new Request('https://example.com/myapp.php?foo=1&bar=2',{method:'POST',headers:{'x-twilio-signature':'L/OH5YylLD5NRKLltdqwSvS0BnU='}});
  const verified=await h.verifyTwilio(req,new URLSearchParams(params).toString(),'12345',req.url);
  assert.equal(verified.CallSid,params.CallSid);
  assert.throws(()=>h.webhookUrl(req,'https://example.com/myapp.php?foo=2&bar=2',url,'unused'),e=>e.status===403);
});
test('Telnyx key decoding accepts raw base64, exact SPKI and hex forms',async()=>{
  for(const value of [keys.publicKey.export({format:'der',type:'spki'}).toString('base64'),Buffer.from(publicKey,'base64').toString('hex')]){
    const f=fixture('liveness-verification-webhook',{env:{TELNYX_PUBLIC_KEY:value}});
    assert.equal((await f.handler(telnyx('liveness-verification-webhook'))).status,200);
  }
});

test('legitimate retry metadata and form ordering do not change an authenticated event identity',async()=>{
  const f=fixture('liveness-verification-webhook');
  assert.equal((await f.handler(telnyx('liveness-verification-webhook',{meta:{attempt:1,delivered_to:'first'}}))).status,200);
  assert.equal((await f.handler(telnyx('liveness-verification-webhook',{meta:{attempt:2,delivered_to:'failover'}}))).status,200);
  assert.equal(f.calls.filter(c=>c.path.endsWith('/settle_line_verification_event')).length,1);
  const voice=fixture('twilio-voice-webhook');
  assert.equal((await voice.handler(twilio('twilio-voice-webhook',{From:'+100',CallSid:'resource-1'}))).status,200);
  assert.equal((await voice.handler(twilio('twilio-voice-webhook',{CallSid:'resource-1',From:'+100'}))).status,200);
  assert.equal(voice.calls.filter(c=>c.path.endsWith('/ingest_offline_refill')).length,1);
});

test('authenticated call endings without observed ringing never award provider verification',async()=>{
 for(const hangup_cause of ['normal_clearing','user_busy','no_answer','timeout']){
  const f=fixture('liveness-verification-webhook');
  assert.equal((await f.handler(telnyx('liveness-verification-webhook',{event_type:'call.hangup',payload:{hangup_cause}}))).status,200);
  const settlement=f.calls.find(c=>c.path.endsWith('/settle_line_verification_event'));
  assert.equal(settlement.body.p_outcome,'inconclusive');assert.equal(settlement.body.p_event_type,'call.hangup');
 }
});
test('authenticated SMS callback rejects foreign or multiple destination records',async()=>{
 for(const to of [[{status:'delivered',phone_number:'+foreign'}],[{status:'delivered'},{status:'delivered'}]]){
  const f=fixture('liveness-verification-webhook',{attempt:{method:'sms',destination_phone:'+15550001011'}});
  assert.equal((await f.handler(telnyx('liveness-verification-webhook',{event_type:'message.finalized',payload:{id:'resource-1',to}}))).status,403);
  assert.equal(f.calls.some(c=>c.path.endsWith('/settle_line_verification_event')),false);
 }
});
