"""Package only ESIM-09 sources; no credentials, provider actions or deploys."""
from pathlib import Path
import hashlib,json,subprocess
root=Path(__file__).resolve().parents[1]
backend=root.parent/'backend-sync-wt'
out=root/'docs/reviews/esimaccess-daily-duration-20261028/release'
customer_files=[
 'lib/features/esim/domain/entities/esim_daily_selection.dart',
 'lib/features/esim/domain/entities/esim_recharge.dart',
 'lib/features/esim/domain/entities/user_esim.dart',
 'lib/features/esim/domain/repositories/esim_repository.dart',
 'lib/features/esim/data/repositories/esim_go_repository_impl.dart',
 'lib/features/esim/presentation/controllers/esim_daily_controller.dart',
 'lib/features/esim/presentation/controllers/esim_recharge_controller.dart',
 'lib/features/esim/presentation/widgets/esim_daily_quote_panel.dart',
 'lib/features/esim/presentation/widgets/esim_checkout_sheet.dart',
 'lib/features/esim/presentation/widgets/esim_profile_card.dart',
 'lib/features/esim/presentation/widgets/compare_offer_card.dart',
 'lib/features/esim/presentation/widgets/compare_offer_details_sheet.dart',
 'lib/features/esim/presentation/screens/esim_plans_screen.dart',
 'lib/features/esim/presentation/screens/esim_recharge_screen.dart',
]
vm=['esim_fulfillment_runtime.js','esim_recharge_discovery.js','esim_recharge_settlement.js',
 'providers/esimaccess.js','providers/esimaccess_recharge.js','providers/esimaccess_daily.js']
sha=lambda b:hashlib.sha256(b).hexdigest()
files={**{'customer/'+n:(root/n).read_bytes() for n in customer_files},
 **{'backend/'+n:(backend/n).read_bytes() for n in vm},
 **{'edge/'+n:(root/'supabase/functions'/n).read_bytes() for n in ['esim-recharge-discovery/index.ts','esim-recharge-discovery/deno.lock','_shared/esim-recharge-discovery.js']},
 **{'migrations/'+p.name:p.read_bytes() for p in (root/'supabase/migrations').glob('*_esim_daily*.sql')}}
for n,b in files.items():
 target=out/n;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(b)
bases={'customer':'fa4ca67582e71093c36a46275f2d7fa6ec370e0e','backend':'3c3961d18cd428817efe1abc18dfbaefa9e27766'}
old={}
for n in vm:
 if n=='providers/esimaccess_daily.js':continue
 old[n]=sha(subprocess.check_output(['git','-C',str(backend),'show',bases['backend']+':'+n]))
manifest={'step':'ESIM-09','project':'zwxswagokhgbuzrrbnhr','source_bases':bases,
 'vm':{'process':'worker-esim-fulfillment','changed_files':vm,'previous_sha256':old},
 'edge':{'slug':'esim-recharge-discovery','verify_jwt':True},
 'flags':{k:False for k in ['new_sales_enabled','recharge_enabled','recharge_contract_verified','wallet_boundary_verified','daily_duration_enabled','daily_contract_verified']},
 'pricing':'No live schedule seeded. Exact account/variant/duration supplier totals and observed recharge limits must be independently verified and imported through service-only RPC.',
 'limits':'1–365 whole days; 1–3 new profiles; account-specific extension count requires fresh verified evidence, never unlimited.',
 'provider_acceptance':'UNVERIFIED; no owned Access profile, paid test or wallet mutation.',
 'files':{n:sha(b) for n,b in files.items()}}
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(out)
