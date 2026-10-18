# Task 25 — coordinated rollout candidate and execution record

Prepared 2026-10-18, Asia/Muscat. **PREPARATION COMPLETE; ROLLOUT BLOCKED AND
NOT PERFORMED.** This is the Task 25 work package from the
[executor plan](audit-executor-plan-20261016.md), starting from the
[October 16 financial rollout](supabase-financial-security-remediation-20261016.md)
and incorporating Tasks 3–22 plus the concurrent Task 23 candidate dependency.
Tasks 23/24 changes arrived during preparation; their completed fleet/release-gate
evidence is still required. This document does not implement those tasks or
authorize an operational release.

## Candidate, target and authorization

The [operational manifest](coordinated-rollout-manifest-20261018.json)
pins the Task 22 source manifest/three-repository lock, its 25 SQL files plus
the explicitly pending-review Task 23 fleet migration (26 files in dependency
order), selected Edge/shared sources, authoritative worker copy set,
preflights and this runbook. Dirty repositories require the actual source bundle;
the recorded HEADs cannot reproduce their current contents. Client version names
come from each pubspec; signed artifact digests, distribution channel and minimum
supported client versions remain unset. Those are blocking release inputs.

Keep this review envelope (manifest/runbook/results) beside the retained source
bundle. Its manifest is deliberately outside the source-lock selection: it pins
the lock's hash without being included in that same lock, avoiding a circular
hash dependency. Verify the envelope against the isolated source checkout before
any approval; record the envelope manifest's own digest in the authorization.

| Target | Candidate identity; verify again before execution |
| --- | --- |
| Supabase | Production `simSaveDB`, project `zwxswagokhgbuzrrbnhr`, expected endpoint `https://zwxswagokhgbuzrrbnhr.supabase.co` |
| History | October 18 evidence: 239 rows, latest `20261016205533`; refresh and diff, never assume still current |
| Workers | `abdal@34.40.33.208`, `/home/abdal/keepsims_backend/servers/`; authority `../backend-sync-wt` |
| Customer/admin | `keep_sims` / `keep_sims_admin`, pinned dirty sources; signed builds and supported targets pending Task 24 |
| Operational scope now | Local preparation and verification only; permitted provider spend is **USD 0**, no test accounts enrolled |

Before any operational action, the release owner must authorize a **specific
manifest digest**, target, window, executing operator, recovery operator and
allowed actions. Record test account references privately, payment rail/provider
environment, maximum cumulative spend and exposure (including DID recurring
costs), per-operation limits and expiry. Authorization must distinguish deployment,
processor pauses/restarts, cron/config changes, sandbox tests and real production
spend. An approved deployment alone does not authorize purchases, payouts,
credential rotation, customer balance repairs or account deletion. The present
request to perform Task 25 does not supply that separate scoped authorization.

No universal money-processing kill switch has been verified. Every pause below
needs a reviewed server control and a proven denial check. A hidden UI, a stopped
worker, disabled carrier routing or a flag with an assumed name cannot establish
that all financial initiators are stopped. If any required boundary lacks a
working control, stop the release before applying financial SQL.

## Blocking evidence and local checks

Run from `keep_sims`:

```sh
python3 tools/check_coordinated_rollout.py --check
python3 tools/check_coordinated_rollout.py --gate
python3 tools/build_deployment_manifest.py --check
python3 tools/build_deployment_manifest.py --gate
python3 tools/migration_archive.py verify
python3 tools/reproducible_sources.py verify
```

The first check verifies local candidate integrity only. Both gates intentionally
exit 2 for this blocked candidate; neither can approve or deploy. The existing
source lock already drifted before Task 25 (six customer tooling/documentation
files). Source-lock refreshes and further fleet/release-gate changes arrived
during this task; the gate reports the current differences rather than claiming
the original six remain unchanged. This task's new files also need a successor
freeze. Do not overwrite the
Task 22 lock to disguise that result. Review all source changes, capture a new
lock and deterministic bundle using Task 22's tooling, rerun the applicable gates
on that exact checkout, then issue a **new** candidate with matching hashes.
Keep the previous manifest/lock/evidence for comparison.

Mandatory evidence before a broad financial cutover:

1. Task 22 complete current-shape upgrade and provisioning checks; definitions,
   owners, defaults, dependencies, approved effective configuration and cron
   contracts; explain the original-history gaps. No reset, history fabrication,
   archive replay or unfiltered `db push` is permitted by this runbook.
2. Task 23 confirmed fleet, runtime dependencies, heartbeats, backlog/age alerts
   and stopped/stalled-process detection. Task 22 now contains October 18 VM
   hashes and recovered package/lock sources; installed dependency equivalence
   and parity with the concurrent instrumented workers remain unverified.
3. Task 24 supported/pinned toolchains, customer/admin analysis, full tests and
   signed target builds, SQL constraints/roles and independent-session races,
   actual PostgREST overloads, Edge runtime/import locks, worker/provider crash
   boundaries, secret/source checks and CI. Historical passing focused counts
   cannot substitute for this exact candidate's release gate.
4. Explicit Edge gateway modes for every selected slug. The existing manifest
   lacks desired settings for `get-turn-credentials` and `validate-sim-liveness`;
   resolve those against intended callers before deployment. Verify signing-key
   presence, canonical callback URLs, account/merchant binding and internal
   voicemail caller compatibility without reading values into release logs.
5. Recovery evidence below, approved containment controls, completed reconciliation
   dispositions and separate operational authorization. Unknown remains blocking.

Independently safe urgent Task 3 containment can be reviewed/released separately;
it does not wait for complete historical reconstruction. Its original-body guards
must hold and its admin/cron callers must work. It must precede newer changed RPC
shapes and must never be replayed over the completed financial/retail contracts.

## Backups and recovery proof — before the window

Record the managed database backup/PITR identifier, capture time, retention,
restorable range, approved RPO/RTO and an isolated restore-drill evidence link.
Verify the restored data/catalog and required Auth/Storage/Vault/cron dependencies;
do not assume a public SQL export backs up every platform or secret dependency.
Keep secret backups in the existing private operational store, never this repo.

Capture the **actual previous deployed** Edge bundles/settings and worker
files/modules/PM2 definitions/dependency versions, sanitized config state, client
artifact digests and the new source bundle digest. Retain these privately with
access controls. Do not copy a VM `.env` into a source artifact or dump the PM2
environment into the transcript. An old binary backup is evidence; it is not
automatically compatible with the new database.

A whole-database restore after external side effects needs a separately approved
incident procedure that reconciles provider transactions accepted after the
restore point. Restoring database state cannot undo a completed payment or
supplier purchase. No restore has been tested or authorized by this task.

## Read-only preflight and legacy disposition

Refresh the project identity/history, selected function body/definition/owner and
effective grant metadata, Edge versions/settings/imports, cron users/schedules and
VM file/module/runtime hashes. Prefer available Supabase MCP read-only tools.
No Supabase MCP tools were exposed in this session; this task made no fresh live
database or VM claim. A failed/missing query is an evidence gap, never zero issues.

Run the manifest's explicit preflight list, including the existing
[financial preflight](../../supabase/verification/financial_remediation_preflight.sql),
[legacy wallet diagnostics](wallet-legacy-reconciliation-20261017.sql), and new
[aggregate rollout inventory](../../supabase/verification/coordinated_rollout_preflight.sql).
Use a read-only transaction and a role able to see all relevant rows; customer
RLS-filtered counts cannot prove fleet-wide consistency. The new inventory is
compatible with absent new version columns but reports their absence as legacy.
Do not run every file under `verification/`: `install_second_number_scheduler.sql`
performs writes. Likewise several SQL regression files mutate isolated fixtures
and must never be treated as production read-only smoke tests.

Retain a timestamped initial snapshot, then repeat after all writers have quiesced
and immediately before activation. Use aggregate counts in public evidence and
restricted correlation IDs/provider receipts in the private operator case log.

| Inventory | Required disposition before activation |
| --- | --- |
| Wallet vs lots, holds vs balance/allocations, ownership/currency, signed ledger/chronology | Explain every discrepancy through the approved accounting process. October 17 evidence reports one wallet-vs-signed-ledger difference; it is unresolved evidence, not proof of loss or a value to overwrite. Money-migration guards must pass. |
| Legacy refill/setup submissions, failed/dead-lettered work with provider identity | Query the authenticated supplier using the original reference, bind delivery/capture or proven terminal failure. Quarantine unknowns and block another purchase of the affected line. No version promotion or resubmission from missing local evidence. |
| Pending/processing/ambiguous refund items | Match provider capture, payout ID, paid amount and original allocation; adopt/poll known payouts. Missing payout IDs after submission require provider investigation, never another payout. |
| Original-funding reversals, including generic/eSIM/call labels | Prove original debit and consumed lot provenance/refundability. The inventory reports candidate linkage only; a single match does not recover allocation proof. Missing legacy allocations block the affected reversal; invent no lots. |
| Expired/ambiguous holds, active calls and verification attempts | Establish provider outcome and ownership. Expiry, a false legacy marker or PM2 downtime cannot justify release. Keep uncertain funds reserved; no new calls until old nonterminal calls are reconciled. |
| Legacy schedules, DIDs/eSIM/voucher orders | Preserve provider work/holds and historical accepted prices. Task 20 pauses old paid schedules for fresh authorization. Keep existing DIDs out of recurring enrollment; verify supplier liabilities before any pilot. |

Assign each case an operator, evidence link, disposition, authorization and
verification timestamp. Counts need not all become zero: quarantined uncertainty
may persist only with a proven server exclusion and approved explicit scope.
Unexplained wallet differences, broken integrity guards or an unbounded supplier
liability block financial activation. No blanket legacy-data repair is included.

## Execution sequence — only after the blocking inputs are satisfied

1. **Freeze and contain.** Announce the authorized window through the established
   operator process. Enforce and check server restrictions on setup/plan/wallet
   mutations, instant/scheduled refill, deposits/capture, refunds, eSIM/voucher
   purchases, paid verification, outgoing calls and DID purchase/renewal. Pause
   initiation, while keeping authenticated settlement callbacks and evidence
   ingestion available under the approved compatible path. If callbacks cannot
   be processed during cutover, prove durable provider retries/replay before
   pausing; never acknowledge an event that was not durably accepted.
2. **Quiesce every writer.** Stop the old `worker_instant_refill`,
   `worker_auto_mini_refill`, `worker_auto_custom_refill` and
   `worker-esim-fulfillment`; stop voucher procurement only if Task 23 confirms an
   active process. Disable invocations of the old refund processor, DID lifecycle,
   paid verification/dialer and applicable cron/pg_net initiators using the exact
   approved controls. Existing in-flight invocations and supplier operations must
   drain/reconcile; stopping PM2 alone cannot retract a provider request. Retain
   read-only catalogue/messaging/evidence services only when compatibility is
   proven. Confirm no incompatible invocation or new claim can cross the boundary.
3. **Pin paused cron state.** Record each prior active state and username. Review
   money-affecting/reaper/expiry and maintenance jobs against current evidence.
   The recovery SQL can create an active cron job partway through the chain:
   the approved procedure must prevent it running against intermediate contracts,
   including between commits. Do not start the SQL sequence without a tested
   scheduler exclusion covering newly created jobs. Capture exact restore
   actions rather than re-enabling all jobs.
4. **Apply only the candidate dependency order.** The JSON manifest lists all
   26 files and SHA-256s, deliberately not chronological filename order. It starts
   with Task 3 containment, then financial containment/funding/submission/setup/
   pricing/retail/recovery, callback auth/PayPal, Tasks 9–13, Second Number base,
   Tasks 14–21, then Task 23 fleet monitoring. That final file is explicitly
   pending its own review/full-upgrade gate and is excluded from Task 22's older
   base order; its inclusion here is a dependency inventory, not release approval.
   Credential migration `20261016205533` is already recorded and
   excluded. Review history and definition guards before each file, record the
   actual applied version/name/digest through the approved forward-migration
   mechanism, and halt at the first error. These files own their transaction
   boundaries; do not wrap/reorder them or bypass their guards. No remaining
   pending/archive/recovered file is implicitly approved.
5. **Replace Edge consumers while initiation stays closed.** Deploy each approved
   selected slug with its pinned imports/shared sources and resolved gateway
   mode. Replace create/capture/PayPal webhook together; liveness/callbacks and
   make-call/Telnyx/media handlers together; refund with the funding SQL;
   manage-dids/lifecycle with the DID contracts; purge/email with Task 16.
   `send-admin-email` intentionally replaces captured v2. Keep account purge/email
   automation paused until its dependency checks pass; do not test on real users.
   The fleet `health` replacement must accompany its new service-only health SQL;
   do not expose privileged diagnostics through the public endpoint.
   `recovery-service`/Firsty and unrelated live-only functions are excluded.
6. **Copy the authoritative workers directly.** Follow
   [`.agents/AGENTS.md`](../../.agents/AGENTS.md): local `node --check`, direct
   SSH/SCP to the VM, remote syntax/hash verification, then only the explicitly
   approved PM2 starts/restarts. Use the manifest's copy set (three refill workers,
   supplier reconciler/PM2 definition, resolver/liveness/approval/provider modules,
   all instrumented fleet entrypoints and `worker_health.js`/`worker-fleet.json`).
   The current workers import the fleet module, so an earlier worker-only copy
   set is incomplete. Pin package/lock and PM2 inputs too; recovered dependency
   sources still require the reviewed clean-install/runtime check.
   Preserve the VM environment and actual CWD; never use a VM Git pull. Verify all
   copied dependency hashes before starting any process. The new PM2 process is
   `supplier-reconciliation`; verify its RPCs/config first. It performs lookups and
   can settle money, so starting it is itself an authorized financial operation.
7. **Release compatible clients.** Verify signed artifacts against the frozen
   customer/admin sources and chosen distribution targets. The changed retail,
   schedule and self-verification APIs deliberately deny old clients. Confirm
   deployed web caches/service workers, mobile version policy and offline queue
   replay; no financial fallback to old raw-table writes is allowed. If compatible
   clients cannot reach test users, keep affected initiation disabled.
8. **Refresh the API and verify before resuming.** Through the approved operator
   channel issue `NOTIFY pgrst, 'reload schema';`, then wait for actual API metadata
   and probe success; notification delivery alone is insufficient. Verify exactly
   one UUID finalizer with its default line argument and retired update-status/
   yearly queue APIs. Keep active mutations limited to approved test accounts.
9. **Resume progressively.** Restore only reviewed cron active states, preserving
   actual `postgres` callers. Start the compatible reconciliation and then refill/
   fulfillment consumers under the approved exclusions. Observe bounded pilot
   operations and evidence below. Expand one feature/cohort at a time only within
   approved account/provider exposure; a completed migration is not activation.

## Deployed acceptance and observation

Capture deployed SQL/version/grant hashes, Edge versions/settings/bundle hashes,
remote file hashes **and loaded process start/version**, signed client digests,
API requests/results and timestamped runtime checks. A disk hash or PM2 “online”
alone does not prove that a loaded process uses that source or progresses queues.

| Scope | Required controlled evidence |
| --- | --- |
| Access | Anon/ordinary/foreign-owner denial, legitimate owner/admin access, service contracts and real postgres cron execution; privileged table/column/default grants checked through metadata, never production TRUNCATE tests |
| Setup/pricing | Actual one-argument `{p_order_id}` and named `{p_order_id,p_sim_line_id}` HTTP finalization on owned authorized test orders, foreign-line denial, one fee/refill capture, Standard/free fallback, quote=charge, wallet/external upgrade evidence, explicit zero promotion |
| Refill/scheduling | Instant plus mini/custom delivery and PIN preservation, one next occurrence, range dispatch amount, insufficient available funds, duplicate/retry adoption; ambiguous outcomes retain reservations |
| Refund/deposit | One canonical completed capture/ledger/lot across client/webhook retry; one payout/SQL settlement, polling/adoption and correct original-funding reversal, with no repeat payout on unknown state |
| Calls/verification | Authentic provider callbacks; caller/attempt ownership; funded duration/provider termination, no-answer/increment settlement, duplicate/out-of-order event handling, no repeat dial and retained unknown holds |
| DID | Off by default. Pilot purchase/renewal/release only after supplier-account/invoice proof, exact funded capture, provider absence verification and approved recurring exposure; suspension alone does not stop supplier bills |
| Maintenance/notifications | Catalog authorization and truthful queued/completed/failure evidence; observe scheduled notification stage/outbox progression and warnings; real deletion/email/delivery only if separately in test scope |
| Fleet/reconciliation | Every required process's fresh heartbeat and advancing queue, oldest claim/backlog age, stale leases, unknown supplier outcomes, retained holds, payout/billing/notification failures and bounded deduplicated alerts |

Use the manifest's **explicit read-only** catalog-check list after SQL deployment
and require zero violations. Observe at least two successive cycles of each
resumed processor and the next natural execution of each required cron. The
window, queue-age limits and permitted quarantine counts must be signed off from
Task 23 baselines before activation; no numeric service-level threshold is
invented here. For long-interval cron, remain in limited pilot until its natural
run or separately authorized bounded runtime proof is recorded. Provider crash/
timeout and concurrency faults belong in the isolated/sandbox gate; do not inject
destructive financial faults into production. Label mock, isolated SQL, real local
HTTP, provider sandbox and live smoke evidence separately.

## Stop and recovery

Stop new initiation immediately on an unauthorized acceptance, source/grant/cache
drift, quote/charge discrepancy, duplicate charge/purchase, unexplained wallet
delta, reservation binding/capture failure, lost callback evidence, missed fleet
heartbeat, escalating unknown outcomes, unverified duration/renewal obligation or
budget exhaustion. Preserve evidence, reservations and reconciliation markers;
keep authenticated callbacks and trusted reconciliation running only if compatible
and expressly within the incident scope. Notify the designated release owner.

Before financial SQL commits, restore only the captured compatible prior
consumers/config if safe. After any commit, retain restrictive gates and use a
reviewed **forward fix**. Do not restore old instant/refund/reaper/dialer binaries,
recreate removed overloads, remove consumption/submission records or release holds
to make the rollout look clean. A failed migration may roll back that file while
earlier files remain committed: record the last successful version and reassess
compatibility before continuing. Client rollback must preserve new API denials.

## Closure record

Start with the [52-finding register](audit-baseline-20261016.md) and append a
release evidence row per F01–F52/A01–A02: source fix/review, deployed SQL/Edge/worker/
client version, runtime/denial evidence, legacy disposition, timestamp/operator
and remaining disabled scope. Existing STALE or narrowly VERIFIED DEPLOYED
entries retain their stated limits. Task 25 preparation closes no additional
production finding. The manifest's closure fields are intentionally pending.

Keep DID broad acquisition, Firsty/recovery, unvalidated provider routes and any
feature missing its acceptance evidence disabled. Exact present flag state is
unverified; this runbook did not change a flag. Task 25 finishes operationally
only when the finding register and incident/reconciliation evidence satisfy the
executor's completion criteria. A blocked candidate, approval or local green
suite alone cannot establish rollout completion.

## Verification performed for this preparation

[Actual check output](coordinated-rollout-results-20261018.json) distinguishes
candidate integrity from release readiness. Reproduce the new checks with:

```sh
python3 -m unittest discover -s tools -p test_coordinated_rollout.py
node tools/financial-tests/rollout-preflight.mjs
python3 tools/check_coordinated_rollout.py --check
python3 tools/check_coordinated_rollout.py --gate
```

Six artifact-safety tests cover changed/missing files, symlink/path traversal,
duplicate/empty pins, wrong target and attempts to turn preparation into approval.
Four PGlite scenarios exercise the actual read-only SQL against the captured old
schema and the existing financial repair fixture: absent evidence tables, legacy
failed submissions with missing version columns, original-debit linkage with
missing/ambiguous/single candidates, and repaired funding/supplier evidence.
The production-shaped constraints remain intact. These are bounded isolated
checks through the existing financial migration subset, **not** a test of all
26 files together or of managed Supabase, fleet runtime, provider outcomes,
independent-session concurrency, signed clients or live grants.

No existing customer/admin/worker implementation was modified by Task 25.
Concurrent changes were preserved. The existing three-repository lock was not
rewritten by this task; its drift and any Task 22 manifest drift stay visible at
the release gate. No deployment, database/history write, cron/config change,
credential action, provider operation, email or account deletion occurred.
