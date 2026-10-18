// Rebuild a bounded production catalog snapshot in an isolated database only.
import fs from 'node:fs';
export const snapshot=JSON.parse(fs.readFileSync(new URL('../../supabase/tests/fixtures/financial_production_snapshot.json',import.meta.url),'utf8'));
const q=s=>'"'+s.replaceAll('"','""')+'"';
const roles=new Set(['anon','authenticated','service_role']);
function aclEntries(acl){return Array.isArray(acl)?acl:acl?acl.replace(/^\{|\}$/g,'').split(',').map(x=>x.replace(/^"|"$/g,'')):[];}
const privileges={r:'SELECT',a:'INSERT',w:'UPDATE',d:'DELETE',D:'TRUNCATE',x:'REFERENCES',t:'TRIGGER',m:'MAINTAIN'};
async function grantAcl(db,object,acl,column){
  for(const entry of aclEntries(acl)){
    const match=/^([^=]*)=([^/]+)\//.exec(entry);if(!match)continue;
    const [,role,letters]=match;if(role&&!roles.has(role))continue;
    for(const [,letter,grantOption] of letters.matchAll(/([^*])(\*)?/g)){
      const privilege=object.startsWith('FUNCTION ')?letter==='X'?'EXECUTE':null:privileges[letter];
      if(!privilege)continue;
      const target=column?`${privilege} (${q(column)}) ON TABLE ${object}`:`${privilege} ON ${object}`;
      await db.exec(`GRANT ${target} TO ${role?q(role):'PUBLIC'}${grantOption?' WITH GRANT OPTION':''}`);
    }
  }
}
export async function createProductionTables(db){
  for(const table of snapshot.tables){
    const columns=snapshot.columns.filter(c=>c.table===table).map(c=>`${q(c.column)} ${c.type}${c.generated?' GENERATED ALWAYS AS ('+c.default+') STORED':c.default?' DEFAULT '+c.default:''}${c.not_null?' NOT NULL':''}`);
    await db.exec(`CREATE TABLE public.${q(table)} (${columns.join(',\n')});`);
  }
  // Referenced unique keys must precede all foreign keys, including circular FKs.
  for(const kind of ['p','u','c','f'])for(const c of snapshot.constraints.filter(c=>c.type===kind)){
    await db.exec(`ALTER TABLE public.${q(c.table)} ADD CONSTRAINT ${q(c.name)} ${c.definition};`);
  }
  for(const index of snapshot.indexes.filter(i=>i.unique&&!snapshot.constraints.some(c=>c.name===i.name)))await db.exec(index.definition);
  for(const view of snapshot.views){
    await db.exec(`CREATE VIEW public.${q(view.name)}${view.options?.length?' WITH ('+view.options.join(',')+')':''} AS ${view.definition}`);
    await db.exec(`REVOKE ALL ON public.${q(view.name)} FROM PUBLIC,anon,authenticated,service_role`);
    await grantAcl(db,'TABLE public.'+q(view.name),view.acl);
  }
}
export async function installProductionFunctions(db){
  // Definitions contain mutually dependent PL/pgSQL bodies; PostgreSQL resolves
  // those statements when executed. No application financial function is stubbed.
  await db.exec('SET check_function_bodies=false');
  for(const fn of snapshot.functions)await db.exec(fn.definition);
  for(const trigger of snapshot.included_triggers)await db.exec(trigger.function_definition);
  await db.exec('SET check_function_bodies=true');
  for(const fn of snapshot.functions){
    await db.exec(`REVOKE ALL ON FUNCTION public.${fn.signature.replace(/^public\./,'')} FROM PUBLIC,anon,authenticated,service_role`);
    await grantAcl(db,'FUNCTION public.'+fn.signature.replace(/^public\./,''),fn.proacl);
  }
}
export async function installProductionSecurityAndTriggers(db){
  for(const relation of snapshot.relations){
    const name='public.'+q(relation.table);
    await db.exec(`REVOKE ALL ON TABLE ${name} FROM PUBLIC,anon,authenticated,service_role`);
    await grantAcl(db,'TABLE '+name,relation.acl);
    if(relation.rls)await db.exec(`ALTER TABLE ${name} ENABLE ROW LEVEL SECURITY`);
    if(relation.force_rls)await db.exec(`ALTER TABLE ${name} FORCE ROW LEVEL SECURITY`);
  }
  for(const entry of snapshot.column_grants)await grantAcl(db,'public.'+q(entry.table),entry.acl,entry.column);
  for(const policy of snapshot.policies){
    await db.exec(`CREATE POLICY ${q(policy.policyname)} ON public.${q(policy.tablename)} AS ${policy.permissive} FOR ${policy.cmd} TO ${policy.roles.map(r=>r==='public'?'PUBLIC':q(r)).join(',')}${policy.qual?' USING ('+policy.qual+')':''}${policy.with_check?' WITH CHECK ('+policy.with_check+')':''}`);
  }
  for(const trigger of snapshot.included_triggers)await db.exec(trigger.definition);
}
