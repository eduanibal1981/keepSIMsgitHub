"""Capture data-free scheduling dependencies; verify bodies against the independent catalogue.

Usage: python3 tools/financial-tests/capture-schedule-fixture.py /path/to/schema.sql
"""
from pathlib import Path
import re,hashlib,json
import sys
root=Path(__file__).resolve().parents[2]
import os
os.chdir(root)
if len(sys.argv)!=2: raise SystemExit('Usage: python3 tools/financial-tests/capture-schedule-fixture.py <schema-export.sql>')
dump=Path(sys.argv[1]).read_text();cat=json.loads(Path('docs/reviews/migration-cleanup-20261016/live-catalog.json').read_text())
parts=['-- ISOLATED ONLY: Task 20 real scheduling functions and triggers; after retail fixture.\nSET check_function_bodies=false;\nDROP FUNCTION public.carrier_refill_offer(uuid,numeric);']
names=['carrier_qualifying_topup_amount','carrier_refill_offer','refill_interval_days','queue_premium_refill_executions','trg_fn_sync_custom_refill_queue','update_sim_line_last_topup_at','reschedule_mini_refill','reset_mini_refill_to_default','update_mini_refill_dates','approve_refill_execution']
hashes={}
for n in names:
 m=re.search(r'CREATE OR REPLACE FUNCTION "public"\."'+n+r'"\(.*?\n    AS (\$[^$]*\$)(.*?)\1;',dump,re.S);assert m,n
 f=next(f for f in cat['functions'] if f['name']==n);h=hashlib.sha256(m[2].encode()).hexdigest();assert h==f['source_sha256'],n
 parts.append(m[0]);hashes[n]=h
for name in ['trg_sync_custom_refill_queue','trigger_update_sim_line_last_topup']:
 m=re.search(r'CREATE OR REPLACE TRIGGER "'+name+r'"[^\n]*;',dump);assert m;parts.append(m[0])
parts.append('SET check_function_bodies=true;')
Path('supabase/tests/fixtures/schedule_mutation_baseline.sql').write_text('\n\n'.join(parts)+'\n')
Path('supabase/tests/fixtures/schedule_mutation_baseline.json').write_text(json.dumps({'functions':hashes,'triggers':['trg_sync_custom_refill_queue','trigger_update_sim_line_last_topup'],'limits':'After the financial, pricing and retail fixtures. Uses real queue and last-topup success triggers; notification/health/risk adapters and external API/provider lifecycle remain omitted.'},indent=2)+'\n')
