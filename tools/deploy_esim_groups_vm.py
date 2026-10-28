"""Run on the VM with a reviewed manifest; outputs redacted deployment evidence."""
import hashlib,json,pathlib,subprocess,sys,shutil
stage=pathlib.Path(__file__).resolve().parent
manifest=json.loads((stage/'manifest.json').read_text());base=pathlib.Path('/home/abdal/keepsims_backend/servers')
vm=manifest['vm'];backup=base.parent/'backups/esim13-14-20261028'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else None
def processes():
 data=json.loads(subprocess.check_output(['pm2','jlist']))
 return {x['name']:{'pid':x['pid'],'status':x['pm2_env']['status'],'restarts':x['pm2_env']['restart_time']} for x in data}
def preflight():
 for n,h in vm['dependencies'].items():assert sha(base/n)==h,'Dependency drift: '+n
 for n,h in vm['previous_sha256'].items():assert sha(base/n)==h,'Source drift: '+n
 for n in vm['changed_files']:assert sha(stage/n)==manifest['files']['backend/'+n],'Staged source drift: '+n
 return processes()
mode=sys.argv[1]
if mode=='preflight':
 before=preflight();(stage/'processes-before.json').write_text(json.dumps(before));print(json.dumps({'preflight':True,'processes':before,'previous_sha256':vm['previous_sha256']}))
elif mode=='install':
 before=preflight();backup.mkdir(parents=True,exist_ok=True)
 for n in vm['changed_files']:
  dest=backup/n;dest.parent.mkdir(parents=True,exist_ok=True)
  if (base/n).exists() and not dest.exists():shutil.copy2(base/n,dest)
  (base/n).parent.mkdir(parents=True,exist_ok=True);shutil.copy2(stage/n,base/n)
 for n in vm['changed_files']:subprocess.run(['node','--check',str(base/n)],check=True)
 subprocess.run(['pm2','restart',vm['process']],check=True,stdout=subprocess.DEVNULL)
 after=processes()
 assert all(before[k]==after[k] for k in before if k!=vm['process']),'Unrelated process changed'
 assert after[vm['process']]['status']=='online'
 hashes={n:sha(base/n) for n in vm['changed_files']}
 assert all(h==manifest['files']['backend/'+n] for n,h in hashes.items())
 print(json.dumps({'installed':True,'backup':str(backup),'hashes':hashes,'before':before,'after':after}))
elif mode=='verify':
 print(json.dumps({'hashes':{n:sha(base/n) for n in vm['changed_files']},'processes':processes()}))
else:raise ValueError('Invalid deployment phase')
