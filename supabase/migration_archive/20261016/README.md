# Historical migration sources

These 240 files were removed from the active migration queue on 2026-10-16 and
preserved byte-for-byte. They must not be bulk-reapplied to the existing database.

- `applied_history/`: 168 local files matched to recorded live versions/names.
- `live_represented/`: 50 files whose structural/routine effects are represented
  live, including verified newer replacements; historical backfill execution is
  not necessarily provable.
- `superseded/`: 22 obsolete/replaced changes, including the undeployed unsafe
  October 4 pricing proposal superseded by October 16's pending repair.

The [assessment and manifest](../../../docs/reviews/migration-cleanup-20261016/README.md)
record each reason, actual remote version mapping, original path and SHA-256.
The archive preserves historical SQL, including unsafe old definitions and seed
material; presence here is not approval to execute it.

Test builders resolve historical sources through the manifest. Run
`python3 tools/migration_archive.py verify` from the repository root to verify all
254 original sources (240 archived and 14 retained). `restore` copies historical
files back without changing the database or overwriting modified local files.
