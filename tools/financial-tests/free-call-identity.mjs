// Native, isolated Postgres: real pgcrypto, migration, ACLs and independent sessions.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import net from 'node:net';
import {randomUUID} from 'node:crypto';
import EmbeddedPostgres from 'embedded-postgres';
const root = new URL('../../', import.meta.url);
const read = file => fs.readFile(new URL(file,root),'utf8');
const port=await new Promise(resolve=>{const s=net.createServer();s.listen(0,'127.0.0.1',()=>{const p=s.address().port;s.close(()=>resolve(p));});});
const dir=await fs.mkdtemp(path.join(os.tmpdir(),'keepsims-free-call-'));
const server=new EmbeddedPostgres({databaseDir:dir,user:'postgres',password:randomUUID(),port,persistent:false,
  initdbFlags:['--locale=C'],postgresFlags:['-h','127.0.0.1','-k','/tmp'],onLog(){},onError(){}});
const clients=[];
const connect=async()=>{const c=server.getPgClient();await c.connect();clients.push(c);return c;};
const scalar=async(c,sql,args=[])=>Object.values((await c.query(sql,args)).rows[0])[0];
const results=[];
async function check(name,body){ await body(); results.push(name); console.log('PASS '+name); }
async function auth(c,id,role='authenticated',extra={}){
  await c.query('RESET ROLE'); await c.query('SET ROLE '+role);
  await c.query("SELECT set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub:id,role,...extra})]);
}
let owner;
async function seed({country=null,phone=null,verified=true}={}){
  const id=randomUUID();
  await owner.query('RESET ROLE');
  await owner.query('INSERT INTO auth.users(id,email,email_confirmed_at,phone,phone_confirmed_at,raw_app_meta_data) VALUES($1,$2,$3,$4,$5,$6)',
    [id,id+'@example.test',verified?new Date():null,phone,phone&&verified?new Date():null,JSON.stringify(country?{registration_country:country}:{})]);
  await owner.query("INSERT INTO profiles(id,full_name,phone) VALUES($1,'Fixture account','+15550009999')",[id]);
  return id;
}
async function lookup(c,type,value){return scalar(c,'SELECT resolve_free_call_identity($1,$2)',[type,value]);}
async function idFor(id){return scalar(owner,'SELECT public_id FROM free_call_private.identities WHERE user_id=$1',[id]);}
try {
  await server.initialise(); await server.start(); owner=await connect();
  await owner.query(await read('supabase/tests/fixtures/free_call_identity.sql'));
  const baseline=await read('supabase/tests/platform/current_public_schema.sql');
  const quota=baseline.match(/CREATE OR REPLACE FUNCTION "public"\."consume_rate_limit"[\s\S]*?\$\$;/)[0];
  await owner.query(quota);
  const files=await fs.readdir(new URL('supabase/migrations/',root));
  const migration=await read('supabase/migrations/'+files.find(f=>f.endsWith('_universal_free_call_identity.sql')));
  await owner.query(migration);
  const a=await connect(), b=await connect();
  await check('legacy backfill is neutral and repeated provisioning is idempotent',async()=>{
    const u='00000000-0000-4000-8000-000000000001',id=await idFor(u);
    assert.match(id,/^KXX-[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{8}$/);
    assert.equal(await scalar(owner,'SELECT free_call_private.issue_identity($1)',[u]),id);
    assert.equal(Number(await scalar(owner,'SELECT count(*) FROM profiles')),1);
  });
  await check('secure generator uses pgcrypto and all 31 readable characters without modulo bias',async()=>{
    assert.match(migration,/extensions\.gen_random_bytes\(16\)/);
    assert.match(migration,/v_byte < 248/);
    const ids=[];for(let i=0;i<80;i++)ids.push(await idFor(await seed({country:'OM'})));
    assert.equal(new Set(ids).size,80);for(const id of ids)assert.match(id,/^KOM-[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{8}$/);
    assert.equal(new Set(ids.join('').replace(/KOM-|-/g,'')).size,31);
  });
  await check('registration country is validated and SIM/profile country is never inferred',async()=>{
    for(const [country,prefix] of [['EG','KEG-'],['SA','KSA-'],['IN','KIN-'],['ZZ','KXX-'],[null,'KXX-']])assert((await idFor(await seed({country}))).startsWith(prefix));
  });
  await check('identity remains immutable and survives deletion as a non-recyclable tombstone',async()=>{
    const u=await seed(),id=await idFor(u);
    await assert.rejects(()=>owner.query("UPDATE free_call_private.identities SET public_id='KXX-22222222' WHERE user_id=$1",[u]),/immutable/);
    await assert.rejects(()=>owner.query('DELETE FROM free_call_private.identities WHERE user_id=$1',[u]),/never recycled/);
    await owner.query('DELETE FROM auth.users WHERE id=$1',[u]);
    assert.equal(await scalar(owner,'SELECT user_id FROM free_call_private.identities WHERE public_id=$1',[id]),null);
    await assert.rejects(()=>owner.query('TRUNCATE free_call_private.identities'),/never recycled/);
  });
  await check('concurrent lazy provisioning adopts exactly one alias',async()=>{
    await owner.query('ALTER TABLE auth.users DISABLE TRIGGER provision_free_call_identity');
    const u=await seed();await owner.query('ALTER TABLE auth.users ENABLE TRIGGER provision_free_call_identity');
    const ids=await Promise.all([a,b].map(c=>scalar(c,'SELECT free_call_private.issue_identity($1)',[u])));
    assert.equal(ids[0],ids[1]);assert.equal(Number(await scalar(owner,'SELECT count(*) FROM free_call_private.identities WHERE user_id=$1',[u])),1);
  });
  await check('secure collisions retry and exhaust a bounded allocation safely',async()=>{
    const definition=await scalar(owner,"SELECT pg_get_functiondef('extensions.gen_random_bytes(integer)'::regprocedure)");
    await owner.query("CREATE OR REPLACE FUNCTION extensions.gen_random_bytes(integer) RETURNS bytea LANGUAGE sql AS $$ SELECT decode(repeat('00',$1),'hex') $$");
    try {
      const u=await seed({country:'AE'});assert.equal(await idFor(u),'KAE-22222222');
      await assert.rejects(()=>seed({country:'AE'}),/Unable to allocate/);
    } finally {await owner.query(definition);}
  });
  await check('all public APIs require active authenticated users and private data has no client grants',async()=>{
    const u=await seed(); await auth(a,u,'anon');
    await assert.rejects(()=>lookup(a,'email',u+'@example.test'),/permission denied/);
    await auth(a,null);await assert.rejects(()=>lookup(a,'id','KXX-22222222'),/Authentication required/);
    await auth(a,u);
    for(const table of ['identities','phone_consents','blocks','resolutions'])await assert.rejects(()=>a.query('SELECT * FROM free_call_private.'+table),/permission denied/);
    const own=await scalar(a,'SELECT get_free_call_identity()');assert.equal(own.public_id,await idFor(u));assert.equal(own.discover_by_email,false);
    assert.equal(await scalar(owner,"SELECT has_function_privilege('service_role','resolve_free_call_identity(text,text)','EXECUTE')"),false);
  });
  await check('complete normalized ID resolves one canonical account with minimal data and no fake history',async()=>{
    const caller=await seed(),target=await seed({country:'EG'}),id=await idFor(target);await auth(a,caller);
    const before=await scalar(owner,'SELECT count(*) FROM voip_call_sessions');
    const r=await lookup(a,'id',' '+id.toLowerCase().replace('-',' - ')+' ');
    assert.equal(r.status,'found');assert.equal(r.recipient.user_id,target);assert.equal(r.recipient.public_id,id);
    assert.equal(r.recipient.phone,undefined);assert.equal(r.recipient.email,undefined);
    assert.equal((await lookup(a,'id',id.slice(0,6))).status,'invalid');
    assert.equal(await scalar(owner,'SELECT count(*) FROM voip_call_sessions'),before);
  });
  await check('verified phones need explicit consent; SIM/test-pass/profile values cannot authorize discovery',async()=>{
    const caller=await seed(),target=await seed({phone:'96891234567'});await auth(a,caller);await auth(b,target);
    assert.equal((await lookup(a,'phone','+96891234567')).status,'not_found');
    await scalar(b,"SELECT set_free_call_phone_discovery('+96891234567',true)");
    assert.equal((await lookup(a,'phone','+96891234567')).recipient.user_id,target);
    assert.equal((await lookup(a,'phone','+968')).status,'invalid');
    assert.equal((await lookup(a,'phone','+20191234567')).status,'not_found');
    await owner.query("INSERT INTO sim_lines VALUES($1,'+96892345678','test_pass')",[target]);
    await assert.rejects(()=>scalar(b,"SELECT set_free_call_phone_discovery('+96892345678',true)"),/not available/);
    assert.equal((await lookup(a,'phone','+96892345678')).status,'not_found');
    await assert.rejects(()=>scalar(b,"SELECT set_free_call_phone_discovery('+15550009999',true)"),/not available/);
  });
  await check('multiple real verified numbers resolve to one account; conflicts and unverified numbers fail closed',async()=>{
    const caller=await seed(),target=await seed();await auth(a,caller);await auth(b,target);
    await owner.query("INSERT INTO user_caller_ids(user_id,phone_number,is_verified,verified_at) VALUES($1,'+201012345678',true,now()),($1,'+96893456789',true,now()),($1,'+96894567890',false,null)",[target]);
    for(const phone of ['+201012345678','+96893456789']){
      await scalar(b,'SELECT set_free_call_phone_discovery($1,true)',[phone]);
      assert.equal((await lookup(a,'phone',phone)).recipient.user_id,target);
    }
    await assert.rejects(()=>scalar(b,"SELECT set_free_call_phone_discovery('+96894567890',true)"),/not available/);
    const other=await seed();await owner.query("INSERT INTO user_caller_ids(user_id,phone_number,is_verified,verified_at) VALUES($1,'+201012345678',true,now())",[other]);
    assert.equal((await lookup(a,'phone','+201012345678')).status,'not_found');
  });
  await check('unlinking, editing or reverifying a phone invalidates the old proof consent',async()=>{
    const caller=await seed(),target=await seed();await auth(a,caller);await auth(b,target);
    await owner.query("INSERT INTO user_caller_ids(user_id,phone_number,is_verified,verified_at) VALUES($1,'+96895678901',true,now())",[target]);
    await scalar(b,"SELECT set_free_call_phone_discovery('+96895678901',true)");
    await owner.query("UPDATE user_caller_ids SET verified_at=now()+interval '1 second' WHERE user_id=$1",[target]);
    assert.equal((await lookup(a,'phone','+96895678901')).status,'not_found');
    await scalar(b,"SELECT set_free_call_phone_discovery('+96895678901',true)");
    await owner.query('DELETE FROM user_caller_ids WHERE user_id=$1',[target]);
    assert.equal((await lookup(a,'phone','+96895678901')).status,'not_found');
  });
  await check('email is exact, verified and off by default; changed emails require fresh consent',async()=>{
    const caller=await seed(),target=await seed();await auth(a,caller);await auth(b,target);
    assert.equal((await lookup(a,'email',target+'@example.test')).status,'not_found');
    await scalar(b,'SELECT set_free_call_discovery(true,true)');
    assert.equal((await lookup(a,'email',(target+'@example.test').toUpperCase())).recipient.user_id,target);
    assert.equal((await lookup(a,'email','user@')).status,'invalid');
    await owner.query("UPDATE auth.users SET email='changed@example.test' WHERE id=$1",[target]);
    assert.equal((await lookup(a,'email','changed@example.test')).status,'not_found');
    assert.equal((await lookup(a,'email',target+'@example.test')).status,'not_found');
    await scalar(b,'SELECT set_free_call_discovery(true,true)');
    await owner.query('UPDATE auth.users SET email_confirmed_at=null WHERE id=$1',[target]);
    assert.equal((await lookup(a,'email','changed@example.test')).status,'not_found');
  });
  await check('blocks in either direction, hidden, suspended, banned and deleted targets share no-match output',async()=>{
    const caller=await seed(),target=await seed(),id=await idFor(target);await auth(a,caller);await auth(b,target);
    const hidden={status:'not_found'};
    await scalar(b,'SELECT set_free_call_discovery(false,false)');assert.deepEqual(await lookup(a,'id',id),hidden);
    await scalar(b,'SELECT set_free_call_discovery(true,false)');
    await scalar(b,'SELECT set_free_call_block($1,true)',[caller]);assert.deepEqual(await lookup(a,'id',id),hidden);
    await scalar(b,'SELECT set_free_call_block($1,false)',[caller]);
    await owner.query('UPDATE profiles SET is_suspended=true WHERE id=$1',[target]);assert.deepEqual(await lookup(a,'id',id),hidden);
    await owner.query('UPDATE profiles SET is_suspended=false WHERE id=$1',[target]);
    await owner.query("UPDATE auth.users SET banned_until=now()+interval '1 day' WHERE id=$1",[target]);assert.deepEqual(await lookup(a,'id',id),hidden);
    await owner.query('UPDATE auth.users SET banned_until=null WHERE id=$1',[target]);
    await owner.query("INSERT INTO account_deletions VALUES($1,'requested')",[target]);assert.deepEqual(await lookup(a,'id',id),hidden);
  });
  await check('expired/revoked auth sessions and suspended callers cannot use APIs',async()=>{
    const caller=await seed();await auth(a,caller,'authenticated',{session_id:randomUUID()});
    await assert.rejects(()=>scalar(a,'SELECT get_free_call_identity()'),/Authentication required/);
    await auth(a,caller);await owner.query('UPDATE profiles SET is_suspended=true WHERE id=$1',[caller]);
    await assert.rejects(()=>lookup(a,'id','KXX-22222222'),/Authentication required/);
  });
  await check('account and signed session rate limits persist and cannot be bypassed by different identifier types',async()=>{
    const caller=await seed();await auth(a,caller);let limited=0;
    for(let i=0;i<23;i++)if((await lookup(a,i%2?'email':'id',i%2?'no@example.test':'KXX-22222222')).status==='rate_limited')limited++;
    assert(limited>=3);
    const c=await seed(),session=randomUUID();await owner.query('INSERT INTO auth.sessions VALUES($1,$2)',[session,c]);
    await auth(b,c,'authenticated',{session_id:session});let sessionLimited=0;
    for(let i=0;i<17;i++)if((await lookup(b,'id','KXX-22222222')).status==='rate_limited')sessionLimited++;
    assert(sessionLimited>=2);
  });
  await check('ID, phone and email lookup feed the existing canonical call session path',async()=>{
    for(const mode of ['id','phone','email']){
      const caller=await seed(),target=await seed({phone:'9689'+Math.floor(1000000+Math.random()*8000000)});
      await auth(a,caller);await auth(b,target);await scalar(b,'SELECT set_free_call_discovery(true,true)');
      const phone=await scalar(owner,"SELECT '+'||phone FROM auth.users WHERE id=$1",[target]);
      await scalar(b,'SELECT set_free_call_phone_discovery($1,true)',[phone]);
      const r=await lookup(a,mode,mode==='id'?await idFor(target):mode==='phone'?phone:target+'@example.test');
      assert.equal(r.recipient.user_id,target);
      const call=await scalar(owner,"INSERT INTO voip_call_sessions(caller_id,callee_id) VALUES($1,$2) RETURNING id",[caller,r.recipient.user_id]);
      assert.equal(await scalar(owner,'SELECT callee_id FROM voip_call_sessions WHERE id=$1',[call]),target);
      assert.equal((await scalar(a,'SELECT resolve_free_call_recipient(null,$1)',[target])).recipient.user_id,target);
      const history=await scalar(a,'SELECT get_free_call_history()');assert.equal(history.length,1);assert.equal(history[0].peer_public_id,await idFor(target));assert.equal(history[0].peer_phone,'');
      await scalar(b,'SELECT set_free_call_block($1,true)',[caller]);
      await assert.rejects(()=>owner.query('INSERT INTO voip_call_sessions(caller_id,callee_id) VALUES($1,$2)',[caller,target]),/unavailable/);
    }
  });
  await check('arbitrary UUID calling is rejected while existing accepted household calling remains compatible',async()=>{
    const caller=await seed(),target=await seed();await auth(a,caller);
    assert.equal((await scalar(a,'SELECT resolve_free_call_recipient(null,$1)',[target])).status,'unavailable');
    await assert.rejects(()=>owner.query('INSERT INTO voip_call_sessions(caller_id,callee_id) VALUES($1,$2)',[caller,target]),/unavailable/);
    await owner.query("INSERT INTO household_members VALUES($1,$2,'accepted')",[caller,target]);
    assert.equal((await scalar(a,'SELECT resolve_free_call_recipient(null,$1)',[target])).status,'found');
    await owner.query('INSERT INTO voip_call_sessions(caller_id,callee_id) VALUES($1,$2)',[caller,target]);
  });
  console.log(`PASS ${results.length} isolated native database scenarios`);
} finally {
  for(const c of clients)await c.end().catch(()=>{});
  await server.stop().catch(()=>{});await fs.rm(dir,{recursive:true,force:true});
}
