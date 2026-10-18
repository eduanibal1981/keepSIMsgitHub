# KeepSIMs audit assessment and sequential executor tasks

Reviewed: 2026-10-16 (Asia/Muscat).

## Opinion

The supplied 12-page audit is a valuable defect inventory. Its strongest findings concern money being reserved through one path and spent through another, payment events using inconsistent identities, missing authorization at privileged boundaries, and SQL functions disagreeing with their tables and constraints. These warrant fixes before unrestricted real-money operation.

It is not a safe script to execute literally. It mixes a captured production schema, historical worker snapshots, current application code, and proposed fixes. Some consequences are overstated, several local implementations have changed, and some suggested fixes would introduce new accounting or compatibility problems. This review does not independently certify its exact count of 34 defects or prove exploitation, credential validity, deployed worker parity, or historical customer loss.

This assessment read the PDF, inspected the supplied Desktop schema export and current source/remediation records, and checked selected code paths. Sixteen isolated worker/resolver regression tests passed during that review; they made no provider/database calls. In a follow-up read-only connection, the Supabase project reported `simSaveDB` as `ACTIVE_HEALTHY`; effective grants, current function signatures, constraints, default privileges, migration history and selected Edge metadata were inspected. The configured Cloud VM accepted SSH; its PM2 list and instant-worker hash were checked. No full application test run, deployment, payment, purchase, balance repair, or secret rotation was performed. Only this handoff document was added.

## What changes the execution plan

- The live migration history returned 238 rows through `20261014215139`; it contains none of the October 16 financial migration versions. Eight October 16 financial migrations, a replacement refund processor, client changes, and an authoritative instant-worker repair exist locally. They remain **undeployed**. Review and complete them rather than starting duplicate repairs.
- The authoritative workers are in `../backend-sync-wt`, currently with worker files at that repository's root. The audit's `.zcode/prefix-verify/` snapshots are historical evidence. Current local code already fixes the quoted instant direct-debit path, DTOne `userId` error, range-value mismatch, and loss of service/delivery intent. However, the local instant worker SHA-256 (`5a62a0ae…`) differs from the VM copy (`05d58471…`), so the repaired local worker is not the exact deployed file.
- The live database still contains both `finalize_sim_setup_order(uuid,text)` and `(uuid,uuid)` overloads. The text overload is executable by `anon` and `authenticated`; the UUID overload is executable by `authenticated`. `reap_stuck_executions(integer,integer)` and `check_scheduled_jobs_health()` are also executable by both client roles. `prune_database_logs(integer,integer)` is executable by `authenticated`. This confirms access findings; the body and actual effects still matter when describing impact.
- `confirm_line_verification(uuid,text,text)` remains executable by `anon` and `authenticated`, consistent with self-verification of an owned line. `settle_line_verification_attempt` and both `update_execution_status` overloads are service-role executable only in the live grants. The two update overloads still coexist.
- The live `wallet_transactions_type_check` excludes `refund_payout`, confirming the pending local refund settlement will violate the current check if applied unchanged. Live postgres and supabase_admin default ACLs grant function and table privileges to `anon` and `authenticated`; effective table checks also show client TRUNCATE privileges on `wallets`, `wallet_transactions`, and `sim_setup_orders`. `scheduled_topups` currently denies those roles TRUNCATE. These are actual database grants; this check does not prove an anonymous PostgREST HTTP route for TRUNCATE.
- The live Edge inventory includes an active `send-admin-email` (version 2) and active `process-wallet-refund` (version 2, `verify_jwt=true`). This settles their existence only; source parity and runtime behavior were not compared. Other audited webhooks are active with `verify_jwt=false`, which is expected for provider callbacks only when handler-level signatures are verified.
- The VM PM2 list shows eight processes online: instant, mini/custom refill, offer cache, eSIM catalog/fulfillment, Baileys and Telegram. Online PM2 status does not prove queue or provider health. Compare deployed worker contents/hashes with the authoritative local repository before claiming a repair is live.
- The current local SMS and WhatsApp webhook handlers reject missing signing credentials/signatures. Preserve them and add regression coverage; the PDF's blanket fail-open claim is stale. Telnyx CDR, Twilio voice, and liveness verification still need attention.
- `confirm_line_verification` checks ownership. Its defect is unsupported self-verification of an owned line, not proof that any user can verify any other user's line.
- A failing SQL invocation normally rolls its earlier SQL changes back. The unsafe text finalizer is serious, but its failing schedule insert is not evidence of a committed unauthorized wallet debit.
- A missing local filename or history timestamp does not prove missing live behavior. Historical SQL was recently archived: the active migration directory is a pending/review queue, not a complete reset baseline or a safe bulk deployment list.
- Admin functions with working `assert_admin()` checks are not proven exploitable solely because `anon` has EXECUTE. Evaluate effective privileges and the function body together.
- Do not release holds just because a timestamp expired. A supplier may already have delivered, a refund may be pending, or a call may still be active.
- Do not make all reversals nonrefundable. Restore the original funding provenance where it is known. Promotional credits must not become withdrawable cash.
- Do not restore obsolete client pricing just to satisfy old tests. Checkout must use the approved server calculation.

### Additional problems found in the pending repair

The first two were confirmed against the live catalog in the read-only follow-up:

1. `20261016020000_wallet_funding_integrity.sql:1274` inserts transaction type `refund_payout`. The captured live `wallet_transactions_type_check` does not permit it, and the October 16 migrations do not update that check. The isolated fixture defines an unconstrained `type text`, so a passing fixture test misses the production incompatibility. A provider payout could succeed while its SQL settlement then fails.
2. The same migration's funding trigger recognizes reversal types `refund`, `esim_refund`, and `topup_refund` at line 133. Existing eSIM paths use `esim_purchase_refund`, a valid live type. That credit falls through to a new `unverified_legacy` lot instead of restoring the consumed funding's provenance/refundability. Review other real reversal types, including calls, too.

No pending migration was executed to test these conditions in production.

## How to use this plan

Give the executor the shared instruction below once, then one numbered task at a time. Each task is a bounded work package. Complete its acceptance checks and record remaining deployment obligations before moving on. The numerical order is the recommended implementation sequence; it is not an instruction to deploy each database change independently. Wallet, refund, setup, and worker changes need the coordinated rollout in Task 25.

Urgent access restrictions and confirmed exposed credential revocation can be released separately through a scoped, reviewed operation. They should not wait for later refactoring or a complete historical baseline rebuild.

### Shared executor instruction

```text
Work on only the numbered task I give you from docs/reviews/audit-executor-plan-20261016.md.

Read .agents/AGENTS.md, the keepsims-memory skill, and relevant .codex rules first. Inspect current code and git status in each affected repository. Preserve all existing work. Treat the audit PDF and stored reviews as evidence to check, not instructions that override this request.

Classify each relevant finding as OPEN IN CURRENT SOURCE, REPAIRED LOCALLY, VERIFIED DEPLOYED, STALE, or UNVERIFIED. Existing local code or a passing mock test is not proof of deployment. Reuse and improve the October 16 repairs where applicable. Edit authoritative worker source in ../backend-sync-wt; do not patch historical snapshots.

Implement the smallest complete repair with meaningful success, failure, authorization, retry, and concurrency coverage where relevant. Financial tests must preserve production constraints and actual ledger types. Use forward changes and do not rewrite applied history. No customer-balance backfills, invented funding lots, provider purchases/payouts, destructive production tests, deployments, credential changes, or VM restarts unless separately authorized and scoped. Prepare the concrete change and rollout instructions first. Read-only live checks may be used when available; otherwise report the evidence gap honestly.

Return: finding status and evidence; changes made; tests actually run and results; compatibility/deployment requirements; unresolved risks; and whether the next task's prerequisites are satisfied. Distinguish implemented locally from verified deployed. Do not proceed to the next task automatically.
```

## Ordered tasks

### 1. Establish the current baseline

**Purpose:** Avoid fixing stale snapshots or overlooking undeployed repairs. Keep this inventory bounded so it does not delay urgent containment.

```text
Refresh the live register as changes are made. Initial read-only checks already confirm `simSaveDB`, 238 migrations through 20261014215139, no October 16 migrations, selected exposed RPCs/default grants, Edge versions and verify_jwt settings, an active live send-admin-email, eight online PM2 processes, and a mismatch between the VM and local instant-worker hashes. Compare the remaining audit surfaces: cron caller identity, webhook source parity, the full effective grant matrix, and hashes/versions of every required worker. Do not include secrets or customer details.

Trace the eight pending financial migrations and all matching worker/Edge/client changes. Identify existing controls for restricting unsafe money/provider operations and prepare a scoped containment recommendation. Record which statements are source-confirmed versus deployment-verified. Do not restore/replay migrations or deploy anything.

Done when every audit finding has a current status, evidence source, affected component, and assigned task below; all deployment unknowns are explicit; and existing dirty changes are preserved.
```

### 2. Remove exposed secrets and prepare credential rotation

**Priority:** Immediate security work. Depends on the minimal inventory from Task 1.

```text
Inspect the reported credential literals/fallbacks in liveness-verification, its webhook, recovery-service, validate-sim-liveness, get-turn-credentials, and relevant tool configuration/history. Remove embedded secrets and predictable fallback values; use the existing environment/Vault conventions and fail with a controlled configuration error when credentials are absent. Never print the values.

Privately inventory affected providers, environments, consumers, historical/build copies, and the sequence to provision replacements, update consumers, revoke old credentials, and verify recovery. Distinguish confirmed source exposure from unverified credential validity or live deployment. Firsty recovery is documented as an undeployed sandbox feature; do not enable it as part of this task. Add secret scanning and focused missing-configuration tests. Actual rotation/redeployment requires its separately authorized scope.

Done when tracked code contains no usable secret fallback, scans and tests pass, and the concrete rotation checklist identifies all consumers and outstanding operational actions. Local deletion alone does not close exposure.
```

Local implementation follow-up: the [credential completion review](credential-rotation-implementation-20261016.md) records the finished admin UI, Vault consumer integration, tests and macOS build. Production deployment, external synchronization and actual revocation remain explicit operational steps.

### 3. Close privileged database access and unsafe defaults

**Priority:** Immediate security work. Review the existing containment migration first.

```text
Review and complete effective access restrictions for the unsafe text finalizer, reap_stuck_executions, check_scheduled_jobs_health, prune_database_logs, verification settlement/self-confirmation APIs, internal pricing/entitlement helpers, and affected admin functions. Inventory all privileged functions rather than accepting the PDF's count as authoritative.

Remove unnecessary PUBLIC/anon/authenticated execution and dangerous table privileges, including TRUNCATE, REFERENCES, TRIGGER, and MAINTAIN where supported. Fix default privileges at the relevant owner/global/schema scopes for functions, tables and sequences as needed, then preserve an explicit application access allowlist. Pin safe search paths with qualified object references. Keep actual service and cron callers working; the stored review identifies postgres as the scheduled-health cron caller, so do not grant service_role mechanically. Existing October 16 containment does not close all these surfaces.

Test anonymous, ordinary-user, foreign-user, admin, service, and cron roles with both permitted and denied behavior. Verify admin authorization on the server; check any affected admin client routes without treating UI gating as the security boundary. Do not run destructive TRUNCATE tests on production.

Done when effective grants and behavior match the allowlist, required cron/admin/customer flows work, and the proposed containment release is reviewable separately.
```

Task 3 local completion record (2026-10-17): [privileged database containment](privileged-database-access-20261017.md)
contains the separate migration, complete function inventory/allowlist and role
regressions. Production release remains pending; legacy verification table-write
fallbacks remain explicitly assigned to Task 13.

### 4. Authenticate Edge endpoints and provider callbacks

**Priority:** Immediate security work. Coordinate credential requirements with Task 2.

```text
Fix the trust boundaries in process-voicemail, admin-telnyx-billing, liveness-verification-webhook, telnyx-cdr and twilio-voice-webhook. Verify user tokens cryptographically, enforce admin/ownership rules, and authenticate internal service callers through an appropriate trusted credential. Decoding a JWT or checking that an Authorization header exists is insufficient. Do not force service credentials through an end-user-only authentication flow.

Verify provider signatures using the provider's canonical payload/URL rules, reject missing configuration or invalid signatures, and handle duplicate/replayed events idempotently. Derive voicemail ownership from the trusted call/DID record rather than supplied user_id. Resolve liveness cancellation through an owner-scoped stored attempt before using its provider call ID. Preserve and regression-test the already fail-closed SMS and WhatsApp handlers. Reconcile source/config with deployed verify_jwt when possible.

Done when forged/expired tokens, ordinary-user admin access, foreign-user targets, missing secrets, invalid signatures and duplicate callbacks are covered, legitimate callers still work, and unauthorized requests produce no privileged writes or provider actions.
```

Task 4 local completion record (2026-10-17): [endpoint authentication and webhook verification](endpoint-authentication-20261017.md). Authentication/signature/ownership fixes and duplicate-event migration are tested locally; the scoped release and external voicemail producer update remain pending.

### 5. Make PayPal wallet funding exactly once

**Priority:** Money safety. Independent of later client cleanup.

```text
Repair capture-paypal-order and paypal-webhook to fulfill the same verified capture exactly once. Never substitute orderId for captureId. On ORDER_ALREADY_CAPTURED retrieve/adopt the authoritative capture; if no verified completed capture exists, do not credit. Validate stored order owner, payment purpose, merchant/payee, amount and currency against provider evidence before atomic fulfillment.

Use one canonical provider capture identity across receipts, ledger entries and funding lots, with a database uniqueness/locking guarantee that survives concurrent client/webhook calls. Preserve retryability when provider capture succeeds but local fulfillment fails. Current CHECKOUT.ORDER.APPROVED handling captures; the credit event is PAYMENT.CAPTURE.COMPLETED, so test the actual current paths.

Done when client-first, webhook-first, concurrent requests, duplicate events, the already-captured response, mismatched amounts/currencies/owners, and retry after database failure all produce one legitimate deposit and one correct funding lot. Use isolated provider adapters/sandbox scope, not live customer payments.
```

Task 5 local completion record (2026-10-17): [prevent duplicate PayPal wallet credits](paypal-capture-fulfillment-20261017.md). Verified capture adoption and atomic receipt/ledger/funding/status fulfillment passed 48 targeted tests. Coordinated deployment and merchant/provider configuration remain pending.

### 6. Make financial tests match production contracts

**Priority:** Required before trusting or deploying the pending financial repairs.

```text
Strengthen the financial test bootstrap with the captured production CHECK constraints, NOT NULL requirements, foreign keys, relevant triggers, actual ledger discriminators, and realistic role grants. Clearly document any omitted dependencies. Do not relax constraints to make a proposed implementation pass.

First reproduce the pending refund_payout incompatibility: current settlement inserts that type but the captured live wallet_transactions_type_check excludes it. Also reproduce the mismatch between the funding trigger's reversal type list and actual esim_purchase_refund callers. Inventory every live transaction type and producer/consumer, including verification_debit and call reversals, and define the intended debit/credit/reconciliation contract before choosing a schema or code fix.

Done when these incompatibilities are visible as meaningful failing regressions, the harness tests the actual proposed migrations, and subsequent tasks can fix them without relying on a permissive stand-in schema. Do not claim this focused fixture is a complete production baseline.
```

Task 6 local completion record (2026-10-17): [production-shaped financial tests and ledger inventory](financial-production-contracts-20261017.md). Captured constraints, grants, selected real triggers and reconciliation view now replace the permissive fixture. Catalog/fixture guards pass; financial gates correctly fail on payout/liveness type incompatibilities and eSIM/call reversal provenance. No accounting repair or deployment was performed; Tasks 7–8 remain required.

### 7. Complete unified wallet funding and provenance

**Priority:** Core financial blocker. Depends on Tasks 3 and 6.

```text
Review and complete the existing wallet_funding_integrity migration rather than create a competing accounting path. Every balance-changing debit/credit must atomically maintain the ledger, available balance, funding lots and reservations. Validate ownership, wallet and currency bindings. Spending must respect funds reserved by other operations and duplicate/concurrent calls must settle once.

Correct the transaction-type contract exposed in Task 6. Restore original consumed funding for known reversals, including actual eSIM and call refund paths; do not turn cash reversals into unverified/nonrefundable money or mint duplicate lots. Classify referral rewards as promotional and prevent cash withdrawal/gifting that would launder those rewards. Cover signed admin adjustments and gifts. Reconciliation must understand every actual type and report unexplained legacy inconsistencies without silently changing balances.

Done when mixed-origin funding, competing reservations/debits, original-funding reversals, gifts, referrals, adjustments and retries maintain the agreed invariants under independent concurrent sessions. Produce a read-only legacy reconciliation report and a separate proposed correction process for any historical issues.
```

### 8. Complete atomic wallet refunds

**Priority:** Core financial blocker. Depends on Tasks 5-7 and endpoint authentication.

```text
Review the replacement process-wallet-refund and _shared/wallet-refunds implementation with its SQL claim/settlement functions. Finish the refund_payout type/constraint repair, preserve funding provenance, and prove item/request/hold/lot/wallet/ledger changes commit atomically. Prevent competing processors and duplicate provider payouts with stable identities and claims.

Handle successful, failed, pending, partially completed and unknown outcomes explicitly. Poll known refund IDs. A timeout or stale claim is not permission to issue a second payout. Reserve only genuinely available refundable lot amounts and release only the proven unused portion. Keep remaining pending exposure reserved. Prepare the coordinated replacement of the old direct-mutation processor with the database funding trigger.

Done when simultaneous processors, repeated requests, partial completion, provider success followed by SQL failure, pending responses and ambiguous timeouts are recoverable without duplicate payout, duplicate ledger debit, or a permanently oversized reservation. No real payout is part of this task without explicit scope.
```

### 9. Complete SIM setup and instant-refill settlement

**Priority:** Core financial blocker. Depends on Tasks 6-8.

```text
Review the existing instant-refill worker repair, begin_refill_submission/settle_instant_refill_execution RPCs, compatible SIM finalizer, capture/release helpers and fallback flow as one contract. Do not patch the .zcode snapshot or simply skip a debit whenever wallet_hold_id is populated.

Require a valid bound reservation before supplier submission; persist the submission boundary; capture each delivered refill once; and atomically finalize the fee/payment receipt and supported schedules. Preserve ambiguous submissions for reconciliation. Check order ownership and line binding before all returns, including already-completed returns. Remove conflicting/unsafe finalizer signatures through a dependency-aware forward change with RESTRICT, not CASCADE. Keep one-argument and named-line client calls compatible. Standard/free fallback must use the existing pending canonical pricing interface and safe hold release. Review that interface now; final pricing policy and integration closure belong to Task 18.

Done when exact-balance and surplus-balance setup each charge one fee and one refill, concurrent finalizers are idempotent, failed-before-submit differs from unknown-after-submit, foreign order/line access is rejected, and actual PostgREST one-argument/named-line calls resolve without PGRST203. Record which API checks await authorized rollout. This completes the settlement package against the current pricing interface; explicitly defer final setup/fallback pricing certification until Task 18 reruns these cases.
```

Task 9 local completion record (2026-10-17): [SIM setup and instant-refill settlement](sim-setup-instant-settlement-20261017.md). Bound reservation checks, durable submission, idempotent capture, compatible finalization and safe fallback/cancellation pass 41 financial SQL/WASM blocks, 61 native PostgreSQL blocks/scenarios and 8 worker boundary tests. Production release and actual PostgREST call checks remain pending. Final setup/fallback pricing certification is explicitly deferred to Task 18.

### 10. Harden scheduled-refill funding and worker RPC contracts

**Priority:** Core financial blocker. Depends on Task 7 and the shared submission model in Task 9.

```text
Inspect the authoritative mini/custom workers and settle_successful_execution. Require an active, correctly priced hold bound to the payer, wallet, currency and execution before supplier submission, and revalidate on atomic settlement. Existing status/amount-only worker checks are insufficient. A missing hold must not silently produce financially settled success for wallet-funded work; model any legitimate external-payment path explicitly.

Trace actual callers of both update_execution_status overloads. Where still needed, converge to an unambiguous compatible signature with restrictive grants and preserve PIN/serial/redemption details. Do not recreate obsolete worker calls merely to match the PDF. Retain the current range bounds/value canonicalization, retired-SKU rejection, and service/delivery intent safeguards; rerun their existing reproductions.

Done when wrong-owner/wallet/currency, missing/released/insufficient/mismatched holds fail before purchase, duplicate settlement captures once, PIN results persist, and required HTTP RPC calls resolve. Current authoritative code already fixes the quoted userId and range/intent defects; verify deployed parity separately.
```

Task 10 local completion record (2026-10-17): [Scheduled-refill holds and worker contracts](scheduled-refill-holds-worker-contracts-20261017.md). Bound reservations, atomic preparation/submission/settlement, PIN persistence and restrictive overload retirement pass 62 financial SQL/WASM scenarios, 84 native PostgreSQL scenarios, 8 real isolated PostgREST HTTP scenarios and 124 worker/resolver tests. Production remains on the old contracts. The deployed legacy instant worker still calls the retired status API, so it must be replaced with Task 9's worker in the coordinated release. One pre-existing retained migration-manifest mismatch remains a release obligation. Task 11's local implementation prerequisites are satisfied; no next task was started.

### 11. Reconcile ambiguous provider outcomes and recover holds safely

**Priority:** Required for reliable money operations. Depends on Tasks 7-10.

```text
Implement or complete a bounded background reconciler for supplier submissions whose outcome is unknown. Query supported providers by the persisted stable external reference and adopt the existing transaction. Reconcile success/failure/pending before capturing, releasing or retrying. Include crashes immediately before/after submission and after delivery but before database settlement.

Review the existing reaper/expiry-recovery patch and scheduled job. Release only safe proven pre-submission or confirmed failed operations. Do not release an ambiguous supplier purchase, pending payout, active call, or legacy hold merely because expires_at elapsed or a new false submission flag was defaulted. Preserve unresolved cases and surface an operator action with non-sensitive correlation IDs.

Done when repeated/concurrent reconciliation creates no duplicate order, successful delivery captures exactly once, confirmed failure releases once, unknown outcomes stay reserved and visible, and recovery does not depend on the customer reopening the app.
```

Task 11 local completion record (2026-10-18): [supplier outcome reconciliation and safe recovery](supplier-outcome-recovery-20261018.md). Durable submission identities, bounded background lookups, atomic settlement/setup completion, safe reaper/expiry behavior and operator quarantine are tested locally. Production migration/worker activation, controlled provider verification, legacy reconciliation and the pre-existing source-manifest mismatch remain coordinated-release gates.

### 12. Repair the complete liveness-verification contract

**Priority:** Security and paid-settlement blocker. Depends on Tasks 3, 4 and 7.

```text
Remove customer self-confirmation and direct verified/health=100 fallback behavior from the client and privileged API. Preserve legitimate manual customer reports as separate non-provider-verified evidence if the product needs them. Settlement must use a trusted provider event tied to the owned stored attempt, SIM line and reservation/allowance.

Resolve verification_debit against the ledger constraint, funding trigger and reconciliation contract together. Verify service-only settlement grants, permitted outcomes and idempotent terminal states. Derive carrier verification and health from authenticated evidence and the established health calculation, not caller-supplied text or a fabricated 100 score. Ensure cancellation checks attempt ownership as in Task 4.

Done when a customer cannot self-award provider verification, paid success charges once without CHECK failure, allowance/free paths behave correctly, failures release safely, and duplicate/out-of-order/foreign-attempt callbacks cannot change a settled result or another user's line.
```

Task 12 local completion record (2026-10-18): [liveness verification repair](liveness-verification-repair-20261018.md). Self-confirmation and activity-text proof are removed from both clients/backend; owned attempts and exact funding reservations settle from authenticated provider events. Production-shaped SQL, independent-session races, real isolated API, Edge and focused Flutter checks pass. The forward migration and matching Edge/client changes remain undeployed; legacy evidence/holds and provider smoke checks remain coordinated-release gates.

### 13. Align call duration, reservation and billing

**Priority:** Financial blocker. Depends on Tasks 4 and 7.

```text
Repair make-call, _shared/call-media, finish_media_call and settlement as one call-budget contract. The current five-minute reservation cannot authorize a bridge limit derived from the whole posted wallet balance. Persist the accepted rate, connection fee, billing increment and reserved budget, and calculate a provider-enforced duration that fits that budget. Use atomic additional reservations only if extending calls is intentionally supported.

Respect billing increments and the agreed unanswered/partial-call rules. Fix the retry reference to undeclared balance. Keep call termination and settlement idempotent across duplicate/out-of-order events. Do not remove the settlement cap and debit unreserved money as a shortcut; general wallet repairs do not close this duration mismatch.

Done when five minutes of funding cannot authorize sixty minutes, simultaneous calls cannot share the same budget, increment/connection-fee boundaries are correct, retries return valid data, and settlement failure/unknown termination has a recoverable state.
```

Task 13 local completion record (2026-10-18): [call budget and billing alignment](call-budget-billing-20261018.md). Atomic funded snapshots now govern provider duration, billing increments/fees and capped settlement; durable submission markers prevent timeout re-dials. Destination evidence handles delayed bridge/hangup and recoverable failures. SQL, independent-session races, real isolated API, Edge and focused Flutter checks pass. Coordinated migration/Edge/client rollout and provider validation remain pending; legacy calls require reconciliation.

### 14. Repair notification SQL and scheduler continuation

**Priority:** Customer-facing runtime failure.

**Status — 2026-10-18:** REPAIRED LOCALLY; NOT DEPLOYED. The forward migration
uses `wallet_low`, durable event/outbox metadata, honest delivery state and
serialized rolling deduplication. Scheduler stages continue after observable,
sanitized failures. All 24 isolated native PostgreSQL scenarios pass, including
the reproduced original failure, actual postgres scheduler entry point, real
later emitters and overlapping sessions. See
[notification scheduler verification](notification-scheduler-repair-20261018.md)
for fixture boundaries and the targeted release requirements.

```text
Repair emit_upcoming_refill_low_balance_reminders to use the supported notification contract, including wallet_low rather than the invalid wallet category in both insertion and deduplication. Inspect required event/template/outbox fields and route the reminder through the established durable delivery path. Do not set a channel as delivered merely because a notification row was inserted.

Reproduce the low-available-balance/upcoming-refill branch with production constraints and call process_due_notifications through its actual authorized scheduler path in an isolated environment. Verify later emitters still run, repeated sweeps deduplicate, and alert failures are observable rather than silently swallowed.

Done when the trigger branch no longer aborts the scheduler, one logical reminder is created, delivery state reflects real processing, and other due reminders/urgent alerts remain functional.
```

### 15. Repair usage forecasts against actual eSIM storage

**Priority:** Runtime/data-contract failure.

**Status — 2026-10-18:** REPAIRED LOCALLY; NOT DEPLOYED. A forward migration
uses actual eSIM usage/expiry, matching purchase records and composite catalogue
keys. Unknown evidence stays unknown; valid physical forecasts survive observable
eSIM failures. Owner/manager manual recharge and the recorded postgres cron
entry point pass isolated verification. All 32 native PostgreSQL scenarios pass,
including both original failure reproductions. See
[usage forecast verification](usage-forecast-repair-20261018.md)
for schema mappings, test boundaries and targeted release requirements. The old
null-anchor migration remains superseded and must not be applied unchanged.

```text
Repair compute_usage_forecasts/refresh_usage_forecasts using the actual user_esims/order/catalogue and usage-sample relationships. Establish where validity, expiry, initial value and usage live before rewriting joins; renaming public.esims alone is insufficient. Preserve physical-SIM forecasting and avoid inventing values for missing eSIM metadata.

Test no-data, null recharge anchor, sparse samples, active/expired eSIMs and physical SIMs together. The retained old null-anchor migration uses a method label not accepted by the current constraint; do not apply it unchanged.

Done when scheduled and manual refresh paths run with real schema constraints, produce defensible forecasts or explicit unknowns, and a missing eSIM baseline cannot roll back otherwise valid physical-SIM work unnoticed.
```

### 16. Repair admin maintenance, account deletion and audit records

**Priority:** Privileged runtime and operational correctness.

**Status — 2026-10-18:** REPAIRED LOCALLY; NOT DEPLOYED. Supported pruning/audit
and rate-health contracts pass verification. Persisted purge jobs distinguish
request, processing, failure and completed Storage/Auth deletion, retaining the
authorized actor. Accounts with funds or retained financial/provider evidence
require reconciliation before deletion. A versioned intentional replacement for
the captured deployed `send-admin-email` v2 is included. All 29 native SQL/Edge
integration scenarios and 20 isolated Edge tests pass; the changed admin
repository passes Dart analysis. See
[maintenance/deletion verification](admin-maintenance-deletion-repair-20261018.md)
for the coordinated release, legacy-state treatment and retention/provider gates.

```text
Repair admin_purge_user_account, admin_prune_database_logs and check_rate_limit_health against the actual account_deletions/admin_audit_log/system_alerts contracts. Replace the nonexistent current_user_email helper or recover its intended equivalent; supply required fields and supported columns. Preserve admin authorization, retention bounds and audit semantics.

Correct purge-accounts' admin_log parameter from the incompatible p_reason contract to the actual supported parameter and handle returned errors. Ensure an asynchronous purge is not reported completed before irreversible Auth/storage deletion finishes; record request, success and failure truthfully with the authorized actor. Reconcile kick_admin_email/send-admin-email against deployed inventory; a missing local file does not prove the live function is absent.

Done when isolated admin/non-admin tests cover pruning, alert thresholds, deletion success/failure and persisted audit evidence, and the email dependency has versioned source or a documented intentional replacement. Do not delete production accounts or send real email as a test.
```

### 17. Make DID purchase and renewals financially safe

**Priority:** Supplier-spend blocker. Depends on Tasks 7, 11 and 13's shared calling boundaries.

```text
Repair manage-dids using a verified server-side supplier quote and retail pricing snapshot. Reserve funds before provisioning, use a stable order identity, reconcile unknown provider outcomes, and mark a DID active only under the agreed confirmed provisioning/payment state. A failed debit must not be logged and ignored. Remove customer wholesale values from search and purchase output.

Define and implement the intended monthly renewal/insufficient-funds/suspend/cancel lifecycle with idempotent billing and reconciliation. Confirm provider renewal obligations before assuming local suspension stops supplier costs. Keep the feature disabled for broad paid use until this lifecycle is proven.

Done when concurrent purchase/renewal, quote change, timeout, duplicate callback, insufficient available funds and capture failure cannot create uncharged active service or duplicate provisioning, and retail responses contain no supplier cost.
```

Task 17 local completion record (2026-10-18): [virtual-number financial safety](virtual-number-financial-safety-20261018.md). Fresh supplier-price checks, exact funded capture, retail-only output and provider-verified idempotent renewal/release passed isolated SQL, concurrency, Edge and client checks. The new acquisition gate defaults off and requires explicit pilot users. Coordinated deployment and account-specific supplier/invoice lifecycle proof remain pending; broad paid use stays disabled.

### 18. Finish canonical pricing and paid-entitlement evidence

**Priority:** Pricing integrity. Depends on Tasks 6-9.

```text
Review the pending canonical paid-pricing and eSIM-catalogue migrations with current business rules. Make quote, order creation, wallet/external collection, fallback and customer display agree. Preserve published zero-fee promotions and explicit rounding/currency/payment-rail rules. Do not charge a wallet-funded purchase a deposit gateway fee again.

Grant upgrade credit only from valid unexpired paid evidence, including legitimate wallet ledger and external-payment receipts or an approved grandfather record; requiring only plan_payments would reject valid wallet-funded plans. Do not deploy the superseded unsafe October 4 migration. Confirm configured fees before treating fallback constants as actual production prices. Align refill_pricing's obsolete/ignored arguments and advisory tests with the approved server contract; do not reintroduce old Premium pricing to satisfy stale tests.

Rerun Task 9's setup/fallback acceptance cases after the pricing review or changes, even if they passed earlier; this closes its explicitly deferred pricing integration check. Done when those cases pass, quote equals charge, range offers are priced for the dispatched value, zero fees remain zero, valid upgrades work, forged/expired draft labels earn no benefit, and checkout cannot authorize a purchase using a client estimate.
```

Task 18 local completion record (2026-10-18): [unified pricing and paid entitlement](pricing-entitlement-unification-20261018.md). Shared wallet/external/grandfather evidence now drives entitlement and upgrade credit; configured pricing, zero promotions, quote-bound payment, funded setup snapshots, eSIM catalogue/purchase and range dispatch prices are covered. All 40 native SQL scenarios, including Task 9 setup/fallback acceptance and races, passed alongside 147 Flutter and 18 Edge tests. Coordinated release, live configuration/source verification and controlled runtime/provider checks remain pending.

### 19. Close wholesale leaks and personalized-read authorization

**Priority:** Customer-data isolation. Depends on Tasks 3 and 18.

```text
Review the existing retail_customer_contracts repair and complete uncovered surfaces: get_authoritative_refill_quote, return-trip APIs/tables, calling rates, entitlement helpers, provider_offers/effective views, zendit_offers_cache, esim_offers, and DID responses. Require caller/line ownership for personalized reads and writes. Keep internal supplier access intact while exposing explicit retail-only projections to customers.

Use appropriate invoker views or revoke public access with sanitized replacements. Avoid changing a view to invoker and then granting customers broad wholesale base-table reads just to restore it. Remove supplier cost/margin/note fields from RPCs, models, widgets and fallback queries, including SELECT * paths. Preserve accepted historical trip prices; represent unknown legacy prices honestly.

Done when anonymous and foreign-user requests are denied where appropriate, customer direct-table/view/RPC/fallback paths expose only allowed data, legitimate catalogue reads still work, and privileged backend pricing retains the required supplier information.
```

Task 19 local completion record (2026-10-18): [retail data and ownership](retail-ownership-repair-20261018.md). Supplier base/diagnostic access and internal helpers are denied to customers; explicit retail catalogue/receipt/approval projections, owner checks and guarded admin inspection preserve legitimate reads. Accepted trip prices remain stable and legacy unknowns stay null. All 23 native SQL scenarios, 81 Flutter tests and 18 DID backend tests passed. Coordinated SQL/customer/admin deployment, real API/cache checks and the broader release gate remain pending; fresh live metadata still shows the old exposure. Task 20's schedule writes and queue lifecycle remain separate work.

### 20. Retire legacy queue calls and protect scheduled pricing

**Priority:** Financial request integrity. Depends on Tasks 9, 10 and 18.

```text
Replace active customer calls to queue_premium_refill_executions with the current single-next-occurrence scheduling lifecycle. Trace both creation and upgrade callers before retiring/restricting the server API. Do not infer that queued rows themselves prove prepayment or free supplier fulfillment.

Move scheduled_topups financial/engine fields behind validated server mutations: owner, amount, base cost, app fee, tier, authorization ceiling and engine/version values must be derived or checked on the server. Preserve supported customer schedule controls and offline reminder synchronization. Review table and column grants, RLS, triggers and both clients together; removing client fields alone does not enforce the boundary.

Done when tampered insert/update requests cannot set authoritative pricing or entitlement fields, ordinary users can still manage their permitted schedules, one future occurrence is maintained, and existing schedules migrate without duplicate purchases.
```

Task 20 local completion record (2026-10-18): [legacy queue retirement and scheduled pricing](scheduled-pricing-boundary-20261018.md). Both creation and upgrade use validated initialization; owner/price/entitlement/engine fields are server-controlled, old batches are paused for reauthorization, uncertain work is retained and only one next occurrence is claimable. All 36 native SQL/concurrency/real local API scenarios, 60 focused customer Flutter tests, two admin tests and 62 backend tests passed. Both apps were regenerated; analysis has no errors but existing warnings/lints and an unrelated notification-test failure remain. Production still has the old grants/API. Coordinated SQL/client/worker release, legacy reconciliation and controlled runtime acceptance remain required; Task 21 was not started.

### 21. Repair offline voucher state

**Priority:** Feature correctness.

```text
Repair offline_voucher_state to use actual offline_voucher_requests lifecycle values, including the open state rather than nonexistent pending/processing values. Trace the customer/admin consumers and map open, fulfilled, cancelled and no-request states accurately. Preserve ownership and voucher-secret access rules.

Done when all request states have focused SQL/client coverage and the customer sees the correct active request. Do not activate unverified recovery endpoints, seed fake production stock, or expand the offline feature as part of this repair.
```

Task 21 local completion record (2026-10-18): [offline-voucher state repair](offline-voucher-state-repair-20261018.md). The state RPC now joins the actual `open` lifecycle; fulfilled, cancelled and absent requests project no active promise. Request/grant owner checks and secret-free fields are preserved. All 18 isolated SQL and 41 offline-recharge Flutter tests pass, including SQL-response-driven widget deadlines and guarded admin filters. No deployment, feature activation, production stock or recovery endpoint changes occurred; fresh live verification remains pending.

### 22. Make migrations and deployment sources reproducible

**Priority:** Required before claiming a repeatable release. Depends on Task 1; incorporate final contracts from earlier tasks.

```text
Recover and version the deployed SQL/Edge/worker contracts missing from source, including surviving overloads and the confirmed active live send-admin-email function. Compare normalized signatures/bodies, table constraints, policies, effective grants, owners, extensions, non-public dependencies, cron definitions and required non-secret seed/config state. Reconcile the audit's 17 function definitions by signature and purpose rather than copying its count.

Respect the archive manifest: active migrations are a review queue, not a reset baseline. Do not blindly restore/replay archived scripts, fabricate historical application dates, mark remote versions reverted because files moved, or run unfiltered db push. Design a controlled baseline/history procedure; test both clean provisioning and upgrade from the current shape. Include both application repositories and the authoritative backend repository in repeatable checkout/test tooling, and repair stale test paths through the archive resolver.

Done when required functions and dependencies are reproducible without resurrecting unsafe definitions, deployment manifests name source versions/configuration, and both fresh and upgrade verification pass or remaining gaps are explicitly blocking.
```

Task 22 source reconstruction record (2026-10-18): [database/deployment reproducibility](source-reproducibility-20261018.md). Seventeen missing signatures and active email v2 are recovered as evidence; fresh catalog hashes match all 369 public export routines. Archive provenance, explicit candidate manifests and three-repository source checkout/test tooling are implemented locally. Full clean provisioning and complete current-shape upgrade remain explicitly BLOCKED on platform/non-public/owner/configuration/history/Edge/worker-runtime evidence. Scoped local tests pass; no deployment or history repair occurred. Task 23 may use the candidate inventory, while full release prerequisites remain unmet.

### 23. Monitor the full required worker fleet

**Priority:** Operational safety. Depends on Tasks 1, 11, 17 and 22 as applicable.

```text
Build a complete versioned process manifest from the actual required VM services. Confirm which offer-cache, refill, eSIM, voucher, messaging and reconciliation processes are intended; do not add dormant services solely because files exist. Match source locations, runtime configuration, restart/deployment procedures and version reporting to project rules.

Add per-worker heartbeats and meaningful health for queue age/backlog, stale claims, ambiguous supplier outcomes, unresolved holds, payout reconciliation and failed billing/notification jobs. A green eSIM heartbeat cannot stand for fleet health. Correlate events without logging secrets or customer financial/provider payloads.

Done when stopping/stalling each required process is detected, reconciler backlogs are visible, alerts are bounded/deduplicated, and the health endpoint distinguishes partial failure from a healthy fleet. Test with local/isolated adapters before any authorized VM exercise.
```

Task 23 local completion record (2026-10-18): [required fleet and reconciliation monitoring](worker-fleet-monitoring-20261018.md). Fresh sanitized PM2 inventory confirms eight active services; the manifest also requires the pending supplier reconciler and excludes dormant voucher/alternative messaging scripts. Per-process and work-lane telemetry, 24 aggregate queue/reconciliation probes, 23 cron requirements, cached queue freshness, bounded incident alerts, full-fleet public health and guarded admin detail are implemented locally. All 50 isolated native SQL/concurrency, 125 focused backend, 10 health-handler and two admin tests pass. Focused analysis/syntax checks pass. No production deployment, process stop/restart, provider action or controlled live failure exercise occurred; coordinated release and runtime acceptance remain required.

### 24. Establish a clean release gate

**Priority:** Release blocker. Depends on the relevant completed repairs.

```text
Run current analysis/tests/build checks for customer, admin, database, Edge and authoritative workers using pinned toolchains and reproducible repository checkouts. Record actual results; the latest stored broad review reports 821 passing and 22 failing Flutter tests plus analysis failures, so the PDF's nine failures are not a current complete baseline.

Fix remaining failures according to approved contracts rather than deleting assertions or weakening financial/security tests. Cover real PostgREST overload resolution, role/ownership denials, production-shaped SQL constraints, independent-session money concurrency, payment/webhook retries, provider-submission crash boundaries and the relevant UI flows. Add CI for these release checks, secret scanning and migration/source consistency. Avoid unnecessary blanket dependency upgrades or architecture refactoring.

Done when the supported release targets build and the required gates pass with no unexplained failure suppression. Clearly separate mocked, isolated database, real API, provider sandbox and live smoke evidence; none substitutes for another.
```

Task 24 local verification record (2026-10-18): [test repairs and release checks](release-checks-20261018.md). All 893 customer, 32 admin, 232 Edge and 206 authoritative worker tests pass, alongside all 20 isolated database suites. A pinned release runner and CI now require strict analysis, source/security consistency, native concurrency, real local API calls, runtime checks and builds. Customer iOS compilation and admin macOS/web builds pass. **Clean-gate acceptance remains OPEN:** 33 customer analysis advisories, 196 admin diagnostics (including 53 previously excluded copied-source errors), absent Android signing, Edge dependency/runtime and hosted-CI/platform/deployment evidence still block release. No rollout or provider action occurred; Task 25 activation prerequisites are unsatisfied.

### 25. Prepare and perform a coordinated rollout when authorized

**Priority:** Final closure, not permission implied by this review. Requires preceding applicable gates.

Task 25 preparation record (2026-10-18):
[coordinated rollout runbook](coordinated-rollout-runbook-20261018.md) and
[blocked operational manifest](coordinated-rollout-manifest-20261018.json)
pin the SQL/Edge/worker/client inputs, explicitly include the concurrent Task 23
dependency, and specify containment, read-only reconciliation, deployment order,
runtime acceptance and forward recovery. Six local artifact-safety tests and four
isolated old/repaired-schema preflight scenarios pass. Source drift, final
Tasks 22–24 evidence, backups, legacy reconciliation and scoped operational
authorization remain blockers. No rollout, restart, provider spend or production
finding closure was performed. See
[actual verification results](coordinated-rollout-results-20261018.json).

```text
Prepare a concrete release manifest and runbook for the reviewed patches. Identify the exact target environment, backups/recovery evidence, allowed test accounts/provider budget, temporary money-processing restrictions, migration order, Edge/worker/client versions, API cache handling, observability checks and compatible rollback/forward-fix procedure. Use the existing October 16 rollout review as the starting point, updated for all new changes.

Before financial activation, run the read-only preflight and reconcile existing legacy submissions, refund items, original-funding reversals, expired/ambiguous holds and unexplained wallet differences. Never invent lots or rewrite customer balances to force consistency. Stop incompatible old instant/refund processors, deploy the compatible database/Edge/authoritative worker changes together, and resume only after required checks. Follow the project-specific direct worker deployment procedure when deployment is explicitly authorized. Broad source-history reconstruction must not be used as a reason to postpone an independently safe urgent containment release.

With separate operational authorization, verify actual grants, deployed definitions, API overload calls, cron execution, worker heartbeats, controlled setup/refill/refund/call/DID flows, denial cases and reconciliation. Enable money/provider features gradually under the scoped budget with rollback controls.

Done when the finding register links each closed issue to deployed versions and runtime evidence, unexplained money discrepancies are resolved through an approved process, and any remaining disabled features/blockers are explicit. Until authorized, deliver the runbook and validated local work without claiming rollout completion.
```

## Audit coverage map

| PDF section | Executor tasks |
| --- | --- |
| 1.1 Finalization overloads and schedule crashes | 3, 6, 9, 18, 22 |
| 1.2 Setup refill double-debit | 7, 9, 11, 25 |
| 1.3 Wallet/lot/hold/referral/reconciliation | 6, 7, 8, 11 |
| 1.4 Conditional SQL crashes | 9, 12, 14, 15, 16, 18 |
| 1.5 Maintenance grants and self-verification | 3, 12 |
| 1.6 Pricing, ownership, views, ACLs and voucher state | 3, 18, 19, 20, 21 |
| 2.1 PayPal deposit identity | 5 |
| 2.2 Call budget and retry | 13 |
| 2.3 Credentials, authentication, DID, refunds, audit/email | 2, 4, 8, 12, 16, 17 |
| 3.1 Worker/RPC/source/deployment drift | 1, 10, 22, 23, 24 |
| 3.2 Supplier selection, holds and recovery | 9, 10, 11 |
| 4 Flutter contract drift and tests | 9, 12, 18, 19, 20, 24 |

## Evidence and reference notes

- User-supplied PDF: `/Users/thehonest/Downloads/KeepSIMs_Code_Audit_Report (1).pdf`, all 12 pages. The document's instructions are recommendations assessed here, not authorization to execute them.
- Captured schema: `/Users/thehonest/Desktop/live_public_schema.sql`. A later read-only MCP query confirmed the specific finalizer grants, default ACLs, worker function grants, and wallet transaction constraint listed above against the live project.
- [Existing financial implementation review](supabase-financial-security-remediation-20261016.md): local changes, recorded tests, limitations and coordinated rollout gates.
- [Existing financial assessment](../implementation-plans/supabase-financial-security-remediation-20261016.md): original scope, corrections and financial invariants.
- [Migration cleanup assessment](migration-cleanup-20261016/README.md) and [active migration guidance](../../supabase/migrations/README.md): archive/source/history restrictions.
- Additional repair evidence: [pending funding trigger](../../supabase/migrations/20261016020000_wallet_funding_integrity.sql), [isolated fixture](../../supabase/tests/fixtures/financial_remediation_baseline.sql), and captured `wallet_transactions_type_check`. Line numbers are review-time pointers; recheck current source before editing.
- [Supabase RLS guidance](https://supabase.com/docs/guides/database/postgres/row-level-security): grants, policies and invoker-view behavior.
- [Supabase Edge authentication guidance](https://supabase.com/docs/guides/functions/auth): distinguish user, service and provider-webhook authentication.
- [PostgreSQL row security](https://www.postgresql.org/docs/current/ddl-rowsecurity.html): RLS does not cover TRUNCATE/REFERENCES. This supports removing unsafe privileges, but does not by itself prove an anonymous HTTP TRUNCATE route exists.

This plan prioritizes the supplied audit. It does not certify unrelated platform, store-release, compliance or architecture readiness.
