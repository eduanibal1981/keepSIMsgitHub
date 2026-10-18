import assert from 'node:assert/strict';
import { snapshot } from './production-fixture.mjs';

const literal=s=>"'"+s.replaceAll("'","''")+"'";
const tables=snapshot.tables.map(literal).join(',');
const order=rows=>rows.map(row=>JSON.stringify(Object.fromEntries(Object.entries(row).sort(([a],[b])=>a.localeCompare(b))))).sort();
const normalize=s=>s?.replace(/\s+/g,' ').trim();
const aclEntries=entries=>Array.isArray(entries)?entries:entries?entries.replace(/^\{|\}$/g,'').split(',').map(x=>x.replace(/^"|"$/g,'')):[];
const acl=entries=>aclEntries(entries).flatMap(entry=>{
  const [,role,privileges]=/^([^=]*)=([^/]+)\//.exec(entry);
  return ['','anon','authenticated','service_role'].includes(role)
    ? [...privileges.matchAll(/([^*])(\*)?/g)].map(([,privilege,grantOption])=>`${role||'PUBLIC'}:${privilege}${grantOption||''}`):[];
}).sort();

// Verify the fixture before migrations can change it. This is a bounded catalog
// comparison, not a claim that unrelated Supabase schemas are reconstructed.
export async function verifyProductionFixture(db){
  const columns=(await db.query(`SELECT c.relname AS "table",a.attname AS "column",
    format_type(a.atttypid,a.atttypmod) AS type,a.attnotnull AS not_null,
    pg_get_expr(d.adbin,d.adrelid) AS "default",a.attgenerated AS generated
    FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace
    LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum
    WHERE n.nspname='public' AND c.relname IN (${tables}) AND a.attnum>0 AND NOT a.attisdropped`)).rows;
  const col=c=>({table:c.table,column:c.column,type:c.type,not_null:c.not_null,default:normalize(c.default),generated:c.generated||''});
  assert.deepEqual(order(columns.map(col)),order(snapshot.columns.map(col)),'captured column types, precision, nullability, defaults and generated expressions');
  const constraints=(await db.query(`SELECT c.relname AS "table",con.conname AS name,
    con.contype AS type,pg_get_constraintdef(con.oid) AS definition FROM pg_constraint con
    JOIN pg_class c ON c.oid=con.conrelid JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relname IN (${tables}) AND con.contype IN ('p','u','c','f')`)).rows;
  // PostgreSQL 17/18 can fold a constant varchar[] -> text[] coercion into
  // per-element casts. Normalize only that deparser difference; keep all
  // operators, values and validation clauses in the comparison.
  const constraintDefinition=s=>normalize(s)
    .replace(/\(\(ARRAY\[([^\]]+)\]\)::text\[\]\)/g,'(ARRAY[$1])')
    .replace(/\(('(?:[^']|'')*')::character varying\)::text/g,'$1::text')
    .replace(/('(?:[^']|'')*')::character varying/g,'$1::text');
  const con=c=>({table:c.table,name:c.name,type:c.type,definition:constraintDefinition(c.definition)});
  assert.deepEqual(order(constraints.map(con)),order(snapshot.constraints.map(con)),'captured CHECK/PK/UNIQUE/FK definitions including NOT VALID');
  const indexes=(await db.query(`SELECT t.relname AS "table",i.relname AS name,pg_get_indexdef(i.oid) AS definition
    FROM pg_index x JOIN pg_class t ON t.oid=x.indrelid JOIN pg_class i ON i.oid=x.indexrelid
    JOIN pg_namespace n ON n.oid=t.relnamespace WHERE n.nspname='public' AND t.relname IN (${tables}) AND x.indisunique`)).rows;
  assert.deepEqual(order(indexes),order(snapshot.indexes.filter(i=>i.unique).map(({table,name,definition})=>({table,name,definition}))),'all captured unique indexes');
  const relations=(await db.query(`SELECT c.relname AS "table",c.relrowsecurity AS rls,
    c.relforcerowsecurity AS force_rls,c.relacl::text[] AS acl FROM pg_class c
    JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname IN (${tables})`)).rows;
  const rel=r=>({table:r.table,rls:r.rls,force_rls:r.force_rls,acl:acl(r.acl)});
  assert.deepEqual(order(relations.map(rel)),order(snapshot.relations.map(rel)),'actual API table grants and RLS flags');
  const policies=(await db.query(`SELECT schemaname,tablename,policyname,permissive,roles::text[] AS roles,cmd,qual,with_check
    FROM pg_policies WHERE schemaname='public' AND tablename IN (${tables})`)).rows;
  const pol=p=>({...p,roles:[...p.roles].sort(),qual:normalize(p.qual),with_check:normalize(p.with_check)});
  assert.deepEqual(order(policies.map(pol)),order(snapshot.policies.map(pol)),'actual RLS predicates and policy roles');
  const columnGrants=(await db.query(`SELECT c.relname AS "table",a.attname AS "column",a.attacl::text[] AS acl
    FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relname IN (${tables}) AND a.attacl IS NOT NULL`)).rows;
  const grant=r=>({table:r.table,column:r.column,acl:acl(r.acl)});
  assert.deepEqual(order(columnGrants.map(grant)),order(snapshot.column_grants.map(grant)),'captured API column grants');
  for(const fn of snapshot.functions){
    const row=(await db.query(`SELECT p.proacl::text[] AS acl,pg_get_functiondef(p.oid) AS definition
      FROM pg_proc p WHERE p.oid=${literal('public.'+fn.signature.replace(/^public\./,''))}::regprocedure`)).rows[0];
    assert.deepEqual(acl(row.acl),acl(fn.proacl),fn.signature+' EXECUTE ACL');
    assert.equal(normalize(row.definition),normalize(fn.definition),fn.signature+' actual definition');
  }
  const triggers=(await db.query(`SELECT c.relname AS "table",t.tgname AS name,pg_get_triggerdef(t.oid) AS definition
    FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relname IN (${tables}) AND NOT t.tgisinternal`)).rows;
  const trig=t=>({table:t.table,name:t.name,definition:normalize(t.definition)});
  assert.deepEqual(order(triggers.map(trig)),order(snapshot.included_triggers.map(trig)),'installed actual trigger definitions; omitted chains stay absent');
  for(const view of snapshot.views){
    const row=(await db.query(`SELECT pg_get_viewdef(c.oid,true) AS definition,c.reloptions AS options,c.relacl::text[] AS acl
      FROM pg_class c WHERE c.oid=${literal('public.'+view.name)}::regclass`)).rows[0];
    assert.equal(normalize(row.definition),normalize(view.definition),view.name+' actual baseline definition');
    assert.deepEqual(row.options,view.options,view.name+' options');
    assert.deepEqual(acl(row.acl),acl(view.acl),view.name+' ACL');
  }
  console.log(`PASS production catalog fidelity: ${columns.length} columns, ${constraints.length} constraints, ${indexes.length} unique indexes, ${policies.length} policies, ${columnGrants.length} column ACLs, ${snapshot.functions.length} functions, ${triggers.length} triggers`);
}
