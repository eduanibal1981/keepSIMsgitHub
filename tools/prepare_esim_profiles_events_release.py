"""Build the scoped ESIM-03/04 runtime from verified ESIM-02 artifacts.

Offline only. Pending fleet telemetry and unrelated Edge credential changes are
preserved locally and excluded from this deployment.
"""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
backend = root.parent / 'backend-sync-wt'
base = root / 'docs/reviews/esimaccess-catalogue-20261028/runtime-fix'
out = root / 'docs/reviews/esimaccess-profiles-events-20261028/release'

worker = (base / 'backend/worker_esim_catalog.js').read_text()
assert hashlib.sha256(worker.encode()).hexdigest() == '8947c6acbc3eefe5047af413f119568e7c78f1c3b8eda7652c32ab0ebabc896e'
local = (backend / 'worker_esim_catalog.js').read_text()
start = 'async function resolveEsimAccessCatalogueCredentials('
end = 'let isRefreshing'
worker = worker[:worker.index(start)] + local[local.index(start):local.index(end)] + worker[worker.index(end):]

fulfillment = (backend / 'worker_esim_fulfillment.js').read_text()
fulfillment = '\n'.join(line for line in fulfillment.split('\n') if not line.startswith('const fleetMonitor ='))
start = fulfillment.index(',\n onHealth:')
end = fulfillment.index('});}return runtime;', start)
fulfillment = fulfillment[:start] + fulfillment[end:]
assert 'worker_health' not in worker + fulfillment
assert 'fleetMonitor' not in worker + fulfillment

edge = (base / 'edge/sync-esim-catalogue/index.ts').read_text()
edge = 'import { acquireEsimSlot } from "../_shared/esimaccess-limiter.js";\n' + edge
needle = '        const res = await fetch(`${ESIM_ACCESS_BASE}/package/list`, {'
assert edge.count(needle) == 1
edge = edge.replace(needle, '        await acquireEsimSlot(supabase);\n' + needle)
assert 'requireProviderSecret' not in edge

files = {
    'backend/worker_esim_catalog.js': worker.encode(),
    'backend/worker_esim_fulfillment.js': fulfillment.encode(),
    'edge/sync-esim-catalogue/index.ts': edge.encode(),
}
for name in ['esim_fulfillment_runtime.js', 'esim_supplier_limiter.js',
             'providers/esimaccess.js', 'providers/esimaccess_catalog.js',
             'providers/esimaccess_profiles.js', 'providers/esimaccess_credentials.js']:
    files['backend/' + name] = (backend / name).read_bytes()
for name in ['_shared/esimaccess-limiter.js', '_shared/esimaccess-catalog.js',
             '_shared/esimaccess-events.js', 'esimaccess-events/index.ts',
             'esimaccess-events/deno.lock', 'sync-esim-catalogue/deno.lock']:
    files['edge/' + name] = (root / 'supabase/functions' / name).read_bytes()
for name in ['20261027235408_esim_profile_identity_lifecycle.sql',
             '20261027235409_esim_event_inbox_reconciliation.sql']:
    files['migrations/' + name] = (root / 'supabase/migrations' / name).read_bytes()
for name, content in files.items():
    path = out / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)
manifest = {
    'steps': ['ESIM-03', 'ESIM-04'], 'status': 'PREPARED',
    'project': 'zwxswagokhgbuzrrbnhr', 'new_sales_enabled': False,
    'supplier_limit_rps': 2, 'callback_auth': 'dedicated header capability; provider account wiring unverified',
    'omitted_pending_work': ['worker fleet telemetry', 'Edge Zendit credential-helper cutover'],
    'files': {name: hashlib.sha256(content).hexdigest() for name, content in files.items()},
}
(out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(out)
