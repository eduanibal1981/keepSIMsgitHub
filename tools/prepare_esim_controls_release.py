"""Freeze only the ESIM-10/11/12 runtime and application sources."""
from pathlib import Path
import hashlib,json,subprocess
root=Path(__file__).resolve().parents[1];backend=root.parent/'backend-sync-wt';admin=root.parent/'keep_sims_admin'
out=root/'docs/reviews/esimaccess-controls-automation-20261028/release'
customer=['lib/features/esim/domain/entities/esim_controls.dart','lib/features/esim/domain/repositories/esim_controls_repository.dart','lib/features/esim/data/repositories/esim_controls_repository_impl.dart','lib/features/esim/presentation/controllers/esim_controls_controller.dart','lib/features/esim/presentation/screens/esim_controls_screen.dart','lib/features/esim/presentation/screens/esim_screen.dart','lib/features/esim/presentation/widgets/esim_profile_card.dart']
admin_files=['lib/core/admin/admin_api.dart','lib/features/control/providers/esim_support_provider.dart','lib/features/control/presentation/widgets/esim_support_panel.dart','lib/features/control/presentation/operations_screen.dart']
vm=['esim_fulfillment_runtime.js','esim_profile_controls.js','providers/esimaccess_profiles.js']
sha=lambda b:hashlib.sha256(b).hexdigest()
files={**{'customer/'+n:(root/n).read_bytes() for n in customer},**{'admin/'+n:(admin/n).read_bytes() for n in admin_files},**{'backend/'+n:(backend/n).read_bytes() for n in vm},**{'edge/'+n:(root/'supabase/functions'/n).read_bytes() for n in ['esim-recharge-discovery/index.ts','esim-recharge-discovery/deno.lock','_shared/esim-recharge-discovery.js']},**{'migrations/'+p.name:p.read_bytes() for p in (root/'supabase/migrations').glob('*_esim_controls_automation.sql')}}
# Admin's primary tree also contains pending carrier/fleet edits. Apply only
# this task's three RPC methods to its reviewed source base.
admin_base=subprocess.check_output(['git','-C',str(admin),'show','codex/esim08-fixed-recharge-20261028:lib/core/admin/admin_api.dart'],text=True)
admin_current=(admin/'lib/core/admin/admin_api.dart').read_text()
start=admin_current.index('  Future<Map<String, dynamic>> esimSupport(')
end=admin_current.index('  Future<Map<String, dynamic>> esimOperationTimeline',start)
admin_scoped=admin_base.replace('  Future<Map<String, dynamic>> esimOperationTimeline',admin_current[start:end]+'  Future<Map<String, dynamic>> esimOperationTimeline',1)
files['admin/lib/core/admin/admin_api.dart']=admin_scoped.encode()
for n,b in files.items():
 target=out/n;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(b)
bases={'customer':subprocess.check_output(['git','-C',str(root),'rev-parse','codex/esim09-daily-duration-20261028'],text=True).strip(),'backend':subprocess.check_output(['git','-C',str(backend),'rev-parse','codex/esim09-daily-duration-20261028'],text=True).strip(),'admin':subprocess.check_output(['git','-C',str(admin),'rev-parse','codex/esim08-fixed-recharge-20261028'],text=True).strip()}
old={n:(None if n=='esim_profile_controls.js' else sha(subprocess.check_output(['git','-C',str(backend),'show',bases['backend']+':'+n]))) for n in vm}
dependencies={n:sha(subprocess.check_output(['git','-C',str(backend),'show',bases['backend']+':'+n])) for n in ['worker_esim_fulfillment.js','providers/esimaccess.js','providers/esimaccess_credentials.js','esim_supplier_limiter.js','esim_recharge_settlement.js','esim_receipt_journal.js','esim_recharge_discovery.js','providers/esimaccess_daily.js','providers/esimaccess_recharge.js']}
manifest={'steps':['ESIM-10','ESIM-11','ESIM-12'],'project':'zwxswagokhgbuzrrbnhr','branch':'codex/esim10-12-controls-20261028','source_bases':bases,'vm':{'process':'worker-esim-fulfillment','changed_files':vm,'previous_sha256':old,'dependencies':dependencies},'edge':{'slug':'esim-recharge-discovery','verify_jwt':True},'new_flags':{k:False for k in ['cancellation_enabled','cancellation_contract_verified','service_controls_enabled','service_controls_contract_verified','automation_enabled']},'acceptance':'No paid supplier tests, live profile actions, refunds, wallet mutations or binary publication. Refund policies/itemized credits require independently verified source evidence.','files':{n:sha(b) for n,b in files.items()}}
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print(out)
