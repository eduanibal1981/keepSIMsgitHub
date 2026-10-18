# Isolated financial regression tests

Task 22 adds `npm run test:source-recovery --prefix tools/financial-tests`.
It verifies 17 recovered signatures/bodies and their captured API ACLs on clean
and existing-identity/wallet **bounded** fixtures, then applies the real financial
forward repairs and checks retirement of obsolete overloads. Five scenarios pass;
this is not a complete Supabase reset/upgrade. `SOURCE_RECOVERY_REPORT` saves its
structured evidence. Historical SQL dependencies now use the archive resolver.
For three-repository source packaging/checkouts and the explicitly blocked full
baseline/history/deployment gate, see
[Task 22](../../docs/reviews/source-reproducibility-20261018.md).

From the repository root:

```sh
npm ci --prefix tools/financial-tests
npm test --prefix tools/financial-tests
npm run test:fixture --prefix tools/financial-tests
npm run test:setup --prefix tools/financial-tests
npm run test:scheduled --prefix tools/financial-tests
npm run test:concurrency --prefix tools/financial-tests
npm run test:credentials --prefix tools/financial-tests
npm run test:privileges --prefix tools/financial-tests
```

The first two runs use PostgreSQL in WASM (PGlite). The concurrency run starts a disposable native PostgreSQL server bound to `127.0.0.1:56543`, creates separate sessions, then stops it and removes its temporary directory. Set `FINANCIAL_TEST_PORT` to choose another local port. Native PostgreSQL requires local shared-memory permissions. Package managers that block dependency install scripts must allow the embedded-postgres platform package's symlink hydration script.

The financial harness reconstructs the bounded captured production catalog in
`supabase/tests/fixtures/financial_production_snapshot.json`, verifies its
constraints/NOT NULLs/types/generated columns/FKs/unique indexes/API grants/RLS/
selected real functions and triggers/reconciliation view, then applies the actual
pending `202610160*.sql` migrations unchanged. It is not a complete production
baseline. The infrastructure SQL contains only explicit Auth/external adapters;
see [Task 6's inventory and omissions](../../docs/reviews/financial-production-contracts-20261017.md).
The read-only snapshot capture query is beside the JSON fixture. Review refreshes
rather than automatically accepting live changes. The old
`TEST_OCTOBER4_APPLIED` history mode is rejected because this baseline represents
captured production, not a pre-October-4 schema.

`test:fixture` checks catalog fidelity and three safeguard blocks. The current
wallet/funding repairs pass the financial and concurrency gates. Task 9 adds
`test:setup` (10 focused scenarios), also included in the default financial run
and the native concurrency run (with two additional independent-session races).
Each SQL DO block rolls back independently; later cases still run after a failure.
Set `FINANCIAL_TEST_REPORT=/absolute/path/report.json` for structured outcomes.
The report distinguishes block/scenario counts from individual assertions.

Task 9 applies the actual `_sim_setup_instant_settlement.sql` migration after
the eight pending October 16 financial migrations. It tests the current pending
pricing interface with a synthetic published zero refill-fee promotion: a $5
Premium fee plus $1 refill is quoted/ordered/reserved through the real RPCs.
That verifies settlement at exact/surplus balances, rather than certifying final
pricing policy (Task 18). The catalogue adapter now includes `offer_value`, which
the actual dispatch function consumes; no financial constraint was loosened.
The new scenarios cover bound reservation rejection, committed submission,
provider identity on retry, safe failure/fallback/cancellation, receipt/schedule
rollback, and concurrent settlement/finalization/submission versus fallback.

These SQL-only suites use synthetic data and never call Supabase, PayPal, carriers or
workers. They do not certify provider delivery, cryptographic JWT handling,
PostgREST overload resolution, complete trigger chains or production deployment.
Native PostgreSQL needs local shared-memory permissions. Existing captured API
grants remain faithful even when unsafe; Task 3's suite tests containment.

Task 10 adds `test:scheduled` (21 scheduled scenarios plus a forward-migration
dependency/rollback check). The same 21 scenarios run in the default suite; the
native suite adds two independent-session scheduled races. The actual Task 10
migration follows Task 9's completion. The fixture now captures both actual live
`update_execution_status` overloads, bringing its selected function count to 44;
the migration retires them with RESTRICT. No production constraint was relaxed.

`test:scheduled:http` additionally starts real PostgREST and native PostgreSQL on
localhost and makes the exact named worker RPC requests, including defaulted
settlement calls, permission denials, duplicate settlement and PIN persistence.
Set `POSTGREST_BINARY` to an explicitly supplied verified executable; the runner
never downloads one or reads application credentials. This task verified official
PostgREST 16.4; its release-asset digest and reproduction notes are in the
[Task 10 review](../../docs/reviews/scheduled-refill-holds-worker-contracts-20261017.md).
macOS may require `DYLD_LIBRARY_PATH` pointing to the embedded PostgreSQL
`native/lib` directory. Default ports are 56553/56554; use `FINANCIAL_TEST_PORT`
and `FINANCIAL_HTTP_PORT` to override them. This is isolated HTTP evidence, not
deployed Supabase/cache/provider certification. The runner stops both servers
and removes its disposable database.

The instant-worker change and its eight executable boundary tests live in the sibling authoritative backend repository. Run `node --test ../backend-sync-wt/test/instant_refill_boundary_test.js` from this repository. Deploy that worker with the submission-boundary and Task 9 settlement migrations before resuming instant processing. The worker now uses the atomic pre-submission failure RPC instead of releasing a hold from its snapshot. Legacy reservations remain version 0 until explicitly reconciled.

The separate credential suite applies the complete Task 2 credential migration
to an isolated fixture with API roles, broad default grants, a claim-checking
`assert_admin`, private Vault stand-ins and a metadata audit recorder. It tests
authorization, direct table denial, version conflicts, write-only responses,
validation, legacy WhatsApp compatibility, sanitized failures and transaction
rollback. It also verifies version-bound operator completion, idempotent
confirmation, automatic return to pending after another replacement, audit
rollback, legacy alias protection and the minimum relay-secret length.
Vault encryption, JWT cryptographic verification, independently
concurrent sessions, external provider validity/revocation, Edge/VM propagation
and deployment are outside this fixture. All credential values are synthetic;
the suite never connects to Supabase or providers. The financial bootstrap
excludes this migration because its dependencies belong to that separate fixture.

Task 3's separate `test:privileges` suite applies the actual
`20261016210736_privileged_database_access.sql` containment migration. It
recreates all captured live function signatures and grants, exercises selected
actual function bodies under API/owner roles, and checks dangerous table and
column grants, defaults for both owners, admin/ownership checks, cron access,
audit rollback, trigger compatibility and search-path shadowing. It has no
network or production writes. Its fixture omits unrelated RLS policies,
constraints and bodies; it is not a financial or complete Supabase baseline.
See `docs/reviews/privileged-database-access-20261017.md` for evidence and the
separately authorized targeted release procedure. The runner accepts the same
`PGLITE_MODULE_PATH` override as the other WASM suites.

If PGlite is already installed in a separate dependency cache, both isolated
WASM runners accept `PGLITE_MODULE_PATH` pointing to its absolute
`@electric-sql/pglite/dist/index.js` path. For example:

```sh
PGLITE_MODULE_PATH=/absolute/cache/node_modules/@electric-sql/pglite/dist/index.js npm run test:credentials --prefix tools/financial-tests
```

Task 4 has separate `test:webhooks` (PGlite) and
`test:webhooks:concurrency` (independent native PostgreSQL sessions) scripts.
They apply only `20261017100000_endpoint_webhook_authentication.sql` to the
minimal endpoint fixture; they do not run the pending financial repairs.
The concurrency server binds `127.0.0.1:56544` (override `WEBHOOK_TEST_PORT`),
stops and removes its temporary directory. `PGLITE_MODULE_PATH` and
`EMBEDDED_POSTGRES_MODULE_PATH` support existing dependency caches.
See `docs/reviews/endpoint-authentication-20261017.md` for the 38 Edge/adapter,
12 SQL and 3 native concurrency checks, compatibility and release requirements.

Task 5 has `test:paypal` (30 PGlite regressions across captured-live and exact M2
deposit definitions) and `test:paypal:concurrency` (4 independent-session native
PostgreSQL checks, local port 56545; override `PAYPAL_TEST_PORT`). Both use the
captured payment-table constraints and indexes, with the omissions described in
`docs/reviews/paypal-capture-fulfillment-20261017.md`. They never connect to an
external database/provider. The same PGLITE_MODULE_PATH and
EMBEDDED_POSTGRES_MODULE_PATH cache overrides are supported. Actual Edge/provider/
SQL integration runs separately with
`node --test test/paypal_capture_fulfillment.test.cjs` (14 tests; set
PGLITE_MODULE_PATH if dependencies are installed outside tools/financial-tests).
This focused suite does not validate the entire pending financial package.

Task 11's `supplier-recovery.mjs` runs in the default and native concurrency
suites after the Task 9/10 and supplier-outcome recovery migrations. It covers
durable submission/lease fencing, exact-once settlement, setup completion without
an app reopen, legacy/supplier uncertainty, active call/payout reservations and
same-line duplicate prevention. The fixture uses supported synthetic supplier
names and fully bound execution IDs; no real provider request is made.
The HTTP suite also exercises the actual named claim/completion payloads and
negative client roles. On macOS use `POSTGREST_LIBRARY_PATH` for the optional
PostgREST loader path, scoped to that child process; avoid injecting it into
Node/initdb. See `docs/reviews/supplier-outcome-recovery-20261018.md`.

Task 12 adds `test:liveness` with 15 production-shaped verification scenarios and
read-only catalog checks. The default financial suite also runs these checks;
the native suite adds three independent-session races. `test:scheduled:http`
now verifies named/defaulted verification RPC calls and role/resource denials
through actual PostgREST. The Task 12 migration follows Task 11 in the shared
financial bootstrap. See the [verification repair record](../../docs/reviews/liveness-verification-repair-20261018.md)
for deployment dependencies and the distinction between fixture/API/provider
and live evidence. No legacy success/log text is accepted as provider proof.

Task 14's `test:notifications` starts isolated native PostgreSQL on
`127.0.0.1:56549` (override `NOTIFICATION_TEST_PORT`) and removes its temporary
database afterward. It supports `EMBEDDED_POSTGRES_MODULE_PATH` for an existing
dependency cache. It reproduces the original category failure, then applies
only `20261018010000_notification_scheduler_contract.sql` and runs 24 scenarios,
including independent-session sweep races. Run with:

```sh
npm run test:notifications --prefix tools/financial-tests
```

The data-free notification fixture retains 21 production table shapes, their
checks and local foreign keys, indexes, 13 function bodies verified against the
October 16 catalog hashes, and the actual notification/system-alert triggers.
Regenerate it from the supplied public schema dump with
`python3 tools/financial-tests/capture-notification-fixture.py /path/to/live_public_schema.sql`.
Its JSON manifest records the excluded payment-gateway foreign key and other
boundaries. The runner invokes the exact recorded cron SQL as `postgres`;
it does not install pg_cron, contact Supabase/providers, or certify API table
ACL/RLS parity or external delivery. See the
[notification repair record](../../docs/reviews/notification-scheduler-repair-20261018.md)
for behavior, evidence and the targeted deployment procedure.

Task 15's `test:forecasts` uses native PostgreSQL on `127.0.0.1:56550`
(override `FORECAST_TEST_PORT`) and supports `EMBEDDED_POSTGRES_MODULE_PATH`.
It loads the notification baseline plus the captured forecast extension,
reproduces the missing relation and invalid legacy method, then applies Task 14
and Task 15's actual forward SQL contracts. Its 32 scenarios cover mixed
subjects, missing metadata, expiry/sampling/reset boundaries, numerical limits,
manual owner/manager access, failure isolation, alerts and concurrent refreshes.
It never connects to production or providers and removes its temporary database.

```sh
npm run test:forecasts --prefix tools/financial-tests
python3 tools/financial-tests/capture-notification-fixture.py /path/to/live_public_schema.sql --forecasts
```

The extension retains seven additional production table shapes, their constraints
and indexes, and six catalog-verified function bodies. It requires the existing
notification fixture. Auth lifecycle, table ACL/RLS parity, health/rescue trigger
chains, pg_cron's daemon and external usage/activation truth remain outside the
fixture. See [Task 15 evidence](../../docs/reviews/usage-forecast-repair-20261018.md)
before interpreting local results as deployment or provider verification.

Task 16's `test:maintenance` runs 29 native PostgreSQL scenarios on loopback port
56551 (override `MAINTENANCE_TEST_PORT`, dependency cache override
`EMBEDDED_POSTGRES_MODULE_PATH`). It recreates the three original SQL failures,
then applies only the Task 16 migration to the captured maintenance/notification
contracts. It tests pruning/audit rollback, rate thresholds, queued deletion,
actor retention, failure/retry/cancellation, role/grant denial, financial/provider
review gates, email state and independent-session claims. Three scenarios execute
the actual Edge handlers against actual named SQL RPCs; Storage/Auth/provider
adapters are synthetic and isolated Auth removal uses only the temporary database.

```sh
npm run test:maintenance --prefix tools/financial-tests
node --test test/admin_maintenance_endpoints.test.cjs
python3 tools/financial-tests/capture-notification-fixture.py /path/to/live_public_schema.sql --maintenance
```

The extension retains eleven table shapes and fourteen function bodies verified
against the stored live catalog. Vault/pg_net/cron relations are stand-ins;
unrelated trigger chains, full table ACL/RLS parity, live Auth/Storage behavior
and provider delivery remain outside the fixture. The 20 Edge adapter tests also
exercise nested/paginated cleanup, authentication, ambiguous email outcomes and
audit failure. No real deletion/email request is made. See
[Task 16 verification](../../docs/reviews/admin-maintenance-deletion-repair-20261018.md)
for the intentional email replacement and coordinated release requirements.

Task 17 extends `test:second-number` with the actual forward financial-safety
migration, the captured legacy DID table grants, service-only catalog checks,
quote/gate/available-funds/hold-binding denials and ledger failure rollback. Set
`SECOND_NUMBER_NATIVE=1` and `EMBEDDED_POSTGRES_MODULE_PATH` to run independent
PostgreSQL sessions for purchase and renewal races (loopback port 56549). The
PGlite mode runs the sequential scenarios. Provider/Auth/cron behavior remains
isolated or omitted; no customer or supplier action is performed. See
[Task 17 verification and activation gates](../../docs/reviews/virtual-number-financial-safety-20261018.md).

Task 18's `test:pricing` applies the real forward unified-pricing/evidence migration
after the pending financial/setup/calling contracts. It captures additional
production table/check dependencies and the actual eSIM purchase function, then
runs explicit reference pricing fixtures. `PRICING_NATIVE=1` uses independent
PostgreSQL sessions on loopback port 56552 for upgrade-credit and Task 9 setup/
fallback races; configure `EMBEDDED_POSTGRES_MODULE_PATH` or installed dependencies.
`PGLITE_MODULE_PATH` supports the sequential runner. Forty native scenarios pass;
the standalone pricing runner is required because the older generic migration
bootstrap does not implicitly include this release. No live/provider action is
performed. See [Task 18 verification and limitations](../../docs/reviews/pricing-entitlement-unification-20261018.md).

```sh
npm run test:pricing --prefix tools/financial-tests
PRICING_NATIVE=1 node tools/financial-tests/pricing.mjs
```


Task 13 adds `test:calls` (`calls.mjs`) and the read-only
`supabase/tests/call_budget_contract_tests.sql` guard. The shared fixture loads
the retained real `call_media_sessions` DDL, outside its original bounded table
snapshot, before the call-budget forward migration. The default suite includes
14 call scenarios; native concurrency adds four independent-session races. The
PostgREST runner adds two call-specific HTTP scenarios through `calls-http.mjs`.
Run Edge regressions with `node --test test/call_budget_endpoint.test.cjs
test/call_media_backend.test.cjs test/endpoint_webhook_auth.test.cjs
test/provider_secrets.test.cjs`. Read
[Task 13 evidence and provider/release limits](../../docs/reviews/call-budget-billing-20261018.md).

Task 19 adds `test:retail` (`retail.mjs`), a native PostgreSQL-only suite on
localhost port 56557 (`RETAIL_TEST_PORT` overrides). It uses the existing
financial bootstrap, actual Task 18 pricing, and the data-free
`retail_ownership_baseline.sql` extension. The extension generator verifies 13
function bodies against the independently captured catalogue. The suite starts
from Task 3's contained legacy response shapes and historical column grants,
then applies the actual Task 19 migration. Twenty-three cases verify retail-only
catalogue/receipt/RPC paths, direct reads, owner/manager/admin denials, trip
history, exact range submissions, zero fees and insertion-time price drift.
Set `EMBEDDED_POSTGRES_MODULE_PATH` to a pinned cache entry and
`RETAIL_TEST_REPORT` to save outcomes. It removes the disposable database after
execution. It neither connects to Supabase/providers nor substitutes for the
Task 24 API/build gate. See [Task 19 evidence and release order](../../docs/reviews/retail-ownership-repair-20261018.md).

Task 20 adds `test:schedules` (`schedules.mjs`), a native PostgreSQL suite on
localhost 56558 (`SCHEDULE_TEST_PORT`). It adds ten hash-verified real scheduling
functions and the actual queue/success triggers to the financial/pricing/retail
fixture, seeds old yearly work, applies the forward boundary, and runs 26 SQL
cases plus three independent-session races. The optional `POSTGREST_BINARY`
enables seven real HTTP cases on 56559 (`SCHEDULE_HTTP_PORT`); macOS may need
`POSTGREST_LIBRARY_PATH` pointing to the pinned native libraries. Set
`EMBEDDED_POSTGRES_MODULE_PATH` for an existing dependency cache and
`SCHEDULE_TEST_REPORT` for outcomes. No downloads, live connections or provider
requests occur. The disposable database is deleted afterward. Regenerate the
data-free extension with `capture-schedule-fixture.py <schema-export.sql>`;
function bodies must match the independent catalogue. Health/notification/risk
adapters and external provider behavior remain fixture limits. See
[Task 20 evidence and coordinated release](../../docs/reviews/scheduled-pricing-boundary-20261018.md).

Task 21 adds `test:vouchers` (`vouchers.mjs`), an isolated PGlite suite using the
captured production financial baseline plus `offline_voucher_baseline.sql`.
Regenerate the data-free extension with
`capture-voucher-fixture.py <schema-export.sql>`; both original RPC bodies must
match the independent catalogue hashes. It reproduces the old open-request bug,
applies the targeted repair, and checks every lifecycle state, role/ownership
boundaries, secret-free projection and existing admin filters. Successful SQL
runs regenerate `test/fixtures/offline_voucher_state_payloads.json`, consumed by
customer cache/model/widget tests. Set `PGLITE_MODULE_PATH` for an existing pinned
dependency cache and `FINANCIAL_TEST_REPORT` to save results. No network, real
stock, voucher mutations, provider purchase or recovery endpoints are exercised.
See [Task 21 evidence](../../docs/reviews/offline-voucher-state-repair-20261018.md).

Task 23 adds `test:fleet` (`fleet.mjs`). It reconstructs the financial baseline,
pricing/voucher table contracts and the captured fleet extension, applies the
actual monitoring migration, and exercises every required worker's stopped and
stalled states plus queue/claim/reconciliation failures, grants, role denials,
secret-free projection, probe-cache freshness, alert retry/deduplication and the
real Node reporter-to-SQL contract. Set `FLEET_NATIVE=1` and
`EMBEDDED_POSTGRES_MODULE_PATH` for isolated native PostgreSQL (port 56560,
override `FLEET_TEST_PORT`); native mode also tests independent concurrent alert
sweeps. PGlite uses `PGLITE_MODULE_PATH`. `FLEET_TEST_REPORT` records outcomes.
Regenerate the extra table fixture with `capture-fleet-fixture.py <schema.sql>`.
The fixture's cron relations are adapters with real `job`/`job_run_details`
column names, not an installed scheduler. No live service is stopped or started,
and no payment, provider or messaging API is called. See
[Task 23 verification](../../docs/reviews/worker-fleet-monitoring-20261018.md).
