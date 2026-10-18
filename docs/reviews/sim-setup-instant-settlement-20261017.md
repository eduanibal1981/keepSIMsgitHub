# Task 9 — SIM setup and instant-refill settlement

Reviewed and implemented locally: 2026-10-17, Asia/Muscat. **REPAIRED LOCALLY; NOT DEPLOYED.** This completes the settlement package against the current pending pricing interface. Final setup/fallback pricing certification remains Task 18. No migration, worker deployment, VM restart, supplier purchase, payout or customer-balance repair was performed.

## Findings and evidence

| Finding | Current status | Evidence |
| --- | --- | --- |
| The original instant worker independently captured/updated delivery; existing October 16 source already replaced that with begin/settle RPCs. | REPAIRED LOCALLY; deployment UNVERIFIED | Authoritative `../backend-sync-wt/worker_instant_refill.js`, preserved and completed here. Historical `.zcode` copies were not edited. |
| Pending begin/settle checked owner and amount but did not fully bind wallet, USD currency, operation/reference, owned line, allocations or repeated provider identity. Settlement could proceed without the committed submission marker. | REPAIRED LOCALLY | New forward migration `20261016235338_sim_setup_instant_settlement.sql`; actual-RPC reservation, settlement and negative tests. |
| A preflight failure could release a hold using a stale execution snapshot and subsequently overwrite delivered/in-flight work as failed. | REPAIRED LOCALLY | New service-only `fail_instant_refill_before_submission`; worker boundary tests and native submission/fallback race. |
| Compatible finalization needed a settled initial-refill receipt; dispatch could rebind an order to another owned phone/line before its retry return. Release/fallback/cancellation needed the same serialization boundary. | REPAIRED LOCALLY | Real dispatch, capture, finalizer, release, fallback and cancellation definitions in the forward migration. Owner/line checks precede completed/failed returns. |
| Two finalizer overloads coexist remotely; the obsolete text overload is still executable by anonymous users. New instant-boundary RPCs are absent remotely. | OPEN IN DEPLOYED CATALOG | Read-only live catalog evidence in `sim-setup-instant-live-20261017.json`. The only migration at or after `20261016010000` was credential migration `20261016205533`; no Task 9 repair was deployed. |
| Final PostgREST one-argument/named-line resolution, real trigger chains, supplier behavior and VM source parity. | UNVERIFIED | SQL/catalog and isolated worker tests do not establish HTTP/runtime parity. Required release checks below. |

Read-only dependency inspection found no normal catalog dependencies on the obsolete text finalizer. Both the earlier compatible repair and this completion use restrictive drops; this migration explicitly uses `DROP FUNCTION IF EXISTS ... RESTRICT`, never CASCADE. Unexpected dependencies must stop release for review.

## Contract changes

- `begin_refill_submission` locks the associated setup order, execution, wallet and hold in that order. It requires the actual linked active, unexpired, version-1 funded reservation, matching payer/wallet/USD amount, operation/reference and owned line. Setup reservations must match the Premium order and annual fee hold. A hold cannot fund multiple executions. The marker must commit before the supplier call.
- `settle_instant_refill_execution` revalidates the reservation after delivery, requires the persisted submission marker, captures once, preserves PIN/serial/redemption details and records authoritative execution/provider metadata. Repeated success must use the same provider identity and captured receipt. Failed settlement rolls back; uncertain work keeps its hold. No non-wallet instant-payment path is silently accepted.
- The worker retains submitted or uncertain work for reconciliation, including timeouts at begin/settle. Before-submission failures use the locked database RPC rather than direct release/status writes. Already submitted snapshots cannot purchase again. A caller-generated external reference is no longer substituted for a missing supplier transaction identity.
- Premium finalization requires the delivered execution's captured ledger receipt. The fee capture, plan receipt, supported notify/refill_mini schedules, activation and order state commit together. Reusing the captured initial-refill hold does not charge it again. Standard finalization pauses non-notify refill schedules.
- The single `finalize_sim_setup_order(p_order_id uuid, p_sim_line_id uuid DEFAULT NULL)` signature supports both existing customer call shapes without client changes. Existing ownership, exact phone and line binding checks precede active/failed/cancelled returns. The admin app has no matching finalizer client to change.
- Safe release, fallback and cancellation take the same setup/execution/wallet locks and preserve captured, submitted or legacy unknown reservations. Standard fallback still calls the existing pending `membership_fee_usd('standard')` interface and atomic capture helper. Insufficient funds remains retryable. Free fallback retains a supported notify schedule and disables other refill schedules.

Existing work in both repositories was preserved. No applied migration history was rewritten. The new migration filename was generated by the cached CLI in UTC; its date differs from the local review date.

## Verification actually run

| Check | Result |
| --- | --- |
| Default financial SQL/WASM suite | **41 passed, 0 failed**: 31 existing blocks plus 10 setup scenarios. |
| Native PostgreSQL financial/concurrency suite | **61 passed, 0 failed**, including concurrent Premium settlement/finalizers and submission versus fallback in independent sessions. Existing funding/refund integration cases also pass. |
| Focused setup runner | **10 passed, 0 failed**. Also included in the default/native suites above; these are not additional distinct checks. |
| Instant worker boundary tests | **8 passed, 0 failed**. Includes validation failure, ambiguous purchase/poll/begin/settlement, stale snapshot failure and already submitted work. |
| Production fixture fidelity and guards | Passed: 651 columns, 217 constraints, 76 unique indexes, 64 policies, 29 column ACLs, 42 functions and 11 selected real triggers; three constraint/RLS/generated-column safeguard blocks. |
| Changed JavaScript syntax; whitespace checks | Passed for worker and financial runners; both repositories' diff checks passed. |
| Live verification | Read-only signatures/defaults/grants, relevant migration versions and obsolete-overload dependencies inspected; no mutating API call or customer data used. |

The exact/surplus cases use the real quote → create order → reserve → dispatch → begin → settle → finalize APIs, with a synthetic published zero refill-fee promotion: $5 fee plus $1 refill, starting balances $6 and $20. Both finish with exactly one fee debit, one refill debit, one plan receipt and two schedules. The fee/receipt/schedule failure case injects an isolated schedule-write error and confirms rollback followed by one successful retry. Additional cases reject wrong owner/wallet/currency/amount/purpose/reference, missing/released/expired/legacy holds, settlement without submission, conflicting provider identity, foreign active/failed orders/lines, and anonymous finalization; they preserve ambiguous delivery and cover free/Standard fallback and insufficient-funds retry.

The fixture's external catalogue adapter now includes the real dispatch caller's `offer_value` field. No financial constraint was relaxed. Supplier catalogue/risk adapters, Auth JWT parsing, and omitted notification/health triggers remain the documented bounded fixture dependencies. These results do not certify final pricing, real provider delivery, actual PostgREST caching or complete production triggers. No Flutter code changed, so no unrelated Flutter suite/build was run.

Reproduce after installing `tools/financial-tests` dependencies:

```sh
npm test --prefix tools/financial-tests
npm run test:setup --prefix tools/financial-tests
npm run test:fixture --prefix tools/financial-tests
npm run test:concurrency --prefix tools/financial-tests
node --check ../backend-sync-wt/worker_instant_refill.js
node --test ../backend-sync-wt/test/instant_refill_boundary_test.js
```

This session used the existing isolated dependencies under `/tmp/keepsims-financial-tests/node_modules` via `PGLITE_MODULE_PATH` and `EMBEDDED_POSTGRES_MODULE_PATH`. Native PostgreSQL required local shared-memory access outside the sandbox; it bound only to localhost port 56549 and removed its disposable database afterward.

## Scoped release requirements — not executed

1. Complete the coordinated wallet/funding/refund release from Tasks 6–8; preserve ledger constraints and funding provenance. Apply the separate Task 3 containment against its intended captured-live contracts **before** the financial return-shape/overload replacements. Its migration explicitly targets the old catalog and must not be replayed afterward or treated as a filename-sorted bulk release.
2. Pause instant processing and setup submission during the coordinated cutover. Review the live catalog/dependencies and actual trigger chain again. Apply the eight October 16 financial migrations in their approved sequence, then this completion migration. Credential and other feature migrations are separate scopes; never run an unfiltered migration push/reset.
3. Copy the authoritative worker and required dependencies directly to the VM using the repository's SSH/SCP process; verify syntax, then restart only the scoped instant process after the database contract is available. Tested local worker SHA-256: `288334ad73c841dda5040efbd10e247eb4d3603d36a47784759778d4877100b1`. Compare the deployed hash before claiming runtime parity. Keep processing paused on mismatch/error.
4. Refresh PostgREST's schema cache (migration sends `NOTIFY pgrst, 'reload schema'`). In an authorized isolated/sandbox API scope, call the actual HTTP RPC with both bodies: `{"p_order_id":"<owned order UUID>"}` and `{"p_order_id":"<owned order UUID>","p_sim_line_id":"<matching owned line UUID>"}`. Assert there is no PGRST203; repeat foreign-order/line/anonymous denials and both balances through the deployed client/API. Catalog and direct SQL checks here are **not** a substitute for these HTTP checks.
5. Inspect existing submitted/version-0/legacy-success reservations individually. Do not automatically release, invent funding, recapture a legacy delivery, retry a supplier purchase or repair customer balances. Provider reconciliation and historical repair require their own scope (Task 11 and the coordinated rollout).
6. Task 18 must rerun the quote/setup/fallback cases against the final approved pricing policy and actual API/trigger integration before final pricing certification or unrestricted release.

Task 10's **local implementation prerequisites are satisfied**: the production-shaped wallet gates pass and the submission/settlement boundary is concrete and tested. Scheduled workers must explicitly extend this binding contract for their own reservation purpose and references; they must not bypass it or silently pass scheduled holds through the instant-only validator. Production release prerequisites, Task 11 recovery closure and Task 18 final pricing/API certification remain outstanding. No next task was started.
