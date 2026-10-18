# Supabase financial and security audit: assessment and remediation plan

Assessment date: 2026-10-16 (Asia/Muscat).

## Scope and conclusion

The supplied audit identifies real security and financial-integrity defects. Fixes are warranted. The unguarded maintenance RPC, competing SIM-finalization contracts, reservation bypasses, and customer access to wholesale data deserve priority. Some exploit descriptions are overstated, some examples are stale, and the October 4 upgrade-discount defect is a local regression that is not present in the inspected live functions.

Evidence: read-only inspection of current source in the customer app, admin-related SQL, and the authoritative `../backend-sync-wt` worker workspace; live function definitions, effective role privileges, default privileges, table schema/policies, migration history, cron configuration, and aggregate wallet checks in project `zwxswagokhgbuzrrbnhr`. No financial RPCs, provider actions, schema changes, or financial test fixtures were executed. Provider/runtime behavior and deployed worker/Edge Function parity were not tested. This review does not independently certify the audit's count of 351 functions or its unnamed list of 18 RPCs.

## Findings and corrections

| Audit section | Assessment | Priority |
| --- | --- | --- |
| 1.1 Finalizer overloads | Both `(uuid,uuid)` and `(uuid,text)` exist live with an optional second parameter. The text version is anonymously executable, lacks ownership checks and delivery verification, and references columns absent from live `scheduled_topups`. The current Premium client uses a one-argument call, making ambiguity relevant to an actual flow. | Immediate access containment and contract repair. |
| 1.2 Wallet accounting | Live direct debits ignore holds and funding lots; gift/refund/admin credit paths can leave lots inconsistent. Refund allocation ignores existing allocations against a lot. Safe expiry recovery is absent from inspected source and relevant cron configuration. | Critical financial-integrity repair before broad money use. |
| 1.3 Reaper grants | Live `reap_stuck_executions` allows anonymous/authenticated execution with no caller guard or parameter bounds. Its configured cron runs as `postgres`. | Immediate access containment. |
| 1.4 Pricing | Zero-fee fallback and quote/charge divergence are real. The October 4 unpaid Standard-upgrade credit exists locally, but its migration is absent from live history and the inspected live functions lack that credit logic. | Repair live pricing; block the pending regression. |
| 1.4 Privacy/access | Return-trip wholesale cost is exposed through both table access and the package RPC. Trip, entitlement and personalized pricing helpers lack sufficient caller/ownership boundaries. | High; include customer contracts and UI changes. |
| 1.4 General hygiene | Broad grants remain a problem, but fee-admin RPCs have `assert_admin()` and VoIP history filters by `auth.uid()`. Missing revocation alone does not establish unauthorized writes or history disclosure. | Review by effective behavior and privileges. |

### 1.1 Finalization details

Relevant source:

- `supabase/migrations/20260909010000_fix_standard_line_setup_and_sim_line_binding.sql:14`: authenticated UUID finalizer. The audit's filename for this migration differs from the actual local filename.
- `supabase/migrations/20260916060000_update_health_score_three_pillars.sql:96`: unsafe text finalizer; invalid schedule insertion begins at line 199.
- `lib/features/sim_lines/presentation/screens/sim_line_form_screen.dart:2028` and `:2084`: Standard named-line and Premium one-argument calls.
- `supabase/migrations/20260915150000_enrich_setup_refill_metadata_and_activity.sql:328`: the working capture helper still writes carrier-verification fields without proof; this is also present live.

An invalid schedule insertion rolls back earlier SQL captures and updates in that invocation. Therefore the broken text overload is not proof of a committed unauthorized debit. Its already-active return still occurs without authorization. Closing access before repairing SQL prevents the latent unsafe path from becoming usable.

The horizon queue call occurs after the failing insertion. It should be removed in favor of the existing next-occurrence scheduling model, but queue creation alone does not demonstrate prepaid/free refills: the current authoritative mini-refill worker reserves funds per execution.

### 1.2 Wallet details

Relevant source:

- `supabase/migrations/20260806010000_g6b_household_spend_enforcement.sql:262`: direct debit checks posted balance, without subtracting holds or consuming lots.
- `supabase/migrations/20260907100000_wallet_holds_lots_and_refunds.sql:777`: cash-refund lot allocation ignores existing active allocations.
- `supabase/migrations/20260801040000_f1_credit_wallet_refund_grant_lockdown.sql:77`: refund credit changes balance without lot restoration.
- `supabase/migrations/20260809020000_g10c_money_path_wiring.sql:641`: gift recipient balance credit.
- `supabase/migrations/20260811100000_h7b_user_ops.sql:268`: admin balance adjustment.

A direct debit can spend money already reserved for another operation. Later hold capture checks balance and can fail, so two successful SQL debits are not guaranteed. The reservation guarantee is nevertheless broken and settlement can fail after provider delivery.

Corrections to the supplied examples:

- `../backend-sync-wt/worker_instant_refill.js:241` now reserves funds and captures/releases holds. Its cited direct-debit example is stale.
- `supabase/functions/make-call/index.ts:535` releases a hold on dial-setup failure. The cited early-cancellation leak is stale.
- `redeem_referral_points` calls `credit_wallet_for_deposit`, creating a lot. The actual live defect is that this deposit function marks referral rewards as refundable PayPal deposits, with inappropriate provenance.
- Missing-lot credits fail reservation when usable unallocated lots are insufficient; failure is not inevitable on every next reservation. Unconsumed lots from old direct debits can mask discrepancies. Adding new lots to every legacy refund could double-count funding.
- Refund holds are not necessarily assigned an expiry, contrary to the audit's statement that every hold sets one.

The adjacent `supabase/functions/process-wallet-refund/index.ts:148` implementation deserves inclusion: provider payout and wallet/lot/ledger writes are separate; pending outcomes and partial completion need explicit recovery; item claiming must prevent competing processors from settling the same refund. This is source-confirmed; deployed parity was not checked.

Live aggregate snapshot: seven wallets; zero wallet-versus-active-lot balance mismatches, zero wallets with active holds above posted balance, zero currently overallocated lots, and one expired active hold. These checks neither establish historical correctness nor prove financial loss or exploitation. The expired hold requires state inspection, not automatic release.

### 1.3 Reaper impact

`supabase/migrations/20260915090000_remediation_carrier_flight_and_trigger_scope.sql:97` drops/recreates the function without restoring restrictive grants. Effective live privileges confirm exposure.

The selection at line 115 targets only executions in `processing` older than the supplied threshold. Calling with zero thresholds can prematurely fail qualifying work across users, but does not select all queued or pending executions. In-flight provider submissions still require reconciliation even when marked failed.

### 1.4 Pricing and access details

- Do not deploy `20261004120000_upgrade_standard_to_premium_pricing.sql` unchanged: its Standard-credit checks trust plan labels without paid/unexpired entitlement. It also replaces canonical fee calculation in the live quote with the legacy configurable formula.
- Live `plan_price_net` and `quote_premium_breakdown` already use different membership-fee sources and fee calculations. Their fallback values are $2.50 and $5 respectively; actual configured amounts were not evaluated. A shared calculation must define both quote and collection.
- The fee constants criticized as hardcoded are configurable fallbacks. Bypassing `resolve_app_fee` is the substantive regression.
- `20260915110001_fresh_refill_price_approval.sql:170` treats a valid zero fee as missing. The eSIM helper has the same pattern. Gateway charges need a deliberate payment-rail policy; wallet spending must not be charged a deposit gateway fee again.
- `20260914000000_return_trips_and_packages.sql:109` grants package access, and its package RPC at line 193 explicitly returns supplier cost. The Flutter package UI also displays a supplier-derived breakdown (`wizard_step_package_selection.dart:436`). Table revocation alone is insufficient.
- Calling-rate RPC output includes supplier cost, and `calling_repository.dart:95` falls back to selecting all rate columns. Provide sanitized customer projections and retain backend-only cost access.
- Active/history trip RPCs report catalogue retail as effective price. Planning should use the authoritative current quote; history should use the accepted/charged snapshot when available, with legacy unknown values handled honestly.
- Live trigger settings show two definer triggers without a configured search path: `trg_fn_notify_topup_result` and `trg_scheduled_topup_health_sync`. The audit incorrectly includes `trg_fn_prune_line_activity_log`, which has an empty search path. The live activity-log trigger has a configured path.
- The actual migration-owner default privileges explicitly grant new public functions to `anon` and `authenticated`, in addition to PostgreSQL's PUBLIC behavior. Revoking PUBLIC alone is insufficient.

## Ordered remediation

### A. Contain exposed privileged operations

Use a small forward migration to revoke PUBLIC, anon and authenticated access from the unsafe text finalizer and reaper. Preserve the verified `postgres` cron path and only other demonstrated trusted callers. Restrict internal entitlement/pricing helpers; give customer wrappers explicit authenticated ownership guards and minimal grants. Keep admin checks. Fix the two live trigger search paths with qualified object references.

Correct default function grants for the actual migration owners, with a reviewed allowlist for public/authenticated APIs. Create/replace/drop functions and set intended privileges in the same transaction. Do not globally revoke customer access without mapping callers.

Acceptance: effective privilege checks for anon, ordinary authenticated, admin, service and cron identities; rejected cross-user access; legitimate customer/admin/cron behavior preserved. Avoid recognizing an original service caller via `current_user` inside a definer function, where it identifies the owner.

### B. Repair one compatible SIM-finalization contract

Retain `(p_order_id uuid, p_sim_line_id uuid DEFAULT NULL)` for existing clients. Trace dependencies, retire the unsafe text overload, then refresh the API schema cache. Check authorization before idempotent returns; validate order/line ownership, allowed states and authoritative Premium delivery success. Capture holds, record payment and activate schedules atomically and once. Correct fabricated verification in the actual capture helper. Use the existing next-occurrence scheduler and verified table columns.

If backend finalization is required, give it an explicit trusted path; a service JWT may have no user UID. Never interpret null UID as authorization.

Acceptance: actual one-argument/named-line API calls; anon/foreign-user denial, including active orders; Standard activation without fabricated verification; Premium pending/failure/success; concurrent retries produce one charge/payment/schedule.

### C. Unify wallet mutation and funding provenance

Retain a coherent model: posted balance, funding lots as provenance, ledger as auditable history, and holds as reservations. Every mutation must update the relevant objects atomically under consistent locks.

Route immediate spending and hold settlement through shared primitives. Immediate spending must respect existing reservations and consume lots. Preserve household caps, gifts' existing eligibility rules, and idempotency. Give deposits, gifts, referrals and admin credits explicit origins/refundability. Restore consumed funding on reversal according to the original debit; do not label internal credits as refundable PayPal deposits.

Share one allocator between reservations, refund quotes and refund requests. It must subtract active per-lot allocations and either allocate the entire request or roll back. Move refund settlement into an idempotent SQL transaction after an atomic claim and authoritative provider-result handling. Keep pending/unknown outcomes recoverable with stable provider idempotency keys.

Reconcile historical transactions and provider outcomes before any adjustment/backfill. Do not silently change customer balances or create lots merely to make totals match.

Acceptance: a fully held balance cannot fund unrelated spending; gifts/refunds/admin/referral flows reconcile; reserved lots cannot be reused; duplicate/concurrent money requests settle once; partial/pending/timeout refunds remain recoverable; quote, allocation, balance and ledger agree.

### D. Recover holds according to operation state

Bound reaper parameters and retain locking/in-flight protections. Release safe terminal pre-submission failures atomically with execution/order state. Introduce idempotent expiry recovery linked to owner state. An expired timestamp alone must never release funds for ambiguous provider purchases, pending payouts or live calls. Reconcile/escalate those cases. Inspect the existing expired live hold before deciding its disposition.

Acceptance: safe failures release; retry retains correct reservation; provider-in-flight/unknown and live-call cases remain protected; recovery is safe under repeat and concurrent execution.

### E. Unify paid entitlements, pricing and customer contracts

Create one paid-entitlement resolver, separate from customer-created setup draft labels. Verify ownership, validity and settled payment evidence for wallet and external payment rails. Requiring only `plan_payments` would reject valid wallet-paid lines, because the current wallet-payment function can record its evidence in wallet transactions instead. Notification entitlement alone is not billing proof.

Make quotes, setup and collection use one canonical calculation. Distinguish no published fee rule from a published zero fee. Supersede the unsafe pending upgrade migration before release; account for all environments' migration histories so fresh replay and upgrades converge. Preserve existing valid paid-upgrade behavior and intentional promotion policy.

Replace customer-facing return-trip and calling projections with retail-only contracts, update the corresponding Flutter models/widgets/fallback queries, and retain backend wholesale access. Enforce user and SIM-line ownership on trip RPCs and trip writes. Persist accepted trip prices for history.

Acceptance: legitimate wallet/external paid upgrades; forged/expired drafts denied benefits; zero-fee promotions preserved; quote/charge parity; gateway policy without duplicate fees; anonymous/foreign-user denial; no wholesale data through direct table access, RPC output or fallback client reads.

## Verification and rollout gates

Extend existing `wallet_accounting_invariants_tests.sql`, `f0_grant_matrix_tests.sql`, pricing and reaper suites rather than duplicating their coverage. Add actual role/ownership/API resolution cases, mixed-origin funding and concurrency tests. Use isolated fixtures/transactions for financial tests; provider tests must be explicitly scoped and controlled. Read-only production catalog checks are useful but do not substitute for behavior and concurrency tests.

Prepare separate reviewable changes for containment, finalization, wallet/recovery, and pricing/privacy. Run security advisors and effective catalog checks after each relevant deployment. Verify fresh migration replay and upgrade from the current live shape, refresh API caches, and deploy matching Edge Functions/workers/client contract changes in a compatible order. Roll back application behavior via a compatible forward fix; do not rewrite already applied migrations.

Completion requires closed effective grants, passing behavior/concurrency tests, explained reconciliation results, successful cron/worker/customer smoke checks, and matching deployed definitions. No implementation or deployment is included in this assessment.

## Reference semantics

- [PostgreSQL CREATE FUNCTION](https://www.postgresql.org/docs/current/sql-createfunction.html): signatures, default-argument ambiguity, replacement privileges, definer search paths and default EXECUTE privileges.
- [Supabase database functions](https://supabase.com/docs/guides/database/functions): function privilege management and safe definer configuration.


## Local implementation follow-up (2026-10-16)

The authorized local remediation is recorded in [the implementation review](../reviews/supabase-financial-security-remediation-20261016.md), including migration order, verification results and outstanding live rollout/reconciliation gates. The assessment above remains the original inspected baseline; it does not imply these local fixes have been deployed.
