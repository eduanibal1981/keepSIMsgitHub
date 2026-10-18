# Financial and security remediation implementation review

Date: 2026-10-16 (Asia/Muscat). Status: **implemented locally; not deployed or certified against the live Supabase project**.

2026-10-17 correction: [Task 6 production-shaped tests](financial-production-contracts-20261017.md)
supersede this report's earlier permissive-fixture pass counts. The current gates
fail on excluded `refund_payout`/`verification_debit` types and eSIM/call reversal
provenance. The pending financial package is not ready to release; Tasks 7–8
must resolve these failures without weakening captured constraints.

The source findings in [the remediation plan](../implementation-plans/supabase-financial-security-remediation-20261016.md) were confirmed. Eight forward migrations, a replacement refund processor, matching customer contracts and isolated regression tooling implement the local repairs. The authoritative sibling `backend-sync-wt/worker_instant_refill.js` and its focused tests were also updated. Existing staged dashboard, calling and authentication work was preserved. The dashboard measurement artifact rewritten by the full test suite was restored to its original staged contents.

## Changes

| Area | Local implementation |
| --- | --- |
| Containment | Revoke the unsafe text finalizer and customer reaper access, restrict internal pricing/entitlement helpers, pin both trigger search paths, and remove global and schema default API EXECUTE grants for actual function owners. Existing API grants are not globally revoked. |
| Finalization | Retire the text overload with `DROP ... RESTRICT`; retain `(uuid,uuid DEFAULT NULL)`. Check owner and line binding before every return, require authoritative Premium delivery, settle holds/receipt/schedules atomically, preserve independent carrier verification, release proven pre-submission failures, and retain ambiguous submissions for reconciliation. |
| Funding | A completed-ledger-insert trigger books funding atomically, including immediate spending, hold and partial-call capture, gifts, referrals and signed admin adjustments. All spending respects active reservations and consumes unallocated lots. Receipt references are checked after locks; household and gift-cap checks are serialized. `wallet_transaction_funding` records consumption for reversals. |
| Refunds | Quotes/reservations share lot availability. Duplicate active requests adopt the same reservation. SQL claims prevent competing payout processors; settlement updates item, reservation, lot, wallet, request and ledger in one transaction. Pending/unknown outcomes remain reserved; known refund IDs are polled. A stale unknown submission is not automatically paid again. |
| Recovery | Bound the reaper; release exhausted pre-submission failures atomically while preserving retry/in-flight reservations. Add bounded, idempotent expiry recovery and cron registration. Expired ambiguous purchases, refunds and call budgets require reconciliation. Pre-migration reservations have recovery contract version 0 and cannot be automatically classified safe from false submission flags. |
| Instant worker | Persist the submission boundary before supplier requests; retain reservations on post-submission errors, pending responses and settlement failures. Commit delivery status, wallet capture and ledger through a validated atomic RPC. Unreserved supplier paths fail before submission. |
| Pricing | Require valid settled receipt evidence for paid tiers, including wallet ledger evidence and the explicit Premium grandfather registry. Bound Standard upgrade credit by settled payment. Quotes, collection, setup-order creation, reminder fallback and eSIM comparison use canonical calculations. Published zero fees are retained; drafts are not published prices. Wallet quotes omit gateway gross-up. Invalid gateway configuration is rejected. |
| Customer contracts | Strip wholesale fields from calling/package RPCs and customer models; restrict direct table/column access; use an explicit retail fallback SELECT. Check trip and SIM ownership on reads and writes. Snapshot server-derived accepted trip prices, reject a changed submitted quote, and retain unknown legacy history as null. |
| Checkout | Require authoritative asynchronous plan quotes, pass the line identity when quoting upgrades, and derive the displayed upgrade-credit flag from the server. Legacy synchronous estimates remain for advisory rendering; they cannot authorize checkout. |

Migration sequence:

1. `20261016010000_financial_rpc_containment.sql`
2. `20261016020000_wallet_funding_integrity.sql`
3. `20261016025000_instant_refill_submission_boundary.sql`
4. `20261016030000_compatible_sim_finalization.sql`
5. `20261016040000_canonical_paid_pricing.sql`
6. `20261016045000_canonical_esim_catalogue_prices.sql`
7. `20261016050000_retail_customer_contracts.sql`
8. `20261016060000_schedule_wallet_recovery.sql`

The wallet migration refuses to run when existing balance/lot totals, hold coverage or allocations disagree. It does not repair historical money records. Legacy reversals without recorded consumption fail with a reconciliation error instead of creating potentially duplicated lots. The unique provider-refund identity index also requires existing duplicate IDs to be resolved explicitly.

## Verification

| Check | Result |
| --- | --- |
| Isolated PostgreSQL behavior: wallet invariants and financial remediation suites | Passed, using the actual forward migrations. |
| Pre-October-4 and October-4-applied starting shapes | Passed in the isolated harness. This is targeted history convergence, not a full replay of the missing initial application schema. |
| Native PostgreSQL 18.4, independent concurrent sessions | Passed: duplicate holds, competing allocations/debits, duplicate refund requests, competing claims/settlement, and simultaneous finalizers. |
| Focused Flutter tests | 36 passed, including retail fallback queries and unknown historical prices. |
| Refund and refill backend tests | 15 passed. |
| Existing call-media tests plus refund/refill tests | 30 passed with a temporary TypeScript 5.9 transform adapter for Node 26; unadapted call-media tests require the removed Node `mode: transform` API. Production source was not changed for that runner issue. |
| Authoritative instant worker | Syntax check and 6 tests executing the actual worker with isolated provider/DB adapters passed. |
| TypeScript check of shared refund processor | Passed. |
| Flutter analysis of changed client files | No issues. |
| Full Flutter tests | 821 passed, 22 failed. Remaining failures are in existing legacy pricing/payment expectations, My Numbers layouts, biometric provider lifecycle, FX, scheduled-channel status and onboarding currency tests. They are not a clean release gate. |
| Full repository analysis | The full run reported 90 findings before final changed-file cleanup, including `docs/reviews/voip-quality-followup-repros_test.dart:34` returning a potentially null result. Final changed-file analysis is clean; the repository-wide release gate remains failing. |
| Diff whitespace check | Passed. |

Reproduction commands and fixture limitations are in [the financial test tooling](../../tools/financial-tests/README.md). Existing `wallet_accounting_invariants_tests.sql` and `f0_grant_matrix_tests.sql` were extended; the complete global grant matrix still requires the actual full database schema. The isolated fixture substitutes external infrastructure/risk/household checks and does not validate supplier behavior, the complete production trigger graph, cron execution or PostgREST HTTP schema resolution.

## Rollout gates

1. Run [the read-only preflight](../../supabase/verification/financial_remediation_preflight.sql) against the intended project, review actual owners/default ACLs and dependent functions, and compare the current worker/Edge source. Inspect the known expired hold and historical/provider outcomes privately. No live hold was inspected or released in this session.
2. Reconcile per-environment migration history first. **Do not run an unfiltered `supabase db push` that executes the pending unsafe October 4 migration against an active environment.** Apply the reviewed corrective definitions through the approved deployment workflow; resolve/stamp the superseded history only after verifying that environment's definitions. Already applied migration files were not rewritten.
3. Pause the instant worker and refund processing; drain/reconcile legacy submissions and purchases requiring reversal before resuming. Apply the wallet/submission migrations and replace `process-wallet-refund` and the authoritative instant worker before processing resumes. Follow the project’s direct SCP/SSH syntax-check/restart workflow when a deployment is authorized; there was no VM deployment here. The old refund handler directly mutates balances/lots and is incompatible with the new funding trigger. The old instant worker can release after an ambiguous supplier response and must not run against the new recovery workflow. Reconcile old in-progress refund items and unmatched legacy reversals explicitly; do not create funding merely to make totals agree.
4. Apply remaining migrations in sequence, deploy the matching client, refresh/check the API schema cache, and run actual one-argument and named-line finalization requests. Verify customer, admin, service and cron identities, normal setup/fallback, wallet-paid and external-paid upgrades, refund polling and worker capture/release behavior.
5. Verify the recovery cron and its registry entry, rerun security advisors and effective grant checks, and explain all reconciliation findings before enabling broad financial use. Fix the existing full-suite release failures separately.

Supabase tools were unavailable in this session. There were no live migrations, deployments, provider payouts/purchases, balance changes or historical backfills. The local tests do not close these rollout gates.

## Reference checks

Owner default grants were checked against [PostgreSQL ALTER DEFAULT PRIVILEGES](https://www.postgresql.org/docs/current/sql-alterdefaultprivileges.html). The refund processor requests `Prefer: return=representation` so amount/currency can be validated before atomic settlement, following [PayPal's refund endpoint contract](https://developer.paypal.com/api/payments/v2/captures-refund).
