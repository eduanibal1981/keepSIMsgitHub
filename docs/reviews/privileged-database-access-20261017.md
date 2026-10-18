# Task 3 — privileged database access and dangerous grants

Reviewed 2026-10-17 (Asia/Muscat). **REPAIRED LOCALLY; NOT DEPLOYED.**

Scope: Task 3 of `audit-executor-plan-20261016.md`. This is a separate containment
release, without wallet accounting, provider calls, customer balance repair or
worker/Edge deployment. Existing dirty work was preserved.

## Current evidence and finding status

Read-only MCP inspection of project `zwxswagokhgbuzrrbnhr` found PostgreSQL
17.6, 369 public application functions, 329 SECURITY DEFINER functions, and
115 public tables. Before containment, 39 definers were anon-executable and
193 were authenticated-executable. These counts describe access, not proven
exploitation: guarded admin APIs intentionally run as definers.

The [complete inventory and explicit application allowlist](privileged-database-access-20261017/allowlist.json)
records every function signature, owner, ACL, path, return shape, captured body
fingerprint and planned API execution roles, plus existing relation ACLs. The
[live catalog summary](privileged-database-access-20261017/live-catalog-summary.json)
records overlapping assertion failures, not a count of independent defects.

| Finding | Live status | Local treatment |
| --- | --- | --- |
| Unsafe text finalizer | OPEN: anon/authenticated/service execution | Remove all API-role execution; retain owner access only. UUID finalizer remains available. |
| Reaper | OPEN: anon/authenticated execution | Service/owner only; keep postgres cron invocation. |
| Scheduled health and raw log pruning | OPEN: client/service execution | Postgres only; guarded admin pruning wrapper remains authenticated/service callable. |
| Legacy `confirm_line_verification` | OPEN: client executable and owner can assert success without provider evidence | Disable direct API execution, including service. Use provider-backed settlement. |
| `settle_line_verification_attempt` and both `update_execution_status` overloads | STALE as a live client-grant finding: already service-only | Preserve existing service grants. Actual settlement success/retry tested in isolation. |
| Internal pricing/entitlement/health/authoritative-refill helpers | OPEN where client-executable; paid-premium helper already service-only | Remove client access; explicit service grants. Public quote APIs remain. |
| Fifteen admin RPCs with anon access | OPEN overgrant, but their live bodies call `assert_admin()` | Remove anon/PUBLIC; preserve authenticated admin entrypoints and server checks. |
| Return-trip and calling APIs accepting another user's ID | OPEN: retained APIs trusted supplied identity | Require signed-in self identity; trips additionally require owned line. Service callers retain explicit targeting. |
| `admin_prune_database_logs` audit insert | OPEN IN LIVE SOURCE: inserts into nonexistent `details` column | Write to existing `after_value` column; preserve atomic deletion/audit rollback. |
| Dangerous table grants | OPEN: TRUNCATE/REFERENCES/TRIGGER and PostgreSQL 17 MAINTAIN | Remove for PUBLIC/anon/authenticated, including column-level REFERENCES. Preserve existing row DML. |
| Broad defaults | OPEN for postgres and supabase_admin in public | Remove all client/PUBLIC function/table/sequence defaults at global and public-schema scopes. |
| Definer paths | OPEN: 156 functions need path hardening under the new policy, including two unpinned triggers | Preserve qualified empty paths; otherwise use pg_catalog, public, pg_temp. Revoke client CREATE on searched schemas. Pin three qualified trigger bodies to empty path. |

Live cron metadata shows both health checking and pruning run as **postgres**.
There are 22 active jobs; their commands were inspected without executing them.
No anon/authenticated/service role memberships were returned. RLS expressions
were inspected: the two anon-retained helpers are invoker JWT predicates
`is_power_user(uuid)` and `is_user_suspended()`, required by existing policies.
There are no anon-retained SECURITY DEFINER functions.

The previously prepared `20261016010000_financial_rpc_containment.sql` was
reviewed and left intact. The new migration completes its missing containment
surfaces without deploying its financial dependencies or rewriting history.

## Change and compatibility

Targeted migration:
`supabase/migrations/20261016210736_privileged_database_access.sql`.

The signed-in allowlist has 189 functions, including 175 definers. Other
application functions receive no client execution; existing worker grants
remain except the four deliberately retired/postgres-only APIs. Trigger
EXECUTE is unnecessary for an already installed trigger to run.

Five identity guards preserve current parameter names, default parameters and
return shapes. Supplier-cost projections and pricing calculations are unchanged
here; the separate retail/financial work remains required. This migration does
not claim to certify every retained financial or calling implementation.

The six replaced bodies have a fingerprint preflight. It accepts the captured
live body or this containment body, and fails before mutation on a different
version. In particular, it must not overwrite the later retail return contracts.
The migration is repeatable on this captured schema, not a reset baseline.

The admin app's database-operations API already calls the guarded
`admin_prune_database_logs`; its SQLSTATE handling supports the retained server
gate. Admin pricing/WhatsApp APIs retain their signatures. UI route gating is
not the authorization boundary and was not changed. No Flutter rebuild or live
UI exercise was performed for this SQL-only change.

Legacy verification clients need special care: the customer repository still
has an RPC-failure fallback that directly writes verification fields/activity;
the admin legacy verification controller also uses client-side confirmation.
Removing this RPC grant does **not** close those independent table-write paths.
Their removal and server-owned verification fields belong to Task 13. Do not
claim end-to-end liveness integrity from this containment release. Current
provider-backed verification quotes and service settlement remain available.

## Tests actually run

Run the isolated suite from the repository root:

```sh
PGLITE_MODULE_PATH=/tmp/keepsims-financial-tests/node_modules/@electric-sql/pglite/dist/index.js npm run test:privileges --prefix tools/financial-tests
```

Use the normal installed dependency instead by omitting `PGLITE_MODULE_PATH`.

The fixture recreates all 369 live function signatures, return shapes, definer
flags and effective API grants. Unexercised bodies are explicit throwing
stand-ins. Thirty-five relevant live bodies (including the five subsequently
replaced APIs) are captured as test input. Table column types come from the
live catalog; represented relation grants match the snapshot. Most table
constraints, RLS policies, external infrastructure and unrelated trigger chains
are omitted. This is an authorization test, not a financial baseline or full
Supabase integration test. No secrets or customer records are included.

**25 isolated regression tests passed.** The suite verifies the full function allowlist, dangerous table/column grants,
owner defaults, existing row DML/service-grant preservation, repeat application,
anon/user/admin denial of internal RPCs, all fifteen affected admin entrypoint
guards, user_metadata rejection, suspended-admin denial, legitimate admin list
and audited pruning, invalid pruning arguments, rollback on audit failure,
postgres health/pruning, service reaper, quote ownership, service settlement and
retry, self/foreign-user trip/calling access, temporary-object shadow resistance,
trigger execution after EXECUTE revocation, anonymous RLS helper availability,
future objects for both owners, and refusal to overwrite a newer body.

The matching `supabase/tests/privileged_database_access_tests.sql` is a
read-only catalog check: **zero rows is PASS**. It was executed against live
production before release and returned the expected outstanding violations.
Its MAINTAIN check is version-gated. No TRUNCATE was executed anywhere against
production. Production role behavior was not exercised: MCP runs as
`supabase_read_only_user`, without membership in application/owner roles.

Live security advisors were also read. They still report three definer-view
errors, two mutable paths, extension placement, intentional/unintentional RPC
exposure and leaked-password protection. Views, extension relocation and Auth
settings are outside this task. Advisor background state is not release proof.

## Separate release procedure — not executed

1. Obtain separately scoped deployment authorization. Recheck the captured
   definitions, all allowlist signatures, table privileges and cron usernames.
   The only October 16 migration currently in live history is the separate
   credential migration `20261016205533`.
2. Verify the release connection can administer **both postgres and
   supabase_admin default privileges**. This is not established by the read-only
   MCP connection. A normal restricted postgres connection may lack that right;
   use an appropriately privileged platform/operator path. The SQL deliberately
   fails and rolls back rather than silently skipping an owner. Do not claim
   defaults closed if that step is unavailable.
3. Apply only the reviewed containment SQL through a targeted migration
   operation. Do not push the pending migration directory wholesale. The
   October 4 pricing file and pending financial files remain separate reviews.
4. Run the read-only catalog test; require zero rows. Confirm runtime admin,
   quote, provider-verification and scheduled-job behavior under scoped safe
   probes. Verify actual cron health from subsequent normal runs; do not invoke
   production pruning or the reaper merely to test permission.
5. Run security advisors again and distinguish intentional allowlisted RPCs
   from remaining findings. Record the applied remote version and smoke-test
   evidence before changing this document to VERIFIED DEPLOYED.
6. Before the coordinated financial release, review migration ordering against
   this separate release. Later retail migrations change these return shapes;
   do not rerun the captured-body replacements over them. Revalidate the grant
   matrix after subsequent changes and deliberately extend it for any new
   customer API. The older `f0_grant_matrix_tests.sql` contains pre-existing
   edits and an outdated allowlist; it was preserved, not treated as current.

Task 4 can be prepared independently. Production containment remains pending
its authorized release; financial Tasks 6 onward and Task 13's verification
ownership work remain necessary. No next task was started.

Reference: [Supabase database functions and function privileges](https://supabase.com/docs/guides/database/functions).
The current documentation was consulted; the changelog markdown endpoint could
not be fetched in this environment. The implementation was checked against the
live PostgreSQL catalog and the local PostgreSQL engine instead.
