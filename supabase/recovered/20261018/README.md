# Recovered deployed source evidence

These files are **not migrations** and must not be loaded as a release baseline.
The deployment tooling has no path that applies them to a remote database.

`public-routines.json` recovers the audit's 16 names / 17 signatures, including
both surviving `update_execution_status` overloads. Each signature and exact body
hash matches the read-only October 18 catalog. All 369 exported public routine
bodies matched that catalog; this does not prove their owners, full definitions,
grants or dependencies match. The JSON records purpose and known successor.
Unsafe legacy wallet/worker definitions are historical evidence; apply the
reviewed forward replacements in the isolated contract suites before testing
repaired behavior. Do not reinstall obsolete overloads on an upgraded database.

`send-admin-email-v2.ts.txt` is the captured deployed v2 entrypoint, preserved with
a non-executable suffix. Task 16 intentionally replaces it with the current
`supabase/functions/send-admin-email` source and persisted claim/outcome contract.
The platform bundle hash in its metadata is not the hash of the entrypoint text.
Its remote unpinned import is also retained as evidence, not approved for reuse.

Regenerate the SQL evidence from the existing supplied export:

```sh
python3 tools/recover_database_sources.py /path/to/live_public_schema.sql
```

Recovery verifies signatures, exact body hashes and embedded-secret checks before
writing. It does not recover original migration dates or migration statements.
The remaining full-baseline/history/non-public/worker/config gaps block a claim
of a reproducible production deployment; see the Task 22 review.
