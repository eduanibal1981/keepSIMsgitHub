"""Package ESIM-06 customer sources. Existing runtime contracts suffice."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FILES = [
    'ios/Runner/AppDelegate.swift',
    'lib/features/esim/domain/entities/esim_activation_payload.dart',
    'lib/features/esim/domain/entities/esim_installation_policy.dart',
    'lib/features/esim/domain/entities/user_esim.dart',
    'lib/features/esim/domain/entities/user_esim.freezed.dart',
    'lib/features/esim/domain/entities/user_esim.g.dart',
    'lib/features/esim/data/services/esim_installation_service.dart',
    'lib/features/esim/presentation/controllers/esim_installation_controller.dart',
    'lib/features/esim/presentation/controllers/user_esims_controller.dart',
    'lib/features/esim/presentation/screens/esim_delivery_screen.dart',
    'lib/features/esim/presentation/screens/esim_screen.dart',
    'lib/features/esim/presentation/widgets/esim_profile_card.dart',
    'lib/features/sim_lines/domain/plan_payment.dart',
]

def prepare():
    out = ROOT / 'docs/reviews/esimaccess-installation-20261028/release'
    hashes = {}
    for name in FILES:
        data = (ROOT / name).read_bytes()
        if name == 'lib/features/sim_lines/domain/plan_payment.dart':
            base = (out.parent / 'evidence/plan-payment-release-before.dart').read_bytes()
            assert hashlib.sha256(base).hexdigest() == '0198aee6bb269fcc3388764bb64337164a853a3e493da4a418ef2031546bcc00'
            local = data.decode()
            begin = local.index('  /// Fresh spendable funds,')
            end = local.index('  /// Calculates the shortfall', begin)
            marker = '  const PlanPayment._();\n\n'
            assert base.decode().count(marker) == 1
            # Include only the missing checkout dependency, not pending wallet work.
            data = base.decode().replace(marker, marker + local[begin:end]).encode()
        target = out / 'customer' / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        hashes[name] = hashlib.sha256(data).hexdigest()
    manifest = {
        'step': 'ESIM-06', 'project': 'zwxswagokhgbuzrrbnhr',
        'customer_status': 'prepared and tested; no app binaries published',
        'runtime_changes': {'migration': False, 'edge': False, 'vm_worker': False},
        'runtime_reason': 'Deployed owner-only invoker profile projection already supplies installation, activation and observation facts.',
        'native_acceptance': 'unverified on a real Apple device/profile',
        'offline_scope': 'Local rendering of an already-loaded signed-in owner snapshot; no new persistent credential cache.',
        'new_sales_enabled': False, 'files': hashes,
        'necessary_source_prerequisite': 'The prior eSIM checkout branch referenced PlanPayment.availableWalletBalance without including it; only that existing read helper is included.',
    }
    (out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(out)

if __name__ == '__main__':
    prepare()
