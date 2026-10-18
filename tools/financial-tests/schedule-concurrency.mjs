import assert from 'node:assert/strict';

// Real independent PostgreSQL connections; synthetic data only.
export async function runScheduleConcurrency(server, owner, check) {
 const one=server.getPgClient(),two=server.getPgClient();
 await one.connect();await two.connect();
 const line='20000000-0000-4000-8000-000000000001';
 const user='10000000-0000-4000-8000-000000000001';
 const save="SELECT public.save_customer_schedule($1,'refill_custom',14,$2,true,'fixed',null,3) AS schedule";
 const auth=async c=>{await c.query('SET ROLE authenticated');await c.query("SELECT set_config('request.jwt.claims',$1,false)",[JSON.stringify({role:'authenticated',sub:user})]);};
 let sid;
 try {
  await auth(one);await auth(two);
  await check('independent simultaneous schedule saves retain one parent and one next occurrence',async()=>{
   const at=new Date(Date.now()+86400000).toISOString();
   const r=await Promise.all([one.query(save,[line,at]),two.query(save,[line,at])]);
   sid=r[0].rows[0].schedule.id;assert.equal(sid,r[1].rows[0].schedule.id);
   const rows=await owner.query("SELECT * FROM public.topup_executions WHERE scheduled_topup_id=$1 AND status='pending'",[sid]);
   assert.equal(rows.rowCount,1);assert.equal(rows.rows[0].payment_gateway_code,'wallet');
  });
  await check('worker row lock rejects a concurrent settings edit without deadlock or partial update',async()=>{
   await one.query('RESET ROLE');await one.query('BEGIN');
   try {
    await one.query("SELECT id FROM public.topup_executions WHERE scheduled_topup_id=$1 AND status='pending' FOR UPDATE",[sid]);
    await two.query("SET statement_timeout='3s'");
    await assert.rejects(()=>two.query(save,[line,new Date(Date.now()+2*86400000).toISOString()]),e=>e.code==='55P03');
    const s=(await owner.query('SELECT frequency_days,next_execution_at FROM public.scheduled_topups WHERE id=$1',[sid])).rows[0];
    assert.equal(s.frequency_days,14);
    assert.ok(new Date(s.next_execution_at).getTime()<Date.now()+1.1*86400000);
   } finally {await one.query('ROLLBACK');}
  });
  await check('independent workers claim a due validated occurrence exactly once',async()=>{
   await auth(one);await one.query(save,[line,new Date().toISOString()]);
   await one.query('SET ROLE service_role');await two.query('SET ROLE service_role');
   await one.query('BEGIN');await two.query('BEGIN');
   try {
    const r=await Promise.all([one.query("SELECT * FROM public.claim_due_executions('refill_custom',10)"),two.query("SELECT * FROM public.claim_due_executions('refill_custom',10)")]);
    assert.equal(r[0].rowCount+r[1].rowCount,1);
    await one.query('COMMIT');await two.query('COMMIT');
    assert.equal((await owner.query("SELECT count(*)::int AS n FROM public.topup_executions WHERE scheduled_topup_id=$1 AND status='processing'",[sid])).rows[0].n,1);
   } catch(e){await one.query('ROLLBACK');await two.query('ROLLBACK');throw e;}
  });
 } finally {await one.end();await two.end();}
}
