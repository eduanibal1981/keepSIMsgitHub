"""Prepare ESIM-05 only; verify the deployed ESIM-03/04 and outbox bases."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[1]
review = root / 'docs/reviews/esimaccess-alerts-20261028'
out = review / 'release'
sha = lambda b: hashlib.sha256(b).hexdigest()
before = review / 'evidence/outbox-before/index.ts'
assert sha(before.read_bytes()) == 'aa15f2bfd611ab414a39253ec589b35f9d5cc4f7095af2f554b5e239115c2d8c'
runtime = (root.parent / 'backend-sync-wt/esim_fulfillment_runtime.js').read_bytes()
base_runtime = (root / 'docs/reviews/esimaccess-profiles-events-20261028/release/backend/esim_fulfillment_runtime.js').read_bytes()
assert sha(base_runtime) == '0e9ec8df3f72bf7fbd0d1d7f1944c42beebfe22366bd563d37a80056619c2848'
addition = b"      // Alerts derive only from saved authenticated observations, including\n      // near-expiry time windows between provider refreshes. No provider sends.\n      const alerts=await rpc('service_esim_emit_alerts');\n      counts.alerts=alerts?.created||0;\n"
assert runtime.count(addition) == 1 and runtime.replace(addition,b'') == base_runtime
files = {'backend/esim_fulfillment_runtime.js': runtime}
for file in ['process-alert-outbox/index.ts', 'process-alert-outbox/quiet_hours.ts']:
    files['edge/' + file] = (root / 'supabase/functions' / file).read_bytes()
assert files['edge/process-alert-outbox/quiet_hours.ts'] == (review / 'evidence/outbox-before/quiet_hours.ts').read_bytes()
name = '20261028013756_esim_actionable_alerts.sql'
files['migrations/' + name] = (root / 'supabase/migrations' / name).read_bytes()
for path, content in files.items():
    target = out / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(content)
manifest = {
    'step': 'ESIM-05', 'project': 'zwxswagokhgbuzrrbnhr',
    'new_sales_enabled': False, 'channels': ['in_app', 'push'],
    'edge': {'slug':'process-alert-outbox', 'base_version':7, 'verify_jwt':False,
             'authentication':'existing service bearer or Vault dispatch shared secret'},
    'vm': {'process':'worker-esim-fulfillment', 'changed_files':['esim_fulfillment_runtime.js'],
           'before_sha256':sha(base_runtime)},
    'omitted': ['other workers', 'fleet telemetry', 'provider callback registration', 'app binaries', 'paid provider actions'],
    'files': {path:sha(content) for path,content in files.items()},
}
(out / 'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(out)
