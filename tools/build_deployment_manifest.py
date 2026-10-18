#!/usr/bin/env python3
"""Describe reviewed source/config intent and blocking evidence; never deploy."""
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT=Path(__file__).resolve().parents[1]
EVIDENCE=ROOT/'docs/reviews/source-reproducibility-20261018'
MANIFEST=ROOT/'deployment/manifest.json'

# Deliberate dependency order, not directory/filename order. This remains a
# candidate until the complete clean/upgrade release gates pass.
ORDER=[
 '20261016210736_privileged_database_access.sql',
 '20261016010000_financial_rpc_containment.sql',
 '20261016020000_wallet_funding_integrity.sql',
 '20261016025000_instant_refill_submission_boundary.sql',
 '20261016030000_compatible_sim_finalization.sql',
 '20261016040000_canonical_paid_pricing.sql',
 '20261016045000_canonical_esim_catalogue_prices.sql',
 '20261016050000_retail_customer_contracts.sql',
 '20261016060000_schedule_wallet_recovery.sql',
 '20261017100000_endpoint_webhook_authentication.sql',
 '20261017110000_paypal_capture_fulfillment.sql',
 '20261016235338_sim_setup_instant_settlement.sql',
 '20261017164417_scheduled_refill_worker_contracts.sql',
 '20261017190000_supplier_outcome_recovery.sql',
 '20261017201740_liveness_verification_contract.sql',
 '20261017203115_call_budget_contract.sql',
 '20261017024520_second_number_inbox_and_lifecycle.sql',
 '20261018010000_notification_scheduler_contract.sql',
 '20261018020000_usage_forecast_schema_contract.sql',
 '20261018030000_admin_maintenance_deletion_contract.sql',
 '20261018040000_second_number_financial_safety.sql',
 '20261018050000_unified_pricing_entitlement.sql',
 '20261018060000_retail_ownership_contract.sql',
 '20261018070000_scheduled_pricing_boundary.sql',
 '20261018080000_offline_voucher_request_state.sql',
]
EXCLUDED={
 '20260825010000_m1_pin_voucher_fallback.sql':'partial review; reconcile current schema, do not replay',
 '20260827000000_realtime_sim_lines_and_executions.sql':'partial publication review',
 '20260828000000_sync_providers_comparison_matrices.sql':'data review; no production data rewrite authorized',
 '20260906125518_harden_scheduled_jobs_health_authorization.sql':'superseded by scoped Task 3 containment',
 '20260911040000_firsty_recovery_schema.sql':'deferred sandbox feature; do not enable',
 '20260916080000_fix_forecast_anchor_null_recharge.sql':'superseded by Task 15; invalid legacy method',
 '20261016205533_admin_provider_credentials.sql':'already recorded live; do not reapply',
 '20261018090000_worker_fleet_monitoring.sql':'concurrent Task 23 work; excluded from the Task 22 candidate pending its separate review',
}
BLOCKERS=[
 {'id':'full-baseline','status':'BLOCKING','detail':'No approved complete provisioning baseline: public export/routine evidence and bounded fixtures omit managed Auth/Storage/Vault/net/cron dependency contracts, application-owned cross-schema objects and owner/default-ACL replay.'},
 {'id':'full-upgrade','status':'BLOCKING','detail':'The entire ordered release has not been applied together to the complete current shape. Bounded subsystem tests cannot establish that convergence.'},
 {'id':'remote-history','status':'BLOCKING','detail':'23 original remote-only history rows lack original statements. Capture current contracts separately; never fabricate dates/statements or mark rows reverted because files moved.'},
 {'id':'live-definition-owners','status':'BLOCKING','detail':'Automatic approval review rejected full production SQL-definition/ownership export. Exact public body/signature comparisons are available; full current definitions/owners remain unverified.'},
 {'id':'worker-runtime','status':'BLOCKING','detail':'Fresh VM hashes differ from some repaired local sources. Runtime package/lock sources are recovered exactly, but installed dependency equivalence and a clean installation under the observed Node 22.23.1 runtime still require release verification.'},
 {'id':'config-seeds-cron','status':'BLOCKING','detail':'Required non-secret effective prices, routing/policy/config rows and safe cron templates are not an approved seed set. Hashes and config names do not provision values. Secrets must be provisioned separately.'},
 {'id':'edge-parity','status':'BLOCKING','detail':'Full deployed Edge source parity, explicit gateway settings for every source and exact remote dependency locks remain incomplete; live test-func-check has no versioned entrypoint.'},
 {'id':'release-gate','status':'BLOCKING','detail':'Task 24 pinned toolchain/application/API/provider checks and Task 25 operational approval are still required.'},
]


def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()


def function_config():
    text=(ROOT/'supabase/config.toml').read_text()
    sections={}
    for m in re.finditer(r'^\[functions\.([^\]]+)\]\s*\n([\s\S]*?)(?=^\[|\Z)',text,re.M):
        jwt=re.search(r'^verify_jwt\s*=\s*(true|false)',m[2],re.M)
        sections[m[1]]={'verify_jwt':jwt[1]=='true' if jwt else None}
    return sections


def generate():
    live=json.loads((EVIDENCE/'live-metadata.json').read_text())
    edge_live={x['slug']:x for x in json.loads((EVIDENCE/'live-edge-metadata.json').read_text())['functions']}
    config=function_config(); edge=[]
    slugs=set(edge_live)|{p.parent.name for p in (ROOT/'supabase/functions').glob('*/index.ts')}
    for slug in sorted(slugs):
        directory=ROOT/'supabase/functions'/slug
        files=[{'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p)}
               for p in sorted(directory.rglob('*')) if p.is_file()] if directory.exists() else []
        edge.append({'slug':slug,'live':edge_live.get(slug),'desired':config.get(slug),
                     'source_files':files,'parity':'NOT VERIFIED' if slug!='send-admin-email' else 'intentional Task 16 replacement of recovered v2'})
    backend=ROOT.parent/'backend-sync-wt'
    vm=json.loads((EVIDENCE/'live-worker-metadata.json').read_text())
    vm_files={f['path']:f['sha256'] for f in vm['files']}
    workers=[]
    for process in vm['processes']:
        file=Path(process['path']).name; source=backend/file
        workers.append({'process':process['name'],'source':file,'local_sha256':sha(source) if source.is_file() else None,
                        'observed_runtime_sha256':vm_files.get(file),'runtime_evidence_date':vm['date'],
                        'remote_path':process['path'],'observed_cwd':process['cwd'],
                        'observed_node_version':process['node_version']})
    runtime_dependencies=[]
    for file in vm['dependencyFiles']:
        source=backend/Path(file['path']).name
        if not source.is_file() or sha(source)!=file['sha256']: raise ValueError('Recovered runtime dependency source drift: '+source.name)
        runtime_dependencies.append({'file':source.name,'sha256':sha(source),'observed_vm_path':file['path']})
    env_names=set()
    for p in list(backend.glob('*.js'))+list((ROOT/'supabase/functions').rglob('*.ts')):
        text=p.read_text()
        env_names.update(re.findall(r'process\.env\.([A-Z_][A-Z_0-9]*)',text))
        env_names.update(re.findall(r'(?:Deno\.env\.get|(?:get|read)ProviderSecret)\([^\n]*?[\'"]([A-Z_][A-Z_0-9]*)[\'"]',text))
    example=backend/'.env.example'
    if example.is_file(): env_names.update(re.findall(r'^([A-Z_][A-Z_0-9]*)=',example.read_text(),re.M))
    migrations=[]
    for filename in ORDER:
        p=ROOT/'supabase/migrations'/filename
        migrations.append({'file':filename,'sha256':sha(p)})
    actual={p.name for p in (ROOT/'supabase/migrations').glob('*.sql')}
    if actual != set(ORDER)|set(EXCLUDED): raise ValueError('Unclassified migration queue: '+str(actual^(set(ORDER)|set(EXCLUDED))))
    return {'format':1,'date':'2026-10-18','status':'BLOCKED — source reconstruction, not release approval',
      'project_id':live['project_id'],'source_lock':'deployment/source-lock.json',
      'history_evidence':'docs/reviews/source-reproducibility-20261018/live-metadata.json',
      'fresh':{'status':'BLOCKED','baseline':None,'must_not_replay':['active migration directory','archive directory','supabase/recovered']},
      'upgrade':{'status':'BLOCKED','expected_history_rows':len(live['history']),
                 'latest_recorded_version':max(h['version'] for h in live['history']),
                 'candidate_dependency_order':migrations,'excluded':EXCLUDED,
                 'preconditions':['Task 3 containment must precede changed return shapes',
                   'credential schema version 20261016205533 must already exist',
                   'stop incompatible money/provider processors only during an authorized release',
                   'compare current shape and reconcile legacy evidence before applying any file']},
      'edge':edge,
      'edge_shared_sources':[{'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p)} for p in sorted((ROOT/'supabase/functions/_shared').rglob('*')) if p.is_file()],
      'workers':{'authority':'../backend-sync-wt','delivery':'direct SSH/SCP only when separately authorized; no VM git pull',
        'observed_processes':workers,
        'observed_source_files':[{'file':name,'runtime_sha256':digest,
          'local_sha256':sha(backend/name) if (backend/name).is_file() else None} for name,digest in sorted(vm_files.items())],
        'runtime_dependency_sources':runtime_dependencies,
        'pending_required_source':'worker_supplier_reconciliation.js',
        'unconfirmed_process_sources':['worker_voucher_stock.js','server_ww.js','sim_liveness_service.js'],
        'dependencies':'Exact VM package/lock files recovered; clean install and installed-runtime equivalence are still unverified'},
      'configuration':{'names_only':sorted(env_names),'configuration_handling':'external environment/Vault; never package credential values',
        'configuration_seed_state':'BLOCKED: reviewed effective configuration not captured as approved seeds',
        'cron':'metadata/hashes in live-metadata.json; no active job installation from evidence'},
      'blockers':BLOCKERS}


if __name__=='__main__':
    data=generate()
    if len(sys.argv)>1 and sys.argv[1]=='--check':
        if not MANIFEST.is_file() or json.loads(MANIFEST.read_text())!=data: raise SystemExit('Deployment manifest drift; review and regenerate')
        print('Deployment source manifest matches current files')
    elif len(sys.argv)>1 and sys.argv[1]=='--gate':
        for blocker in data['blockers']: print(blocker['status']+': '+blocker['id']+' — '+blocker['detail'])
        raise SystemExit(2)
    else:
        MANIFEST.parent.mkdir(exist_ok=True);MANIFEST.write_text(json.dumps(data,indent=2)+'\n')
        print('Wrote blocked candidate manifest; no deployment or database changes')
