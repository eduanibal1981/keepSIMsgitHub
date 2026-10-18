#!/usr/bin/env python3
"""Check the pinned Task 25 candidate locally. No deployment or approval path."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import sys

import build_deployment_manifest
import reproducible_sources

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'docs/reviews/coordinated-rollout-manifest-20261018.json'
REPOSITORIES = {'customer': 'keep_sims', 'admin': 'keep_sims_admin', 'backend': 'backend-sync-wt'}


def check_pins(manifest, parent):
    """Validate each scoped file before using any candidate evidence."""
    errors = []
    seen = set()
    if manifest.get('project_id') != 'zwxswagokhgbuzrrbnhr':
        errors.append('Unexpected target project')
    if manifest.get('status') != 'BLOCKED_PREPARATION_ONLY':
        errors.append('This checker supports only the blocked preparation candidate')
    if not manifest.get('pins'):
        errors.append('Missing pinned inputs')
    for pin in manifest.get('pins', []):
        component, name = pin['component'], pin['path']
        path = PurePosixPath(name)
        if (component not in REPOSITORIES or path.is_absolute() or not path.parts
                or '..' in path.parts or '\\' in name):
            errors.append('Unsafe pin path')
            continue
        key = component, name
        if key in seen:
            errors.append('Duplicate pin: ' + component + ':' + name)
        seen.add(key)
        repo = parent / REPOSITORIES[component]
        file = repo / name
        if (any((repo / Path(*path.parts[:i])).is_symlink() for i in range(1,len(path.parts)+1))
                or not file.is_file()
                or hashlib.sha256(file.read_bytes()).hexdigest() != pin['sha256']):
            errors.append('Source drift: ' + component + ':' + name)
    return errors


def check_candidate(manifest, root=ROOT):
    errors = check_pins(manifest, root.parent)
    source = json.loads((root / 'deployment/manifest.json').read_text())
    supplemental = manifest.get('supplemental_migrations_pending_review', [])
    if any(m['file'] != '20261018090000_worker_fleet_monitoring.sql' for m in supplemental):
        errors.append('Unexpected supplemental migration; review the candidate scope')
    if manifest['migration_order'] != source['upgrade']['candidate_dependency_order'] + supplemental:
        errors.append('Candidate migration order differs from Task 22 plus explicit Task 23 dependency')
    # Every deployment input already fingerprinted by Task 22 must be pinned by
    # this candidate too; empty/subset artifact lists cannot silently pass.
    expected = {('customer', 'deployment/manifest.json'), ('customer', 'deployment/source-lock.json')}
    expected.update(('customer', 'supabase/migrations/' + m['file']) for m in manifest['migration_order'])
    by_slug = {e['slug']: e for e in source['edge']}
    if not manifest['edge_candidates']:
        errors.append('Missing Edge candidates')
    for slug in manifest['edge_candidates']:
        edge = by_slug.get(slug)
        if not edge or not edge['source_files']:
            errors.append('Missing Edge source: ' + slug)
            continue
        expected.update(('customer', p['path']) for p in edge['source_files'])
    expected.update(('customer', p['path']) for p in source['edge_shared_sources'])
    expected.update(('backend', name) for name in manifest['worker_copy_set'])
    actual = {(p['component'], p['path']) for p in manifest['pins']}
    errors.extend('Missing pin: ' + c + ':' + p for c,p in sorted(expected-actual))
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--check', action='store_true', help='Check candidate file integrity only')
    mode.add_argument('--gate', action='store_true', help='Report blockers; always exits 2 for this candidate')
    args = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text())
    errors = check_candidate(manifest)
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print('Candidate pins and dependency order verified locally; no runtime verification')
    if args.gate:
        source = json.loads((ROOT / 'deployment/manifest.json').read_text())
        if source != build_deployment_manifest.generate():
            print('BLOCKING: Task 22 source manifest drift; refresh only after reviewing concurrent changes')
        try:
            lock = json.loads((ROOT / 'deployment/source-lock.json').read_text())
            reproducible_sources.verify(lock, ROOT.parent)
        except ValueError as error:
            print('BLOCKING: ' + str(error))
        for blocker in manifest['blockers']:
            print('BLOCKING: ' + blocker['id'] + ' — ' + blocker['detail'])
        print('Preparation candidate cannot authorize deployment or activation')
        return 2
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
