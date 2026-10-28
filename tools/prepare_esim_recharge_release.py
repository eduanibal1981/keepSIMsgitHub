"""Build ESIM-07's scoped review artifact. No credentials or deployments."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[1]
backend = root.parent / 'backend-sync-wt'
out = root / 'docs/reviews/esimaccess-recharge-discovery-20261028/release'
sha = lambda content: hashlib.sha256(content).hexdigest()
base = (root / 'docs/reviews/esimaccess-alerts-20261028/release/backend/esim_fulfillment_runtime.js').read_bytes()
assert sha(base) == '543f438ee844e98b99c9591bf9d77918c9426ef7654e6ec41569c22a2c4e1557'
expected = base.replace(b"const {limitedFetch}=require('./esim_supplier_limiter');", b"const {limitedFetch}=require('./esim_supplier_limiter');\nconst {createRechargeDiscovery}=require('./esim_recharge_discovery');")
expected = expected.replace(b'  const request=limitedFetch(supabase,accountKey,fetchImpl);', b'  const request=limitedFetch(supabase,accountKey,fetchImpl);\n  const discoverTopups=createRechargeDiscovery({supabase,accountKey,fetchImpl});')
expected = expected.replace(b'      counts.alerts=alerts?.created||0;', b'      counts.alerts=alerts?.created||0;\n      counts.topup_discoveries=await discoverTopups();')
assert expected == (backend / 'esim_fulfillment_runtime.js').read_bytes(), 'Unrelated fulfillment changes'
files = {'backend/esim_fulfillment_runtime.js': expected,
         'backend/esim_recharge_discovery.js': (backend / 'esim_recharge_discovery.js').read_bytes()}
for name in ['esim-recharge-discovery/index.ts', 'esim-recharge-discovery/deno.lock', '_shared/esim-recharge-discovery.js']:
    files['edge/' + name] = (root / 'supabase/functions' / name).read_bytes()
name = '20261028070000_esim_recharge_discovery_quotes.sql'
files['migrations/' + name] = (root / 'supabase/migrations' / name).read_bytes()
for name in ['domain/entities/esim_recharge.dart', 'domain/repositories/esim_repository.dart',
             'data/repositories/esim_go_repository_impl.dart', 'presentation/controllers/esim_recharge_controller.dart',
             'presentation/screens/esim_recharge_screen.dart', 'presentation/screens/esim_delivery_screen.dart',
             'presentation/screens/esim_screen.dart', 'presentation/screens/esim_alert_target_screen.dart',
             'presentation/widgets/esim_profile_card.dart']:
    files['customer/lib/features/esim/' + name] = (root / 'lib/features/esim' / name).read_bytes()
for name, content in files.items():
    target = out / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(content)
manifest = {
    'step': 'ESIM-07', 'project': 'zwxswagokhgbuzrrbnhr',
    'source_bases': {'customer': 'd67bba0e513b9ec7b918fb23b22b7d5f4ca8e1b3',
                     'backend': '5960b9d3ce093c6addaa3643bef74f52bf023c88'},
    'edge': {'slug': 'esim-recharge-discovery', 'verify_jwt': True, 'authentication': 'validated customer JWT; customer-scoped SQL'},
    'vm': {'process': 'worker-esim-fulfillment', 'changed_files': ['esim_recharge_discovery.js', 'esim_fulfillment_runtime.js'],
           'previous_runtime_sha256': sha(base)},
    'rollout': 'Apply disabled policy, deploy Edge/helper, verify heartbeat, enable only read-only discovery',
    'acceptance_enabled': False, 'new_sales_enabled': False,
    'cache_ttl_seconds': 300, 'quote_ttl_seconds': 120, 'profile_freshness_seconds': 900,
    'omitted': ['purchase/recharge submission', 'wallet mutations', 'daily-duration quotes', 'callback registration',
                'provider adapters/credentials', 'other VM processes', 'Admin app', 'app publication'],
    'files': {name: sha(content) for name, content in files.items()},
}
(out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(out)
