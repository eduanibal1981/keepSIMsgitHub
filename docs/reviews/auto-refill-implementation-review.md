# Auto-refill implementation review

Reviewed 15 September 2026 against the executor implementation and the original resilience plan.

## Verdict

**Changes requested. This is a partial implementation with material security, financial, and reliability defects. It is not ready to be accepted as completion of the plan.**

Useful progress includes an atomic capture/status RPC, improved funding-lot allocation, preserving holds after potentially submitted requests, explicit target/cap fields, and removing one duplicate next-cycle insertion. Those improvements do not establish safe end-to-end behavior yet.

The two main product requirements remain unmet:

- Customer transparency/authorization: approval can be performed without ownership checks; the app has no wired approval action; uncertain purchases still become “failed”; invalid substitutions can change the delivered benefit.
- Owner protection: ranged purchases are priced at their minimum, persisted submission state is best-effort, and there is no demonstrated automatic settlement recovery for retained holds.

## What was verified

- Read the five new migrations, changed Flutter scheduling paths, both updated workers, provider adapters, resolver, and phase test suites.
- Read deployed Supabase definitions and privileges. The unsafe approval function and provider initialization are deployed, not merely proposed migrations.
- Compared SHA-256 hashes of the deployed VM's `offer_validation.js`, `worker_auto_custom_refill.js`, and `worker_auto_mini_refill.js` with local authoritative files. All three match. This verifies deployed files, not in-memory PM2 module reloads or actual supplier transactions.
- Live snapshot contains three pending v2 custom executions. All three already list their selected provider in `attempted_providers` before the next worker run.
- Ran the executor's four phase suites: **26 passed**. Several tests simulate replacement logic in the test itself or assert source text, rather than execute the database/worker interaction.
- Added and ran six isolated probes calling the actual resolver: **all six fail their required-behavior assertions**. No supplier, database, wallet, or network calls are made by these probes.
- No customer data, balances, functions, schedules, or production configuration were modified during this review. Added only this report and the local regression probe file. No real-money purchase tests were performed.

## Findings, ordered by urgency

### R1 — P1: Anyone with an execution ID can approve someone else's spending

Source: `supabase/migrations/20260915050000_approve_refill_execution_rpc.sql:20–51`.

`approve_refill_execution` is `SECURITY DEFINER`. It reads solely by execution ID, never requires `auth.uid()`, never checks the payer/line owner or authorized household manager, and never validates the caller's right to change the limit. It updates both the queued execution and the recurring schedule. The migration grants authenticated execution without revoking the default PUBLIC grant.

**Live evidence:** `has_function_privilege('anon', ..., 'EXECUTE') = true` and authenticated execution is also true. This is authorization failure; UUID unpredictability is not authorization. A caller who knows the ID of an awaiting-approval execution can raise its cap and queue it without the customer's approval.

The new `resume_awaiting_funds_executions` function also has anonymous execution permission and no ownership check. Fix the complete set of new RPC grants, not just the UI.

**Required:** revoke PUBLIC/anonymous execution, explicitly require authentication and owner/payer/manager permission, validate finite positive limits and allowed transitions, preserve household restrictions, and record consent. Separate a one-time approval from a permanent recurring limit increase. Test anonymous and cross-user calls against the actual database function, without changing live customer records.

### R2 — P1: A range's largest refill can be charged at its smallest price

Source: `C:/Users/abdal/Work/KeepSIMs/backend-sync-wt/offer_validation.js:459–470`; SQL quote function also uses `price_min_usd` at `20260915040000_phase2_intent_pricing_and_authorization.sql:210`.

The resolver sets `resolvedOfferValue` to the requested value, but always assigns `costUsd = price.min`. Provider adapters can send the requested destination value, while the wallet reserves minimum cost plus fee.

**Reproduced:** fixture with a $1 minimum/$100 maximum and a requested maximum value returns `offerValue=100` and `costUsd=1`. The actual maximum endpoint is $100. The nominal “margin floor” still passes because it compares the customer charge with the same understated cost.

**Required:** derive the exact supplier debit for the chosen destination amount using the provider's supported quote/calculation mechanism. Bind exact quote, request payload, cap, and hold. Verify endpoints, intermediate values, currencies, units, supplier fees, and real settlement bounds. Block automatic range purchases whose cost cannot be established.

### R3 — P1: Newly queued refills skip their selected supplier before any attempt

Sources: `20260915030000_phase1_atomic_settlement_and_recovery.sql:310–313` and `C:/Users/abdal/Work/KeepSIMs/backend-sync-wt/offer_validation.js:548–553`.

The routing trigger initializes `attempted_providers` with the selected provider at insertion. The resolver removes every provider in that array from its available candidates. These individually tested changes contradict each other.

**Live evidence:** all three pending custom executions already contain their selected provider in this array. The resolver will skip it; with no alternate it fails, and with alternatives it can route away from the preferred supplier unnecessarily.

**Reproduced:** one enabled DT One mapping, a matching preferred offer, and the trigger-generated `['dtone']` value immediately throw “All available suppliers have already been attempted.”

**Required:** do not mark a provider attempted on schedule insertion or quote selection. Persist submission attempts and outcomes separately. Exclude a provider for the appropriate retry reason only after a real attempt; unknown attempts must be reconciled, not excluded in order to start another purchase. Repair existing pending rows only after verifying their submission history.

### R4 — P1: Wrong products can pass “intent” matching and advance line protection

Sources: `C:/Users/abdal/Work/KeepSIMs/backend-sync-wt/offer_validation.js:375–449`; `20260915060000_phase3_scheduling_and_cross_flow_coordination.sql:20–69`.

Four resolver paths violate the customer-intent rule:

1. An existing offer ID is accepted without checking that its current destination amount/currency still matches.
2. Supplier native cost is accepted as evidence of destination value. The code even does this when a conflicting destination value exists.
3. If intent matching fails, historical-price proximity selects another product without preserving destination benefit.
4. No service/delivery requirement excludes PINs, data, or bundles from direct airtime matching.

**All four behaviors were reproduced against the real function.** The workers do not pass distinct mini/custom qualification policies. Both can purchase a PIN. The new cross-flow trigger assumes any successful custom/instant/manual transaction extends line validity and pushes mini protection into the future, without checking redemption, qualifying denomination, or carrier activity rules.

**Required:** remove price-based equivalence; validate even the preferred SKU against complete intent; use destination units and explicit service/delivery semantics. For mini, require verified qualifying activity and reviewed carrier rules. A PIN purchase or nonqualifying data purchase must never reset the protection clock.

### R5 — P1: Uncertain purchases become retryable failures, with no demonstrated recovery to settlement

Sources: both workers' catch blocks (`worker_auto_custom_refill.js:527–592`), reaper (`20260915030000_phase1_atomic_settlement_and_recovery.sql:349–357`), and deployed `retry_topup_execution`.

Retaining the hold after a timeout is an improvement. But the worker then calls `markExecutionFailed` even when delivery is unknown or supplier success was observed and local settlement failed. The reaper likewise changes a submitted/uncertain row to `failed`. Generic result notifications can consequently contradict the worker's “under verification” message.

The existing user Retry function still accepts `failed`, creates a new execution ID, and copies historical fields. It does not inspect an unresolved supplier attempt or retained hold. A new execution gives the provider a different external reference. Depending on available funding/routing, this can permit another purchase while the first could still deliver; the provider-skip bug is not a reliable safety control.

Confirmed provider declines also take the same general catch path, retain the hold, and are described as ambiguous. No automatic scheduled-refill reconciler was found in the changed workers or inspected database jobs. An alert alone does not query the provider, capture delivered refills, release definitive failures, or finish the cycle.

**Required:** distinct pending/unknown/delivered-unsettled/definitively-failed states; persisted provider external ID; automatic reconciliation using that same ID; retry settlement without repurchase; release on proven non-delivery. User Retry and reaper must use the same state machine. Preserve a stable occurrence across attempts and make duplicate callback/settlement handling idempotent.

### R6 — P1: Submission can proceed after losing its database record or with an incorrect hold

Sources: `worker_auto_custom_refill.js:286–329` (same in mini); `20260915030000_phase1_atomic_settlement_and_recovery.sql:168–234`.

- Hold reservation and linkage are separate calls. Link failure logs a warning but does not stop the purchase.
- The `carrier_in_flight=true` update result is ignored. A database failure can leave a submitted request looking safe to requeue.
- Route/price updates also ignore returned errors.
- A pre-existing `wallet_hold_id` bypasses reservation without verifying that it is active, belongs to this payer/occurrence, and covers the current price.
- Settlement permits a null hold, skips capture for a nonexistent hold, and marks success. It does not require the hold amount/owner/reference to match the execution. Its already-success path can return success with no ledger transaction.

**Required:** atomic quote/hold/attempt preparation before submission; mandatory persistence and version/fencing checks; validate adopted holds; enforce funded-settlement invariants. Supplier success with a missing/invalid hold is a financial reconciliation exception, not successful settlement. Keep legacy prepaid exceptions explicit and separately validated.

### R7 — P1: Backfill assigns every custom schedule the same 1 OMR/DT One intent

Source: `20260915040000_phase2_intent_pricing_and_authorization.sql:39–55`.

The migration's comment says Omantel, but its predicates match **every** custom schedule/execution with missing target fields. They do not filter the line's carrier/country/product. Schedule backfill also changes preferred provider to DT One. Historical executions are not restricted to pending status.

This can rewrite another carrier's or package's customer intent and alter historical records. The baseline document itself lists pending custom executions using other providers, so a universal Omantel assumption is not supported by that baseline; their intended benefits require individual verification.

**Required:** audit affected rows against original selection/setup evidence and provider-qualified metadata; correct only with established destination benefit and authorization. Do not infer intent from price or assume every customer owns the same carrier. Preserve history. Unrecoverable intent should require review, not silent substitution.

### R8 — P1: “Approval required” has no usable approval journey in the customer app

Sources: `lib/features/scheduled_topups/ui/widgets/scheduled_topup_sheet.dart:1166`; repository/model/UI search.

The app writes `maxAuthorizedUsd = totalAmount` internally. The new field exists in models, but the inspected app contains no call to `approve_refill_execution`, no corresponding approval action, and no explicit customer-editable recurring limit/one-time approval flow. The notification tells customers to approve in KeepSIMs without implementing that action. Existing Retry only handles `failed`, not `awaiting_approval`.

The quote RPC is also not wired into the schedule save path; the repository still directly saves locally priced schedule data. No versioned consent or immutable quote snapshot was found in that path.

**Required:** finish setup/edit/approval UI and server-owned save/quote RPCs, full charge/fee breakdown, explicit recurring-limit consent, one-time approval, correct money/protection statuses, and localization. Verify the full mobile journey instead of asserting that fields appear in source.

### R9 — P1: The new line-concurrency check is not concurrency serialization

Source: `20260915060000_phase3_scheduling_and_cross_flow_coordination.sql:80–105`.

`NOT EXISTS` checks for a currently processing sibling, but concurrent mini/custom claim transactions can both observe none and lock different execution rows. Even one batch can select multiple pending rows for a line from the same statement snapshot. Locking each execution with `SKIP LOCKED` does not lock the shared line or create uniqueness for an unresolved purchase.

**Required:** lock a shared line/occurrence record using a consistent order, or enforce an appropriate database uniqueness constraint with a durable submission state. Test two actual database connections and multiple rows in one batch. The current JavaScript test mutates statuses sequentially, so it cannot reproduce the SQL race.

### R10 — P1: Lowering a pending refill cap can leave the old higher cap executable

Source: `20260915060000_phase3_scheduling_and_cross_flow_coordination.sql:300–312`.

The queue trigger notices a schedule cap change, but its “matching pending execution already exists” query omits `max_authorized_usd`, provider, engine version, and intent kind. If amount/date/offer/target remain the same, it returns without updating the pending execution. The worker reads the execution's old cap and never revalidates the current schedule authorization immediately before submission.

Also, pause/update cancellation covers pending/pending-payment only, not awaiting-approval/funds; old waiting rows can remain after replacement. The worker has no final schedule-version check to fence out stale claimed work.

**Required:** versioned authorization checked at dispatch; synchronize all relevant unsubmitted states; invalidate/requote stale work atomically. Test cap decrease, provider change, pause, and approval races against the real trigger chain.

### R11 — P2: Profitability and current pricing are not established by the implemented checks

Sources: `C:/Users/abdal/Work/KeepSIMs/backend-sync-wt/offer_validation.js:130–174,341–353,469–479`; SQL quote function in the phase-2 migration.

Fees remain hard-coded in the worker instead of using the published fee rule/version. The SQL quote returns a hard-coded fee version and still treats a valid zero fee as missing. Stale-cache fallback remains, including reconstructed enabled offers; fixed destination metadata is still dropped by the cache writer. The margin check is effectively “cost plus a positive fee is at least cost,” ignoring whether the cost is current/complete/bounded and whether funding/settlement costs consume the fee.

The SQL quote also has no line-owner check, does not constrain explicit offers to the line's carrier, and its benefit lookup joins mappings on provider but not provider-specific country/carrier codes. Without an explicit offer, its uninitialized RECORD access needs testing/fixing before wiring it into clients.

**Required:** one verified pricing contract for UI/worker/database, fresh destination/cost evidence, published fee version, supplier debit bounds, and full owner cost accounting. Do not describe `is_profitable=true` as protection against owner losses until those values are proven.

### R12 — P2: Delivery evidence and migration/test completeness fall short of the plan

- No demonstrated immutable quote/consent/attempt history, bounded reconciliation, durable notification outbox, shadow rollout, or complete rollback/recovery workflow.
- Both workers still allow entitlement lookup errors/not-found to fall through to purchasing.
- Phase-3 SQL references `topup_executions.engine_version` and `intent_kind`, while the new phase-2 migration adds those only to schedules. The columns exist live, indicating the supplied migrations alone do not document that portion of the schema change. Verify a clean replay rather than rely on production-only patches.
- Many tests encode desired behavior in separate JavaScript mock functions or use regexes to assert implementation text. This is why the incompatible “initialize attempted provider” and “exclude attempted providers” changes both pass.

**Required:** complete the missing migration history and plan work, then run actual SQL integration, multi-connection concurrency, worker crash/timeout, approval authorization, and UI tests. Passing the current phase suites is not sufficient release evidence.

## Required next steps

1. Urgently close the deployed approval/resume RPC access holes with ownership checks and correct grants. Check audit history for unexpected approvals without asserting that abuse occurred.
2. Repair provider initialization and ranged pricing before relying on unattended purchases. Review the three pending rows and the broad backfill against original intent.
3. Complete durable submission/settlement/reconciliation and protect every retry entry point. Do not enable a new supplier retry to compensate for these bugs.
4. Enforce real product equivalence and qualifying activity, then finish customer approval and server-authoritative quote/save flows.
5. Add database-backed tests for RPC permissions, claim races, cap edits, and settlement failures; keep the six resolver regression probes. Re-run the original plan's release gates and verify deployment.

I would not sign off on unattended real-money execution until these release blockers are resolved. The useful fixes can be retained; this does not require discarding all the executor's work.

## Reproducing the local checks

From `C:/Users/abdal/Work/KeepSIMs/keep_sims`:

```powershell
node --test --test-isolation=none ../backend-sync-wt/test/phase1_settlement_and_holds_test.js ../backend-sync-wt/test/phase2_canonical_offers_and_pricing_test.js ../backend-sync-wt/test/phase3_scheduling_and_recovery_test.js ../backend-sync-wt/test/phase4_safe_failover_and_replacement_test.js
node --test --test-isolation=none docs/reviews/auto-refill-review-repros.cjs
```

Observed results: first command 26/26 pass; second command 0/6 pass, with failures documenting actual resolver defects. The default isolated test runner initially could not spawn processes in this review environment; same-process test mode ran successfully. These results are local code checks, not paid end-to-end supplier validation.

Deployed/local matching SHA-256 values:

| File | SHA-256 |
|---|---|
| `offer_validation.js` | `35894424bbaaecd1838cfdc83cc83601559589d16f176e443a75d49414006a72` |
| `worker_auto_custom_refill.js` | `3ed948fe742eec55d0d33ed1a0b78e51b05b5ba3e9d73db4807e7587b786d99d` |
| `worker_auto_mini_refill.js` | `3cca3a31c8ce2c82b8ee337de1a1e06f21064b494284c2541a15c92d133fec14` |
