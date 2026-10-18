// Task 4: actual PostgreSQL semantics in PGlite, without network/production writes.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';
const { PGlite } = await import(process.env.PGLITE_MODULE_PATH
  ? pathToFileURL(process.env.PGLITE_MODULE_PATH).href : '@electric-sql/pglite');
const db = new PGlite();
const read = p => fs.readFileSync(new URL('../../'+p,import.meta.url),'utf8');
let count=0;
async function test(name, run) { await run(); console.log('PASS '+name); count++; }
async function asRole(role, run) {
  await db.exec('BEGIN');
  try { await db.exec('SET LOCAL ROLE '+role); await db.query("select set_config('request.jwt.claims',$1,true)",[JSON.stringify({role})]); return await run(); }
  finally { await db.exec('ROLLBACK'); }
}
const claim = async (event='event-1',resource='resource-1',hash='a'.repeat(64)) =>
  (await db.query('select public.claim_verified_webhook($1,$2,$3,$4) as value',['telnyx',event,resource,hash])).rows[0].value;
const finish = (event,token,success) => db.query('select public.finish_verified_webhook($1,$2,$3,$4)',['telnyx',event,token,success]);
try {
  await db.exec(read('supabase/tests/fixtures/endpoint_webhook_authentication.sql'));
  await db.exec(read('supabase/migrations/20261017100000_endpoint_webhook_authentication.sql'));
  await test('private receipt table rejects all direct API-role reads/writes despite unsafe defaults', async()=>{
    for(const role of ['anon','authenticated','service_role']) {
      await assert.rejects(asRole(role,()=>db.query('select * from public.verified_webhook_events')),e=>e.code==='42501');
      await assert.rejects(asRole(role,()=>db.query('delete from public.verified_webhook_events')),e=>e.code==='42501');
    }
  });
  await test('anonymous and authenticated callers cannot claim or finish events',async()=>{
    for(const role of ['anon','authenticated']) {
      await assert.rejects(asRole(role,()=>claim()),e=>e.code==='42501');
      await assert.rejects(asRole(role,()=>finish('e','10000000-0000-4000-8000-000000000001',true)),e=>e.code==='42501');
    }
  });
  await test('definer bodies reject a non-service identity even with accidental execute access',async()=>{
    await db.exec('GRANT EXECUTE ON FUNCTION public.claim_verified_webhook(text,text,text,text) TO authenticated');
    await assert.rejects(asRole('authenticated',()=>claim()),e=>e.code==='42501');
    await db.exec('REVOKE EXECUTE ON FUNCTION public.claim_verified_webhook(text,text,text,text) FROM authenticated');
  });
  await test('service claim, completion and replay are idempotent',()=>asRole('service_role',async()=>{
    const c=await claim(); assert.equal(c.state,'claimed'); await finish('event-1',c.token,true);
    assert.equal((await claim()).state,'completed');
    await finish('event-1',c.token,false); assert.equal((await claim()).state,'completed');
  }));
  await test('conflicting payload or resource cannot reuse an event identity',()=>asRole('service_role',async()=>{
    await claim(); assert.equal((await claim('event-1','resource-1','b'.repeat(64))).state,'conflict');
    assert.equal((await claim('event-1','foreign-resource')).state,'conflict');
  }));
  await test('overlapping claims for one resource admit one worker; separate resources remain available',()=>asRole('service_role',async()=>{
    const claims=await Promise.all([claim('a'),claim('b')]);
    assert.deepEqual(claims.map(c=>c.state).sort(),['busy','claimed']);
    assert.equal((await claim('c','resource-2')).state,'claimed');
  }));
  await test('explicit failure permits a retry with a new token and rejects old completion tokens',async()=>{
    await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({role:'service_role'})]);
    const first=await claim('retry'); await finish('retry',first.token,false);
    const second=await claim('retry'); assert.notEqual(first.token,second.token);
    await assert.rejects(finish('retry',first.token,true),e=>e.code==='42501');
    await finish('retry',second.token,true);
  });
  await test('abandoned processing is not stolen after a timeout',async()=>{
    const first=await claim('abandoned','abandoned-resource');
    await db.query("update public.verified_webhook_events set updated_at=now()-interval '1 day' where event_id='abandoned'");
    assert.equal((await claim('abandoned','abandoned-resource')).state,'busy');
    await finish('abandoned',first.token,true);
  });
  await test('legacy processed events stay completed after migration',async()=>{
    assert.equal((await claim('legacy-event','old-resource')).state,'completed');
  });
  await test('new voicemail recordings have a unique source identity while legacy nulls remain compatible',async()=>{
    const user='10000000-0000-4000-8000-000000000001';
    await db.query('insert into public.voicemail_messages(user_id,source_recording_id) values ($1,$2)',[user,'recording']);
    await assert.rejects(db.query('insert into public.voicemail_messages(user_id,source_recording_id) values ($1,$2)',[user,'recording']),e=>e.code==='23505');
    await db.query('insert into public.voicemail_messages(user_id) values ($1),($1)',[user]);
  });
  await test('forward migration pins safe paths and exact execute grants',async()=>{
    const {rows}=await db.query(`select p.proname,p.prosecdef,p.proconfig,
      has_function_privilege('anon',p.oid,'EXECUTE') as anon,
      has_function_privilege('authenticated',p.oid,'EXECUTE') as authenticated,
      has_function_privilege('service_role',p.oid,'EXECUTE') as service
      from pg_proc p where proname in ('claim_verified_webhook','finish_verified_webhook')`);
    assert.equal(rows.length,2);for(const row of rows){assert.equal(row.prosecdef,true);assert.deepEqual(row.proconfig,['search_path=""']);assert.equal(row.anon,false);assert.equal(row.authenticated,false);assert.equal(row.service,true);}
  });
  await test('read-only deployment catalog check reports no outstanding violations',async()=>{
    assert.deepEqual((await db.query(read('supabase/tests/endpoint_webhook_authentication_tests.sql'))).rows,[]);
  });
  console.log(`${count} webhook SQL regressions passed`);
} finally { await db.close(); }
