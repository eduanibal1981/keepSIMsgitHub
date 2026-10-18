# Task 10 — scheduled-refill holds and worker contracts

Implemented and validated locally on 2026-10-17, Asia/Muscat. **REPAIRED LOCALLY; NOT DEPLOYED.** Scope is Task 10 of the audit executor plan. No migration was applied remotely, worker deployed/restarted, supplier purchased, customer balance repaired, or next task started. Existing staged work in the customer app and instant worker was preserved; the admin app was inspected without edits.

## Findings and current status

| Finding | Status | Evidence |
| --- | --- | --- |
| Scheduled workers checked only hold status/amount and could replace/release a hold without binding its payer, wallet, currency or execution. | REPAIRED LOCALLY; old behavior VERIFIED DEPLOYED | The original authoritative mini/custom hashes exactly match the read-only VM hashes. Both repaired workers now call the atomic prepare/begin/settle contracts below. |
| Live `settle_successful_execution` permits success without a hold and returns early for an already-successful execution without checking financial/provider identity. | REPAIRED LOCALLY; old function VERIFIED DEPLOYED | Actual live function source and ACLs are recorded in [read-only evidence](scheduled-refill-live-20261017.json). The new forward replacement requires a funded reservation and committed submission, including on retries. |
| Split marker/status/release writes allow stale snapshots or lost responses to contradict financial state. | REPAIRED LOCALLY | Execution → wallet → hold serialization; actual SQL rollback/race tests and executable worker boundary tests. Lost submission/settlement/stop responses retain safety. |
| Two `update_execution_status` overloads remain live. Current local clients/Edge/authoritative workers have no production caller, but the deployed legacy instant worker calls it at line 463. | REPAIRED LOCALLY; deployment compatibility remains OPEN | Both overloads are captured in the production-shaped fixture and retired with RESTRICT. **Replace/pause the deployed instant worker in the coordinated release before retiring them.** There were no normal live catalog dependencies; runtime callers are a separate check. |
| The audit's undefined DTOne `userId`, range canonicalization and service/delivery intent findings are already repaired in authoritative source. | STALE for current source | Existing range-bound/value, retired-SKU, bundle exclusion, replacement and supplier-intent tests were rerun. No obsolete worker calls or pricing rules were restored. |
| Custom worker passed Zendit polling credentials as `apiKey` rather than the adapter's `apiSecret`. | REPAIRED LOCALLY | Corrected locally; both worker variants have executable coverage for the adapter argument. |
| Exact deployed PostgREST/cache behavior, real provider delivery and automatic reconciliation of unknown outcomes. | UNVERIFIED / Task 11 remains OPEN | Local HTTP verification is real PostgREST, but it is a separate environment. No production mutation or supplier test was performed. |

## Changes and trust boundary

The CLI-generated forward migration is `supabase/migrations/20261017164417_scheduled_refill_worker_contracts.sql`. It follows the pending wallet repairs and Task 9 completion; it is not a standalone production release or permission for a bulk migration push.

- `prepare_scheduled_refill(p_execution_id,p_route)` atomically persists the trusted worker's fresh supplier route, reserves funds and links the hold. It checks the original authorization ceiling, canonical `resolve_app_fee` result, actual payer/owned line, wallet, USD currency, exact amount, reservation purpose/reference, funding allocations, expiry and recovery version. An invalid existing hold causes rejection; it is never silently adopted, released or replaced.
- The production fee trigger runs on INSERT only. Repricing explicitly calls its canonical fee interface rather than assuming an UPDATE will recalculate fees. A route/fee disagreement fails before purchase. Final pricing policy certification remains Task 18.
- This path supports API refills funded by `wallet_due`. External-payment, unproven `legacy_prepaid`, non-USD and offline messaging paths fail closed. There is no implicit hold-free prepaid success. Supporting another payment rail requires its explicit receipt/settlement contract.
- `begin_scheduled_refill_submission(p_execution_id,p_hold_id,p_route)` revalidates the reservation and prepared route under the execution/wallet/hold locks. It commits both in-flight markers and a route/payer/line/hold/currency snapshot before purchase. Concurrent or stale starts cannot authorize another supplier call.
- `settle_successful_execution` retains its existing seven-argument signature and optional defaults. It revalidates the actual reservation and persisted submission snapshot, requires a confirmed supplier transaction identity, captures once, validates the matching ledger receipt, and persists PIN/serial/redemption details atomically. Caller metadata cannot overwrite authoritative execution/provider keys. A retry must match the original transaction and any supplied PIN details. Omitting the hold argument uses the stored link and still validates it.
- Expiry after submission does not imply non-delivery: a confirmed successful delivery can settle an expired, still-active submitted reservation. Unknown outcomes remain reserved for Task 11; no timer-based release or new supplier submission was added.
- `stop_scheduled_refill_before_submission` checks the current locked execution before failure, awaiting-funds or approval transitions. Only a valid, version-1, never-submitted active hold is released. A stale failure cannot downgrade success or release in-flight money. Safely released attempts clear the link; a later approved attempt receives a fresh bound reservation identity while duplicate preparation adopts one active hold.
- Mini/custom workers use those RPCs instead of independent reservation/link/marker/release/status writes. Entitlement lookup failure stops processing. The resolved cost is also copied into the in-memory execution used by supplier adapters. PIN notification follows successful persistence. An actual provider ID is required; the caller's external reference cannot stand in for missing provider evidence. Ambiguous or lost responses create a non-sensitive operator correlation alert without rewriting a possibly successful execution.
- Both obsolete status overloads are dropped with RESTRICT. Grants for the worker APIs are service-only; entry functions have in-body service-role checks and empty search paths. Unexpected dependencies roll back the whole migration.

Authoritative worker changes are in `../backend-sync-wt`, not historical `.zcode` snapshots. The old Phase 1 linkage assertion was updated for the atomic database boundary, backed by real SQL/HTTP linkage tests. Two existing source tests now follow and verify the archive manifest without restoring SQL.

## Verification actually run

Machine-readable results: [test results](scheduled-refill-contract-results-20261017.json).

| Check | Result |
| --- | --- |
| Default financial SQL/WASM suite | **62 passed, 0 failed**; includes 21 scheduled scenarios and the existing 41 financial/setup scenarios. |
| Native PostgreSQL suite | **84 passed, 0 failed**; includes duplicate preparation/submission/settlement and submission versus preflight-stop races in independent service-role sessions. Existing wallet/refund/setup races also pass. |
| Focused scheduled suite | **22 passed, 0 failed**; the 21 scheduled scenarios plus an actual legacy-function dependency that must stop and roll back the complete forward migration. |
| Real isolated HTTP RPC suite | **8 passed, 0 failed**, using **PostgREST 16.4** and native PostgreSQL on localhost. Tests actual named worker payloads, omitted optional arguments, anon/authenticated denial, missing/wrong-currency holds, concurrent settlement, persisted PIN data and retired overloads. No PGRST203 occurred. |
| Authoritative worker/resolver suite | **124 passed, 0 failed**: 42 new scheduled worker scenarios, 8 existing instant worker boundaries and 74 existing financial/routing/provider regressions. |
| Production fixture fidelity | Passed: **651 columns, 217 constraints, 76 unique indexes, 64 policies, 29 column ACLs, 44 actual functions and 11 selected real triggers**, plus 3 constraint/RLS/generated-column safeguard blocks. The two actual live status overloads were added to the capture query and fixture; no constraint or ledger type was relaxed. |
| Syntax and whitespace | All changed JavaScript syntax checks and both repositories' diff checks passed. |
| Migration source manifest | **240 archived sources verified. Full verifier fails on one pre-existing retained-file hash:** `20261016020000_wallet_funding_integrity.sql`. Its content matches the existing Git index; Task 10 did not edit it. Do not rewrite the manifest or earlier repair merely to make this check green. Review/reconcile the expected pending-source hash in the release/source work. |

Counts overlap across suites; they are not an additive total. Cases cover wrong payer/wallet/currency/purpose/reference, insufficient/excess/released/expired/missing/legacy holds, reused allocations/hold links, unsupported funding, authorization/price disagreement, stale routes, submission-required settlement, identity-conflicting retries, atomic rollback and safe pre-submission recovery. Synthetic zero-fee rules test the existing canonical pricing interface without certifying Task 18's final policy.

The HTTP executable was downloaded from the official [PostgREST 16.4 release](https://github.com/PostgREST/postgrest/releases/tag/v16.4). The macOS ARM64 archive SHA-256 was verified against the release asset digest: `5720fbde4a19ade9fb189791615c84beb9f0e58201b1b6d17fe3b698faf60776`. It used the existing embedded PostgreSQL libpq; no system package was installed. The runner itself never downloads software and requires an explicit binary path. Local servers bound only to localhost and were stopped; disposable databases were removed.

These are production-shaped isolated tests with synthetic balances, provider identifiers and signing keys. Auth cryptography against Supabase, full notification/health/scheduling trigger chains, current provider responses and deployed source/cache behavior are separate evidence. No Dart code changed, so unrelated Flutter tests/builds were not run. The [PostgREST RPC documentation](https://docs.postgrest.org/en/stable/references/api/functions.html) describes named arguments/defaults and the separate schema-cache reload requirement.

## Reproduction

After installing the pinned dependencies in `tools/financial-tests`:

```sh
npm run test:scheduled --prefix tools/financial-tests
npm test --prefix tools/financial-tests
npm run test:fixture --prefix tools/financial-tests
npm run test:concurrency --prefix tools/financial-tests
POSTGREST_BINARY=/absolute/path/to/verified/postgrest npm run test:scheduled:http --prefix tools/financial-tests
node --test ../backend-sync-wt/test/scheduled_refill_boundary_test.js ../backend-sync-wt/test/instant_refill_boundary_test.js ../backend-sync-wt/test/phase1_settlement_and_holds_test.js ../backend-sync-wt/test/phase2_canonical_offers_and_pricing_test.js ../backend-sync-wt/test/phase4_safe_failover_and_replacement_test.js ../backend-sync-wt/test/fulfillment_test.js ../backend-sync-wt/test/wallet_reservation_fulfillment_test.js ../backend-sync-wt/test/resilience_f01_f18_repro_test.js ../backend-sync-wt/offer_validation.test.js
```

This session reused `/tmp/keepsims-financial-tests/node_modules` via the existing `PGLITE_MODULE_PATH` and `EMBEDDED_POSTGRES_MODULE_PATH` overrides. macOS may require `DYLD_LIBRARY_PATH` pointing at the existing embedded PostgreSQL `native/lib` directory for the official PostgREST binary. Native tests need local shared-memory/network permissions. The HTTP runner uses ports 56553/56554 by default; `FINANCIAL_TEST_PORT`/`FINANCIAL_HTTP_PORT` override them.

## Scoped release requirements — not executed

1. Retain the Tasks 6–9 coordinated financial release dependencies and Task 3 containment ordering. The live catalog check returned only credential migration `20261016205533` at or after the financial start version; the financial repairs and this task remain undeployed. Reconcile the pre-existing retained-source manifest mismatch before claiming a reproducible release. Do not run unfiltered push/reset or replay archived migrations.
2. Pause **instant, mini and custom** processing before the database cutover. The old VM instant worker calls the status API being retired; the old scheduled workers do not commit the new snapshot. Deploy Task 9's compatible instant worker and both Task 10 scheduled workers together with their database dependencies. Never resume the old binaries against this migration.
3. Review actual function grants, dependencies, price policy, trigger chains and outstanding reservations again. After the eight approved financial migrations and `20261016235338_sim_setup_instant_settlement.sql`, apply this narrowly reviewed forward migration. Other pending feature/credential/containment migrations have separate scopes and ordering. RESTRICT failures must stop release for review.
4. Copy reviewed workers directly from the authoritative repository to the VM using the SSH/SCP procedure in `.agents/AGENTS.md`, verify syntax and hashes, then restart only the scoped processes after the new RPCs are available. The tested hashes are below and in the read-only evidence JSON.
5. Reload PostgREST's schema cache (the migration sends NOTIFY), verify the deployed named/full/default worker HTTP request shapes and anon/authenticated denials under an explicitly scoped sandbox/test-account budget, and confirm actual ledger/PIN/schedule results. Local PostgREST 16.4 does not establish the deployed version or cache state.
6. Review existing version-0, submitted, legacy-success, externally funded, mismatched or price-disagreeing executions individually. Do not default the new snapshot onto old submissions, release uncertain holds, recapture legacy deliveries, invent funding, retry supplier purchases or repair balances. Task 11 must reconcile unknown outcomes; Task 18 must close final pricing; worker monitoring and full rollout remain their assigned tasks.

| Tested local component | SHA-256 |
| --- | --- |
| `worker_auto_mini_refill.js` | `896c8cb4416d7974201a82da03e432a6bb093be01304fffbab89a533470c794b` |
| `worker_auto_custom_refill.js` | `d0eaa3b582f16d773717dbd92bd815a39795c5d22a3ce9c920a382f613ff7804` |
| Existing Task 9 `worker_instant_refill.js` (preserved) | `288334ad73c841dda5040efbd10e247eb4d3603d36a47784759778d4877100b1` |
| Task 10 forward migration | `be9e5223d86b7d17803b8466b175f7797469f67552e9171722dd3f102ea76bee` |

**Task 11's local implementation prerequisites are satisfied.** Its unknown-outcome reconciliation/recovery work remains unimplemented in this task. Production activation prerequisites, including the coordinated release, deployed verification, source-manifest reconciliation and later pricing closure, remain outstanding. No next task was started.
