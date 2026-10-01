# Notification executor re-review — 1 October 2026

## Verdict

**The emergency enqueue failure is repaired, but the whole notification system is still not production ready.** The original Standard WhatsApp settings problem has been addressed in the catalog and customer source. Several first-review blockers are closed. Delivery failure handling, Meta authentication, Admin management, sender identity, retries and cycle concurrency still need work before release.

This report supersedes the first review's *current-state verdict*; the earlier report remains a historical record. This was a read-only review of deployed Supabase functions/schema/policies and local customer, Admin and authoritative worker source. Only this report and an offline reproduction script were added. No customer event was inserted, no real provider message was sent, no route was changed, and no worker was deployed or restarted.

## Fixes verified

| Earlier issue | Current evidence | Status |
| --- | --- | --- |
| Live trigger referenced absent outbox `sim_line_id` column | Live trigger now inserts only `(notification_id,user_id,payload)` with the line ID inside the payload. Non-executing `EXPLAIN` for this contract succeeds. | Closed at schema/SQL planning level; enqueue-to-receipt fixture still needed. |
| Incompatible inline HTTP dispatch | Repair trigger has no inline HTTP block and restores `target` in the payload. | Closed. |
| WhatsApp catalog required Premium | Live WhatsApp and Email catalog minimums are Standard. | Closed. |
| Carrier validity confused with subscription expiry | Deployed outbox, Email gate and bundled WhatsApp router use `plan_expires_at`, canonical `plan_type` first and line ownership. | Closed for these reviewed paths. |
| Email defaulted to paid/account tier | Email starts at Basic and requires the owned originating line. | Closed for line-specific alerts. |
| Function deployment gaps | Live inventory is `dispatch-alert` v34, `process-alert-outbox` v5, `waba-webhook` v4 and newly present `send-whatsapp-alert` v1. Relevant remaining defects below are also present in these deployed sources. | Deployment gap closed; endpoint behavior remains defective. |
| Worker/Meta wrote missing `sent_at` | Live `whatsapp_message_attempts.sent_at` exists; Meta handler writes it. | Schema mismatch closed; worker runtime/real receipt not verified. |
| Settings locked/paused preference switches | Paid channel controls remain editable and show the Standard/Premium label. A global pause preserves editable preferences. | Fixed in customer source. |
| Swallowed settings failures and stale recipient keys | Controller writes rethrow; UI rolls back/shows failure. Saves write both Email and phone key variants consistently. | Fixed for new saves in customer source. |
| Multiple schedule rows and refill type mismatch | Router loads a list and recognizes `refill`, `refill_mini`, `refill_custom`. | Partial: concurrency and actual refill health remain open. |
| Preserve country-selected providers | Live routes remain 24 total: 21 Disabled, 2 Baileys, 1 Meta. Both adapters and Admin route/profile design remain. | Preserved. Stored health labels are not fresh delivery evidence. |

The customer app itself has not been built, installed or exercised on a device during this review. Source fixes do not prove a released app contains them.

## Remaining release blockers

### 1. P1 — Channel failure still completes the dispatch job

[Dispatcher return](C:/Users/abdal/Work/KeepSIMs/keep_sims/supabase/functions/dispatch-alert/index.ts:703) returns HTTP 200 and `success:true` after recording failed channels. [Outbox completion](C:/Users/abdal/Work/KeepSIMs/keep_sims/supabase/functions/process-alert-outbox/index.ts:167) then completes the logical job solely from that response. There is no channel-level retry contract for definitive failures.

**Reproduced offline:** Telegram HTTP 503 creates a `failed` delivery row, returns `success:true`, and the actual outbox `processJob()` marks the job `complete`. The same structural problem covers rejected Email/WhatsApp/Webhook sends and failed push targets. A successfully handled request is not evidence that its selected channels succeeded.

**Repair:** return and persist structured outcomes per channel/target. Retry only definitively failed, safe targets with bounded backoff; retain accepted targets; quarantine ambiguous sends. Do not merely return a generic failure and replay every channel, which can duplicate channels already accepted.

### 2. P1 — Meta webhook still accepts unsigned commands when secret resolution fails

[Webhook signature branch](C:/Users/abdal/Work/KeepSIMs/keep_sims/supabase/functions/waba-webhook/index.ts:114) proceeds when neither the global app secret nor the single-profile fallback resolves. The deployed v4 logs that it is skipping signature verification and processes inbound commands/status updates anyway. The fallback uses `.maybeSingle()` across all Meta profiles, so adding a second profile can also make lookup fail.

**Reproduced offline:** an unsigned POST with no configured app secret reached `handle_inbound_command()` and returned 200. The live Meta profile has no `app_secret_vault_id`; the actual global environment secret was not inspected. This proves a deployed unsafe fallback, not that an unsigned production request was tested or accepted.

**Repair:** reject missing/failed secret resolution before processing commands or receipts. Resolve and verify the receiving provider profile/app identity, handle multiple profiles deliberately, and reject unknown sender IDs. Require valid signatures for every accepted Meta POST.

### 3. P1 — Newly deployed Admin endpoint checks the wrong authentication context

[Management authentication](C:/Users/abdal/Work/KeepSIMs/keep_sims/supabase/functions/send-whatsapp-alert/index.ts:35) creates a service-role client. `auth.getUser(jwt)` verifies the submitted user, but the subsequent `is_power_user(user_id)` RPC still uses that service client without forwarding the user's Authorization header. The live RPC ignores its `user_id` argument and reads **the RPC caller's JWT app_metadata**. Consequently a normal service-role JWT does not carry the verified administrator's power-user claim, and the endpoint rejects legitimate Admin actions with 403.

**Reproduced offline against the live RPC's claim semantics:** a verified user with `app_metadata.is_power_user=true` still gets 403 from the management handler when the RPC uses service-role claims. This is source/contract evidence; no real administrator session was used. Supabase distinguishes caller-scoped and service-role clients in its [Edge Function authentication guidance](https://supabase.com/docs/guides/functions/auth); [getUser(jwt)](https://supabase.com/docs/reference/javascript/auth-getuser) retrieves an authenticated user, rather than configuring subsequent database requests with that JWT.

There is a second independent management defect after authorization is repaired. [Secret lookup](C:/Users/abdal/Work/KeepSIMs/keep_sims/supabase/functions/send-whatsapp-alert/index.ts:81) queries `vault.decrypted_secrets` for `whatsapp_profile_<id>_secret`. [Admin profile saving](C:/Users/abdal/Work/KeepSIMs/keep_sims/supabase/migrations/20260926100000_whatsapp_country_routing.sql:255) stores `wa_meta_token_<id>` and `wa_baileys_key_<id>`. Management also uses different environment fallback names from the send adapters. Vault-backed profile probes/QR/logout can therefore use missing or unrelated credentials.

[Admin probe fallback](C:/Users/abdal/Work/KeepSIMs/keep_sims_admin/lib/features/whatsapp_management/repository/whatsapp_management_repository.dart:265) still catches endpoint errors and probes a worker directly, or treats stored Meta readiness as a new health result. This can hide the broken endpoint.

**Repair:** authorize with verified server-owned caller claims or a separately caller-scoped client; retain the service client for permitted operations. Share the profile credential resolver with the adapters, check RPC errors and remove misleading direct/global probe fallbacks. Prove Admin probe/QR/logout/test against the selected profile with both authorized and unauthorized callers.

### 4. P1 — Retries can switch providers and concurrent retries can duplicate Meta sends

[Failed retry handling](C:/Users/abdal/Work/KeepSIMs/keep_sims/supabase/functions/_shared/whatsapp_router.ts:300) reloads the current country route/profile and overwrites the original attempt snapshot. Its update filters only by attempt ID, without an atomic failed-state claim or lease. Two callers that read the same failed row can both send. A route change can also move the same attempt from Baileys to Meta or vice versa, contrary to the required selected-provider retry behavior.

**Reproduced offline:** two calls for the same failed idempotency key both issued Meta sends and both overwrote a formerly Baileys attempt with the newly selected Meta profile. No real provider was called.

[Profile eligibility](C:/Users/abdal/Work/KeepSIMs/keep_sims/supabase/functions/_shared/whatsapp_router.ts:195) loads readiness and expected/observed sender fields, but only checks `is_enabled`. **Another offline reproduction** sent through an enabled, degraded profile whose observed sender differed from its expected sender.

**Repair:** freeze provider/profile/sender snapshots for an attempt; atomically claim eligible retry states with a lease; validate purpose-specific readiness and sender identity before sending. Keep unknown outcomes withheld until reconciled. Preserve country choice for new sends and both existing adapters.

### 5. P1 — Meta inbound replies do not preserve their provider/profile

[Webhook reply request](C:/Users/abdal/Work/KeepSIMs/keep_sims/supabase/functions/waba-webhook/index.ts:230) passes only the receiving Meta `phone_number_id`. The router still selects a provider/profile from the recipient's country before using that override inside `sendViaMeta`.

**Reproduced offline:** a valid operational reply containing the receiving Meta sender ID is skipped when the recipient country route is Disabled. With a Baileys country route, the same control flow selects the Baileys adapter instead; with a different Meta profile, it can use that profile's token with the receiving sender ID.

**Repair:** authenticate/correlate the receiving profile and carry it as the operational conversation identity. Reply using that Meta profile/sender regardless of the recipient's outbound subscription-alert country route. Do not relax or change the Admin country-route policy for new outbound alerts.

### 6. P1 — Customer-controlled event text and binding fields remain a send surface

Live authenticated grants still permit notification INSERT/UPDATE (including title/body) and channel `config` updates. Notification INSERT policy checks only owner user ID and suspension. The only notification trigger is dispatch; the only channel trigger defaults Email. There is no narrow server-owned event creation or binding-field protection in these reviewed live objects.

The new paid-line ownership check closes the earlier foreign-line entitlement borrowing path. It does **not** stop a paid user from inserting arbitrary external-send text for their own line, choosing recipient config, or fabricating Telegram binding metadata. That leaves notification authenticity, verified consent and provider budgets exposed to client-controlled data.

**Repair:** use narrow server-rendered/rate-limited event creation contracts, restrict event updates to permitted read-state actions, and separate editable preferences from verified channel bindings. Add negative tests for forged events, arbitrary recipients and binding tampering. Perform isolated tests with providers disabled; no production abuse probe was performed here.

### 7. P1 — One-alert-per-cycle and ordinary scheduler dedupe are not atomic

[Cycle gate and consumption](C:/Users/abdal/Work/KeepSIMs/keep_sims/supabase/functions/_shared/whatsapp_router.ts:137) still read booleans before sending and set them after acceptance. Independent notification IDs for the same line/cycle can both pass; a line with no relevant schedules has no cycle guard. The update also sets every schedule of the line rather than reserving an identified alert cycle. Active refill `status='active'` is still treated as healthy without execution-health evidence.

Live `process_due_notifications()` reads due schedules without an atomic claim and inserts events without a deterministic source-cycle key before updating the schedule. Its current [migration definition](C:/Users/abdal/Work/KeepSIMs/keep_sims/supabase/migrations/20260926120000_alert_clock_and_durable_channel_dispatch.sql:777) retains this pattern. Overlapping execution can emit duplicate logical reminders.

**Repair:** reserve a unique line/purpose/cycle send atomically; consume/release it according to acceptance and safe failure semantics. Claim schedule rows and emit one source-keyed event per intended due cycle. Test overlapping producers and mixed notify/refill schedules.

### 8. P1 — Live database changes still lack migration provenance

The live repaired trigger, Standard WhatsApp catalog and `sent_at` column exist, but migration history contains no entries for the three new `20261001...` files. The predecessor `20261001030000...` file still contains the broken trigger; `20261001031000...` repairs it afterward. Database state and deployment history are out of sync.

**Repair:** compare and reconcile the exact applied definitions with the intended forward migrations, and verify clean-build and upgrade paths. Avoid blindly replaying the faulty predecessor against the live database. Record the successful schema/function release together; this review did not modify migration history.

## Other plan work still incomplete

- **Account/digest policy:** live weekly digest emits an account-wide event with no line ID. The repaired trigger/outbox/Email gate now treat such events as Basic, so paid Email digest delivery is unreachable. This avoids accidental borrowed entitlement but is not the explicit eligible-line aggregate policy required by the plan. Define the policy and generate only permitted content.
- **Receipt projection:** Meta and local Baileys receipt paths update WhatsApp attempt rows. They do not implement the planned consistent channel-delivery projection or update notification `delivered_via` from later verified receipts. Meta also correlates only by provider message ID, without the receiving profile, and its state rule only protects an already-delivered state.
- **UX/policy accuracy:** new plan/pause/failure copy remains hardcoded English. Local availability hints are not authoritative server capabilities and can describe a channel as active despite a disabled preference, missing binding or unavailable route. The fixed Email event allowlist still needs to match the category controls and documented event/channel policy.
- **Acceptance evidence:** no new end-to-end paid-line matrix, save-failure widget test, forged-event negative test, concurrent cycle/scheduler test, fresh profile probe or provider receipt fixture was supplied. Runtime worker parity, device behavior, approved Meta template compatibility and client/Admin release versions remain unverified.

## Validation completed

| Check | Result |
| --- | --- |
| Live catalog, repaired trigger/outbox schema and INSERT planning | Reviewed; repaired INSERT plans successfully with `EXPLAIN` without `ANALYZE`. |
| Deployed source and function versions | v34/v5/v4/v1 verified as above; remaining listed branches are deployed. |
| Live policies, grants, function definitions, scheduler and safe route/profile metadata | Reviewed read-only. No secrets/customer messages exported. |
| Focused Flutter analysis of settings screen/controller | No issues found. |
| Four existing Flutter notification/alert test files | **28 tests passed.** |
| Existing push/quiet-hours/worker durable queue tests | **16 tests passed.** |
| New offline defect reproductions | **6 defects reproduced**: failed delivery completes job, missing-secret unsigned command, lost Meta reply affinity, duplicate/provider-switch retry, unready/wrong-sender send, wrong Admin JWT context. |

The reproduction script is [notification-rereview-repros-20261001.cjs](C:/Users/abdal/Work/KeepSIMs/keep_sims/docs/reviews/notification-rereview-repros-20261001.cjs). Run from the customer repository with:

```text
node --test --test-isolation=none docs/reviews/notification-rereview-repros-20261001.cjs
```

These assertions intentionally confirm current defects. Their passing output is **not** a production acceptance pass; convert them into expected-safe-behavior regression tests when repairing the code.

## Executor repair order

1. Fix webhook signature failure behavior and the client event/binding trust boundary.
2. Fix channel outcome persistence/retry semantics and Admin caller/credential contracts.
3. Fix immutable attempt routing, retry claims, profile readiness and inbound Meta profile affinity while retaining country-selected Baileys/Meta outbound routes.
4. Implement atomic cycle/scheduler behavior and the account/digest/receipt policy.
5. Reconcile migration history, deploy compatible reviewed bundles/worker changes, release updated apps, and run the production-readiness acceptance matrix with isolated fixtures and controlled recipients.

Do not approve the whole system based only on the fixed settings screen or passing existing tests. The first-review P0 is closed; the remaining P1 findings above still justify holding production sign-off.
