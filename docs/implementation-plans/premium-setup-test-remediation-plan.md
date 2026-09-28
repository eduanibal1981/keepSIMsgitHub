# Implementation plan: Premium SIM setup, refill pricing and notifications

Prepared 15 September 2026 for an AI implementation executor.

## 1. Objective and evidence

Fix the confirmed defects from the premium setup test, verify the uncertain findings, and preserve the successful setup and wallet behavior.

Repository: C:/Users/abdal/Work/KeepSIMs/keep_sims

Read these before implementation:
- [Test report](C:/Users/abdal/Work/KeepSIMs/keep_sims/test-results/premium-setup-20260915/REPORT.md)
- [Recorded MCP evidence](C:/Users/abdal/Work/KeepSIMs/keep_sims/test-results/premium-setup-20260915/evidence.json)

Observed baseline:
- Premium setup succeeded through the deployed authenticated database functions and supplier worker.
- Wallet decreased from $1,883.44 to $1,871.26: $7.18 refill plus $5 annual fee, each charged once.
- The first refill hold and debit metadata correctly use setup_refill.
- The generated future refill is inconsistent: amount $7.40, base_cost_usd $7.18, max_authorized_usd $7.18.
- OneSignal returned invalid_aliases for this user; FCM fallback reported 2/3 devices.
- WhatsApp is globally disabled and its credentials are marked missing. Email and Telegram are disabled for the test user.
- The line has health_score=50 and null next_topup_due / validity_expires_at despite successful setup and two active schedules.

The original test did not exercise Flutter screens, a new HTTP authentication session, scheduled supplier execution, or failure/refund flows. Do not present those as passing tests.

## 2. Priorities and scope

| Priority | Work item | Evidence status |
| --- | --- | --- |
| P1 | Correct premium schedule pricing and generated execution pricing | Confirmed database defect |
| P1 | Diagnose and repair OneSignal identity registration; improve FCM failure handling | Delivery failure confirmed; precise OneSignal cause unproven |
| P2 | Show Setup refill consistently in history and new ledger descriptions | Accounting rename works; presentation is incomplete |
| P2 | Show notification channel availability separately from user preference | Configuration mismatch confirmed; screen behavior needs verification |
| P2 | Make health and due-date behavior consistent | Stored values observed; user-facing impact needs verification |
| P2 | Align SIM status default with its check constraint | Database schema inconsistency confirmed |

Do not treat a standard account profile with a premium SIM as a bug: line-specific notification dispatch already resolves the line tier first. Do not automatically enable disabled channels or upgrade the account.

## 3. Establish the current implementation baseline

1. Read applicable AGENTS.md and Supabase skill instructions. Inspect git status and preserve all existing user changes.
2. Re-read live function definitions, table defaults, constraints, triggers and grants through Supabase MCP. The working tree already contained unfinished refill changes and multiple same-prefix migration files; never overwrite those blindly.
3. Identify the source checkout and deployed version of the running refill workers. Some existing tests reference ../backend-sync-wt; establish which checkout owns deployment before editing or publishing.
4. Compare the recorded evidence with current records. Other work may have changed them since the test.
5. Use the repository's schema workflow. For its current imperative migrations, create new uniquely timestamped migrations using the installed CLI's supported migration command. Do not edit an already-applied migration as the deployment strategy.
6. Verify relevant current Supabase/OneSignal/Firebase documentation and installed SDK APIs before implementation.
7. Keep implementation and verification in separate, reviewable changes: pricing, notification lifecycle, presentation, derived state/default repair.

## 4. P1 — Fix the price copied from setup into the refill schedule

### Code and database entry points

- capture_sim_setup_holds and finalize_sim_setup_order:
  [setup migration](C:/Users/abdal/Work/KeepSIMs/keep_sims/supabase/migrations/20260909010000_fix_standard_line_setup_and_sim_line_binding.sql)
- trg_fn_sync_custom_refill_queue:
  [queue synchronization](C:/Users/abdal/Work/KeepSIMs/keep_sims/supabase/migrations/20260915110000_preserve_approved_executions_in_queue_sync.sql)
- calculate_topup_fees:
  [fee/cap migration](C:/Users/abdal/Work/KeepSIMs/keep_sims/supabase/migrations/20260915100000_align_max_authorized_usd_in_calculate_topup_fees.sql)
- quote_premium_breakdown, carrier_refill_offer, resolve_app_fee and resolve_line_entitlement: inspect their latest live definitions.
- [instant worker](C:/Users/abdal/Work/KeepSIMs/keep_sims/servers/worker_instant_refill.js)
- [mini-refill worker](C:/Users/abdal/Work/KeepSIMs/keep_sims/servers/worker_auto_mini_refill.js)
- [approval regression tests](C:/Users/abdal/Work/KeepSIMs/keep_sims/test/refill_approval_backend.test.cjs)

### Root cause

Setup first_refill_cost_usd is the customer total, including the app fee. Finalization copies it into scheduled_topups.amount without a supplier base or fee. Queue synchronization falls back to COALESCE(NEW.base_cost_usd, NEW.amount), so a retail total becomes the supplier base. calculate_topup_fees then adds another fee.

Setup used Ding XCSASA72721, but the schedule copied the carrier-rule Zendit SKU STC_SA_001_USD. Supplier changes are allowed, but product, supplier and price must be resolved together.

### Required implementation

1. Establish one explicit pricing contract across quotation, schedules, executions, approval and settlement:
   - base_cost_usd: supplier cost, retaining required decimal precision.
   - app_fee_usd: fee from the existing tier-aware rule.
   - amount: customer total rounded according to the existing USD accounting rules.
   - max_authorized_usd: customer-approved maximum; never increased by migration, normalization or fee calculation.
   - preferred_provider, offer_id and offer_value: one coherent route snapshot.
   - pricing_tier and fee_rule_version where supported.
   - intent_kind, target_local_value and target_local_currency: resolve from canonical offer data. Do not interpret offer_value as a currency amount without checking its supplier semantics.
2. Populate the premium schedule from a coherent trusted quote or successful execution snapshot. A successful execution can seed an initial estimate, but it is not a permanently fresh supplier quote.
3. For the recorded unchanged Ding route, the fixture must yield base $6.9701, fee $0.21 and customer total $7.18. These are regression fixture values, not hardcoded production prices.
4. If the next refill chooses another route, obtain that route's price and preserve the customer's existing cap. Higher cost must enter the existing approval flow rather than silently enlarging the cap.
5. Change queue synchronization so missing base cost does not cause an already-inclusive amount to be marked up again. Audit every schedule writer, including custom refills, before removing any fallback that legitimately supports legacy base-only amounts.
6. Preserve the existing fee trigger or consolidate calculation into an existing shared helper; there must be one authoritative formula and no second fee application.
7. Ensure no-op and cap-only schedule changes remain idempotent. Preserve approved quote associations and already due or in-flight executions.
8. Keep scheduled customer approval distinct from display estimates. Missing pricing must be reported as unavailable or awaiting refresh using a supported state; do not invent a price, silently authorize it, or enqueue an unpriced purchase.
9. Preserve setup capture idempotency: worker capture followed by finalization must still produce one refill debit and one plan debit.

### Repair existing affected rows

- First produce a read-only candidate list with old/new prices, source of supplier price, schedule ID, execution ID and authorization cap.
- Scope automatic repair to provable setup-generated pricing errors on unsubmitted future work.
- Lock/recheck schedule and execution state during repair so a worker claim cannot race the update.
- Reconcile schedule and pending execution together; account for synchronization triggers so repair creates no duplicate queue entry.
- Do not edit successful executions, captured holds, historical ledger amounts, in-flight transactions, or existing approved quote snapshots.
- Preserve execution dates and customer limits. Rows with uncertain cost provenance or stale catalog data require fresh quoting, not a guessed division of the total.
- Make the repair idempotent and retain before/after evidence.

### Acceptance tests

- Fresh premium setup produces a coherent schedule and one future refill with no additional markup.
- Replaying setup finalization produces no additional debits, payments, schedules or queue entries.
- Existing explicit low cap remains unchanged and blocks a higher supplier price.
- Missing or stale supplier pricing produces no purchase.
- Mini, custom and standalone instant refills still calculate their existing fees correctly.
- Cap-only approval updates preserve execution identity and approved quote.
- Concurrent schedule repair and worker claim cannot create or settle two purchases.
- Setup failure releases the appropriate holds without activating unpaid protection.
- Wallet accounting invariants pass.

## 5. P1 — Repair notification identity lifecycle and fallback diagnostics

### Files

- [application initialization](C:/Users/abdal/Work/KeepSIMs/keep_sims/lib/main.dart)
- [authentication controller](C:/Users/abdal/Work/KeepSIMs/keep_sims/lib/features/auth/controller/auth_controller.dart)
- [device token registration](C:/Users/abdal/Work/KeepSIMs/keep_sims/lib/features/notifications/data/repositories/device_token_repository.dart)
- [notification dispatcher](C:/Users/abdal/Work/KeepSIMs/keep_sims/supabase/functions/dispatch-alert/index.ts)

### Diagnose before changing provider routing

OneSignal.initialize, login(profile.id) and logout already exist. Local app and dispatcher App IDs match. Confirm the deployed App ID/key pairing, installed build, notification permission, push subscription opt-in, subscription ID and actual external-ID association. Do not infer that the key is wrong solely from invalid_aliases.

Official guidance calls for identifying the user after sign-in/session restoration and on account changes, and observing asynchronously available identity/subscription state. Use the installed Flutter SDK's equivalent APIs. [OneSignal reference](https://documentation.onesignal.com/docs/en/mobile-sdk-reference)

### Required implementation

1. Give token registration an explicit current-user lifecycle. Current callbacks close over the userId passed when observers were first attached; prevent stale-user writes after logout or account switching.
2. Store observer callbacks so they can be removed on disposal. Currently only the FCM subscription is cancelled.
3. Handle provider disposal and asynchronous registration races: check the current authenticated identity before committing an upsert; ignore late completions from an old identity.
4. Fix sign-out ordering as needed. Current code attempts to clear device rows after repo.signOut(), when row-level permissions may no longer authorize the update. Clear the correct user's current device while authorized, detach registration listeners, and complete logout without indefinite blocking.
5. Keep account switching safe even if cleanup fails. Evaluate existing ownership constraints so one installation's active token cannot keep receiving the previous user's private alerts.
6. Replace swallowed registration errors with sanitized diagnostics and bounded retry at appropriate lifecycle events. Never log raw tokens or credentials.
7. Preserve the current OneSignal fallback distinction: a valid accepted notification ID without errors is not a failure merely because the immediate recipients field is zero. An explicit invalid_aliases error is a failure.
8. In sendFcm, deduplicate tokens and retain device identifiers for diagnostics. Parse structured FCM errors and include failure counts/reasons even when some devices succeed.
9. Retire only conclusively invalid tokens and use a compare-and-clear check against the exact token sent, so a concurrent refreshed token is not erased. UNREGISTERED is terminal; INVALID_ARGUMENT requires confirming the message payload is valid. Retain tokens on transient/network/provider failures. [Firebase token management](https://firebase.google.com/docs/cloud-messaging/manage-tokens), [error reference](https://firebase.google.com/docs/cloud-messaging/error-codes)
10. Distinguish provider acceptance from confirmed handset receipt in logs and reports. Avoid claiming that every device received an alert when only some sends succeeded.

### Acceptance tests

- Fresh login, restored session, delayed permission grant and token rotation bind the correct user.
- Login A → logout → login B does not re-register A or deliver A's new alerts to B's active session.
- Disposal removes observers; late callbacks do not write.
- OneSignal invalid_aliases invokes FCM fallback; accepted response without errors does not spuriously invoke fallback.
- Partial FCM success retains per-device errors; invalid token retirement preserves concurrently refreshed tokens.
- A physical or emulator device test verifies one visible notification and the expected destination after tapping it. If platform access is unavailable, mark that test blocked.

## 6. P2 — Complete Setup refill presentation

### Files

- [execution model](C:/Users/abdal/Work/KeepSIMs/keep_sims/lib/features/scheduled_topups/model/topup_execution_model.dart)
- [execution history](C:/Users/abdal/Work/KeepSIMs/keep_sims/lib/features/sim_lines/presentation/screens/sim_line_executions_history_screen.dart)
- [wallet UI](C:/Users/abdal/Work/KeepSIMs/keep_sims/lib/features/wallet/ui/wallet_screen.dart)
- instant worker, execution repository projections, activity rendering and localization resources.

### Implementation

1. Keep the machine routing contract: execution_type=refill_instant and funding_kind=setup_hold. The setup_refill value remains the wallet hold classification.
2. Add optional fundingKind to the execution model and ensure query projections include it. Regenerate Freezed/JSON files through the repository's generation workflow.
3. Use one display helper for Setup refill, Instant refill and Scheduled refill. Prefer funding_kind=setup_hold for execution classification; use metadata.order_type=setup_refill for wallet entries.
4. Give new setup debit descriptions a Setup refill label in the actual deployed worker settlement path.
5. Include funding_kind in new activity metadata where helpful. Support older entries using the linked execution/hold when necessary.
6. Do not rewrite settled amounts, transaction references or historical accounting categories simply to change a label.
7. Localize the display label. Database enum values should not appear as untranslated user-facing text.

### Acceptance

New setup appears as Setup refill in history and wallet; old rows remain readable; ordinary instant/scheduled labels remain correct; worker claiming and settlement are unchanged.

## 7. P2 — Make channel availability understandable

### Files and data

- [notification settings screen](C:/Users/abdal/Work/KeepSIMs/keep_sims/lib/features/notifications/presentation/screens/notification_settings_screen.dart)
- Its controllers/repository and ChannelConfigCard implementation.
- notification_channel_catalog, notification_channels, alert_settings and the dispatch trigger.

### Implementation

1. Verify current UI behavior. Build an effective availability model that combines user preference, operator availability, required recipient setup, category choices and existing entitlement policy.
2. Show human-readable states such as Enabled, Off, Setup required and Temporarily unavailable. A saved WhatsApp preference must not imply that the disabled service can deliver.
3. Preserve saved user preferences when a provider is temporarily disabled. Disable unavailable actions or clearly explain their effect.
4. Expose only safe catalog fields to clients. Do not send secret identifiers, credentials or operator-only notes to the app.
5. Keep account-level and line-level entitlement contexts explicit. Verify the standard-profile/premium-line case without changing the account's subscription.
6. Do not globally enable WhatsApp as a code fix. Provider credential provisioning and an actual delivery check are separate operator work.
7. Email/Telegram being off and Webhook being unconfigured are valid states, not failed deliveries.

### Acceptance

Global disable overrides user enable; recipient setup requirements are visible; disabled choices remain saved; premium line alerts receive the correct eligible channel set; unavailable channels are never described as successfully delivered.

## 8. P2 — Reconcile health and timing

### Entry points

- [server health calculation](C:/Users/abdal/Work/KeepSIMs/keep_sims/supabase/migrations/20260914040000_update_health_score_four_pillars.sql)
- [client health calculation](C:/Users/abdal/Work/KeepSIMs/keep_sims/lib/features/sim_lines/domain/sim_line_health.dart)
- capture_sim_setup_holds, schedule mutation triggers, SIM cards/detail screens and reschedule/reset helpers.

### Investigation and implementation

1. Compare stored health with a fresh server calculation after both schedules exist. Finalization updates the SIM before inserting schedules, which may explain the stored 50; confirm the deployed trigger ordering.
2. Map each consumer of health_score, next_topup_due, validity_expires_at, execution_time and executed_at.
3. Keep distinct concepts distinct:
   - plan_expires_at: paid protection expiry.
   - next_execution_at/execution_time: scheduled refill time.
   - validity_expires_at: carrier validity, only when supported by actual evidence.
4. Recompute cached health after schedule creation/activation/pause/delete if stored health is consumed. Use a targeted server helper/trigger without recursive update loops; cover time-based aging through the existing periodic process or derived reads.
5. Align server/client pillar rules and active schedule interpretation. Do not grant verification points solely because a draft row has status=active if that row is still explicitly unverified. Verify this against the intended four-pillar behavior before changing both implementations.
6. Populate next_topup_due only after confirming its intended meaning in existing consumers. Prefer a shared derived value if duplicating it would create another stale cache.
7. Leave unknown carrier validity null and display Unknown. Do not copy the plan expiry or refill date into a field that claims confirmed carrier validity.
8. Inspect pending execution date rendering. History currently prefers executedAt over executionTime, and the recorded pending execution has executed_at set at creation. Use execution_time for pending work; only show a completed/attempted timestamp with the appropriate status.

### Acceptance

Immediately after successful setup, all relevant screens and the server use the same health definition. Pausing a schedule updates the relevant pillar. Draft/unverified lines are not shown as carrier-verified. Pending refill history shows its scheduled date, and unknown validity remains honest.

## 9. P2 — Repair the invalid SIM status default

Observed default: status='unverified'. Allowed values: active, paused, expired, grace_period, deactivated. The app explicitly sends active and separately tracks verification_status / carrier_status.

1. Verify the current default and all insert callers.
2. In a new migration, align the default with the established lifecycle, preferably the app's current active value if consumer checks confirm that active is not treated as verified.
3. Keep verification_status=unverified and carrier_status=pending as separate defaults.
4. Do not widen the status constraint with another lifecycle state just to accommodate an accidental default.
5. Test a minimal valid insert omitting status; it must satisfy constraints without granting verified/premium entitlements.

This defect caused a test-harness insert failure; it was not an observed failure of the app's explicit insert.

## 10. Validation and release sequence

1. Reproduce the pricing fixture with deterministic supplier responses.
2. Implement pricing functions, queue propagation and narrowly scoped data repair; test wallet invariants and approval preservation.
3. Implement push lifecycle and dispatcher diagnostics; test account switching and partial delivery.
4. Add Setup refill labels, channel availability and verified health/date fixes.
5. Run focused SQL, worker and Flutter tests plus affected static analysis/code generation. Use existing test conventions; inspect scripts before running anything capable of charging a wallet.
6. Exercise migrations in an isolated local database or approved test environment. Never disable triggers or cron globally on the shared database to make tests safe.
7. Review function grants, ownership checks and Supabase advisors after database changes. Client fixes must not require broader writes to wallet or verification fields.
8. Deploy compatible database additions before client code that needs them. Deploy the correct worker checkout and Edge Function revision; record revision identifiers.
9. Apply the reviewed repair under state checks and compare row counts and wallet totals before/after. Historical monetary totals must remain unchanged.
10. Run read-only post-deployment checks against the recorded test line and verify no duplicate pending executions.
11. Complete Flutter Add SIM, wallet/history, notification settings and notification tap checks. Preserve screenshots and correlate them with database IDs.
12. Treat any new paid supplier test as a separate step. The prior request to execute another scheduled refill was rejected by automatic approval review and has not been approved by the user. Do not execute it or raise its cap based on this plan. Prepare deterministic tests and the exact proposed live test first.

### Rollback

Keep previous function/worker/Edge versions and a record of changed unsubmitted rows. Roll back only compatible code/schema changes and rows still unsubmitted after rechecking state. Do not restore a known duplicate-fee path as an automatic response to a release failure; use the existing supported pause mechanism for affected new work if necessary. Never reverse completed provider transactions or ledger captures with direct SQL.

## 11. Executor completion report

Return:
- Each finding marked fixed, disproven, or blocked, with evidence.
- Changed source files and applied migration names.
- Focused test commands and results.
- Before/after pricing and exact unchanged authorization caps.
- Device notification acceptance/receipt evidence, with failures distinguished.
- Data repair row counts and proof of unchanged historical wallet totals.
- Deployed revision IDs, remaining configuration work and any unexecuted tests.

Reference test IDs:
- User: 8a07a25b-a49b-4ec3-a56c-cfe7f7ea0c0e
- SIM: da7eb107-1a84-4a87-a563-4aacba4ed86f
- Setup: edd42ee5-27ab-49ca-ad45-bdcac4dd44a6
- Successful refill: eaa197f7-c3a9-4207-84d9-b25fcc401199
- Pending refill: c3dad031-c9dc-48d0-8d69-f5cae8fe6c97
- Notification: 8be45b0c-aa6d-4861-8f2b-f1132f140d5e

These IDs are investigation references, not IDs to hardcode into application logic or general schema migrations.

