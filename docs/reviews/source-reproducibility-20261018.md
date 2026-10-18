# Task 22 — database and deployment source reproducibility

2026-10-18 (Asia/Muscat). **Source recovery and local tooling implemented;
complete production provisioning and coordinated upgrade remain BLOCKED.** No
deployment, migration/history write, account/balance change, provider request,
credential change or VM restart was performed. Existing customer/admin/backend
work was preserved; concurrent changes arriving during this work are included in
the candidate inventory, not attributed to Task 22.

## Findings and evidence

| Finding | Status | Evidence / practical limit |
| --- | --- | --- |
| F41, 16 names / 17 missing SQL signatures | REPAIRED LOCALLY | Recovered by signature/purpose from the existing supplied export into `supabase/recovered/20261018/public-routines.json`. All 17 exact body hashes match the fresh read-only live catalog. Both surviving legacy status overloads are represented as evidence; forward repairs retire them. |
| Remaining public routines | VERIFIED DEPLOYED, body/signature comparison only | All 369 export signatures/body hashes match the October 18 live catalog. This is not full-definition, owner, grant safety or runtime verification. |
| F40, supposedly absent live admin email | STALE; source gap REPAIRED LOCALLY | Active `send-admin-email` v2 was fetched read-only and preserved as non-executable evidence with entrypoint and platform-bundle hashes. Task 16's tested intentional replacement remains the pending release source. No email was sent. |
| Migration source/history agreement | OPEN, blocking | Live history has 239 rows through `20261016205533`; credential-control release is recorded. Original 23 remote-only rows still lack original migration statements. Do not infer dates or replay old source from names. |
| Archive verification | REPAIRED LOCALLY | All 240 immutable archived sources verify. The retained pending funding file changed after the original manifest; an explicit revision records both hashes and the current reviewed source. Original manifest/history is unchanged. |
| Worker runtime/source agreement | VERIFIED DEPLOYED hashes/dependency-file bytes only; activation still blocking | Fresh read-only VM metadata covers eight processes and 24 source hashes. Some differ from present source; this executor made no deployment. Exact runtime package/lock files were recovered into authoritative backend source after secret/URL/hash checks. Installed-module equivalence and clean installation remain unverified. |
| Complete clean provisioning / complete current-shape upgrade | OPEN, blocking | Existing subsystem fixtures plus recovered-source clean/upgrade checks pass, but omit complete platform/non-public/configuration/owner dependencies. No full baseline/reset claim is made. |

The [metadata snapshot](source-reproducibility-20261018/live-metadata.json) records
369 routines, 546 constraints, 1,453 table columns, 137 policies, 66 application
triggers (including the Auth signup trigger), seven views, relation/column/default
ACLs, effective client/service table privileges, eight installed extensions,
22 cron hashes/schedules, and 239 history rows. It contains no customer rows,
secret/config values, function bodies or cron command text.

The [comparison](source-reproducibility-20261018/catalog-comparison.json) compares
the previous evidence with the new capture. The previous 543 constraints and
65 public triggers match exactly when PostgreSQL uses the same non-pretty
deparse; all 137 USING/CHECK policy expressions and 22 cron command/schedule/active
triples match. Three credential routines were added; `admin_set_vault_secret`'s
body changed with that recorded release. Routine ACL differences are listed.
These comparisons establish source drift, not that the old grants are safe.

Automatic approval review rejected retrieval of full private production SQL
definitions and ownership metadata. Work continued with the existing supplied
export and a safer read-only hash/shape comparison. Full live definition/owner
parity remains an explicit blocker; it was not silently substituted with a body
hash. Recovery does not modify or install any production routine.

## Versioned sources and configuration

[The blocked candidate deployment manifest](../../deployment/manifest.json)
classifies every active migration, lists an explicit dependency order (Task 3
before later changed return shapes), records exact SQL/Edge/shared/worker hashes,
and separates observed live Edge versions/settings from desired local settings.
Unspecified gateway settings and the live-only `test-func-check` entrypoint are
blocking gaps, not defaults. New supplier reconciliation source is listed
separately from the eight freshly observed processes; dormant files are not
declared live. Worker delivery remains direct SSH/SCP when separately authorized.

The manifest records environment/Vault **names only**. It does not seed prices,
enable Firsty, enroll DID pilot users or provision secrets. Canonical membership
and fee policies, countries/carrier/provider routing, permitted feature gates,
catalogue refresh inputs, recovery templates, scheduled jobs, Auth/Storage/Vault/
net dependencies and relevant platform settings still need an approved minimum
configuration set. Captured extension versions/schema locations are prerequisites,
not recreated stand-ins. Static non-public references are listed in the comparison;
PL/pgSQL/dynamic SQL dependencies require additional review.

The [fresh worker metadata](source-reproducibility-20261018/live-worker-metadata.json)
contains no environment values or source bodies. Both dependency files copied
from `/home/abdal/keepsims_backend` match their VM SHA-256 values byte for byte;
the lockfile records 171 package entries and the eight PM2 records report Node
22.23.1. The recovered package files were added locally without installing packages,
changing existing backend files or touching the VM. These source/dependency
records do not prove running process memory, installed modules or provider health.

The initial full-archive packaging attempt correctly stopped at a real
credential-shaped literal in the pre-existing immutable international-calling
migration. Its value was not printed, copied to a bundle, edited or tested for
validity. The supported test snapshot includes only the six historical SQL files
actually consumed by current test tooling, listed in
`deployment/required-migration-sources.json`; all other archive sources remain
untouched in the original repository. This is a deliberate deployment/test source
scope, not a weaker secret rule or a complete repository/history export. Any
distribution of the entire historical archive remains blocked pending the
separately scoped credential/history treatment. An earlier broader scan also
reported synthetic maintenance-fixture assignments; after unrelated concurrent
scanner/fixture changes, the final customer scan returned zero active findings
and the one historical inventory finding. This is not a clean-history scan or
evidence of credential revocation.

`tools/build_deployment_manifest.py --check` detects source/config intent drift.
`--gate` deliberately exits **2**, listing unresolved blocking evidence. It cannot
deploy or mutate history. This is a Task 22 evidence gate, not Task 24's full gate.

## Repeatable source checkout and test procedure

`tools/reproducible_sources.py` locks deployment/test source in the customer,
admin and authoritative backend repositories, including current uncommitted and
untracked source bytes. Each component records its HEAD, dirty flag and per-file
SHA-256/mode; a HEAD alone cannot reproduce these working trees. Snapshot scopes
exclude environments, private signing keys, dependency/build caches, tool
credentials, unused historical SQL and historical worker mirrors. This is a source checkout for tests,
not a signed mobile release or credential backup.

From the customer repository:

```sh
python3 tools/migration_archive.py verify
python3 tools/build_deployment_manifest.py --check
python3 tools/reproducible_sources.py verify
python3 tools/reproducible_sources.py bundle /private/tmp/keepsims-task22.tar
python3 tools/reproducible_sources.py checkout /private/tmp/keepsims-task22.tar /private/tmp/keepsims-task22-checkout
```

The archive contains the lock and all selected source bytes, with deterministic
ordering/modes/owners/mtimes. Packaging refuses source drift and embedded runtime
secret findings. Checkout validates all paths, file kinds, duplicates and hashes
before writing; it refuses an existing destination and never alters the original
repositories. Keep the verified bundle with the release evidence until fixes are
committed in **all three** repositories. The lock does not itself contain dirty
source bytes, fetch commits or permit a missing bundle to be reconstructed.

The retained tested snapshot is `/private/tmp/keepsims-task22-source-verified.tar`
(SHA-256 `b259a2f8f3df43e675409a7a0aebd60f96fe92a321b1d497f821ae6b4bfc6b17`).
Its isolated checkout is `/private/tmp/keepsims-task22-checkout-verified`; its
deployment manifest reproduces exactly. `deployment/source-lock.json` identifies
that frozen source set. The working repositories continued changing in other
chats after capture, so a current-tree verification can correctly report drift;
review/re-lock before a later release. Final test receipts are outside the bundle
and do not claim those later edits were tested. Temporary artifacts must be
retained elsewhere before cleanup if they are needed for a future release.

At the isolated checkout's `keep_sims` root, run:

```sh
npm ci --prefix tools/financial-tests
python3 tools/reproducible_sources.py --parent .. --lock ../source-lock.json verify --checkout
python3 tools/reproducible_sources.py --parent .. test source
python3 tools/reproducible_sources.py --parent .. test contracts
python3 tools/reproducible_sources.py --parent .. test workers
python3 tools/reproducible_sources.py --parent .. test apps
```

The pinned financial package lock supplies PGlite 0.5.10 and embedded-postgres
18.4.0-beta.17. Existing cache overrides `PGLITE_MODULE_PATH` and
`EMBEDDED_POSTGRES_MODULE_PATH` remain supported. Worker tests resolve customer
SQL through adjacent `keep_sims`; the three component directory names are retained.
The customer financial fixture and DID harness now resolve historical SQL through
the verified archive resolver, avoiding hardcoded archive-category paths.
Task 24 still must pin supported Flutter/Node/PostgreSQL/Supabase/Deno/OS/runtime
versions and run all supported release checks; installed local tools are evidence,
not a blanket supported-toolchain decision. Installed dependency equivalence is not
proved by an unrelated machine's `node_modules` directory. The recovered backend
package/lock files are included as exact source bytes in the checkout.

## Controlled baseline and history procedure

1. Freeze reviewed source bytes from all three repositories. Keep history and
   current-shape evidence separate. Recover original remote-only statements where
   available, checking version/name/digest; missing original statements stay missing.
   Never fabricate original SQL or mark remote rows reverted because files moved.
2. Produce a **new, separately identified** clean-provisioning baseline from reviewed
   current contracts plus required non-public dependencies and non-secret seeds.
   Historical unsafe definitions and superseded migrations remain evidence outside
   its execution path. Do not install the recovered JSON as a baseline, restore the
   archive into a bulk push, or reset production.
3. On a disposable, pinned complete Supabase environment with outgoing effects and
   cron execution disabled, prove clean creation and all final contracts/grants/
   owners/constraints/extension/API behavior. Fixtures/adapters must be named;
   they cannot count as proof of managed platform or provider compatibility.
4. Independently reconstruct the complete captured current shape and history, add
   representative synthetic legacy states, then apply only the reviewed candidate
   dependency order. Compare its final normalized catalog and behavior with the
   clean path. Preserve uncertain provider work/holds and reject incompatible
   identities; do not invent funding or rebalance customers to make tests pass.
5. Keep fresh-install baseline lineage separate from existing project history.
   Any later baseline adoption/history reconciliation must be an explicitly
   scoped, backed-up, reviewed operation after both paths pass. This tooling has
   no `migration repair`, `db push`, history-write or remote reset implementation.
6. Refresh read-only live hashes, Edge source/settings, cron callers/templates,
   owners/effective grants and every required VM source/dependency version. Resolve
   all manifest blockers, then complete Tasks 23/24 and Task 25's separately
   authorized coordinated release. Urgent independently safe containment need
   not wait for broad history reconstruction.

## Verification and remaining obligations

Actual Task 22 results are saved under
`docs/reviews/source-reproducibility-20261018/`. Recovery checks use five isolated
clean/upgrade scenarios, not a complete production reset. The default financial
suite passed 107 SQL blocks with production-shaped constraints; fixture fidelity
and three safeguards passed. Seventy-six focused authoritative instant/scheduled/recovery
worker tests passed, and the restored snapshot passed 137 backend test-directory
tests. A **later frozen snapshot including concurrent Task 23 work** ran 148
backend tests: **147 passed / 1 failed**. The failure is
`test/worker_health_test.js`, “out of order/fenced responses do not trigger worker
purchase retries” (sequence 6 versus expected 7). No assertion was weakened or
test suppressed; it remains blocking until the responsible work is completed
and the next frozen source set is tested. The changed DID archive resolver
passed 17 Second Number SQL scenarios.
Twelve Python and two Node source tooling tests cover altered/new files, dirty-source
round trip, deterministic bundles, secret rejection and unsafe/tampered archives.
No app code was changed by Task 22. An attempted Flutter version query was blocked
by a write to the SDK cache outside workspace permissions; no new app test/build
claim is made.

Full clean/upgrade gates remain blocking, as do original history recovery,
definition/owner parity, complete non-public dependencies, reviewed config/seeds/
cron templates, Edge parity/import locks and current VM/runtime dependency proof.
Task 23 can use the candidate process/source inventory; its deployment and Tasks
24/25 release claims must retain these blockers. This executor did not run later
tasks; concurrent work was preserved and the new Task 23 migration is explicitly
excluded from this Task 22 candidate pending its separate review.

Migration/history procedure follows the
[Supabase migration guidance](https://supabase.com/docs/guides/deployment/database-migrations).
The project's archive/review-queue restrictions remain authoritative here.
