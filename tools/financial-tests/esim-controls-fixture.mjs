import fs from 'node:fs';
import {createFixture,owner,other} from './esim-settlement-fixture.mjs';
export {owner,other};
export async function createControlsFixture(database=null){
 const f=await createFixture(database);
 const read=name=>fs.readFileSync('supabase/migrations/'+fs.readdirSync('supabase/migrations').find(n=>n.endsWith(name)),'utf8').replace(/DO \$preflight\$[\s\S]*?END \$preflight\$;/,'');
 await f.db.exec(read('_esim_daily_duration.sql'));
 await f.db.exec(read('_esim_controls_automation.sql'));
 await f.db.exec(JSON.parse(fs.readFileSync('docs/reviews/esimaccess-controls-automation-20261028/evidence/dependencies.json')).find(x=>x.proname==='credit_wallet').definition);
 return f;
}
