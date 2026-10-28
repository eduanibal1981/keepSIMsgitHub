"""Package reviewed ESIM-08 sources without credentials or deployment effects.

Run in the customer checkout, with authoritative ../backend-sync-wt and the
isolated admin checkout supplied as --admin-source (avoids unrelated edits).
"""
from pathlib import Path
import argparse
import hashlib
import json

p = argparse.ArgumentParser()
p.add_argument('--backend-source', type=Path)
p.add_argument('--admin-source', type=Path, required=True)
args = p.parse_args()
root = Path(__file__).resolve().parents[1]
backend = args.backend_source or root.parent / 'backend-sync-wt'
out = root / 'docs/reviews/esimaccess-recharge-settlement-20261028/release'
sha = lambda b: hashlib.sha256(b).hexdigest()
previous = root / 'docs/reviews/esimaccess-recharge-discovery-20261028/release/backend/esim_fulfillment_runtime.js'
assert sha(previous.read_bytes()) == '7812c180aab52043525e862475c10828f17fd55fc04dc2cfe489fe010108e7d3'
files = {}
vm_files = ['esim_fulfillment_runtime.js', 'esim_recharge_settlement.js',
            'esim_receipt_journal.js', 'providers/esimaccess_recharge.js']
for name in vm_files:
    files['backend/' + name] = (backend / name).read_bytes()
for name in ['esim-recharge-discovery/index.ts', 'esim-recharge-discovery/deno.lock', '_shared/esim-recharge-discovery.js']:
    files['edge/' + name] = (root / 'supabase/functions' / name).read_bytes()
for name in ['20261028032323_esim_fixed_recharge_settlement.sql', '20261028042528_esim_settlement_view_boundary.sql']:
    files['migrations/' + name] = (root / 'supabase/migrations' / name).read_bytes()
for name in ['domain/entities/esim_recharge.dart', 'domain/repositories/esim_repository.dart',
             'data/repositories/esim_go_repository_impl.dart', 'presentation/controllers/esim_recharge_controller.dart',
             'presentation/screens/esim_recharge_screen.dart', 'presentation/widgets/esim_checkout_sheet.dart']:
    files['customer/lib/features/esim/' + name] = (root / 'lib/features/esim' / name).read_bytes()
for name in ['lib/core/admin/admin_api.dart', 'lib/features/control/presentation/operations_screen.dart',
             'lib/features/control/providers/esim_operation_provider.dart',
             'lib/features/control/presentation/widgets/esim_operation_inspector.dart']:
    files['admin/' + name] = (args.admin_source / name).read_bytes()
for name, content in files.items():
    target = out / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(content)
manifest = {
    'step': 'ESIM-08', 'project': 'zwxswagokhgbuzrrbnhr',
    'source_bases': {'customer': 'b070f59c470ef8bbaa46e56cca570b53f6c934d7',
                     'backend': 'e2e2c7c2abe90d5abc3c4157d7a2de0b6bc6257c',
                     'admin': '15d9d02951e2b49390637327e1eaf875bc16c2f0'},
    'edge': {'slug': 'esim-recharge-discovery', 'verify_jwt': True,
             'authority': 'validated customer JWT; owner-checked SQL RPCs'},
    'vm': {'process': 'worker-esim-fulfillment', 'changed_files': vm_files,
           'previous_runtime_sha256': sha(previous.read_bytes()),
           'journal': {'directory': '.esim-receipts', 'directory_mode': '0700', 'file_mode': '0600'}},
    'flags': {'recharge_enabled': False, 'recharge_contract_verified': False,
              'wallet_boundary_verified': False, 'new_sales_enabled': False},
    'financial_scope': ['existing eSIM orders/run authority', 'reserve/capture/release actual wallet helpers',
                        'wallet-before-hold locking and private capture provenance',
                        'protect active eSIM reservations from legacy direct writers',
                        'bounded proven original-payer legacy refund', 'eSIM reconciliation types'],
    'provider_acceptance': 'UNVERIFIED: no named paid test profile or ceiling; missing/lost topup receipts stay reserved',
    'exclusions': ['other VM processes', 'provider credentials', 'account-deletion/wallet overhaul',
                   'daily-duration/automatic/group recharge', 'app binary publication', 'paid supplier calls'],
    'files': {name: sha(content) for name, content in files.items()},
}
(out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(out)
