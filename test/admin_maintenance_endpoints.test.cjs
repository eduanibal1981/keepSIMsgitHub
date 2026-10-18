const {test}=require('node:test');
const assert=require('node:assert/strict');
const {loadEdge}=require('./edge_module_loader.cjs');
const job='10000000-0000-4000-8000-000000000001',user='20000000-0000-4000-8000-000000000001',token='30000000-0000-4000-8000-000000000001';
const env={SUPABASE_URL:'https://project.invalid',SUPABASE_SERVICE_ROLE_KEY:'synthetic-service',RESEND_API_KEY:'synthetic-provider'};
function fixture(options={}){
  const calls=[];let claimed=false,complete=false;
  const client={async rpc(name,args){
    calls.push({name,args});
    if(name==='get_internal_secret')return {data:options.noSecret?null:'synthetic-secret',error:options.secretError?{}:null};
    if(name==='claim_account_purge_job'){
      if(options.claimError)return {error:{message:'private SQL error'}};
      if(options.busy||claimed)return {data:{claimed:false,state:complete?'completed':'busy'}};
      if(options.ineligible)return {data:{claimed:false,state:'review_required'}};
      claimed=true;return {data:{claimed:true,claim_token:token,user_id:user}};
    }
    if(name==='finish_account_purge_job'){
      assert.equal(args.p_claim_token,token);assert.equal(args.p_job_id,job);assert.ok(Object.hasOwn(args,'p_note'));assert.ok(!Object.hasOwn(args,'p_reason'));
      if(options.auditError)return {error:{message:'private audit error'}};
      complete=args.p_success;return {data:true};
    }
    if(name==='claim_admin_email'){
      if(claimed)return {data:{claimed:false}};claimed=true;
      return {data:{claimed:true,claim_token:token,email:{from_address:'from@example.invalid',to_addresses:['to@example.invalid'],cc_addresses:[],subject:'Persisted subject',body_text:'Persisted text'}}};
    }
    if(name==='finish_admin_email')return options.auditError?{error:{message:'private audit error'}}:{data:true};
    throw Error('Unexpected RPC '+name);
  },storage:{from(bucket){return {
    async list(path,{offset}){
      calls.push({name:'list',bucket,path,offset});
      if(options.listError)return {error:{statusCode:403,message:'private permission failure'}};
      if(options.missingBucket)return {error:{statusCode:404}};
      if(options.invalidName)return {data:[{name:'../escape',id:'file'}]};
      const records=path.endsWith('/nested')?[{id:'file',name:'child.txt'}]:
        [{id:null,metadata:null,name:'nested'},...Array.from({length:205},(_,i)=>({id:'file-'+i,name:i+'.txt'}))];
      return {data:records.slice(offset,offset+100)};
    },async remove(paths){calls.push({name:'remove',bucket,paths});return {error:options.removeError?{message:'private storage failure'}:null};}
  };}},auth:{admin:{async deleteUser(id){calls.push({name:'deleteUser',id});return {error:options.authError?{status:500,message:'private Auth failure'}:options.authMissing?{status:404}:null};}}}};
  const fetch=async(address,init)=>{
    calls.push({name:'fetch',address,init});assert.equal(address,'https://api.resend.com/emails');
    if(options.timeout)throw Error('private provider timeout');
    return options.providerError?Response.json({private:'payload'},{status:options.providerError}):Response.json(options.badResponse?{}:{id:'synthetic-email-id'});
  };
  const purge=loadEdge('supabase/functions/purge-accounts/index.ts',{serve:()=>{},createClient:()=>client,env:{...env,...options.env},fetch}).handlePurgeRequest;
  const email=loadEdge('supabase/functions/send-admin-email/index.ts',{serve:()=>{},createClient:()=>client,env:{...env,...options.env},fetch}).handleAdminEmail;
  const request=(body,secret='synthetic-secret',method='POST',header='x-keep-sims-secret')=>new Request('https://project.invalid/endpoint',{
    method,headers:{[header]:secret},...(method==='POST'?{body:typeof body==='string'?body:JSON.stringify(body)}:{})});
  return {calls,purge:(body={job_id:job},secret,method)=>purge(request(body,secret,method)),
    email:(body={email_id:job},secret,method)=>email(request(body,secret,method,'x-sync-secret'))};
}
for(const kind of ['purge','email']){
  test(kind+' rejects wrong/missing secret, Vault errors and missing configuration before irreversible work',async()=>{
    for(const option of [{secretError:true},{noSecret:true},{env:{SUPABASE_SERVICE_ROLE_KEY:''}},{}]){
      const f=fixture(option);const r=await f[kind](undefined,'wrong-secret');assert.ok([401,503].includes(r.status));
      assert.equal(f.calls.some(c=>['deleteUser','fetch','claim_account_purge_job','claim_admin_email'].includes(c.name)),false);
    }
  });
  test(kind+' rejects malformed JSON/IDs and non-POST requests',async()=>{
    for(const body of ['{bad',null,{},kind==='purge'?{job_id:'bad'}:{email_id:'bad'}]){
      const f=fixture();assert.equal((await f[kind](body)).status,400);assert.equal(f.calls.some(c=>c.name.startsWith('claim_')),false);
    }
    assert.equal((await fixture()[kind](undefined,undefined,'GET')).status,405);
  });
}
test('raw user/admin purge payloads cannot bypass a persisted authorized job',async()=>{
  const f=fixture();assert.equal((await f.purge({user_id:user,admin_purge:true,confirm_user_id:user})).status,400);
  assert.equal(f.calls.some(c=>c.name==='deleteUser'),false);
});
test('paginated nested attachments are all removed before Auth, then audited completion',async()=>{
  const f=fixture();assert.equal((await f.purge()).status,200);
  const removes=f.calls.filter(c=>c.name==='remove');assert.equal(removes.reduce((n,r)=>n+r.paths.length,0),412);
  assert.ok(removes.every(r=>r.paths.length<=100&&r.paths.every(p=>p.startsWith(user+'/'))));
  const lastRemove=f.calls.findLastIndex(c=>c.name==='remove'),auth=f.calls.findIndex(c=>c.name==='deleteUser'),finish=f.calls.findIndex(c=>c.name==='finish_account_purge_job');
  assert.ok(lastRemove<auth&&auth<finish);assert.equal(f.calls[finish].args.p_success,true);
  assert.equal((await f.purge()).status,200);assert.equal(f.calls.filter(c=>c.name==='deleteUser').length,1);
});
for(const error of ['listError','removeError','invalidName'])test(error+' records storage failure and never starts Auth deletion',async()=>{
  const f=fixture({[error]:true});const r=await f.purge();assert.equal(r.status,503);
  assert.equal(f.calls.some(c=>c.name==='deleteUser'),false);assert.equal(f.calls.find(c=>c.name==='finish_account_purge_job').args.p_note,'storage_failed');
  assert.ok(!(await r.text()).includes('private'));
});
test('Auth failure persists failed state, has no raw SQL fallback and does not report completion',async()=>{
  const f=fixture({authError:true});const r=await f.purge();assert.equal(r.status,503);
  assert.equal(f.calls.some(c=>c.name==='delete_auth_user_by_id'),false);
  assert.equal(f.calls.find(c=>c.name==='finish_account_purge_job').args.p_success,false);
});
test('missing buckets and already absent Auth are idempotent completion paths',async()=>{
  assert.equal((await fixture({missingBucket:true,authMissing:true}).purge()).status,200);
});
test('failed completion/audit RPC never reports completed, even after Auth deletion',async()=>{
  const f=fixture({auditError:true});assert.equal((await f.purge()).status,503);
  assert.equal(f.calls.filter(c=>c.name==='finish_account_purge_job').length,2);
});
test('ineligible/busy jobs and claim failures perform no cleanup',async()=>{
  for(const options of [{busy:true},{ineligible:true},{claimError:true}]){
    const f=fixture(options);assert.ok([202,409,503].includes((await f.purge()).status));assert.equal(f.calls.some(c=>c.name==='list'||c.name==='deleteUser'),false);
  }
});
test('email uses only the persisted envelope, an idempotency key, and provider acceptance wording',async()=>{
  const f=fixture();const r=await f.email({email_id:job,to:['attacker@example.invalid']});assert.equal(r.status,200);assert.equal((await r.json()).status,'accepted_by_provider');
  const c=f.calls.find(c=>c.name==='fetch');assert.equal(c.init.headers['Idempotency-Key'],'admin-email-'+job);
  assert.deepEqual(JSON.parse(c.init.body).to,['to@example.invalid']);assert.equal((await f.email()).status,202);assert.equal(f.calls.filter(c=>c.name==='fetch').length,1);
});
for(const options of [{timeout:true},{providerError:500},{providerError:409},{badResponse:true}])test('ambiguous email outcome '+JSON.stringify(options)+' is retained without automatic retry',async()=>{
  const f=fixture(options);assert.equal((await f.email()).status,503);
  assert.equal(f.calls.find(c=>c.name==='finish_admin_email').args.p_error_code,'provider_outcome_unknown');
  await f.email();assert.equal(f.calls.filter(c=>c.name==='fetch').length,1);
});
test('explicit email provider rejection records failure and missing provider configuration leaves it unclaimed',async()=>{
  const f=fixture({providerError:400});assert.equal((await f.email()).status,503);assert.equal(f.calls.find(c=>c.name==='finish_admin_email').args.p_error_code,'provider_rejected');
  const missing=fixture({env:{RESEND_API_KEY:''}});assert.equal((await missing.email()).status,503);assert.equal(missing.calls.some(c=>c.name==='claim_admin_email'),false);
});
test('email outcome persistence failure returns error without claiming success',async()=>{
  assert.equal((await fixture({auditError:true}).email()).status,503);
});
