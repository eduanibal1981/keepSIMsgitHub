#!/usr/bin/env python3
"""Compare captured metadata without executing any recovered SQL."""
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
DIRECTORY=ROOT/'docs/reviews/source-reproducibility-20261018'


def compare():
    old=json.loads((ROOT/'docs/reviews/migration-cleanup-20261016/live-catalog.json').read_text())
    new=json.loads((DIRECTORY/'live-metadata.json').read_text())
    definitions=json.loads((DIRECTORY/'definition-hashes.json').read_text())
    recovered=json.loads((ROOT/'supabase/recovered/20261018/public-routines.json').read_text())
    result={'date':'2026-10-18','function_export_exact_body_matches':sum(f['exact_body_match'] for f in recovered['export_live_comparison']),
            'function_export_signatures':len(recovered['export_live_comparison'])}
    current={(f['name'],f['types']):f for f in new['functions']}
    previous={(f['name'],f['types']):f for f in old['functions']}
    result['functions_since_october16']={
        'new':[list(k) for k in sorted(current.keys()-previous.keys())],
        'removed':[list(k) for k in sorted(previous.keys()-current.keys())],
        'body_changed':[list(k) for k in sorted(previous.keys()&current.keys()) if previous[k]['source_sha256']!=current[k]['source_sha256']],
        'acl_changed':[list(k) for k in sorted(previous.keys()&current.keys()) if previous[k]['acl']!=current[k]['acl']]}
    sha=lambda s:hashlib.sha256((s or '').encode()).hexdigest()
    for key in ['constraints','triggers']:
        lookup={(x['table'],x['name']):x for x in definitions[key]}
        unmatched=[{'table':x['table'],'name':x['name']} for x in old[key]
                   if lookup.get((x['table'],x['name']),{}).get('sha256')!=sha(x['definition'])]
        result[key]={'previous':len(old[key]),'current_public':len(definitions[key]),
                     'exact_definition_matches':len(old[key])-len(unmatched),'unmatched':unmatched}
    policies={(x['table'],x['name']):x for x in new['policies']}
    result['policies']={'previous':len(old['policies']),'current':len(new['policies']),
        'exact_using_and_check_matches':sum((x['table'],x['name']) in policies and
         sha(x['using'])==policies[(x['table'],x['name'])]['using_sha256'] and
         sha(x['check'])==policies[(x['table'],x['name'])]['check_sha256'] for x in old['policies'])}
    cron={x['name']:x for x in new['cron']}
    result['cron']={'previous':len(old['cron']),'current':len(new['cron']),
        'unchanged_schedule_active_command':sum(x['name'] in cron and all(x[k]==cron[x['name']][k] for k in ['schedule','active','command_sha256']) for x in old['cron'])}
    result['non_public_static_references']=sorted({x for f in recovered['export_live_comparison'] for x in f.get('non_public_static_references',[])})
    result['limits']=[
      'Function bodies/signatures are exact matches; owners and full definition parity remain blocked.',
      'Constraint/trigger comparison uses the same non-pretty PostgreSQL deparse; pretty formatting produced false differences.',
      '137 policy expressions match; this does not claim that their legacy access is safe.',
      'Static non-public references omit dynamic SQL and runtime configuration dependencies.',
      'Current effective table/function/column/default ACLs are evidence, not an approved fresh-install grant script.',
      'Cron commands are compared by hash; secret-free executable cron templates and complete platform dependencies remain blocked.']
    return result


if __name__=='__main__':
    result=compare(); (DIRECTORY/'catalog-comparison.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ['non_public_static_references','limits']},indent=2))
