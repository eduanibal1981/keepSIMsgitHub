"""Capture data-free Task 23 monitoring table dependencies from the supplied export.

Usage: python3 tools/financial-tests/capture-fleet-fixture.py /path/to/schema.sql
Load after bootstrap(), pricing_contract_baseline.sql and offline_voucher_baseline.sql.
No production connection or data is used. Cross-domain omitted FKs are recorded.
"""
from pathlib import Path
import hashlib
import json
import re
import sys
root=Path(__file__).resolve().parents[2]
dump=Path(sys.argv[1]).read_text()
catalog=json.loads((root/'docs/reviews/migration-cleanup-20261016/live-catalog.json').read_text())
base=json.loads((root/'supabase/tests/fixtures/financial_production_snapshot.json').read_text())['tables']
tables=['notification_dispatch_jobs','notification_channel_targets','offline_voucher_purchase_jobs','admin_emails',
        'whatsapp_provider_profiles','whatsapp_message_attempts','supplier_policy','refill_approval_quotes']
known=base+tables+['esim_orders','offline_voucher_stock','offline_voucher_grants','offline_voucher_requests']
parts=['-- ISOLATED ONLY: exact Task 23 export dependencies; no records or provider calls.']
for name in tables:
 parts.append(re.search(r'CREATE TABLE IF NOT EXISTS "public"\."'+name+r'" \(.*?\n\);',dump,re.S)[0])
omitted=[]
for kind in ['PRIMARY KEY','UNIQUE','FOREIGN KEY']:
 for c in catalog['constraints']:
  if c['table'] not in tables or not c['definition'].startswith(kind):continue
  if kind=='FOREIGN KEY':
   target=re.search(r'REFERENCES ([\w.]+)',c['definition'])[1]
   if target not in known+['auth.users']:
    omitted.append(c);continue
  parts.append(f'ALTER TABLE public."{c["table"]}" ADD CONSTRAINT "{c["name"]}" {c["definition"]};')
for index in catalog['indexes']:
 if index['table'] in tables and not any(c['name']==index['name'] for c in catalog['constraints']):parts.append(index['definition']+';')
# The actual post-Task-16 job table is a local forward contract, not a fabricated shape.
source=(root/'supabase/migrations/20261018030000_admin_maintenance_deletion_contract.sql').read_text()
job=re.search(r'CREATE TABLE public.account_purge_jobs\(.*?\n\);',source,re.S)[0]
parts.append(job)
output=root/'supabase/tests/fixtures/worker_fleet_baseline.sql'
output.write_text('\n\n'.join(parts)+'\n')
output.with_suffix('.json').write_text(json.dumps(dict(tables=tables+['account_purge_jobs'],omitted_foreign_keys=omitted,
 account_purge_source_sha256=hashlib.sha256(job.encode()).hexdigest(),
 limits='Exact bounded table shapes and constraints. Database cron relations and Supabase Auth remain isolated adapters. No full trigger, REST/pg_cron scheduler, runtime dependency or provider parity claim.'),indent=2)+'\n')
