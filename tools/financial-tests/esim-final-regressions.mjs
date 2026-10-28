// Re-run existing assertions against the complete ESIM-13 schema.
import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {randomUUID} from 'node:crypto';
const jobs=[
 {file:'esim-settlement.mjs',from:"{createFixture,owner,other} from './esim-settlement-fixture.mjs'",to:"{createGroupsFixture as createFixture,owner,other} from './esim-groups-fixture.mjs'"},
 {file:'esim-daily.mjs',from:"{createFixture,owner,other} from './esim-settlement-fixture.mjs'",to:"{createGroupsFixture as createFixture,owner,other} from './esim-groups-fixture.mjs'",daily:true},
 {file:'esim-controls.mjs',from:"{createControlsFixture,owner,other} from './esim-controls-fixture.mjs'",to:"{createGroupsFixture as createControlsFixture,owner,other} from './esim-groups-fixture.mjs'"},
 {file:'esim-controls-concurrency.mjs',from:"{createControlsFixture,owner,other} from './esim-controls-fixture.mjs'",to:"{createGroupsFixture as createControlsFixture,owner,other} from './esim-groups-fixture.mjs'"},
];
for(const job of jobs){
 let source=fs.readFileSync(path.join('tools/financial-tests',job.file),'utf8');
 if(!source.includes(job.from))throw Error('Regression import drift: '+job.file);
 source=source.replace(job.from,job.to);
 if(job.daily){const start=source.indexOf("const migration=fs.readdirSync"),end=source.indexOf('const enable=',start);if(start<0||end<0)throw Error('Daily fixture drift');source=source.slice(0,start)+source.slice(end);}
 const temp=path.join('tools/financial-tests','.esim-final-'+randomUUID()+'.mjs');
 try{fs.writeFileSync(temp,source);const r=spawnSync(process.execPath,[temp],{encoding:'utf8'});process.stdout.write(r.stdout||'');process.stderr.write(r.stderr||'');if(r.status!==0)throw Error('Regression failed: '+job.file);}
 finally{fs.rmSync(temp,{force:true});}
}
