"""Locate, verify, and restore historical migration sources; never connect to a DB."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'docs/reviews/migration-cleanup-20261016/manifest.json'
REVISIONS = MANIFEST.with_name('source-revisions.json')


def source_entries():
    entries = json.loads(MANIFEST.read_text())['migrations']
    revisions = json.loads(REVISIONS.read_text())['revisions'] if REVISIONS.exists() else []
    by_file = {entry['file']: entry for entry in entries}
    seen = set()
    for revision in revisions:
        name = revision['file']
        entry = by_file[name]
        if name in seen or entry['action'] == 'archived' or entry['category'] != 'pending_remediation':
            raise ValueError(f'Cannot revise immutable historical source: {name}')
        if revision['original_sha256'] != entry['sha256']:
            raise ValueError(f'Revision provenance differs: {name}')
        if not (ROOT / revision['review']).is_file():
            raise ValueError(f'Revision review missing: {name}')
        entry['original_sha256'] = entry['sha256']
        entry['sha256'] = revision['sha256']
        seen.add(name)
    return entries


def migration_path(filename: str) -> Path:
    if Path(filename).name != filename:
        raise ValueError('Expected a migration filename')
    if '\\' in filename:
        raise ValueError('Expected a migration filename')
    active = ROOT / 'supabase/migrations' / filename
    entries = source_entries()
    entry = next((row for row in entries if row['file'] == filename), None)
    if active.is_file():
        if entry is not None and entry['action'] == 'archived' and hashlib.sha256(active.read_bytes()).hexdigest() != entry['sha256']:
            raise ValueError(f'Restored source differs: {filename}')
        return active
    if entry is None:
        raise FileNotFoundError(filename)
    source = ROOT / entry['current_path']
    if not source.is_file():
        raise FileNotFoundError(source)
    if hashlib.sha256(source.read_bytes()).hexdigest() != entry['sha256']:
        raise ValueError(f'Migration source changed: {filename}')
    return source


def verify_sources(required_only=False):
    entries = source_entries()
    if required_only:
        names = json.loads((ROOT / 'deployment/required-migration-sources.json').read_text())['files']
        known = {entry['file'] for entry in entries}
        if set(names) - known:
            raise ValueError('Required migration missing from archive manifest')
        entries = [entry for entry in entries if entry['file'] in names]
    for entry in entries:
        source = ROOT / entry['current_path']
        if hashlib.sha256(source.read_bytes()).hexdigest() != entry['sha256']:
            raise ValueError(f"Migration source changed: {entry['current_path']}")
        active = ROOT / entry['original_path']
        if active.exists() and active != source:
            if hashlib.sha256(active.read_bytes()).hexdigest() != entry['sha256']:
                raise ValueError(f"Restored source differs: {entry['original_path']}")
    return entries


def restore_sources(output: Path):
    entries = verify_sources()
    # Check every destination before writing; never overwrite different work.
    for entry in entries:
        destination = output / entry['file']
        if destination.exists():
            if hashlib.sha256(destination.read_bytes()).hexdigest() != entry['sha256']:
                raise ValueError(f'Refusing to overwrite modified file: {destination}')
    output.mkdir(parents=True, exist_ok=True)
    copied = 0
    for entry in entries:
        destination = output / entry['file']
        if not destination.exists():
            shutil.copy2(ROOT / entry['current_path'], destination)
            copied += 1
    print(f'Restored {copied} local source files to {output}. No database changes.')
    print('Local/remote timestamp differences still require history reconciliation.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['verify', 'restore', 'locate'])
    parser.add_argument('filename', nargs='?')
    parser.add_argument('--output', type=Path, default=ROOT / 'supabase/migrations')
    parser.add_argument('--required-only', action='store_true', help='Verify only the explicit historical test dependencies, not the complete archive')
    args = parser.parse_args()
    if args.command == 'verify':
        entries = verify_sources(args.required_only)
        print(f"Verified {len(entries)} migration sources; "
              f"{sum(row['action'] == 'archived' for row in entries)} immutable archived, "
              f"{sum('original_sha256' in row for row in entries)} explicitly revised pending.")
    elif args.command == 'restore':
        restore_sources(args.output.resolve())
    elif args.filename is None:
        parser.error('locate requires a filename')
    else:
        print(migration_path(args.filename))
