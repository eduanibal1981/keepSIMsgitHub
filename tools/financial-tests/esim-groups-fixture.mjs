import fs from 'node:fs';
import {createControlsFixture,owner,other} from './esim-controls-fixture.mjs';
export {owner,other};
export async function createGroupsFixture(database=null){
 const f=await createControlsFixture(database);
 const name=fs.readdirSync('supabase/migrations').find(n=>n.endsWith('_esim_traveller_groups.sql'));
 await f.db.exec(fs.readFileSync('supabase/migrations/'+name,'utf8').replace(/DO \$preflight\$[\s\S]*?END \$preflight\$;/,''));
 return f;
}
