# KeepSIMs alert channels and Alert Clock — AI executor prompt

**Prepared:** 2026-09-26  
**Purpose:** Implement the accepted alert-channel improvements across the customer app, Supabase, backend workers, and admin app. This is an execution brief, not a claim that the work is already implemented.

## Copy this prompt to the AI executor

You are implementing and verifying a production-ready improvement to KeepSIMs alerts. Work through the full scope below, including the **admin UI project**. Inspect the current code and live read-only configuration first. Preserve unrelated work in all checkouts. Implement in reviewable stages, test each boundary, and report exactly what was changed, deployed, verified, and left pending. Do not mark a provider acceptance response as delivery to a user's device or inbox.

### Repositories and source-of-truth rules

| Area | Local path | Notes |
| --- | --- | --- |
| Customer Flutter app, Supabase migrations and Edge Functions | `C:\Users\abdal\Work\KeepSIMs\keep_sims` | Read its `.agents/AGENTS.md` and relevant existing plans. Many files have pre-existing staged, unstaged, and untracked changes; preserve them. |
| Admin Flutter app | `C:\Users\abdal\Work\KeepSIMs\keep_sims_admin` | Read `ARCHITECTURE_RULES.md`; build any new admin feature in its model → contract → repository → controller → UI order. Preserve its ongoing WhatsApp management feature and other local work. |
| Authoritative local backend worker checkout | `C:\Users\abdal\Work\KeepSIMs\backend-sync-wt` | Worker changes belong here. The `servers` mirror in the customer repo is not authoritative. Follow the main repo's `.agents/AGENTS.md` for deployment only when deployment is authorized. |

Do not assume these checkouts are clean or that their HEAD represents production. Compare local code, deployed Edge Function versions, database migration history, cron definitions, and worker runtime before applying migrations or releasing. The user's clarification is authoritative: **`dispatch-alert` version 29 → 30 during the review changed only email sender/template branding from SIM Shield to KeepSIMs. Preserve the KeepSIMs branding.** Do not attribute the channel-router changes to that version bump without evidence.

### Product decisions already made

1. Add an **in-app Alert Clock** on each eligible line, with **one urgent 48-hour alert event** when the line is about two days from its estimated carrier deactivation cutoff. The user chose this instead of a persistent, updating phone notification. The in-app clock may update while visible; the phone notification must not be continuously rewritten.
2. Use the carrier's **inactivity/deactivation rule**, counted from the last **qualifying activity**. Do not use balance validity, bundle validity, grace period, a refill forecast, or an arbitrary recharge reminder date as if it were a verified line deactivation deadline.
3. The urgent event uses existing user channel preferences, entitlements, and deliverability rules. It should be one logical event per line and qualifying-activity cycle, with independently tracked channel attempts. A disabled channel stays disabled. The risk card remains visible in the app even when outbound channels are disabled.
4. Routine alerts respect Quiet Hours. The 48-hour critical event and a genuine `line_critical` event may bypass **in-app** Quiet Hours, with this clearly explained in settings. Respect OS notification permissions and Do Not Disturb. If a product policy elsewhere expressly disagrees, surface that conflict before release and choose one documented rule across app, database, and admin.
5. No exact countdown or 48-hour claim should appear where a trustworthy activity anchor or carrier rule is missing. Show a clear “date needed” or “estimate unavailable” state with the next useful action. The current missing-recharge-date reminder can help collect evidence; do not convert absence of data into an exact clock.

### Current baseline to verify, not hard-code

- At review, the live project had 105 carrier rules with inactivity limits; most used `recharge_ok`, 11 used `min_denomination`, and 2 used `usage_required`. Source and last-verification coverage were incomplete. The two active lines seen then had no `last_topup_at`, so neither qualified for a trustworthy 48-hour clock. Re-check the current state before work.
- Last-30-day logs showed many push provider acceptances alongside no-device skips; email was largely filtered by current category/quota behavior; Telegram commonly had no bound chat ID. WhatsApp routing and outbox work was in progress. These are observations, not confirmed end-user delivery rates.
- Local migrations, live database schema, and deployment history showed drift, including an untracked WhatsApp country-routing migration and a live `top_up_reminder` category. Reconcile state before proposing new DDL or changing an existing migration.
- `notification_settings_screen.dart` exposes Quiet Hours and Weekly Digest controls and makes fallback/test-delivery claims that need to match actual server behavior. The admin `channels_screen.dart` currently calls provider-accepted outcomes “Delivered.”

### Phase 0 — baseline and safety map

1. Inventory all writers and readers of `notifications`, `notification_deliveries`, channel preferences, carrier rules, SIM activity dates, WhatsApp outbox, push tokens, Telegram bindings, digest settings, and scheduled jobs. Identify the deployed code corresponding to each path.
2. Read the latest relevant migrations, especially `20260817000000_i7_carrier_activity_semantics.sql`, `20260817030000_i7d_forecast_uses_deactivation_cadence.sql`, `20260916080000_fix_forecast_anchor_null_recharge.sql`, `20260818010000_i8b_carrier_advice_notifications.sql`, `20260917021500_missing_recharge_date_reminders.sql`, and the currently untracked `20260926100000_whatsapp_country_routing.sql`. Confirm whether their contents or equivalents are already live. Never edit an applied migration; add forward migrations.
3. Capture a baseline of queue counts, notification-event counts, channel attempt status counts, no-device/no-chat skips, WhatsApp route health, cron results, admin channel status, and a few consented test accounts. Avoid sending test messages to real customers.
4. Write a small contract table for event categories, severity, entitlement, supported channels, Quiet Hours handling, deduplication identity, and intended UI deep link. Make the customer app, trigger, Edge Function, worker, and admin UI follow that contract.

### Phase 1 — trustworthy Alert Clock calculation

Implement one server-owned, testable source of truth that returns line-level clock state and eligibility. Keep the data model auditable: rule ID/version or snapshot, source URL or provenance, last verification time, qualifying activity source, activity timestamp/date, cutoff computation, precision, evaluation time, and reason for ineligibility. Restrict user-level data with existing RLS; use role-gated admin access for diagnostics.

**Carrier semantics and eligibility**

- `inactivity_limit_days` counts toward line-loss risk from the last qualifying activity. `grace_period_days` is after the cliff and is never added to the safe deadline. `balance_validity_days` and `topup_validity_days` are distinct concepts and must not drive this clock.
- For `recharge_ok`, use a confirmed successful recharge or a user-supplied last carrier top-up date marked as self-reported. Validate ownership and timestamp sanity. For `min_denomination`, qualify only a confirmed recharge meeting the carrier's amount and currency threshold; an amount-free manual date is insufficient. For `usage_required`, a recharge alone does not reset the clock: require a confirmed qualifying call, SMS, or data event. If the event is unavailable, mark the clock ineligible and explain the action required.
- Do not silently use `sim_lines.created_at`, `next_topup_due`, `validity_expires_at`, `predicted_depletion_at`, the last notification time, or a null fallback as activity. The existing forecast can be advisory, but it is not a verified deactivation timestamp.
- If the carrier provides only a date/day rule, do not invent a minute-accurate expiry. Use the carrier's known local calendar/time zone if documented; otherwise show **“about 2 days”** or a date-based countdown with an uncertainty label and record the time-zone assumption. Show hours/minutes only when the underlying cutoff timestamp has that precision. Store comparison instants in UTC and avoid client clock drift by returning server evaluation time.
- Distinguish `eligible`, `needs_activity_date`, `needs_qualifying_usage`, `needs_amount`, `missing_rule`, `stale_rule`, `inactive_line`, and `carrier_deactivated` states. An explicit, verified carrier deactivation overrides the estimate. Define a documented policy for a stale rule; do not send a claimed 48-hour deactivation alert from unverified or stale data.
- A qualifying activity update, carrier rule change, line deletion/inactivation, or carrier-confirmed status change must recompute clock state and invalidate stale pending alerts. Provide a dry-run preview of how many lines become eligible and how deadlines change before enabling production emission.

**Urgent-event scheduler**

- Emit the new event when an eligible line first enters the 48-hour threshold, including a bounded catch-up window if a scheduled run was missed. Re-read current line/rule/activity state immediately before sending, so an intervening recharge or confirmed usage cancels stale alerts.
- Persist a stable unique event identity such as line ID + activity/rule revision + threshold. Prevent duplicates across retries, concurrent cron runs, provider fallback, and activity edits; allow a new event only after a new qualifying cycle. Distinguish created, queued, attempted, accepted, delivered if provider evidence exists, skipped, failed, retrying, and canceled states.
- Keep existing `line_critical`, refill reminder, carrier advice, missing-date reminder, and any recovery flow from double-alerting on the same risk. Define priority and suppression rules in code and tests. The 48-hour event should navigate to the correct SIM line and show the evidence and action that can keep it active.
- The scheduler must be safe to run twice, have bounded work per run and backfill, expose dry-run output, and record failures for admin inspection. User preferences and entitlement are evaluated at dispatch time as well as when the logical event is created.

**Customer app**

- Show the Alert Clock prominently on the line detail and on any existing urgent-risk surface where it improves actionability. Add the carrier rule, last qualifying activity, cutoff date/precision, source or verification indicator, and one-tap action to record/verify activity or recharge. Do not imply a manual entry guarantees carrier acceptance.
- Render a date-based countdown honestly; while the screen is visible, refresh the display from the server-derived deadline and server time offset. Recompute on app resume or line updates. Do not persist a guessed local deadline or run a permanent background timer.
- Add a clear 48-hour alert entry to notification history and settings. Include accessible copy and deep-link routing; distinguish the new clock event from generic line-critical/recharge reminders. Ensure localization and KeepSIMs branding wherever notification copy is changed.

### Phase 2 — channel delivery correctness and resilience

**Durable dispatch and status semantics**

Replace or harden the current database-trigger → `pg_net` → `dispatch-alert` handoff with a durable, observable job/outbox boundary. A trigger may enqueue, but a successful HTTP request or provider acceptance must not mark an alert “delivered.” Provide idempotency keys, attempts, exponential backoff with caps, terminal/dead-letter states, retry policy by error type, stale-event cancellation, and a way to replay safely. Make the job worker and any cron schedule observable in admin. Preserve currently working channels during rollout.

Track a channel attempt separately from the logical event. Record at least `queued`, `attempting`, `accepted_by_provider`, `delivered` only with a receipt if available, `unknown`, `skipped` with a reason, `retrying`, and `failed`. If a provider cannot report delivery, the UI must say “accepted by provider” or “status unknown.” Update `delivered_via` or replace it with an accurate derived value; do not pre-populate it before the provider result. A successful test-send request likewise means accepted unless a receipt proves delivery.

**WhatsApp and worker idempotency**

Fix `supabase/functions/_shared/whatsapp_router.ts` and the authoritative worker `server_baileys.js` as one end-to-end transaction model. The router currently returns early only for `sent`/`delivered`, ignores an insert conflict before sending, and passes the request's optional idempotency key to the worker instead of its generated key. The worker currently accepts `/send` by adding a queue job and returns before recipient delivery. Make the same stable key survive router → worker queue → send attempt → callback/receipt, and enforce uniqueness at each boundary. Treat `pending`, `accepted`, and `unknown` as potentially sent until reconciled; never launch a duplicate merely because a response was lost. Define when `whatsapp_sent_this_cycle` becomes true based on actual policy and evidence, rather than confusing a queued job with recipient delivery. Add recovery for worker restart, timeouts, callback loss, and manual retry. Preserve country route selection and the work already in progress.

**Other routes and preference truth**

- Keep OneSignal → targeted FCM fallback scoped to a known failed push attempt; do not fan out a second push when the first outcome is unknown. Record no-device and revoked-token reasons, repair stale tokens, and ensure only intended devices/users are targeted.
- Audit Telegram binding (`server_tg.js` `/start bind_UUID` and the related RPC) for account ownership, expiry, replay prevention, and the absence of chat ID. The admin and customer UI must tell users when setup is incomplete. Do not expose or log raw binding secrets or chat IDs unnecessarily.
- Reconcile the effective entitlement matrix, including the current WhatsApp premium/catalog vs routing/UI mismatch and the `top_up_reminder` category drift. Choose the product's intended tier policy from existing authoritative product rules; encode it once and apply it across database, Edge Function, customer UI, and admin UI. Do not silently upgrade or downgrade users.
- Make the email category/quota behavior visible and accurate. Preserve the version 30 KeepSIMs sender/template branding. Explain the precise fallback policy: if automatic email fallback from a failed push is implemented, specify eligible categories, consent, quotas, and deduplication; otherwise remove the app's promise of fallback. Never use email as a way around an explicit channel opt-out.
- Implement actual Quiet Hours behavior for routine sends, with a release time, time-zone/DST handling, and idempotent catch-up. Implement Weekly Digest aggregation, schedule, consent, and clear separation from urgent events. If a route is unsupported, show that truth in settings rather than a toggle that does nothing.

### Phase 3 — admin UI and operational control

Update `keep_sims_admin`, not just the customer app. Use its required model → contract → repository → controller → UI architecture and admin-authorized RPCs/queries; keep service-role credentials out of the Flutter client. Extend existing `channels_screen.dart`, `operations_screen.dart`, `carriers_screen.dart`, and the in-progress WhatsApp management feature rather than duplicating them.

1. **Channel health:** show logical events, attempted sends, provider acceptances, confirmed deliveries where receipts exist, unknowns, failures, skips by reason, retry backlog, oldest queued item, dead-letter count, and last successful worker/cron run. Rename existing “Delivered” metrics where the data only establishes provider acceptance. Display the effective channel availability and entitlement for each category.
2. **Actionable diagnostics:** surface no-device push, unbound Telegram, disabled or missing WhatsApp route, missing credentials, unsupported email category/quota, consent/opt-out, and webhook configuration distinctly. Give an admin safe test-send path to a selected internal/test identity, with exact outcome wording and audit trail.
3. **Alert Clock oversight:** show eligible/unknown/stale-rule/within-48h/alerted counts; drill into a line's rule, activity evidence, cutoff precision, next alert action, and suppression reason. Provide a read-only dry-run preview before enabling the new scheduler and a scoped pause/kill switch with audit logging. Never expose another user's private line data without existing admin authorization.
4. **Carrier rule quality:** let admins inspect and correct inactivity limits, activity requirements, minimum denomination/currency, source URL, verification date, and effective version. Preview affected clocks and alerts before committing a rule change; invalidate stale alerts after changes. Separate grace, balance validity, and bundle validity visually from deactivation cadence.
5. **Operational workflow:** allow safe retry/replay of failed jobs when idempotency state proves it safe; show why an accepted/unknown WhatsApp job cannot yet be retried. Document escalation and provider receipt limits. Reflect the same status model in admin tables, charts, exports, and any settings copy.

### Phase 4 — migration, tests, release and evidence

Build additive forward migrations with RLS, ownership checks, indexes for due jobs, uniqueness constraints, and explicit grants. Check query plans for the due-job and per-line clock queries on realistic volumes. Reconcile deployed/local migration drift before executing DDL; do not replay an already-live WhatsApp migration blindly. Use the project's Supabase workflow and verify current official platform behavior before relying on a platform feature.

Provide meaningful automated tests for:

- Carrier rule types (`recharge_ok`, `min_denomination`, `usage_required`); missing, self-reported, invalid and newly confirmed activity; date-only rules, carrier time zones/DST, grace exclusion, and rule changes.
- The 48-hour crossing, missed scheduler run, concurrent runs, duplicate suppression, new qualifying cycle, activity just before dispatch, canceled/inactive line, and deep link.
- Preferences, entitlement, Quiet Hours, Weekly Digest, disabled channels, unsupported routes, no-device/no-chat states, email quota, and truthful fallback copy.
- Provider accepted vs delivered vs unknown; HTTP timeout after provider acceptance; retry limits; WhatsApp duplicate request/insert conflict/worker restart/callback replay; targeted FCM fallback.
- Admin authorization, channel metrics, rule preview, pause switch, and test-send status labels.

Run relevant existing tests and new focused tests for each codebase, plus migration validation and worker syntax checks. Use controlled test recipients and provider mocks before a small canary. Do not send a real 48-hour warning to customers from speculative dates. Roll out behind a feature flag with dry-run metrics, then a limited canary of lines with verified qualifying activity and verified carrier rules. Monitor queue lag, duplicate events, skips, accepted/unknown outcomes, callback reconciliation, and opt-outs. Document a rollback that stops emission without deleting history or losing queued state. If deployment is in scope and authorized, follow the worker SSH/SCP rule in `.agents/AGENTS.md`; otherwise leave exact deployment commands and validation evidence for the release owner.

### Required delivery artifacts and definition of done

Return a concise implementation report with links to changed files/PRs across **all three checkouts**; a migration/deployment map; tests and their results; screenshots or UI walkthroughs of the customer Alert Clock and admin diagnostics; before/after status counts; outstanding provider receipt limits; and rollout/rollback steps. State explicitly which changes are local only and which are live.

The job is complete only when an eligible line shows an honest, source-backed clock; one 48-hour logical alert is created and routed according to preferences; an ineligible line does not display a fabricated deadline; retries cannot duplicate a send; Quiet Hours and Weekly Digest controls perform as labeled; all channel metrics distinguish acceptance from delivery; the admin app exposes the new health and carrier-rule workflows; KeepSIMs branding remains intact; and the verified deployment state is documented.
