# Notification executor review — 1 October 2026

## Verdict

**Not production ready. Hold release and repair the live notification trigger first.** The executor partially fixed the original settings problem, but did not complete the production-readiness plan. More seriously, the changed trigger is already live and references a column absent from the live outbox table. Notification inserts that reach its enqueue branch will fail instead of entering the delivery queue.

This was a review of local customer/Supabase changes, sibling Admin and authoritative worker source, deployed Edge Function source, live catalog/schema/policies/trigger definitions/migration history, cron metadata, and existing tests. No production data was inserted or changed, no provider message was sent, and no worker was restarted. Only this review document was added.

## Findings

### 1. P0 — Live trigger cannot enqueue eligible notifications

`supabase/migrations/20261001030000_standard_whatsapp_catalog_and_entitlement_fix.sql:128-141` inserts a `sim_line_id` column into `notification_dispatch_jobs`. The live table has no such column; its line association is in `payload`. The deployed `trg_fn_dispatch_notification()` contains this exact new INSERT.

A non-executing SQL planning check confirmed:

```text
EXPLAIN (FORMAT JSON) INSERT INTO public.notification_dispatch_jobs
  (notification_id,user_id,sim_line_id,payload,state) ...

ERROR 42703: column "sim_line_id" of relation
"notification_dispatch_jobs" does not exist
```

`EXPLAIN` was used without `ANALYZE`; no row was inserted and no notification/send was attempted. This failure occurs outside the inner exception handler, so it aborts notification creation when any enabled channel is selected. It affects Push, Email, Telegram and WhatsApp, not only paid alerts. Existing complete jobs do not prove new events can enqueue.

The same migration also introduces incompatible inline dispatch at lines 146–163: nonexistent `public.system_secrets`, local-container address `http://kong:8000`, wrong authentication header `X-Internal-Secret`, and a `{job_id,source}` body unsupported by the deployed dispatcher. That inner error is swallowed. The current architecture expects durable enqueue, then a leased outbox drain; adding unleased direct sends can create a second send path if these other mistakes are subsequently patched.

**Required repair:** restore the actual durable outbox INSERT contract, preserve the full event payload including `target`, and remove this unrelated inline dispatch. Use a forward migration, prove enqueue against the actual schema with an isolated provider-disabled fixture, and verify worker claim/dispatch afterward. The live catalog/trigger edits are not represented in migration history: there is no `20261001030000` entry. Reconcile deployment provenance and history after comparing definitions; do not blindly rerun the faulty migration.

### 2. P1 — Correct expiry checks remain local; production still uses carrier expiry

The new trigger and local router check `plan_expires_at`, which is the right direction. However:

- Live `dispatch-alert` is still **v33**, with its bundled router selecting and gating on `validity_expires_at` at lines 78–86.
- Live `process-alert-outbox` is still **v4**, with carrier-validity gating at lines 62 and 106–107.
- Live `waba-webhook` is still **v3**.

An active Standard/Premium subscription can therefore still lose external warnings when its SIM's carrier validity expires. The latest trigger changes do not update the already deployed Edge Function bundles.

**Required repair:** test and deploy compatible function bundles after repairing the database contract; prove active-plan/expired-carrier and expired-plan/valid-carrier cases. Deploying the shared router requires redeploying each function that bundles it. Record versions/hashes and test evidence.

### 3. P1 — Entitlement decisions remain inconsistent between layers

The new trigger and local WhatsApp router prefer `plan_type`; local `process-alert-outbox/index.ts:104-105` still prefers `protection_tier`. A line with a paid canonical plan and a stale Basic legacy tier can enqueue correctly and then lose paid channels in the outbox. Conversely, a stale paid legacy tier can affect eligibility differently in the opposite direction.

The customer UI accepts either line tier and even uses account tier when determining its “Active for your eligible … SIM lines” hint (`notification_settings_screen.dart:1243-1254`). Email still defaults to Standard and borrows account tier (`dispatch-alert/index.ts:495-517`). Null plan expiry is treated as unexpired without the audited legacy-paid-evidence policy required by the plan. No shared notification entitlement/capability resolver was introduced.

**Required repair:** reuse one owner-checked, trusted server entitlement rule for enqueue, outbox, dispatcher and router. Handle inconsistent/unknown/legacy rows explicitly and prevent account/another-line privilege from authorizing a Basic line. Drive UI hints from the same owner-scoped capability contract. Include mismatched-field and null-expiry fixtures.

### 4. P1 — External notification creation and binding authorization are unfinished

Live notification INSERT/UPDATE policies still validate only the row's `user_id` and suspension. The only notification trigger is dispatch. Its line lookup (`new migration:54`) does not check that the referenced line belongs to the notification user. The service-role outbox/router also look up the supplied line without an owner predicate.

Customer repository methods still insert client-selected title/body/category/line IDs directly. The broad owner policy on channel `config` still allows writes to binding data; no narrow binding/config contract was added.

**Required repair:** enforce notification-to-line ownership before accepting an event, restrict external-send-producing events to validated/rate-limited server contracts, protect event/delivery fields on update, and allow Telegram binding changes only through the validated bot-link contract. Keep read/mark-read/delete and legitimate configuration working. Verify ordinary-user/foreign-line/direct-binding denial in an isolated database. No exploit was attempted during this review.

### 5. P1 — Channel failures still become complete jobs without safe retry

The deployed dispatcher persists failed/skipped results and returns `success:true` (`dispatch-alert/index.ts:710`). The outbox marks the parent job complete when that flag is true (`process-alert-outbox/index.ts:168-170`). An Email/Telegram/WhatsApp failure can therefore be permanently treated as a handled job without the planned per-channel retry/reconciliation.

**Required repair:** persist structured per-channel/per-device attempts and outcomes; retry only definitively failed targets with stable idempotency keys and bounds. Do not resend accepted channels or replay unknown outcomes. Show partial failures independently of logical-job completion. This phase of the plan was not implemented.

### 6. P1 — WhatsApp management and receipt deployment remain incomplete

- The live function inventory still lacks `send-whatsapp-alert`, which Admin probe/QR/logout/test actions invoke.
- Its local implementation still reads `provider_type`, top-level `endpoint_url` and `metadata`, inconsistent with live `provider_kind` and `connection_metadata`.
- Admin still has direct-worker probe/global-host fallback in `WhatsappManagementRepository.probeProfile()`.
- Live Meta webhook v3 does not contain the local routed-attempt receipt handling. Both old deployed and local code skip signature validation when the app secret is missing; actual production secret presence was not inspected.
- The authoritative local Baileys worker PATCHes `sent_at` (`backend-sync-wt/server_baileys.js:305`), absent from the live `whatsapp_message_attempts` schema. Its receipt sync remains fire-and-forget. The running VM version was not inspected, so VM exposure to that exact source mismatch is unverified.

**Required repair:** align/deploy a secured Admin management contract; remove profile/global fallback; require verified webhook signatures; deploy and test receipt handlers; align worker/schema and persist failed receipt synchronization for reconciliation. Prove both providers with authorized controlled identities before declaring delivery validated.

### 7. P1 — WhatsApp schedule/quota/readiness/retry work was not completed

The router still:

- Calls `.maybeSingle()` across all schedules for a line (`whatsapp_router.ts:130-134`), despite notify and refill schedules coexisting. It ignores the multiple-row error and then lacks the intended cycle/suppression state.
- Checks `schedule_type === 'refill'`, while current provisioning uses `refill_mini` and `refill_custom`.
- Reads quota then updates a boolean after sending without an atomic cycle reservation.
- Loads profile `ready_state` and observed/expected sender fields without enforcing them.
- Reassigns a failed attempt to the currently selected route/profile without an atomic failed-state claim, violating fixed-provider retry policy.

**Required repair:** explicit schedule selection and real refill health, atomic cycle reservation, sender/readiness checks, and atomic retries on the original provider snapshot. Preserve the two providers and Admin country-selection design.

### 8. P1 — Saving can report success after persistence fails; old destinations can win

`NotificationChannelsController.updateChannelConfig()` catches and hides write errors at lines 259–260. The screen awaits it and unconditionally displays success (`notification_settings_screen.dart:1154-1166`). The toggle has the same hidden-error pattern. The new “Preference saved” hint is therefore not trustworthy.

Destination canonicalization is also unfinished: UI updates `config.phone`, retaining a prior `config.phone_number`; dispatcher line 607 prefers `phone_number`. A user's new WhatsApp recipient can be ignored in favor of the old one. Email has the equivalent `email_address`/`email` precedence issue.

**Required repair:** acknowledge persistence errors, preserve drafts, and show success only after the server confirms the write. Migrate legacy destination keys into one validated canonical field and remove stale alternatives on save.

### 9. P2 — Configuration during platform pause and hints do not match the contract

The subscription lock is removed, but the new UI still forces the switch off and disables editing during platform pause (`notification_settings_screen.dart:1274,1380,1401`). The plan explicitly required retaining displayed saved preference and allowing configuration during pause. New paid-channel copy is hard-coded English, and the “Active …” hint does not consider recipient setup, route readiness or the user's disabled switch.

**Required repair:** separate opt-in, plan eligibility, setup and platform delivery availability. Keep the saved preference visible/configurable during pause and localize the new copy.

## Plan completion assessment

| Plan area | Review result |
| --- | --- |
| Remove subscription-gated UI switch | Implemented locally for globally enabled channels; pause/error/localization gaps remain |
| Standard/Premium WhatsApp catalog | Live WhatsApp minimum tier is now Standard |
| Subscription versus carrier expiry | Trigger/local edits made; deployed outbox/router remain old |
| Canonical server entitlement/capabilities | Not completed |
| Secure server-owned event/binding contracts | Not completed |
| Durable per-channel attempts/partial retry | Not completed |
| Both country-selected WhatsApp providers | Preserved; 21 Disabled, 2 Baileys, 1 Meta routes remain |
| Management, receipt, readiness and cycle fixes | Not completed |
| Scheduler/digest/catch-up/operational phases | No completion evidence; original gaps remain |
| Migration/deployment provenance | New live trigger/catalog absent from migration history; function deployment incomplete |
| End-to-end production acceptance | Not proven |

## Verification and limits

- Read-only live inspection and non-executing `EXPLAIN` confirm the P0 contract error.
- Live deployed source confirms older carrier-expiry gates, incomplete receipts and completion semantics.
- Current local push/quiet-hours tests: **12/12 passed**. Authoritative durable WhatsApp queue tests: **4/4 passed**. These are the same existing tests; they do not cover the new migration or the full production acceptance matrix.
- Targeted Flutter analysis and five targeted Dart/Flutter test files were attempted, but both commands produced no output and did not complete during the bounded review; they were stopped. Flutter validation is **unverified**, not passed.
- No customer data writes, real provider probes/sends, or VM changes were made. Running VM hashes, installed mobile/Admin releases, Meta template approvals and authorized recipient receipts remain unverified.
- SQL cron status and 189 existing complete jobs cannot validate enqueue after the changed trigger or recipient delivery. SQL cron enqueue success is not an HTTP/provider receipt.

## Repair order for the executor

1. **Immediately repair the live P0 durable-enqueue contract** and remove the incompatible inline dispatch. Verify without contacting customers; reconcile migration history from actual definitions.
2. Finish one trusted, owner-checked entitlement/event contract and test security denial and expiry combinations.
3. Fix settings persistence/destination handling; deploy matching dispatcher/outbox/router bundles.
4. Finish per-channel attempts, partial-failure retry and WhatsApp schedule/quota/readiness/retry handling.
5. Align Admin management, signed Meta receipts and durable Baileys receipt synchronization; validate each selected provider.
6. Complete scheduler/digest/operations acceptance, Flutter builds and controlled end-to-end evidence. Report remaining external setup honestly.

Do not mark the production-readiness plan complete after only the settings/catalog fix. Use the original plan's verification matrix and release gates for acceptance.
