'use strict';
const fs=require('node:fs'),path=require('node:path');
// Private receipt evidence only: no activation payload, API key or wallet amount.
function createReceiptJournal(directory=path.join(__dirname,'.esim-receipts')) {
  const valid=id=>typeof id==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id);
  const syncDir=()=>{if(process.platform==='win32')return;const fd=fs.openSync(directory,'r');try{fs.fsyncSync(fd);}finally{fs.closeSync(fd);}};
  const ready=()=>{fs.mkdirSync(directory,{recursive:true,mode:0o700});fs.chmodSync(directory,0o700);fs.accessSync(directory,fs.constants.R_OK|fs.constants.W_OK);};
  const file=id=>{if(!valid(id))throw Error('Invalid receipt ID');return path.join(directory,id+'.json');};
  return {
    ready,
    write(entry){ready();const target=file(entry.order_id),data=JSON.stringify(entry);if(data.length>8192)throw Error('Invalid receipt');
      if(fs.existsSync(target)){if(fs.readFileSync(target,'utf8')!==data)throw Error('Conflicting receipt');return;}
      const temp=target+'.tmp',fd=fs.openSync(temp,'w',0o600);try{fs.writeFileSync(fd,data);fs.fsyncSync(fd);}finally{fs.closeSync(fd);}
      fs.renameSync(temp,target);syncDir();
    },
    list(){ready();return fs.readdirSync(directory).filter(n=>valid(n.slice(0,-5))&&n.endsWith('.json')).sort().slice(0,100).map(n=>{
      const stat=fs.statSync(path.join(directory,n));if(stat.size>8192)throw Error('Invalid receipt size');
      const entry=JSON.parse(fs.readFileSync(path.join(directory,n),'utf8'));if(entry.order_id+'.json'!==n)throw Error('Receipt identity mismatch');return entry;
    });},
    remove(id){fs.unlinkSync(file(id));syncDir();},
  };
}
module.exports={createReceiptJournal};
