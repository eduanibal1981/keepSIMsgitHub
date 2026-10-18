# Task 11 — supplier outcome reconciliation and safe hold recovery

Implemented and verified locally on **2026-10-18, Asia/Muscat**. **REPAIRED LOCALLY; NOT DEPLOYED.** This completes the local Task 11 work package. No production migration, supplier query/purchase, worker deployment/restart, customer balance repair, notification or payout was performed. Existing work in both application repositories and the authoritative backend repository was preserved. No subsequent executor task was started.

## Findings

| Finding | Classification and evidence |
| --- | --- |
| No durable background refill reconciliation queue/consumer existed. A committed submission could remain unresolved after a worker crash. | REPAIRED LOCALLY. The forward migration and new authoritative worker below cover instant, mini and custom API refills. |
| The pending reaper/expiry patch relied on absent/default-false submission flags and incompletely bound execution links. | REPAIRED LOCALLY. Existing executions retain recovery version 0; only trusted post-cutover inserts receive version 2. Recovery checks the full Task 9/10 reservation binding. |
| Dead-lettering an uncertain execution as an ordinary failure can remove the scheduler's processing blocker. | REPAIRED LOCALLY. Uncertain processing/routing work is quarantined in place. Submission also checks unresolved sibling operations on the same line while holding the payer wallet lock. |
| Pending financial migration had removed postgres execution from the reaper while the actual cron caller is postgres. | REPAIRED LOCALLY. Reaper/expiry entry points explicitly allow service and postgres, deny clients, and check trusted callers in their bodies. |
| Live reaper is the old public-search-path definition with anonymous/authenticated execution; the queue and expiry RPC are absent. | VERIFIED DEPLOYED old behavior by read-only MCP catalog/cron checks. Only credential migration `20261016205533` was present at/after the financial start version. No containment or financial rollout is claimed. |
| Real supplier account/environment response compatibility and deployed worker/API parity. | UNVERIFIED. Documentation and isolated responses validate the implementation contract, not live provider behavior. Existing Ding/Reloadly activation gates remain. |

## Implementation

Forward migration: `supabase/migrations/20261017190000_supplier_outcome_recovery.sql`. It follows the coordinated October 16 financial repairs, Task 9 setup/instant completion and Task 10 scheduled worker contracts; it is not a standalone release.

- The existing `begin_refill_submission` and `begin_scheduled_refill_submission` RPCs record `refill_supplier_submissions` **in the same transaction** as the in-flight markers. Each record binds execution, actual hold, payer, owned line, currency and supplier route to the exact existing worker reference: `dt_`, `z_`, `rl_` or `d_` plus execution UUID. Unique execution/reference and provider-transaction constraints prevent duplicate adoption. Repeated begin calls cannot authorize another purchase.
- Existing executions get version 0, without backfilling a story about whether they were submitted. Trusted server inserts after cutover get version 2. An invoker trigger prevents direct customers from manufacturing that version or hiding work with a recovery marker. Legacy rows cannot use begin/prepare/pre-submission-stop/setup-release paths as if newly proven safe. Do not bulk promote legacy versions.
- Service-only claim/completion RPCs use bounded batches, expiring tokens, `SKIP LOCKED`, backoff and a twelve-attempt budget, including repeated processor crashes. Completion locks setup → execution → wallet → hold → reconciliation record, validates the persisted binding, and uses the existing atomic settlement contracts. No database lock spans supplier network I/O. Missing, expired and stale leases cannot settle.
- Confirmed success captures exactly once and persists supplied PIN/serial/redemption details. For initial setup it also finalizes the plan fee, receipt and schedules without a customer reopening the app. Confirmed terminal failure releases the matching refill and setup reservations once. Failure conflicting with an already delivered/captured operation, changed bindings, reused transaction identities or settlement errors retain financial state and create an operator item. Completion retries cannot change the terminal supplier identity.
- Missing records, 404s, timeouts, malformed/duplicate/mismatched responses and unrecognized/reversed/refunded states do not prove failure. They remain reserved and visible. After the retry budget, or on a contract/configuration error, a deduplicated operator alert contains only execution/hold correlation IDs. Inspect the privileged queue and corresponding supplier account/reference; any legacy resolution or retry rearming needs a separately audited operator decision. This implementation never resubmits a purchase.
- The reaper processes at most 100 candidates; expiry recovery accepts 1–1000. Only a fully bound, versioned, proven pre-submission terminal refill may release automatically. Exhausted safe attempts release; ambiguous work stays quarantined and cannot return to pending. Calls, pending refunds, unsupported operations and legacy holds stay reserved. Stale payout items move to reconciliation, without paying them again. Previously flagged holds do not monopolize the expiry sweep or duplicate alerts.

Authoritative backend additions are in `../backend-sync-wt`:

- `supplier_reconciliation.js`: isolated read-only lookup/normalization and batch orchestration; imports no purchase adapters.
- `worker_supplier_reconciliation.js`: bounded background polling with request/database timeouts and graceful stop handling; batches of ten, once per minute, with a ten-minute initial grace/lease.
- `supplier_reconciliation.pm2.config.cjs`: one restartable process, prepared for the authorized coordinated rollout.
- `test/supplier_reconciliation_test.js`: 26 supplier/worker boundary tests.

The consumer queries the persisted reference using the official [DT One external-ID lookup](https://developers.dtone.com/reference/gettransactions), [Zendit topup transaction lookup](https://developers.zendit.io/api/), [Reloadly transaction reports](https://docs.reloadly.com/airtime/Commissions?lang=java), and [Ding ListTransferRecords query](https://www.postman.com/dingconnect/dingconnect-public-workspace/request/tgvbtaz/listtransferrecords). Ding's documented query uses POST, but it creates no transfer. OAuth token issuance for Reloadly also creates no order. Exact references and returned transaction identities are checked; Zendit's partner-supplied transaction ID is its documented identity. No external reference substitutes for an absent supplier ID on the other providers. See [Ding response fields/states](https://www.dingconnect.com/Api/Description) and [DT One terminal states](https://developers.dtone.com/reference/transactions-1).

Customer/admin Dart code did not need changing. Operator evidence uses the existing system-alert channel and a service-only queue; customer table/API reads receive no new supplier or financial data.

## Verification

[Machine-readable evidence, source hashes and read-only live facts](supplier-outcome-recovery-results-20261018.json).

| Check | Actual result |
| --- | --- |
| Production-shaped financial SQL/WASM suite | **78 passed, 0 failed** |
| Native PostgreSQL with independent sessions | **102 passed, 0 failed** |
| Real isolated PostgREST 16.4 HTTP scenarios | **10 passed, 0 failed** |
| Authoritative worker/resolver/provider regression selection | **150 passed, 0 failed**, including 26 new recovery tests |
| Focused scheduled migration/dependency suite | **22 passed, 0 failed** |
| JavaScript syntax and both repositories' whitespace checks | Passed |
| Migration-source hashes | **253 matched, including 240 archived sources; one pre-existing retained-file mismatch** |

Counts overlap. Tests include the before/after submission crash boundaries, delivered-but-unsettled recovery, PIN persistence, setup completion/failure without an app reopen, duplicate/concurrent claims and completion, stale/missing leases, binding/currency/price failures, negative client roles, forged provenance, conflicting failure after capture, safe expiry versus delivery races, active calls, genuinely submitted stale payouts, legacy false flags, retry exhaustion and unresolved same-line submissions. Old fixtures now use supported synthetic supplier names and correctly bound execution IDs/types; production ledger types and constraints were not relaxed. Catalog fidelity remains 651 columns, 217 constraints, 76 unique indexes, 64 policies, 29 column ACLs, 44 captured functions and 11 selected triggers before the forward migrations.

The HTTP runner now scopes the optional loader path to PostgREST and fails visibly on startup timeout or abnormal version exits. An initial failed test left a disposable local PostgreSQL listener; its recorded test directory/PID was identified and stopped. The successful run shut down its local servers and removed its disposable database. Native shared-memory/network permissions were used only for these local tests.

The known hash mismatch is `20261016020000_wallet_funding_integrity.sql`, already recorded by Task 10. This task changed neither that migration nor its manifest. Do not rewrite either simply to make the verifier green. Provider-account queries, full scheduler/notification/health chains, deployed API cache behavior and real delivery remain separate release evidence.

## Reproduction and scoped rollout gates

Run `npm test --prefix tools/financial-tests`, `npm run test:concurrency --prefix tools/financial-tests`, and `npm run test:scheduled --prefix tools/financial-tests` using the existing pinned dependencies. Cache overrides `PGLITE_MODULE_PATH` and `EMBEDDED_POSTGRES_MODULE_PATH` remain supported. Run the authoritative worker selection from Task 10 with `test/supplier_reconciliation_test.js` added.

For HTTP checks, provide the already verified PostgREST executable through `POSTGREST_BINARY`. On macOS set `POSTGREST_LIBRARY_PATH` to the embedded PostgreSQL `native/lib` directory, then run `node tools/financial-tests/scheduled-http.mjs`. This applies the loader path only to PostgREST. All test databases bind localhost and use synthetic credentials; no production/provider credentials are read.

Before release:

1. Resolve the retained-source manifest mismatch through the release review. Preserve Tasks 3 and 6–10 ordering and Task 18's deferred pricing gate. Do not run an unfiltered migration push/reset.
2. Pause instant, mini and custom processing. Inspect existing version-0 executions/holds and old submitted/dead-lettered rows. Reconcile them individually under the approved operational process; do not invent funding, repair balances, release expiry alone, or retry a supplier order. The new queue intentionally contains no fabricated legacy submissions.
3. Apply the reviewed financial dependencies, Task 9, Task 10, then this migration. Keep the existing `recover-expired-wallet-holds` and `reap-stuck-executions` schedules; verify postgres execution on both. Reload the API cache and exercise the exact named claim/completion payloads and client denials against the deployed API.
4. Deploy compatible instant/mini/custom workers **and the three new runtime/configuration files** directly from the authoritative repository using the SSH/SCP procedure in `.agents/AGENTS.md`. Verify source hashes/syntax and start the prepared supplier-reconciliation PM2 process only after its RPCs exist. Do not resume old worker binaries. This task did not start or restart a VM process.
5. Verify that the reconciler's supplier credentials/base URLs/account and environment match the submitting workers. Use an explicitly scoped test account/provider budget to validate controlled actual responses, stable identities, completion, failure and pending recovery before financial activation. Do not enable unverified supplier routing from this change alone.
6. Inspect queue age, operator items and unresolved reservations before resuming money processing. Preserve queue/markers on rollback; pause incompatible consumers and use a reviewed forward fix. Never revert to a reaper that releases uncertainty. Full fleet monitoring remains Task 23; coordinated operational closure remains Task 25.
