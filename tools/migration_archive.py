"""Locate, verify, and restore historical migration sources; never connect to a DB."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'docs/reviews/migration-cleanup-20261016/manifest.json'


def migration_path(filename: str) -> Path:
    if Path(filename).name != filename:
        raise ValueError('Expected a migration filename')
    active = ROOT / 'supabase/migrations' / filename
    if active.is_file():
        return active
    entries = json.loads(MANIFEST.read_text())['migrations']
    entry = next((row for row in entries if row['file'] == filename), None)
    if entry is None:
        raise FileNotFoundError(filename)
    source = ROOT / entry['current_path']
    if not source.is_file():
        raise FileNotFoundError(source)
    return source


def verify_sources():
    entries = json.loads(MANIFEST.read_text())['migrations']
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
    args = parser.parse_args()
    if args.command == 'verify':
        entries = verify_sources()
        print(f"Verified {len(entries)} unchanged migration sources; "
              f"{sum(row['action'] == 'archived' for row in entries)} archived.")
    elif args.command == 'restore':
        restore_sources(args.output.resolve())
    elif args.filename is None:
        parser.error('locate requires a filename')
    else:
        print(migration_path(args.filename))
